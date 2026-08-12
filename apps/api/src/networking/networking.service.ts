import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

// Discovery is opt-in both ways: a candidate must publish a discoverable
// profile of their own before they can see anyone else's. No lurking --
// you can't browse without being visible yourself. See
// NetworkingService.discover's doc comment.
const DISCOVER_RESULT_LIMIT = 20;

// A connection request touches another candidate's inbox, not just the
// requester's own data -- generous enough for genuine use, low enough to
// blunt spam. Same in-memory, resets-on-restart posture as
// ResumeService/CoachService's rate limits; see resume.service.ts's doc
// comment for why that trade-off is accepted for v1.
const MAX_CONNECTION_REQUESTS_PER_DAY = 20;

const MAX_PREFERRED_ROLES = 10;
const MAX_FIELD_LENGTH = 80;
const MAX_HEADLINE_LENGTH = 160;

type ConnectionStatus = 'pending' | 'accepted' | 'declined' | 'withdrawn';

interface ProfileRow {
  candidate_id: string;
  discoverable: boolean;
  full_name: string;
  headline: string;
  city: string;
  state: string;
  preferred_roles: string[];
}

interface ConnectionRow {
  id: string;
  requester_id: string;
  recipient_id: string;
  status: ConnectionStatus;
  created_at: string;
  responded_at: string | null;
}

export interface PublishProfileBody {
  fullName: string;
  headline?: string;
  city?: string;
  state?: string;
  preferredRoles: string[];
  discoverable: boolean;
}

export interface NetworkingProfileResponse {
  discoverable: boolean;
  fullName: string;
  headline: string;
  city: string;
  state: string;
  preferredRoles: string[];
}

export interface DiscoveredCandidate {
  candidateId: string;
  fullName: string;
  headline: string;
  city: string;
  state: string;
  sharedRoles: string[];
}

export interface ConnectionActionResponse {
  id: string;
  status: ConnectionStatus;
}

export interface OtherCandidateSummary {
  fullName: string;
  headline: string;
  city: string;
  state: string;
}

export interface ConnectionSummary {
  id: string;
  status: 'pending' | 'accepted';
  direction: 'incoming' | 'outgoing';
  otherCandidateId: string;
  otherCandidate: OtherCandidateSummary | null;
  createdAt: string;
  respondedAt: string | null;
}

export interface ConnectionsResponse {
  accepted: ConnectionSummary[];
  incomingPending: ConnectionSummary[];
  outgoingPending: ConnectionSummary[];
}

const UNAVAILABLE_MESSAGE =
  'Networking is temporarily unavailable. Please try again in a moment.';

function unavailable(): AppError {
  return AppError.serviceUnavailable('NETWORKING_UNAVAILABLE', UNAVAILABLE_MESSAGE);
}

/**
 * Candidate-to-candidate discovery and connections -- deliberately
 * view-only for v1. Once connected, both sides can see each other's
 * published networking profile; there is no in-app messaging here.
 * Messaging is a real follow-on decision, not an oversight: it needs its
 * own moderation, blocking-mid-conversation, and reporting-to-Flora-staff
 * work to ship responsibly, and none of that exists yet. Block/unblock
 * below is the one safety primitive this v1 does ship, since even a
 * view-only connection is something a candidate needs to be able to shut
 * down unilaterally.
 *
 * Every cross-candidate read and write goes through this service (the
 * BFF), never a direct Supabase call from the app -- matching how
 * `CareerPassportService.listAppliedEmployers` already treats "read
 * something that depends on other users' rows" as BFF-only. RLS on the
 * underlying tables is defense-in-depth (own-row visibility), not the
 * real authorization boundary; this service enforces matching, blocking,
 * and rate limits in code.
 */
@Injectable()
export class NetworkingService {
  private readonly dailyRequestCounts = new Map<
    string,
    { day: string; count: number }
  >();

  constructor(private readonly supabase: SupabaseService) {}

  /**
   * The candidate's own current networking profile, including
   * `discoverable` -- added alongside the mobile-client fix for the bug
   * where `NetworkingSection`'s local `_discoverable` state was hardcoded
   * to `false` on every fresh build instead of ever being read from here.
   * This reuses the exact same row lookup `discover`/`sendConnectionRequest`
   * already do via `getProfileRow`; a candidate who has never published a
   * profile has no row yet, which honestly *is* "not discoverable" --
   * so that case returns the same all-defaults shape `publishProfile`
   * would produce for a fresh candidate, not an error.
   */
  async getMyProfile(candidateId: string): Promise<NetworkingProfileResponse> {
    const row = await this.getProfileRow(candidateId);
    if (!row) {
      return {
        discoverable: false,
        fullName: '',
        headline: '',
        city: '',
        state: '',
        preferredRoles: [],
      };
    }
    return {
      discoverable: row.discoverable,
      fullName: row.full_name,
      headline: row.headline,
      city: row.city,
      state: row.state,
      preferredRoles: row.preferred_roles,
    };
  }

  async publishProfile(
    candidateId: string,
    body: PublishProfileBody,
  ): Promise<NetworkingProfileResponse> {
    const fullName = body.fullName?.trim() ?? '';
    if (!fullName) {
      throw AppError.validation(
        'A name is required to publish your networking profile.',
      );
    }
    const headline = (body.headline ?? '').trim().slice(0, MAX_HEADLINE_LENGTH);
    const city = (body.city ?? '').trim().slice(0, MAX_FIELD_LENGTH);
    const state = (body.state ?? '').trim().slice(0, MAX_FIELD_LENGTH);
    const preferredRoles = this.sanitizeRoles(body.preferredRoles);
    const discoverable = body.discoverable === true;

    const { error } = await this.supabase.admin.from('networking_profiles').upsert({
      candidate_id: candidateId,
      discoverable,
      full_name: fullName,
      headline,
      city,
      state,
      preferred_roles: preferredRoles,
      updated_at: new Date().toISOString(),
    });
    if (error) throw unavailable();

    return { discoverable, fullName, headline, city, state, preferredRoles };
  }

  /**
   * Reciprocal by design: a candidate who hasn't published a discoverable
   * profile of their own gets a clear, actionable error rather than a
   * silent empty list -- browsing without being visible yourself isn't
   * offered as an option, not just an oversight.
   */
  async discover(candidateId: string): Promise<DiscoveredCandidate[]> {
    const myProfile = await this.getProfileRow(candidateId);
    if (!myProfile || !myProfile.discoverable) {
      throw AppError.forbidden(
        'DISCOVERABILITY_REQUIRED',
        'Turn on discoverability on your Professional Persona to see other candidates.',
      );
    }
    const myRoles = new Set(myProfile.preferred_roles);
    if (myRoles.size === 0) return [];

    const { data, error } = await this.supabase.admin
      .from('networking_profiles')
      .select('candidate_id, full_name, headline, city, state, preferred_roles')
      .eq('discoverable', true);
    if (error) throw unavailable();

    const excluded = await this.excludedCandidateIds(candidateId);

    const results: DiscoveredCandidate[] = [];
    for (const row of (data ?? []) as ProfileRow[]) {
      if (row.candidate_id === candidateId) continue;
      if (excluded.has(row.candidate_id)) continue;
      const sharedRoles = row.preferred_roles.filter((role) => myRoles.has(role));
      if (sharedRoles.length === 0) continue;
      results.push({
        candidateId: row.candidate_id,
        fullName: row.full_name,
        headline: row.headline,
        city: row.city,
        state: row.state,
        sharedRoles,
      });
      if (results.length >= DISCOVER_RESULT_LIMIT) break;
    }
    return results;
  }

  async sendConnectionRequest(
    candidateId: string,
    recipientCandidateId: string,
  ): Promise<ConnectionActionResponse> {
    const recipientId = recipientCandidateId?.trim();
    if (!recipientId) {
      throw AppError.validation('A recipient is required.');
    }
    if (recipientId === candidateId) {
      throw AppError.validation(
        'You cannot send a connection request to yourself.',
      );
    }

    const [blockedByMe, blockedMe] = await Promise.all([
      this.isBlocked(candidateId, recipientId),
      this.isBlocked(recipientId, candidateId),
    ]);
    if (blockedByMe || blockedMe) {
      throw AppError.forbidden(
        'NETWORKING_BLOCKED',
        'This candidate is not available to connect with.',
      );
    }

    const recipientProfile = await this.getProfileRow(recipientId);
    if (!recipientProfile || !recipientProfile.discoverable) {
      throw AppError.validation('This candidate is not currently discoverable.');
    }

    const existing = await this.findActiveConnectionBetween(candidateId, recipientId);
    if (existing?.status === 'accepted') {
      throw AppError.validation('You are already connected with this candidate.');
    }
    if (existing?.status === 'pending' && existing.requester_id === candidateId) {
      throw AppError.validation(
        'You already have a pending request to this candidate.',
      );
    }
    if (existing?.status === 'pending' && existing.requester_id === recipientId) {
      // They already asked -- accept immediately instead of leaving two
      // one-way requests sitting in parallel waiting on each other.
      return this.updateConnectionStatus(existing.id, 'accepted');
    }

    this.enforceRequestRateLimit(candidateId);

    const { data, error } = await this.supabase.admin
      .from('networking_connections')
      .insert({
        requester_id: candidateId,
        recipient_id: recipientId,
        status: 'pending' as const,
      })
      .select('id, status')
      .maybeSingle();
    if (error || !data) throw unavailable();
    return data as ConnectionActionResponse;
  }

  async respondToConnection(
    candidateId: string,
    connectionId: string,
    accept: boolean,
  ): Promise<ConnectionActionResponse> {
    const row = await this.getConnectionRow(connectionId);
    if (!row || row.recipient_id !== candidateId || row.status !== 'pending') {
      throw AppError.notFound(
        'CONNECTION_NOT_FOUND',
        'This connection request is no longer available.',
      );
    }
    return this.updateConnectionStatus(connectionId, accept ? 'accepted' : 'declined');
  }

  async withdrawConnection(
    candidateId: string,
    connectionId: string,
  ): Promise<ConnectionActionResponse> {
    const row = await this.getConnectionRow(connectionId);
    const involvesMe =
      row && (row.requester_id === candidateId || row.recipient_id === candidateId);
    const isActive = row && (row.status === 'pending' || row.status === 'accepted');
    if (!row || !involvesMe || !isActive) {
      throw AppError.notFound(
        'CONNECTION_NOT_FOUND',
        'This connection is no longer available.',
      );
    }
    return this.updateConnectionStatus(connectionId, 'withdrawn');
  }

  async listConnections(candidateId: string): Promise<ConnectionsResponse> {
    const [asRequester, asRecipient] = await Promise.all([
      this.supabase.admin
        .from('networking_connections')
        .select('id, requester_id, recipient_id, status, created_at, responded_at')
        .eq('requester_id', candidateId),
      this.supabase.admin
        .from('networking_connections')
        .select('id, requester_id, recipient_id, status, created_at, responded_at')
        .eq('recipient_id', candidateId),
    ]);
    if (asRequester.error || asRecipient.error) throw unavailable();
    const rows = [
      ...((asRequester.data ?? []) as ConnectionRow[]),
      ...((asRecipient.data ?? []) as ConnectionRow[]),
    ];

    const otherIds = new Set<string>();
    for (const row of rows) {
      if (row.status !== 'pending' && row.status !== 'accepted') continue;
      otherIds.add(row.requester_id === candidateId ? row.recipient_id : row.requester_id);
    }
    const profiles = await this.getProfilesByIds([...otherIds]);

    const accepted: ConnectionSummary[] = [];
    const incomingPending: ConnectionSummary[] = [];
    const outgoingPending: ConnectionSummary[] = [];

    for (const row of rows) {
      if (row.status !== 'pending' && row.status !== 'accepted') continue;
      const isRequester = row.requester_id === candidateId;
      const otherId = isRequester ? row.recipient_id : row.requester_id;
      const summary: ConnectionSummary = {
        id: row.id,
        status: row.status,
        direction: isRequester ? 'outgoing' : 'incoming',
        otherCandidateId: otherId,
        otherCandidate: profiles.get(otherId) ?? null,
        createdAt: row.created_at,
        respondedAt: row.responded_at,
      };
      if (row.status === 'accepted') accepted.push(summary);
      else if (isRequester) outgoingPending.push(summary);
      else incomingPending.push(summary);
    }

    return { accepted, incomingPending, outgoingPending };
  }

  /**
   * Blocking is unilateral -- it never requires the blocked candidate's
   * cooperation -- and immediately ends any existing pending/accepted
   * connection between the pair rather than leaving it dangling.
   */
  async blockCandidate(candidateId: string, blockedId: string): Promise<void> {
    const target = blockedId?.trim();
    if (!target) {
      throw AppError.validation('A candidate to block is required.');
    }
    if (target === candidateId) {
      throw AppError.validation('You cannot block yourself.');
    }
    const { error } = await this.supabase.admin
      .from('networking_blocks')
      .upsert({ blocker_id: candidateId, blocked_id: target });
    if (error) throw unavailable();

    const existing = await this.findActiveConnectionBetween(candidateId, target);
    if (existing) {
      await this.updateConnectionStatus(existing.id, 'withdrawn');
    }
  }

  async unblockCandidate(candidateId: string, blockedId: string): Promise<void> {
    const target = blockedId?.trim();
    if (!target) {
      throw AppError.validation('A candidate to unblock is required.');
    }
    const { error } = await this.supabase.admin
      .from('networking_blocks')
      .delete()
      .eq('blocker_id', candidateId)
      .eq('blocked_id', target);
    if (error) throw unavailable();
  }

  private sanitizeRoles(roles: unknown): string[] {
    if (!Array.isArray(roles)) return [];
    const cleaned = roles
      .filter((role): role is string => typeof role === 'string')
      .map((role) => role.trim())
      .filter((role) => role.length > 0 && role.length <= 60);
    return [...new Set(cleaned)].slice(0, MAX_PREFERRED_ROLES);
  }

  private async getProfileRow(candidateId: string): Promise<ProfileRow | null> {
    const { data, error } = await this.supabase.admin
      .from('networking_profiles')
      .select('candidate_id, discoverable, full_name, headline, city, state, preferred_roles')
      .eq('candidate_id', candidateId)
      .maybeSingle();
    if (error) throw unavailable();
    return (data as ProfileRow | null) ?? null;
  }

  private async getProfilesByIds(
    ids: string[],
  ): Promise<Map<string, OtherCandidateSummary>> {
    const map = new Map<string, OtherCandidateSummary>();
    if (ids.length === 0) return map;
    const { data, error } = await this.supabase.admin
      .from('networking_profiles')
      .select('candidate_id, full_name, headline, city, state')
      .in('candidate_id', ids);
    if (error) throw unavailable();
    for (const row of (data ?? []) as Pick<
      ProfileRow,
      'candidate_id' | 'full_name' | 'headline' | 'city' | 'state'
    >[]) {
      map.set(row.candidate_id, {
        fullName: row.full_name,
        headline: row.headline,
        city: row.city,
        state: row.state,
      });
    }
    return map;
  }

  private async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    const { data, error } = await this.supabase.admin
      .from('networking_blocks')
      .select('blocker_id')
      .eq('blocker_id', blockerId)
      .eq('blocked_id', blockedId)
      .maybeSingle();
    if (error) throw unavailable();
    return data != null;
  }

  private async excludedCandidateIds(candidateId: string): Promise<Set<string>> {
    const excluded = new Set<string>();

    const [blocksIMade, blocksAgainstMe, asRequester, asRecipient] = await Promise.all([
      this.supabase.admin
        .from('networking_blocks')
        .select('blocked_id')
        .eq('blocker_id', candidateId),
      this.supabase.admin
        .from('networking_blocks')
        .select('blocker_id')
        .eq('blocked_id', candidateId),
      this.supabase.admin
        .from('networking_connections')
        .select('recipient_id, status')
        .eq('requester_id', candidateId)
        .in('status', ['pending', 'accepted']),
      this.supabase.admin
        .from('networking_connections')
        .select('requester_id, status')
        .eq('recipient_id', candidateId)
        .in('status', ['pending', 'accepted']),
    ]);
    if (
      blocksIMade.error ||
      blocksAgainstMe.error ||
      asRequester.error ||
      asRecipient.error
    ) {
      throw unavailable();
    }

    (blocksIMade.data ?? []).forEach((row: { blocked_id: string }) =>
      excluded.add(row.blocked_id),
    );
    (blocksAgainstMe.data ?? []).forEach((row: { blocker_id: string }) =>
      excluded.add(row.blocker_id),
    );
    (asRequester.data ?? []).forEach((row: { recipient_id: string }) =>
      excluded.add(row.recipient_id),
    );
    (asRecipient.data ?? []).forEach((row: { requester_id: string }) =>
      excluded.add(row.requester_id),
    );
    return excluded;
  }

  private async findActiveConnectionBetween(
    a: string,
    b: string,
  ): Promise<ConnectionRow | null> {
    const { data, error } = await this.supabase.admin
      .from('networking_connections')
      .select('id, requester_id, recipient_id, status, created_at, responded_at')
      .in('requester_id', [a, b])
      .in('recipient_id', [a, b]);
    if (error) throw unavailable();
    const rows = (data ?? []) as ConnectionRow[];
    return (
      rows.find(
        (row) =>
          ((row.requester_id === a && row.recipient_id === b) ||
            (row.requester_id === b && row.recipient_id === a)) &&
          (row.status === 'pending' || row.status === 'accepted'),
      ) ?? null
    );
  }

  private async getConnectionRow(connectionId: string): Promise<ConnectionRow | null> {
    const { data, error } = await this.supabase.admin
      .from('networking_connections')
      .select('id, requester_id, recipient_id, status, created_at, responded_at')
      .eq('id', connectionId)
      .maybeSingle();
    if (error) throw unavailable();
    return (data as ConnectionRow | null) ?? null;
  }

  private async updateConnectionStatus(
    connectionId: string,
    status: ConnectionStatus,
  ): Promise<ConnectionActionResponse> {
    const { error } = await this.supabase.admin
      .from('networking_connections')
      .update({ status, responded_at: new Date().toISOString() })
      .eq('id', connectionId);
    if (error) throw unavailable();
    return { id: connectionId, status };
  }

  private enforceRequestRateLimit(candidateId: string): void {
    const today = new Date().toISOString().slice(0, 10);
    const existing = this.dailyRequestCounts.get(candidateId);
    if (!existing || existing.day !== today) {
      this.dailyRequestCounts.set(candidateId, { day: today, count: 1 });
      return;
    }
    if (existing.count >= MAX_CONNECTION_REQUESTS_PER_DAY) {
      throw AppError.rateLimited(
        "You have reached today's connection request limit. Please try again tomorrow.",
      );
    }
    existing.count += 1;
  }
}

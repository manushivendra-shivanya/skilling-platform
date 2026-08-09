import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

export interface ShiftRequest {
  id: string;
  role_title: string;
  site_name: string;
  site_address: string;
  city: string;
  starts_at: string;
  ends_at: string;
  reporting_time: string | null;
  headcount: number;
  pay_amount: string;
  pay_currency: string;
  required_competency_ids: string[];
  description: string | null;
  supervisor_name: string | null;
  supervisor_contact: string | null;
  cancellation_policy: string | null;
  status: string;
}

// A single unbroken string literal, not `+`-concatenated -- concatenation
// widens the inferred type to plain `string`, which breaks postgrest-js's
// compile-time column-name parsing (surfaces as a `GenericStringError`
// return type instead of the real row shape). Matches jobs.service.ts's
// JOB_COLUMNS exactly for this reason.
const SHIFT_COLUMNS = 'id, role_title, site_name, site_address, city, starts_at, ends_at, reporting_time, headcount, pay_amount, pay_currency, required_competency_ids, description, supervisor_name, supervisor_contact, cancellation_policy, status';

export interface ShiftApplication {
  id: string;
  shift_id: string;
  candidate_id: string;
  status: string;
  checked_in_at: string | null;
  checked_out_at: string | null;
  created_at: string;
}

const APPLICATION_COLUMNS = 'id, shift_id, candidate_id, status, checked_in_at, checked_out_at, created_at';

@Injectable()
export class ShiftsService {
  constructor(private readonly supabase: SupabaseService) {}

  /**
   * Deliberately returns plain listings with no candidate-specific
   * match/eligibility data. Match% and skill-gate status are computed on
   * the mobile client instead, from the same already-loaded Career
   * Passport evidence Role Readiness uses -- the service-role client here
   * can only see server-synced (WMS) evidence, not the device-local
   * micro-lesson/certification-exam evidence, so computing it here would
   * silently under-count real candidate readiness.
   */
  async listPublished(): Promise<ShiftRequest[]> {
    const { data, error } = await this.supabase.admin
      .from('shift_requests')
      .select(SHIFT_COLUMNS)
      .eq('status', 'published')
      .order('starts_at', { ascending: true });
    if (error) {
      throw new Error(`Failed to load shifts: ${error.message}`);
    }
    return data ?? [];
  }

  async getById(shiftId: string): Promise<ShiftRequest> {
    const { data, error } = await this.supabase.admin
      .from('shift_requests')
      .select(SHIFT_COLUMNS)
      .eq('id', shiftId)
      .eq('status', 'published')
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to load shift: ${error.message}`);
    }
    if (!data) {
      throw AppError.notFound('SHIFT_NOT_FOUND', 'This shift is not available.');
    }
    return data;
  }

  async listApplicationsForCandidate(
    candidateId: string,
  ): Promise<ShiftApplication[]> {
    const { data, error } = await this.supabase.admin
      .from('shift_applications')
      .select(APPLICATION_COLUMNS)
      .eq('candidate_id', candidateId)
      .order('created_at', { ascending: false });
    if (error) {
      throw new Error(`Failed to load shift applications: ${error.message}`);
    }
    return data ?? [];
  }

  /**
   * Idempotent the same way jobs.service.ts's applyToJob is: a repeated
   * call for the same candidate and shift returns the existing
   * application rather than erroring, backstopped by the unique
   * (shift_id, candidate_id) constraint from the migration, not just this
   * read-then-write check.
   *
   * No waitlist in this phase: a shift at headcount is a clean rejection,
   * not a queue -- see the plan's "Explicitly deferred" section.
   */
  async applyToShift(
    candidateId: string,
    shiftId: string,
    idempotencyKey: string,
  ): Promise<{ application: ShiftApplication; created: boolean }> {
    const shift = await this.getById(shiftId);

    const { data: existing, error: existingError } = await this.supabase.admin
      .from('shift_applications')
      .select(APPLICATION_COLUMNS)
      .eq('shift_id', shiftId)
      .eq('candidate_id', candidateId)
      .maybeSingle();
    if (existingError) {
      throw new Error(
        `Failed to check existing shift application: ${existingError.message}`,
      );
    }
    if (existing) {
      return { application: existing, created: false };
    }

    const { count, error: countError } = await this.supabase.admin
      .from('shift_applications')
      .select('id', { count: 'exact', head: true })
      .eq('shift_id', shiftId)
      .in('status', ['accepted', 'confirmed', 'checked_in', 'completed']);
    if (countError) {
      throw new Error(`Failed to check shift headcount: ${countError.message}`);
    }
    if ((count ?? 0) >= shift.headcount) {
      throw AppError.validation('This shift is already fully staffed.');
    }

    const { data: created, error: insertError } = await this.supabase.admin
      .from('shift_applications')
      .insert({
        shift_id: shiftId,
        candidate_id: candidateId,
        idempotency_key: idempotencyKey,
      })
      .select(APPLICATION_COLUMNS)
      .single();
    if (insertError) {
      // A concurrent request may have inserted first -- the unique
      // constraint on (shift_id, candidate_id) is the real idempotency
      // guarantee; fall back to reading what won the race.
      const { data: winner } = await this.supabase.admin
        .from('shift_applications')
        .select(APPLICATION_COLUMNS)
        .eq('shift_id', shiftId)
        .eq('candidate_id', candidateId)
        .maybeSingle();
      if (winner) {
        return { application: winner, created: false };
      }
      throw new Error(
        `Failed to create shift application: ${insertError.message}`,
      );
    }

    return { application: created, created: true };
  }

  /**
   * Check-in uses a supervisor-issued code, not GPS/QR/selfie -- see the
   * plan's "Explicitly deferred" section for why. The code lives on the
   * shift, not the application, since it's the same code for every worker
   * on that shift (given out to the site supervisor once, out-of-band).
   */
  async checkIn(
    candidateId: string,
    applicationId: string,
    code: string,
  ): Promise<ShiftApplication> {
    const application = await this.findOwnedApplication(
      candidateId,
      applicationId,
    );
    if (application.status === 'checked_in' || application.status === 'completed') {
      return application;
    }
    if (application.status !== 'accepted' && application.status !== 'confirmed') {
      throw AppError.validation(
        `Cannot check in from status "${application.status}".`,
      );
    }

    const { data: shift, error: shiftError } = await this.supabase.admin
      .from('shift_requests')
      .select('check_in_code')
      .eq('id', application.shift_id)
      .single();
    if (shiftError) {
      throw new Error(`Failed to load shift: ${shiftError.message}`);
    }
    if (shift.check_in_code !== code) {
      throw AppError.validation('That check-in code does not match.');
    }

    const { data: updated, error: updateError } = await this.supabase.admin
      .from('shift_applications')
      .update({
        status: 'checked_in',
        checked_in_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', applicationId)
      .eq('candidate_id', candidateId)
      .select(APPLICATION_COLUMNS)
      .single();
    if (updateError) {
      throw new Error(`Failed to check in: ${updateError.message}`);
    }
    return updated;
  }

  /**
   * Checking out marks the application completed and creates the payout
   * ledger row at pending_approval -- a status a human (site/ops) still
   * has to move forward. No money moves here or anywhere in this service;
   * see the migration header for why.
   */
  async checkOut(
    candidateId: string,
    applicationId: string,
  ): Promise<ShiftApplication> {
    const application = await this.findOwnedApplication(
      candidateId,
      applicationId,
    );
    if (application.status === 'completed') {
      return application;
    }
    if (application.status !== 'checked_in') {
      throw AppError.validation(
        `Cannot check out from status "${application.status}".`,
      );
    }

    const { data: shift, error: shiftError } = await this.supabase.admin
      .from('shift_requests')
      .select('pay_amount')
      .eq('id', application.shift_id)
      .single();
    if (shiftError) {
      throw new Error(`Failed to load shift: ${shiftError.message}`);
    }

    const { data: updated, error: updateError } = await this.supabase.admin
      .from('shift_applications')
      .update({
        status: 'completed',
        checked_out_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', applicationId)
      .eq('candidate_id', candidateId)
      .select(APPLICATION_COLUMNS)
      .single();
    if (updateError) {
      throw new Error(`Failed to check out: ${updateError.message}`);
    }

    const { error: payoutError } = await this.supabase.admin
      .from('shift_payouts')
      .upsert(
        {
          shift_application_id: applicationId,
          candidate_id: candidateId,
          base_pay: shift.pay_amount,
          total: shift.pay_amount,
        },
        { onConflict: 'shift_application_id' },
      );
    if (payoutError) {
      throw new Error(`Failed to create payout record: ${payoutError.message}`);
    }

    return updated;
  }

  private async findOwnedApplication(
    candidateId: string,
    applicationId: string,
  ): Promise<ShiftApplication> {
    const { data, error } = await this.supabase.admin
      .from('shift_applications')
      .select(APPLICATION_COLUMNS)
      .eq('id', applicationId)
      .eq('candidate_id', candidateId)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to load shift application: ${error.message}`);
    }
    if (!data) {
      throw AppError.notFound(
        'SHIFT_APPLICATION_NOT_FOUND',
        'Shift application not found.',
      );
    }
    return data;
  }
}

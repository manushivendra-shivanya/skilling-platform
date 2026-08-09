import { randomInt } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AppError } from '../common/app-error';
import { SupabaseService } from '../supabase/supabase.service';

export interface EmployerShift {
  id: string;
  roleTitle: string;
  siteName: string;
  siteAddress: string;
  city: string;
  startsAt: string;
  endsAt: string;
  reportingTime: string | null;
  headcount: number;
  payAmount: string;
  payCurrency: string;
  requiredCompetencyIds: string[];
  description: string | null;
  supervisorName: string | null;
  supervisorContact: string | null;
  cancellationPolicy: string | null;
  checkInCode: string;
  status: string;
}

export interface EmployerShiftWithApplicationCount extends EmployerShift {
  applicationCount: number;
}

interface ShiftRow {
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
  check_in_code: string;
  status: string;
}

function toEmployerShift(row: ShiftRow): EmployerShift {
  return {
    id: row.id,
    roleTitle: row.role_title,
    siteName: row.site_name,
    siteAddress: row.site_address,
    city: row.city,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    reportingTime: row.reporting_time,
    headcount: row.headcount,
    payAmount: row.pay_amount,
    payCurrency: row.pay_currency,
    requiredCompetencyIds: row.required_competency_ids,
    description: row.description,
    supervisorName: row.supervisor_name,
    supervisorContact: row.supervisor_contact,
    cancellationPolicy: row.cancellation_policy,
    checkInCode: row.check_in_code,
    status: row.status,
  };
}

// Single unbroken literal, not `+`-concatenated -- see the identical
// comment in shifts.service.ts's SHIFT_COLUMNS for why.
const SHIFT_COLUMNS = 'id, role_title, site_name, site_address, city, starts_at, ends_at, reporting_time, headcount, pay_amount, pay_currency, required_competency_ids, description, supervisor_name, supervisor_contact, cancellation_policy, check_in_code, status';

/**
 * Direct employer shift posting, the shift-marketplace analog of
 * EmployerJobsService. No portal exists for this either -- same posture
 * Phase H established for `POST /employer/jobs`: this is a real API
 * surface, usable today via any HTTP client, with the admin UI (OD-6 in
 * the plan) deferred as its own later phase. Ownership scoping mirrors
 * `EmployerJobsService.findOwnedJob` exactly.
 */
@Injectable()
export class EmployerShiftsService {
  constructor(private readonly supabase: SupabaseService) {}

  async createDraft(
    employerId: string,
    input: {
      roleTitle: string;
      siteName: string;
      siteAddress: string;
      city: string;
      startsAt: string;
      endsAt: string;
      reportingTime: string | null;
      headcount: number;
      payAmount: number;
      requiredCompetencyIds: string[];
      description: string | null;
      supervisorName: string | null;
      supervisorContact: string | null;
      cancellationPolicy: string | null;
    },
  ): Promise<EmployerShift> {
    const { data, error } = await this.supabase.admin
      .from('shift_requests')
      .insert({
        employer_id: employerId,
        role_title: input.roleTitle,
        site_name: input.siteName,
        site_address: input.siteAddress,
        city: input.city,
        starts_at: input.startsAt,
        ends_at: input.endsAt,
        reporting_time: input.reportingTime,
        headcount: input.headcount,
        pay_amount: input.payAmount,
        required_competency_ids: input.requiredCompetencyIds,
        description: input.description,
        supervisor_name: input.supervisorName,
        supervisor_contact: input.supervisorContact,
        cancellation_policy: input.cancellationPolicy,
        check_in_code: generateCheckInCode(),
        status: 'draft',
      })
      .select(SHIFT_COLUMNS)
      .single();
    if (error) {
      throw new Error(`Failed to create shift: ${error.message}`);
    }
    return toEmployerShift(data);
  }

  async publish(employerId: string, shiftId: string): Promise<EmployerShift> {
    const shift = await this.findOwnedShift(employerId, shiftId);
    if (!shift) {
      throw AppError.notFound('SHIFT_NOT_FOUND', 'Shift not found.');
    }
    if (shift.status === 'cancelled' || shift.status === 'completed') {
      throw AppError.validation(`Cannot publish a ${shift.status} shift.`);
    }
    if (shift.status === 'published') {
      return toEmployerShift(shift);
    }

    const { data, error } = await this.supabase.admin
      .from('shift_requests')
      .update({ status: 'published' })
      .eq('id', shiftId)
      .eq('employer_id', employerId)
      .select(SHIFT_COLUMNS)
      .single();
    if (error) {
      throw new Error(`Failed to publish shift: ${error.message}`);
    }
    return toEmployerShift(data);
  }

  async listOwn(
    employerId: string,
  ): Promise<EmployerShiftWithApplicationCount[]> {
    const { data: shifts, error } = await this.supabase.admin
      .from('shift_requests')
      .select(SHIFT_COLUMNS)
      .eq('employer_id', employerId)
      .order('starts_at', { ascending: false });
    if (error) {
      throw new Error(`Failed to load shifts: ${error.message}`);
    }
    if (!shifts?.length) return [];

    const { data: applications, error: applicationsError } =
      await this.supabase.admin
        .from('shift_applications')
        .select('shift_id')
        .in(
          'shift_id',
          shifts.map((shift: ShiftRow) => shift.id),
        )
        .neq('status', 'cancelled');
    if (applicationsError) {
      throw new Error(
        `Failed to load application counts: ${applicationsError.message}`,
      );
    }

    const counts = new Map<string, number>();
    for (const row of (applications ?? []) as { shift_id: string }[]) {
      counts.set(row.shift_id, (counts.get(row.shift_id) ?? 0) + 1);
    }
    return shifts.map((shift: ShiftRow) => ({
      ...toEmployerShift(shift),
      applicationCount: counts.get(shift.id) ?? 0,
    }));
  }

  private async findOwnedShift(
    employerId: string,
    shiftId: string,
  ): Promise<ShiftRow | null> {
    const { data, error } = await this.supabase.admin
      .from('shift_requests')
      .select(SHIFT_COLUMNS)
      .eq('id', shiftId)
      .eq('employer_id', employerId)
      .maybeSingle();
    if (error) {
      throw new Error(`Failed to load shift: ${error.message}`);
    }
    return data;
  }
}

/** A short, easy-to-relay-verbally code -- no ambiguous characters. */
function generateCheckInCode(): string {
  return String(randomInt(100000, 999999));
}

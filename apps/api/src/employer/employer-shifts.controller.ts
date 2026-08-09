import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AppError } from '../common/app-error';
import { CurrentEmployer } from './current-employer.decorator';
import { EmployerAuthGuard } from './employer-auth.guard';
import { EmployerShiftsService } from './employer-shifts.service';

interface CreateShiftBody {
  roleTitle?: string;
  siteName?: string;
  siteAddress?: string;
  city?: string;
  startsAt?: string;
  endsAt?: string;
  reportingTime?: string;
  headcount?: number;
  payAmount?: number;
  requiredCompetencyIds?: string[];
  description?: string;
  supervisorName?: string;
  supervisorContact?: string;
  cancellationPolicy?: string;
}

/**
 * No global `ValidationPipe` is registered (see `main.ts`), same as
 * `EmployerJobsController` -- these manual checks are load-bearing.
 */
@Controller('employer/shifts')
@UseGuards(EmployerAuthGuard)
export class EmployerShiftsController {
  constructor(private readonly employerShifts: EmployerShiftsService) {}

  @Post()
  @HttpCode(201)
  async create(
    @CurrentEmployer() employerId: string,
    @Body() body: CreateShiftBody,
  ) {
    if (!body?.roleTitle?.trim()) {
      throw AppError.validation('roleTitle is required.');
    }
    if (!body.siteName?.trim()) {
      throw AppError.validation('siteName is required.');
    }
    if (!body.siteAddress?.trim()) {
      throw AppError.validation('siteAddress is required.');
    }
    if (!body.city?.trim()) {
      throw AppError.validation('city is required.');
    }
    if (!body.startsAt || Number.isNaN(Date.parse(body.startsAt))) {
      throw AppError.validation('startsAt must be a valid ISO date.');
    }
    if (!body.endsAt || Number.isNaN(Date.parse(body.endsAt))) {
      throw AppError.validation('endsAt must be a valid ISO date.');
    }
    if (!Number.isInteger(body.headcount) || (body.headcount ?? 0) <= 0) {
      throw AppError.validation('headcount must be a positive integer.');
    }
    if (typeof body.payAmount !== 'number' || body.payAmount < 0) {
      throw AppError.validation('payAmount must be a non-negative number.');
    }
    return {
      shift: await this.employerShifts.createDraft(employerId, {
        roleTitle: body.roleTitle,
        siteName: body.siteName,
        siteAddress: body.siteAddress,
        city: body.city,
        startsAt: body.startsAt,
        endsAt: body.endsAt,
        reportingTime: body.reportingTime ?? null,
        headcount: body.headcount as number,
        payAmount: body.payAmount,
        requiredCompetencyIds: body.requiredCompetencyIds ?? [],
        description: body.description ?? null,
        supervisorName: body.supervisorName ?? null,
        supervisorContact: body.supervisorContact ?? null,
        cancellationPolicy: body.cancellationPolicy ?? null,
      }),
    };
  }

  @Post(':id/publish')
  @HttpCode(200)
  async publish(
    @Param('id') id: string,
    @CurrentEmployer() employerId: string,
  ) {
    return { shift: await this.employerShifts.publish(employerId, id) };
  }

  @Get()
  async list(@CurrentEmployer() employerId: string) {
    return { shifts: await this.employerShifts.listOwn(employerId) };
  }
}

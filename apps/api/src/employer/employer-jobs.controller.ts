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
import { EmployerJobsService } from './employer-jobs.service';

interface CreateJobBody {
  title?: string;
  location?: string;
  description?: string;
  roleProfileId?: string;
}

/**
 * No global `ValidationPipe` is registered (see `main.ts`), so the manual
 * checks below are load-bearing, not decorative -- matches how the rest
 * of this API already handles request validation.
 */
@Controller('employer/jobs')
@UseGuards(EmployerAuthGuard)
export class EmployerJobsController {
  constructor(private readonly employerJobs: EmployerJobsService) {}

  @Post()
  @HttpCode(201)
  async create(
    @CurrentEmployer() employerId: string,
    @Body() body: CreateJobBody,
  ) {
    if (!body?.title?.trim()) {
      throw AppError.validation('title is required.');
    }
    if (!body.location?.trim()) {
      throw AppError.validation('location is required.');
    }
    if (!body.description?.trim()) {
      throw AppError.validation('description is required.');
    }
    return {
      job: await this.employerJobs.createDraft(employerId, {
        title: body.title,
        location: body.location,
        description: body.description,
        roleProfileId: body.roleProfileId ?? null,
      }),
    };
  }

  @Post(':id/publish')
  @HttpCode(200)
  async publish(
    @Param('id') id: string,
    @CurrentEmployer() employerId: string,
  ) {
    return { job: await this.employerJobs.publish(employerId, id) };
  }

  @Get()
  async list(@CurrentEmployer() employerId: string) {
    return { jobs: await this.employerJobs.listOwn(employerId) };
  }
}

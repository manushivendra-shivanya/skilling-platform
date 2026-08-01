import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { CurrentEmployer } from './current-employer.decorator';
import { EmployerAuthGuard } from './employer-auth.guard';
import { EmployerService } from './employer.service';

@Controller('employer')
@UseGuards(EmployerAuthGuard)
export class EmployerController {
  constructor(private readonly employer: EmployerService) {}

  @Get('applicants')
  async applicants(@CurrentEmployer() employerId: string) {
    return { applicants: await this.employer.listApplicants(employerId) };
  }

  @Get('applicants/:candidateId/evidence')
  async evidence(
    @Param('candidateId') candidateId: string,
    @CurrentEmployer() employerId: string,
  ) {
    return this.employer.reviewCandidateEvidence(employerId, candidateId);
  }
}

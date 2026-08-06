import { Module } from '@nestjs/common';
import { EmployerAuthGuard } from './employer-auth.guard';
import { EmployerController } from './employer.controller';
import { EmployerJobsController } from './employer-jobs.controller';
import { EmployerJobsService } from './employer-jobs.service';
import { EmployerService } from './employer.service';

@Module({
  controllers: [EmployerController, EmployerJobsController],
  providers: [EmployerService, EmployerJobsService, EmployerAuthGuard],
})
export class EmployerModule {}

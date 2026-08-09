import { Module } from '@nestjs/common';
import { EmployerAuthGuard } from './employer-auth.guard';
import { EmployerController } from './employer.controller';
import { EmployerJobsController } from './employer-jobs.controller';
import { EmployerJobsService } from './employer-jobs.service';
import { EmployerShiftsController } from './employer-shifts.controller';
import { EmployerShiftsService } from './employer-shifts.service';
import { EmployerService } from './employer.service';

@Module({
  controllers: [EmployerController, EmployerJobsController, EmployerShiftsController],
  providers: [
    EmployerService,
    EmployerJobsService,
    EmployerShiftsService,
    EmployerAuthGuard,
  ],
})
export class EmployerModule {}

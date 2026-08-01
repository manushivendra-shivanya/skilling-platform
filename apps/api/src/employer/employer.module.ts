import { Module } from '@nestjs/common';
import { EmployerAuthGuard } from './employer-auth.guard';
import { EmployerController } from './employer.controller';
import { EmployerService } from './employer.service';

@Module({
  controllers: [EmployerController],
  providers: [EmployerService, EmployerAuthGuard],
})
export class EmployerModule {}

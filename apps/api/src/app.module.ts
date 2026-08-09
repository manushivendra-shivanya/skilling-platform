import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { SupabaseModule } from './supabase/supabase.module';
import { CareerPassportModule } from './career-passport/career-passport.module';
import { DevModule } from './dev/dev.module';
import { EmployerModule } from './employer/employer.module';
import { JobSourcesModule } from './integrations/job-sources/job-sources.module';
import { JobsModule } from './jobs/jobs.module';
import { ShiftsModule } from './shifts/shifts.module';
import { WorkplaceSimulationModule } from './workplace-simulation/workplace-simulation.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    SupabaseModule,
    CareerPassportModule,
    DevModule,
    EmployerModule,
    JobSourcesModule,
    JobsModule,
    ShiftsModule,
    WorkplaceSimulationModule,
  ],
})
export class AppModule {}

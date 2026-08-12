import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthHooksModule } from './auth-hooks/auth-hooks.module';
import { SupabaseModule } from './supabase/supabase.module';
import { CareerPassportModule } from './career-passport/career-passport.module';
import { CoachModule } from './coach/coach.module';
import { DevModule } from './dev/dev.module';
import { EmployerModule } from './employer/employer.module';
import { HealthController } from './health/health.controller';
import { JobSourcesModule } from './integrations/job-sources/job-sources.module';
import { JobsModule } from './jobs/jobs.module';
import { ResumeModule } from './resume/resume.module';
import { ShiftsModule } from './shifts/shifts.module';
import { WorkplaceSimulationModule } from './workplace-simulation/workplace-simulation.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    AuthHooksModule,
    SupabaseModule,
    CareerPassportModule,
    CoachModule,
    DevModule,
    EmployerModule,
    JobSourcesModule,
    JobsModule,
    ResumeModule,
    ShiftsModule,
    WorkplaceSimulationModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}

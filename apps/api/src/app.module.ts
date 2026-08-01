import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { SupabaseModule } from './supabase/supabase.module';
import { EmployerModule } from './employer/employer.module';
import { JobsModule } from './jobs/jobs.module';
import { WorkplaceSimulationModule } from './workplace-simulation/workplace-simulation.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
    EmployerModule,
    JobsModule,
    WorkplaceSimulationModule,
  ],
})
export class AppModule {}

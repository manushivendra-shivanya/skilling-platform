import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { SupabaseModule } from './supabase/supabase.module';
import { JobsModule } from './jobs/jobs.module';
import { WorkplaceSimulationModule } from './workplace-simulation/workplace-simulation.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
    JobsModule,
    WorkplaceSimulationModule,
  ],
})
export class AppModule {}

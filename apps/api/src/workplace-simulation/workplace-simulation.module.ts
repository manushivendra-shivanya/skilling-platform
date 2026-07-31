import { Module } from '@nestjs/common';
import { WorkplaceSimulationController } from './workplace-simulation.controller';
import { WorkplaceSimulationService } from './workplace-simulation.service';

@Module({
  controllers: [WorkplaceSimulationController],
  providers: [WorkplaceSimulationService],
})
export class WorkplaceSimulationModule {}

import { Module } from '@nestjs/common';
import { JobSourcesModule } from '../integrations/job-sources/job-sources.module';
import { DevController } from './dev.controller';

@Module({
  imports: [JobSourcesModule],
  controllers: [DevController],
})
export class DevModule {}

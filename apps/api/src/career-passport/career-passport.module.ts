import { Module } from '@nestjs/common';
import { CareerPassportController } from './career-passport.controller';
import { CareerPassportService } from './career-passport.service';

@Module({
  controllers: [CareerPassportController],
  providers: [CareerPassportService],
})
export class CareerPassportModule {}

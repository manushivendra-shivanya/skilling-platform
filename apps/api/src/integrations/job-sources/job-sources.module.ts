import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AdzunaAdapter } from './adzuna.adapter';
import { CareerjetAdapter } from './careerjet.adapter';
import { GreenhouseAdapter } from './greenhouse.adapter';
import { HTTP_FETCHER, HttpFetcher } from './http-fetcher';
import { JobSourceAdapter } from './job-source-adapter';
import { JOB_SOURCE_ADAPTERS } from './job-source-adapters.token';
import { JobSyncScheduler } from './job-sync.scheduler';
import { JobSyncService } from './job-sync.service';
import { JoobleAdapter } from './jooble.adapter';
import { LeverAdapter } from './lever.adapter';
import {
  GREENHOUSE_BOARD_COMPANIES,
  LEVER_COMPANIES,
} from './named-companies.config';

/**
 * Wires each adapter's raw config (env vars, static company lists) into
 * its constructor via `useFactory`, so the adapter classes themselves stay
 * free of `ConfigService` and are trivially constructible in tests --
 * see each adapter's `.spec.ts` for the pattern this enables.
 */
@Module({
  providers: [
    {
      provide: HTTP_FETCHER,
      useValue: ((input, init) => fetch(input, init)) as HttpFetcher,
    },
    {
      provide: AdzunaAdapter,
      useFactory: (config: ConfigService, http: HttpFetcher) =>
        new AdzunaAdapter(
          config.get<string>('ADZUNA_APP_ID'),
          config.get<string>('ADZUNA_APP_KEY'),
          http,
        ),
      inject: [ConfigService, HTTP_FETCHER],
    },
    {
      provide: JoobleAdapter,
      useFactory: (config: ConfigService, http: HttpFetcher) =>
        new JoobleAdapter(config.get<string>('JOOBLE_API_KEY'), http),
      inject: [ConfigService, HTTP_FETCHER],
    },
    {
      provide: CareerjetAdapter,
      useFactory: (config: ConfigService, http: HttpFetcher) =>
        new CareerjetAdapter(config.get<string>('CAREERJET_API_KEY'), http),
      inject: [ConfigService, HTTP_FETCHER],
    },
    {
      provide: GreenhouseAdapter,
      useFactory: (http: HttpFetcher) =>
        new GreenhouseAdapter(GREENHOUSE_BOARD_COMPANIES, http),
      inject: [HTTP_FETCHER],
    },
    {
      provide: LeverAdapter,
      useFactory: (http: HttpFetcher) =>
        new LeverAdapter(LEVER_COMPANIES, http),
      inject: [HTTP_FETCHER],
    },
    {
      provide: JOB_SOURCE_ADAPTERS,
      useFactory: (
        adzuna: AdzunaAdapter,
        jooble: JoobleAdapter,
        careerjet: CareerjetAdapter,
        greenhouse: GreenhouseAdapter,
        lever: LeverAdapter,
      ): JobSourceAdapter[] => [adzuna, jooble, careerjet, greenhouse, lever],
      inject: [
        AdzunaAdapter,
        JoobleAdapter,
        CareerjetAdapter,
        GreenhouseAdapter,
        LeverAdapter,
      ],
    },
    JobSyncService,
    JobSyncScheduler,
  ],
  exports: [JobSyncService],
})
export class JobSourcesModule {}

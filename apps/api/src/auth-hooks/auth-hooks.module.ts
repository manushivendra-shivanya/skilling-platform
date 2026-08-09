import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Zavudev from '@zavudev/sdk';
import { SendSmsController } from './send-sms.controller';
import { ZAVUDEV_API_KEY, ZavudevService } from './zavudev.service';

@Module({
  controllers: [SendSmsController],
  providers: [
    {
      provide: Zavudev,
      useFactory: (config: ConfigService) =>
        // The Zavudev constructor throws synchronously if apiKey is
        // empty -- passing a placeholder here means a missing
        // ZAVUDEV_API_KEY can never take the whole app down at boot
        // (every other route would break too, not just this one),
        // matching this codebase's established "missing optional config
        // is a graceful no-op, not a hard failure" convention (see
        // job-sources.module.ts's adapters). ZavudevService checks the
        // real config value itself (via ZAVUDEV_API_KEY below) before
        // ever using this client, so a missing key still fails loudly,
        // just only for this one route, at request time instead of at
        // boot.
        new Zavudev({
          apiKey: config.get<string>('ZAVUDEV_API_KEY') || 'not-configured',
        }),
      inject: [ConfigService],
    },
    {
      provide: ZAVUDEV_API_KEY,
      useFactory: (config: ConfigService) =>
        config.get<string>('ZAVUDEV_API_KEY'),
      inject: [ConfigService],
    },
    ZavudevService,
  ],
})
export class AuthHooksModule {}

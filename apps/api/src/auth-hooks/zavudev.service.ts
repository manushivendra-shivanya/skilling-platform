import { Inject, Injectable } from '@nestjs/common';
import Zavudev from '@zavudev/sdk';

export const ZAVUDEV_API_KEY = Symbol('ZAVUDEV_API_KEY');

@Injectable()
export class ZavudevService {
  constructor(
    private readonly client: Zavudev,
    @Inject(ZAVUDEV_API_KEY) private readonly apiKey: string | undefined,
  ) {}

  /**
   * `channel: 'sms'`, always explicit, never omitted/`'auto'` -- this was
   * originally WhatsApp-with-SMS-fallback (free under the account's
   * monthly quota, vs. SMS billed per-message from the pay-as-you-go
   * balance), but the account only has an SMS sender connected today, not
   * a WhatsApp one (that needs a full Meta Business/WABA verification,
   * not a quick dashboard toggle). Sending via 'whatsapp' with zero
   * WhatsApp senders configured is not the same situation
   * `fallbackEnabled` covers (a specific recipient lacking WhatsApp) and
   * was likely to just fail outright. `to` here is always a phone number
   * (from Supabase's Send SMS hook payload), so there is no legitimate
   * case for auto-routing regardless. Revisit once a WhatsApp sender is
   * connected in Zavu.
   *
   * `idempotencyKey` is the Send SMS hook's own `webhook-id` header value
   * (the caller passes it through) -- Supabase, like most webhook
   * senders, can retry a hook delivery, and this prevents a retry from
   * sending the same OTP twice.
   */
  async sendOtpSms(params: {
    to: string;
    text: string;
    idempotencyKey: string;
  }): Promise<void> {
    if (!this.apiKey) {
      // The Zavudev client itself was constructed with a placeholder key
      // (see auth-hooks.module.ts) specifically so a missing key can't
      // crash the whole app at boot -- this check is where that deferred
      // failure actually surfaces, as a normal caught error the
      // controller turns into a 500, not an app-wide outage.
      throw new Error('ZAVUDEV_API_KEY is not configured.');
    }
    await this.client.messages.send({
      to: params.to,
      text: params.text,
      channel: 'sms',
      idempotencyKey: params.idempotencyKey,
    });
  }
}

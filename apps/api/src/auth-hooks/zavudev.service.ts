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
   * `channel: 'whatsapp'` with `fallbackEnabled: true` -- WhatsApp is
   * free under the account's monthly app-message quota, while SMS is
   * billed per-message from the pay-as-you-go credit balance, and
   * WhatsApp penetration is high for this app's audience. `fallbackEnabled`
   * (the SDK defaults this to true; set explicitly here so the choice is
   * visible, not implicit) means Zavu automatically retries via SMS if
   * the recipient has no WhatsApp or the WhatsApp send fails, so OTP
   * delivery never silently depends on WhatsApp alone. `channel` is
   * always explicit, never omitted/`'auto'` -- `to` here is always a
   * phone number (from Supabase's Send SMS hook payload), and being
   * explicit keeps this behavior an intentional choice rather than
   * whatever Zavu's auto-routing happens to decide.
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
      channel: 'whatsapp',
      fallbackEnabled: true,
      idempotencyKey: params.idempotencyKey,
    });
  }
}

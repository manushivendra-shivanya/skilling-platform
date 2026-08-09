import {
  Controller,
  Headers,
  Post,
  RawBodyRequest,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Webhook, WebhookVerificationError } from 'standardwebhooks';
import { ZavudevService } from './zavudev.service';

/**
 * Supabase's "Send SMS" Auth Hook -- fires whenever Supabase needs to
 * deliver a phone OTP (sign-in, sign-up, phone change). Configured in
 * Supabase Dashboard -> Authentication -> Auth Hooks -> Send SMS hook as
 * an HTTP hook pointed at this route.
 *
 * This is the entire trust boundary for sending real SMS on this
 * project's Zavu balance: every request must carry a valid Standard
 * Webhooks signature over the SEND_SMS_HOOK_SECRET Supabase generated
 * when the hook was created (see
 * https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook). A
 * request that fails verification never reaches ZavudevService --
 * nothing about `user`/`sms` in the body is trusted before that check
 * passes. The OTP itself is deliberately never logged (see
 * `_sendOtpSms`'s doc comment on ZavudevService for the message content).
 */
@Controller('auth-hooks')
export class SendSmsController {
  constructor(private readonly zavudev: ZavudevService) {}

  @Post('send-sms')
  async handle(
    @Req() request: RawBodyRequest<Request>,
    @Res() response: Response,
    @Headers('webhook-id') webhookId?: string,
    @Headers('webhook-timestamp') webhookTimestamp?: string,
    @Headers('webhook-signature') webhookSignature?: string,
  ): Promise<void> {
    const secret = process.env.SEND_SMS_HOOK_SECRET;
    if (!secret) {
      response
        .status(500)
        .json({
          error: {
            http_code: 500,
            message: 'Send SMS hook is not configured.',
          },
        });
      return;
    }
    if (!request.rawBody || !webhookId || !webhookTimestamp || !webhookSignature) {
      response
        .status(401)
        .json({ error: { http_code: 401, message: 'Missing signature.' } });
      return;
    }

    // Supabase's own example strips the `v1,whsec_` prefix before handing
    // the remaining base64 portion to the Webhook constructor -- see
    // https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook.
    const secretKey = secret.replace('v1,whsec_', '');

    let payload: unknown;
    try {
      payload = new Webhook(secretKey).verify(request.rawBody, {
        'webhook-id': webhookId,
        'webhook-timestamp': webhookTimestamp,
        'webhook-signature': webhookSignature,
      });
    } catch (error) {
      if (error instanceof WebhookVerificationError) {
        response
          .status(401)
          .json({
            error: { http_code: 401, message: 'Invalid signature.' },
          });
        return;
      }
      throw error;
    }

    const parsed = parseSendSmsPayload(payload);
    if (!parsed) {
      response
        .status(400)
        .json({
          error: { http_code: 400, message: 'Malformed hook payload.' },
        });
      return;
    }

    try {
      await this.zavudev.sendOtpSms({
        to: parsed.phone,
        text: `Your Saksham verification code is ${parsed.otp}. It expires shortly -- do not share this code with anyone.`,
        idempotencyKey: webhookId,
      });
    } catch (error) {
      response
        .status(500)
        .json({
          error: {
            http_code: 500,
            message:
              error instanceof Error
                ? error.message
                : 'Failed to send the verification SMS.',
          },
        });
      return;
    }

    response.status(200).json({});
  }
}

/**
 * Runtime-validates the verified payload before trusting it -- the
 * signature check above proves the request genuinely came from Supabase,
 * but `verify()` returns `unknown`, and defense in depth here is cheap:
 * a malformed `otp` (not exactly 6 digits, per Supabase's own documented
 * pattern) or missing phone number is rejected rather than forwarded to
 * Zavu as free-form text.
 */
function parseSendSmsPayload(
  payload: unknown,
): { phone: string; otp: string } | null {
  if (typeof payload !== 'object' || payload === null) return null;
  const body = payload as Record<string, unknown>;
  const user = body.user;
  const sms = body.sms;
  if (typeof user !== 'object' || user === null) return null;
  if (typeof sms !== 'object' || sms === null) return null;
  const phone = (user as Record<string, unknown>).phone;
  const otp = (sms as Record<string, unknown>).otp;
  if (typeof phone !== 'string' || phone.trim().length === 0) return null;
  if (typeof otp !== 'string' || !/^\d{6}$/.test(otp)) return null;
  return { phone, otp };
}

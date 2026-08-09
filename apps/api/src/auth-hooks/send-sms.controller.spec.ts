import type { RawBodyRequest } from '@nestjs/common';
import type { Request, Response } from 'express';
import { Webhook } from 'standardwebhooks';
import { SendSmsController } from './send-sms.controller';
import { ZavudevService } from './zavudev.service';

// Real Standard Webhooks secret shape Supabase's dashboard hands out:
// "v1,whsec_<base64>". Only the base64 portion is what the Webhook
// constructor actually wants -- see the controller's own comment on why
// it strips the "v1,whsec_" prefix itself.
const TEST_SECRET = 'v1,whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw';

function fakeResponse(): Response & {
  status: jest.Mock;
  json: jest.Mock;
} {
  const res = {} as Response & { status: jest.Mock; json: jest.Mock };
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

/**
 * Signs a real payload with the real library, exactly as Supabase would --
 * this test exercises the actual verification path end to end rather than
 * mocking `Webhook` (which would prove nothing about whether the
 * controller's header handling / secret stripping is actually correct).
 */
function signedRequest(payload: object): {
  request: RawBodyRequest<Request>;
  headers: { webhookId: string; webhookTimestamp: string; webhookSignature: string };
} {
  const rawBody = Buffer.from(JSON.stringify(payload));
  const wh = new Webhook(TEST_SECRET.replace('v1,whsec_', ''));
  const msgId = 'msg_test_123';
  const timestamp = new Date();
  const signature = wh.sign(msgId, timestamp, rawBody);
  return {
    request: { rawBody } as RawBodyRequest<Request>,
    headers: {
      webhookId: msgId,
      webhookTimestamp: String(Math.floor(timestamp.getTime() / 1000)),
      webhookSignature: signature,
    },
  };
}

const VALID_PAYLOAD = {
  user: { id: 'user-1', phone: '+911234567890' },
  sms: { otp: '123456' },
};

describe('SendSmsController', () => {
  let zavudev: { sendOtpSms: jest.Mock };
  let controller: SendSmsController;
  const originalSecret = process.env.SEND_SMS_HOOK_SECRET;

  beforeEach(() => {
    process.env.SEND_SMS_HOOK_SECRET = TEST_SECRET;
    zavudev = { sendOtpSms: jest.fn().mockResolvedValue(undefined) };
    controller = new SendSmsController(
      zavudev as unknown as ZavudevService,
    );
  });

  afterAll(() => {
    process.env.SEND_SMS_HOOK_SECRET = originalSecret;
  });

  it('sends the OTP and returns 200 for a genuinely valid signature', async () => {
    const { request, headers } = signedRequest(VALID_PAYLOAD);
    const response = fakeResponse();

    await controller.handle(
      request,
      response,
      headers.webhookId,
      headers.webhookTimestamp,
      headers.webhookSignature,
    );

    expect(zavudev.sendOtpSms).toHaveBeenCalledWith({
      to: '+911234567890',
      text: expect.stringContaining('123456'),
      idempotencyKey: headers.webhookId,
    });
    expect(response.status).toHaveBeenCalledWith(200);
    expect(response.json).toHaveBeenCalledWith({});
  });

  it('rejects a tampered payload -- signature was computed over different bytes', async () => {
    const { headers } = signedRequest(VALID_PAYLOAD);
    // Same headers/signature, but the raw body has been swapped after
    // signing -- exactly what an attacker replaying/modifying a request
    // would do.
    const tamperedRequest = {
      rawBody: Buffer.from(
        JSON.stringify({
          user: { id: 'user-1', phone: '+919999999999' },
          sms: { otp: '000000' },
        }),
      ),
    } as RawBodyRequest<Request>;
    const response = fakeResponse();

    await controller.handle(
      tamperedRequest,
      response,
      headers.webhookId,
      headers.webhookTimestamp,
      headers.webhookSignature,
    );

    expect(zavudev.sendOtpSms).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(401);
  });

  it('rejects a signature computed with the wrong secret', async () => {
    const rawBody = Buffer.from(JSON.stringify(VALID_PAYLOAD));
    const wrongWh = new Webhook('MfKQ9r8GKYqrTwjUPD8ILPZIo2LaDIFFERENT');
    const msgId = 'msg_test_456';
    const timestamp = new Date();
    const signature = wrongWh.sign(msgId, timestamp, rawBody);
    const response = fakeResponse();

    await controller.handle(
      { rawBody } as RawBodyRequest<Request>,
      response,
      msgId,
      String(Math.floor(timestamp.getTime() / 1000)),
      signature,
    );

    expect(zavudev.sendOtpSms).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(401);
  });

  it('rejects when headers are missing entirely', async () => {
    const { request } = signedRequest(VALID_PAYLOAD);
    const response = fakeResponse();

    await controller.handle(request, response, undefined, undefined, undefined);

    expect(zavudev.sendOtpSms).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(401);
  });

  it('rejects a well-signed but malformed payload (missing phone)', async () => {
    const { request, headers } = signedRequest({
      user: { id: 'user-1' },
      sms: { otp: '123456' },
    });
    const response = fakeResponse();

    await controller.handle(
      request,
      response,
      headers.webhookId,
      headers.webhookTimestamp,
      headers.webhookSignature,
    );

    expect(zavudev.sendOtpSms).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(400);
  });

  it('rejects a well-signed payload whose otp is not exactly 6 digits', async () => {
    const { request, headers } = signedRequest({
      user: { id: 'user-1', phone: '+911234567890' },
      sms: { otp: '12345' },
    });
    const response = fakeResponse();

    await controller.handle(
      request,
      response,
      headers.webhookId,
      headers.webhookTimestamp,
      headers.webhookSignature,
    );

    expect(zavudev.sendOtpSms).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(400);
  });

  it('returns 500 without ever calling Zavudev when the hook secret is not configured', async () => {
    delete process.env.SEND_SMS_HOOK_SECRET;
    const { request, headers } = signedRequest(VALID_PAYLOAD);
    const response = fakeResponse();

    await controller.handle(
      request,
      response,
      headers.webhookId,
      headers.webhookTimestamp,
      headers.webhookSignature,
    );

    expect(zavudev.sendOtpSms).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(500);
  });

  it('returns 500 when the send itself fails, after a valid verify', async () => {
    zavudev.sendOtpSms.mockRejectedValue(new Error('Zavu balance exhausted'));
    const { request, headers } = signedRequest(VALID_PAYLOAD);
    const response = fakeResponse();

    await controller.handle(
      request,
      response,
      headers.webhookId,
      headers.webhookTimestamp,
      headers.webhookSignature,
    );

    expect(response.status).toHaveBeenCalledWith(500);
  });
});

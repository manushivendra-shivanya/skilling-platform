import { ZavudevService } from './zavudev.service';

describe('ZavudevService', () => {
  it('always sends via SMS explicitly, never auto-routing', async () => {
    const send = jest.fn().mockResolvedValue({ message: { id: 'msg-1' } });
    const client = { messages: { send } };
    const service = new ZavudevService(client as never, 'real-api-key');

    await service.sendOtpSms({
      to: '+911234567890',
      text: 'Your code is 123456',
      idempotencyKey: 'webhook-id-1',
    });

    expect(send).toHaveBeenCalledWith({
      to: '+911234567890',
      text: 'Your code is 123456',
      channel: 'sms',
      idempotencyKey: 'webhook-id-1',
    });
  });

  it('propagates a send failure rather than swallowing it', async () => {
    const send = jest.fn().mockRejectedValue(new Error('rate limited'));
    const client = { messages: { send } };
    const service = new ZavudevService(client as never, 'real-api-key');

    await expect(
      service.sendOtpSms({
        to: '+911234567890',
        text: 'Your code is 123456',
        idempotencyKey: 'webhook-id-1',
      }),
    ).rejects.toThrow('rate limited');
  });

  it('fails clearly, without ever calling the client, when no key is configured', async () => {
    const send = jest.fn();
    const client = { messages: { send } };
    const service = new ZavudevService(client as never, undefined);

    await expect(
      service.sendOtpSms({
        to: '+911234567890',
        text: 'Your code is 123456',
        idempotencyKey: 'webhook-id-1',
      }),
    ).rejects.toThrow('ZAVUDEV_API_KEY is not configured.');
    expect(send).not.toHaveBeenCalled();
  });
});

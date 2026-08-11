import 'dart:async';

import 'package:candidate_mobile/core/storage/secure_key_value_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the Android-specific "stored value survived a device backup but
/// the AndroidKeystore key that encrypted it didn't" failure mode
/// (`javax.crypto.BadPaddingException: BAD_DECRYPT`, and the related
/// "the master key itself can no longer be unwrapped" variant), reproduced
/// directly via `flutter_secure_storage`'s real platform channel
/// (`plugins.it_nomads.com/flutter_secure_storage`) rather than a fake
/// [SecureKeyValueStore] -- the fix lives specifically in how
/// [FlutterSecureKeyValueStore] talks to that channel.
///
/// The plugin's Android implementation puts the actual Java exception text
/// in [PlatformException.details] (a String), not [PlatformException.message]
/// (which is just a constant like `"read"` describing which plugin call
/// failed) -- confirmed on-device by printing the real exception this
/// class exists to handle. Every case below reflects that real shape,
/// not a guessed one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Future<void> mockChannel(
    Future<Object?> Function(MethodCall call) handler,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() async {
    await mockChannel((_) async => null);
  });

  test(
    'a BadPaddingException on read is treated as "nothing stored", not an error',
    () async {
      final deletedKeys = <String>[];
      await mockChannel((call) async {
        switch (call.method) {
          case 'read':
            throw PlatformException(
              code: 'Exception encountered',
              message: 'read',
              details:
                  'javax.crypto.BadPaddingException: error:1e000065:Cipher '
                  'functions:OPENSSL_internal:BAD_DECRYPT\n\tat ...',
            );
          case 'delete':
            deletedKeys.add(call.arguments['key'] as String);
            return null;
          default:
            return null;
        }
      });
      final store = FlutterSecureKeyValueStore(
        storage: const FlutterSecureStorage(),
      );

      final value = await store.read('candidate.session');

      expect(value, isNull);
      expect(deletedKeys, ['candidate.session']);
    },
  );

  test('an unwrap-key failure (InvalidKeyException) is also treated as '
      '"nothing stored"', () async {
    await mockChannel((call) async {
      if (call.method == 'read') {
        throw PlatformException(
          code: 'Exception encountered',
          message: 'read',
          details:
              'java.security.InvalidKeyException: Failed to unwrap key\n'
              'Caused by: javax.crypto.IllegalBlockSizeException\n'
              'Caused by: android.security.KeyStoreException: Unknown '
              'error (internal Keystore code: -1000...',
        );
      }
      return null;
    });
    final store = FlutterSecureKeyValueStore(
      storage: const FlutterSecureStorage(),
    );

    final value = await store.read('candidate.session');

    expect(value, isNull);
  });

  test(
    'an AEADBadTagException on read is also treated as "nothing stored"',
    () async {
      await mockChannel((call) async {
        if (call.method == 'read') {
          throw PlatformException(
            code: 'Exception encountered',
            message: 'read',
            details: 'javax.crypto.AEADBadTagException: mac check failed',
          );
        }
        return null;
      });
      final store = FlutterSecureKeyValueStore(
        storage: const FlutterSecureStorage(),
      );

      final value = await store.read('candidate.session');

      expect(value, isNull);
    },
  );

  test(
    'cleanup still returns "nothing stored" even if the delete itself also fails',
    () async {
      // On a device where the AndroidKeystore master key itself is
      // unusable, delete() can fail the exact same way read() just did --
      // the entry can never be read again either way, so this should not
      // block startup.
      await mockChannel((call) async {
        if (call.method == 'read') {
          throw PlatformException(
            code: 'Exception encountered',
            message: 'read',
            details: 'javax.crypto.BadPaddingException: BAD_DECRYPT',
          );
        }
        if (call.method == 'delete') {
          throw PlatformException(code: 'delete-also-broken');
        }
        return null;
      });
      final store = FlutterSecureKeyValueStore(
        storage: const FlutterSecureStorage(),
      );

      final value = await store.read('candidate.session');

      expect(value, isNull);
    },
  );

  test('an unrelated PlatformException on read is not swallowed', () async {
    await mockChannel((call) async {
      if (call.method == 'read') {
        throw PlatformException(
          code: 'Exception encountered',
          message: 'read',
          details: 'Some unrelated platform failure',
        );
      }
      return null;
    });
    final store = FlutterSecureKeyValueStore(
      storage: const FlutterSecureStorage(),
    );

    await expectLater(
      store.read('candidate.session'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('a successful read is passed through unchanged', () async {
    await mockChannel((call) async {
      if (call.method == 'read') return 'stored-value';
      return null;
    });
    final store = FlutterSecureKeyValueStore(
      storage: const FlutterSecureStorage(),
    );

    expect(await store.read('candidate.session'), 'stored-value');
  });

  group('a stalled platform channel call (real-device report: stuck '
      'indefinitely on the splash screen after first Google sign-in, no '
      'error shown)', () {
    // Simulates the platform channel simply never responding -- not
    // throwing, which every case above already covers -- by handing back a
    // Future that never completes. Uses an injected short timeout so this
    // doesn't actually wait 12s (the production default) per test.
    const shortTimeout = Duration(milliseconds: 20);

    test('read times out instead of hanging forever', () async {
      await mockChannel((call) async {
        if (call.method == 'read') return Completer<Object?>().future;
        return null;
      });
      final store = FlutterSecureKeyValueStore(
        storage: const FlutterSecureStorage(),
        callTimeout: shortTimeout,
      );

      await expectLater(
        store.read('candidate.session'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('write times out instead of hanging forever', () async {
      await mockChannel((call) async {
        if (call.method == 'write') return Completer<Object?>().future;
        return null;
      });
      final store = FlutterSecureKeyValueStore(
        storage: const FlutterSecureStorage(),
        callTimeout: shortTimeout,
      );

      await expectLater(
        store.write('candidate.session', 'value'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('remove times out instead of hanging forever', () async {
      await mockChannel((call) async {
        if (call.method == 'delete') return Completer<Object?>().future;
        return null;
      });
      final store = FlutterSecureKeyValueStore(
        storage: const FlutterSecureStorage(),
        callTimeout: shortTimeout,
      );

      await expectLater(
        store.remove('candidate.session'),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}

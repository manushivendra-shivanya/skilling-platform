import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({
    FlutterSecureStorage? storage,
    Duration callTimeout = const Duration(seconds: 12),
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _callTimeout = callTimeout;

  final FlutterSecureStorage _storage;

  // Real-device report: app stuck indefinitely on the splash screen after
  // first Google sign-in, no error surfaced (a genuine hang, not a thrown
  // exception -- confirmed by ruling out every build-time-exception
  // candidate first). The AndroidKeystore-backed read this class wraps is
  // the exact call that gates AppStartupController.build() via
  // readSession() (see the BAD_DECRYPT handling below, which already
  // documents that dependency for a *different* failure mode -- a thrown
  // exception, not a stall). A first-time Keystore key provisioning can be
  // genuinely slow on a budget device, which this app explicitly targets,
  // but the plugin call itself has no built-in ceiling: if the platform
  // channel stalls rather than throwing, `await` waits forever with no
  // recovery path. 12s (the production default) is generous enough not to
  // false-positive on a slow but real provisioning, short enough that
  // "stuck" becomes "a retryable error" instead of "forever." Injectable
  // so tests can use a short timeout instead of actually waiting 12s.
  final Duration _callTimeout;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key).timeout(_callTimeout);
    } catch (error) {
      if (error is! PlatformException) rethrow;
      // flutter_secure_storage's Android implementation can end up with a
      // stored value it can no longer decrypt: the underlying
      // SharedPreferences file (unencrypted bytes) sometimes survives an
      // OEM app-data backup/restore (observed on Samsung devices, whose
      // own backup is more aggressive than stock Android's), while the
      // AndroidKeystore-backed AES key that encrypted it never does --
      // Keystore keys are hardware-bound and explicitly excluded from any
      // backup. The result is `javax.crypto.BadPaddingException:
      // BAD_DECRYPT` on every future read, which a plain uninstall alone
      // doesn't always clear if the OEM restores app data right back.
      // Treat this the same as "nothing was ever stored" -- delete the
      // now-unreadable entry so it self-heals instead of permanently
      // blocking app startup (this exact key gates
      // AppStartupController.build() via readSession()).
      if (_isUndecryptable(error)) {
        // Best-effort cleanup only -- on a device where the underlying
        // AndroidKeystore master key itself is unusable (not just this one
        // value), delete() can fail the exact same way read() just did.
        // Either way, the original entry can never be read again, so this
        // key already behaves as "nothing stored" going forward regardless
        // of whether the cleanup itself succeeds.
        try {
          await _storage.delete(key: key).timeout(_callTimeout);
        } catch (_) {
          // Swallowed deliberately -- see the comment above.
        }
        return null;
      }
      rethrow;
    }
  }

  bool _isUndecryptable(PlatformException error) {
    // The exception text itself lands in `details` (a String on Android's
    // implementation of this plugin, carrying the underlying Java
    // exception's toString() including its stack trace), not `message`
    // (which is just the constant "read"/"write"/etc. describing which
    // plugin call failed) -- confirmed by printing the real exception
    // this method exists to handle, on-device. Checking both anyway, in
    // case the plugin ever changes where it puts this text.
    final text = '${error.message ?? ''} ${error.details ?? ''}';
    return text.contains('BadPaddingException') ||
        text.contains('BAD_DECRYPT') ||
        text.contains('AEADBadTagException') ||
        text.contains('InvalidKeyException') ||
        text.contains('IllegalBlockSizeException');
  }

  @override
  Future<void> remove(String key) =>
      _storage.delete(key: key).timeout(_callTimeout);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value).timeout(_callTimeout);
  }
}

class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  InMemorySecureKeyValueStore([Map<String, String>? values])
    : _values = values ?? {};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

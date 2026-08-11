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

  // Real-device reproduction, distinct from the stall above: sign-in
  // completes, saveSession() writes the new session, the app immediately
  // navigates and the router's redirect immediately calls readSession()
  // again to decide where to go -- and *that* read comes back empty/stuck,
  // even though a full process kill and relaunch (a fresh read with
  // nothing else in flight) loads correctly. That's a read-immediately-
  // after-write gap on the platform channel, not the provisioning stall
  // _callTimeout guards against. A key containing a value the app itself
  // just wrote (or just confirmed absent, e.g. after delete/self-heal) is
  // present in this map -- read() answers from here instead of touching
  // the channel at all, so a same-process read can never race its own
  // preceding write. A key simply absent from the map means "unknown, ask
  // the platform" -- this is a cache of *this process's own writes*, not a
  // general-purpose cache, so there's nothing to invalidate: the store has
  // exactly one writer (this class), so nothing else can make it stale.
  final Map<String, String?> _writeThroughCache = {};

  @override
  Future<String?> read(String key) async {
    if (_writeThroughCache.containsKey(key)) {
      return _writeThroughCache[key];
    }
    try {
      final value = await _storage.read(key: key).timeout(_callTimeout);
      _writeThroughCache[key] = value;
      return value;
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
        _writeThroughCache[key] = null;
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
  Future<void> remove(String key) async {
    await _storage.delete(key: key).timeout(_callTimeout);
    _writeThroughCache[key] = null;
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value).timeout(_callTimeout);
    _writeThroughCache[key] = value;
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

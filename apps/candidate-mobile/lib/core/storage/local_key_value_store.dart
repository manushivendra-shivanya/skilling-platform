abstract interface class LocalKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// Test and development storage only. Sensitive data will use a secure storage
/// adapter when authentication is implemented.
class InMemoryLocalKeyValueStore implements LocalKeyValueStore {
  final Map<String, String> _values = {};

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

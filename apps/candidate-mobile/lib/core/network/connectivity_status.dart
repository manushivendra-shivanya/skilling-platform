import 'dart:async';

enum ConnectivityStatus { online, offline }

abstract interface class ConnectivityRepository {
  ConnectivityStatus get currentStatus;

  Stream<ConnectivityStatus> watchStatus();
}

/// A deterministic local adapter until a platform connectivity integration is
/// introduced. Screens can be tested against both online and offline states.
class MockConnectivityRepository implements ConnectivityRepository {
  MockConnectivityRepository({
    ConnectivityStatus initialStatus = ConnectivityStatus.online,
  }) : _currentStatus = initialStatus;

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _currentStatus;

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  void setStatus(ConnectivityStatus status) {
    if (_currentStatus == status) {
      return;
    }

    _currentStatus = status;
    _controller.add(status);
  }

  @override
  Stream<ConnectivityStatus> watchStatus() async* {
    yield _currentStatus;
    yield* _controller.stream;
  }

  void dispose() {
    _controller.close();
  }
}

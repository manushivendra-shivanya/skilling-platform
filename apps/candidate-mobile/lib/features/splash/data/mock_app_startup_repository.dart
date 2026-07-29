import '../../../core/errors/result.dart';
import '../domain/app_startup_repository.dart';
import '../domain/app_startup_state.dart';

class MockAppStartupRepository implements AppStartupRepository {
  MockAppStartupRepository({Result<AppStartupState>? response})
    : _response = response ?? const Success(AppStartupState());

  Result<AppStartupState> _response;

  @override
  Future<Result<AppStartupState>> initialize() async => _response;

  void setResponse(Result<AppStartupState> response) {
    _response = response;
  }
}

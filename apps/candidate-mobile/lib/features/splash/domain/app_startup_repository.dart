import '../../../core/errors/result.dart';
import 'app_startup_state.dart';

abstract interface class AppStartupRepository {
  Future<Result<AppStartupState>> initialize();
}

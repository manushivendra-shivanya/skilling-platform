import '../../../core/repositories/candidate_session_repository.dart';

class AppStartupState {
  const AppStartupState({this.isLowDataMode = false, this.session});

  final bool isLowDataMode;
  final CandidateSession? session;

  AppStartupState copyWith({CandidateSession? session}) {
    return AppStartupState(
      isLowDataMode: isLowDataMode,
      session: session ?? this.session,
    );
  }
}

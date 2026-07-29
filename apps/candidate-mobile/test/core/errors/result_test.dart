import 'package:candidate_mobile/core/errors/app_failure.dart';
import 'package:candidate_mobile/core/errors/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success exposes its value through when', () {
    const result = Success<String>('ready');

    final value = result.when(
      success: (value) => value,
      failure: (failure) => failure.message,
    );

    expect(value, 'ready');
  });

  test('failure exposes the typed failure through when', () {
    const result = ResultFailure<String>(NetworkFailure('No connection'));

    final value = result.when(
      success: (value) => value,
      failure: (failure) => failure.message,
    );

    expect(value, 'No connection');
  });
}

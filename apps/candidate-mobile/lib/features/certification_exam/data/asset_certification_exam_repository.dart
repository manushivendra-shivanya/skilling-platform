import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/certification_exam.dart';
import '../domain/certification_exam_repository.dart';
import '../domain/certification_exam_validator.dart';

class AssetCertificationExamRepository implements CertificationExamRepository {
  const AssetCertificationExamRepository({
    this.assetBundle,
    this.assetPath =
        'assets/certification_exam/warehouse_operations_exam_v1.json',
  });

  final AssetBundle? assetBundle;
  final String assetPath;

  AssetBundle get _effectiveBundle => assetBundle ?? rootBundle;

  @override
  Future<Result<CertificationExam>> loadExam() async {
    try {
      final raw = await _effectiveBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final exam = CertificationExam.fromJson(decoded);
      final errors = validateCertificationExam(exam);
      if (errors.isNotEmpty) {
        return ResultFailure(
          ValidationFailure(
            'Certification exam content is invalid: ${errors.join(', ')}',
          ),
        );
      }
      return Success(exam);
    } on FormatException catch (error, stackTrace) {
      return ResultFailure(
        ValidationFailure(
          'Certification exam content is invalid.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on Object catch (error, stackTrace) {
      return ResultFailure(
        StorageFailure(
          'Could not load the certification exam.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

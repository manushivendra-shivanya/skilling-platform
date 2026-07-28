import '../simulation_content.dart';
import '../simulation_runtime.dart';

class ScenarioGenerator {
  const ScenarioGenerator();

  GeneratedScenario generate(MissionDefinition mission, int seed) {
    final random = _StableRandom(seed ^ _stableHash(mission.versionedId));
    final resources = [
      for (final resource in mission.resources)
        resource.copyWith(issues: [...resource.issues]),
    ];
    final assignedTargets = <String>{};

    for (final rule in mission.scenario.variationRules) {
      if (rule.type != 'assign_issue') {
        throw FormatException('Unsupported variation rule: ${rule.type}');
      }
      if (rule.count < 1 || rule.count > rule.eligibleTargets.length) {
        throw FormatException('Invalid variation count for ${rule.issue}');
      }
      final targets = [
        ...rule.eligibleTargets.where(
          (target) => !assignedTargets.contains(target),
        ),
      ];
      if (targets.length < rule.count) {
        throw FormatException(
          'Variation ${rule.issue} cannot be assigned to a unique target',
        );
      }
      _shuffle(targets, random);
      for (final targetId in targets.take(rule.count)) {
        assignedTargets.add(targetId);
        final index = resources.indexWhere((item) => item.id == targetId);
        if (index < 0) {
          throw FormatException(
            'Variation ${rule.issue} references missing resource $targetId',
          );
        }
        final resource = resources[index];
        resources[index] = resource.copyWith(
          content: _applyIssue(resource.content, rule.issue),
          issues: [
            ...resource.issues.where((item) => item.issueType != rule.issue),
            ResourceIssue(issueType: rule.issue, severity: rule.severity),
          ],
        );
      }
    }

    _shuffle(resources, random);
    return GeneratedScenario(
      missionId: mission.id,
      missionVersion: mission.version,
      seed: seed,
      resources: resources,
    );
  }

  JsonMap _applyIssue(JsonMap content, String issue) {
    final next = {...content};
    switch (issue) {
      case 'packaging_damage':
        next['packagingStatus'] = 'damaged';
      case 'unreadable_barcode':
        next['barcodeStatus'] = 'unreadable';
      case 'incorrect_sku':
        next['expectedSku'] = content['sku'];
        next['sku'] = 'SKU-1094';
        next['productName'] = 'Unauthorized Multi Plug';
      case 'quantity_shortage':
        final quantity = content['quantity'];
        if (quantity is int) {
          next['quantity'] = (quantity - 2).clamp(0, quantity);
        }
      case 'near_expiry':
        next['expiryDate'] = '2026-09-15';
      default:
        break;
    }
    return next;
  }

  void _shuffle<T>(List<T> values, _StableRandom random) {
    for (var index = values.length - 1; index > 0; index--) {
      final replacement = random.nextInt(index + 1);
      final value = values[index];
      values[index] = values[replacement];
      values[replacement] = value;
    }
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _StableRandom {
  _StableRandom(int seed) : _state = seed & 0x7fffffff;

  int _state;

  int nextInt(int maximum) {
    if (maximum <= 0) throw ArgumentError.value(maximum, 'maximum');
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state % maximum;
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/simulation_content.dart';
import '../domain/simulation_repositories.dart';

class AssetSimulationContentRepository implements SimulationContentRepository {
  AssetSimulationContentRepository({
    AssetBundle? bundle,
    this.basePath = 'assets/workplace_simulation/logistics',
  }) : _bundle = bundle ?? rootBundle;

  static const supportedEngineVersion = '1.0.0';

  static const _missionFiles = {
    'receive-incoming-shipment-01': 'receive_shipment_mission.json',
    'put-away-incoming-stock-01': 'put_away_mission.json',
    'process-batch-01': 'processing_mission.json',
    'dispatch-orders-01': 'dispatch_mission.json',
  };

  final AssetBundle _bundle;
  final String basePath;

  SimulationPack? _pack;
  Workplace? _workplace;
  final Map<String, MissionDefinition> _missions = {};
  List<CompetencyDefinition>? _competencies;
  List<RemediationRecommendation>? _remediation;

  @override
  Future<SimulationPack> getPack(String packId) async {
    final pack = _pack ??= SimulationPack.fromJson(
      await _loadObject('pack.json'),
    );
    if (pack.id != packId) {
      throw StateError('Simulation pack "$packId" is unavailable');
    }
    if (_compareVersions(pack.minimumEngineVersion, supportedEngineVersion) >
        0) {
      throw StateError(
        'Pack requires engine ${pack.minimumEngineVersion}, '
        'but this app supports $supportedEngineVersion',
      );
    }
    return pack;
  }

  @override
  Future<Workplace> getWorkplace(String workplaceId) async {
    final workplace = _workplace ??= Workplace.fromJson(
      await _loadObject('workplace.json'),
    );
    if (workplace.id != workplaceId) {
      throw StateError('Workplace "$workplaceId" is unavailable');
    }
    await getPack(workplace.packId);
    return workplace;
  }

  @override
  Future<MissionDefinition> getMission(String missionId) async {
    final cached = _missions[missionId];
    if (cached != null) return cached;
    final fileName = _missionFiles[missionId];
    if (fileName == null) {
      throw StateError('Mission "$missionId" is unavailable');
    }
    final mission = MissionDefinition.fromJson(await _loadObject(fileName));
    if (mission.id != missionId) {
      throw StateError('Mission "$missionId" is unavailable');
    }
    _missions[missionId] = mission;
    final workplace = await getWorkplace(mission.workplaceId);
    if (mission.packId != workplace.packId ||
        workplace.departmentIds.contains(mission.departmentId) == false ||
        workplace.workstations.every(
          (item) => item.id != mission.startingWorkstationId,
        )) {
      throw const FormatException(
        'Mission references invalid pack, department, or workstation content',
      );
    }
    final competencies = await getCompetencies(
      mission.role.requiredCompetencies,
    );
    if (competencies.length != mission.role.requiredCompetencies.length) {
      throw const FormatException(
        'Mission role references an undefined competency',
      );
    }
    return mission;
  }

  @override
  Future<List<CompetencyDefinition>> getCompetencies(
    List<String> competencyIds,
  ) async {
    final competencies = _competencies ??= (await _loadList(
      'competencies.json',
    )).map(CompetencyDefinition.fromJson).toList(growable: false);
    final requested = competencies
        .where((item) => competencyIds.contains(item.id))
        .toList(growable: false);
    if (requested.length != competencyIds.toSet().length) {
      throw StateError('One or more competencies are unavailable');
    }
    return requested;
  }

  @override
  Future<List<RemediationRecommendation>> getRemediation() async =>
      _remediation ??= (await _loadList(
        'remediation.json',
      )).map(RemediationRecommendation.fromJson).toList(growable: false);

  Future<JsonMap> _loadObject(String fileName) async {
    final decoded = jsonDecode(await _bundle.loadString('$basePath/$fileName'));
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$fileName must contain a JSON object');
    }
    return decoded;
  }

  Future<List<JsonMap>> _loadList(String fileName) async {
    final decoded = jsonDecode(await _bundle.loadString('$basePath/$fileName'));
    if (decoded is! List<Object?>) {
      throw FormatException('$fileName must contain a JSON array');
    }
    return decoded
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw FormatException('$fileName must contain only JSON objects');
          }
          return item;
        })
        .toList(growable: false);
  }

  int _compareVersions(String left, String right) {
    final leftParts = left.split('.').map(int.parse).toList();
    final rightParts = right.split('.').map(int.parse).toList();
    for (var index = 0; index < 3; index++) {
      final difference = leftParts[index] - rightParts[index];
      if (difference != 0) return difference;
    }
    return 0;
  }
}

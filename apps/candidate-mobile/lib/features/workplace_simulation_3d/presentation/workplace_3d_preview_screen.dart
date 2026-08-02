import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../workplace_simulation/application/workplace_simulation_controller.dart';
import '../../workplace_simulation/application/workplace_interaction_contracts.dart';
import '../../workplace_simulation/domain/simulation_enums.dart';
import '../../workplace_simulation/domain/workplace_task_drafts.dart';

/// Foundation proof-of-concept for a 3D workstation view (WMS 3D bridge,
/// task #12): loads a self-contained Babylon.js scene bundled as a Flutter
/// asset and renders it in a WebView. Deliberately dev-tools-only and not
/// reachable from the real practice flow -- this proves the render path
/// works, nothing more.
///
/// Task #13/#14: a `FloraNative` JavaScriptChannel carries carton-click
/// messages from the scene to [WorkplaceSimulationController], which
/// records a real carton inspection against the real
/// `receive-incoming-shipment-01` mission (creating and starting an
/// attempt on demand). The result is posted back into the WebView via
/// `window.onFloraAck`, proving a genuine round trip rather than a
/// one-way notification.
///
/// Known limitation, not yet resolved: the bundled HTML loads Babylon.js
/// itself from a CDN script tag (`cdn.babylonjs.com`), so this screen
/// requires network access at runtime. Vendoring the Babylon.js bundle as
/// a local asset instead is a follow-up hardening step, not required to
/// prove the WebView render path itself.
class Workplace3dPreviewScreen extends ConsumerStatefulWidget {
  const Workplace3dPreviewScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  ConsumerState<Workplace3dPreviewScreen> createState() =>
      _Workplace3dPreviewScreenState();
}

class _Workplace3dPreviewScreenState
    extends ConsumerState<Workplace3dPreviewScreen> {
  static const _missionId = WorkplaceSimulationController.missionId;

  late final WebViewController _controller;
  bool _loading = true;
  String? _loadError;
  String? _lastBridgeStatus;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0d0d10))
      ..addJavaScriptChannel(
        'FloraNative',
        onMessageReceived: _handleCartonPickedMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) => setState(() {
            _loading = false;
            _loadError = '${error.errorCode}: ${error.description}';
          }),
        ),
      )
      ..loadFlutterAsset('assets/wms_3d/inspection_zone_poc.html');
  }

  void _handleCartonPickedMessage(JavaScriptMessage message) {
    // The scene posts a JSON string, not a structured object -- WebView
    // JavaScriptChannel messages are always plain strings on both
    // platforms.
    final decoded = jsonDecode(message.message) as Map<String, dynamic>;
    final cartonId = decoded['cartonId'] as String;
    final issue = decoded['issue'] as String?;
    unawaited(_recordCartonClick(cartonId: cartonId, issue: issue));
  }

  Future<void> _recordCartonClick({
    required String cartonId,
    required String? issue,
  }) async {
    final notifier = ref.read(
      workplaceSimulationControllerProvider(_missionId).notifier,
    );
    final ensured = await _ensureActiveAttempt(notifier);
    if (!ensured) {
      await _ackToScene(
        cartonId: cartonId,
        success: false,
        result: 'noAttempt',
      );
      return;
    }
    final finding = CartonFinding.fromWireName(issue ?? 'compliant');
    final result = await notifier.recordCartonInspection(
      RecordCartonInspectionCommand(cartonId: cartonId, findings: [finding]),
    );
    await _ackToScene(
      cartonId: cartonId,
      success:
          result == RecordCartonInspectionResult.success ||
          result == RecordCartonInspectionResult.duplicateEntry,
      result: result.name,
    );
  }

  /// Drives the real attempt state machine (notStarted -> briefing ->
  /// inProgress) up to the point where [WorkplaceSimulationController]
  /// accepts scoreable actions. Returns false only if the controller
  /// rejects a step the dev-preview screen doesn't expect (e.g. content
  /// genuinely missing), which the caller surfaces via the ack channel
  /// rather than throwing.
  Future<bool> _ensureActiveAttempt(
    WorkplaceSimulationController notifier,
  ) async {
    var attempt = ref
        .read(workplaceSimulationControllerProvider(_missionId))
        .valueOrNull
        ?.attempt;
    if (attempt == null ||
        attempt.state == MissionState.completed ||
        attempt.state == MissionState.failed) {
      final failure = await notifier.startMission();
      if (failure != null) return false;
      attempt = ref
          .read(workplaceSimulationControllerProvider(_missionId))
          .valueOrNull
          ?.attempt;
    }
    if (attempt?.state == MissionState.briefing) {
      await notifier.setBriefingAcknowledged(true);
      final beginResult = await notifier.beginShift();
      if (beginResult != BeginShiftResult.success) return false;
    } else if (attempt?.state == MissionState.paused) {
      await notifier.continueMission();
    }
    return ref
            .read(workplaceSimulationControllerProvider(_missionId))
            .valueOrNull
            ?.attempt
            ?.state ==
        MissionState.inProgress;
  }

  Future<void> _ackToScene({
    required String cartonId,
    required bool success,
    required String result,
  }) async {
    if (!mounted) return;
    setState(() => _lastBridgeStatus = '$cartonId -> $result');
    final payload = jsonEncode({
      'cartonId': cartonId,
      'success': success,
      'result': result,
    });
    await _controller.runJavaScript('window.onFloraAck($payload)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('WMS 3D preview (dev only)'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_loadError != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Scene failed to load: $_loadError',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          if (_lastBridgeStatus != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Material(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'Bridge: $_lastBridgeStatus',
                    key: const Key('wmsBridgeStatus'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

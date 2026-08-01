import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Foundation proof-of-concept for a 3D workstation view (WMS 3D bridge,
/// task #12): loads a self-contained Babylon.js scene bundled as a Flutter
/// asset and renders it in a WebView. Deliberately dev-tools-only and not
/// reachable from the real practice flow -- this proves the render path
/// works, nothing more. Wiring a click in the scene to a real
/// `WorkplaceSimulationController` action is a later, separate step.
///
/// Known limitation, not yet resolved: the bundled HTML loads Babylon.js
/// itself from a CDN script tag (`cdn.babylonjs.com`), so this screen
/// requires network access at runtime. Vendoring the Babylon.js bundle as
/// a local asset instead is a follow-up hardening step, not required to
/// prove the WebView render path itself.
class Workplace3dPreviewScreen extends StatefulWidget {
  const Workplace3dPreviewScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<Workplace3dPreviewScreen> createState() =>
      _Workplace3dPreviewScreenState();
}

class _Workplace3dPreviewScreenState extends State<Workplace3dPreviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0d0d10))
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
        ],
      ),
    );
  }
}

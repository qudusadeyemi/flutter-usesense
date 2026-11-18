import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

/// Silent device check (Your KYC) demo.
///
/// In a real app your server calls `POST /v1/device-checks` with its API key
/// and hands the three values below to the app. Here you paste them (for
/// example from a curl on your machine), then run start and finish.
///
/// For automated device tests the screen also reads them from the launch
/// environment (`USESENSE_DC_ID`, `USESENSE_DC_TOKEN`, `USESENSE_DC_NONCE`,
/// optional `USESENSE_DC_BASE_URL`) and runs start then finish on its own.
class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key, this.autorun = false});

  final bool autorun;

  /// Launch values: the process environment, or `--dart-define` (for
  /// `flutter run`, which cannot pass an environment to the app).
  static String launchValue(String key) {
    final fromEnv = Platform.environment[key] ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    switch (key) {
      case 'USESENSE_DC_ID':
        return const String.fromEnvironment('USESENSE_DC_ID');
      case 'USESENSE_DC_TOKEN':
        return const String.fromEnvironment('USESENSE_DC_TOKEN');
      case 'USESENSE_DC_NONCE':
        return const String.fromEnvironment('USESENSE_DC_NONCE');
      case 'USESENSE_DC_BASE_URL':
        return const String.fromEnvironment('USESENSE_DC_BASE_URL');
    }
    return '';
  }

  /// True when the launch carries a device check to run.
  static bool get hasLaunchCheck =>
      launchValue('USESENSE_DC_ID').isNotEmpty &&
      launchValue('USESENSE_DC_TOKEN').isNotEmpty &&
      launchValue('USESENSE_DC_NONCE').isNotEmpty;

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  final _baseUrl = TextEditingController(text: 'https://api.usesense.ai');
  final _id = TextEditingController();
  final _token = TextEditingController();
  final _nonce = TextEditingController();
  final _log = <String>[];
  UseSenseDeviceCheck? _check;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _id.text = DeviceCheckScreen.launchValue('USESENSE_DC_ID');
    _token.text = DeviceCheckScreen.launchValue('USESENSE_DC_TOKEN');
    _nonce.text = DeviceCheckScreen.launchValue('USESENSE_DC_NONCE');
    final base = DeviceCheckScreen.launchValue('USESENSE_DC_BASE_URL');
    if (base.isNotEmpty) _baseUrl.text = base;
    if (widget.autorun) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _run(start: true);
        await _run(start: false);
      });
    }
  }

  @override
  void dispose() {
    _check?.dispose();
    for (final c in [_baseUrl, _id, _token, _nonce]) {
      c.dispose();
    }
    super.dispose();
  }

  UseSenseDeviceCheck _current() => _check ??= UseSenseDeviceCheck(
        deviceCheckId: _id.text.trim(),
        token: _token.text.trim(),
        nonce: _nonce.text.trim(),
        apiBaseUrl: _baseUrl.text.trim(),
      );

  Future<void> _run({required bool start}) async {
    setState(() => _busy = true);
    final check = _current();
    final r = start ? await check.start() : await check.finish();
    final line = r.ok
        ? '${r.phase.name}: received'
        : '${r.phase.name}: ${r.error!.code.name} (${r.error!.message})';
    // Visible in the device console, for automated runs.
    debugPrint('USESENSE_DEVICE_CHECK ${check.deviceCheckId} $line');
    if (!mounted) return;
    setState(() {
      _log.insert(0, line);
      _busy = false;
    });
  }

  void _reset() {
    _check?.dispose();
    setState(() {
      _check = null;
      _log.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: c,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Silent device check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Your server creates the check (POST /v1/device-checks) and '
            'passes these to the app. No UI, camera or permission prompt.',
          ),
          const SizedBox(height: 12),
          field(_baseUrl, 'API base URL', 'https://api.usesense.ai'),
          field(_id, 'Device check id', 'dc_...'),
          field(_token, 'Token', 'dct_...'),
          field(_nonce, 'Nonce', 'dn_...'),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _run(start: true),
                  child: const Text('Start'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _busy ? null : () => _run(start: false),
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
          TextButton(onPressed: _reset, child: const Text('New check')),
          const Divider(),
          for (final line in _log)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(line, key: ValueKey(line)),
            ),
        ],
      ),
    );
  }
}

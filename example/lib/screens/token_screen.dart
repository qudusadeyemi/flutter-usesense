import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

import 'embedded_capture_screen.dart';
import 'result_screen.dart';

/// Client tokens (J1) and the embedded capture (J2).
///
/// In production your server calls `POST /v1/sessions/create-token` with its
/// secret key and gives the app only the single-use `client_token`. To test
/// end to end without a server, this screen can mint one with the API key you
/// typed on the home screen ("Mint with my API key"), or you can paste a
/// token your server created.
class TokenScreen extends StatefulWidget {
  const TokenScreen({
    super.key,
    required this.useSense,
    required this.apiKey,
    required this.useProduction,
    required this.ensureInitialized,
  });

  final UseSenseFlutter useSense;
  final String apiKey;
  final bool useProduction;

  /// Initializes the SDK with the home screen's key (for the API key
  /// embedded demo). Returns false when there is no key or it failed.
  final Future<bool> Function() ensureInitialized;

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  static const _apiBase = 'https://api.usesense.ai';

  final _tokenController = TextEditingController();
  final _identityIdController = TextEditingController();
  SessionType _sessionType = SessionType.enrollment;
  bool _busy = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _identityIdController.dispose();
    super.dispose();
  }

  /// Demo only: what your server does. Never ship a secret key in an app.
  Future<String> _mintToken() async {
    if (widget.apiKey.isEmpty) {
      throw 'Enter your API key on the home screen, or paste a client token.';
    }
    final identityId = _identityIdController.text.trim();
    final client = HttpClient();
    try {
      final req =
          await client.postUrl(Uri.parse('$_apiBase/v1/sessions/create-token'));
      req.headers.set('content-type', 'application/json');
      req.headers.set('x-api-key', widget.apiKey);
      req.headers.set(
          'x-environment', widget.useProduction ? 'production' : 'sandbox');
      req.add(utf8.encode(jsonEncode({
        'session_type': _sessionType.name,
        if (_sessionType == SessionType.authentication)
          'identity_id': identityId,
        'external_user_id': 'flutter-demo-user',
        'platform': Platform.isIOS ? 'ios' : 'android',
      })));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw 'create-token failed (HTTP ${resp.statusCode}): $body';
      }
      final token = (jsonDecode(body) as Map<String, dynamic>)['client_token'];
      if (token is! String || token.isEmpty) throw 'No client_token returned.';
      return token;
    } finally {
      client.close();
    }
  }

  /// The pasted token, else a freshly minted one. Tokens are single use, so
  /// a pasted one is cleared once it has been handed to the SDK.
  Future<String?> _token() async {
    final pasted = _tokenController.text.trim();
    if (pasted.isNotEmpty) {
      _tokenController.clear();
      return pasted;
    }
    try {
      return await _mintToken();
    } catch (e) {
      _show('$e');
      return null;
    }
  }

  Future<void> _fullScreen() async {
    setState(() => _busy = true);
    try {
      final token = await _token();
      if (token == null) return;
      final result = await widget.useSense.startVerificationWithToken(
        clientToken: token,
        sessionType: _sessionType,
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
        );
      }
    } on UseSenseError catch (e) {
      if (e.code == UseSenseError.sessionCancelled) return;
      _show(e.code == UseSenseError.invalidClientToken
          ? 'Token rejected (${e.serverCode}). Tokens are single use: '
              'get a new one.'
          : 'Verification failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _embeddedWithToken() async {
    setState(() => _busy = true);
    final token = await _token();
    if (mounted) setState(() => _busy = false);
    if (token == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmbeddedCaptureScreen.token(
          clientToken: token,
          sessionType: _sessionType,
        ),
      ),
    );
  }

  Future<void> _embeddedWithApiKey() async {
    if (!await widget.ensureInitialized()) {
      _show('Enter your API key on the home screen first.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmbeddedCaptureScreen.request(
          request: VerificationRequest(
            sessionType: _sessionType,
            identityId: _sessionType == SessionType.authentication
                ? _identityIdController.text.trim()
                : null,
          ),
        ),
      ),
    );
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Client token and embedded')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your server calls POST /v1/sessions/create-token and gives the '
            'app a single-use client token, so the API key never ships in '
            'the app. Leave the field empty to mint one here with the key '
            'from the home screen (demo only).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<SessionType>(
            segments: const [
              ButtonSegment(
                  value: SessionType.enrollment, label: Text('Enrol')),
              ButtonSegment(
                value: SessionType.authentication,
                label: Text('Auth'),
              ),
              ButtonSegment(
                  value: SessionType.liveness, label: Text('Liveness')),
            ],
            selected: {_sessionType},
            onSelectionChanged: (s) => setState(() => _sessionType = s.first),
          ),
          if (_sessionType == SessionType.authentication) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _identityIdController,
              decoration: const InputDecoration(
                labelText: 'Identity ID',
                hintText: 'idn_...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Client token (optional)',
              hintText: 'Paste one from your server',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _fullScreen,
            icon: const Icon(Icons.key_off),
            label: const Text('Full screen with a client token'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _embeddedWithToken,
            icon: const Icon(Icons.picture_in_picture),
            label: const Text('Embedded with a client token'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _embeddedWithApiKey,
            icon: const Icon(Icons.picture_in_picture_alt),
            label: const Text('Embedded with the API key'),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

import '../widgets/event_tile.dart';
import 'result_screen.dart';

// Keys for shared_preferences persistence. Match the semantics of iOS's
// @AppStorage("apiKey") and Android's SharedPreferences("api_key").
const _kPrefsApiKey = 'api_key';
const _kPrefsUseProduction = 'use_production';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.useSense});

  final UseSenseFlutter useSense;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiKeyController = TextEditingController();
  final _identityIdController = TextEditingController();
  final _events = <UseSenseEvent>[];

  bool _apiKeyVisible = false;
  bool _useProduction = false;
  bool _loading = false;

  // Tracks whether the SDK has been initialized for the current API
  // key value. If the user changes the key, we re-initialize on next
  // tap so the new key takes effect.
  String? _initializedForKey;

  StreamSubscription<UseSenseEvent>? _eventSub;
  StreamSubscription<void>? _cancelledSub;

  @override
  void initState() {
    super.initState();
    _restorePersistedState();
    _eventSub = widget.useSense.onEvent.listen(_onEvent);
    _cancelledSub = widget.useSense.onCancelled.listen((_) {
      _addSyntheticEvent('Session cancelled by user');
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _cancelledSub?.cancel();
    _apiKeyController.dispose();
    _identityIdController.dispose();
    super.dispose();
  }

  Future<void> _restorePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = prefs.getString(_kPrefsApiKey) ?? '';
      _useProduction = prefs.getBool(_kPrefsUseProduction) ?? false;
    });
  }

  Future<void> _persistApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsApiKey, key);
  }

  Future<void> _persistUseProduction(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefsUseProduction, value);
  }

  /// Ensures the SDK is initialized with the currently-entered key.
  /// Returns `true` if the SDK is ready to start a session, `false`
  /// if the key is empty or initialization failed.
  Future<bool> _ensureInitialized() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return false;
    if (_initializedForKey == key) return true;

    try {
      // Re-initialize with the (possibly new) key. The native plugin
      // handles re-initialization as a reset + re-init internally, so
      // we don't need to call reset() explicitly.
      await widget.useSense.initialize(
        UseSenseConfig(
          apiKey: key,
          environment: _useProduction
              ? UseSenseEnvironment.production
              : UseSenseEnvironment.sandbox,
        ),
      );
      _initializedForKey = key;
      return true;
    } on UseSenseError catch (e) {
      if (mounted) _showError(e);
      return false;
    }
  }

  void _onEvent(UseSenseEvent event) {
    setState(() {
      _events.insert(0, event);
      if (_events.length > 100) _events.removeLast();
    });
  }

  void _addSyntheticEvent(String message) {
    setState(() {
      _events.insert(
        0,
        UseSenseEvent(
          type: UseSenseEventType.error,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          data: {'message': message},
        ),
      );
    });
  }

  Future<void> _startEnrollment() async {
    if (!await _ensureInitialized()) return;
    setState(() => _loading = true);
    try {
      final result = await widget.useSense.startVerification(
        const VerificationRequest(sessionType: SessionType.enrollment),
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
        );
      }
    } on UseSenseError catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startAuthentication() async {
    final identityId = _identityIdController.text.trim();
    if (identityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an identity ID to authenticate.')),
      );
      return;
    }
    if (!await _ensureInitialized()) return;
    setState(() => _loading = true);
    try {
      final result = await widget.useSense.startVerification(
        VerificationRequest(
          sessionType: SessionType.authentication,
          identityId: identityId,
        ),
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
        );
      }
    } on UseSenseError catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(UseSenseError error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verification Failed'),
        content: Text('${error.message}\n\nCode: ${error.code}'),
        actions: [
          if (error.isRetryable)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = _apiKeyController.text.trim().isNotEmpty;
    final canInteract = hasKey && !_loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UseSense Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset SDK',
            onPressed: () async {
              await widget.useSense.reset();
              _initializedForKey = null;
              setState(() => _events.clear());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API key input. Persisted via shared_preferences so the
            // user only has to paste it once per install. Masked by
            // default; tap the eye icon to reveal.
            TextField(
              controller: _apiKeyController,
              obscureText: !_apiKeyVisible,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (value) {
                setState(() {
                  // If the key changed, force a re-init on next tap.
                  if (_initializedForKey != value.trim()) {
                    _initializedForKey = null;
                  }
                });
                _persistApiKey(value.trim());
              },
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Paste your sandbox or production key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _apiKeyVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _apiKeyVisible = !_apiKeyVisible),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Environment toggle.
            SwitchListTile(
              title: const Text('Production'),
              subtitle: Text(
                _useProduction
                    ? 'Using production environment'
                    : 'Using sandbox environment',
                style: theme.textTheme.bodySmall,
              ),
              value: _useProduction,
              onChanged: (value) {
                setState(() {
                  _useProduction = value;
                  // Force re-init so the new environment is picked up.
                  _initializedForKey = null;
                });
                _persistUseProduction(value);
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (!hasKey)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Enter your API key from watchtower.usesense.ai',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Enroll button.
            FilledButton.icon(
              onPressed: canInteract ? _startEnrollment : null,
              icon: const Icon(Icons.person_add),
              label: const Text('Enroll New Identity'),
            ),
            const SizedBox(height: 12),

            // Identity ID field + Authenticate button.
            TextField(
              controller: _identityIdController,
              decoration: const InputDecoration(
                labelText: 'Identity ID (for authentication)',
                hintText: 'idn_...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: canInteract ? _startAuthentication : null,
              child: const Text('Authenticate'),
            ),
            const SizedBox(height: 16),

            // Event log. Uses a bounded SizedBox inside the scrolling
            // Column so events are visible alongside the config fields
            // on smaller screens.
            Text('Event Log', style: theme.textTheme.titleSmall),
            const Divider(),
            SizedBox(
              height: 280,
              child: _events.isEmpty
                  ? Center(
                      child: Text(
                        _loading
                            ? 'Session in progress…'
                            : 'Events will appear here during a session.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (_, i) => EventTile(event: _events[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

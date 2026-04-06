import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

import '../main.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final UseSenseResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color decisionColor;
    final IconData decisionIcon;
    final String decisionLabel;

    if (result.isApproved) {
      decisionColor = UseSenseColors.green5;
      decisionIcon = Icons.check_circle;
      decisionLabel = 'Approved';
    } else if (result.isRejected) {
      decisionColor = UseSenseColors.red5;
      decisionIcon = Icons.cancel;
      decisionLabel = 'Rejected';
    } else {
      decisionColor = UseSenseColors.warm5;
      decisionIcon = Icons.hourglass_top;
      decisionLabel = 'Manual Review';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Decision badge
          Card(
            color: decisionColor.withAlpha(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Icon(decisionIcon, size: 48, color: decisionColor),
                  const SizedBox(height: 8),
                  Text(
                    decisionLabel,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: decisionColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pillar scores (v4.1)
          if (_hasPillarScores) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pillar Scores', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (result.channelTrustScore != null)
                      _PillarRow(
                        label: 'DeepSense (Channel Trust)',
                        score: result.channelTrustScore!,
                        verdict: result.channelTrustVerdict,
                      ),
                    if (result.livenessScore != null)
                      _PillarRow(
                        label: 'LiveSense (Liveness)',
                        score: result.livenessScore!,
                        verdict: result.livenessVerdict,
                      ),
                    if (result.dedupeRiskScore != null)
                      _PillarRow(
                        label: 'MatchSense (Dedupe Risk)',
                        score: result.dedupeRiskScore!,
                        verdict: result.dedupeVerdict,
                        invertScore: true,
                      ),
                    if (result.stepUpTriggered != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.shield,
                            size: 16,
                            color: result.stepUpTriggered!
                                ? UseSenseColors.warm5
                                : UseSenseColors.neutral4,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            result.stepUpTriggered!
                                ? 'Step-up triggered${result.stepUpPassed == true ? ' (passed)' : result.stepUpPassed == false ? ' (failed)' : ''}'
                                : 'Step-up not triggered',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Session details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Details',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Session ID',
                    value: result.sessionId,
                    copyable: true,
                  ),
                  if (result.sessionType != null)
                    _DetailRow(
                      label: 'Session Type',
                      value: result.sessionType!,
                    ),
                  if (result.identityId != null)
                    _DetailRow(
                      label: 'Identity ID',
                      value: result.identityId!,
                      copyable: true,
                    ),
                  _DetailRow(
                    label: 'Decision',
                    value: result.decision,
                  ),
                  _DetailRow(
                    label: 'Timestamp',
                    value: result.timestamp,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Security note
          Card(
            color: UseSenseColors.blue0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security,
                    color: UseSenseColors.blue7,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This result is for UI feedback only. The definitive '
                      'verdict is delivered via webhook to your backend. '
                      'Never trust the SDK result for access-control decisions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: UseSenseColors.blue7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  bool get _hasPillarScores =>
      result.channelTrustScore != null ||
      result.livenessScore != null ||
      result.dedupeRiskScore != null;
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.label,
    required this.score,
    this.verdict,
    this.invertScore = false,
  });

  final String label;
  final int score;
  final String? verdict;
  final bool invertScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // For dedupe risk, lower is better. For others, higher is better.
    final effectiveScore = invertScore ? (100 - score) : score;
    final Color barColor;
    if (effectiveScore >= 70) {
      barColor = UseSenseColors.green5;
    } else if (effectiveScore >= 40) {
      barColor = UseSenseColors.warm5;
    } else {
      barColor = UseSenseColors.red5;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Row(
                children: [
                  Text(
                    '$score',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (verdict != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: barColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        verdict!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: barColor.withAlpha(30),
              color: barColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: UseSenseColors.neutral4,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
          if (copyable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
              },
              child: const Icon(
                Icons.copy,
                size: 16,
                color: UseSenseColors.neutral4,
              ),
            ),
        ],
      ),
    );
  }
}

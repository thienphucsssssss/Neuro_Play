import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/neuro_theme.dart';

class LocalGamePage extends StatelessWidget {
  const LocalGamePage({
    required this.title,
    required this.children,
    this.maxWidth = 480,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: SingleChildScrollView(
        key: ValueKey(title),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

String roundTime(Duration duration) {
  final seconds = duration.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class LocalGameMetric extends StatelessWidget {
  const LocalGameMetric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: NeuroTheme.muted),
        ),
        Text(value, style: NeuroTheme.metric),
      ],
    ),
  );
}

class LocalGameClock extends StatefulWidget {
  const LocalGameClock({required this.elapsed, super.key});

  final Duration Function() elapsed;

  @override
  State<LocalGameClock> createState() => _LocalGameClockState();
}

class _LocalGameClockState extends State<LocalGameClock> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LocalGameMetric(label: 'Thời gian', value: roundTime(widget.elapsed()));
}

class LocalGameResult extends StatelessWidget {
  const LocalGameResult({
    required this.title,
    required this.skill,
    required this.success,
    required this.metrics,
    super.key,
  });

  final String title;
  final String skill;
  final bool success;
  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: success ? NeuroTheme.successFill : NeuroTheme.card,
        border: Border.all(color: NeuroTheme.outline),
        borderRadius: BorderRadius.circular(NeuroTheme.sheetRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(title, style: type.headlineMedium),
          ),
          Text(skill, style: type.bodyLarge),
          const SizedBox(height: 4),
          Wrap(spacing: 24, runSpacing: 8, children: metrics),
        ],
      ),
    );
  }
}

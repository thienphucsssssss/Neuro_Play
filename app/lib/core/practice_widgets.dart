import 'package:material_ui/material_ui.dart';

import 'neuro_theme.dart';
import 'practice_progress.dart';

class PracticeWeek extends StatelessWidget {
  const PracticeWeek({required this.progress, required this.today, super.key});

  final PracticeProgress progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final date in PracticeProgress.weekOf(today))
          Builder(
            builder: (context) {
              final day = date.weekday == DateTime.sunday
                  ? 'CN'
                  : 'T${date.weekday + 1}';
              final current = DateUtils.isSameDay(date, today);
              final done = progress.practicedOn(date);
              return Semantics(
                label: date.weekday == DateTime.sunday
                    ? 'Chủ nhật'
                    : 'Thứ ${date.weekday + 1}',
                value: [
                  if (current) 'hôm nay',
                  done ? 'đã luyện tập' : 'chưa luyện tập',
                ].join(', '),
                excludeSemantics: true,
                child: SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: done
                              ? NeuroTheme.primaryContainer
                              : NeuroTheme.inset,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: current || done
                                ? NeuroTheme.primary
                                : NeuroTheme.rule,
                            width: current ? 2 : 1,
                          ),
                        ),
                        child: done
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: NeuroTheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(child: Text(day, style: label)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class PracticeMeter extends StatelessWidget {
  const PracticeMeter({
    required this.label,
    required this.valueLabel,
    required this.value,
    this.color = NeuroTheme.primary,
    super.key,
  });

  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(
            valueLabel,
            style: const TextStyle(
              fontFeatures: NeuroTheme.digits,
              fontWeight: FontWeight.w600,
              color: NeuroTheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: value,
        minHeight: 8,
        color: color,
        backgroundColor: NeuroTheme.inset,
        borderRadius: BorderRadius.circular(4),
        semanticsLabel: '$label, $valueLabel',
      ),
    ],
  );
}

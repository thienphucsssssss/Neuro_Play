import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../core/neuro_theme.dart';
import '../core/practice_progress.dart';
import '../core/practice_widgets.dart';
import 'sudoku_api.dart';

String formatSudokuTime(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remaining = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remaining';
}

class SudokuMetric extends StatelessWidget {
  const SudokuMetric({
    required this.label,
    required this.value,
    this.isScore = false,
    super.key,
  });

  final String label;
  final String value;
  final bool isScore;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label $value',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: NeuroTheme.muted),
        ),
        Text(value, style: isScore ? NeuroTheme.score : NeuroTheme.metric),
      ],
    ),
  );
}

class SudokuResultView extends StatelessWidget {
  const SudokuResultView({
    required this.result,
    required this.progress,
    required this.completedAt,
    required this.onHome,
    required this.onReplay,
    super.key,
  });

  final SudokuResult result;
  final PracticeProgress? progress;
  final DateTime completedAt;
  final VoidCallback onHome;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final practice = progress;
    final outcome = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NeuroTheme.successFill,
        border: Border.all(color: NeuroTheme.outline),
        borderRadius: BorderRadius.circular(NeuroTheme.sheetRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(Icons.check, color: NeuroTheme.success, size: 20),
              Expanded(
                child: Text(
                  'Đã lưu kết quả',
                  style: type.labelLarge?.copyWith(color: NeuroTheme.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Semantics(
                liveRegion: true,
                header: true,
                child: Text('Hoàn thành Sudoku!', style: type.displaySmall),
              );
              final showStamp =
                  constraints.maxWidth >= 225 &&
                  MediaQuery.textScalerOf(context).scale(16) < 23;
              return showStamp
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Expanded(child: title),
                        const _CompletionTile(),
                      ],
                    )
                  : title;
            },
          ),
          const SizedBox(height: 4),
          Text('Độ khó · ${result.difficulty.label}', style: type.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              SudokuMetric(
                label: 'Điểm ván',
                value: NumberFormat.decimalPattern('vi').format(result.score),
                isScore: true,
              ),
              SudokuMetric(
                label: 'Thời gian',
                value: formatSudokuTime(result.durationSec),
              ),
              SudokuMetric(label: 'Số lỗi', value: '${result.mistakes}'),
            ],
          ),
        ],
      ),
    );
    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 2, thickness: 2, color: NeuroTheme.outline),
        const SizedBox(height: 12),
        Text('Tiến độ luyện tập', style: type.headlineSmall),
        const SizedBox(height: 16),
        if (practice == null) ...[
          Text('Suy luận logic', style: type.titleMedium),
          const Text('Tiến độ trên thiết bị hiện chưa khả dụng.'),
        ] else ...[
          PracticeMeter(
            label: 'Suy luận logic',
            valueLabel:
                '${practice.weeklyRounds(completedAt)} / ${PracticeProgress.weeklyGoal} ván',
            value: practice.weeklyFraction(completedAt),
            color: NeuroTheme.sudoku,
          ),
          const SizedBox(height: 6),
          const Text('Số ván luyện tập trong tuần này.'),
          const Divider(height: 24),
          PracticeMeter(
            label: 'Cấp ${practice.level} · +${PracticeProgress.xpPerRound} XP',
            valueLabel:
                '${practice.levelXp} / ${PracticeProgress.xpPerLevel} XP',
            value: practice.levelXp / PracticeProgress.xpPerLevel,
          ),
          const Divider(height: 24),
          Text(
            '${practice.streak(completedAt)} ngày liên tiếp',
            style: type.titleMedium,
          ),
          const SizedBox(height: 8),
          PracticeWeek(progress: practice, today: completedAt),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            if (wide)
              Row(
                spacing: 24,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: outcome),
                  Expanded(child: stats),
                ],
              )
            else ...[
              outcome,
              stats,
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onHome,
                  child: const Text('Về trang chủ'),
                ),
                OutlinedButton(
                  onPressed: onReplay,
                  child: const Text('Chơi đề mới'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CompletionTile extends StatelessWidget {
  const _CompletionTile();

  @override
  Widget build(BuildContext context) {
    final child = ExcludeSemantics(
      child: SizedBox.square(
        dimension: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -.25,
              child: const _Tile(color: NeuroTheme.successFill),
            ),
            Transform.rotate(
              angle: .16,
              child: const _Tile(
                color: NeuroTheme.card,
                child: Icon(Icons.check, size: 31, color: NeuroTheme.success),
              ),
            ),
          ],
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NeuroTheme.result,
      curve: Curves.easeOut,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -7 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.color, this.child});

  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: NeuroTheme.success, width: 1.5),
      borderRadius: BorderRadius.circular(NeuroTheme.controlRadius),
    ),
    child: child,
  );
}

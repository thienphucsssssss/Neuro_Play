import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'core/neuro_theme.dart';
import 'core/practice_progress.dart';
import 'core/practice_widgets.dart';
import 'sudoku/sudoku_api.dart';
import 'sudoku/sudoku_puzzle.dart';
import 'sudoku/sudoku_screen.dart';

class GameHome extends StatefulWidget {
  const GameHome({required this.sudokuApi, required this.health, super.key});

  final SudokuApi sudokuApi;
  final Widget health;

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  final _todaySection = GlobalKey();
  final _practiceSection = GlobalKey();
  final _gamesSection = GlobalKey();
  late final AppLifecycleListener _lifecycle;
  late final PracticeStore _store;
  late Future<void> _load;
  Future<void> _writes = Future<void>.value();
  PracticeProgress? _progress;
  bool _loadFailed = false;
  bool _saveFailed = false;
  bool _openingSudoku = false;
  int _destination = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _store = PracticeStore(auth.user!.id);
    _load = _loadPractice();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(auth.reloadProfile());
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadPractice() async {
    try {
      final progress = await _store.load();
      if (mounted) setState(() => _progress = progress);
    } on Exception {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _savePractice(PracticeProgress progress) {
    _writes = _writes.then((_) async {
      try {
        await _store.save(progress);
        if (mounted && _saveFailed) setState(() => _saveFailed = false);
      } on Exception {
        if (mounted) setState(() => _saveFailed = true);
      }
    });
  }

  PracticeProgress? _record(SudokuResult result, DateTime now) {
    final previous = _progress;
    if (!mounted || previous == null) return null;
    final progress = previous.record(result.sessionId, now);
    if (identical(previous, progress)) return progress;
    setState(() => _progress = progress);
    _savePractice(progress);
    return progress;
  }

  Future<void> _play({SudokuDifficulty? difficulty}) async {
    final auth = context.read<AuthController>();
    if (_openingSudoku || auth.busy) return;
    final navigator = Navigator.of(context);
    _openingSudoku = true;
    try {
      await _load;
      if (!mounted || auth.busy) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SudokuScreen(
            api: widget.sudokuApi,
            authorize: auth.requestWithSession,
            initialDifficulty: difficulty,
            recordPractice: _record,
          ),
        ),
      );
    } finally {
      _openingSudoku = false;
    }
  }

  void _navigate(int index) {
    setState(() => _destination = index);
    final target = [_todaySection, _gamesSection, _practiceSection][index];
    if (target.currentContext case final context?) {
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _openProfile() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Consumer<AuthController>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hồ sơ',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Xin chào, ${user.displayName}'),
                  Text('@${user.username}'),
                  const SizedBox(height: 16),
                  widget.health,
                  if (auth.message case final message?)
                    Semantics(liveRegion: true, child: Text(message)),
                  if (auth.profileRetry)
                    TextButton(
                      onPressed: auth.busy ? null : auth.reloadProfile,
                      child: const Text('Tải lại hồ sơ'),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: auth.busy
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            unawaited(auth.logout());
                          },
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final today = DateTime.now();
    final progress = _progress;
    final daily = _DailyChallenge(
      key: _todaySection,
      completed: progress?.practicedOn(today) ?? false,
      onPlay: auth.busy
          ? null
          : () => _play(difficulty: SudokuDifficulty.medium),
    );
    final practice = _practice(today, progress);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_rounded, color: NeuroTheme.primary, size: 27),
            SizedBox(width: 8),
            Flexible(child: Text('Neuro Play')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ',
            onPressed: _openProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final gutter = constraints.maxWidth >= 600
                ? 24.0
                : NeuroTheme.gutter;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 7, child: daily),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: practice),
                          ],
                        )
                      else ...[
                        daily,
                        const SizedBox(height: 16),
                        practice,
                      ],
                      const SizedBox(height: 24),
                      _SkillLibrary(
                        key: _gamesSection,
                        onSudoku: auth.busy ? null : _play,
                      ),
                      if (auth.message case final message?) ...[
                        const SizedBox(height: 12),
                        Semantics(liveRegion: true, child: Text(message)),
                      ],
                      if (auth.profileRetry)
                        TextButton(
                          onPressed: auth.busy ? null : auth.reloadProfile,
                          child: const Text('Tải lại hồ sơ'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination,
        onDestinationSelected: _navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Hôm nay',
          ),
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Trò chơi'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Tiến độ',
          ),
        ],
      ),
    );
  }

  Widget _practice(DateTime today, PracticeProgress? progress) => Padding(
    key: _practiceSection,
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null) ...[
          Text(
            progress.streak(today) == 0
                ? 'Bắt đầu chuỗi luyện tập'
                : '${progress.streak(today)} ngày liên tiếp',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          PracticeWeek(progress: progress, today: today),
          const SizedBox(height: 16),
          PracticeMeter(
            label: 'Cấp ${progress.level}',
            valueLabel:
                '${progress.levelXp} / ${PracticeProgress.xpPerLevel} XP',
            value: progress.levelXp / PracticeProgress.xpPerLevel,
          ),
          if (_saveFailed) ...[
            const SizedBox(height: 8),
            const Text('Chưa thể lưu tiến độ trên thiết bị.'),
            TextButton(
              onPressed: () => _savePractice(progress),
              child: const Text('Lưu lại tiến độ'),
            ),
          ],
        ] else if (_loadFailed) ...[
          const Text('Chưa đọc được tiến độ trên thiết bị.'),
          TextButton(
            onPressed: () => setState(() {
              _loadFailed = false;
              _load = _loadPractice();
            }),
            child: const Text('Tải lại tiến độ'),
          ),
        ] else
          const LinearProgressIndicator(semanticsLabel: 'Đang tải tiến độ'),
      ],
    ),
  );
}

class _DailyChallenge extends StatelessWidget {
  const _DailyChallenge({
    required this.completed,
    required this.onPlay,
    super.key,
  });

  final bool completed;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    const foreground = NeuroTheme.onPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NeuroTheme.sheetRadius),
      child: ColoredBox(
        color: NeuroTheme.primary,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final showArt =
                bounds.maxWidth >= 285 &&
                MediaQuery.textScalerOf(context).scale(16) < 24;
            final artSize = (bounds.maxWidth * .43).clamp(120.0, 195.0);
            return Stack(
              alignment: Alignment.centerRight,
              children: [
                if (showArt)
                  Positioned(
                    right: bounds.maxWidth >= 460 ? 28 : 12,
                    child: ExcludeSemantics(child: _DailyArt(size: artSize)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: showArt ? .62 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 8, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            completed
                                ? 'Thử thách hôm nay · Đã xong'
                                : 'Thử thách hôm nay',
                            style: type.labelLarge?.copyWith(color: foreground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sudoku',
                            style: type.displaySmall?.copyWith(
                              color: foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mức vừa · Suy luận logic',
                            style: type.bodyLarge?.copyWith(color: foreground),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: onPlay,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: foreground,
                              foregroundColor: NeuroTheme.onPrimaryContainer,
                              side: const BorderSide(color: foreground),
                            ),
                            child: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(completed ? 'Chơi lại' : 'Chơi ngay'),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DailyArt extends StatelessWidget {
  const _DailyArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    const digits = ['2', '', '9', '', '', '4', '', '6', '3'];
    final tile = size * .23;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.22,
            child: SizedBox(
              width: tile * 3 + 8,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var index = 0; index < digits.length; index++)
                    Container(
                      width: tile,
                      height: tile,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0 || index == 8
                            ? NeuroTheme.primaryContainer
                            : NeuroTheme.primaryPressed,
                        border: Border.all(color: NeuroTheme.primaryContainer),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        digits[index],
                        style: TextStyle(
                          color: index == 0 || index == 8
                              ? NeuroTheme.onPrimaryContainer
                              : NeuroTheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: size * .10,
            top: size * .12,
            child: Transform.rotate(
              angle: .18,
              child: Container(
                width: size * .36,
                height: size * .36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: NeuroTheme.sudokuFill,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    bottom: BorderSide(color: NeuroTheme.sudoku, width: 4),
                  ),
                ),
                child: Text(
                  '7',
                  style: TextStyle(
                    fontSize: size * .19,
                    fontWeight: FontWeight.w700,
                    color: NeuroTheme.sudoku,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillLibrary extends StatelessWidget {
  const _SkillLibrary({required this.onSudoku, super.key});

  final VoidCallback? onSudoku;

  @override
  Widget build(BuildContext context) {
    final groups = [
      _SkillGroup(
        title: 'Suy luận logic',
        games: [
          _GameRow(
            title: 'Sudoku',
            description: 'Tìm số bằng cách loại trừ',
            icon: Icons.grid_3x3,
            color: NeuroTheme.sudoku,
            background: NeuroTheme.sudokuFill,
            onTap: onSudoku,
          ),
          const _GameRow(
            title: 'Khối lập phương 3D',
            description: 'Tìm quy luật xoay',
            icon: Icons.view_in_ar_outlined,
            color: NeuroTheme.cube,
            background: NeuroTheme.cubeFill,
          ),
        ],
      ),
      const _SkillGroup(
        title: 'Không gian và lập kế hoạch',
        games: [
          _GameRow(
            title: 'Xếp hình',
            description: 'Sắp thứ tự các bước trượt',
            icon: Icons.dashboard_customize_outlined,
            color: NeuroTheme.sliding,
            background: NeuroTheme.slidingFill,
          ),
        ],
      ),
      const _SkillGroup(
        title: 'Chiến thuật và dự đoán',
        games: [
          _GameRow(
            title: 'Cờ Caro',
            description: 'Đọc thế cờ và đoán nước đáp',
            icon: Icons.close,
            color: NeuroTheme.caro,
            background: NeuroTheme.caroFill,
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chơi theo kỹ năng',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 720
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [
                    for (final group in groups) Expanded(child: group),
                  ],
                )
              : Column(spacing: 12, children: groups),
        ),
      ],
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({required this.title, required this.games});

  final String title;
  final List<Widget> games;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 1, thickness: 1, color: NeuroTheme.outline),
      const SizedBox(height: 8),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      ...games,
    ],
  );
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.background,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: type.titleMedium),
                Text(
                  onTap == null && title != 'Sudoku'
                      ? '$description · Sắp có'
                      : description,
                  style: type.bodyMedium?.copyWith(color: NeuroTheme.muted),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
    return Column(
      children: [
        if (onTap case final action?)
          InkWell(onTap: action, child: row)
        else
          row,
        const Divider(height: 1, color: NeuroTheme.rule),
      ],
    );
  }
}

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'sudoku_api.dart';
import 'sudoku_board.dart';
import 'sudoku_game.dart';
import 'sudoku_puzzle.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({required this.api, required this.authorize, super.key});

  final SudokuApi api;
  final SudokuAuthorize authorize;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late final SudokuGame _game;
  bool _confirmingExit = false;

  @override
  void initState() {
    super.initState();
    _game = SudokuGame(api: widget.api, authorize: widget.authorize);
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_confirmingExit) return;
    if (_game.requiresExitConfirmation) {
      _confirmingExit = true;
      final leave = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('Rời ván Sudoku?'),
          content: const Text('Tiến độ của ván này sẽ mất khi bạn rời bàn.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Chơi tiếp'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rời ván'),
            ),
          ],
        ),
      );
      _confirmingExit = false;
      if (leave != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _game,
    builder: (_, _) => PopScope<void>(
      canPop: !_game.requiresExitConfirmation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: const Text('Sudoku'),
        ),
        body: SafeArea(child: _content()),
      ),
    ),
  );

  Widget _content() => switch (_game.phase) {
    SudokuPhase.choosing => _difficultyPicker(),
    SudokuPhase.loading => const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Đang tải đề'),
    ),
    SudokuPhase.loadFailed => _loadFailed(),
    SudokuPhase.completed => _result(_game.result!),
    _ => _play(_game.board!),
  };

  Widget _panel(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );

  Widget _difficultyPicker() => _panel([
    Text('Chọn độ khó', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 16),
    for (final difficulty in SudokuDifficulty.values) ...[
      OutlinedButton(
        onPressed: () => _game.start(difficulty),
        child: Text(difficulty.label),
      ),
      const SizedBox(height: 8),
    ],
  ]);

  Widget _loadFailed() => _panel([
    Text(_game.error!, textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton(onPressed: _game.retryLoad, child: const Text('Thử lại')),
    TextButton(onPressed: _game.chooseAgain, child: const Text('Đổi độ khó')),
  ]);

  Widget _result(SudokuResult result) => _panel([
    Semantics(
      liveRegion: true,
      header: true,
      child: Text(
        'Hoàn thành',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ),
    const SizedBox(height: 16),
    Text(result.difficulty.label),
    Text(
      'Điểm ${result.score}',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    Text('Thời gian ${_formatElapsed(result.durationSec)}'),
    Text('Lỗi ${result.mistakes}'),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: _game.chooseAgain,
      child: const Text('Chơi đề mới'),
    ),
    OutlinedButton(onPressed: _leave, child: const Text('Về trang chính')),
  ]);

  Widget _play(SudokuBoard board) {
    final theme = Theme.of(context);
    final playing = _game.phase == SudokuPhase.playing;
    final canEdit = _game.canInteract && board.canEdit;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 4,
                spacing: 12,
                children: [
                  Text(
                    _game.difficulty!.label,
                    style: theme.textTheme.titleMedium,
                  ),
                  _ElapsedDisplay(game: _game),
                  Text('Lỗi ${_game.mistakes}'),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, index) => _SudokuCell(
                    key: ValueKey('sudoku-cell-$index'),
                    board: board,
                    index: index,
                    onSelect: _game.canInteract
                        ? () => _game.select(index)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (playing) ...[
                _SudokuKeypad(
                  enabled:
                      canEdit &&
                      (!board.noteMode || board.valueAt(board.selected!) == 0),
                  onDigit: _game.enter,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Ghi chú'),
                      selected: board.noteMode,
                      onSelected: _game.canInteract ? _game.toggleNotes : null,
                    ),
                    OutlinedButton.icon(
                      onPressed: canEdit ? _game.erase : null,
                      icon: const Icon(Icons.backspace_outlined, size: 18),
                      label: const Text('Xóa'),
                    ),
                  ],
                ),
              ],
              if (_game.sendingMove || _game.phase == SudokuPhase.submitting)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _game.sendingMove
                        ? 'Đang xác nhận nước đi…'
                        : 'Đang lưu điểm…',
                  ),
                ),
              if (_game.error case final message?) ...[
                const SizedBox(height: 8),
                Semantics(liveRegion: true, child: Text(message)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: playing ? _game.retryMove : _game.retrySubmit,
                    child: Text(playing ? 'Thử lại' : 'Nộp lại'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatElapsed(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainingSeconds';
}

class _ElapsedDisplay extends StatefulWidget {
  const _ElapsedDisplay({required this.game});

  final SudokuGame game;

  @override
  State<_ElapsedDisplay> createState() => _ElapsedDisplayState();
}

class _ElapsedDisplayState extends State<_ElapsedDisplay> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.game.phase == SudokuPhase.playing) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text('Thời gian ${_formatElapsed(widget.game.elapsedSec)}');
}

class _SudokuKeypad extends StatelessWidget {
  const _SudokuKeypad({required this.enabled, required this.onDigit});

  final bool enabled;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 440 ? 9 : 5;
      const gap = 4.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var digit = 1; digit <= 9; digit++)
            SizedBox(
              width: width,
              height: 48,
              child: OutlinedButton(
                key: ValueKey('sudoku-digit-$digit'),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: enabled ? () => onDigit(digit) : null,
                child: Text('$digit'),
              ),
            ),
        ],
      );
    },
  );
}

class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    super.key,
    required this.board,
    required this.index,
    required this.onSelect,
  });

  final SudokuBoard board;
  final int index;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final row = index ~/ 9;
    final column = index % 9;
    final selected = board.selected == index;
    final given = board.isGiven(index);
    final conflict = board.conflicts.contains(index);
    final wrong = board.isWrong(index);
    final value = board.valueAt(index);
    final notes = board.notesAt(index);
    final noteDigits = [
      for (var digit = 1; digit <= 9; digit++)
        if ((notes & (1 << digit)) != 0) digit,
    ];
    final description = [
      'Hàng ${row + 1}, cột ${column + 1}',
      if (value != 0) '$value' else 'ô trống',
      if (given) 'cho sẵn',
      if (wrong) 'sai',
      if (conflict) 'trùng số',
      if (noteDigits.isNotEmpty) 'ghi chú ${noteDigits.join(', ')}',
    ].join(', ');
    final background = conflict || wrong
        ? colors.errorContainer
        : selected
        ? colors.primaryContainer
        : board.isRelated(index)
        ? colors.secondaryContainer
        : colors.surface;
    final strongLine = BorderSide(color: colors.outline, width: 1.8);
    final lightLine = BorderSide(color: colors.outlineVariant, width: 0.6);
    return Semantics(
      label: description,
      selected: selected,
      button: true,
      onTap: onSelect,
      excludeSemantics: true,
      child: Material(
        color: background,
        child: InkWell(
          onTap: onSelect,
          child: Ink(
            decoration: BoxDecoration(
              border: Border(
                top: row == 0 ? strongLine : BorderSide.none,
                left: column == 0 ? strongLine : BorderSide.none,
                bottom: row % 3 == 2 ? strongLine : lightLine,
                right: column % 3 == 2 ? strongLine : lightLine,
              ),
            ),
            child: value != 0
                ? Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: given ? FontWeight.w800 : FontWeight.w500,
                          color: conflict || wrong
                              ? colors.onErrorContainer
                              : given
                              ? colors.onSurface
                              : colors.primary,
                        ),
                      ),
                    ),
                  )
                : _PencilNotes(notes: notes),
          ),
        ),
      ),
    );
  }
}

class _PencilNotes extends StatelessWidget {
  const _PencilNotes({required this.notes});

  final int notes;

  @override
  Widget build(BuildContext context) {
    if (notes == 0) return const SizedBox.expand();
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 3; column++)
                  Expanded(
                    child: Center(child: _note(row * 3 + column + 1, color)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _note(int digit, Color color) => (notes & (1 << digit)) == 0
      ? const SizedBox.shrink()
      : FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('$digit', style: TextStyle(fontSize: 11, color: color)),
        );
}

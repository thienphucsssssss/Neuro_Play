import 'dart:async';
import 'dart:collection';

import 'package:material_ui/material_ui.dart';

import '../core/neuro_theme.dart';
import '../core/practice_progress.dart';
import 'sudoku_api.dart';
import 'sudoku_board.dart';
import 'sudoku_game.dart';
import 'sudoku_grid.dart';
import 'sudoku_puzzle.dart';
import 'sudoku_result.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({
    required this.api,
    required this.authorize,
    this.initialDifficulty,
    this.recordPractice,
    super.key,
  });

  final SudokuApi api;
  final SudokuAuthorize authorize;
  final SudokuDifficulty? initialDifficulty;
  final PracticeProgress? Function(SudokuResult, DateTime)? recordPractice;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late final SudokuGame _game;
  late final ScrollController _scroll;
  bool _confirmingExit = false;
  int? _hintIndex;
  String? _hintMessage;
  SudokuResult? _handledResult;
  PracticeProgress? _practice;
  DateTime? _completedAt;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _game = SudokuGame(api: widget.api, authorize: widget.authorize)
      ..addListener(_captureResult);
    if (widget.initialDifficulty case final difficulty?) {
      unawaited(_game.start(difficulty));
    }
  }

  void _captureResult() {
    final result = _game.result;
    if (result == null || identical(result, _handledResult)) return;
    _handledResult = result;
    final now = DateTime.now();
    _completedAt = now;
    _practice = widget.recordPractice?.call(result, now);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _game.dispose();
    _scroll.dispose();
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

  void _chooseAgain() {
    _clearHint();
    _game.chooseAgain();
  }

  void _clearHint() {
    if (_hintMessage == null) return;
    setState(() {
      _hintIndex = null;
      _hintMessage = null;
    });
  }

  void _select(int index) {
    if (index != _hintIndex) _clearHint();
    _game.select(index);
  }

  void _hint(SudokuBoard board) {
    final selected = board.selected;
    final preferred = selected == null
        ? const <int>[]
        : board.candidatesAt(selected);
    final int? target = preferred.isNotEmpty
        ? selected
        : Iterable<int>.generate(81)
              .where((index) => board.candidatesAt(index).length == 1)
              .firstOrNull;
    if (target == null) {
      setState(() {
        _hintIndex = null;
        _hintMessage = 'Chọn một ô trống để xem các số có thể điền.';
      });
      return;
    }
    final candidates = target == selected
        ? preferred
        : board.candidatesAt(target);
    _game.select(target);
    setState(() {
      _hintIndex = target;
      _hintMessage = candidates.length == 1
          ? '${_position(target)} chỉ còn số ${candidates.single} sau khi loại các số đã có trong hàng, cột và khối.'
          : '${_position(target)} còn các khả năng ${candidates.join(', ')}. Kiểm tra các ô liên quan để loại trừ thêm.';
    });
  }

  void _zoom() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExpandedSudoku(
        game: _game,
        select: _select,
        enter: _enter,
        erase: _erase,
      ),
    );
  }

  void _enter(int digit) {
    _clearHint();
    unawaited(_game.enter(digit));
  }

  void _erase() {
    _clearHint();
    unawaited(_game.erase());
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
          title: Text(
            _game.phase == SudokuPhase.completed ? 'Kết quả' : 'Sudoku',
          ),
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
    SudokuPhase.completed => _panel(
      maxWidth: 960,
      children: [
        SudokuResultView(
          result: _game.result!,
          progress: _practice,
          completedAt: _completedAt!,
          onHome: _leave,
          onReplay: _chooseAgain,
        ),
      ],
    ),
    _ => _play(_game.board!),
  };

  Widget _panel({required List<Widget> children, double maxWidth = 440}) =>
      SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );

  Widget _difficultyPicker() => _panel(
    children: [
      const Icon(Icons.grid_3x3, color: NeuroTheme.sudoku, size: 48),
      const SizedBox(height: 12),
      Text('Chọn độ khó', style: Theme.of(context).textTheme.headlineMedium),
      const Text('Suy luận logic · Tìm số bằng cách loại trừ'),
      const SizedBox(height: 16),
      for (final difficulty in SudokuDifficulty.values) ...[
        OutlinedButton(
          onPressed: () => _game.start(difficulty),
          child: Text(difficulty.label),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );

  Widget _loadFailed() => _panel(
    children: [
      Text(_game.error!, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: _game.retryLoad, child: const Text('Thử lại')),
      TextButton(onPressed: _chooseAgain, child: const Text('Đổi độ khó')),
    ],
  );

  Widget _play(SudokuBoard board) {
    final playing = _game.phase == SudokuPhase.playing;
    final canEdit = _game.canInteract && board.canEdit;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final type = Theme.of(context).textTheme;
    final selected = board.selected;
    final grid = SudokuGrid(
      board: board,
      onSelect: _game.canInteract ? _select : null,
      hint: _hintIndex,
      lastCorrect: _lastCorrect(_game, board),
    );
    final control = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (playing) ...[
          _SelectedCell(board: board, selected: selected),
          const SizedBox(height: 8),
          _SudokuKeypad(
            digitsEnabled:
                canEdit && (!board.noteMode || board.valueAt(selected!) == 0),
            eraseEnabled: canEdit,
            onDigit: _enter,
            onErase: _erase,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                style: board.noteMode
                    ? OutlinedButton.styleFrom(
                        backgroundColor: NeuroTheme.primaryContainer,
                        foregroundColor: NeuroTheme.onPrimaryContainer,
                        side: const BorderSide(color: NeuroTheme.primary),
                      )
                    : null,
                onPressed: _game.canInteract
                    ? () => _game.toggleNotes(!board.noteMode)
                    : null,
                child: Semantics(
                  toggled: board.noteMode,
                  child: const Text('Ghi chú'),
                ),
              ),
              OutlinedButton(
                onPressed: _game.canInteract ? () => _hint(board) : null,
                child: const Text('Gợi ý'),
              ),
              OutlinedButton(onPressed: _zoom, child: const Text('Phóng to')),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_hintMessage case final message?)
          _HintMessage(message: message, number: _hintIndex != null)
        else if (_game.error == null)
          Semantics(
            liveRegion: true,
            child: Text(
              _game.sendingMove
                  ? 'Đang xác nhận nước đi…'
                  : !playing
                  ? 'Đang lưu điểm…'
                  : selected != null && board.isWrong(selected)
                  ? 'Ô này chưa đúng. Bạn có thể thử lại.'
                  : 'Điểm sẽ được lưu khi bạn giải xong.',
              style: type.bodyMedium?.copyWith(
                color: selected != null && board.isWrong(selected)
                    ? NeuroTheme.error
                    : NeuroTheme.muted,
              ),
            ),
          ),
        if (_game.error case final message?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: const TextStyle(color: NeuroTheme.error),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: playing ? _game.retryMove : _game.retrySubmit,
              child: Text(playing ? 'Thử lại' : 'Nộp lại'),
            ),
          ),
        ],
      ],
    );
    return _panel(
      maxWidth: wide ? 960 : 456,
      children: [
        Text(
          'Mức ${_game.difficulty!.label.toLowerCase()} · Suy luận logic',
          style: type.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 4,
          children: [
            _ElapsedDisplay(game: _game),
            SudokuMetric(label: 'Số lỗi', value: '${_game.mistakes}'),
            SudokuMetric(
              label: 'Ô còn trống',
              value:
                  '${Iterable<int>.generate(81).where((i) => board.valueAt(i) == 0).length}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 24,
            children: [
              SizedBox(width: 456, child: grid),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 336),
                  child: control,
                ),
              ),
            ],
          )
        else ...[
          grid,
          const SizedBox(height: 12),
          control,
        ],
      ],
    );
  }
}

String _position(int index) => 'Hàng ${index ~/ 9 + 1}, cột ${index % 9 + 1}';

int? _lastCorrect(SudokuGame game, SudokuBoard board) {
  final index = game.lastCorrectIndex;
  return index != null && board.valueAt(index) != 0 ? index : null;
}

class _SelectedCell extends StatelessWidget {
  const _SelectedCell({required this.board, required this.selected});

  final SudokuBoard board;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final index = selected;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text('Ô đang chọn', style: Theme.of(context).textTheme.labelLarge),
        Text(
          index == null
              ? 'Chạm vào một ô'
              : '${_position(index)}${board.valueAt(index) == 0 ? '' : ' · ${board.valueAt(index)}'}${board.isGiven(index) ? ' · Số cho sẵn' : ''}',
        ),
      ],
    );
  }
}

class _HintMessage extends StatelessWidget {
  const _HintMessage({required this.message, required this.number});

  final String message;
  final bool number;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeuroTheme.primaryContainer,
        border: Border.all(color: NeuroTheme.onPrimaryContainer),
        borderRadius: BorderRadius.circular(NeuroTheme.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (number)
            const CircleAvatar(
              radius: 11,
              foregroundColor: NeuroTheme.onPrimary,
              backgroundColor: NeuroTheme.onPrimaryContainer,
              child: Text('1'),
            ),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: NeuroTheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => SudokuMetric(
    label: 'Thời gian',
    value: formatSudokuTime(widget.game.elapsedSec),
  );
}

class _SudokuKeypad extends StatelessWidget {
  const _SudokuKeypad({
    required this.digitsEnabled,
    required this.eraseEnabled,
    required this.onDigit,
    required this.onErase,
    this.enlarged = false,
  });

  final bool digitsEnabled;
  final bool eraseEnabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onErase;
  final bool enlarged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final columns = ((constraints.maxWidth + gap) / (NeuroTheme.touch + gap))
          .floor()
          .clamp(1, 5);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var digit = 1; digit <= 9; digit++)
            SizedBox(
              width: width,
              height: NeuroTheme.touch,
              child: OutlinedButton(
                key: ValueKey(
                  '${enlarged ? 'enlarged' : 'sudoku'}-digit-$digit',
                ),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: digitsEnabled ? () => onDigit(digit) : null,
                child: Text(
                  '$digit',
                  style: const TextStyle(
                    fontSize: 18,
                    fontFeatures: NeuroTheme.digits,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: width,
            height: NeuroTheme.touch,
            child: Tooltip(
              message: 'Xóa số',
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: eraseEnabled ? onErase : null,
                child: const Icon(Icons.backspace_outlined, size: 18),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ExpandedSudoku extends StatefulWidget {
  const _ExpandedSudoku({
    required this.game,
    required this.select,
    required this.enter,
    required this.erase,
  });

  final SudokuGame game;
  final ValueChanged<int> select;
  final ValueChanged<int> enter;
  final VoidCallback erase;

  @override
  State<_ExpandedSudoku> createState() => _ExpandedSudokuState();
}

class _ExpandedSudokuState extends State<_ExpandedSudoku> {
  static const _cell = 50.0;
  final _horizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.game.board?.selected;
      if (mounted && index != null) _show(index);
    });
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  void _show(int index) {
    if (!_horizontal.hasClients) return;
    final content = _horizontal.position;
    final column = index % 9;
    final leading = column * _cell;
    final trailing = leading + _cell;
    final target = leading < content.pixels
        ? leading
        : trailing > content.pixels + content.viewportDimension
        ? trailing - content.viewportDimension
        : content.pixels;
    if (target != content.pixels) {
      _horizontal.jumpTo(
        target.clamp(content.minScrollExtent, content.maxScrollExtent),
      );
    }
  }

  void _move(int row, int column) {
    final selected = widget.game.board?.selected;
    final target = selected == null
        ? 0
        : (selected ~/ 9 + row).clamp(0, 8) * 9 +
              (selected % 9 + column).clamp(0, 8);
    widget.select(target);
    _show(target);
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .92,
    child: ListenableBuilder(
      listenable: widget.game,
      builder: (context, _) {
        final game = widget.game;
        final board = game.board!;
        final selected = board.selected;
        final canEdit = game.canInteract && board.canEdit;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bàn Sudoku phóng to',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                _SelectedCell(board: board, selected: selected),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (r, c, icon, label) in [
                      (0, -1, Icons.arrow_back, 'Sang trái'),
                      (-1, 0, Icons.arrow_upward, 'Lên một hàng'),
                      (1, 0, Icons.arrow_downward, 'Xuống một hàng'),
                      (0, 1, Icons.arrow_forward, 'Sang phải'),
                    ])
                      IconButton.outlined(
                        tooltip: label,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: game.canInteract ? () => _move(r, c) : null,
                        icon: Icon(icon),
                      ),
                  ],
                ),
                Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: _cell * 9,
                      child: SudokuGrid(
                        board: board,
                        enlarged: true,
                        lastCorrect: _lastCorrect(game, board),
                        onSelect: game.canInteract ? widget.select : null,
                      ),
                    ),
                  ),
                ),
                _SudokuKeypad(
                  digitsEnabled:
                      canEdit &&
                      (!board.noteMode || board.valueAt(selected!) == 0),
                  eraseEnabled: canEdit,
                  onDigit: widget.enter,
                  onErase: widget.erase,
                  enlarged: true,
                ),
                if (game.error case final message?)
                  Semantics(liveRegion: true, child: Text(message))
                else if (game.phase == SudokuPhase.completed)
                  const Text('Đã lưu kết quả. Đóng bàn phóng to để xem điểm.')
                else if (game.sendingMove)
                  const Text('Đang xác nhận nước đi…'),
              ],
            ),
          ),
        );
      },
    ),
  );
}

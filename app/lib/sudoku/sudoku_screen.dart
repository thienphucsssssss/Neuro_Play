import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../auth/auth_controller.dart';
import 'sudoku_board.dart';
import 'sudoku_puzzle.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({required this.loadPuzzle, super.key});

  final Future<SudokuPuzzle> Function() loadPuzzle;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  SudokuBoard? _board;
  String? _loadError;
  bool _loading = false;
  bool _confirmingExit = false;

  bool get _requiresConfirmation {
    final board = _board;
    return board != null && board.hasProgress && !board.isComplete;
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _board = null;
      _loadError = null;
    });
    try {
      final puzzle = await widget.loadPuzzle();
      if (mounted) setState(() => _board = SudokuBoard(puzzle.puzzle));
    } on Exception catch (error) {
      if (mounted) setState(() => _loadError = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leave() async {
    if (_confirmingExit) return;
    if (_requiresConfirmation) {
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
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_requiresConfirmation,
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
  );

  Widget _content() {
    final board = _board;
    if (board == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_loadError) {
            final error? => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
            null => const CircularProgressIndicator(
              semanticsLabel: 'Đang tải đề',
            ),
          },
        ),
      );
    }
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Dễ', style: theme.textTheme.titleMedium),
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
                    onSelect: () => setState(() => board.selected = index),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (board.isComplete) ...[
                Semantics(
                  liveRegion: true,
                  child: Text('Hoàn thành', style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Chơi đề mới'),
                    ),
                    OutlinedButton(
                      onPressed: _leave,
                      child: const Text('Về trang chính'),
                    ),
                  ],
                ),
              ] else ...[
                _SudokuKeypad(
                  enabled:
                      board.canEdit &&
                      (!board.noteMode || board.valueAt(board.selected!) == 0),
                  onDigit: (digit) => setState(() => board.enter(digit)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Ghi chú'),
                      selected: board.noteMode,
                      onSelected: (value) =>
                          setState(() => board.noteMode = value),
                    ),
                    OutlinedButton.icon(
                      onPressed: board.canEdit
                          ? () => setState(board.erase)
                          : null,
                      icon: const Icon(Icons.backspace_outlined, size: 18),
                      label: const Text('Xóa'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final row = index ~/ 9;
    final column = index % 9;
    final selected = board.selected == index;
    final given = board.isGiven(index);
    final conflict = board.conflicts.contains(index);
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
      if (conflict) 'trùng số',
      if (noteDigits.isNotEmpty) 'ghi chú ${noteDigits.join(', ')}',
    ].join(', ');
    final background = conflict
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
                          color: conflict
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

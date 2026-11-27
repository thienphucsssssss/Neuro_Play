final class SudokuBoard {
  SudokuBoard(List<int> puzzle)
    : _givens = List.unmodifiable(puzzle),
      _values = List.of(puzzle) {
    if (puzzle.length != 81 || puzzle.any((value) => value < 0 || value > 9)) {
      throw ArgumentError('Sudoku requires 81 digits from 0 to 9.');
    }
    _updateConflicts();
  }

  final List<int> _givens;
  final List<int> _values;
  final _notes = List<int>.filled(81, 0);
  final _wrong = <int>{};
  late Set<int> _conflicts;

  int? selected;
  bool noteMode = false;

  int valueAt(int index) => _values[index];
  int notesAt(int index) => _notes[index];
  bool isGiven(int index) => _givens[index] != 0;
  bool isWrong(int index) => _wrong.contains(index);
  List<int> candidatesAt(int index) {
    if (isGiven(index) || (_values[index] != 0 && !isWrong(index))) {
      return const [];
    }
    final used = {
      for (final unit in _units)
        if (unit.contains(index))
          for (final peer in unit)
            if (peer != index && !isWrong(peer)) _values[peer],
    };
    return [
      for (var digit = 1; digit <= 9; digit++)
        if (!used.contains(digit)) digit,
    ];
  }

  List<int> snapshot() => List.unmodifiable(_values);
  Set<int> get conflicts => _conflicts;
  bool get hasProgress => Iterable<int>.generate(81)
      .any((index) => _values[index] != _givens[index] || _notes[index] != 0);
  bool get isComplete => _conflicts.isEmpty && !_values.contains(0);
  bool get canEdit {
    final index = selected;
    return index != null && !isGiven(index) && !isComplete;
  }

  bool isRelated(int index) {
    final current = selected;
    if (current == null) return false;
    final row = index ~/ 9;
    final column = index % 9;
    final selectedRow = current ~/ 9;
    final selectedColumn = current % 9;
    return row == selectedRow ||
        column == selectedColumn ||
        (row ~/ 3 == selectedRow ~/ 3 && column ~/ 3 == selectedColumn ~/ 3);
  }

  void enter(int number) {
    RangeError.checkValueInInterval(number, 1, 9, 'number');
    if (!canEdit) return;
    final index = selected!;
    if (noteMode) {
      if (_values[index] == 0) _notes[index] ^= 1 << number;
      return;
    }
    confirmValue(index, number);
  }

  void erase() {
    if (!canEdit) return;
    confirmValue(selected!, 0);
  }

  void confirmValue(int index, int value, {bool? correct}) {
    RangeError.checkValueInInterval(value, 0, 9, 'value');
    if (isGiven(index) || isComplete) return;
    _values[index] = value;
    _notes[index] = 0;
    if (value > 0 && correct == false) {
      _wrong.add(index);
    } else {
      _wrong.remove(index);
    }
    _updateConflicts();
  }

  static final _units = [
    for (var row = 0; row < 9; row++)
      List.generate(9, (column) => row * 9 + column),
    for (var column = 0; column < 9; column++)
      List.generate(9, (row) => row * 9 + column),
    for (var box = 0; box < 9; box++)
      List.generate(
        9,
        (cell) => (box ~/ 3 * 3 + cell ~/ 3) * 9 + box % 3 * 3 + cell % 3,
      ),
  ];

  void _updateConflicts() {
    final conflicts = <int>{};
    for (final unit in _units) {
      final positions = List<int?>.filled(10, null);
      for (final index in unit) {
        final value = _values[index];
        if (value == 0) continue;
        if (positions[value] case final first?) {
          conflicts.addAll([first, index]);
        } else {
          positions[value] = index;
        }
      }
    }
    _conflicts = Set.unmodifiable(conflicts);
  }
}

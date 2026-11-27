import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { generateSudoku, SudokuGenerationExhausted } from '../src/sudoku/generator.ts';

const digits = [1, 2, 3, 4, 5, 6, 7, 8, 9];
const representativeSeeds = [
  '0'.repeat(32), 'f'.repeat(32),
  ...Array.from({ length: 12 }, (_, index) =>
    createHash('sha256').update(`sudoku fixture ${index}`).digest('hex').slice(0, 32)),
].map((entropy) => `sudoku-v1:${entropy}`);

function solveIndependently(puzzle) {
  const board = [...puzzle];
  const rows = Array.from({ length: 9 }, (_, index) => new Set(board.slice(index * 9, index * 9 + 9)));
  const columns = Array.from({ length: 9 }, (_, column) =>
    new Set(board.filter((_, index) => index % 9 === column)));
  const boxes = Array.from({ length: 9 }, () => new Set());
  const blanks = [];
  for (const [index, digit] of board.entries()) {
    const row = Math.floor(index / 9);
    const column = index % 9;
    const box = Math.floor(row / 3) * 3 + Math.floor(column / 3);
    if (digit === 0) blanks.push([index, row, column, box]);
    else boxes[box].add(digit);
  }

  const solutions = [];
  function visit(blank) {
    if (blank === blanks.length) {
      solutions.push([...board]);
      return;
    }

    const [index, row, column, box] = blanks[blank];
    for (const digit of digits) {
      if (rows[row].has(digit) || columns[column].has(digit) || boxes[box].has(digit)) continue;
      board[index] = digit;
      rows[row].add(digit);
      columns[column].add(digit);
      boxes[box].add(digit);
      visit(blank + 1);
      rows[row].delete(digit);
      columns[column].delete(digit);
      boxes[box].delete(digit);
      if (solutions.length === 2) break;
    }
  }

  visit(0);
  return solutions;
}

test('Sudoku v1 generates distinct, reproducible puzzles from representative seeds', () => {
  const puzzles = new Set();
  for (const seed of representativeSeeds) {
    const generated = generateSudoku(seed);
    assert.deepEqual(generateSudoku(seed), generated, seed);
    puzzles.add(generated.puzzle.join(''));
  }
  assert.equal(puzzles.size, representativeSeeds.length);
});

test('Sudoku v1 replays a stored seed with the original puzzle and answer', () => {
  const { puzzle, solution } = generateSudoku(`sudoku-v1:${'0'.repeat(32)}`);
  assert.equal(puzzle.join(''), '702581040480002050035007920007005090854306000901200005579024361048010509010000004');
  assert.equal(solution.join(''), '792581643486932157135467928327145896854396712961278435579824361248613579613759284');
});

test('easy Sudoku has exactly 42 clues, one valid solution, and a matching answer', () => {
  for (const seed of representativeSeeds) {
    const { puzzle, solution } = generateSudoku(seed);
    assert.equal(puzzle.length, 81, seed);
    assert.ok(puzzle.every((digit) => digit === 0 || digits.includes(digit)), seed);
    assert.equal(puzzle.filter(Boolean).length, 42, seed);
    assert.deepEqual(solveIndependently(puzzle), [solution], seed);
    for (let index = 0; index < 9; index++) {
      const row = solution.slice(index * 9, index * 9 + 9);
      const column = solution.filter((_, position) => position % 9 === index);
      const boxStart = Math.floor(index / 3) * 27 + (index % 3) * 3;
      const box = [0, 9, 18].flatMap((offset) => solution.slice(boxStart + offset, boxStart + offset + 3));
      assert.deepEqual(row.sort(), digits, seed);
      assert.deepEqual(column.sort(), digits, seed);
      assert.deepEqual(box.sort(), digits, seed);
    }
  }
});

test('Sudoku generation fails closed when it cannot prove a removal within the node budget', () => {
  assert.throws(() => generateSudoku(representativeSeeds[0], 83), SudokuGenerationExhausted);
});

test('regeneration rejects malformed seeds and unknown generator versions', () => {
  for (const seed of ['sudoku-v1:abcd', `sudoku-v2:${'0'.repeat(32)}`]) {
    assert.throws(() => generateSudoku(seed), /Unsupported Sudoku seed/);
  }
});

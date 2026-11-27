import { createHash, randomBytes } from 'node:crypto';

const seedPrefix = 'sudoku-v1:';
const cells = Array.from({ length: 81 }, (_, index) => {
  const row = Math.floor(index / 9);
  const column = index % 9;
  const box = Math.floor(row / 3) * 3 + Math.floor(column / 3);
  return { index, row, column, box };
});
const digits = [1, 2, 3, 4, 5, 6, 7, 8, 9];
const allDigits = 0b1111111110;
const clueTarget = 42;
const attemptLimit = 4;
const nodeLimit = 50_000;

type RandomNumber = () => number;

interface SearchBudget {
  remaining: number;
}

export class SudokuGenerationExhausted extends Error {
  constructor() {
    super('Sudoku generation budget exhausted.');
  }
}

export function newSudokuSeed(): string {
  return seedPrefix + randomBytes(16).toString('hex');
}

function seededRandom(seed: string): RandomNumber {
  let block = Buffer.alloc(0);
  let offset = 0;
  let blockNumber = 0;
  return () => {
    if (offset === block.length) {
      block = createHash('sha256').update(`${seed}:${blockNumber++}`).digest();
      offset = 0;
    }
    const value = block.readUInt32BE(offset);
    offset += 4;
    return value / 2 ** 32;
  };
}

function shuffle<T>(values: T[], random: RandomNumber): T[] {
  for (let index = values.length - 1; index > 0; index--) {
    const other = Math.floor(random() * (index + 1));
    [values[index], values[other]] = [values[other], values[index]];
  }
  return values;
}

function bitCount(mask: number): number {
  let count = 0;
  while (mask !== 0) {
    mask &= mask - 1;
    count++;
  }
  return count;
}

function searchSolutions(board: number[], budget: SearchBudget, limit: number, random?: RandomNumber) {
  const rows = Array<number>(9).fill(0);
  const columns = Array<number>(9).fill(0);
  const boxes = Array<number>(9).fill(0);
  for (const { index, row, column, box } of cells) {
    if (board[index] === 0) continue;
    const bit = 1 << board[index];
    rows[row] |= bit;
    columns[column] |= bit;
    boxes[box] |= bit;
  }

  let solution: number[] | undefined;
  function visit(remainingSolutions: number): number {
    if (budget.remaining === 0) throw new SudokuGenerationExhausted();
    budget.remaining--;

    let bestCell: (typeof cells)[number] | undefined;
    let bestMask = 0;
    let bestCount = 10;
    for (const cell of cells) {
      if (board[cell.index] !== 0) continue;
      const mask = allDigits & ~(rows[cell.row] | columns[cell.column] | boxes[cell.box]);
      if (mask === 0) return 0;
      const count = bitCount(mask);
      if (count < bestCount) {
        bestCell = cell;
        bestMask = mask;
        bestCount = count;
      }
    }

    if (!bestCell) {
      if (random) solution = [...board];
      return 1;
    }

    const { index, row, column, box } = bestCell;
    const candidates = digits.filter((digit) => bestMask & (1 << digit));
    if (random) shuffle(candidates, random);

    let found = 0;
    for (const digit of candidates) {
      const bit = 1 << digit;
      board[index] = digit;
      rows[row] |= bit;
      columns[column] |= bit;
      boxes[box] |= bit;
      found += visit(remainingSolutions - found);
      board[index] = 0;
      rows[row] &= ~bit;
      columns[column] &= ~bit;
      boxes[box] &= ~bit;
      if (found === remainingSolutions) break;
    }
    return found;
  }

  const count = visit(limit);
  return { count, solution };
}

// Preserve the v1 ordering and defaults so previously stored seeds can be replayed.
export function generateSudoku(seed: string, maxNodes = nodeLimit) {
  if (!seed.startsWith(seedPrefix) || !/^[a-f0-9]{32}$/.test(seed.slice(seedPrefix.length))) {
    throw new Error('Unsupported Sudoku seed.');
  }
  if (!Number.isSafeInteger(maxNodes) || maxNodes < 0) throw new RangeError('Invalid Sudoku node budget.');

  const random = seededRandom(seed);
  const budget = { remaining: Math.min(maxNodes, nodeLimit) };
  for (let attempt = 0; attempt < attemptLimit; attempt++) {
    const blankBoard = Array<number>(cells.length).fill(0);
    const { solution } = searchSolutions(blankBoard, budget, 1, random);
    if (!solution) throw new SudokuGenerationExhausted();

    const puzzle = [...solution];
    const removalOrder = shuffle(cells.map(({ index }) => index), random);
    let clues = cells.length;
    for (const index of removalOrder) {
      puzzle[index] = 0;
      if (searchSolutions(puzzle, budget, 2).count === 1) {
        clues--;
        if (clues === clueTarget) return { puzzle, solution };
      } else {
        puzzle[index] = solution[index];
      }
    }
  }

  throw new SudokuGenerationExhausted();
}

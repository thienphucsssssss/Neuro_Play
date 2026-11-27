import type { Pool, PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { generateSudoku } from './generator.ts';
import type { SudokuDifficulty } from './generator.ts';

interface Session extends RowDataPacket {
  gameId: number;
  difficulty: SudokuDifficulty;
  seed: string | null;
  status: 'active' | 'completed' | 'abandoned';
}

interface Progress extends RowDataPacket {
  board: string;
  mistakes: number;
  moveNo: string;
  lastCellIndex: number | null;
  lastValue: number | null;
  lastCorrect: number | null;
  lastElapsedSec: number;
  durationSec: number | string | null;
}

interface Score extends RowDataPacket {
  score: number;
  durationSec: number;
  mistakes: number;
}

export interface SudokuMove {
  sessionId: string;
  moveNo: number;
  cellIndex: number;
  value: number;
}

export class SudokuRequestError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

const scoreMaximums: Record<SudokuDifficulty, number> = { easy: 1000, medium: 1500, hard: 2000 };

async function transact<T>(pool: Pool, operation: (connection: PoolConnection) => Promise<T>): Promise<T> {
  const connection = await pool.getConnection();
  try {
    await connection.query("SET time_zone = '+00:00'");
    await connection.beginTransaction();
    try {
      const result = await operation(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    }
  } finally {
    connection.release();
  }
}

export function startSudoku(pool: Pool, userId: string, difficulty: SudokuDifficulty, seed: string, puzzle: number[]) {
  return transact(pool, async (connection) => {
    const [result] = await connection.execute<ResultSetHeader>(
      `INSERT INTO game_sessions (user_id, game_id, difficulty, seed, status)
       SELECT CAST(? AS UNSIGNED), id, ?, ?, 'active' FROM games WHERE code = 'sudoku'`,
      [userId, difficulty, seed],
    );
    if (result.affectedRows !== 1) throw new Error('Sudoku is missing from the game catalog.');

    const [[{ id: sessionId }]] = await connection.query<(RowDataPacket & { id: string })[]>(
      'SELECT CAST(LAST_INSERT_ID() AS CHAR) AS id',
    );
    await connection.execute(
      'INSERT INTO sudoku_progress (session_id, board) VALUES (CAST(? AS UNSIGNED), ?)',
      [sessionId, puzzle.join('')],
    );
    return { sessionId, difficulty, puzzle, elapsedSec: 0 };
  });
}

async function lockSudoku(connection: PoolConnection, userId: string, sessionId: string) {
  const [[session]] = await connection.execute<Session[]>(
    `SELECT game_id AS gameId, difficulty, seed, status
     FROM game_sessions
     WHERE id = CAST(? AS UNSIGNED) AND user_id = CAST(? AS UNSIGNED)
       AND game_id = (SELECT id FROM games WHERE code = 'sudoku')
     FOR UPDATE`,
    [sessionId, userId],
  );
  if (!session) throw new SudokuRequestError(404, 'Không tìm thấy ván Sudoku.');
  if (!session.seed?.startsWith('sudoku-v2:')) {
    throw new SudokuRequestError(409, 'Vui lòng mở ván Sudoku Tuần 4 để tính điểm.');
  }
  if (session.status === 'abandoned') {
    throw new SudokuRequestError(409, 'Ván Sudoku đã kết thúc.');
  }

  const [[progress]] = await connection.execute<Progress[]>(
    `SELECT progress.board, progress.mistakes, CAST(progress.move_no AS CHAR) AS moveNo,
            progress.last_cell_index AS lastCellIndex, progress.last_digit AS lastValue,
            progress.last_correct AS lastCorrect, progress.last_elapsed_sec AS lastElapsedSec,
            GREATEST(0, TIMESTAMPDIFF(SECOND, game_sessions.started_at, progress.solved_at)) AS durationSec
     FROM sudoku_progress AS progress JOIN game_sessions ON game_sessions.id = progress.session_id
     WHERE progress.session_id = CAST(? AS UNSIGNED)
     FOR UPDATE`,
    [sessionId],
  );
  if (!progress) throw new Error('Sudoku progress is missing for its session.');
  return { session, seed: session.seed, progress };
}

export function applySudokuMove(pool: Pool, userId: string, move: SudokuMove) {
  return transact(pool, async (connection) => {
    const { sessionId, moveNo, cellIndex, value } = move;
    const { session, seed, progress } = await lockSudoku(connection, userId, sessionId);
    const lastMoveNo = Number(progress.moveNo);
    if (moveNo === lastMoveNo && cellIndex === progress.lastCellIndex && value === progress.lastValue) {
      return {
        moveNo,
        mistakes: progress.mistakes,
        correct: progress.lastCorrect === null ? null : Boolean(progress.lastCorrect),
        elapsedSec: progress.lastElapsedSec,
        solved: progress.durationSec !== null,
      };
    }
    if (session.status !== 'active' || progress.durationSec !== null) {
      throw new SudokuRequestError(409, 'Ván Sudoku đã kết thúc.');
    }
    if (moveNo !== lastMoveNo + 1) {
      throw new SudokuRequestError(409, 'Số thứ tự nước đi Sudoku không hợp lệ.');
    }

    const { puzzle, solution } = generateSudoku(seed, session.difficulty);
    if (puzzle[cellIndex] !== 0) throw new SudokuRequestError(400, 'Không thể sửa ô cho sẵn.');

    const correct = value === 0 ? null : value === solution[cellIndex];
    const digit = String(value);
    const isChanged = progress.board[cellIndex] !== digit;
    const mistakes = progress.mistakes + Number(isChanged && correct === false);
    const board = progress.board.slice(0, cellIndex) + digit + progress.board.slice(cellIndex + 1);
    const solved = board === solution.join('');

    const [result] = await connection.execute<ResultSetHeader>(
      `UPDATE sudoku_progress AS progress JOIN game_sessions ON game_sessions.id = progress.session_id
       SET progress.board = ?, progress.mistakes = ?, progress.move_no = ?,
           progress.last_cell_index = ?, progress.last_digit = ?, progress.last_correct = ?,
           progress.last_elapsed_sec = GREATEST(0, TIMESTAMPDIFF(SECOND, game_sessions.started_at, CURRENT_TIMESTAMP(3))),
           progress.solved_at = IF(?, CURRENT_TIMESTAMP(3), NULL)
       WHERE progress.session_id = CAST(? AS UNSIGNED)`,
      [board, mistakes, moveNo, cellIndex, value, correct, solved, sessionId],
    );
    if (result.affectedRows !== 1) throw new Error('Failed to update Sudoku progress.');

    const [[{ elapsedSec }]] = await connection.execute<(RowDataPacket & { elapsedSec: number })[]>(
      'SELECT last_elapsed_sec AS elapsedSec FROM sudoku_progress WHERE session_id = CAST(? AS UNSIGNED)',
      [sessionId],
    );
    return { moveNo, mistakes, correct, elapsedSec, solved };
  });
}

export function submitSudoku(pool: Pool, userId: string, sessionId: string, board: number[]) {
  return transact(pool, async (connection) => {
    const { session, seed, progress } = await lockSudoku(connection, userId, sessionId);
    const { difficulty } = session;
    const boardString = board.join('');
    const { solution } = generateSudoku(seed, difficulty);
    if (progress.durationSec === null || boardString !== progress.board || boardString !== solution.join('')) {
      throw new SudokuRequestError(422, 'Bàn Sudoku chưa được giải đúng.');
    }

    if (session.status === 'completed') {
      const [[stored]] = await connection.execute<Score[]>(
        'SELECT score, duration_sec AS durationSec, mistakes FROM scores WHERE session_id = CAST(? AS UNSIGNED)',
        [sessionId],
      );
      if (!stored) throw new Error('The completed Sudoku session is missing its score.');
      return { sessionId, difficulty, score: stored.score, durationSec: stored.durationSec, mistakes: stored.mistakes };
    }

    const durationSec = Number(progress.durationSec);
    const { mistakes } = progress;
    const score = Math.max(0, scoreMaximums[difficulty] - 2 * durationSec - 50 * mistakes);
    await connection.execute(
      `INSERT INTO scores (session_id, user_id, game_id, difficulty, score, duration_sec, mistakes)
       VALUES (CAST(? AS UNSIGNED), CAST(? AS UNSIGNED), ?, ?, ?, ?, ?)`,
      [sessionId, userId, session.gameId, difficulty, score, durationSec, mistakes],
    );
    const [result] = await connection.execute<ResultSetHeader>(
      `UPDATE game_sessions JOIN sudoku_progress AS progress ON progress.session_id = game_sessions.id
       SET game_sessions.status = 'completed', game_sessions.finished_at = progress.solved_at
       WHERE game_sessions.id = CAST(? AS UNSIGNED) AND game_sessions.status = 'active'`,
      [sessionId],
    );
    if (result.affectedRows !== 1) throw new Error('Failed to complete the Sudoku session.');
    return { sessionId, difficulty, score, durationSec, mistakes };
  });
}

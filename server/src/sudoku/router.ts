import express from 'express';
import type { ErrorRequestHandler, RequestHandler } from 'express';
import type { Pool } from 'mysql2/promise';
import type { UserProfile } from '../auth/live-session.ts';
import { generateSudoku, isSudokuDifficulty, newSudokuSeed, SudokuGenerationExhausted } from './generator.ts';
import type { SudokuDifficulty } from './generator.ts';
import { applySudokuMove, startSudoku, submitSudoku, SudokuRequestError } from './store.ts';

const invalidInput = { error: 'Dữ liệu Sudoku không hợp lệ.' };
const retryLater = { error: 'Chưa thể tạo đề Sudoku. Vui lòng thử lại.' };

function isBody(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isSessionId(value: unknown): value is string {
  // Keep string IDs exact when MySQL converts them to BIGINT UNSIGNED.
  return typeof value === 'string' && /^[1-9][0-9]{0,19}$/.test(value) &&
    (value.length < 20 || value <= '18446744073709551615');
}

function isIntegerBetween(value: unknown, minimum: number, maximum: number): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

export function createSudokuRouter(
  pool: Pool,
  authenticate: RequestHandler,
  generatePuzzle: (seed: string, difficulty: SudokuDifficulty) => { puzzle: number[] } = generateSudoku,
) {
  const router = express.Router();
  const json = express.json({ limit: '16kb' });

  router.use((_request, response, next) => {
    response.set('Cache-Control', 'no-store');
    next();
  });

  router.post('/new', authenticate, json, async (request, response) => {
    const body: unknown = request.body;
    if (!isBody(body) || !Object.hasOwn(body, 'difficulty') ||
        !isSudokuDifficulty(body.difficulty) || Object.keys(body).length !== 1) {
      return response.status(400).json(invalidInput);
    }

    const user: UserProfile = response.locals.user;
    const { difficulty } = body;
    const seed = newSudokuSeed();
    const { puzzle } = generatePuzzle(seed, difficulty);
    const result = await startSudoku(pool, user.id, difficulty, seed, puzzle);
    return response.status(201).json(result);
  });

  router.post('/move', authenticate, json, async (request, response) => {
    const body: unknown = request.body;
    if (!isBody(body)) return response.status(400).json(invalidInput);
    const { sessionId, moveNo, cellIndex, value } = body;
    if (!isSessionId(sessionId) || !isIntegerBetween(moveNo, 1, Number.MAX_SAFE_INTEGER) ||
        !isIntegerBetween(cellIndex, 0, 80) || !isIntegerBetween(value, 0, 9)) {
      return response.status(400).json(invalidInput);
    }

    const user: UserProfile = response.locals.user;
    const result = await applySudokuMove(pool, user.id, { sessionId, moveNo, cellIndex, value });
    return response.json(result);
  });

  router.post('/submit', authenticate, json, async (request, response) => {
    const body: unknown = request.body;
    if (!isBody(body)) return response.status(400).json(invalidInput);
    const { sessionId, board } = body;
    if (!isSessionId(sessionId) || !Array.isArray(board) || board.length !== 81 ||
        !board.every((value: unknown) => isIntegerBetween(value, 1, 9))) {
      return response.status(400).json(invalidInput);
    }

    const user: UserProfile = response.locals.user;
    const result = await submitSudoku(pool, user.id, sessionId, board);
    return response.json(result);
  });

  const handleError: ErrorRequestHandler = (error: unknown, _request, response, next) => {
    if (error instanceof SudokuGenerationExhausted) return response.status(503).json(retryLater);
    if (error instanceof SudokuRequestError) return response.status(error.status).json({ error: error.message });
    if (error instanceof Error && 'status' in error &&
        typeof error.status === 'number' && error.status >= 400 && error.status < 500) {
      return response.status(400).json(invalidInput);
    }

    const message = 'Sudoku request failed.';
    if (response.headersSent) return next(new Error(message));
    console.error(message);
    return response.status(500).json({ error: 'Máy chủ gặp lỗi. Vui lòng thử lại sau.' });
  };
  router.use(handleError);

  return router;
}

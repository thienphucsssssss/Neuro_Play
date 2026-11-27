import express from 'express';
import type { ErrorRequestHandler, RequestHandler } from 'express';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import type { UserProfile } from '../auth/live-session.ts';
import { generateSudoku, newSudokuSeed, SudokuGenerationExhausted } from './generator.ts';

const invalidInput = { error: 'Dữ liệu Sudoku không hợp lệ.' };
const retryLater = { error: 'Chưa thể tạo đề Sudoku. Vui lòng thử lại.' };

export function createSudokuRouter(pool: Pool, authenticate: RequestHandler) {
  const router = express.Router();
  const json = express.json({ limit: '16kb' });

  router.use((_request, response, next) => {
    response.set('Cache-Control', 'no-store');
    next();
  });

  router.post('/new', authenticate, json, async (request, response) => {
    const body: unknown = request.body;
    if (typeof body !== 'object' || body === null || !('difficulty' in body) ||
        body.difficulty !== 'easy' || !Object.hasOwn(body, 'difficulty') || Object.keys(body).length !== 1) {
      return response.status(400).json(invalidInput);
    }

    const { difficulty } = body;
    const user: UserProfile = response.locals.user;
    const seed = newSudokuSeed();
    const { puzzle } = generateSudoku(seed);
    const connection = await pool.getConnection();
    try {
      const [result] = await connection.execute<ResultSetHeader>(
        `INSERT INTO game_sessions (user_id, game_id, difficulty, seed, status)
         SELECT CAST(? AS UNSIGNED), id, ?, ?, 'active' FROM games WHERE code = 'sudoku'`,
        [user.id, difficulty, seed],
      );
      if (result.affectedRows !== 1) throw new Error('Sudoku is missing from the game catalog.');

      const [[{ id: sessionId }]] = await connection.query<(RowDataPacket & { id: string })[]>(
        'SELECT CAST(LAST_INSERT_ID() AS CHAR) AS id',
      );
      return response.status(201).json({ sessionId, difficulty, puzzle });
    } finally {
      connection.release();
    }
  });

  const handleError: ErrorRequestHandler = (error: unknown, _request, response, next) => {
    if (error instanceof SudokuGenerationExhausted) return response.status(503).json(retryLater);
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

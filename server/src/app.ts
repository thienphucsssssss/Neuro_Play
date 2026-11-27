import express from 'express';
import type { Pool } from 'mysql2/promise';
import { requireLiveSession } from './auth/live-session.ts';
import { createAuthRouter } from './auth/router.ts';
import { createTokens } from './auth/tokens.ts';
import type { JwtSecrets } from './config/env.ts';
import { createSudokuRouter } from './sudoku/router.ts';

interface AuthOptions {
  pool: Pool;
  jwtSecrets: JwtSecrets;
  accessTokenTtlSeconds?: number;
}

export function createApp(auth?: AuthOptions) {
  const app = express();

  app.get('/health', (_request, response) => {
    response.json({ status: 'ok' });
  });

  if (auth) {
    const tokens = createTokens(auth.jwtSecrets, auth.accessTokenTtlSeconds);
    const authenticate = requireLiveSession(auth.pool, tokens);
    app.use('/api/auth', createAuthRouter(auth.pool, tokens, authenticate));
    app.use('/api/games/sudoku', createSudokuRouter(auth.pool, authenticate));
  }

  return app;
}

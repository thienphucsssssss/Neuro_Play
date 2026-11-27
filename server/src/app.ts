import express from 'express';
import type { Pool } from 'mysql2/promise';
import { createAuthRouter } from './auth/router.ts';
import type { JwtSecrets } from './config/env.ts';

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
    app.use('/api/auth', createAuthRouter(auth.pool, auth.jwtSecrets, auth.accessTokenTtlSeconds));
  }

  return app;
}

import { randomUUID, timingSafeEqual } from 'node:crypto';
import bcrypt from 'bcrypt';
import express from 'express';
import type { ErrorRequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import type { Pool, RowDataPacket } from 'mysql2/promise';
import type { JwtSecrets } from '../config/env.ts';
import { readLogin, readRefreshToken, readRegistration } from './input.ts';
import { createTokens, refreshDigest, sessionLifetime, unixTime } from './tokens.ts';
import type { SessionClaims } from './tokens.ts';

const invalidInput = { error: 'Dữ liệu xác thực không hợp lệ.' };
const invalidLogin = { error: 'Tên đăng nhập, email hoặc mật khẩu không đúng.' };
const invalidSession = { error: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.' };
const passwordCost = 12;
const fallbackHash = '$2b$12$Kv/C0uMohsH2iohmXCIwuuYcsQfWyveXbMthqbt9AzauWezDHDp6a';

interface UserProfile {
  id: string;
  username: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
}

function authLimit(limit: number) {
  return rateLimit({
    limit,
    windowMs: 15 * 60 * 1000,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    validate: { xForwardedForHeader: false },
    message: { error: 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau.' },
  });
}

function sessionExpiry(session: SessionClaims): Date {
  return new Date(session.expiresAt * 1000);
}

export function createAuthRouter(pool: Pool, jwtSecrets: JwtSecrets, accessTokenTtlSeconds?: number) {
  const router = express.Router();
  const json = express.json({ limit: '16kb' });
  const tokens = createTokens(jwtSecrets, accessTokenTtlSeconds);

  router.use((_request, response, next) => {
    response.set('Cache-Control', 'no-store');
    next();
  });

  router.post('/register', authLimit(10), json, async (request, response) => {
    const input = readRegistration(request.body);
    if (!input) return response.status(400).json(invalidInput);

    const { username, email, password, displayName } = input;
    const passwordHash = await bcrypt.hash(password, passwordCost);
    const connection = await pool.getConnection();
    try {
      await connection.execute(
        `INSERT INTO users (username, email, password_hash, display_name) VALUES (?, ?, ?, ?)`,
        [username, email, passwordHash, displayName],
      );
      const [[{ id }]] = await connection.query<(RowDataPacket & { id: string })[]>(
        'SELECT CAST(LAST_INSERT_ID() AS CHAR) AS id',
      );
      const user: UserProfile = { id, username, email, displayName, avatarUrl: null };
      return response.status(201).json({ user });
    } catch (error) {
      if (error instanceof Error && 'code' in error && error.code === 'ER_DUP_ENTRY') {
        return response.status(409).json({ error: 'Tên đăng nhập hoặc email đã được sử dụng.' });
      }
      throw error;
    } finally {
      connection.release();
    }
  });

  router.post('/login', authLimit(20), json, async (request, response) => {
    const input = readLogin(request.body);
    if (!input) return response.status(400).json(invalidInput);

    const { identifier, password } = input;
    const query = identifier.includes('@')
      ? 'SELECT CAST(id AS CHAR) AS id, password_hash FROM users WHERE email = ?'
      : 'SELECT CAST(id AS CHAR) AS id, password_hash FROM users WHERE username = ?';
    const [[user]] = await pool.execute<(RowDataPacket & { id: string; password_hash: string })[]>(query,
      [identifier]);
    const matches = await bcrypt.compare(password, user?.password_hash ?? fallbackHash);
    if (!user || !matches) return response.status(401).json(invalidLogin);

    const now = unixTime();
    const session = { sessionId: randomUUID(), userId: user.id, expiresAt: now + sessionLifetime };
    const pair = tokens.pair(session, now);
    await pool.execute(
      `INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at)
       VALUES (?, CAST(? AS UNSIGNED), ?, ?)`,
      [session.sessionId, session.userId, refreshDigest(pair.refreshToken), sessionExpiry(session)],
    );
    return response.json(pair);
  });

  router.get('/me', async (request, response, next) => {
    const match = /^Bearer ([^\s]+)$/i.exec(request.get('Authorization') ?? '');
    const session = match && tokens.verify(match[1], 'access');
    if (!session) return response.status(401).json(invalidSession);

    const [[user]] = await pool.execute<(RowDataPacket & UserProfile)[]>(
      `SELECT CAST(users.id AS CHAR) AS id, users.username, users.email,
              users.display_name AS displayName, users.avatar_url AS avatarUrl
       FROM auth_sessions JOIN users ON users.id = auth_sessions.user_id
       WHERE auth_sessions.id = ? AND auth_sessions.user_id = CAST(? AS UNSIGNED)
         AND auth_sessions.revoked_at IS NULL AND auth_sessions.expires_at > UTC_TIMESTAMP(3)`,
      [session.sessionId, session.userId],
    );
    if (!user) return response.status(401).json(invalidSession);

    response.locals.user = user;
    next();
  }, (_request, response) => response.json({ user: response.locals.user }));

  async function rotateRefreshToken(session: SessionClaims, refreshToken: string) {
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      const [[current]] = await connection.execute<(RowDataPacket & { refresh_token_hash: Buffer })[]>(
        `SELECT refresh_token_hash FROM auth_sessions
         WHERE id = ? AND user_id = CAST(? AS UNSIGNED) AND expires_at = ?
           AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP(3)
         FOR UPDATE`,
        [session.sessionId, session.userId, sessionExpiry(session)],
      );

      const now = unixTime();
      let pair = null;
      if (current && session.expiresAt > now) {
        if (timingSafeEqual(current.refresh_token_hash, refreshDigest(refreshToken))) {
          pair = tokens.pair(session, now);
          await connection.execute('UPDATE auth_sessions SET refresh_token_hash = ? WHERE id = ?',
            [refreshDigest(pair.refreshToken), session.sessionId]);
        } else {
          await connection.execute('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE id = ?',
            [session.sessionId]);
        }
      }

      await connection.commit();
      return pair;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  router.post('/refresh', authLimit(120), json, async (request, response) => {
    const refreshToken = readRefreshToken(request.body);
    if (!refreshToken) return response.status(400).json(invalidInput);

    const session = tokens.verify(refreshToken, 'refresh');
    if (!session) return response.status(401).json(invalidSession);

    const pair = await rotateRefreshToken(session, refreshToken);
    return pair ? response.json(pair) : response.status(401).json(invalidSession);
  });

  router.post('/logout', json, async (request, response) => {
    const refreshToken = readRefreshToken(request.body);
    if (!refreshToken) return response.status(400).json(invalidInput);

    const session = tokens.verify(refreshToken, 'refresh');
    if (!session) return response.status(401).json(invalidSession);

    await pool.execute(
      `UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP(3)
       WHERE id = ? AND user_id = CAST(? AS UNSIGNED) AND expires_at = ? AND revoked_at IS NULL`,
      [session.sessionId, session.userId, sessionExpiry(session)],
    );
    return response.status(204).end();
  });

  const handleError: ErrorRequestHandler = (error: unknown, _request, response, next) => {
    if (error instanceof Error && 'status' in error &&
        typeof error.status === 'number' && error.status >= 400 && error.status < 500) {
      return response.status(400).json(invalidInput);
    }

    const message = 'Auth request failed.';
    if (response.headersSent) return next(new Error(message));
    console.error(message);
    return response.status(500).json({ error: 'Máy chủ gặp lỗi. Vui lòng thử lại sau.' });
  };
  router.use(handleError);

  return router;
}

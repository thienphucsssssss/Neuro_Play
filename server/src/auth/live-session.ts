import type { RequestHandler } from 'express';
import type { Pool, RowDataPacket } from 'mysql2/promise';
import type { createTokens } from './tokens.ts';

export interface UserProfile {
  id: string;
  username: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
}

export const invalidSession = { error: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.' };

export function requireLiveSession(pool: Pool, tokens: ReturnType<typeof createTokens>): RequestHandler {
  return async (request, response, next) => {
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
  };
}

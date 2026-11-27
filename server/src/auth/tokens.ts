import { createHash, randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import type { JwtSecrets } from '../config/env.ts';

const issuer = 'neuro-play';
const audiences = { access: 'neuro-play:access', refresh: 'neuro-play:refresh' };
const maxAccessLifetime = 15 * 60;
export const sessionLifetime = 30 * 24 * 60 * 60;

const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const unsignedBigintMax = 18446744073709551615n;

type TokenUse = keyof JwtSecrets;

export interface SessionClaims {
  userId: string;
  sessionId: string;
  expiresAt: number;
}

export function unixTime(): number {
  return Math.floor(Date.now() / 1000);
}

export function refreshDigest(token: string): Buffer {
  return createHash('sha256').update(token).digest();
}

export function createTokens(secrets: JwtSecrets, accessLifetime = maxAccessLifetime) {
  if (!Number.isInteger(accessLifetime) || accessLifetime < 1 || accessLifetime > maxAccessLifetime) {
    throw new Error('The access token lifetime must be between 1 and 900 seconds.');
  }

  function sign(use: TokenUse, session: SessionClaims, now: number, expiresAt: number): string {
    return jwt.sign({ sid: session.sessionId, use, iat: now, exp: expiresAt }, secrets[use], {
      algorithm: 'HS256',
      audience: audiences[use],
      issuer,
      jwtid: randomUUID(),
      subject: session.userId,
    });
  }

  function pair(session: SessionClaims, now: number) {
    return {
      accessToken: sign('access', session, now, Math.min(now + accessLifetime, session.expiresAt)),
      refreshToken: sign('refresh', session, now, session.expiresAt),
    };
  }

  function verify(token: string, use: TokenUse): SessionClaims | null {
    const now = unixTime();
    try {
      const claims = jwt.verify(token, secrets[use], {
        algorithms: ['HS256'], audience: audiences[use], issuer, clockTimestamp: now,
      });
      if (!claims || typeof claims !== 'object' || claims.use !== use || claims.aud !== audiences[use]) return null;

      const { exp, iat, sub, sid, jti } = claims;
      const lifetime = use === 'access' ? maxAccessLifetime : sessionLifetime;
      if (typeof exp !== 'number' || !Number.isSafeInteger(exp) || exp <= now ||
          typeof iat !== 'number' || !Number.isSafeInteger(iat) || iat <= 0 || iat > now ||
          exp <= iat || exp - iat > lifetime) return null;
      if (typeof sub !== 'string' || !/^[1-9][0-9]{0,19}$/.test(sub) || BigInt(sub) > unsignedBigintMax ||
          typeof sid !== 'string' || !uuidV4.test(sid) || typeof jti !== 'string' || !uuidV4.test(jti)) return null;

      return { userId: sub, sessionId: sid, expiresAt: exp };
    } catch (error) {
      // Some malformed JOSE data fails to decode before jsonwebtoken can report a JWT error.
      if (error instanceof jwt.JsonWebTokenError || error instanceof SyntaxError || error instanceof TypeError) {
        return null;
      }
      throw error;
    }
  }

  return { pair, verify };
}

import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { createPool } from 'mysql2/promise';
import { createApp } from '../src/app.ts';
import { close, serve } from '../test-support/http.mjs';

const {
  AUTH_TEST_DB_HOST = '127.0.0.1',
  AUTH_TEST_DB_PORT = '3307',
  AUTH_TEST_DB_NAME,
  AUTH_TEST_DB_USER,
  AUTH_TEST_DB_PASSWORD,
  DB_NAME,
} = process.env;

assert.match(AUTH_TEST_DB_NAME ?? '', /^[A-Za-z0-9_]+_test$/,
  'Set AUTH_TEST_DB_NAME to a dedicated MySQL schema ending in _test.');
assert.notEqual(AUTH_TEST_DB_NAME.toLowerCase(), DB_NAME?.toLowerCase());
assert.ok(AUTH_TEST_DB_USER && AUTH_TEST_DB_PASSWORD,
  'Set AUTH_TEST_DB_USER and AUTH_TEST_DB_PASSWORD.');

const pool = createPool({
  host: AUTH_TEST_DB_HOST,
  port: Number(AUTH_TEST_DB_PORT),
  database: AUTH_TEST_DB_NAME,
  user: AUTH_TEST_DB_USER,
  password: AUTH_TEST_DB_PASSWORD,
  multipleStatements: true,
  timezone: 'Z',
  supportBigNumbers: true,
  bigNumberStrings: true,
});
const jwtSecrets = { access: randomBytes(32), refresh: randomBytes(32) };
const prefix = `t${randomBytes(8).toString('hex')}`;
let fixtureNumber = 0;
let schemaReady = false;

before(async () => {
  for (const file of ['001_initial.sql', '002_auth_sessions.sql']) {
    const sql = await readFile(new URL(`../sql/${file}`, import.meta.url), 'utf8');
    await pool.query(sql);
  }
  schemaReady = true;
});

after(async () => {
  try {
    if (schemaReady) {
      await pool.execute(
        'DELETE game_sessions FROM game_sessions JOIN users ON users.id = game_sessions.user_id WHERE users.username LIKE ?',
        [`${prefix}%`],
      );
      await pool.execute('DELETE FROM users WHERE username LIKE ?', [`${prefix}%`]);
    }
  } finally {
    await pool.end();
  }
});

async function startApi(context) {
  const { server, request } = await serve(createApp({ pool, jwtSecrets }));
  context.after(() => close(server));
  const auth = (endpoint, options) => request(`/api/auth/${endpoint}`, options);
  return { request, auth };
}

async function authApi(context) {
  const { auth } = await startApi(context);
  return auth;
}

function credentials(overrides = {}) {
  const username = `${prefix}${++fixtureNumber}`;
  return {
    username,
    email: `${username}@example.test`,
    password: '  Cà phê sữa đẹp  ',
    ...overrides,
  };
}

async function register(api, body) {
  const response = await api('register', { body });
  assert.equal(response.status, 201);
  const { user } = await response.json();
  return user;
}

async function login(api, body, identifier = body.username) {
  const response = await api('login', { body: { identifier, password: body.password } });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const tokens = await response.json();
  assert.deepEqual(Object.keys(tokens).sort(), ['accessToken', 'refreshToken']);
  assert.equal(typeof tokens.accessToken, 'string');
  assert.equal(typeof tokens.refreshToken, 'string');
  return tokens;
}

test('register normalizes identity, returns the profile and rejects both duplicate keys', async (context) => {
  const api = await authApi(context);
  const account = credentials();
  const user = await register(api, {
    ...account,
    username: ` ${account.username.toUpperCase()} `,
    email: ` ${account.email.toUpperCase()} `,
    displayName: '  Người Chơi  ',
  });

  assert.match(user.id, /^[1-9][0-9]*$/);
  assert.deepEqual(user, {
    id: user.id,
    username: account.username,
    email: account.email,
    displayName: 'Người Chơi',
    avatarUrl: null,
  });

  for (const duplicate of [credentials({ username: account.username }), credentials({ email: account.email })]) {
    const response = await api('register', { body: duplicate });
    assert.equal(response.status, 409);
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  }

  const [[stored]] = await pool.execute('SELECT password_hash FROM users WHERE id = ?', [user.id]);
  assert.equal(bcrypt.getRounds(stored.password_hash), 12);
  assert.equal(await bcrypt.compare(account.password, stored.password_hash), true);
});

test('login accepts normalized username and email and returns a new session each time', async (context) => {
  const api = await authApi(context);
  const account = credentials();
  const user = await register(api, account);
  assert.equal(user.displayName, account.username);

  const first = await login(api, account, ` ${account.username.toUpperCase()} `);
  const second = await login(api, account, ` ${account.email.toUpperCase()} `);
  const access = jwt.decode(first.accessToken);
  const refresh = jwt.decode(first.refreshToken);
  assert.notEqual(refresh.sid, jwt.decode(second.refreshToken).sid);
  assert.equal(access.exp - access.iat, 15 * 60);
  assert.equal(refresh.exp - refresh.iat, 30 * 24 * 60 * 60);

  const [[session]] = await pool.execute('SELECT refresh_token_hash FROM auth_sessions WHERE id = ?', [refresh.sid]);
  assert.deepEqual(session.refresh_token_hash, createHash('sha256').update(first.refreshToken).digest());

  const me = await api('me', { accessToken: first.accessToken });
  assert.equal(me.status, 200);
  assert.deepEqual(await me.json(), { user });

  const invalid = await api('login', { body: { identifier: account.email, password: 'another long password' } });
  const missing = await api('login', { body: { identifier: 'nobody@example.test', password: account.password } });
  assert.equal(invalid.status, 401);
  assert.equal(missing.status, 401);
  assert.deepEqual(await invalid.json(), await missing.json());
});

test('register and login enforce the Unicode character minimum and UTF-8 byte cap', async (context) => {
  const api = await authApi(context);
  const account = credentials({ password: '🍀'.repeat(18) });

  for (const password of ['🍀'.repeat(14), '🍀'.repeat(19)]) {
    const response = await api('register', { body: { ...account, password } });
    assert.equal(response.status, 400);
    await response.json();
  }

  await register(api, account);
  await login(api, account);
  const truncated = await api('login', {
    body: { identifier: account.username, password: `${account.password}x` },
  });
  assert.equal(truncated.status, 400);
});

test('protected routes reject expired or wrong-type JWTs and expired database sessions', async (context) => {
  const api = await authApi(context);
  const account = credentials();
  await register(api, account);
  const tokens = await login(api, account);
  const access = jwt.decode(tokens.accessToken);
  const refresh = jwt.decode(tokens.refreshToken);

  for (const payload of [
    { ...access, exp: access.iat - 1 },
    { ...access, exp: undefined },
    { ...access, iss: 'wrong-issuer' },
    { ...access, aud: refresh.aud },
    { ...access, use: 'refresh' },
    { ...access, sid: undefined },
    { ...access, sub: undefined },
    { ...access, jti: undefined },
  ]) {
    const claims = Object.fromEntries(Object.entries(payload).filter(([, value]) => value !== undefined));
    const response = await api('me', { accessToken: jwt.sign(claims, jwtSecrets.access) });
    assert.equal(response.status, 401);
    await response.json();
  }

  const substitute = await api('me', { accessToken: tokens.refreshToken });
  assert.equal(substitute.status, 401);
  const unsupported = await api('me', { accessToken: jwt.sign(access, jwtSecrets.access, { algorithm: 'HS384' }) });
  assert.equal(unsupported.status, 401);

  const wrongType = await api('refresh', { body: { refreshToken: tokens.accessToken } });
  assert.equal(wrongType.status, 401);
  const expired = jwt.sign({ ...refresh, exp: refresh.iat - 1 }, jwtSecrets.refresh);
  const expiredRefresh = await api('refresh', { body: { refreshToken: expired } });
  assert.equal(expiredRefresh.status, 401);

  await pool.execute('UPDATE auth_sessions SET expires_at = UTC_TIMESTAMP(3) - INTERVAL 1 SECOND WHERE id = ?',
    [refresh.sid]);
  const expiredSession = await api('me', { accessToken: tokens.accessToken });
  assert.equal(expiredSession.status, 401);
  const expiredDatabaseRefresh = await api('refresh', { body: { refreshToken: tokens.refreshToken } });
  assert.equal(expiredDatabaseRefresh.status, 401);
});

test('refresh rotates the token at the same expiry and an old token revokes only its session', async (context) => {
  const api = await authApi(context);
  const account = credentials();
  await register(api, account);
  const first = await login(api, account);
  const separate = await login(api, account);

  const rotated = await api('refresh', { body: { refreshToken: first.refreshToken } });
  assert.equal(rotated.status, 200);
  const pair = await rotated.json();
  assert.deepEqual(Object.keys(pair).sort(), ['accessToken', 'refreshToken']);
  const oldClaims = jwt.decode(first.refreshToken);
  const newClaims = jwt.decode(pair.refreshToken);
  assert.equal(newClaims.exp, oldClaims.exp);
  assert.notEqual(newClaims.jti, oldClaims.jti);
  const valid = await api('me', { accessToken: pair.accessToken });
  assert.equal(valid.status, 200);

  const replay = await api('refresh', { body: { refreshToken: first.refreshToken } });
  assert.equal(replay.status, 401);
  const revokedAccess = await api('me', { accessToken: pair.accessToken });
  assert.equal(revokedAccess.status, 401);
  const revokedRefresh = await api('refresh', { body: { refreshToken: pair.refreshToken } });
  assert.equal(revokedRefresh.status, 401);
  const unaffected = await api('me', { accessToken: separate.accessToken });
  assert.equal(unaffected.status, 200);
});

test('concurrent refresh produces one rotation and commits replay revocation', async (context) => {
  const api = await authApi(context);
  const account = credentials();
  await register(api, account);
  const first = await login(api, account);

  const responses = await Promise.all([0, 1].map(() =>
    api('refresh', { body: { refreshToken: first.refreshToken } })));
  assert.deepEqual(responses.map((response) => response.status).sort(), [200, 401]);
  const pair = await responses.find((response) => response.ok).json();
  const access = await api('me', { accessToken: pair.accessToken });
  assert.equal(access.status, 401);
  const refresh = await api('refresh', { body: { refreshToken: pair.refreshToken } });
  assert.equal(refresh.status, 401);
});

test('logout with a previously rotated refresh token revokes only that session without access credentials', async (context) => {
  const api = await authApi(context);
  const account = credentials();
  await register(api, account);
  const first = await login(api, account);
  const separate = await login(api, account);
  const rotated = await api('refresh', { body: { refreshToken: first.refreshToken } });
  assert.equal(rotated.status, 200);
  const pair = await rotated.json();

  const wrongType = await api('logout', { body: { refreshToken: first.accessToken } });
  assert.equal(wrongType.status, 401);
  const logout = await api('logout', { body: { refreshToken: first.refreshToken } });
  assert.equal(logout.status, 204);
  assert.equal(await logout.text(), '');
  const revokedAccess = await api('me', { accessToken: pair.accessToken });
  assert.equal(revokedAccess.status, 401);
  const revokedRefresh = await api('refresh', { body: { refreshToken: pair.refreshToken } });
  assert.equal(revokedRefresh.status, 401);
  const unaffected = await api('refresh', { body: { refreshToken: separate.refreshToken } });
  assert.equal(unaffected.status, 200);
});

test('Sudoku creates an active puzzle with its own authenticated user and a reproducible server seed', async (context) => {
  const { request, auth } = await startApi(context);
  const accounts = [credentials(), credentials()];
  const users = await Promise.all(accounts.map((account) => register(auth, account)));
  const tokens = await Promise.all(accounts.map((account) => login(auth, account)));
  const [[{ start }]] = await pool.query('SELECT UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3)) AS start');

  const responses = await Promise.all(tokens.map(({ accessToken }) =>
    request('/api/games/sudoku/new', { body: { difficulty: 'easy' }, accessToken })));
  for (const response of responses) assert.equal(response.status, 201);

  const [{ generateSudoku }, payloads] = await Promise.all([
    import('../src/sudoku/generator.ts'),
    Promise.all(responses.map((response) => response.json())),
  ]);
  assert.notEqual(payloads[0].sessionId, payloads[1].sessionId);
  for (const [index, payload] of payloads.entries()) {
    assert.equal(responses[index].headers.get('cache-control'), 'no-store');
    assert.deepEqual(Object.keys(payload).sort(), ['difficulty', 'puzzle', 'sessionId']);
    assert.match(payload.sessionId, /^[1-9][0-9]*$/);
    assert.equal(payload.difficulty, 'easy');
    assert.equal(payload.puzzle.length, 81);
    assert.ok(payload.puzzle.every((digit) => Number.isInteger(digit) && digit >= 0 && digit <= 9));
    assert.equal(payload.puzzle.filter(Boolean).length, 42);

    const [[session]] = await pool.execute(
      `SELECT CAST(game_sessions.user_id AS CHAR) AS userId, games.code, game_sessions.difficulty,
              game_sessions.seed, game_sessions.status, UNIX_TIMESTAMP(started_at) AS started,
              UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3)) AS now, finished_at AS finishedAt
       FROM game_sessions JOIN games ON games.id = game_sessions.game_id
       WHERE game_sessions.id = CAST(? AS UNSIGNED)`, [payload.sessionId]);
    assert.equal(session.userId, users[index].id);
    assert.equal(session.code, 'sudoku');
    assert.equal(session.difficulty, 'easy');
    assert.equal(session.status, 'active');
    assert.equal(session.finishedAt, null);
    assert.ok(Number(session.started) >= Number(start));
    assert.ok(Number(session.started) <= Number(session.now));
    assert.match(session.seed, /^sudoku-v1:[a-f0-9]{32}$/);
    assert.deepEqual(generateSudoku(session.seed).puzzle, payload.puzzle);
  }
});

test('Sudoku rejects missing, expired and wrong-type bearer tokens and expired or revoked MySQL sessions', async (context) => {
  const { request, auth } = await startApi(context);
  const account = credentials();
  const user = await register(auth, account);
  const first = await login(auth, account);
  const second = await login(auth, account);
  const claims = jwt.decode(first.accessToken);

  const assertUnauthorized = async (accessToken) => {
    const response = await request('/api/games/sudoku/new', { body: { difficulty: 'easy' }, accessToken });
    assert.equal(response.status, 401);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  };
  await assertUnauthorized(undefined);
  await assertUnauthorized('malformed');
  await assertUnauthorized(jwt.sign({ ...claims, exp: claims.iat - 1 }, jwtSecrets.access));
  await assertUnauthorized(first.refreshToken);

  await pool.execute('UPDATE auth_sessions SET expires_at = UTC_TIMESTAMP(3) - INTERVAL 1 SECOND WHERE id = ?',
    [claims.sid]);
  await assertUnauthorized(first.accessToken);

  const logout = await auth('logout', { body: { refreshToken: second.refreshToken } });
  assert.equal(logout.status, 204);
  await assertUnauthorized(second.accessToken);

  const [[{ total }]] = await pool.execute('SELECT COUNT(*) AS total FROM game_sessions WHERE user_id = ?', [user.id]);
  assert.equal(Number(total), 0);
});

test('Sudoku rejects malformed input and unsupported difficulty without creating sessions', async (context) => {
  const { request, auth } = await startApi(context);
  const account = credentials();
  const user = await register(auth, account);
  const { accessToken } = await login(auth, account);

  for (const body of ['', [], null, {}, '{broken json', { difficulty: 'medium' }, { difficulty: 'hard' },
    { difficulty: 'EASY' }, { difficulty: 1 }, { difficulty: 'easy', userId: '1' }]) {
    const response = await request('/api/games/sudoku/new', { body, accessToken });
    assert.equal(response.status, 400, JSON.stringify(body));
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  }

  const [[{ total }]] = await pool.execute('SELECT COUNT(*) AS total FROM game_sessions WHERE user_id = ?', [user.id]);
  assert.equal(Number(total), 0);
});

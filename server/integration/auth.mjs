import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { after, before, test } from 'node:test';
import bcrypt from 'bcrypt';
import express from 'express';
import jwt from 'jsonwebtoken';
import { createPool } from 'mysql2/promise';
import { createApp } from '../src/app.ts';
import { requireLiveSession } from '../src/auth/live-session.ts';
import { createTokens } from '../src/auth/tokens.ts';
import { generateSudoku } from '../src/sudoku/generator.ts';
import { createSudokuRouter } from '../src/sudoku/router.ts';
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
  for (const file of ['001_initial.sql', '002_auth_sessions.sql', '003_sudoku_progress.sql']) {
    const sql = await readFile(new URL(`../sql/${file}`, import.meta.url), 'utf8');
    await pool.query(sql);
  }
  schemaReady = true;
});

after(async () => {
  try {
    if (schemaReady) {
      await pool.execute(
        'DELETE scores FROM scores JOIN users ON users.id = scores.user_id WHERE users.username LIKE ?',
        [`${prefix}%`],
      );
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

async function startApi(context, app = createApp({ pool, jwtSecrets })) {
  const { server, request } = await serve(app);
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

  const difficulties = ['easy', 'medium', 'hard'];
  const responses = await Promise.all(difficulties.map((difficulty, index) =>
    request('/api/games/sudoku/new', { body: { difficulty }, accessToken: tokens[index % tokens.length].accessToken })));
  for (const response of responses) assert.equal(response.status, 201);

  const payloads = await Promise.all(responses.map((response) => response.json()));
  assert.equal(new Set(payloads.map(({ sessionId }) => sessionId)).size, difficulties.length);
  for (const [index, payload] of payloads.entries()) {
    const difficulty = difficulties[index];
    assert.equal(responses[index].headers.get('cache-control'), 'no-store');
    assert.deepEqual(Object.keys(payload).sort(), ['difficulty', 'elapsedSec', 'puzzle', 'sessionId']);
    assert.match(payload.sessionId, /^[1-9][0-9]*$/);
    assert.equal(payload.difficulty, difficulty);
    assert.equal(payload.elapsedSec, 0);
    assert.equal(payload.puzzle.length, 81);
    assert.ok(payload.puzzle.every((digit) => Number.isInteger(digit) && digit >= 0 && digit <= 9));
    assert.equal(payload.puzzle.filter(Boolean).length, [42, 34, 28][index]);

    const [[session]] = await pool.execute(
      `SELECT CAST(game_sessions.user_id AS CHAR) AS userId, games.code, game_sessions.difficulty,
              game_sessions.seed, game_sessions.status, UNIX_TIMESTAMP(started_at) AS started,
              UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3)) AS now, finished_at AS finishedAt
       FROM game_sessions JOIN games ON games.id = game_sessions.game_id
       WHERE game_sessions.id = CAST(? AS UNSIGNED)`, [payload.sessionId]);
    assert.equal(session.userId, users[index % users.length].id);
    assert.equal(session.code, 'sudoku');
    assert.equal(session.difficulty, difficulty);
    assert.equal(session.status, 'active');
    assert.equal(session.finishedAt, null);
    assert.ok(Number(session.started) >= Number(start));
    assert.ok(Number(session.started) <= Number(session.now));
    assert.match(session.seed, /^sudoku-v2:[a-f0-9]{32}$/);
    assert.deepEqual(generateSudoku(session.seed, difficulty).puzzle, payload.puzzle);

    const [[progress]] = await pool.execute(
      'SELECT board, mistakes, CAST(move_no AS CHAR) AS moveNo, solved_at AS solvedAt FROM sudoku_progress WHERE session_id = CAST(? AS UNSIGNED)',
      [payload.sessionId],
    );
    assert.deepEqual({ ...progress }, { board: payload.puzzle.join(''), mistakes: 0, moveNo: '0', solvedAt: null });
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
    for (const [endpoint, body] of [
      ['new', { difficulty: 'easy' }],
      ['move', { sessionId: '1', moveNo: 1, cellIndex: 0, value: 1 }],
      ['submit', { sessionId: '1', board: Array(81).fill(1) }],
    ]) {
      const response = await request(`/api/games/sudoku/${endpoint}`, { body, accessToken });
      assert.equal(response.status, 401, endpoint);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      assert.deepEqual(Object.keys(await response.json()), ['error']);
    }
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

  for (const body of ['', [], null, {}, '{broken json', { difficulty: 'expert' },
    { difficulty: 'EASY' }, { difficulty: 1 }, { difficulty: 'easy', userId: '1' }]) {
    const response = await request('/api/games/sudoku/new', { body, accessToken });
    assert.equal(response.status, 400, JSON.stringify(body));
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  }

  const [[{ total }]] = await pool.execute('SELECT COUNT(*) AS total FROM game_sessions WHERE user_id = ?', [user.id]);
  assert.equal(Number(total), 0);
});

async function sudokuPlayer(context) {
  const { request, auth } = await startApi(context);
  const account = credentials();
  const user = await register(auth, account);
  const { accessToken } = await login(auth, account);
  const play = (endpoint, body) => request(`/api/games/sudoku/${endpoint}`, { body, accessToken });
  return { user, auth, request, play };
}

async function startPuzzle(play, difficulty) {
  const response = await play('new', { difficulty });
  assert.equal(response.status, 201);
  const { sessionId, puzzle } = await response.json();
  const [[{ seed }]] = await pool.execute(
    'SELECT seed FROM game_sessions WHERE id = CAST(? AS UNSIGNED)', [sessionId]);
  const { solution } = generateSudoku(seed, difficulty);
  return { sessionId, puzzle, solution };
}

async function sudokuError(response, status) {
  assert.equal(response.status, status);
  assert.deepEqual(Object.keys(await response.json()), ['error']);
}

test('Sudoku returns 503 without a session when generation exhausts its budget', async (context) => {
  const { auth } = await startApi(context);
  const account = credentials();
  const user = await register(auth, account);
  const { accessToken } = await login(auth, account);
  const app = express();
  const authenticate = requireLiveSession(pool, createTokens(jwtSecrets));
  app.use('/api/games/sudoku', createSudokuRouter(pool, authenticate,
    (seed, difficulty) => generateSudoku(seed, difficulty, 0)));
  const { request } = await startApi(context, app);

  await sudokuError(await request('/api/games/sudoku/new', { body: { difficulty: 'hard' }, accessToken }), 503);
  const [[{ total }]] = await pool.execute('SELECT COUNT(*) AS total FROM game_sessions WHERE user_id = ?', [user.id]);
  assert.equal(Number(total), 0);
});

test('Sudoku move and submit validate input, protect ownership, and reject legacy sessions', async (context) => {
  const { user, auth, request, play } = await sudokuPlayer(context);
  const { sessionId, puzzle, solution } = await startPuzzle(play, 'easy');
  const move = { sessionId, moveNo: 1, cellIndex: puzzle.indexOf(0), value: 1 };
  const submit = { sessionId, board: solution };

  for (const body of [[], null, {}, '{broken json', { ...move, sessionId: Number(sessionId) },
    { ...move, sessionId: '0' }, { ...move, moveNo: 0 }, { ...move, moveNo: 1.5 },
    { ...move, moveNo: '1' }, { ...move, moveNo: Number.MAX_SAFE_INTEGER + 1 },
    { ...move, cellIndex: -1 }, { ...move, cellIndex: 81 }, { ...move, value: '1' },
    { ...move, value: 10 }]) {
    await sudokuError(await play('move', body), 400);
  }
  for (const body of [[], null, {}, '{broken json', { ...submit, sessionId: 'x' },
    { ...submit, board: solution.slice(1) }, { ...submit, board: [0, ...solution.slice(1)] },
    { ...submit, board: ['1', ...solution.slice(1)] }]) {
    await sudokuError(await play('submit', body), 400);
  }

  const foreignAccount = credentials();
  await register(auth, foreignAccount);
  const { accessToken } = await login(auth, foreignAccount);
  const lastUnsignedId = '18446744073709551615';
  for (const [endpoint, body] of [['move', move], ['submit', submit]]) {
    await sudokuError(await request(`/api/games/sudoku/${endpoint}`, { body, accessToken }), 404);
    await sudokuError(await play(endpoint, { ...body, sessionId: lastUnsignedId }), 404);
  }
  await sudokuError(await play('move', { ...move, cellIndex: puzzle.findIndex(Boolean) }), 400);
  await sudokuError(await play('submit', submit), 422);
  await sudokuError(await play('submit', { ...submit, board: Array(81).fill(1) }), 422);

  const connection = await pool.getConnection();
  let legacyId;
  let otherGameId;
  try {
    for (const [game, seed, setId] of [
      ['sudoku', `sudoku-v1:${'0'.repeat(32)}`, (id) => { legacyId = id; }],
      ['rubik', null, (id) => { otherGameId = id; }],
    ]) {
      await connection.execute(
        `INSERT INTO game_sessions (user_id, game_id, difficulty, seed)
         SELECT CAST(? AS UNSIGNED), id, 'easy', ? FROM games WHERE code = ?`, [user.id, seed, game]);
      const [[{ id }]] = await connection.query('SELECT CAST(LAST_INSERT_ID() AS CHAR) AS id');
      setId(id);
    }
  } finally {
    connection.release();
  }
  for (const [endpoint, body] of [['move', move], ['submit', submit]]) {
    await sudokuError(await play(endpoint, { ...body, sessionId: legacyId }), 409);
    await sudokuError(await play(endpoint, { ...body, sessionId: otherGameId }), 404);
  }

  const [[{ total }]] = await pool.execute('SELECT COUNT(*) AS total FROM scores WHERE user_id = ?', [user.id]);
  assert.equal(Number(total), 0);
});

test('Sudoku move serializes simultaneous retries and counts only changes to wrong digits', async (context) => {
  const { play } = await sudokuPlayer(context);
  const { sessionId, puzzle, solution } = await startPuzzle(play, 'medium');
  const cellIndex = puzzle.indexOf(0);
  const correctDigit = solution[cellIndex];
  const incorrectDigits = [1, 2, 3].filter((digit) => digit !== correctDigit);
  const [wrong, otherWrong] = incorrectDigits;
  const first = { sessionId, moveNo: 1, cellIndex, value: wrong };
  await sudokuError(await play('move', { ...first, moveNo: 2 }), 409);

  const concurrent = await Promise.all([play('move', first), play('move', first)]);
  assert.deepEqual(concurrent.map(({ status }) => status), [200, 200]);
  const [acknowledged, replayed] = await Promise.all(concurrent.map((response) => response.json()));
  assert.deepEqual(acknowledged, { moveNo: 1, mistakes: 1, correct: false, elapsedSec: acknowledged.elapsedSec, solved: false });
  assert.ok(Number.isInteger(acknowledged.elapsedSec) && acknowledged.elapsedSec >= 0);
  assert.deepEqual(replayed, acknowledged);
  await sudokuError(await play('move', { ...first, value: otherWrong }), 409);

  await pool.execute('UPDATE game_sessions SET started_at = started_at - INTERVAL 30 SECOND WHERE id = ?', [sessionId]);
  const retry = await play('move', first);
  assert.equal(retry.status, 200);
  assert.deepEqual(await retry.json(), acknowledged);

  for (const [moveNo, value, mistakes, correct] of [
    [2, wrong, 1, false],
    [3, otherWrong, 2, false],
    [4, 0, 2, null],
    [5, 0, 2, null],
    [6, correctDigit, 2, true],
  ]) {
    const response = await play('move', { sessionId, moveNo, cellIndex, value, mistakes: 900, elapsedSec: 0 });
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.ok(Number.isInteger(result.elapsedSec) && result.elapsedSec >= 30);
    assert.deepEqual(result, { moveNo, mistakes, correct, elapsedSec: result.elapsedSec, solved: false });
  }
  await sudokuError(await play('move', first), 409);
  const [[progress]] = await pool.execute(
    'SELECT board, mistakes, CAST(move_no AS CHAR) AS moveNo FROM sudoku_progress WHERE session_id = ?', [sessionId]);
  puzzle[cellIndex] = correctDigit;
  assert.deepEqual({ ...progress }, { board: puzzle.join(''), mistakes: 2, moveNo: '6' });

  const competingMoves = [wrong, otherWrong].map((value) => ({ sessionId, moveNo: 7, cellIndex, value }));
  const competing = await Promise.all(competingMoves.map((body) => play('move', body)));
  assert.deepEqual(competing.map(({ status }) => status).sort(), [200, 409]);
  const winner = competing.findIndex(({ ok }) => ok);
  const winnerResult = await competing[winner].json();
  assert.equal(winnerResult.mistakes, 3);
  const replayedWinner = await play('move', competingMoves[winner]);
  assert.equal(replayedWinner.status, 200);
  assert.deepEqual(await replayedWinner.json(), winnerResult);
});

test('Sudoku submit freezes authoritative scores for each difficulty and commits one result under concurrency', async (context) => {
  const { play, user } = await sudokuPlayer(context);
  for (const [difficulty, maximum, startOffset] of [
    ['easy', 1000, 20], ['medium', 1500, 30], ['hard', 2000, 40], ['hard', 2000, 1100],
  ]) {
    const { sessionId, puzzle, solution } = await startPuzzle(play, difficulty);
    await pool.execute(
      'UPDATE game_sessions SET started_at = CURRENT_TIMESTAMP(3) - INTERVAL ? SECOND WHERE id = ?', [startOffset, sessionId]);
    const firstBlank = puzzle.indexOf(0);
    let moveNo = 1;
    const wrongDigit = solution[firstBlank] % 9 + 1;
    const wrong = await play('move', { sessionId, moveNo, cellIndex: firstBlank, value: wrongDigit });
    assert.equal(wrong.status, 200);
    assert.equal((await wrong.json()).mistakes, 1);

    let lastMove;
    let lastAcknowledgement;
    for (const [cellIndex, given] of puzzle.entries()) {
      if (given) continue;
      lastMove = { sessionId, moveNo: ++moveNo, cellIndex, value: solution[cellIndex] };
      const response = await play('move', lastMove);
      assert.equal(response.status, 200);
      lastAcknowledgement = await response.json();
      assert.equal(lastAcknowledgement.solved, cellIndex === puzzle.lastIndexOf(0));
    }
    assert.deepEqual(lastAcknowledgement, {
      moveNo, mistakes: 1, correct: true, elapsedSec: lastAcknowledgement.elapsedSec, solved: true,
    });
    assert.ok(Number.isInteger(lastAcknowledgement.elapsedSec) && lastAcknowledgement.elapsedSec >= startOffset);
    const replay = await play('move', lastMove);
    assert.equal(replay.status, 200);
    assert.deepEqual(await replay.json(), lastAcknowledgement);
    await sudokuError(await play('move', { ...lastMove, moveNo: moveNo + 1 }), 409);
    await sudokuError(await play('submit', { sessionId, board: Array(81).fill(1) }), 422);

    if (difficulty === 'easy') await delay(1100);
    const submission = { sessionId, board: solution, durationSec: 0, mistakes: 0, score: 3000 };
    const responses = await Promise.all([play('submit', submission), play('submit', submission)]);
    const expected = {
      sessionId, difficulty, durationSec: lastAcknowledgement.elapsedSec, mistakes: 1,
      score: Math.max(0, maximum - 2 * lastAcknowledgement.elapsedSec - 50),
    };
    if (startOffset === 1100) assert.equal(expected.score, 0);
    for (const response of responses) {
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), expected);
    }
    const completedReplay = await play('move', lastMove);
    assert.equal(completedReplay.status, 200);
    assert.deepEqual(await completedReplay.json(), lastAcknowledgement);
    await sudokuError(await play('move', { ...lastMove, value: 0 }), 409);
    await sudokuError(await play('submit', { sessionId, board: Array(81).fill(1) }), 422);

    const [results] = await pool.execute(
      `SELECT CAST(scores.user_id AS CHAR) AS userId, games.code, scores.difficulty, scores.score,
              scores.duration_sec AS durationSec, scores.mistakes, game_sessions.status,
              game_sessions.finished_at = sudoku_progress.solved_at AS finishedOnSolve,
              TIMESTAMPDIFF(SECOND, game_sessions.started_at, sudoku_progress.solved_at) AS recordedDuration,
              TIMESTAMPDIFF(SECOND, sudoku_progress.solved_at, scores.created_at) AS submissionDelay
       FROM scores JOIN game_sessions ON game_sessions.id = scores.session_id
       JOIN sudoku_progress ON sudoku_progress.session_id = scores.session_id
       JOIN games ON games.id = scores.game_id
       WHERE scores.session_id = CAST(? AS UNSIGNED)`, [sessionId]);
    assert.equal(results.length, 1);
    const [saved] = results;
    assert.equal(saved.userId, user.id);
    assert.equal(saved.code, 'sudoku');
    assert.equal(saved.difficulty, difficulty);
    assert.equal(saved.score, expected.score);
    assert.equal(saved.durationSec, expected.durationSec);
    assert.equal(saved.mistakes, 1);
    assert.equal(saved.status, 'completed');
    assert.equal(Number(saved.finishedOnSolve), 1);
    assert.equal(Number(saved.recordedDuration), expected.durationSec);
    if (difficulty === 'easy') assert.ok(Number(saved.submissionDelay) >= 1);
  }
});

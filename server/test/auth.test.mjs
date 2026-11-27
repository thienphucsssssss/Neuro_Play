import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { test } from 'node:test';
import { createApp } from '../src/app.ts';
import { close, serve } from '../test-support/http.mjs';

const jwtSecrets = {
  access: randomBytes(32),
  refresh: randomBytes(32),
};

test('auth rejects invalid input as uncached JSON and keeps health public', async (context) => {
  const { server, request } = await serve(createApp({ pool: {}, jwtSecrets }));
  context.after(() => close(server));

  for (const body of [{}, [], null, '{broken json']) {
    const response = await request('/api/auth/register', { body });
    assert.equal(response.status, 400);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  }

  for (const path of ['/api/auth/login', '/api/auth/refresh', '/api/auth/logout']) {
    const response = await request(path, { body: {} });
    assert.equal(response.status, 400);
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  }

  const unauthorized = await request('/api/auth/me');
  assert.equal(unauthorized.status, 401);
  assert.deepEqual(Object.keys(await unauthorized.json()), ['error']);

  const health = await request('/health');
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: 'ok' });
});

test('each public auth endpoint enforces its own per-IP request limit', async (context) => {
  const { server, request } = await serve(createApp({ pool: {}, jwtSecrets }));
  context.after(() => close(server));

  for (const [path, limit] of [['register', 10], ['login', 20], ['refresh', 120]]) {
    for (let index = 0; index < limit; index++) {
      const response = await request(`/api/auth/${path}`, {
        body: {},
        headers: { 'x-forwarded-for': `192.0.2.${index + 1}` },
      });
      assert.equal(response.status, 400);
      await response.json();
    }

    const response = await request(`/api/auth/${path}`, { body: {} });
    assert.equal(response.status, 429);
    assert.ok(Number(response.headers.get('retry-after')) > 0);
    assert.deepEqual(Object.keys(await response.json()), ['error']);
  }
});

test('registration rejects non-ASCII username letters even when they lowercase to ASCII', async (context) => {
  const { server, request } = await serve(createApp({ pool: {}, jwtSecrets }));
  context.after(() => close(server));

  const response = await request('/api/auth/register', {
    body: { username: 'Kelvin', email: 'kelvin@example.test', password: 'a long password here' },
  });
  assert.equal(response.status, 400);
  assert.deepEqual(Object.keys(await response.json()), ['error']);
});

test('malformed JWT JSON is reported as invalid credentials', async (context) => {
  const { server, request } = await serve(createApp({ pool: {}, jwtSecrets }));
  context.after(() => close(server));

  const header = Buffer.from('{"alg":"HS256","typ":"JWT"}').toString('base64url');
  const payload = Buffer.from('{').toString('base64url');
  const response = await request('/api/auth/me', { accessToken: `${header}.${payload}.invalid` });
  assert.equal(response.status, 401);
  assert.deepEqual(Object.keys(await response.json()), ['error']);
});

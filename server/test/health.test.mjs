import assert from 'node:assert/strict';
import { once } from 'node:events';
import { test } from 'node:test';
import { createApp } from '../src/app.ts';

test('GET /health responds with a successful JSON status', async (context) => {
  const server = createApp().listen(0, '127.0.0.1');
  context.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  await once(server, 'listening');
  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/health`);
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.deepEqual(JSON.parse(body), { status: 'ok' });
});

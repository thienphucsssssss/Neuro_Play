import { once } from 'node:events';

export async function serve(app) {
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const { port } = server.address();

  return {
    server,
    request(path, { body, accessToken, headers = {} } = {}) {
      if (body !== undefined) headers['content-type'] = 'application/json';
      if (accessToken !== undefined) headers.authorization = `Bearer ${accessToken}`;

      return fetch(`http://127.0.0.1:${port}${path}`, {
        method: body === undefined ? 'GET' : 'POST',
        headers,
        body: typeof body === 'string' ? body : JSON.stringify(body),
      });
    },
  };
}

export function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
}

import { createServer } from 'node:http';
import { Server as SocketServer } from 'socket.io';
import { createApp } from './app.ts';
import { createDatabasePool } from './config/database.ts';
import { parsePort, readJwtSecrets } from './config/env.ts';

const host = process.env.HOST ?? '127.0.0.1';
const port = parsePort(process.env.PORT ?? '3000', 'PORT');
const jwtSecrets = readJwtSecrets();
const server = createServer(createApp({ pool: createDatabasePool(), jwtSecrets }));
new SocketServer(server);

server.listen(port, host, () => {
  console.log(`API listening at http://${host}:${port}`);
});

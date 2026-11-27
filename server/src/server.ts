import { createServer } from 'node:http';
import { Server as SocketServer } from 'socket.io';
import { createApp } from './app.ts';
import { parsePort } from './config/env.ts';

const host = process.env.HOST ?? '127.0.0.1';
const port = parsePort(process.env.PORT ?? '3000', 'PORT');
const server = createServer(createApp());
new SocketServer(server);

server.listen(port, host, () => {
  console.log(`API listening at http://${host}:${port}`);
});

import { createConnection, createPool } from 'mysql2/promise';
import { parsePort } from './env.ts';

function databaseOptions() {
  const { DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD } = process.env;
  if (!DB_NAME || !DB_USER || !DB_PASSWORD) {
    throw new Error('Configure DB_NAME, DB_USER and DB_PASSWORD in server/.env.');
  }

  return {
    host: DB_HOST ?? '127.0.0.1',
    port: parsePort(DB_PORT ?? '3307', 'DB_PORT'),
    database: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    connectTimeout: 5000,
  };
}

export function connectDatabase() {
  return createConnection(databaseOptions());
}

export function createDatabasePool() {
  return createPool({ ...databaseOptions(), timezone: 'Z' });
}

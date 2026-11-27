import type { RowDataPacket } from 'mysql2/promise';
import { connectDatabase } from './config/database.ts';

try {
  const connection = await connectDatabase();
  try {
    const [rows] = await connection.query<RowDataPacket[]>(
      'SELECT VERSION() AS version, DATABASE() AS database_name',
    );
    const [games] = await connection.query<RowDataPacket[]>(
      'SELECT code FROM games ORDER BY code',
    );
    console.log(`MySQL ${rows[0].version}, database ${rows[0].database_name}`);
    console.log(`Games: ${games.map((game) => game.code).join(', ')}`);
  } finally {
    await connection.end();
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}

// backend/src/config/migrate.js
// Simple migration runner — run via: node src/config/migrate.js
// Or via docker exec after container starts

require('dotenv').config();
const { Client } = require('pg');
const fs   = require('fs');
const path = require('path');

async function runMigrations() {
  const client = new Client({
    host:     process.env.DB_HOST     || 'localhost',
    port:     parseInt(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME     || 'flowpath_db',
    user:     process.env.DB_USER     || 'flowpath_user',
    password: process.env.DB_PASSWORD,
  });

  try {
    await client.connect();
    console.log('✅ Connected to database');

    const migrationsDir = path.join(__dirname, '../../../database/migrations');
    if (!fs.existsSync(migrationsDir)) {
      console.log('No migrations directory found at', migrationsDir);
      return;
    }

    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      console.log(`Running: ${file}`);
      try {
        await client.query(sql);
        console.log(`  ✅ ${file} done`);
      } catch (err) {
        console.log(`  ⚠️  ${file} skipped (${err.message.split('\n')[0]})`);
      }
    }

    console.log('✅ All migrations complete');
  } finally {
    await client.end();
  }
}

runMigrations().catch(err => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});

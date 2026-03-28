// backend/src/server.js
// Fixed: startBroadcastIntervals() called AFTER DB is ready.
require('dotenv').config();
const http    = require('http');
const { Server } = require('socket.io');
const app     = require('./app');
const { connectDatabase } = require('./config/database');
const { setupSocketHandlers, startBroadcastIntervals } = require('./services/socketService');
const logger  = require('./utils/logger');

const PORT   = parseInt(process.env.PORT) || 3000;
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin:  process.env.SOCKET_CORS_ORIGIN || '*',
    methods: ['GET','POST'],
    credentials: true,
  },
  pingTimeout:  parseInt(process.env.SOCKET_PING_TIMEOUT)  || 60000,
  pingInterval: parseInt(process.env.SOCKET_PING_INTERVAL) || 25000,
  transports: ['websocket','polling'],
});

app.set('io', io);

// Register connection handlers immediately (no DB needed)
setupSocketHandlers(io);

const startServer = async () => {
  let retries = 5;
  while (retries > 0) {
    try {
      await connectDatabase();
      break; // success
    } catch (err) {
      retries--;
      if (retries === 0) {
        logger.error('❌ Could not connect to database after 5 attempts. Exiting.');
        process.exit(1);
      }
      logger.warn(`⚠️  DB not ready, retrying in 5s... (${retries} attempts left)`);
      await new Promise(r => setTimeout(r, 5000));
    }
  }

  // Only start broadcast intervals AFTER DB is confirmed ready
  startBroadcastIntervals(io);

  server.listen(PORT, '0.0.0.0', () => {
    logger.info('═══════════════════════════════════════════');
    logger.info(`🛣️  FlowPath AI API running on port ${PORT}`);
    logger.info(`📡 Socket.IO real-time ready`);
    logger.info(`🌍 Environment: ${process.env.NODE_ENV}`);
    logger.info('═══════════════════════════════════════════');
  });
};

const shutdown = async (signal) => {
  logger.info(`${signal} — shutting down`);
  server.close(async () => {
    const { sequelize } = require('./config/database');
    await sequelize.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => logger.error('Unhandled rejection: ' + reason));
process.on('uncaughtException',  (err)    => { logger.error('Uncaught exception: ' + err.message); process.exit(1); });

startServer();

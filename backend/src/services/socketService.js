// backend/src/services/socketService.js
// Fixed: intervals only start AFTER database is confirmed ready.
const logger = require('../utils/logger');
let _intervalsStarted = false;

const setupSocketHandlers = (io) => {
  logger.info('📡 Initialising Socket.IO handlers');

  io.on('connection', (socket) => {
    logger.debug(`Socket connected: ${socket.id}`);

    socket.on('join:user', ({ userId }) => {
      if (!userId) return;
      socket.join(`user:${userId}`);
      socket.userId = userId;
      socket.emit('joined', { room: `user:${userId}` });
    });

    socket.on('join:admin', () => {
      socket.join('admin-room');
      socket.emit('joined', { room: 'admin-room' });
    });

    socket.on('vehicle:location', async (data) => {
      const { userId, lat, lon, speedKmh, heading } = data;
      if (!userId || lat == null || lon == null) return;
      try {
        const Vehicle = require('../models/Vehicle');
        await Vehicle.update(
          { current_lat: lat, current_lon: lon, speed_kmh: speedKmh || 0,
            heading: heading || 0, last_updated: new Date(),
            socket_id: socket.id, is_navigating: true },
          { where: { user_id: userId } }
        );
        io.to('admin-room').emit('vehicle:update', { userId, lat, lon, speedKmh, heading, timestamp: Date.now() });
      } catch (err) {
        logger.debug('vehicle:location skipped: ' + err.message);
      }
    });

    socket.on('navigation:start', ({ userId, routeId }) => {
      if (routeId) socket.join(`route:${routeId}`);
      io.to('admin-room').emit('navigation:started', { userId, routeId, timestamp: Date.now() });
    });

    socket.on('navigation:end', async ({ userId, routeId }) => {
      if (routeId) socket.leave(`route:${routeId}`);
      io.to('admin-room').emit('navigation:ended', { userId, routeId, timestamp: Date.now() });
      try {
        const Vehicle = require('../models/Vehicle');
        await Vehicle.update({ is_navigating: false }, { where: { user_id: userId } });
      } catch (_) {}
    });

    socket.on('disconnect', () => {
      logger.debug(`Socket disconnected: ${socket.id}`);
    });
  });

  logger.info('✅ Socket.IO handlers registered');
};

// Called ONLY after DB is confirmed ready
const startBroadcastIntervals = (io) => {
  if (_intervalsStarted) return;
  _intervalsStarted = true;
  logger.info('📡 Starting real-time broadcast intervals');

  const TrafficSignal = require('../models/TrafficSignal');
  const Vehicle       = require('../models/Vehicle');

  // Signal phases — every 1 second
  setInterval(async () => {
    try {
      const signals = await TrafficSignal.findAll({
        where: { is_active: true },
        attributes: ['id','intersection_name','latitude','longitude',
                     'green_duration','yellow_duration','red_duration','cycle_time','offset'],
        limit: 300, raw: true,
      });
      if (!signals.length) return;
      const now = new Date();
      const payload = signals.map(s => {
        const cycle   = parseInt(s.cycle_time) || 110;
        const elapsed = (Math.floor(now.getTime() / 1000) + (parseInt(s.offset) || 0)) % cycle;
        const g = parseInt(s.green_duration)  || 45;
        const y = parseInt(s.yellow_duration) || 5;
        const r = parseInt(s.red_duration)    || 60;
        let phase, remaining, nextGreenIn;
        if (elapsed < g) {
          phase = 'green';  remaining = g - elapsed;           nextGreenIn = 0;
        } else if (elapsed < g + y) {
          phase = 'yellow'; remaining = g + y - elapsed;       nextGreenIn = remaining + r;
        } else {
          phase = 'red';    remaining = cycle - elapsed;       nextGreenIn = remaining;
        }
        return { id: s.id, intersectionName: s.intersection_name,
                 latitude: parseFloat(s.latitude), longitude: parseFloat(s.longitude),
                 phase, remaining, nextGreenIn };
      });
      io.emit('signals:update', { signals: payload, count: payload.length, timestamp: now.toISOString() });
    } catch (err) {
      logger.debug('Signal broadcast skipped: ' + err.message);
    }
  }, 1000);

  // Congestion alerts — every 30 seconds
  setInterval(async () => {
    try {
      const vehicles = await Vehicle.findAll({ where: { is_navigating: true }, raw: true });
      if (!vehicles.length) return;
      const slow  = vehicles.filter(v => parseFloat(v.speed_kmh) < 15);
      const ratio = slow.length / vehicles.length;
      const level = ratio > 0.5 ? 'high' : ratio > 0.25 ? 'moderate' : null;
      if (level) {
        io.emit('congestion:alert', {
          level, vehiclesAffected: slow.length, totalVehicles: vehicles.length,
          message: level === 'high' ? 'Heavy congestion — recalculating' : 'Moderate traffic ahead',
          timestamp: new Date().toISOString(),
        });
      }
    } catch (_) {}
  }, 30000);

  logger.info('✅ Broadcast intervals started');
};

module.exports = { setupSocketHandlers, startBroadcastIntervals };

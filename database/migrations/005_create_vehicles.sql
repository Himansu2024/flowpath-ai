CREATE TABLE IF NOT EXISTS vehicles (
  vehicle_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  current_lat     DECIMAL(10,8),
  current_lon     DECIMAL(11,8),
  speed_kmh       DECIMAL(5,2) DEFAULT 0,
  heading         DECIMAL(5,2) DEFAULT 0,
  destination_lat DECIMAL(10,8),
  destination_lon DECIMAL(11,8),
  route_id        UUID,
  vehicle_type    VARCHAR(20) DEFAULT 'car',
  is_navigating   BOOLEAN DEFAULT false,
  socket_id       VARCHAR(100),
  last_updated    TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT one_vehicle_per_user UNIQUE(user_id)
);
CREATE INDEX IF NOT EXISTS idx_vehicles_navigating ON vehicles(is_navigating);

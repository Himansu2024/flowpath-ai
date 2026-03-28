CREATE TABLE IF NOT EXISTS routes (
  route_id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                 UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  start_lat               DECIMAL(10,8) NOT NULL,
  start_lon               DECIMAL(11,8) NOT NULL,
  end_lat                 DECIMAL(10,8) NOT NULL,
  end_lon                 DECIMAL(11,8) NOT NULL,
  start_address           TEXT,
  end_address             TEXT,
  distance_km             DECIMAL(8,3),
  estimated_duration_min  INTEGER,
  actual_duration_min     INTEGER,
  signal_sequence         JSONB DEFAULT '[]',
  waypoints               JSONB DEFAULT '[]',
  osrm_route              JSONB,
  greenwave_score         DECIMAL(5,2) DEFAULT 0,
  stops_avoided           INTEGER DEFAULT 0,
  fuel_saved_ml           INTEGER DEFAULT 0,
  co2_saved_g             INTEGER DEFAULT 0,
  status                  VARCHAR(20) DEFAULT 'planned',
  started_at              TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_routes_user_id ON routes(user_id);
CREATE INDEX IF NOT EXISTS idx_routes_status  ON routes(status);

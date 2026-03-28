CREATE TABLE IF NOT EXISTS traffic_signals (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  intersection_name VARCHAR(200) NOT NULL,
  latitude          DECIMAL(10,8) NOT NULL,
  longitude         DECIMAL(11,8) NOT NULL,
  green_duration    INTEGER NOT NULL DEFAULT 45,
  yellow_duration   INTEGER NOT NULL DEFAULT 5,
  red_duration      INTEGER NOT NULL DEFAULT 60,
  cycle_time        INTEGER DEFAULT 110,
  offset_seconds    INTEGER DEFAULT 0,
  current_phase     VARCHAR(10) DEFAULT 'red',
  seconds_remaining INTEGER DEFAULT 0,
  road_name         VARCHAR(200),
  city              VARCHAR(100) DEFAULT 'Bengaluru',
  zone              VARCHAR(100),
  avg_wait_time     DECIMAL(5,2) DEFAULT 0,
  efficiency_score  DECIMAL(5,2) DEFAULT 100,
  is_active         BOOLEAN DEFAULT true,
  atms_id           VARCHAR(100),
  metadata          JSONB DEFAULT '{}',
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_signals_city   ON traffic_signals(city, zone);
CREATE INDEX IF NOT EXISTS idx_signals_active ON traffic_signals(is_active);

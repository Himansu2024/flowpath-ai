CREATE TABLE IF NOT EXISTS users (
  user_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email             VARCHAR(255) UNIQUE NOT NULL,
  password_hash     VARCHAR(255) NOT NULL,
  full_name         VARCHAR(100),
  phone             VARCHAR(20),
  role              VARCHAR(30) DEFAULT 'user',
  vehicle_type      VARCHAR(20) DEFAULT 'car',
  eco_score         DECIMAL(5,2) DEFAULT 100.00,
  total_trips       INTEGER DEFAULT 0,
  total_distance_km DECIMAL(10,2) DEFAULT 0.00,
  fuel_saved_litres DECIMAL(8,3) DEFAULT 0.000,
  is_active         BOOLEAN DEFAULT true,
  last_login        TIMESTAMPTZ,
  push_token        TEXT,
  preferences       JSONB DEFAULT '{"voice_navigation":true,"eco_mode":true,"notifications":true}',
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

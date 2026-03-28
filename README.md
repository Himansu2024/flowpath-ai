# FlowPath AI 🛣️

**Smart Traffic Navigation Platform — GreenWave Optimization Engine**

See full documentation in [`docs/README.md`](docs/README.md).

## Quick Start

```bash
# Clone
git clone https://github.com/YOUR_ORG/flowpath-ai.git && cd flowpath-ai

# Configure
cp backend/.env.example backend/.env

# Start everything
docker-compose -f docker/docker-compose.yml up -d

# Seed Bengaluru signals (40 real intersections)
docker exec flowpath-db psql -U flowpath_user -d flowpath_db \
  -f /docker-entrypoint-initdb.d/bangalore_signals.sql

# API health check
curl http://localhost:3000/health
```

**API**: http://localhost:3000 | **AI Engine**: http://localhost:8000/docs | **Dashboard**: http://localhost:3001

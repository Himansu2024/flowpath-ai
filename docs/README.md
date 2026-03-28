# 🛣️ FlowPath AI — Smart Traffic Navigation Platform

> **GreenWave optimization engine that eliminates traffic stops by predicting signal timing and recommending optimal driving speeds.**

[![CI/CD](https://github.com/YOUR_ORG/flowpath-ai/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/YOUR_ORG/flowpath-ai/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📐 System Architecture

```
Flutter Mobile App
       ↓ HTTPS / WebSocket
AWS CloudFront CDN
       ↓
AWS EC2 — Node.js + Express REST API + Socket.IO
       ↓                        ↓
AWS RDS PostgreSQL+PostGIS   Python FastAPI
   (geospatial queries)       AI Engine
                                  ↓
                            AWS Lambda
                          (batch predictions)
```

---

## 📁 Repository Structure

```
flowpath-ai/
├── backend/                    Node.js + Express API
│   ├── src/
│   │   ├── config/             DB + AWS configuration
│   │   ├── controllers/        Request handlers
│   │   ├── services/           GreenWave + routing + Socket.IO
│   │   ├── models/             Sequelize ORM models
│   │   ├── routes/             Express routers
│   │   ├── middleware/         JWT auth + rate limiting
│   │   ├── utils/              Logger, geo math, speed optimizer
│   │   ├── app.js              Express app setup
│   │   └── server.js           HTTP + Socket.IO server
│   ├── .env.example
│   └── package.json
│
├── ai-engine/                  Python FastAPI AI service
│   ├── app/
│   │   ├── main.py             FastAPI application
│   │   ├── routers/            prediction + optimization endpoints
│   │   └── services/           GreenWave algorithm
│   ├── tests/                  Unit tests (pytest)
│   └── requirements.txt
│
├── database/
│   ├── migrations/             PostgreSQL + PostGIS schema (001–005)
│   └── seeds/                  40 Bengaluru signal locations
│
├── mobile/flowpath_app/        Flutter mobile application
│   ├── lib/
│   │   ├── main.dart           App entry + auth
│   │   ├── screens/            home, navigation, analytics, settings
│   │   ├── widgets/            signal countdown, speed advisor, score
│   │   ├── providers/          auth + navigation state
│   │   ├── services/           API client + Socket.IO + GPS
│   │   └── models/             Signal, Route, User
│   └── pubspec.yaml
│
├── dashboard/                  React admin dashboard
│   ├── src/
│   │   ├── pages/Dashboard.jsx Live map + vehicles + signals
│   │   └── App.js
│   └── package.json
│
├── infrastructure/
│   ├── terraform/              AWS EC2, RDS, S3, CloudFront, Lambda
│   └── scripts/deploy.sh       One-command deployment
│
├── docker/
│   ├── Dockerfile.backend      Multi-stage Node.js image
│   ├── Dockerfile.ai           Python 3.11 image
│   └── docker-compose.yml      4-service local dev stack
│
├── .github/workflows/ci-cd.yml  Test → Build → Migrate → Deploy
└── docs/
    ├── README.md               This file
    ├── API.md                  REST API reference
    └── DEPLOYMENT.md           Full deployment guide
```

---

## 🚀 Quick Start (Local Development)

### Prerequisites
- Docker Desktop
- Node.js 20+
- Python 3.11+
- Flutter 3.16+
- Git

### 1. Clone and configure
```bash
git clone https://github.com/YOUR_ORG/flowpath-ai.git
cd flowpath-ai
cp backend/.env.example backend/.env
# Edit backend/.env — fill in JWT_SECRET at minimum
```

### 2. Start all services
```bash
docker-compose -f docker/docker-compose.yml up -d
```

Services:
| Service     | Port  | URL                          |
|-------------|-------|------------------------------|
| API         | 3000  | http://localhost:3000/health |
| AI Engine   | 8000  | http://localhost:8000/docs   |
| PostgreSQL  | 5432  | localhost:5432               |
| Redis       | 6379  | localhost:6379               |
| Dashboard   | 3001  | http://localhost:3001        |

### 3. Seed Bengaluru signals
```bash
docker exec flowpath-db psql -U flowpath_user -d flowpath_db \
  -f /docker-entrypoint-initdb.d/bangalore_signals.sql
```

### 4. Test the API
```bash
# Register
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@flowpath.in","password":"password123","fullName":"Test"}'

# Navigate from Koramangala to MG Road
curl -X POST http://localhost:3000/api/v1/navigation/start \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"startLat":12.9352,"startLon":77.6245,"endLat":12.9756,"endLon":77.6099}'
```

---

## 📱 Flutter App Build

```bash
cd mobile/flowpath_app
flutter pub get

# Development (connected device / emulator)
flutter run

# Android APK
flutter build apk --release

# Google Play AAB
flutter build appbundle --release
```

### Google Play Store Publishing
1. Generate keystore: `keytool -genkey -v -keystore flowpath.jks -keyAlias flowpath -keyalg RSA -keysize 2048 -validity 10000`
2. Create `android/key.properties`:
   ```
   storePassword=YOUR_STORE_PASS
   keyPassword=YOUR_KEY_PASS
   keyAlias=flowpath
   storeFile=../flowpath.jks
   ```
3. Update `android/app/build.gradle` with signing config
4. Build: `flutter build appbundle --release`
5. Upload AAB to Google Play Console → Production track

---

## ☁️ AWS Deployment

```bash
cd infrastructure/terraform
terraform init
terraform plan \
  -var="key_pair_name=flowpath-key" \
  -var="db_username=flowpath_admin" \
  -var="db_password=SecurePassword123!" \
  -var="admin_ip=$(curl -s ifconfig.me)/32" \
  -var="github_org=YOUR_ORG"
terraform apply
```

After apply, note the outputs:
- `cloudfront_domain` → your API base URL
- `rds_endpoint` → database host
- `ssh_command` → connect to EC2

---

## 🔧 Environment Variables

| Variable              | Required | Description                           |
|-----------------------|----------|---------------------------------------|
| `DB_HOST`             | ✅       | PostgreSQL host                       |
| `DB_PASSWORD`         | ✅       | PostgreSQL password                   |
| `JWT_SECRET`          | ✅       | JWT signing secret (min 32 chars)     |
| `AI_ENGINE_URL`       | ✅       | Python FastAPI service URL            |
| `AI_ENGINE_API_KEY`   | ✅       | API key for AI engine auth            |
| `REDIS_URL`           | ✅       | Redis connection string               |
| `AWS_ACCESS_KEY_ID`   | ⬜       | AWS credentials (production only)     |
| `AWS_SECRET_ACCESS_KEY` | ⬜     | AWS credentials (production only)     |

---

## 📡 API Reference

| Method | Endpoint                    | Auth | Description                        |
|--------|-----------------------------|------|------------------------------------|
| POST   | `/auth/register`            | ❌   | Create user account                |
| POST   | `/auth/login`               | ❌   | Get JWT token                      |
| GET    | `/auth/me`                  | ✅   | Get profile                        |
| POST   | `/navigation/start`         | ✅   | Start navigation session           |
| POST   | `/vehicle/location`         | ✅   | Update live GPS position           |
| GET    | `/optimal-speed`            | ✅   | Get speed recommendation           |
| GET    | `/signals`                  | ✅   | All active signals                 |
| GET    | `/signals/nearby`           | ✅   | Signals near coordinates           |
| GET    | `/signal/:id`               | ✅   | Single signal with current state   |
| GET    | `/eco-stats`                | ✅   | User eco-driving statistics        |
| GET    | `/trip-history`             | ✅   | Paginated trip history             |
| GET    | `/parking-nearby`           | ✅   | Parking spots near coordinates     |

### WebSocket Events (Socket.IO)

**Client → Server:**
- `join:user` `{ userId }` — join personal room
- `join:admin` `{ token }` — join admin monitoring room
- `vehicle:location` `{ userId, lat, lon, speedKmh, heading }` — live position
- `navigation:start` `{ userId, routeId }` — navigation started
- `navigation:end` `{ userId, routeId, stats }` — navigation ended

**Server → Client:**
- `signals:update` — signal phases broadcast every **1 second**
- `congestion:alert` — congestion detected (every 30s if active)
- `vehicle:update` — vehicle position (admin dashboard only)
- `navigation:rerouting` — off-route detected

---

## 🌊 GreenWave Algorithm

```
arrival_time = distance / vehicle_speed
elapsed_at_arrival = (epoch_time + arrival_time + signal.offset) % cycle_time

if elapsed_at_arrival < green_duration:
    → MAINTAIN speed (already on green path)
else:
    next_green_in = remaining_red_time
    optimal_speed = distance / next_green_in  (converted to km/h)
    if MIN_SPEED ≤ optimal_speed ≤ MAX_SPEED:
        → ADJUST speed (slow down or speed up)
    else:
        → STOP (unavoidable red)
```

---

## 🏗️ Technology Stack

| Layer         | Technology                        |
|---------------|-----------------------------------|
| Mobile App    | Flutter 3, Dart                   |
| Backend API   | Node.js 20, Express, Socket.IO    |
| AI Engine     | Python 3.11, FastAPI, NumPy       |
| Database      | PostgreSQL 15 + PostGIS 3.3       |
| Cache         | Redis 7                           |
| Maps          | OpenStreetMap + Leaflet (free)    |
| Routing       | OSRM (free, full India)           |
| Containerisation | Docker, Docker Compose         |
| Cloud         | AWS (EC2, RDS, S3, CloudFront, Lambda, ECR) |
| CI/CD         | GitHub Actions                    |

---

## 📄 License

MIT License — see [LICENSE](LICENSE)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -m 'feat: add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

---

*Built with ❤️ for smarter cities and cleaner air.*

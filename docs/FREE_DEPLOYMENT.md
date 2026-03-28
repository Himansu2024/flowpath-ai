# FlowPath AI — 100% Free Cloud Deployment Guide

## Free Stack (Zero Cost Forever)
| Service       | Provider       | Free Limit         | Link                    |
|---------------|----------------|--------------------|-------------------------|
| PostgreSQL DB | Supabase       | 500MB, PostGIS ✅  | supabase.com            |
| Redis Cache   | Upstash        | 10,000 cmds/day    | upstash.com             |
| Backend API   | Render.com     | 750 hrs/month      | render.com              |
| AI Engine     | Render.com     | 750 hrs/month      | render.com              |
| Mobile App    | Direct APK     | Unlimited          | —                       |

Total monthly cost: **₹0**

---

## STEP 1 — Supabase Free PostgreSQL (5 minutes)

1. Go to **supabase.com** → Sign Up Free (use GitHub login)
2. Click **New Project**
   - Name: `flowpath`
   - Password: create a strong password (SAVE IT)
   - Region: **Southeast Asia (Singapore)** — closest to India
3. Wait 2 minutes for project to create
4. Go to **Settings → Database**
5. Scroll to **Connection string → URI** — copy it, looks like:
   `postgresql://postgres:YOUR_PASSWORD@db.xxx.supabase.co:5432/postgres`

### Run Migrations on Supabase
1. Go to **SQL Editor** in Supabase dashboard
2. Click **New query**
3. Paste and run each file one by one:
   - `database/migrations/001_create_extensions.sql`
   - `database/migrations/002_create_users.sql`
   - `database/migrations/003_create_traffic_signals.sql`
   - `database/migrations/004_create_routes.sql`
   - `database/migrations/005_create_vehicles.sql`
   - `database/seeds/bangalore_signals.sql`
4. Click **Run** after each one

---

## STEP 2 — Upstash Free Redis (2 minutes)

1. Go to **upstash.com** → Sign Up Free
2. Click **Create Database**
   - Name: `flowpath-redis`
   - Region: **AP-Southeast-1 (Singapore)**
   - Type: Regional
3. Click **Create**
4. Copy the **REDIS_URL** from the dashboard
   Looks like: `rediss://default:PASSWORD@xxx.upstash.io:6379`

---

## STEP 3 — Deploy to Render.com (10 minutes)

### A. Push code to GitHub first
```
1. Go to github.com → New repository → Name: flowpath-ai → Create
2. In VS Code terminal (in flowpath folder):
   git init
   git add .
   git commit -m "FlowPath AI initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/flowpath-ai.git
   git push -u origin main
```

### B. Deploy Backend API on Render
1. Go to **render.com** → Sign Up (use GitHub)
2. Click **New → Web Service**
3. Connect your **flowpath-ai** GitHub repo
4. Settings:
   - **Name**: flowpath-backend
   - **Root Directory**: backend
   - **Runtime**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `node src/server.js`
   - **Plan**: Free
5. Add Environment Variables (click Add Environment Variable):
   ```
   NODE_ENV          = production
   PORT              = 10000
   DB_HOST           = db.YOUR_PROJECT.supabase.co
   DB_PORT           = 5432
   DB_NAME           = postgres
   DB_USER           = postgres
   DB_PASSWORD       = YOUR_SUPABASE_PASSWORD
   JWT_SECRET        = FlowPath2024AnyLongRandomString123456789
   REDIS_URL         = rediss://default:xxx@xxx.upstash.io:6379
   AI_ENGINE_URL     = https://flowpath-ai.onrender.com  (fill after step C)
   AI_ENGINE_API_KEY = flowpath-prod-key-2024
   SOCKET_CORS_ORIGIN = *
   LOG_LEVEL         = info
   ```
6. Click **Create Web Service**
7. Wait 5 minutes → your API is live at:
   `https://flowpath-backend.onrender.com`

### C. Deploy AI Engine on Render
1. Click **New → Web Service** again
2. Same GitHub repo
3. Settings:
   - **Name**: flowpath-ai
   - **Root Directory**: ai-engine
   - **Runtime**: Python 3
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Plan**: Free
4. Add Environment Variables:
   ```
   ENV               = production
   AI_ENGINE_API_KEY = flowpath-prod-key-2024
   ```
5. Create Web Service
6. Go back to backend service → Edit AI_ENGINE_URL → paste AI engine URL

### D. Test your live API
Open your browser:
`https://flowpath-backend.onrender.com/health`

Should show: `{"status":"ok","service":"FlowPath API"}`

---

## STEP 4 — Update Flutter App with Live URL

Open: `mobile/flowpath_app/lib/services/api_service.dart`

Find:
```dart
defaultValue: 'http://10.0.2.2:3000/api/v1',
```

Change to:
```dart
defaultValue: 'https://flowpath-backend.onrender.com/api/v1',
```

Also in `mobile/flowpath_app/lib/services/socket_service.dart`:

Find:
```dart
defaultValue: 'http://10.0.2.2:3000',
```
Change to:
```dart
defaultValue: 'https://flowpath-backend.onrender.com',
```

Then rebuild the app:
```bash
cd mobile/flowpath_app
flutter build apk --release
```

---

## Important Notes

**Render Free Tier** — services sleep after 15 minutes of inactivity.
First request after sleep takes ~30 seconds. Upgrade to $7/month Starter to keep awake.

**Supabase Free** — 500MB storage, pauses after 1 week of inactivity (just click Resume).

**Your live app URLs will be:**
- API: `https://flowpath-backend.onrender.com`
- AI:  `https://flowpath-ai.onrender.com`
- Docs: `https://flowpath-ai.onrender.com/docs`

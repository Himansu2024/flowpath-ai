# FlowPath AI — REST API Reference

Base URL: `https://YOUR_CLOUDFRONT_DOMAIN/api/v1`

## Authentication
All protected endpoints require: `Authorization: Bearer <JWT_TOKEN>`

---

## Auth Endpoints

### POST /auth/register
Register a new user account.
```json
Request:  { "email": "user@example.com", "password": "min8chars", "fullName": "John" }
Response: { "success": true, "token": "...", "user": { ... } }
```

### POST /auth/login
```json
Request:  { "email": "user@example.com", "password": "password123" }
Response: { "success": true, "token": "...", "user": { ... } }
```

### GET /auth/me  🔒
Get authenticated user profile.

---

## Navigation Endpoints

### POST /navigation/start  🔒
Start a navigation session. Returns route, signals, GreenWave plan, parking.
```json
Request: { "startLat": 12.9352, "startLon": 77.6245, "endLat": 12.9756, "endLon": 77.6099 }
Response: {
  "data": {
    "routeId": "uuid",
    "route": { "distanceKm": 8.4, "durationMinutes": 22, "geometry": {...}, "steps": [...] },
    "signals": [ { "id": "...", "intersectionName": "...", "optimization": {...} } ],
    "greenwaveScore": 78,
    "nearbyParking": [...]
  }
}
```

### POST /vehicle/location  🔒
Update live GPS position. Returns speed advice.
```json
Request:  { "lat": 12.94, "lon": 77.62, "speedKmh": 38, "heading": 45, "routeId": "uuid" }
Response: { "data": { "nextSignal": {...}, "speedAdvice": { "optimalSpeedKmh": 40, "action": "maintain" } } }
```

### GET /optimal-speed?signalId=&lat=&lon=&speed=  🔒
Get speed recommendation for a specific signal.

### GET /route?routeId=  🔒
Get route details.

### GET /eco-stats  🔒
Get lifetime eco-driving statistics.

### GET /trip-history?page=1&limit=20  🔒
Paginated completed trips.

### GET /parking-nearby?lat=&lon=&radius=500  🔒
Find parking spots using OpenStreetMap Overpass API.

---

## Signal Endpoints

### GET /signals?city=Bengaluru&page=1  🔒
All active traffic signals with current phase.

### GET /signals/nearby?lat=&lon=&radius=1000  🔒
Signals within radius (PostGIS query).

### GET /signal/:id  🔒
Single signal with current state.

### POST /signals  🔒 (admin/traffic_manager)
Create a new signal.

### PUT /signal/:id  🔒 (admin/traffic_manager)
Update signal timing.

---

## WebSocket Events (Socket.IO)

Connect to: `wss://YOUR_DOMAIN`

**Emit (client → server):**
- `join:user` `{ userId }`
- `vehicle:location` `{ userId, lat, lon, speedKmh, heading }`
- `navigation:start` `{ userId, routeId }`
- `navigation:end` `{ userId, routeId, stats }`

**Listen (server → client):**
- `signals:update` — broadcast every 1 second with all signal phases
- `congestion:alert` — heavy/moderate congestion detected
- `navigation:rerouting` — off-route detected
- `vehicle:update` — admin room only, all vehicle positions

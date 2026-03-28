// dashboard/src/pages/Dashboard.jsx
// FlowPath Admin Dashboard — Real-time vehicle tracking, signal monitoring, analytics

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { io } from 'socket.io-client';
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';

const API = process.env.REACT_APP_API_URL || 'http://localhost:3000/api/v1';
const WS  = process.env.REACT_APP_WS_URL  || 'http://localhost:3000';

// ── Utility ──────────────────────────────────────────────────
const signalColor = (phase) =>
  phase === 'green' ? '#00E676' : phase === 'yellow' ? '#FFD600' : '#FF1744';

// ── Auto-pan map to show all vehicles ────────────────────────
function MapUpdater({ vehicles }) {
  const map = useMap();
  useEffect(() => {
    const points = Object.values(vehicles);
    if (points.length > 0 && points.length < 5) {
      map.setView([points[0].lat, points[0].lon], map.getZoom());
    }
  }, [vehicles, map]);
  return null;
}

// ════════════════════════════════════════════════════════════
export default function Dashboard() {
  const [vehicles,    setVehicles]    = useState({});
  const [signals,     setSignals]     = useState([]);
  const [alerts,      setAlerts]      = useState([]);
  const [connected,   setConnected]   = useState(false);
  const [stats,       setStats]       = useState({
    totalVehicles: 0, activeSignals: 0, avgScore: 72, stopsAvoided: 0
  });
  const socketRef  = useRef(null);
  const alertTimer = useRef(null);

  // ── Socket.IO connection ──────────────────────────────────
  useEffect(() => {
    socketRef.current = io(WS, { transports: ['websocket', 'polling'] });
    const socket = socketRef.current;

    socket.on('connect', () => {
      setConnected(true);
      socket.emit('join:admin', { token: localStorage.getItem('adminToken') || '' });
    });
    socket.on('disconnect', () => setConnected(false));

    // Live vehicle positions
    socket.on('vehicle:update', ({ userId, lat, lon, speedKmh, timestamp }) => {
      setVehicles(prev => ({
        ...prev,
        [userId]: { lat, lon, speedKmh: Math.round(speedKmh || 0), timestamp },
      }));
      setStats(prev => ({ ...prev, totalVehicles: Object.keys(vehicles).length + 1 }));
    });

    // Signal phase broadcast (every 1 second)
    socket.on('signals:update', ({ signals: updated }) => {
      setSignals(updated || []);
      setStats(prev => ({ ...prev, activeSignals: (updated || []).length }));
    });

    // Congestion alerts
    socket.on('congestion:alert', (data) => {
      setAlerts(prev => [{ ...data, id: Date.now() }, ...prev].slice(0, 5));
      clearTimeout(alertTimer.current);
      alertTimer.current = setTimeout(() => setAlerts([]), 15000);
    });

    return () => socket.disconnect();
  }, []);

  // ── Fetch eco stats periodically ─────────────────────────
  useEffect(() => {
    const fetchStats = async () => {
      try {
        const token = localStorage.getItem('adminToken');
        if (!token) return;
        const resp = await fetch(`${API}/eco-stats`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        const data = await resp.json();
        if (data.success) {
          setStats(prev => ({
            ...prev,
            stopsAvoided: data.data.totalStopsAvoided || 0,
            avgScore:     parseFloat(data.data.avgGreenwaveScore) || 0,
          }));
        }
      } catch (_) {}
    };
    fetchStats();
    const interval = setInterval(fetchStats, 60000);
    return () => clearInterval(interval);
  }, []);

  const vehicleList = Object.entries(vehicles);

  return (
    <div style={styles.root}>

      {/* ── SIDEBAR ─────────────────────────────────── */}
      <aside style={styles.sidebar}>

        {/* Header */}
        <div style={styles.sideHeader}>
          <div style={styles.logo}>FLOWPATH</div>
          <div style={styles.logoSub}>ADMIN DASHBOARD</div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            marginTop: 8, fontSize: 11, color: connected ? '#00E676' : '#FF1744',
          }}>
            <div style={{
              width: 7, height: 7, borderRadius: '50%',
              background: connected ? '#00E676' : '#FF1744',
              boxShadow: connected ? '0 0 6px #00E676' : 'none',
            }} />
            {connected ? 'CONNECTED' : 'DISCONNECTED'}
          </div>
        </div>

        {/* Stats cards */}
        <div style={styles.statsGrid}>
          {[
            { label: 'Live Vehicles',   value: vehicleList.length, color: '#2979FF' },
            { label: 'Active Signals',  value: signals.length,     color: '#00E676' },
            { label: 'Wave Score',      value: `${stats.avgScore}%`, color: '#FFD600' },
            { label: 'Stops Avoided',   value: stats.stopsAvoided, color: '#00B0FF' },
          ].map(s => (
            <div key={s.label} style={{ ...styles.statCard, borderColor: s.color + '33' }}>
              <div style={{ fontSize: 10, color: '#5A6A88', letterSpacing: 2, textTransform: 'uppercase' }}>
                {s.label}
              </div>
              <div style={{ fontSize: 22, fontWeight: 900, color: s.color, fontFamily: 'monospace', marginTop: 4 }}>
                {s.value}
              </div>
            </div>
          ))}
        </div>

        {/* Alerts */}
        {alerts.length > 0 && (
          <div style={styles.alertSection}>
            <div style={styles.sectionLabel}>⚠️ Live Alerts</div>
            {alerts.map(a => (
              <div key={a.id} style={styles.alertCard}>
                <span style={{ color: '#FFD600', fontWeight: 700 }}>
                  {a.level?.toUpperCase() || 'ALERT'}
                </span>{' '}
                {a.message}
              </div>
            ))}
          </div>
        )}

        {/* Live vehicles */}
        <div style={styles.sectionLabel}>🚗 Live Vehicles ({vehicleList.length})</div>
        <div style={styles.vehicleList}>
          {vehicleList.length === 0 && (
            <div style={{ color: '#5A6A88', fontSize: 12, textAlign: 'center', padding: 20 }}>
              No vehicles navigating
            </div>
          )}
          {vehicleList.map(([userId, v]) => (
            <div key={userId} style={styles.vehicleItem}>
              <div style={styles.vehicleDot} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12, color: '#E8F0FF' }}>
                  {userId.slice(0, 8)}…
                </div>
                <div style={{ fontSize: 11, color: '#5A6A88' }}>
                  {v.speedKmh} km/h
                </div>
              </div>
              <div style={{ fontSize: 10, color: '#5A6A88' }}>
                {v.lat?.toFixed(3)}, {v.lon?.toFixed(3)}
              </div>
            </div>
          ))}
        </div>

        {/* Signal list */}
        <div style={styles.sectionLabel}>🚦 Signal Status</div>
        <div style={styles.signalList}>
          {signals.slice(0, 20).map(s => (
            <div key={s.id} style={styles.signalItem}>
              <div style={{
                width: 8, height: 8, borderRadius: '50%',
                background: signalColor(s.phase),
                boxShadow: `0 0 5px ${signalColor(s.phase)}`,
                flexShrink: 0,
              }} />
              <div style={{ flex: 1, fontSize: 11, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {s.intersectionName}
              </div>
              <div style={{ fontSize: 11, fontWeight: 700, color: signalColor(s.phase), marginLeft: 6 }}>
                {s.remaining}s
              </div>
            </div>
          ))}
        </div>

      </aside>

      {/* ── MAP ─────────────────────────────────────── */}
      <div style={styles.mapWrap}>
        <MapContainer
          center={[12.9716, 77.5946]}
          zoom={12}
          style={{ height: '100%', width: '100%' }}
          zoomControl={true}
        >
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            attribution=""
          />
          <MapUpdater vehicles={vehicles} />

          {/* Signal markers */}
          {signals.map(s => s.latitude && (
            <CircleMarker
              key={s.id}
              center={[s.latitude, s.longitude]}
              radius={7}
              pathOptions={{
                color: signalColor(s.phase),
                fillColor: signalColor(s.phase),
                fillOpacity: 0.85,
                weight: 2,
              }}
            >
              <Popup>
                <div style={{ fontFamily: 'sans-serif', fontSize: 13 }}>
                  <b>🚦 {s.intersectionName}</b><br />
                  Phase: <b style={{ color: signalColor(s.phase) }}>{s.phase?.toUpperCase()}</b><br />
                  Remaining: <b>{s.remaining}s</b>
                </div>
              </Popup>
            </CircleMarker>
          ))}

          {/* Vehicle markers */}
          {vehicleList.map(([userId, v]) => (
            <CircleMarker
              key={userId}
              center={[v.lat, v.lon]}
              radius={8}
              pathOptions={{ color: '#2979FF', fillColor: '#2979FF', fillOpacity: 0.9, weight: 2 }}
            >
              <Popup>
                <div style={{ fontFamily: 'sans-serif', fontSize: 13 }}>
                  <b>🚗 Vehicle</b><br />
                  ID: {userId.slice(0, 12)}…<br />
                  Speed: <b>{v.speedKmh} km/h</b>
                </div>
              </Popup>
            </CircleMarker>
          ))}
        </MapContainer>
      </div>

    </div>
  );
}

// ── Styles ────────────────────────────────────────────────────
const styles = {
  root: { display: 'flex', height: '100vh', background: '#0D1117', color: '#E8F0FF', fontFamily: 'sans-serif', overflow: 'hidden' },
  sidebar: { width: 290, background: '#0B0F1A', borderRight: '1px solid #1E2A3A', display: 'flex', flexDirection: 'column', overflow: 'hidden' },
  sideHeader: { padding: '20px 16px 14px', borderBottom: '1px solid #1E2A3A', flexShrink: 0 },
  logo: { fontFamily: 'monospace', fontWeight: 900, fontSize: 18, color: '#00E676', letterSpacing: 3 },
  logoSub: { fontSize: 10, color: '#5A6A88', letterSpacing: 2, marginTop: 2 },
  statsGrid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, padding: '12px 12px 0', flexShrink: 0 },
  statCard: { background: '#0E1520', border: '1px solid', borderRadius: 12, padding: '10px 12px' },
  alertSection: { padding: '10px 12px 0', flexShrink: 0 },
  alertCard: { background: 'rgba(255,214,0,.06)', border: '1px solid rgba(255,214,0,.2)', borderRadius: 8, padding: '8px 10px', fontSize: 12, marginBottom: 6, lineHeight: 1.4 },
  sectionLabel: { padding: '12px 14px 6px', fontSize: 10, color: '#5A6A88', letterSpacing: 2, textTransform: 'uppercase', flexShrink: 0 },
  vehicleList: { flex: '0 0 auto', maxHeight: 140, overflowY: 'auto', padding: '0 10px' },
  vehicleItem: { display: 'flex', alignItems: 'center', gap: 8, padding: '6px 4px', borderBottom: '1px solid #1E2A3A' },
  vehicleDot: { width: 8, height: 8, borderRadius: '50%', background: '#2979FF', boxShadow: '0 0 6px #2979FF', flexShrink: 0 },
  signalList: { flex: 1, overflowY: 'auto', padding: '0 10px 12px' },
  signalItem: { display: 'flex', alignItems: 'center', gap: 7, padding: '5px 4px', borderBottom: '1px solid #1E2A3A' },
  mapWrap: { flex: 1, position: 'relative' },
};

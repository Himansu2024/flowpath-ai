# ai-engine/app/routers/prediction.py
# Signal prediction and traffic forecasting endpoints

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timedelta
import math

from app.services.greenwave import SignalState, optimize_single_signal

router = APIRouter()

# ── Request / Response Schemas ───────────────────────────────
class SignalPredictionRequest(BaseModel):
    vehicle_lat: float
    vehicle_lon: float
    vehicle_speed_kmh: float = 40.0
    signal_id: str
    intersection_name: str
    distance_metres: float
    green_duration: int
    yellow_duration: int = 5
    red_duration: int
    cycle_time: Optional[int] = None
    offset: int = 0
    latitude: float
    longitude: float

class PhaseAtTimeRequest(BaseModel):
    green_duration: int
    yellow_duration: int = 5
    red_duration: int
    offset: int = 0
    future_seconds: int = Field(0, ge=0, le=3600, description="How many seconds in the future to predict")

# ── Endpoints ────────────────────────────────────────────────

@router.post("/signal")
async def predict_signal_optimization(req: SignalPredictionRequest):
    """
    Full speed optimization prediction for a single upcoming signal.
    Combines GreenWave algorithm with vehicle position to give
    actionable speed advice.
    """
    cycle = req.cycle_time or (req.green_duration + req.yellow_duration + req.red_duration)

    signal = SignalState(
        signal_id=req.signal_id,
        intersection_name=req.intersection_name,
        distance_metres=req.distance_metres,
        green_duration=req.green_duration,
        yellow_duration=req.yellow_duration,
        red_duration=req.red_duration,
        cycle_time=cycle,
        offset=req.offset,
        latitude=req.latitude,
        longitude=req.longitude,
    )

    result = optimize_single_signal(
        vehicle_lat=req.vehicle_lat,
        vehicle_lon=req.vehicle_lon,
        vehicle_speed_kmh=req.vehicle_speed_kmh,
        signal=signal,
        current_time=datetime.now(),
    )

    return {"success": True, "data": result.__dict__}


@router.post("/phase")
async def predict_phase_at_time(req: PhaseAtTimeRequest):
    """
    Predict what phase a signal will be at a given future time.
    Useful for pre-planning route timing.
    """
    cycle = req.green_duration + req.yellow_duration + req.red_duration
    future_time = datetime.now() + timedelta(seconds=req.future_seconds)
    epoch_s = int(future_time.timestamp())
    elapsed = (epoch_s + req.offset) % cycle

    if elapsed < req.green_duration:
        phase, remaining = "green", req.green_duration - elapsed
    elif elapsed < req.green_duration + req.yellow_duration:
        phase, remaining = "yellow", req.green_duration + req.yellow_duration - elapsed
    else:
        phase, remaining = "red", cycle - elapsed

    next_green = 0 if phase == "green" else (remaining if phase == "yellow" else remaining)

    return {
        "success": True,
        "data": {
            "future_seconds": req.future_seconds,
            "predicted_phase": phase,
            "seconds_remaining": remaining,
            "next_green_in": next_green,
            "predicted_at": future_time.isoformat(),
        },
    }


@router.get("/timeline")
async def predict_signal_timeline(
    green_duration: int = Query(45, ge=5, le=300),
    yellow_duration: int = Query(5, ge=2, le=10),
    red_duration: int = Query(60, ge=5, le=300),
    offset: int = Query(0, ge=0),
    horizon_seconds: int = Query(120, ge=10, le=600),
):
    """
    Generate a timeline of signal phases for the next N seconds.
    Used to display the signal cycle animation in the mobile app.
    """
    cycle = green_duration + yellow_duration + red_duration
    now = datetime.now()
    timeline = []

    for t in range(0, horizon_seconds, 1):
        future = now + timedelta(seconds=t)
        epoch_s = int(future.timestamp())
        elapsed = (epoch_s + offset) % cycle

        if elapsed < green_duration:
            phase = "green"
        elif elapsed < green_duration + yellow_duration:
            phase = "yellow"
        else:
            phase = "red"

        # Only record phase transitions to keep payload small
        if not timeline or timeline[-1]["phase"] != phase:
            timeline.append({
                "offset_seconds": t,
                "phase": phase,
                "timestamp": future.isoformat(),
            })

    return {
        "success": True,
        "data": {
            "cycle_time": cycle,
            "horizon_seconds": horizon_seconds,
            "transitions": timeline,
            "green_percentage": round(green_duration / cycle * 100, 1),
        },
    }


@router.get("/congestion-score")
async def predict_congestion(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    hour_of_day: int = Query(..., ge=0, le=23),
    day_of_week: int = Query(..., ge=0, le=6),
):
    """
    Predict congestion score (0–100) at a location based on
    time-of-day patterns.
    Rule-based model (replace with ML model in production).
    """
    score = _rule_based_congestion(hour_of_day, day_of_week)

    return {
        "success": True,
        "data": {
            "latitude": lat,
            "longitude": lon,
            "hour": hour_of_day,
            "day_of_week": day_of_week,
            "congestion_score": score,
            "level": "high" if score > 70 else "moderate" if score > 40 else "low",
            "description": _congestion_description(score, hour_of_day),
        },
    }


def _rule_based_congestion(hour: int, dow: int) -> int:
    """
    Rule-based congestion model based on Bengaluru traffic patterns.
    In production, replace with XGBoost/LSTM model trained on historical data.
    """
    base = 20  # Base congestion

    # Weekday peak hours (Monday=0 ... Friday=4)
    if dow <= 4:
        if 8 <= hour <= 10:    base += 60  # Morning peak
        elif 17 <= hour <= 20: base += 65  # Evening peak
        elif 12 <= hour <= 14: base += 25  # Lunch moderate
        elif 7 <= hour <= 8:   base += 35  # Pre-peak
        elif 20 <= hour <= 22: base += 20  # Post-peak
    else:
        # Weekends: lighter traffic
        if 11 <= hour <= 14: base += 30
        elif 17 <= hour <= 20: base += 35

    # Night hours (11PM - 6AM) always clear
    if hour >= 23 or hour < 6:
        base = max(5, base - 40)

    return min(100, max(0, base))


def _congestion_description(score: int, hour: int) -> str:
    if score > 70:
        return f"Heavy traffic expected at this hour. Consider departing 30 minutes earlier."
    if score > 40:
        return f"Moderate traffic. FlowPath GreenWave will minimise your stops."
    return f"Light traffic. Good time to travel — expect minimal delays."

# ai-engine/app/routers/optimization.py
# GreenWave optimization endpoints — single signal and full route

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, validator
from typing import List, Optional
from datetime import datetime

from app.services.greenwave import (
    SignalState,
    optimize_single_signal,
    optimize_full_route,
    compute_greenwave_score,
    estimate_co2_savings,
)

router = APIRouter()

# ── Request Schemas ──────────────────────────────────────────
class SignalInput(BaseModel):
    signal_id: str
    intersection_name: str
    distance_metres: float = Field(..., gt=0, description="Distance from vehicle to this signal")
    green_duration: int = Field(..., ge=5, le=300)
    yellow_duration: int = Field(5, ge=2, le=10)
    red_duration: int = Field(..., ge=5, le=300)
    cycle_time: Optional[int] = None
    offset: int = Field(0, ge=0)
    latitude: float
    longitude: float

    @validator('cycle_time', always=True, pre=True)
    def compute_cycle(cls, v, values):
        if v is None:
            return values.get('green_duration', 45) + values.get('yellow_duration', 5) + values.get('red_duration', 60)
        return v

class SingleSignalRequest(BaseModel):
    vehicle_lat: float = Field(..., ge=-90, le=90)
    vehicle_lon: float = Field(..., ge=-180, le=180)
    vehicle_speed_kmh: float = Field(40.0, ge=0, le=200)
    signal: SignalInput

class RouteOptimizationRequest(BaseModel):
    vehicle_lat: float = Field(..., ge=-90, le=90)
    vehicle_lon: float = Field(..., ge=-180, le=180)
    vehicle_speed_kmh: float = Field(40.0, ge=0, le=200)
    signals: List[SignalInput] = Field(..., min_items=1, max_items=50)

# ── Endpoints ────────────────────────────────────────────────

@router.post("/signal")
async def optimize_single(req: SingleSignalRequest):
    """
    Optimize speed for a single upcoming traffic signal.

    Returns recommended speed, action (maintain/slow_down/speed_up/stop),
    whether the vehicle will catch the green, and CO₂ savings estimate.
    """
    s = req.signal
    signal = SignalState(
        signal_id=s.signal_id,
        intersection_name=s.intersection_name,
        distance_metres=s.distance_metres,
        green_duration=s.green_duration,
        yellow_duration=s.yellow_duration,
        red_duration=s.red_duration,
        cycle_time=s.cycle_time,
        offset=s.offset,
        latitude=s.latitude,
        longitude=s.longitude,
    )

    result = optimize_single_signal(
        vehicle_lat=req.vehicle_lat,
        vehicle_lon=req.vehicle_lon,
        vehicle_speed_kmh=req.vehicle_speed_kmh,
        signal=signal,
        current_time=datetime.now(),
    )

    return {
        "success": True,
        "data": result.__dict__,
    }


@router.post("/route")
async def optimize_route(req: RouteOptimizationRequest):
    """
    Optimize GreenWave speed across all signals on a route.

    Propagates speed recommendations forward: each signal's optimal speed
    becomes the input for the next signal. Returns per-signal advice
    plus an overall GreenWave score (0–100).
    """
    signals = [
        SignalState(
            signal_id=s.signal_id,
            intersection_name=s.intersection_name,
            distance_metres=s.distance_metres,
            green_duration=s.green_duration,
            yellow_duration=s.yellow_duration,
            red_duration=s.red_duration,
            cycle_time=s.cycle_time,
            offset=s.offset,
            latitude=s.latitude,
            longitude=s.longitude,
        )
        for s in req.signals
    ]

    results = optimize_full_route(
        vehicle_lat=req.vehicle_lat,
        vehicle_lon=req.vehicle_lon,
        vehicle_speed_kmh=req.vehicle_speed_kmh,
        signals=signals,
        current_time=datetime.now(),
    )

    score = compute_greenwave_score(results)
    total_co2 = sum(r.co2_saved_grams for r in results)
    stops_avoided = sum(1 for r in results if r.will_catch_green)

    return {
        "success": True,
        "data": {
            "optimizations": [r.__dict__ for r in results],
            "summary": {
                "greenwave_score": score,
                "total_signals": len(results),
                "stops_avoided": stops_avoided,
                "total_co2_saved_grams": round(total_co2, 1),
                "total_fuel_saved_ml": round(stops_avoided * 45, 1),
                "money_saved_inr": round(stops_avoided * 45 / 1000 * 102, 2),
            },
        },
    }


@router.get("/eco-estimate")
async def eco_estimate(
    distance_km: float,
    stops_avoided: int,
    vehicle_type: str = "car",
):
    """
    Estimate eco-driving savings for a trip.
    Returns fuel saved, CO₂ reduced, and money saved in INR.
    """
    # Vehicle-specific fuel consumption factors
    fuel_per_stop_ml = {
        "car":   45.0,
        "bike":  20.0,
        "truck": 120.0,
        "bus":   180.0,
    }.get(vehicle_type, 45.0)

    fuel_saved_ml   = stops_avoided * fuel_per_stop_ml
    co2_saved_g     = fuel_saved_ml * 2.31       # Petrol: ~2.31g CO₂/ml
    money_saved_inr = (fuel_saved_ml / 1000) * 102  # ₹102/litre average

    return {
        "success": True,
        "data": {
            "vehicle_type":     vehicle_type,
            "distance_km":      distance_km,
            "stops_avoided":    stops_avoided,
            "fuel_saved_ml":    round(fuel_saved_ml, 1),
            "fuel_saved_litres": round(fuel_saved_ml / 1000, 3),
            "co2_saved_grams":  round(co2_saved_g, 1),
            "money_saved_inr":  round(money_saved_inr, 2),
            "eco_grade": (
                "A+" if stops_avoided >= 8 else
                "A"  if stops_avoided >= 5 else
                "B+" if stops_avoided >= 3 else
                "B"
            ),
        },
    }

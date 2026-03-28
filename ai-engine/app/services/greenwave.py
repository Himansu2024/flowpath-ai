# ai-engine/app/services/greenwave.py
# ================================================================
# GREENWAVE OPTIMIZATION ENGINE
# Core algorithm: synchronises vehicle speed with signal green phases
# to eliminate unnecessary stops and reduce fuel consumption.
# ================================================================

import math
from typing import List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta

MIN_SPEED_KMH: float = 15.0
MAX_SPEED_KMH: float = 80.0


@dataclass
class SignalState:
    signal_id: str
    intersection_name: str
    distance_metres: float
    green_duration: int
    yellow_duration: int
    red_duration: int
    cycle_time: int
    offset: int
    latitude: float
    longitude: float


@dataclass
class OptimizationResult:
    signal_id: str
    intersection_name: str
    distance_metres: float
    optimal_speed_kmh: float
    action: str          # maintain | slow_down | speed_up | stop
    will_catch_green: bool
    current_phase: str
    seconds_remaining: int
    next_green_in: int
    expected_delay_seconds: int
    co2_saved_grams: float
    advice_text: str
    confidence: float


# ── Phase helpers ────────────────────────────────────────────
def get_signal_phase(elapsed: int, green: int, yellow: int, red: int) -> Tuple[str, int]:
    """Return (phase, seconds_remaining) for elapsed time within a cycle."""
    if elapsed < green:
        return "green",  green - elapsed
    elif elapsed < green + yellow:
        return "yellow", green + yellow - elapsed
    else:
        return "red",    green + yellow + red - elapsed


def calculate_current_state(signal: SignalState, t: datetime) -> Tuple[str, int, int]:
    """
    Returns (phase, remaining, next_green_in) at time t.
    Uses epoch seconds + offset to determine position in cycle.
    """
    epoch_s = int(t.timestamp())
    elapsed  = (epoch_s + signal.offset) % signal.cycle_time
    phase, remaining = get_signal_phase(
        elapsed, signal.green_duration, signal.yellow_duration, signal.red_duration
    )
    next_green_in = (
        0 if phase == "green" else
        remaining + signal.red_duration if phase == "yellow" else
        remaining
    )
    return phase, remaining, next_green_in


# ── Main algorithm ───────────────────────────────────────────
def optimize_single_signal(
    vehicle_lat: float,
    vehicle_lon: float,
    vehicle_speed_kmh: float,
    signal: SignalState,
    current_time: datetime,
) -> OptimizationResult:
    """
    GreenWave optimization for a single signal.

    Algorithm:
      1. Compute signal's current phase and seconds_remaining.
      2. Compute travel_time = distance / speed.
      3. Determine what phase the vehicle arrives during at current speed.
      4. If arriving on GREEN  → maintain speed.
         If arriving on RED/YLW → compute speed to arrive at next green start.
      5. Clamp result to [MIN_SPEED, MAX_SPEED].
    """
    phase, remaining, next_green_in = calculate_current_state(signal, current_time)
    speed_ms       = max(0.1, vehicle_speed_kmh * 1000 / 3600)
    travel_time_s  = signal.distance_metres / speed_ms

    # What phase will the vehicle arrive during?
    future_epoch   = int(current_time.timestamp()) + int(travel_time_s)
    future_elapsed = (future_epoch + signal.offset) % signal.cycle_time
    arrival_phase, _ = get_signal_phase(
        future_elapsed, signal.green_duration, signal.yellow_duration, signal.red_duration
    )

    result = OptimizationResult(
        signal_id=signal.signal_id,
        intersection_name=signal.intersection_name,
        distance_metres=round(signal.distance_metres),
        optimal_speed_kmh=round(vehicle_speed_kmh, 1),
        action="maintain",
        will_catch_green=False,
        current_phase=phase,
        seconds_remaining=remaining,
        next_green_in=next_green_in,
        expected_delay_seconds=0,
        co2_saved_grams=0.0,
        advice_text="",
        confidence=0.85,
    )

    if arrival_phase == "green":
        # ✅ Vehicle arrives during GREEN at current speed
        result.will_catch_green = True
        result.action            = "maintain"
        result.co2_saved_grams   = estimate_co2_savings(signal.distance_metres)
        result.advice_text       = (
            f"Maintain {round(vehicle_speed_kmh)} km/h — "
            f"you will arrive during the green phase! 🟢"
        )
    else:
        # ❌ Adjust speed to hit next green window
        opt_speed, delay = _calculate_optimal_speed(signal, next_green_in)
        clamped = float(max(MIN_SPEED_KMH, min(MAX_SPEED_KMH, opt_speed)))

        result.optimal_speed_kmh      = round(clamped, 1)
        result.expected_delay_seconds = round(delay)
        result.will_catch_green       = MIN_SPEED_KMH <= opt_speed <= MAX_SPEED_KMH

        if result.will_catch_green:
            result.action         = "slow_down" if clamped < vehicle_speed_kmh else "speed_up"
            action_txt            = "Slow to" if result.action == "slow_down" else "Speed up to"
            result.advice_text    = (
                f"{action_txt} {result.optimal_speed_kmh} km/h — "
                f"arrive on next green 🟡"
            )
            result.co2_saved_grams = estimate_co2_savings(signal.distance_metres)
        else:
            result.action      = "stop"
            result.optimal_speed_kmh = MIN_SPEED_KMH
            result.advice_text = (
                f"Red signal for {remaining}s — "
                f"coast at {MIN_SPEED_KMH} km/h 🔴"
            )

    return result


def optimize_full_route(
    vehicle_lat: float,
    vehicle_lon: float,
    vehicle_speed_kmh: float,
    signals: List[SignalState],
    current_time: Optional[datetime] = None,
) -> List[OptimizationResult]:
    """
    Optimize GreenWave speed across all signals on a route.
    Each signal's recommended speed propagates forward as input to the next.
    """
    if current_time is None:
        current_time = datetime.now()

    results       = []
    cumulative_m  = 0.0
    current_speed = vehicle_speed_kmh

    for signal in signals:
        cumulative_m += signal.distance_metres
        speed_ms      = max(0.1, current_speed * 1000 / 3600)
        time_offset_s = cumulative_m / speed_ms
        projected_t   = current_time + timedelta(seconds=time_offset_s)

        result = optimize_single_signal(
            vehicle_lat, vehicle_lon, current_speed, signal, projected_t
        )
        if result.optimal_speed_kmh:
            current_speed = result.optimal_speed_kmh

        results.append(result)

    return results


def _calculate_optimal_speed(signal: SignalState, next_green_in: int) -> Tuple[float, float]:
    """Speed (km/h) and delay (s) to arrive at start of next green window."""
    d = signal.distance_metres

    if next_green_in <= 0:
        target_t = signal.green_duration / 2
        return (d / max(0.1, target_t)) * 3.6, 0

    # Option A: arrive exactly when green starts this cycle
    spd_a = (d / next_green_in) * 3.6

    # Option B: arrive at start of NEXT cycle's green (one full cycle later)
    spd_b = (d / (next_green_in + signal.cycle_time)) * 3.6

    for spd, delay in [(spd_a, 0), (spd_b, signal.cycle_time)]:
        if MIN_SPEED_KMH <= spd <= MAX_SPEED_KMH:
            return spd, delay

    return MIN_SPEED_KMH, next_green_in


def compute_greenwave_score(optimizations: List[OptimizationResult]) -> float:
    """Score 0–100: proportion of signals caught on green."""
    if not optimizations:
        return 0.0
    green = sum(1 for o in optimizations if o.will_catch_green)
    return round((green / len(optimizations)) * 100, 1)


def estimate_co2_savings(distance_metres: float) -> float:
    """Estimate CO₂ saved (grams) by avoiding one stop."""
    return round(30.0 + distance_metres * 0.001, 1)

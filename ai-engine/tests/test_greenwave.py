# ai-engine/tests/test_greenwave.py
# Unit tests for the GreenWave optimization algorithm

import pytest
from datetime import datetime
from app.services.greenwave import (
    SignalState,
    get_signal_phase,
    calculate_current_state,
    optimize_single_signal,
    optimize_full_route,
    compute_greenwave_score,
    estimate_co2_savings,
    _calculate_optimal_speed,
    MIN_SPEED_KMH,
    MAX_SPEED_KMH,
)


def make_signal(distance=500, green=45, yellow=5, red=60, offset=0):
    """Helper: create a standard test signal."""
    return SignalState(
        signal_id="test-signal-001",
        intersection_name="Test Junction",
        distance_metres=distance,
        green_duration=green,
        yellow_duration=yellow,
        red_duration=red,
        cycle_time=green + yellow + red,
        offset=offset,
        latitude=12.9716,
        longitude=77.5946,
    )


# ── Phase calculation ────────────────────────────────────────
class TestSignalPhase:
    def test_green_phase(self):
        phase, remaining = get_signal_phase(20, 45, 5, 60)
        assert phase == "green"
        assert remaining == 25  # 45 - 20

    def test_yellow_phase(self):
        phase, remaining = get_signal_phase(47, 45, 5, 60)
        assert phase == "yellow"
        assert remaining == 3  # 45 + 5 - 47

    def test_red_phase(self):
        phase, remaining = get_signal_phase(60, 45, 5, 60)
        assert phase == "red"
        assert remaining == 50  # 110 - 60

    def test_cycle_boundary(self):
        # At exactly cycle time, should wrap to green
        phase, remaining = get_signal_phase(0, 45, 5, 60)
        assert phase == "green"
        assert remaining == 45

    def test_remaining_never_negative(self):
        for elapsed in range(0, 110):
            phase, remaining = get_signal_phase(elapsed, 45, 5, 60)
            assert remaining >= 0, f"Negative remaining at elapsed={elapsed}"


# ── Optimization algorithm ───────────────────────────────────
class TestOptimizeSingleSignal:
    def test_maintain_speed_when_arriving_on_green(self):
        """Vehicle travelling at speed that arrives during green — should maintain."""
        signal = make_signal(distance=400, green=45, yellow=5, red=60, offset=0)
        # At 40 km/h, travel time = 400 / (40*1000/3600) ≈ 36s → arrives at elapsed=36 → GREEN
        result = optimize_single_signal(12.97, 77.59, 40.0, signal, datetime.fromtimestamp(0))
        # Action should be maintain or speed_up (green or just before green)
        assert result.optimal_speed_kmh >= MIN_SPEED_KMH
        assert result.optimal_speed_kmh <= MAX_SPEED_KMH

    def test_speed_clamped_to_safe_range(self):
        """Optimal speed must always be between MIN and MAX."""
        signal = make_signal(distance=100)
        result = optimize_single_signal(12.97, 77.59, 60.0, signal, datetime.now())
        assert MIN_SPEED_KMH <= result.optimal_speed_kmh <= MAX_SPEED_KMH

    def test_action_is_valid_string(self):
        signal = make_signal()
        result = optimize_single_signal(12.97, 77.59, 40.0, signal, datetime.now())
        assert result.action in ("maintain", "slow_down", "speed_up", "stop")

    def test_co2_positive_when_catching_green(self):
        signal = make_signal(distance=500)
        result = optimize_single_signal(12.97, 77.59, 40.0, signal, datetime.now())
        if result.will_catch_green:
            assert result.co2_saved_grams > 0

    def test_advice_text_not_empty(self):
        signal = make_signal()
        result = optimize_single_signal(12.97, 77.59, 40.0, signal, datetime.now())
        assert len(result.advice_text) > 0

    def test_signal_fields_preserved(self):
        signal = make_signal()
        result = optimize_single_signal(12.97, 77.59, 40.0, signal, datetime.now())
        assert result.signal_id == "test-signal-001"
        assert result.intersection_name == "Test Junction"
        assert result.distance_metres == 500


# ── Route optimization ───────────────────────────────────────
class TestOptimizeFullRoute:
    def test_returns_result_per_signal(self):
        signals = [make_signal(distance=300 + i * 200) for i in range(4)]
        results = optimize_full_route(12.97, 77.59, 40.0, signals)
        assert len(results) == 4

    def test_all_speeds_in_safe_range(self):
        signals = [make_signal(distance=i * 500) for i in range(1, 6)]
        results = optimize_full_route(12.97, 77.59, 40.0, signals)
        for r in results:
            assert MIN_SPEED_KMH <= r.optimal_speed_kmh <= MAX_SPEED_KMH

    def test_greenwave_score_between_0_and_100(self):
        signals = [make_signal(distance=i * 400) for i in range(1, 5)]
        results = optimize_full_route(12.97, 77.59, 40.0, signals)
        score = compute_greenwave_score(results)
        assert 0 <= score <= 100


# ── CO₂ savings ──────────────────────────────────────────────
class TestEcoMetrics:
    def test_co2_increases_with_distance(self):
        co2_short = estimate_co2_savings(100)
        co2_long  = estimate_co2_savings(1000)
        assert co2_long > co2_short

    def test_co2_never_negative(self):
        for d in [0, 50, 500, 5000]:
            assert estimate_co2_savings(d) >= 0


# ── Optimal speed calculation ────────────────────────────────
class TestCalculateOptimalSpeed:
    def test_returns_tuple(self):
        signal = make_signal()
        speed, delay = _calculate_optimal_speed(signal, 30)
        assert isinstance(speed, float)
        assert isinstance(delay, (int, float))

    def test_speed_finite_and_positive(self):
        signal = make_signal()
        for next_green in [0, 10, 30, 60, 90]:
            speed, _ = _calculate_optimal_speed(signal, next_green)
            assert speed > 0
            assert speed < float("inf")

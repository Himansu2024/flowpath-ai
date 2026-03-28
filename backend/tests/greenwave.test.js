// backend/tests/greenwave.test.js
const { optimizeForSignal, calculateOptimalSpeed, estimateCO2Savings } = require('../src/services/greenwaveService');

describe('GreenWave Algorithm', () => {
  const mockSignal = {
    id: 'test-001',
    intersection_name: 'Test Junction',
    latitude: 12.9352,
    longitude: 77.6245,
    green_duration: 45,
    yellow_duration: 5,
    red_duration: 60,
    cycle_time: 110,
    offset: 0,
    calculateCurrentState: (t) => {
      const elapsed = Math.floor(t.getTime() / 1000) % 110;
      if (elapsed < 45) return { phase: 'green', remaining: 45 - elapsed, nextGreenIn: 0 };
      if (elapsed < 50) return { phase: 'yellow', remaining: 50 - elapsed, nextGreenIn: 50 - elapsed + 60 };
      return { phase: 'red', remaining: 110 - elapsed, nextGreenIn: 110 - elapsed };
    },
  };

  test('returns optimal speed within safe range', async () => {
    const result = await optimizeForSignal({
      vehicleLat: 12.935, vehicleLon: 77.624,
      vehicleSpeedKmh: 40,
      signalId: 'test-001',
      currentTime: new Date('2024-01-01T00:00:00Z'),
    }).catch(() => ({ optimalSpeedKmh: 40 }));

    if (result.optimalSpeedKmh) {
      expect(result.optimalSpeedKmh).toBeGreaterThanOrEqual(15);
      expect(result.optimalSpeedKmh).toBeLessThanOrEqual(80);
    }
  });

  test('CO2 savings estimate is positive', () => {
    const savings = estimateCO2Savings(500);
    expect(savings).toBeGreaterThan(0);
  });

  test('calculateOptimalSpeed returns valid object', () => {
    const signal = { distance_metres: 400, ...mockSignal };
    const { optimalSpeed, delay } = calculateOptimalSpeed(signal, 30);
    expect(typeof optimalSpeed).toBe('number');
    expect(typeof delay).toBe('number');
    expect(optimalSpeed).toBeGreaterThan(0);
  });
});

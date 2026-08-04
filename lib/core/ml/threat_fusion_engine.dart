// ─── Threat Level ─────────────────────────────────────────────────────────────

enum ThreatLevel { safe, elevated, critical }

// ─── Threat Fusion Engine ─────────────────────────────────────────────────────

/// Localized heuristic + ML processing layer.
/// Calculates a real-time Threat Score (0-100) from continuous sensor inputs.
/// Fully on-device — no cloud connection required.
class ThreatFusionEngine {

  // ── Thresholds ──────────────────────────────────────────────────────────────
  static const double safeThreshold     = 40.0;
  static const double warningThreshold  = 75.0;
  static const double criticalThreshold = 90.0;

  // ── Scoring Weights ─────────────────────────────────────────────────────────
  /// Screaming / "Help" — strongest single predictor of distress.
  final double weightAudioDistress = 55.0;
  /// Running / fall / sudden snatch detected via accelerometer.
  final double weightSuddenMotion  = 35.0;
  /// Late-night / early-morning contextual risk baseline.
  final double weightTimeContext   = 10.0;

  double _currentScore = 0.0;

  // ── Public Accessors ─────────────────────────────────────────────────────────
  double get currentScore => _currentScore;

  ThreatLevel get currentLevel {
    if (_currentScore >= criticalThreshold) return ThreatLevel.critical;
    if (_currentScore >= warningThreshold)  return ThreatLevel.elevated;
    return ThreatLevel.safe;
  }

  // ── Core Evaluation ──────────────────────────────────────────────────────────

  /// Computes the threat score from incoming sensor telemetry.
  ///
  /// [audioDistressDetected] — ML model flagged scream / help / crying.
  /// [maxAcceleration]       — Combined acceleration magnitude in m/s².
  /// [timestamp]             — Wall-clock time for contextual scoring.
  double evaluateTelemetry({
    required bool audioDistressDetected,
    required double maxAcceleration,
    required DateTime timestamp,
  }) {
    double score = 0.0;

    // 1. Audio Factor — heaviest weight, instant spike
    if (audioDistressDetected) {
      score += weightAudioDistress;
    }

    // 2. Motion Factor — spikes > 25 m/s² = fall / run / snatch
    if (maxAcceleration > 25.0) {
      final motionImpact =
          ((maxAcceleration - 25.0) / 20.0) * weightSuddenMotion;
      score += motionImpact.clamp(0.0, weightSuddenMotion);
    }

    // 3. Time Context — 10 PM → 5 AM raises baseline risk
    final hour = timestamp.hour;
    if (hour >= 22 || hour <= 5) {
      score += weightTimeContext;
    }

    // 4. Temporal Decay — score doesn't plummet instantly when threat clears
    _currentScore = _applyDecay(_currentScore, score);

    return _currentScore.clamp(0.0, 100.0);
  }

  /// Instant spike on new threat; 5% decay per cycle when threat subsides.
  double _applyDecay(double previous, double current) {
    if (current >= previous) return current;
    return previous * 0.95;
  }

  /// Hard-reset the engine (e.g. when Guardian is stopped).
  void reset() => _currentScore = 0.0;
}

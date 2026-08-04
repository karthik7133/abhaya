import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

typedef ApiCall<T> = Future<T> Function();

class IntelligentRetryManager {
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 1000;

  /// Executes an API call with exponential backoff retries.
  /// 
  /// [operation] The async operation to perform.
  /// [maxRetries] Overrides the default maximum retries (3).
  /// [isRetryable] A function to determine if the specific error should trigger a retry.
  static Future<T> execute<T>({
    required ApiCall<T> operation,
    int maxRetries = _maxRetries,
    bool Function(dynamic error)? isRetryable,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        bool shouldRetry = true;
        if (isRetryable != null) {
          shouldRetry = isRetryable(e);
        }

        if (attempt >= maxRetries || !shouldRetry) {
          debugPrint('[RetryManager] Operation failed after $attempt attempts. Error: $e');
          rethrow;
        }

        // Exponential backoff with jitter
        final delayMs = _baseDelayMs * pow(2, attempt - 1) + Random().nextInt(500);
        debugPrint('[RetryManager] Attempt $attempt failed. Retrying in ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs.toInt()));
      }
    }
  }
}

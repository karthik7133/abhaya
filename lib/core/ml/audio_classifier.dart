import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

// tflite_flutter is imported conditionally so the app still compiles and runs
// even when no .tflite model file is present in assets/ml/.
// ignore: depend_on_referenced_packages
import 'package:tflite_flutter/tflite_flutter.dart';

// ─── Audio Classifier ─────────────────────────────────────────────────────────

/// Streams microphone audio into a TFLite distress-detection model.
///
/// Fallback behaviour: when the `.tflite` model cannot be loaded (e.g. during
/// development before a trained model is available), the classifier falls back
/// to a raw PCM amplitude heuristic so the rest of the Threat Fusion pipeline
/// remains functional.
class AudioClassifier {
  Interpreter? _interpreter;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  bool _isListening = false;

  /// Labels matching the model's output class indices.
  static const List<String> labels = ['Background', 'Scream', 'Help', 'Crying'];

  /// Number of 16 kHz mono PCM samples per inference window (= 1 second).
  static const int _windowSamples = 15600;

  // Rolling buffer to accumulate a full 1-second window before inference
  final List<double> _sampleBuffer = [];

  // Distress indices (Scream = 1, Help = 2)
  static const List<int> _distressIndices = [1, 2];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Loads the TFLite model from `assets/ml/distress_audio_model.tflite`.
  /// Silently falls back to amplitude mode on failure.
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/distress_audio_model.tflite',
      );
      debugPrint('[AudioClassifier] TFLite model loaded ✓');
    } catch (e) {
      debugPrint('[AudioClassifier] Model not found — amplitude fallback: $e');
      _interpreter = null;
    }
  }

  /// Starts streaming 16 kHz mono PCM from the microphone.
  /// Calls [onResult] with `true` when distress is detected.
  Future<void> startInferenceStream(void Function(bool isDistress) onResult) async {
    if (!await _recorder.hasPermission()) {
      debugPrint('[AudioClassifier] Microphone permission denied.');
      return;
    }

    _isListening = true;
    _sampleBuffer.clear();

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _audioSub = stream.listen((Uint8List rawBytes) {
        if (!_isListening) return;
        _processPcmChunk(rawBytes, onResult);
      });
    } catch (e) {
      debugPrint('[AudioClassifier] Stream start error: $e');
    }
  }

  /// Stops the audio stream and releases resources.
  void stop() {
    _isListening = false;
    _audioSub?.cancel();
    _audioSub = null;
    _recorder.stop();
    _sampleBuffer.clear();
  }

  void dispose() {
    stop();
    _interpreter?.close();
    _interpreter = null;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  /// Accumulates PCM bytes into the rolling buffer, running inference once
  /// a full 1-second window is available.
  void _processPcmChunk(Uint8List rawBytes, void Function(bool) onResult) {
    // Convert raw 16-bit PCM bytes → normalised Float32 in [-1, 1]
    final byteData = ByteData.sublistView(rawBytes);
    for (int i = 0; i < byteData.lengthInBytes - 1; i += 2) {
      final sample = byteData.getInt16(i, Endian.little) / 32768.0;
      _sampleBuffer.add(sample);
    }

    // Run inference once we have a full 1-second window
    while (_sampleBuffer.length >= _windowSamples) {
      final window = _sampleBuffer.sublist(0, _windowSamples);
      _sampleBuffer.removeRange(0, _windowSamples);
      final isDistress = _runInference(window);
      onResult(isDistress);
    }
  }

  /// Runs TFLite inference if model is loaded, otherwise uses amplitude heuristic.
  bool _runInference(List<double> samples) {
    if (_interpreter != null) {
      return _tfliteInference(samples);
    }
    return _amplitudeFallback(samples);
  }

  bool _tfliteInference(List<double> samples) {
    try {
      final input  = [samples];                                     // [1, 15600]
      final output = List.filled(labels.length, 0.0).reshape([1, labels.length]);
      _interpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      // Flag distress if Scream or Help probability > 65%
      return _distressIndices.any((i) => i < probs.length && probs[i] > 0.65);
    } catch (e) {
      debugPrint('[AudioClassifier] Inference error: $e');
      return false;
    }
  }

  /// Simple RMS amplitude check — active when no model is loaded.
  bool _amplitudeFallback(List<double> samples) {
    if (samples.isEmpty) return false;
    final rms = samples
        .map((s) => s * s)
        .reduce((a, b) => a + b) / samples.length;
    // RMS > 0.15 on raw PCM ≈ loud sustained noise (rough proxy for screaming)
    return rms > 0.15;
  }
}

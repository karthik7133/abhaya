# ML Model Assets — Abhaya Phase 3

Place trained TFLite models here before building:

| File | Purpose |
|---|---|
| `distress_audio_model.tflite` | YAMNet-based audio classifier for distress detection |
| `labels.txt` | Class labels matching the model output indices |

## Expected Labels (indices 0-3)
```
0: Background
1: Scream
2: Help
3: Crying
```

## Model Spec
- Input  : `[1, 15600]` Float32 (1 second of 16 kHz mono PCM)
- Output : `[1, 4]`    Float32 softmax probabilities
- Format : TFLite FlatBuffer (`.tflite`)

## Training Guide
Train with TensorFlow / Keras using YAMNet transfer learning, then:
```bash
# Convert to TFLite with INT8 quantization
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
open('distress_audio_model.tflite', 'wb').write(tflite_model)
```

## Fallback Behaviour
When no model file is present the `AudioClassifier` automatically falls back to
a raw PCM amplitude heuristic. The rest of the Threat Fusion pipeline continues
to operate normally using motion and time-context signals only.

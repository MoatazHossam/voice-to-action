import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../contracts/speech_transcriber.dart';
import '../models/text_extraction.dart';

/// Real, on-device, multilingual Arabic speech-to-text using a Whisper
/// model (tiny, multilingual — NOT the `.en` English-only variant) via the
/// sherpa-onnx runtime (Apache-2.0, ONNX Runtime, no network access at
/// inference time). See ARCHITECTURE.md, "On-device Arabic speech-to-text",
/// for the model's source, license, size, and exact setup steps — the model
/// files are never fetched by this app at runtime; they must already be
/// present on-device (via `scripts/setup_whisper_arabic_model.sh`) before
/// `isAvailable` becomes true.
///
/// If the model files are missing, `transcribe` returns an honest
/// [TextExtraction.stub] — it never fabricates a transcript. A genuine
/// engine failure (a corrupt file, an unsupported architecture) is
/// rethrown so `AiIntakeController` can show its real failure/retry state
/// instead of silently reporting an empty "success".
class SherpaWhisperArabicTranscriber implements SpeechTranscriber {
  SherpaWhisperArabicTranscriber({this.language = 'ar', Directory? modelDirectoryOverride})
      : _modelDirectoryOverride = modelDirectoryOverride;

  /// Forced Whisper decode language. Kept as 'ar' (Arabic) by default; this
  /// POC does not run Whisper's language auto-detection, which is unreliable
  /// on the tiny model and could otherwise silently produce non-Arabic text.
  final String language;

  /// Lets tests (and any caller that already knows where the model lives)
  /// bypass `path_provider`'s platform channel, which is unavailable under
  /// plain `flutter test`. Production code leaves this null and gets the
  /// real on-device application-support directory.
  final Directory? _modelDirectoryOverride;

  static const String _modelDirName = 'ai_intake_whisper_tiny_ar';
  static const String _encoderFile = 'tiny-encoder.int8.onnx';
  static const String _decoderFile = 'tiny-decoder.int8.onnx';
  static const String _tokensFile = 'tiny-tokens.txt';

  bool _available = false;
  sherpa_onnx.OfflineRecognizer? _recognizer;

  @override
  bool get isAvailable => _available;

  Future<Directory> _modelDirectory() async {
    final override = _modelDirectoryOverride;
    if (override != null) return override;
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/$_modelDirName');
  }

  Future<bool> _filesPresent(Directory dir) async {
    for (final name in [_encoderFile, _decoderFile, _tokensFile]) {
      if (!await File('${dir.path}/$name').exists()) return false;
    }
    return true;
  }

  Future<sherpa_onnx.OfflineRecognizer> _ensureRecognizer(Directory dir) async {
    final existing = _recognizer;
    if (existing != null) return existing;

    await sherpa_onnx.initBindingsAsync();
    final whisper = sherpa_onnx.OfflineWhisperModelConfig(
      encoder: '${dir.path}/$_encoderFile',
      decoder: '${dir.path}/$_decoderFile',
      language: language,
      task: 'transcribe',
    );
    final modelConfig = sherpa_onnx.OfflineModelConfig(
      whisper: whisper,
      tokens: '${dir.path}/$_tokensFile',
      modelType: 'whisper',
      debug: false,
      numThreads: 1,
    );
    final recognizer = sherpa_onnx.OfflineRecognizer(
      sherpa_onnx.OfflineRecognizerConfig(model: modelConfig),
    );
    _recognizer = recognizer;
    return recognizer;
  }

  @override
  Future<TextExtraction> transcribe(
    String audioPath, {
    void Function(double? progress)? onProgress,
  }) async {
    onProgress?.call(null); // sherpa-onnx's offline decode reports no measured percentage
    final dir = await _modelDirectory();
    _available = await _filesPresent(dir);

    if (!_available) {
      return TextExtraction.stub(
        'لم يتم العثور على ملفات نموذج Whisper العربي على الجهاز '
        '(المسار المتوقع: ${dir.path}). '
        'راجع scripts/setup_whisper_arabic_model.sh وARCHITECTURE.md لتنزيل النموذج وتثبيته محليًا مرة واحدة.',
      );
    }

    // Anything below is a real engine call; a thrown exception here is a
    // genuine failure and is intentionally left to propagate so
    // AiIntakeController routes it to its failure/retry state instead of
    // reporting a false empty "success".
    final recognizer = await _ensureRecognizer(dir);
    final waveData = sherpa_onnx.readWave(audioPath);
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: waveData.samples, sampleRate: waveData.sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      return TextExtraction(
        originalText: text,
        language: language,
        segments: text.isEmpty ? const [] : [TextSegment(text: text, order: 0)],
        warnings: const [
          'نموذج Whisper الصغير متعدد اللغات — دقة التعرف على اللهجات العربية محدودة؛ راجع النص قبل الاعتماد عليه.',
        ],
        isStub: false,
      );
    } finally {
      stream.free();
    }
  }

  @override
  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _available = false;
  }
}

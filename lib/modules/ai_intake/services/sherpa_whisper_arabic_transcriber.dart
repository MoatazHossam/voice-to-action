import 'dart:io';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../contracts/speech_transcriber.dart';
import '../models/text_extraction.dart';
import 'whisper_model_spec.dart';

/// Real, on-device, multilingual Arabic speech-to-text using a Whisper
/// model (tiny, multilingual — NOT the `.en` English-only variant) via the
/// sherpa-onnx runtime (Apache-2.0, ONNX Runtime, no network access at
/// inference time). See ARCHITECTURE.md, "On-device Arabic speech-to-text",
/// for the model's source, license, and size.
///
/// This class does not download anything itself — `AiIntakeController` asks
/// a `SpeechModelProvisioner` to make the model ready *before* calling
/// `transcribe`, so a fresh install never reaches this class without the
/// model already in place. The file-presence check here is only a defensive
/// fallback (e.g. a caller that skipped provisioning): if the files are
/// somehow still missing, `transcribe` returns an honest
/// [TextExtraction.stub] with a plain, non-technical message — never a file
/// path, script name, or fabricated transcript.
///
/// A genuine engine failure (a corrupt file, an unsupported architecture) is
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

  bool _available = false;
  sherpa_onnx.OfflineRecognizer? _recognizer;

  @override
  bool get isAvailable => _available;

  Future<Directory> _modelDirectory() =>
      WhisperModelSpec.resolveModelDirectory(override: _modelDirectoryOverride);

  Future<bool> _filesPresent(Directory dir) async {
    for (final file in WhisperModelSpec.files) {
      if (!await File('${dir.path}/${file.fileName}').exists()) return false;
    }
    return true;
  }

  Future<sherpa_onnx.OfflineRecognizer> _ensureRecognizer(Directory dir) async {
    final existing = _recognizer;
    if (existing != null) return existing;

    await sherpa_onnx.initBindingsAsync();
    final whisper = sherpa_onnx.OfflineWhisperModelConfig(
      encoder: '${dir.path}/${WhisperModelSpec.encoderFileName}',
      decoder: '${dir.path}/${WhisperModelSpec.decoderFileName}',
      language: language,
      task: 'transcribe',
    );
    final modelConfig = sherpa_onnx.OfflineModelConfig(
      whisper: whisper,
      tokens: '${dir.path}/${WhisperModelSpec.tokensFileName}',
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
      // Defensive fallback only — see class doc. No path, no script name.
      return TextExtraction.stub(
        'تعذّر تجهيز ميزة تحويل الصوت إلى نص. حاول مرة أخرى.',
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
          'نموذج التعرف على الصوت مضغوط وسريع، وقد تقل دقّته مع اللهجات العربية؛ راجع النص قبل الاعتماد عليه.',
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

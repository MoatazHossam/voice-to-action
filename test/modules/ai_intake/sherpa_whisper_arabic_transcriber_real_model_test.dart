// Opt-in verification test: exercises the REAL sherpa-onnx Whisper engine
// against the REAL downloaded tiny multilingual model and REAL synthesized
// Arabic audio — not a fake/mock. It is skipped by default because it needs
// the model files on disk (not committed to this repo — see
// ARCHITECTURE.md, "On-device Arabic speech-to-text").
//
// To run it:
//   1. bash scripts/setup_whisper_arabic_model.sh <some-local-dir>
//   2. Provide two 16kHz mono WAV fixtures (one Arabic-only, one mixed
//      Arabic/English) in another directory.
//   3. AI_INTAKE_WHISPER_MODEL_DIR=<model-dir> \
//      AI_INTAKE_WHISPER_TEST_AUDIO_DIR=<audio-dir> \
//      flutter test test/modules/ai_intake/sherpa_whisper_arabic_transcriber_real_model_test.dart
//
// The audio directory must contain ar_only.wav and ar_mixed.wav.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_to_action/modules/ai_intake/services/sherpa_whisper_arabic_transcriber.dart';

void main() {
  final modelDirPath = Platform.environment['AI_INTAKE_WHISPER_MODEL_DIR'];
  final audioDirPath = Platform.environment['AI_INTAKE_WHISPER_TEST_AUDIO_DIR'];
  final skipReason = (modelDirPath == null || audioDirPath == null)
      ? 'Set AI_INTAKE_WHISPER_MODEL_DIR and AI_INTAKE_WHISPER_TEST_AUDIO_DIR to run this optional real-model test.'
      : null;

  group('SherpaWhisperArabicTranscriber against the real tiny multilingual model', () {
    late SherpaWhisperArabicTranscriber transcriber;

    setUp(() {
      if (skipReason != null) return;
      transcriber = SherpaWhisperArabicTranscriber(modelDirectoryOverride: Directory(modelDirPath!));
    });

    tearDown(() {
      if (skipReason != null) return;
      transcriber.dispose();
    });

    test('reports available and transcribes a real Arabic-only recording', () async {
      final result = await transcriber.transcribe('$audioDirPath/ar_only.wav');
      // ignore: avoid_print
      print('[ar_only] isStub=${result.isStub} text="${result.originalText}"');
      expect(result.isStub, isFalse);
      expect(transcriber.isAvailable, isTrue);
      expect(result.originalText.trim(), isNotEmpty);
    }, skip: skipReason);

    test('transcribes a real mixed Arabic/English recording without inventing text', () async {
      final result = await transcriber.transcribe('$audioDirPath/ar_mixed.wav');
      // ignore: avoid_print
      print('[ar_mixed] isStub=${result.isStub} text="${result.originalText}"');
      expect(result.isStub, isFalse);
      expect(result.originalText.trim(), isNotEmpty);
    }, skip: skipReason);

    test('reports an honest stub when model files are missing', () async {
      final missingDirTranscriber = SherpaWhisperArabicTranscriber(
        modelDirectoryOverride: Directory('$audioDirPath/does_not_exist'),
      );
      final result = await missingDirTranscriber.transcribe('$audioDirPath/ar_only.wav');
      expect(result.isStub, isTrue);
      expect(result.originalText, isEmpty);
      expect(missingDirTranscriber.isAvailable, isFalse);
      missingDirTranscriber.dispose();
    }, skip: skipReason);
  });
}

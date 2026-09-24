import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:voice_to_action/modules/ai_intake/services/tesseract_arabic_ocr_extractor.dart';
import 'package:voice_to_action/modules/ai_intake/services/tesseract_model_spec.dart';

/// These tests exercise `TesseractArabicOcrExtractor`'s own logic — output
/// mapping, empty/error handling, and image preprocessing — via an injected
/// fake OCR call ([OcrCall]). They intentionally do not invoke the real
/// native Tesseract engine (that needs a real device/simulator; see
/// ARCHITECTURE.md, "On-device Arabic OCR" for that verification).
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tesseract_extractor_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> installFakeTrainedData() async {
    for (final file in TesseractModelSpec.files) {
      await File('${tempDir.path}/${file.fileName}').writeAsBytes([0]);
    }
  }

  /// A tiny, genuinely valid image — enough for img.decodeImage to succeed.
  /// JPEG specifically: this package's PNG decoder does not parse the PNG
  /// eXIf chunk (its own source marks that "TODO"), but JPEG EXIF read/write
  /// is fully supported — and JPEG is what a real camera capture actually
  /// produces, so this is also the realistic case to test.
  Future<String> writeTestImage(Directory dir, {int orientation = 1}) async {
    final image = img.Image(width: 4, height: 2);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    if (orientation != 1) {
      image.exif.imageIfd.orientation = orientation;
    }
    final path = '${dir.path}/input.jpg';
    await File(path).writeAsBytes(img.encodeJpg(image));
    return path;
  }

  test('reports an honest stub when trained-data files are missing, and never calls OCR', () async {
    var called = false;
    final extractor = TesseractArabicOcrExtractor(
      modelDirectoryOverride: tempDir, // left empty: no trained-data files
      ocrCallOverride: (imagePath, {language, args}) async {
        called = true;
        return 'should not be reached';
      },
    );

    final path = await writeTestImage(tempDir);
    final result = await extractor.extract(path);

    expect(result.isStub, isTrue);
    expect(result.originalText, isEmpty);
    expect(called, isFalse);
    expect(extractor.isAvailable, isFalse);
  });

  test('maps real recognized text to a non-stub extraction with an accuracy warning', () async {
    await installFakeTrainedData();
    final extractor = TesseractArabicOcrExtractor(
      modelDirectoryOverride: tempDir,
      ocrCallOverride: (imagePath, {language, args}) async => '  فاتورة رقم 123  ',
    );

    final path = await writeTestImage(tempDir);
    final result = await extractor.extract(path);

    expect(result.isStub, isFalse);
    expect(result.originalText, 'فاتورة رقم 123'); // trimmed
    expect(result.segments, hasLength(1));
    expect(result.warnings, isNotEmpty);
    expect(extractor.isAvailable, isTrue);
  });

  test('an empty OCR result is honest (not a fabricated success) with a "try again" warning', () async {
    await installFakeTrainedData();
    final extractor = TesseractArabicOcrExtractor(
      modelDirectoryOverride: tempDir,
      ocrCallOverride: (imagePath, {language, args}) async => '   ',
    );

    final path = await writeTestImage(tempDir);
    final result = await extractor.extract(path);

    expect(result.isStub, isFalse);
    expect(result.originalText, isEmpty);
    expect(result.segments, isEmpty);
    expect(result.warnings.single, contains('لم يتم العثور على نص'));
  });

  test('an OCR engine failure degrades to an editable empty result instead of throwing', () async {
    await installFakeTrainedData();
    final extractor = TesseractArabicOcrExtractor(
      modelDirectoryOverride: tempDir,
      ocrCallOverride: (imagePath, {language, args}) async => throw Exception('native engine crashed'),
    );

    final path = await writeTestImage(tempDir);
    // Must not throw: allows the caller (AiIntakeController) to still reach
    // the editable review screen for manual entry, per this milestone's
    // requirement, rather than dead-ending on a hard failure screen.
    final result = await extractor.extract(path);

    expect(result.isStub, isFalse);
    expect(result.originalText, isEmpty);
    expect(result.warnings.single, contains('يمكنك كتابة النص يدويًا'));
  });

  test('an unsupported/corrupt image also degrades instead of throwing', () async {
    await installFakeTrainedData();
    var called = false;
    final extractor = TesseractArabicOcrExtractor(
      modelDirectoryOverride: tempDir,
      ocrCallOverride: (imagePath, {language, args}) async {
        called = true;
        return 'unreachable';
      },
    );

    final corruptPath = '${tempDir.path}/not_an_image.png';
    await File(corruptPath).writeAsBytes([0x00, 0x01, 0x02, 0x03]); // garbage, not a real image

    final result = await extractor.extract(corruptPath);

    expect(result.isStub, isFalse);
    expect(result.originalText, isEmpty);
    expect(called, isFalse, reason: 'preprocessing should fail before ever reaching the OCR call');
  });

  test('never leaves the .ocr.png intermediate file behind', () async {
    await installFakeTrainedData();
    final extractor = TesseractArabicOcrExtractor(
      modelDirectoryOverride: tempDir,
      ocrCallOverride: (imagePath, {language, args}) async => 'نص',
    );
    final path = await writeTestImage(tempDir);

    await extractor.extract(path);

    expect(File('$path.ocr.png').existsSync(), isFalse);
  });

  group('EXIF orientation correction', () {
    test('a sideways (orientation=6) image is rotated upright before OCR sees it', () async {
      await installFakeTrainedData();
      img.Image? prepared;
      final extractor = TesseractArabicOcrExtractor(
        modelDirectoryOverride: tempDir,
        ocrCallOverride: (imagePath, {language, args}) async {
          // Must read the prepared file here: the extractor deletes it in
          // its `finally` block once extract() returns.
          prepared = img.decodeImage(await File(imagePath).readAsBytes());
          return 'ok';
        },
      );

      // 4x2 source tagged as needing a 90-degree rotation (EXIF orientation
      // 6) should be baked into a 2x4 upright image before OCR.
      final path = await writeTestImage(tempDir, orientation: 6);
      await extractor.extract(path);

      expect(prepared, isNotNull);
      expect(prepared!.width, 2);
      expect(prepared!.height, 4);
      expect(prepared!.exif.imageIfd.hasOrientation, isFalse,
          reason: 'orientation should be baked into pixels, not left as a tag for a viewer to apply again');
    });

    test('an already-upright image is left at the same dimensions', () async {
      await installFakeTrainedData();
      img.Image? prepared;
      final extractor = TesseractArabicOcrExtractor(
        modelDirectoryOverride: tempDir,
        ocrCallOverride: (imagePath, {language, args}) async {
          prepared = img.decodeImage(await File(imagePath).readAsBytes());
          return 'ok';
        },
      );

      final path = await writeTestImage(tempDir); // orientation 1 (default/upright)
      await extractor.extract(path);

      expect(prepared!.width, 4);
      expect(prepared!.height, 2);
    });
  });
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Unified image picker helper that works on web and native.
///
/// Every picked image is automatically compressed client-side to a maximum
/// width of [kMaxCompressWidth] pixels and JPEG quality [kCompressQuality]
/// (70–80%) *before* it is uploaded to Storage. This keeps Storage usage and
/// download bandwidth low as the user base grows (the biggest Blaze cost risk).
class PickedImage {
  final Uint8List? bytes;
  final File? dartFile;

  /// Maximum width for uploaded images (keeps Storage/download cost low).
  static const double kMaxCompressWidth = 1280;

  /// JPEG quality (70–80%) — visually near-lossless but much smaller files.
  static const int kCompressQuality = 75;

  const PickedImage({this.bytes, this.dartFile});

  /// Resizes + JPEG-encodes [imageBytes] down to [kMaxCompressWidth] width and
  /// [kCompressQuality] quality. Returns the compressed JPEG bytes.
  ///
  /// This works identically on web and native (uses the pure-Dart `image`
  /// package, so no extra native plugin is needed).
  static Future<Uint8List> compressBytes(
    Uint8List imageBytes, {
    double maxWidth = kMaxCompressWidth,
    int quality = kCompressQuality,
  }) async {
    return compute(_compressSync, _CompressArgs(imageBytes, maxWidth, quality));
  }

  static Uint8List _compressSync(_CompressArgs args) {
    try {
      final decoded = img.decodeImage(args.bytes);
      if (decoded == null) return args.bytes;

      img.Image resized = decoded;
      if (decoded.width > args.maxWidth) {
        final scale = args.maxWidth / decoded.width;
        resized = img.copyResize(
          decoded,
          width: args.maxWidth.round(),
          height: (decoded.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );
      }

      return Uint8List.fromList(
        img.encodeJpg(resized, quality: args.quality),
      );
    } catch (e) {
      debugPrint('Image compression failed, using original: $e');
      return args.bytes;
    }
  }

  /// Returns the bytes to upload (compressing first when necessary).
  ///
  /// On web the picked file is already in memory; on native we read the file
  /// from disk, decode + resize + re-encode to JPEG, and return the compressed
  /// bytes so callers always upload a small JPEG regardless of source.
  Future<Uint8List> compressedUploadBytes() async {
    try {
      if (dartFile != null) {
        final raw = await dartFile!.readAsBytes();
        return compressBytes(raw);
      }
      if (bytes != null) return compressBytes(bytes!);
      return Uint8List(0);
    } catch (e) {
      debugPrint('compressedUploadBytes fallback: $e');
      if (bytes != null) return bytes!;
      if (dartFile != null) return await dartFile!.readAsBytes();
      return Uint8List(0);
    }
  }

  static Future<PickedImage?> pick(ImageSource source,
      {double maxWidth = kMaxCompressWidth,
      double maxHeight = kMaxCompressWidth,
      int imageQuality = kCompressQuality}) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (xFile == null) return null;

    if (kIsWeb) {
      // On web the OS picker ignores imageQuality, so compress in-memory before
      // handing the bytes back to any upload point.
      final raw = await xFile.readAsBytes();
      return PickedImage(bytes: await compressBytes(raw));
    } else {
      return PickedImage(dartFile: File(xFile.path));
    }
  }

  /// Multi-select image picker (works on web and native).
  static Future<List<PickedImage>> pickMultiple(
      {double maxWidth = kMaxCompressWidth,
      double maxHeight = kMaxCompressWidth,
      int imageQuality = kCompressQuality}) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    final out = <PickedImage>[];
    for (final xFile in files) {
      if (kIsWeb) {
        final raw = await xFile.readAsBytes();
        out.add(PickedImage(bytes: await compressBytes(raw)));
      } else {
        out.add(PickedImage(dartFile: File(xFile.path)));
      }
    }
    return out;
  }
}

/// Arguments for the synchronous compress function used with [compute].
class _CompressArgs {
  final Uint8List bytes;
  final double maxWidth;
  final int quality;

  const _CompressArgs(this.bytes, this.maxWidth, this.quality);
}
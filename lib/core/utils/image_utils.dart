import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Unified image picker helper that works on web and native.
class PickedImage {
  final Uint8List? bytes;
  final File? dartFile;

  const PickedImage({this.bytes, this.dartFile});

  static Future<PickedImage?> pick(ImageSource source,
      {double maxWidth = 1024, double maxHeight = 1024, int imageQuality = 85}) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (xFile == null) return null;

    if (kIsWeb) {
      final bytes = await xFile.readAsBytes();
      return PickedImage(bytes: bytes);
    } else {
      return PickedImage(dartFile: File(xFile.path));
    }
  }
}
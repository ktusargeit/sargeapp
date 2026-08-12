import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cross-platform image display widget.
/// On web: shows from bytes. On native: shows from File.
class PlatformImageFile extends StatelessWidget {
  final Uint8List? bytes;
  final File? file;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  const PlatformImageFile({
    super.key,
    this.bytes,
    this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (kIsWeb && bytes != null) {
      provider = MemoryImage(bytes!);
    } else if (!kIsWeb && file != null) {
      provider = FileImage(file!);
    }
    if (provider == null) {
      return Container(
        width: width ?? double.infinity,
        height: height ?? 100,
        color: Colors.grey[800],
        child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image(
        image: provider,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
}
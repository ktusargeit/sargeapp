import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'platform_image.dart';

/// Opens a full-screen zoomable image viewer. Supports web (bytes) and
/// native (File). Tapping also supports a list of images with swiping.
void showFullScreenImageViewer(
  BuildContext context, {
  List<String>? urls,
  int initialIndex = 0,
  Uint8List? bytes,
}) {
  if (urls != null && urls.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NetworkImageViewer(
          urls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
    return;
  }

  if (bytes != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ByteImageViewer(bytes: bytes),
      ),
    );
  }
}

/// Jump to full screen for a network image.
void openNetworkImageViewer(BuildContext context, String url) {
  showFullScreenImageViewer(context, urls: [url]);
}

class _NetworkImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _NetworkImageViewer({required this.urls, this.initialIndex = 0});

  @override
  State<_NetworkImageViewer> createState() => _NetworkImageViewerState();
}

class _NetworkImageViewerState extends State<_NetworkImageViewer> {
  late final PageController _controller;
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: widget.urls.length > 1
            ? Text('${_index + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white))
            : null,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5.0,
          minScale: 1.0,
          child: Center(
            child: Image.network(
              widget.urls[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ByteImageViewer extends StatelessWidget {
  final Uint8List bytes;
  const _ByteImageViewer({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: InteractiveViewer(
        maxScale: 5.0,
        minScale: 1.0,
        child: Center(
          child: PlatformImageFile(
            bytes: bytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

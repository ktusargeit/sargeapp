import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders [text] while automatically turning URLs into tappable links.
///
/// Detects `http://`, `https://` and `www.` prefixed URLs and opens them in an
/// external application via [url_launcher].
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final int? maxLines;
  final TextOverflow overflow;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkColor,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final RegExp _urlRegex = RegExp(
    r'((?:https?:\/\/|www\.)[^\s]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort; never let a failed launch break the UI.
    }
  }

  String _normalizeUrl(String raw) {
    var value = raw.startsWith('www.') ? 'https://$raw' : raw;
    // Strip trailing punctuation that is unlikely to be part of the URL.
    value = value.replaceFirst(RegExp(r'[).,;:!?]+$'), '');
    return value;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final linkColor = widget.linkColor ?? Theme.of(context).colorScheme.primary;

    final spans = <InlineSpan>[];
    final matches = _urlRegex.allMatches(widget.text);
    int last = 0;

    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final rawUrl = m.group(0)!;
      final target = _normalizeUrl(rawUrl);
      final recognizer = TapGestureRecognizer()..onTap = () => _open(target);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: widget.text.substring(m.start, m.end),
        style: baseStyle.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
        ),
        recognizer: recognizer,
      ));
      last = m.end;
    }

    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

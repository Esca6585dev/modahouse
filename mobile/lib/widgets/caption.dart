import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';

/// One piece of a caption: plain text, a #hashtag or an @mention.
class CaptionToken {
  const CaptionToken(this.text, {this.tag, this.mention});

  final String text;

  /// Hashtag without "#".
  final String? tag;

  /// Username without "@".
  final String? mention;
}

final _tokenRe = RegExp(r'([#@])([\p{L}\p{N}_.]+)', unicode: true);

/// Splits a caption into text, hashtags and mentions.
List<CaptionToken> tokenizeCaption(String text) {
  final out = <CaptionToken>[];
  var last = 0;
  for (final m in _tokenRe.allMatches(text)) {
    // "#" must start a word (not "abc#def").
    if (m.start > 0 &&
        RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(text[m.start - 1])) {
      continue;
    }
    var word = m.group(2)!;
    // A trailing "." ends the sentence, it is not part of the name.
    var end = m.end;
    while (word.endsWith('.')) {
      word = word.substring(0, word.length - 1);
      end--;
    }
    if (word.isEmpty) continue;
    if (m.start > last) out.add(CaptionToken(text.substring(last, m.start)));
    final raw = text.substring(m.start, end);
    out.add(
      m.group(1) == '#'
          ? CaptionToken(raw, tag: word)
          : CaptionToken(raw, mention: word),
    );
    last = end;
  }
  if (last < text.length) out.add(CaptionToken(text.substring(last)));
  return out;
}

/// Instagram-style caption: optional bold [author] prefix, tappable
/// #hashtags (→ `/tag/…`) and @mentions (→ `/user/…`), collapsed to
/// [maxLines] with "… köpräk".
class RichCaption extends StatefulWidget {
  const RichCaption({
    super.key,
    required this.text,
    this.author,
    this.onAuthorTap,
    this.maxLines = 2,
    this.style,
    this.linkColor,
  });

  final String text;
  final String? author;
  final VoidCallback? onAuthorTap;
  final int maxLines;
  final TextStyle? style;

  /// Color of hashtags and mentions (default: Instagram link blue).
  final Color? linkColor;

  @override
  State<RichCaption> createState() => _RichCaptionState();
}

class _RichCaptionState extends State<RichCaption> {
  bool _expanded = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback f) {
    final r = TapGestureRecognizer()..onTap = f;
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final p = AppPalette.of(context);
    final base =
        widget.style ?? TextStyle(fontSize: 14.5, height: 1.4, color: p.text);
    const link = TextStyle(
      color: Color(0xFF00376B),
      fontWeight: FontWeight.w600,
    );
    final linkStyle = widget.linkColor != null
        ? link.copyWith(color: widget.linkColor)
        : Theme.of(context).brightness == Brightness.dark
        ? link.copyWith(color: const Color(0xFFE0F1FF))
        : link;
    final router = GoRouter.maybeOf(context);
    final spans = <InlineSpan>[
      if (widget.author != null)
        TextSpan(
          text: '${widget.author} ',
          style: const TextStyle(fontWeight: FontWeight.w700),
          recognizer: widget.onAuthorTap == null
              ? null
              : _tap(widget.onAuthorTap!),
        ),
      for (final t in tokenizeCaption(widget.text))
        if (t.tag != null)
          TextSpan(
            text: t.text,
            style: linkStyle,
            recognizer: router == null
                ? null
                : _tap(
                    () => router.push('/tag/${Uri.encodeComponent(t.tag!)}'),
                  ),
          )
        else if (t.mention != null)
          TextSpan(
            text: t.text,
            style: linkStyle,
            recognizer: router == null
                ? null
                : _tap(
                    () =>
                        router.push('/user/${Uri.encodeComponent(t.mention!)}'),
                  ),
          )
        else
          TextSpan(text: t.text),
    ];
    final span = TextSpan(style: base, children: spans);
    if (_expanded) return Text.rich(span);
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          text: span,
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: c.maxWidth);
        if (!tp.didExceedMaxLines) return Text.rich(span);
        return GestureDetector(
          onTap: () => setState(() => _expanded = true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                span,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
              Semantics(
                button: true,
                child: Text(
                  '… ${S.moreText}',
                  style: base.copyWith(color: p.muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

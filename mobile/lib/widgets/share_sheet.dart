import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/download/download.dart';
import '../core/share_links.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/providers.dart';
import 'pin_menu.dart';
import 'states.dart';

/// Opens the Pinterest-style share sheet for [pin]: a preview of the branded
/// share card (`/pins/:id/share-card`) and the share targets.
Future<void> showShareSheet(BuildContext context, Pin pin) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ShareSheet(pin: pin),
    );

/// The targets, in order. Keys are `share-<name>` in widget tests.
enum ShareTarget { copy, whatsapp, telegram, instagram, image, download, more }

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.pin});

  final Pin pin;

  /// The card shown in the preview and shared as an image.
  String get cardUrl => AppConfig.pinShareCardUrl(pin.id);

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late Future<FetchedMedia> _card;
  ShareTarget? _busy;

  Pin get pin => widget.pin;
  String get _link => AppConfig.pinLink(pin.id);

  @override
  void initState() {
    super.initState();
    _card = _loadCard();
  }

  Future<FetchedMedia> _loadCard() =>
      ref.read(mediaLoaderProvider)(widget.cardUrl);

  void _retry() {
    final next = _loadCard();
    setState(() {
      _card = next;
    });
  }

  Future<FetchedMedia?> _cardOrNull() async {
    try {
      return await _card;
    } catch (_) {
      return null;
    }
  }

  XFile _cardFile(FetchedMedia card) => XFile.fromData(
    card.bytes,
    name: pinShareCardFileName(pin.id),
    mimeType: card.mimeType,
  );

  Future<void> _open(Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) showSnack(S.cannotOpenLink, error: true);
  }

  /// Shares [files] (+ [text]); when the platform can't, saves the card and
  /// copies the link instead so the user still gets both.
  Future<void> _shareFiles(
    FetchedMedia card, {
    String? text,
    bool copyLink = false,
  }) async {
    try {
      final res = await SharePlus.instance.share(
        ShareParams(
          files: [_cardFile(card)],
          fileNameOverrides: [pinShareCardFileName(pin.id)],
          text: text,
          subject: pin.title,
        ),
      );
      if (res.status == ShareResultStatus.unavailable) {
        throw Exception('unavailable');
      }
      if (copyLink) showSnack(S.instagramLinkCopied);
    } catch (_) {
      await saveFile(card.bytes, pinShareCardFileName(pin.id), card.mimeType);
      await Clipboard.setData(ClipboardData(text: _link));
      showSnack(S.linkCopied);
    }
  }

  Future<void> _run(ShareTarget target) async {
    if (_busy != null) return;
    final nav = Navigator.of(context);
    FetchedMedia? card;
    const needsCard = {
      ShareTarget.instagram,
      ShareTarget.image,
      ShareTarget.download,
    };
    if (needsCard.contains(target)) {
      setState(() => _busy = target);
      card = await _cardOrNull();
      if (!mounted) return;
      setState(() => _busy = null);
      if (card == null && target != ShareTarget.image) {
        showSnack(S.shareCardFailed, error: true);
        return;
      }
    }
    if (nav.canPop()) nav.pop();
    try {
      switch (target) {
        case ShareTarget.copy:
          await Clipboard.setData(ClipboardData(text: _link));
          showSnack(S.linkCopied);
        case ShareTarget.whatsapp:
          await _open(whatsappShareUri(_link, text: pin.title));
        case ShareTarget.telegram:
          await _open(telegramShareUri(_link, text: pin.title));
        case ShareTarget.instagram:
          // Instagram ignores shared text: the link goes to the clipboard so it
          // can be pasted into the story's link sticker.
          await Clipboard.setData(ClipboardData(text: _link));
          await _shareFiles(card!, copyLink: true);
        case ShareTarget.image:
          if (card == null) {
            await sharePin(pin);
          } else {
            await _shareFiles(card, text: pinShareText(pin));
          }
        case ShareTarget.download:
          await saveFile(
            card!.bytes,
            pinShareCardFileName(pin.id),
            card.mimeType,
          );
          showSnack(S.downloaded);
        case ShareTarget.more:
          await sharePin(pin);
      }
    } catch (_) {
      showSnack(S.genericError, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final previewHeight = (size.height * 0.42).clamp(220.0, 400.0);

    Widget target(
      ShareTarget t,
      String label,
      IconData icon, {
      Color? color,
      Gradient? gradient,
      Color? iconColor,
    }) => _TargetButton(
      key: Key('share-${t.name}'),
      label: label,
      icon: icon,
      color: color ?? p.surface,
      gradient: gradient,
      iconColor:
          iconColor ??
          (color == null && gradient == null ? p.text : Colors.white),
      busy: _busy == t,
      onTap: () => _run(t),
    );

    final targets = [
      target(ShareTarget.copy, S.menuCopyLink, Icons.link_rounded),
      target(
        ShareTarget.whatsapp,
        S.whatsapp,
        Icons.chat_rounded,
        color: const Color(0xFF25D366),
      ),
      target(
        ShareTarget.telegram,
        S.telegram,
        Icons.telegram,
        color: const Color(0xFF229ED9),
      ),
      target(
        ShareTarget.instagram,
        S.instagram,
        Icons.camera_alt_outlined,
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFFFEDA75),
            Color(0xFFFA7E1E),
            Color(0xFFD62976),
            Color(0xFF962FBF),
            Color(0xFF4F5BD5),
          ],
        ),
      ),
      target(
        ShareTarget.image,
        S.shareWithImage,
        Icons.photo_outlined,
        color: AppPalette.accent,
      ),
      target(ShareTarget.download, S.menuDownload, Icons.download_rounded),
      target(ShareTarget.more, S.shareMore, Icons.more_horiz_rounded),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card preview on a soft panel, like Pinterest's screenshot share.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: SizedBox(
                height: previewHeight,
                width: previewHeight * 9 / 16,
                child: _CardPreview(
                  url: widget.cardUrl,
                  future: _card,
                  onRetry: _retry,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            S.shareSheetTitle,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              const perRow = 4;
              final w = c.maxWidth / perRow;
              return Wrap(
                runSpacing: 14,
                children: [
                  for (final t in targets) SizedBox(width: w, child: t),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The share card scaled into the sheet: shimmer while it is generated,
/// rounded corners, retry on error.
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.url,
    required this.future,
    required this.onRetry,
  });

  final String url;
  final Future<FetchedMedia> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FutureBuilder<FetchedMedia>(
      future: future,
      builder: (context, snap) {
        Widget child;
        if (snap.hasData) {
          child = Image.memory(
            snap.data!.bytes,
            key: const Key('share-card-image'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            semanticLabel: S.shareCard,
          );
        } else if (snap.hasError) {
          child = ColoredBox(
            color: p.surface2,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: p.muted),
                  const SizedBox(height: 6),
                  Text(
                    S.shareCardFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                  TextButton(onPressed: onRetry, child: const Text(S.retry)),
                ],
              ),
            ),
          );
        } else {
          child = Semantics(
            label: S.shareCardLoading,
            child: const Skeleton(radius: 0),
          );
        }
        return DecoratedBox(
          key: ValueKey('share-card:$url'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: SizedBox.expand(
                key: ValueKey(snap.connectionState),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A big round share button with its label under it.
class _TargetButton extends StatelessWidget {
  const _TargetButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.gradient,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final Gradient? gradient;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: gradient == null ? color : null,
                  gradient: gradient,
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? Center(child: Spinner(size: 20, color: iconColor))
                    : Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

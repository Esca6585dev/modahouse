import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/chat_format.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import 'app_image.dart';
import 'avatar.dart';
import 'shop_ui.dart';
import 'states.dart';

/// Brand red of my bubbles.
const myBubbleColor = AppPalette.accent;

/// An avatar with a small storefront badge for business accounts.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.user, this.size = 52});

  final UserBrief user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final avatar = UserAvatar(user: user, size: size);
    if (!user.isBusiness) return avatar;
    final badge = size * 0.36;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: AppPalette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: p.bg, width: 2),
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: badge * 0.58,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the chat list: avatar, name, preview, time and unread pill.
class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.typing = false,
    this.now,
  });

  final Chat chat;
  final VoidCallback onTap;
  final bool typing;

  /// Fixed clock for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final unread = chat.unreadCount > 0;
    final last = chat.lastMessage;
    final preview = typing
        ? S.typing
        : last == null
        ? '@${chat.other.username}'
        : messagePreview(last);
    final time = chatTime(last?.createdAt ?? chat.updatedAt, now: now);
    return Semantics(
      button: true,
      label: [
        chat.other.displayName,
        preview,
        if (unread) '${chat.unreadCount}',
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppPalette.gutter,
            vertical: 9,
          ),
          child: Row(
            children: [
              ChatAvatar(user: chat.other),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: UserName(
                            user: chat.other,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: unread ? AppPalette.accent : p.muted,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (!typing && last != null && last.mine) ...[
                          ReadTicks(message: last, color: p.muted, size: 15),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: typing
                                  ? AppPalette.accent
                                  : unread
                                  ? p.text
                                  : p.muted,
                              fontWeight: unread || typing
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontStyle: last?.deleted == true && !typing
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          UnreadPill(count: chat.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red pill with the unread count.
class UnreadPill extends StatelessWidget {
  const UnreadPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22),
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppPalette.accent,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );
}

/// ✓ sent, ✓✓ read, a clock while sending, ! when it failed.
class ReadTicks extends StatelessWidget {
  const ReadTicks({
    super.key,
    required this.message,
    required this.color,
    this.readColor,
    this.size = 16,
  });

  final Message message;
  final Color color;
  final Color? readColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color c) = switch (message.status) {
      MessageStatus.pending => (Icons.schedule_rounded, S.sending, color),
      MessageStatus.failed => (
        Icons.error_outline_rounded,
        S.notSent,
        AppPalette.danger,
      ),
      MessageStatus.sent when message.read => (
        Icons.done_all_rounded,
        S.messageRead,
        readColor ?? const Color(0xFF34B7F1),
      ),
      MessageStatus.sent => (Icons.done_rounded, S.messageSent, color),
    };
    return Semantics(
      label: label,
      child: Icon(
        icon,
        key: Key('ticks-${message.status.name}${message.read ? '-read' : ''}'),
        size: size,
        color: c,
      ),
    );
  }
}

/// "Şu gün" / "Düýn" / "12 oktýabr" between days.
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

IconData fileIcon(String name, String mime) {
  final ext = name.toLowerCase().split('.').last;
  if (mime.startsWith('audio/')) return Icons.audiotrack_rounded;
  if (mime.startsWith('video/')) return Icons.movie_outlined;
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'doc' || 'docx' || 'txt' => Icons.description_rounded,
    'xls' || 'xlsx' => Icons.table_chart_rounded,
    'ppt' || 'pptx' => Icons.slideshow_rounded,
    'zip' => Icons.folder_zip_rounded,
    _ => Icons.insert_drive_file_rounded,
  };
}

/// One message bubble. Mine: brand red on the right; theirs: gray on the
/// left. [first]/[last] = position inside a group from one sender (the
/// tail corner is sharper).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.first = true,
    this.last = true,
    this.onLongPress,
    this.onOpenImage,
    this.onOpenFile,
    this.onOpenPin,
    this.onRetry,
  });

  final Message message;
  final bool first;
  final bool last;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpenImage;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenPin;
  final VoidCallback? onRetry;

  static const _r = Radius.circular(20);
  static const _small = Radius.circular(6);

  BorderRadius get _radius {
    final mine = message.mine;
    return BorderRadius.only(
      topLeft: !mine && !first ? _small : _r,
      bottomLeft: !mine && !last ? _small : _r,
      topRight: mine && !first ? _small : _r,
      bottomRight: mine && !last ? _small : _r,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final mine = message.mine;
    final bg = message.deleted
        ? Colors.transparent
        : mine
        ? myBubbleColor
        : p.surface;
    final fg = mine && !message.deleted ? Colors.white : p.text;
    final meta = mine && !message.deleted
        ? Colors.white.withValues(alpha: 0.85)
        : p.muted;
    final maxW = MediaQuery.sizeOf(context).width * 0.76;

    Widget content;
    var padded = true;
    if (message.deleted) {
      content = _deleted(p);
    } else {
      switch (message.kind) {
        case MessageKind.image:
          padded = false;
          content = _image(context, fg, meta);
        case MessageKind.file:
          content = _file(fg, meta);
        case MessageKind.pin:
          padded = false;
          content = _pin(context, fg, meta);
        case MessageKind.text:
          content = _text(fg, meta);
      }
    }

    final bubble = Container(
      key: Key(
        'bubble-${message.clientId.isEmpty ? message.id : message.clientId}',
      ),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _radius,
        border: message.deleted ? Border.all(color: p.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      padding: padded
          ? const EdgeInsets.fromLTRB(12, 8, 10, 6)
          : EdgeInsets.zero,
      child: content,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: mine ? 56 : 0,
        right: mine ? 0 : 56,
        top: first ? 6 : 1.5,
        bottom: last ? 2 : 1.5,
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: message.deleted ? null : onLongPress,
            child: Opacity(
              opacity: message.isPending && message.file == null ? 0.75 : 1,
              child: bubble,
            ),
          ),
          if (message.isFailed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InkWell(
                key: Key('retry-${message.clientId}'),
                onTap: onRetry,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 15,
                        color: AppPalette.danger,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${S.notSent} · ${S.retrySend}',
                        style: TextStyle(
                          color: AppPalette.danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _meta(Color color, {bool onImage = false}) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clockTime(message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: onImage ? Colors.white : color,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (message.mine) ...[
          const SizedBox(width: 3),
          ReadTicks(
            message: message,
            color: onImage ? Colors.white : color,
            readColor: onImage || message.mine ? Colors.white : null,
            size: 14,
          ),
        ],
      ],
    );
    if (!onImage) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: row,
    );
  }

  Widget _text(Color fg, Color meta) => Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.end,
    spacing: 8,
    children: [
      Text(
        message.text,
        style: TextStyle(color: fg, fontSize: 15.5, height: 1.3),
      ),
      Padding(padding: const EdgeInsets.only(top: 2), child: _meta(meta)),
    ],
  );

  Widget _deleted(AppPalette p) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.block_rounded, size: 16, color: p.muted),
      const SizedBox(width: 6),
      Text(
        S.messageDeleted,
        style: TextStyle(
          color: p.muted,
          fontStyle: FontStyle.italic,
          fontSize: 14.5,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        clockTime(message.createdAt),
        style: TextStyle(fontSize: 11, color: p.muted),
      ),
    ],
  );

  Widget _caption(Color fg, Color meta) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
    child: _text(fg, meta),
  );

  Widget _image(BuildContext context, Color fg, Color meta) {
    final a = message.attachment;
    final file = message.file;
    final ratio = file != null && file.width > 0 && file.height > 0
        ? (file.width / file.height).clamp(0.5, 1.9).toDouble()
        : a?.aspectRatio ?? 1;
    final width = (MediaQuery.sizeOf(context).width * 0.64).clamp(0.0, 320.0);
    final Widget picture = file != null && message.isLocal
        ? Image.memory(file.bytes, fit: BoxFit.cover, gaplessPlayback: true)
        : AppImage(
            a?.url ?? '',
            semanticLabel: S.photoPreview,
            cacheWidth: width,
          );
    final progress = message.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  button: onOpenImage != null,
                  label: S.photoPreview,
                  child: GestureDetector(
                    key: Key('image-${message.id}'),
                    onTap: message.isLocal ? null : onOpenImage,
                    child: picture,
                  ),
                ),
                if (message.isPending && progress != null)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 46,
                        child: CircularProgressIndicator(
                          value: progress <= 0 ? null : progress,
                          strokeWidth: 3.5,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                if (message.text.isEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _meta(meta, onImage: true),
                  ),
              ],
            ),
          ),
        ),
        if (message.text.isNotEmpty)
          SizedBox(width: width, child: _caption(fg, meta)),
      ],
    );
  }

  Widget _file(Color fg, Color meta) {
    final a = message.attachment;
    final name = a?.name ?? S.fileLabel;
    final mine = message.mine;
    final progress = message.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: Key('file-${message.id}'),
          onTap: message.isLocal ? null : onOpenFile,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppPalette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: message.isPending && progress != null
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          value: progress <= 0 ? null : progress,
                          strokeWidth: 2.5,
                          color: mine ? Colors.white : AppPalette.accent,
                        ),
                      )
                    : Icon(
                        fileIcon(name, a?.mimeType ?? ''),
                        color: mine ? Colors.white : AppPalette.accent,
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize(a?.size ?? 0),
                      style: TextStyle(color: meta, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (message.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _text(fg, meta),
          )
        else
          _meta(meta),
      ],
    );
  }

  Widget _pin(BuildContext context, Color fg, Color meta) {
    final pin = message.pin;
    final width = (MediaQuery.sizeOf(context).width * 0.6).clamp(0.0, 280.0);
    if (pin == null) return _caption(fg, meta);
    final ratio = pin.width > 0 && pin.height > 0
        ? (pin.width / pin.height).clamp(0.75, 1.6).toDouble()
        : 0.8;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: '${S.postPreview}: ${pin.title}',
            child: InkWell(
              key: Key('pin-${pin.id}'),
              onTap: onOpenPin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: ratio,
                    child: AppImage(
                      pin.imageUrl,
                      placeholder: parseHexColor(pin.color, Colors.black12),
                      cacheWidth: width,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      pin.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (pin.price > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                      child: Text(
                        switch (pin.listingType) {
                          'rent' => '${formatPrice(pin.price)} ${S.perDay}',
                          'custom' => S.priceFromLine(formatPrice(pin.price)),
                          _ => formatPrice(pin.price),
                        },
                        style: TextStyle(
                          color: message.mine
                              ? Colors.white
                              : AppPalette.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 10, 6),
            child: message.text.isEmpty
                ? Align(alignment: Alignment.centerRight, child: _meta(meta))
                : _text(fg, meta),
          ),
        ],
      ),
    );
  }
}

/// What the composer sends: text, plus at most one file or post.
class ComposerDraft {
  const ComposerDraft({this.text = '', this.file, this.pin});

  final String text;
  final OutgoingFile? file;
  final PinPreview? pin;

  bool get isEmpty => text.trim().isEmpty && file == null && pin == null;
}

enum AttachSource { camera, gallery, file }

/// Multiline field, attach menu, preview of the attached file/post and the
/// send button.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.onAttach,
    this.onTyping,
    this.initialText = '',
    this.initialPin,
  });

  final void Function(ComposerDraft draft) onSend;

  /// Picks a file from [AttachSource]; null = cancelled.
  final Future<OutgoingFile?> Function(AttachSource source)? onAttach;
  final VoidCallback? onTyping;
  final String initialText;
  final PinPreview? initialPin;

  @override
  State<ChatComposer> createState() => ChatComposerState();
}

class ChatComposerState extends State<ChatComposer> {
  late final _text = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  OutgoingFile? _file;
  PinPreview? _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _last = '';

  void _changed() {
    final t = _text.text;
    if (t == _last) return;
    final grew = t.length > _last.length;
    _last = t;
    setState(() {});
    if (grew) widget.onTyping?.call();
  }

  ComposerDraft get _draft =>
      ComposerDraft(text: _text.text, file: _file, pin: _pin);

  void _send() {
    final d = _draft;
    if (d.isEmpty) return;
    widget.onSend(d);
    _text.clear();
    setState(() {
      _file = null;
      _pin = null;
    });
  }

  Future<void> _attach() async {
    final pick = widget.onAttach;
    if (pick == null) return;
    final source = await showModalBottomSheet<AttachSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                key: const Key('attach-camera'),
                icon: Icons.photo_camera_rounded,
                label: S.camera,
                color: const Color(0xFF1A73E8),
                onTap: () => Navigator.of(ctx).pop(AttachSource.camera),
              ),
              _AttachOption(
                key: const Key('attach-gallery'),
                icon: Icons.photo_library_rounded,
                label: S.gallery,
                color: const Color(0xFF8E44AD),
                onTap: () => Navigator.of(ctx).pop(AttachSource.gallery),
              ),
              _AttachOption(
                key: const Key('attach-file'),
                icon: Icons.insert_drive_file_rounded,
                label: S.fileLabel,
                color: const Color(0xFFE37400),
                onTap: () => Navigator.of(ctx).pop(AttachSource.file),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await pick(source);
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _pin = null;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final canSend = !_draft.isEmpty;
    final attached = _file != null || _pin != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attached) _preview(p),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.onAttach != null)
                    IconButton(
                      key: const Key('composer-attach'),
                      tooltip: S.attach,
                      onPressed: _attach,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      iconSize: 28,
                      color: AppPalette.accent,
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        key: const Key('composer-field'),
                        controller: _text,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 15.5),
                        decoration: InputDecoration(
                          hintText: attached ? S.captionHint : S.messageHint,
                          counterText: '',
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: canSend ? 1 : 0.9,
                    child: Semantics(
                      button: true,
                      enabled: canSend,
                      label: S.sendMessage,
                      excludeSemantics: true,
                      onTap: canSend ? _send : null,
                      child: Material(
                        color: canSend ? AppPalette.accent : p.surface2,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('composer-send'),
                          customBorder: const CircleBorder(),
                          onTap: canSend ? _send : null,
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(
                              Icons.send_rounded,
                              size: 21,
                              color: canSend ? Colors.white : p.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(AppPalette p) {
    final file = _file;
    final pin = _pin;
    Widget thumb;
    String title;
    String subtitle;
    if (file != null && file.isImage) {
      thumb = Image.memory(file.bytes, fit: BoxFit.cover);
      title = S.photoPreview;
      subtitle = fileSize(file.bytes.length);
    } else if (file != null) {
      thumb = ColoredBox(
        color: AppPalette.accent.withValues(alpha: 0.12),
        child: Icon(
          fileIcon(file.name, file.mimeType),
          color: AppPalette.accent,
        ),
      );
      title = file.name;
      subtitle = fileSize(file.bytes.length);
    } else {
      thumb = AppImage(pin!.imageUrl, cacheWidth: 56);
      title = pin.title;
      subtitle = S.postPreview;
    }
    return Container(
      key: const Key('composer-preview'),
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(dimension: 52, child: thumb),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.discard,
            onPressed: () => setState(() {
              _file = null;
              _pin = null;
            }),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shown instead of the composer in a blocked chat.
class BlockedNotice extends StatelessWidget {
  const BlockedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded, color: p.muted),
              const SizedBox(height: 6),
              const Text(
                S.chatBlocked,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                S.chatBlockedText,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen photo with pinch zoom and "Suraty sakla".
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.url, this.onSave});

  final String url;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (onSave != null)
            IconButton(
              tooltip: S.saveImage,
              onPressed: onSave,
              icon: const Icon(Icons.download_rounded, color: Colors.white),
            ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: AppImage(
            url,
            fit: BoxFit.contain,
            placeholder: Colors.black,
            semanticLabel: S.photoPreview,
          ),
        ),
      ),
    ),
  );
}

/// A small spinner row ("Öňki habarlar ýüklenýär…").
class OlderLoader extends StatelessWidget {
  const OlderLoader({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Center(child: Spinner(size: 20)),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import 'avatar.dart';
import 'chat_launch.dart';
import 'shop_ui.dart';

String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

String _handle(String v) => v.trim().replaceFirst(RegExp(r'^@'), '');

/// One way to reach a shop.
class ContactLink {
  const ContactLink({
    required this.kind,
    required this.label,
    required this.value,
    required this.icon,
    this.uri,
    this.copyText,
    this.color,
  });

  /// phone, whatsapp, telegram, imo, instagram, tiktok, youtube, website.
  final String kind;
  final String label;

  /// Shown under the label (number, @handle, address).
  final String value;
  final IconData icon;

  /// Opened on tap; null = [copyText] is copied instead.
  final Uri? uri;
  final String? copyText;
  final Color? color;
}

/// Phone, WhatsApp (with the prefilled [message]), Telegram, IMO and the
/// social profiles of a business, in display order.
List<ContactLink> contactLinks(Business b, {String message = ''}) {
  final out = <ContactLink>[];
  if (b.phone.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'phone',
        label: S.call,
        value: b.phone,
        icon: Icons.call_rounded,
        uri: Uri(
          scheme: 'tel',
          path:
              '${b.phone.trim().startsWith('+') ? '+' : ''}${_digits(b.phone)}',
        ),
        color: const Color(0xFF1E8E3E),
      ),
    );
  }
  final wa = b.whatsapp.isNotEmpty ? b.whatsapp : '';
  if (wa.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'whatsapp',
        label: S.whatsapp,
        value: wa,
        icon: Icons.chat_rounded,
        uri: Uri.parse(
          'https://wa.me/${_digits(wa)}'
          '${message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}'}',
        ),
        color: const Color(0xFF25D366),
      ),
    );
  }
  if (b.telegram.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'telegram',
        label: S.telegram,
        value: '@${_handle(b.telegram)}',
        icon: Icons.send_rounded,
        uri: Uri.parse('https://t.me/${_handle(b.telegram)}'),
        color: const Color(0xFF229ED9),
      ),
    );
  }
  if (b.imo.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'imo',
        label: S.imo,
        value: b.imo,
        icon: Icons.videocam_rounded,
        // IMO has no public web link: copy the number to paste in the app.
        copyText: b.imo,
        color: const Color(0xFF0C7BDC),
      ),
    );
  }
  if (b.instagram.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'instagram',
        label: S.instagram,
        value: '@${_handle(b.instagram)}',
        icon: Icons.camera_alt_rounded,
        uri: Uri.parse('https://instagram.com/${_handle(b.instagram)}'),
        color: const Color(0xFFD62976),
      ),
    );
  }
  if (b.tiktok.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'tiktok',
        label: S.tiktok,
        value: '@${_handle(b.tiktok)}',
        icon: Icons.music_note_rounded,
        uri: Uri.parse('https://www.tiktok.com/@${_handle(b.tiktok)}'),
        color: const Color(0xFF111111),
      ),
    );
  }
  if (b.youtube.isNotEmpty) {
    final yt = b.youtube.trim();
    out.add(
      ContactLink(
        kind: 'youtube',
        label: S.youtube,
        value: yt,
        icon: Icons.smart_display_rounded,
        uri: Uri.parse(
          yt.startsWith('http') ? yt : 'https://youtube.com/@${_handle(yt)}',
        ),
        color: const Color(0xFFFF0000),
      ),
    );
  }
  if (b.website.isNotEmpty) {
    out.add(
      ContactLink(
        kind: 'website',
        label: S.website,
        value: b.website.replaceFirst(RegExp(r'^https?://'), ''),
        icon: Icons.language_rounded,
        uri: Uri.tryParse(b.website),
        color: const Color(0xFF5F6368),
      ),
    );
  }
  return out;
}

Future<void> openContact(ContactLink l) async {
  final uri = l.uri;
  if (uri == null) {
    await Clipboard.setData(ClipboardData(text: l.copyText ?? l.value));
    showSnack('${l.label}: ${l.value} · ${S.linkCopied.toLowerCase()}');
    return;
  }
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    showSnack(l.kind == 'phone' ? S.cannotCall : S.cannotOpenLink, error: true);
  }
}

/// Round social buttons for a business profile.
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key, required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final links = contactLinks(business)
        .where((l) => l.kind != 'phone')
        .toList();
    if (links.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in links)
          Tooltip(
            message: l.label,
            child: Semantics(
              button: true,
              label: l.label,
              excludeSemantics: true,
              onTap: () => openContact(l),
              child: Material(
                color: p.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => openContact(l),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(l.icon, size: 20, color: l.color ?? p.text),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Kärendä al" / "Sargyt et": every way to reach the shop plus the
/// prefilled message "Salam! ModaHouse-da «…» gördüm…". The first option,
/// "ModaHouse-da ýaz", opens the in-app chat with that message and [pin]
/// attached.
Future<void> showContactSheet(
  BuildContext context, {
  required UserBrief shop,
  required Business? business,
  String title = '',
  PinPreview? pin,
}) {
  final message = title.isEmpty ? '' : S.contactMessage(title);
  final links = business == null
      ? const <ContactLink>[]
      : contactLinks(business, message: message);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(user: shop, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserName(
                          user: shop,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          S.contactSubtitle,
                          style: TextStyle(color: p.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(height: 1.4, fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ListTile(
                key: const Key('contact-chat'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const CircleAvatar(
                  backgroundColor: AppPalette.accent,
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: const Text(
                  S.writeOnModaHouse,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(S.writeOnModaHouseHint),
                trailing: Icon(Icons.chevron_right_rounded, color: p.muted),
                onTap: () {
                  Navigator.of(ctx).pop();
                  openChatWith(
                    context,
                    shop.username,
                    draft: message,
                    pin: pin,
                  );
                },
              ),
              for (final l in links)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: (l.color ?? p.text).withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(l.icon, color: l.color ?? p.text, size: 22),
                  ),
                  title: Text(
                    l.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(l.value),
                  trailing: Icon(
                    l.uri == null
                        ? Icons.copy_rounded
                        : Icons.open_in_new_rounded,
                    size: 18,
                    color: p.muted,
                  ),
                  onTap: () {
                    // Copy-only links confirm with a snackbar: close first.
                    if (l.uri == null) Navigator.of(ctx).pop();
                    openContact(l);
                  },
                ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Clipboard.setData(ClipboardData(text: message));
                    showSnack(S.messageCopied);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(S.copyMessage),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

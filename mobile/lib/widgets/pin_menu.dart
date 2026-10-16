import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../core/download/download.dart';
import '../core/format.dart';
import '../core/share_links.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import 'app_image.dart';
import 'save_sheet.dart';
import 'share_sheet.dart';
import 'states.dart';

/// Shares a post's title and link through the system share sheet (falls back
/// to copying the link). "Başga…" in the share sheet.
Future<void> sharePin(Pin pin) async {
  final link = AppConfig.pinLink(pin.id);
  try {
    final res = await SharePlus.instance.share(
      ShareParams(text: pinShareText(pin), subject: pin.title),
    );
    if (res.status == ShareResultStatus.unavailable) {
      throw Exception('unavailable');
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: link));
    showSnack(S.linkCopied);
  }
}

/// Downloads media item [index] of the post from `/pins/:id/download`, so
/// images carry the ModaHouse watermark, and saves it (gallery on Android,
/// a file download on the web).
Future<void> downloadPin(WidgetRef ref, Pin pin, {int index = 0}) async {
  final i = pin.gallery.isEmpty ? 0 : index.clamp(0, pin.gallery.length - 1);
  final load = ref.read(mediaLoaderProvider);
  showSnack(S.downloadStarted);
  try {
    final file = await load(AppConfig.pinDownloadUrl(pin.id, index: i));
    await saveFile(
      file.bytes,
      pinDownloadFileName(pin.id, i, file.mimeType),
      file.mimeType,
    );
    showSnack(S.downloaded);
  } catch (_) {
    showSnack(S.genericError, error: true);
  }
}

/// Hides a post from my feeds, with "Yzyna al" (undo) in the snackbar.
Future<void> hidePin(WidgetRef ref, Pin pin) async {
  final repo = ref.read(pinsRepositoryProvider);
  final updates = ref.read(pinUpdatesProvider.notifier);
  updates.hidden(pin.id);
  try {
    await repo.hide(pin.id);
    showSnack(
      S.hiddenDone,
      actionLabel: S.undo,
      onAction: () async {
        updates.unhidden(pin.id);
        try {
          await repo.unhide(pin.id);
        } catch (e) {
          showError(e);
        }
      },
    );
  } catch (e) {
    updates.unhidden(pin.id);
    showError(e);
  }
}

/// Opens the "⋯" bottom sheet for [pin]. [onEdit] / [onDelete] are used for
/// the owner's actions (defaults: open the edit screen / delete with confirm).
/// [index] is the carousel item on screen ("Ýükle" downloads that one).
Future<void> showPinMenu(
  BuildContext context,
  WidgetRef ref,
  Pin pin, {
  int index = 0,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) async {
  final me = ref.read(authProvider).user;
  final isOwner = me != null && me.id == pin.author.id;
  final router = GoRouter.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => _PinMenuSheet(pin: pin, isOwner: isOwner),
  );
  if (action == null || !context.mounted) return;
  bool requireLogin() {
    if (ref.read(authProvider).isLoggedIn) return true;
    router.push('/login?from=${Uri.encodeComponent('/pin/${pin.id}')}');
    return false;
  }

  switch (action) {
    case 'save':
      await showSaveSheet(context, ref, pin);
    case 'share':
      await showShareSheet(context, pin);
    case 'download':
      await downloadPin(ref, pin, index: index);
    case 'copy':
      await Clipboard.setData(ClipboardData(text: AppConfig.pinLink(pin.id)));
      showSnack(S.linkCopied);
    case 'similar':
      await router.push('/visual/pin/${pin.id}');
    case 'hide':
      if (requireLogin()) await hidePin(ref, pin);
    case 'report':
      if (requireLogin() && context.mounted) {
        await showReportSheet(context, ref, pin);
      }
    case 'edit':
      if (onEdit != null) {
        onEdit();
      } else {
        final updated = await router.push<Pin>('/pin/${pin.id}/edit');
        if (updated != null) {
          ref.read(pinUpdatesProvider.notifier).updated(updated);
        }
      }
    case 'delete':
      if (onDelete != null) {
        onDelete();
      } else if (context.mounted) {
        final ok = await confirmDialog(
          context,
          title: S.deletePinTitle,
          text: S.deletePinText,
        );
        if (!ok) return;
        try {
          await ref.read(pinsRepositoryProvider).delete(pin.id);
          ref.read(pinUpdatesProvider.notifier).deleted(pin.id);
          ref.read(boardsVersionProvider.notifier).bump();
          showSnack(S.pinDeleted);
        } catch (e) {
          showError(e);
        }
      }
  }
}

class _PinMenuSheet extends StatelessWidget {
  const _PinMenuSheet({required this.pin, required this.isOwner});

  final Pin pin;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget item(String value, IconData icon, String label, {Color? color}) =>
        ListTile(
          leading: Icon(icon, color: color ?? p.text),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? p.text,
            ),
          ),
          visualDensity: VisualDensity.compact,
          onTap: () => Navigator.of(context).pop(value),
        );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 56,
                    child: AppImage(
                      pin.imageUrl,
                      cacheWidth: 44,
                      placeholder: parseHexColor(pin.color, p.surface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pin.title.isEmpty ? S.postOptions : pin.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          item('save', Icons.push_pin_outlined, S.menuSave),
          item('share', Icons.ios_share_rounded, S.menuShare),
          item('download', Icons.download_rounded, S.menuDownload),
          item('copy', Icons.link_rounded, S.menuCopyLink),
          item('similar', Icons.image_search_rounded, S.menuSimilar),
          if (isOwner) ...[
            item('edit', Icons.edit_outlined, S.edit),
            item(
              'delete',
              Icons.delete_outline_rounded,
              S.delete,
              color: AppPalette.danger,
            ),
          ] else ...[
            item('hide', Icons.visibility_off_outlined, S.menuHide),
            item(
              'report',
              Icons.flag_outlined,
              S.menuReport,
              color: AppPalette.danger,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Reason picker for "Şikaýat et".
Future<void> showReportSheet(BuildContext context, WidgetRef ref, Pin pin) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(pin: pin),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.pin});

  final Pin pin;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  static const reasons = {
    'spam': S.reportSpam,
    'inappropriate': S.reportInappropriate,
    'copyright': S.reportCopyright,
    'fake': S.reportFake,
    'other': S.reportOther,
  };
  String? _reason;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final r = _reason;
    if (r == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(pinsRepositoryProvider)
          .report(widget.pin.id, r, note: _note.text.trim());
      showSnack(S.reportSent);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      showError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              S.reportTitle,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final e in reasons.entries)
                  RadioListTile<String>(
                    value: e.key,
                    title: Text(e.value),
                    activeColor: AppPalette.accent,
                    dense: true,
                  ),
              ],
            ),
          ),
          if (_reason != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _note,
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: S.reportNote),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _reason == null || _busy ? null : _send,
              child: _busy
                  ? const Spinner(size: 18, color: Colors.white)
                  : const Text(S.menuReport),
            ),
          ),
        ],
      ),
    );
  }
}

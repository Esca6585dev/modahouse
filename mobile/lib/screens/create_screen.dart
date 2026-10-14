import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../core/video_meta/video_meta.dart';
import '../data/common.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/board_form.dart';
import '../widgets/pin_fields.dart';
import '../widgets/product_form.dart';
import '../widgets/ai_sheet.dart';
import '../widgets/states.dart';
import '../widgets/video_view.dart';

/// Picks an image from the gallery or camera. Returns null when cancelled.
Future<PickedImage?> pickImage(
  ImageSource source, {
  double maxSize = 2048,
}) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: maxSize,
      maxHeight: maxSize,
      imageQuality: 90,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : 'surat.jpg';
    return PickedImage(bytes: bytes, name: name);
  } catch (e) {
    showSnack(S.genericError, error: true);
    return null;
  }
}

/// Longest video accepted for posts and stories (seconds).
const maxVideoSeconds = 60;

/// Reads a picked file; videos also get their length and a poster.
Future<PickedImage?> readPicked(XFile f) async {
  final bytes = await f.readAsBytes();
  var img = PickedImage(
    bytes: bytes,
    name: f.name.isNotEmpty ? f.name : 'surat.jpg',
    mimeType: f.mimeType,
    path: f.path,
  );
  if (img.isVideo) {
    final meta = await readVideoMeta(f.path);
    if (meta?.duration != null && meta!.duration! > maxVideoSeconds + 1) {
      showSnack(S.videoTooLong, error: true);
      return null;
    }
    img = img.copyWith(
      duration: meta?.duration,
      poster: meta?.poster == null
          ? null
          : PickedImage(bytes: meta!.poster!, name: 'poster.jpg'),
    );
  }
  return img;
}

/// Picks up to [limit] photos and videos from the gallery.
Future<List<PickedImage>> pickImages({
  int limit = 8,
  bool videos = true,
}) async {
  if (limit <= 0) return const [];
  try {
    final picker = ImagePicker();
    final files = videos
        ? await picker.pickMultipleMedia(
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 90,
            limit: limit > 1 ? limit : null,
          )
        : await picker.pickMultiImage(
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 90,
            limit: limit > 1 ? limit : null,
          );
    final out = <PickedImage>[];
    for (final f in files.take(limit)) {
      final img = await readPicked(f);
      if (img != null) out.add(img);
    }
    return out;
  } catch (e) {
    showSnack(S.genericError, error: true);
    return const [];
  }
}

/// Picks one video from the gallery (or records one with [camera]).
Future<PickedImage?> pickVideo({bool camera = false}) async {
  try {
    final f = await ImagePicker().pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(seconds: maxVideoSeconds),
    );
    if (f == null) return null;
    return await readPicked(f);
  } catch (e) {
    showSnack(S.genericError, error: true);
    return null;
  }
}

const maxPinImages = 10;

class CreateScreen extends ConsumerWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((s) => s.user));
    return Scaffold(
      appBar: AppBar(
        title: Text(me?.isBusiness ?? false ? S.addProduct : S.createPin),
        actions: [
          if (me != null)
            TextButton.icon(
              onPressed: () => context.push('/story/new'),
              icon: const Icon(Icons.auto_stories_outlined, size: 20),
              label: const Text(S.addStory),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: me != null
          ? _CreateForm(key: ValueKey('create-${me.id}-${me.isBusiness}'))
          : const LoginPrompt(
              text: S.loginPromptCreate,
              from: '/create',
              icon: Icons.add_photo_alternate_outlined,
            ),
    );
  }
}

class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm({super.key});

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  final _formKey = GlobalKey<FormState>();
  final _fields = PinFieldControllers();
  late final Me _me = ref.read(authProvider).user!;
  late final _product = ProductFormControllers(
    deliveryDays: _me.business?.deliveryDays,
    returnDays: _me.business?.returnDays,
  );
  late ListingType _type = _me.isBusiness ? ListingType.sale : ListingType.post;

  bool get _isProduct => _type != ListingType.post;
  final List<PickedImage> _images = [];
  int? _boardId;
  List<Board>? _boards;
  bool _busy = false;
  double? _progress;
  String? _formError;
  bool _imageMissing = false;

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  @override
  void dispose() {
    _fields.dispose();
    _product.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    try {
      final boards = await ref.read(boardsRepositoryProvider).mine();
      if (!mounted) return;
      setState(() {
        _boards = boards;
        if (!boards.any((b) => b.id == _boardId)) _boardId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _boards = const []);
    }
  }

  void _addImages(List<PickedImage> imgs) {
    if (imgs.isEmpty || !mounted) return;
    final room = maxPinImages - _images.length;
    if (imgs.length > room) showSnack(S.maxImages, error: true);
    setState(() {
      _images.addAll(imgs.take(room));
      _imageMissing = false;
    });
  }

  /// [source]: `gallery` (photos and videos), `camera` or `video`.
  Future<void> _pick(String source) async {
    if (_images.length >= maxPinImages) {
      showSnack(S.maxImages, error: true);
      return;
    }
    if (source == 'gallery') {
      _addImages(await pickImages(limit: maxPinImages - _images.length));
    } else if (source == 'video') {
      final v = await pickVideo();
      if (v != null) _addImages([v]);
    } else {
      final img = await pickImage(ImageSource.camera);
      if (img != null) _addImages([img]);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final formOk = _formKey.currentState!.validate();
    setState(() => _imageMissing = _images.isEmpty);
    if (!formOk || _images.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _formError = null;
    });
    try {
      final pin = await ref
          .read(pinsRepositoryProvider)
          .create(
            images: List.of(_images),
            title: _fields.title.text.trim(),
            category: _fields.category!,
            description: _fields.description.text.trim(),
            link: _fields.link.text.trim(),
            tags: splitTags(_fields.tags.text).join(','),
            boardId: _boardId,
            product: _isProduct ? _product.toInput(_type) : null,
            listingType: _me.isBusiness && !_isProduct
                ? ListingType.post
                : null,
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      ref.read(pinUpdatesProvider.notifier).created(pin);
      if (_boardId != null) ref.read(boardsVersionProvider.notifier).bump();
      showSnack(_isProduct ? S.productCreated : S.pinCreated);
      if (!mounted) return;
      setState(() {
        _images.clear();
        _fields.clear();
        _product.clear();
        _boardId = null;
      });
      _formKey.currentState?.reset();
      setState(() {
        _busy = false;
        _progress = null;
      });
      // Not awaited: the form must be usable again when the user comes back.
      unawaited(context.push('/pin/${pin.id}'));
    } catch (e) {
      if (mounted) setState(() => _formError = errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _openAi() async {
    final first = _images.isEmpty ? null : _images.first;
    final image = first == null ? null : (first.isVideo ? first.poster : first);
    final s = await showAiSuggestSheet(
      context,
      listingType: _type,
      category: _fields.category ?? '',
      title: _fields.title.text.trim(),
      image: image,
    );
    if (s == null || !mounted) return;
    final cats = ref.read(categoriesProvider).value ?? const <Category>[];
    setState(() {
      if (s.title.isNotEmpty && !s.title.contains('…')) {
        _fields.title.text = s.title;
      }
      _fields.description.text = s.fullDescription;
      if (s.hashtags.isNotEmpty) _fields.tags.text = s.hashtags.join(', ');
      if (cats.any((c) => c.slug == s.category)) {
        _fields.category = s.category;
      }
    });
    showSnack(S.aiInserted);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(boardsVersionProvider, (_, _) => _loadBoards());
    final p = AppPalette.of(context);
    final boards = _boards ?? const <Board>[];
    final progress = _progress;
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          4,
          AppPalette.gutter,
          32,
        ),
        children: [
          if (_me.isBusiness) ...[
            ListingTypeSelector(
              value: _type,
              enabled: !_busy,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 16),
          ],
          _ImagesArea(
            images: _images,
            missing: _imageMissing,
            enabled: !_busy,
            onPick: _pick,
            onRemove: (i) => setState(() => _images.removeAt(i)),
            onReorder: (from, to) => setState(() {
              final img = _images.removeAt(from);
              _images.insert(to, img);
            }),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('ai-write'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.accent,
                side: BorderSide(
                  color: AppPalette.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              onPressed: _busy ? null : _openAi,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(S.aiWrite),
            ),
          ),
          const SizedBox(height: 16),
          PinFields(
            controllers: _fields,
            enabled: !_busy,
            onCategoryChanged: (v) => setState(() => _fields.category = v),
          ),
          if (_isProduct) ...[
            const SizedBox(height: 12),
            Divider(color: p.border),
            section(switch (_type) {
              ListingType.rent => S.rentInfo,
              ListingType.custom => S.customInfo,
              _ => S.productInfo,
            }),
            ProductFields(
              key: ValueKey('fields-${_type.value}'),
              controllers: _product,
              enabled: !_busy,
              type: _type,
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            key: ValueKey('board-${boards.length}-$_boardId'),
            initialValue: _boardId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            decoration: const InputDecoration(labelText: S.board),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text(S.noBoard)),
              for (final b in boards)
                DropdownMenuItem<int?>(
                  value: b.id,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                      if (b.isPrivate) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded, size: 15, color: p.muted),
                      ],
                    ],
                  ),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _boardId = v),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            FormErrorBox(message: _formError!),
          ],
          const SizedBox(height: 24),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Text(
              S.uploading((progress * 100).round()),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: const Key('create-submit'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? S.publishing : S.publish),
          ),
        ],
      ),
    );
  }
}

/// Up to 8 images: reorderable thumbnails (the first is the cover), remove
/// buttons and an "add" tile.
class _ImagesArea extends StatelessWidget {
  const _ImagesArea({
    required this.images,
    required this.missing,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
    required this.onReorder,
  });

  final List<PickedImage> images;
  final bool missing;
  final bool enabled;
  final ValueChanged<String> onPick;
  final ValueChanged<int> onRemove;

  /// [to] is the final index (already adjusted for the removed item).
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (images.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: missing ? AppPalette.danger : p.border,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 44, color: p.muted),
            const SizedBox(height: 10),
            const Text(
              S.pickImage,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              S.mediaHelp,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: missing ? AppPalette.danger : p.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? () => onPick('gallery') : null,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text(S.gallery),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: p.bg),
                  onPressed: enabled ? () => onPick('camera') : null,
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const Text(S.camera),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: p.bg),
                  onPressed: enabled ? () => onPick('video') : null,
                  icon: const Icon(Icons.videocam_outlined, size: 20),
                  label: const Text(S.addVideo),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${S.media} (${images.length}/$maxPinImages)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(S.mediaHelp, style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            itemCount: images.length,
            onReorderItem: enabled ? onReorder : (_, _) {},
            footer: images.length < maxPinImages
                ? Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _AddTile(enabled: enabled, onPick: onPick),
                  )
                : null,
            itemBuilder: (context, i) => Padding(
              key: ValueKey(images[i]),
              padding: const EdgeInsets.only(right: 8),
              child: ReorderableDelayedDragStartListener(
                index: i,
                enabled: enabled,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 116,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Thumb(media: images[i]),
                        if (i == 0)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                S.coverLabel,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            left: 4,
                            bottom: 4,
                            child: _SmallButton(
                              icon: Icons.star_outline_rounded,
                              tooltip: S.makeCover,
                              onTap: enabled ? () => onReorder(i, 0) : null,
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _SmallButton(
                            icon: Icons.close_rounded,
                            tooltip: S.removeImage,
                            onTap: enabled ? () => onRemove(i) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.enabled, required this.onPick});

  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      width: 116,
      child: Column(
        children: [
          Expanded(
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled ? () => onPick('gallery') : null,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: p.muted),
                      const SizedBox(height: 4),
                      Text(
                        S.addImages,
                        style: TextStyle(
                          color: p.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: Row(
              children: [
                for (final (src, icon, tip) in [
                  ('camera', Icons.photo_camera_outlined, S.camera),
                  ('video', Icons.videocam_outlined, S.addVideo),
                ]) ...[
                  if (src == 'video') const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: tip,
                      child: Material(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: enabled ? () => onPick(src) : null,
                          child: Icon(icon, size: 18, color: p.muted),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail of a picked photo, or a video's poster with a ▶.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.media});

  final PickedImage media;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final still = media.isVideo ? media.poster : media;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (still != null)
          Image.memory(
            still.bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: p.surface,
              child: Icon(Icons.broken_image_outlined, color: p.muted),
            ),
          )
        else
          const ColoredBox(color: Color(0xFF222222)),
        if (media.isVideo)
          Center(child: VideoBadge(duration: media.duration ?? 0)),
      ],
    );
  }
}

/// "Postuň maksady": Diňe paýlaşmak / Satlyk / Kärende / Sargyt bilen tikmek.
class ListingTypeSelector extends StatelessWidget {
  const ListingTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final ListingType value;
  final ValueChanged<ListingType> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const items = [
      (ListingType.post, Icons.photo_outlined, S.typePost, S.typePostHint),
      (ListingType.sale, Icons.sell_outlined, S.typeSale, S.typeSaleHint),
      (
        ListingType.rent,
        Icons.event_available_outlined,
        S.typeRent,
        S.typeRentHint,
      ),
      (
        ListingType.custom,
        Icons.content_cut_rounded,
        S.typeCustom,
        S.typeCustomHint,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          S.listingType,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: [
            for (final (type, icon, label, hint) in items)
              Semantics(
                button: true,
                selected: type == value,
                label: label,
                excludeSemantics: true,
                onTap: enabled ? () => onChanged(type) : null,
                child: Material(
                  color: type == value
                      ? AppPalette.accent.withValues(alpha: 0.08)
                      : p.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: type == value ? AppPalette.accent : p.border,
                      width: type == value ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: enabled ? () => onChanged(type) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 22,
                            color: type == value ? AppPalette.accent : p.text,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: type == value
                                        ? AppPalette.accent
                                        : p.text,
                                  ),
                                ),
                                Text(
                                  hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

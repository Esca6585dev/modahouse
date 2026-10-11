import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../data/common.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/board_form.dart';
import '../widgets/pin_fields.dart';
import '../widgets/product_form.dart';
import '../widgets/states.dart';

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

/// Picks up to [limit] images from the gallery.
Future<List<PickedImage>> pickImages({int limit = 8}) async {
  if (limit <= 0) return const [];
  try {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
      limit: limit > 1 ? limit : null,
    );
    final out = <PickedImage>[];
    for (final f in files.take(limit)) {
      out.add(
        PickedImage(
          bytes: await f.readAsBytes(),
          name: f.name.isNotEmpty ? f.name : 'surat.jpg',
        ),
      );
    }
    return out;
  } catch (e) {
    showSnack(S.genericError, error: true);
    return const [];
  }
}

const maxPinImages = 8;

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
  late bool _isProduct = _me.isBusiness;
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

  Future<void> _pick(ImageSource source) async {
    if (_images.length >= maxPinImages) {
      showSnack(S.maxImages, error: true);
      return;
    }
    if (source == ImageSource.gallery) {
      _addImages(await pickImages(limit: maxPinImages - _images.length));
    } else {
      final img = await pickImage(source);
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
            product: _isProduct ? _product.toInput() : null,
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
      await context.push('/pin/${pin.id}');
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
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: p.text,
                selectedForegroundColor: p.bg,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.sell_outlined, size: 18),
                  label: Text(S.modeProduct),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.push_pin_outlined, size: 18),
                  label: Text(S.modePin),
                ),
              ],
              selected: {_isProduct},
              onSelectionChanged: _busy
                  ? null
                  : (v) => setState(() => _isProduct = v.first),
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
          const SizedBox(height: 24),
          PinFields(
            controllers: _fields,
            enabled: !_busy,
            onCategoryChanged: (v) => setState(() => _fields.category = v),
          ),
          if (_isProduct) ...[
            const SizedBox(height: 12),
            Divider(color: p.border),
            section(S.productInfo),
            ProductFields(controllers: _product, enabled: !_busy),
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
  final ValueChanged<ImageSource> onPick;
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
              '${S.imagesHelp}\n${S.pickImageHelp}',
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
                  onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text(S.gallery),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: p.bg),
                  onPressed: enabled ? () => onPick(ImageSource.camera) : null,
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const Text(S.camera),
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
              '${S.images} (${images.length}/$maxPinImages)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(S.imagesHelp, style: TextStyle(color: p.muted, fontSize: 12.5)),
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
                        Image.memory(
                          images[i].bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: p.surface,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: p.muted,
                            ),
                          ),
                        ),
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
  final ValueChanged<ImageSource> onPick;

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
                onTap: enabled ? () => onPick(ImageSource.gallery) : null,
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
            width: double.infinity,
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: enabled ? () => onPick(ImageSource.camera) : null,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: p.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

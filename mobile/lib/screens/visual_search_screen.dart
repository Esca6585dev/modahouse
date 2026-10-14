import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/common.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/crop_box.dart';
import '../widgets/pin_card.dart';
import '../widgets/states.dart';
import 'create_screen.dart' show pickImage;

/// Asks camera or gallery, then opens the photo search with the picked photo.
Future<void> startPhotoSearch(BuildContext context) async {
  final router = GoRouter.of(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              S.photoSearch,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text(S.camera),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text(S.gallery),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return;
  final img = await pickImage(source, maxSize: 1600);
  if (img == null) return;
  await router.push('/visual', extra: img);
}

/// Camera icon used in search bars.
class PhotoSearchButton extends StatelessWidget {
  const PhotoSearchButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('photo-search'),
    tooltip: S.photoSearch,
    onPressed: () => startPhotoSearch(context),
    icon: Icon(Icons.photo_camera_outlined, color: color),
  );
}

/// `/visual`: the photo with an adjustable frame and similar posts below.
class PhotoSearchScreen extends ConsumerStatefulWidget {
  const PhotoSearchScreen({super.key, this.image});

  final PickedImage? image;

  @override
  ConsumerState<PhotoSearchScreen> createState() => _PhotoSearchScreenState();
}

class _PhotoSearchScreenState extends ConsumerState<PhotoSearchScreen> {
  PickedImage? _image;
  Size? _size;
  CropFrame _frame = const CropFrame.centered();
  bool _productsOnly = false;
  VisualResult? _result;
  Object? _error;
  bool _loading = false;
  Timer? _debounce;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
    if (_image != null) _prepare();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final img = _image!;
    try {
      final decoded = await _decodeSize(img);
      if (!mounted) return;
      setState(() {
        _size = decoded;
        _frame = const CropFrame.centered();
      });
    } catch (_) {
      if (mounted) setState(() => _size = const Size(1, 1));
    }
    await _search();
  }

  static Future<Size> _decodeSize(PickedImage img) async {
    final codec = await ui.instantiateImageCodec(img.bytes);
    final frame = await codec.getNextFrame();
    final s = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    codec.dispose();
    return s;
  }

  Future<void> _search() async {
    final img = _image;
    if (img == null) return;
    _cancel?.cancel();
    final token = CancelToken();
    _cancel = token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(pinsRepositoryProvider)
          .searchImage(
            img,
            crop: _frame.record,
            productsOnly: _productsOnly,
            cancelToken: token,
          );
      if (!mounted || token.isCancelled) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted || token.isCancelled) return;
      setState(() => _error = e);
    } finally {
      if (mounted && _cancel == token) setState(() => _loading = false);
    }
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _changePhoto() async {
    final img = await pickImage(ImageSource.gallery, maxSize: 1600);
    if (img == null || !mounted) return;
    setState(() {
      _image = img;
      _size = null;
      _result = null;
    });
    await _prepare();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final size = _size;
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.photoSearch),
        actions: [
          if (img != null)
            TextButton.icon(
              onPressed: _changePhoto,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text(S.changePhoto),
            ),
        ],
      ),
      body: img == null
          ? EmptyView(
              icon: Icons.image_search_rounded,
              title: S.photoSearch,
              text: S.photoSearchHint,
              action: FilledButton.icon(
                onPressed: () => startPhotoSearch(context),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text(S.photoSearchHint),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFF111111),
                    height: (screen.height * 0.42).clamp(240.0, 420.0),
                    padding: const EdgeInsets.all(12),
                    child: size == null
                        ? const Center(child: Spinner(color: Colors.white))
                        : CropBox(
                            imageSize: size,
                            frame: _frame,
                            image: Image.memory(img.bytes, fit: BoxFit.fill),
                            onChanged: (f) => setState(() => _frame = f),
                            onChangeEnd: (_) => _scheduleSearch(),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
                    child: Text(
                      S.cropHint,
                      style: TextStyle(
                        color: AppPalette.of(context).muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                ..._resultsHeaderAndGrid(),
              ],
            ),
    );
  }

  List<Widget> _resultsHeaderAndGrid() => visualResultSlivers(
    context: context,
    result: _result,
    loading: _loading,
    error: _error,
    productsOnly: _productsOnly,
    onProductsOnly: (v) {
      setState(() => _productsOnly = v);
      _search();
    },
    onRetry: _search,
  );
}

/// `/visual/pin/:id`: "Meňzeşini tap" for an existing post.
class SimilarByPhotoScreen extends ConsumerStatefulWidget {
  const SimilarByPhotoScreen({super.key, required this.pinId});

  final int pinId;

  @override
  ConsumerState<SimilarByPhotoScreen> createState() =>
      _SimilarByPhotoScreenState();
}

class _SimilarByPhotoScreenState extends ConsumerState<SimilarByPhotoScreen> {
  Pin? _pin;
  VisualResult? _result;
  Object? _error;
  bool _loading = false;
  bool _productsOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(pinsRepositoryProvider);
      final pin = _pin ?? await repo.get(widget.pinId);
      final res = await repo.visual(widget.pinId, productsOnly: _productsOnly);
      if (mounted) {
        setState(() {
          _pin = pin;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S.menuSimilar)),
      body: CustomScrollView(
        slivers: [
          if (pin != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 72,
                        height: 90,
                        child: AppImage(
                          pin.imageUrl,
                          cacheWidth: 72,
                          placeholder: parseHexColor(pin.color, p.surface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pin.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...visualResultSlivers(
            context: context,
            result: _result,
            loading: _loading,
            error: _error,
            productsOnly: _productsOnly,
            onProductsOnly: (v) {
              setState(() => _productsOnly = v);
              _load();
            },
            onRetry: _load,
          ),
        ],
      ),
    );
  }
}

/// Header ("Meňzeş postlar", AI category, "Diňe harytlar") and the results.
List<Widget> visualResultSlivers({
  required BuildContext context,
  required VisualResult? result,
  required bool loading,
  required Object? error,
  required bool productsOnly,
  required ValueChanged<bool> onProductsOnly,
  required VoidCallback onRetry,
}) {
  final p = AppPalette.of(context);
  final items = result?.items ?? const <Pin>[];
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Text(
              S.similarResults,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (result != null && result.category.isNotEmpty) ...[
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, _) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    S.aiCategory(
                      categoryName(
                        result.category,
                        ref.watch(categoriesProvider).value,
                      ),
                    ),
                    style: const TextStyle(
                      color: AppPalette.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Spinner(size: 16),
              ),
            Text(S.onlyProducts, style: TextStyle(color: p.text, fontSize: 13)),
            Switch(
              key: const Key('only-products'),
              value: productsOnly,
              onChanged: onProductsOnly,
            ),
          ],
        ),
      ),
    ),
    if (error != null && items.isEmpty)
      SliverToBoxAdapter(
        child: ErrorView(error: error, onRetry: onRetry),
      )
    else if (result == null)
      const SliverToBoxAdapter(child: LoadingView())
    else if (items.isEmpty)
      const SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.image_search_rounded,
          title: S.noSimilarResults,
          compact: true,
        ),
      )
    else
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          0,
          AppPalette.gutter,
          24,
        ),
        sliver: SliverMasonryGrid.extent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 16,
          crossAxisSpacing: 10,
          childCount: items.length,
          itemBuilder: (context, i) {
            final pin = items[i];
            final score = (result.scoreAt(i) * 100).round();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PinCard(
                  key: ValueKey('v-${pin.id}'),
                  pin: pin,
                  onTap: () => context.push('/pin/${pin.id}'),
                  onAuthorTap: () => context.push(
                    '/user/${Uri.encodeComponent(pin.author.username)}',
                  ),
                ),
                if (score > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text(
                      S.matchPercent(score),
                      style: TextStyle(color: p.muted, fontSize: 11.5),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
  ];
}

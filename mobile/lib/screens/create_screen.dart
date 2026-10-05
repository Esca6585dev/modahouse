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
import '../widgets/states.dart';

/// Picks an image from the gallery or camera. Returns null when cancelled.
Future<PickedImage?> pickImage(ImageSource source, {double maxSize = 2048}) async {
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

class CreateScreen extends ConsumerWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    return Scaffold(
      appBar: AppBar(title: const Text(S.createPin)),
      body: loggedIn
          ? const _CreateForm()
          : const LoginPrompt(text: S.loginPromptCreate, from: '/create', icon: Icons.add_photo_alternate_outlined),
    );
  }
}

class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm();

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  final _formKey = GlobalKey<FormState>();
  final _fields = PinFieldControllers();
  PickedImage? _image;
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

  Future<void> _pick(ImageSource source) async {
    final img = await pickImage(source);
    if (img != null && mounted) {
      setState(() {
        _image = img;
        _imageMissing = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final formOk = _formKey.currentState!.validate();
    setState(() => _imageMissing = _image == null);
    if (!formOk || _image == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _formError = null;
    });
    try {
      final pin = await ref.read(pinsRepositoryProvider).create(
            image: _image!,
            title: _fields.title.text.trim(),
            category: _fields.category!,
            description: _fields.description.text.trim(),
            link: _fields.link.text.trim(),
            tags: splitTags(_fields.tags.text).join(','),
            boardId: _boardId,
            onProgress: (sent, total) {
              if (mounted && total > 0) setState(() => _progress = sent / total);
            },
          );
      ref.read(pinUpdatesProvider.notifier).created(pin);
      if (_boardId != null) ref.read(boardsVersionProvider.notifier).bump();
      showSnack(S.pinCreated);
      if (!mounted) return;
      setState(() {
        _image = null;
        _fields.clear();
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

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppPalette.gutter, 4, AppPalette.gutter, 32),
        children: [
          _ImageArea(
            image: _image,
            missing: _imageMissing,
            enabled: !_busy,
            onPick: _pick,
            onClear: () => setState(() => _image = null),
          ),
          const SizedBox(height: 24),
          PinFields(
            controllers: _fields,
            enabled: !_busy,
            onCategoryChanged: (v) => setState(() => _fields.category = v),
          ),
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
                      Flexible(child: Text(b.name, overflow: TextOverflow.ellipsis)),
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
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? S.publishing : S.publish),
          ),
        ],
      ),
    );
  }
}

class _ImageArea extends StatelessWidget {
  const _ImageArea({
    required this.image,
    required this.missing,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final PickedImage? image;
  final bool missing;
  final bool enabled;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final img = image;
    if (img != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460, minHeight: 160),
              child: ColoredBox(
                color: p.surface,
                child: Center(
                  child: Image.memory(
                    img.bytes,
                    fit: BoxFit.contain,
                    semanticLabel: img.name,
                    errorBuilder: (_, _, _) => SizedBox(
                      height: 200,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: p.muted, size: 40)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: S.removeImage,
                onPressed: enabled ? onClear : null,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: missing ? AppPalette.danger : p.border, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 44, color: p.muted),
          const SizedBox(height: 10),
          const Text(S.pickImage, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text(S.pickImageHelp, style: TextStyle(color: missing ? AppPalette.danger : p.muted, fontSize: 13)),
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
}

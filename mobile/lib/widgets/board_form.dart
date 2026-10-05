import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';

/// Create a board (when [board] is null) or edit an existing one.
/// Returns the saved board, or null when cancelled.
Future<Board?> showBoardForm(BuildContext context, {Board? board}) => showModalBottomSheet<Board>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BoardForm(board: board),
    );

class BoardForm extends ConsumerStatefulWidget {
  const BoardForm({super.key, this.board});

  final Board? board;

  @override
  ConsumerState<BoardForm> createState() => _BoardFormState();
}

class _BoardFormState extends ConsumerState<BoardForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.board?.name ?? '');
  late final _description = TextEditingController(text: widget.board?.description ?? '');
  late bool _private = widget.board?.isPrivate ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(boardsRepositoryProvider);
    try {
      final b = widget.board;
      final saved = b == null
          ? await repo.create(
              name: _name.text.trim(),
              description: _description.text.trim(),
              isPrivate: _private,
            )
          : await repo.update(
              b.id,
              name: _name.text.trim(),
              description: _description.text.trim(),
              isPrivate: _private,
            );
      ref.read(boardsVersionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final editing = widget.board != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? S.editBoard : S.newBoard,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                autofocus: !editing,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: S.newBoardName, hintText: S.boardNameHint),
                validator: (v) => (v ?? '').trim().isEmpty ? S.boardNameRequired : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                enabled: !_busy,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(labelText: S.description, hintText: S.boardDescriptionHint),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _private,
                onChanged: _busy ? null : (v) => setState(() => _private = v),
                title: const Text(S.privateBoardLabel, style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(S.privateBoardHelp, style: TextStyle(color: p.muted)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FormErrorBox(message: _error!),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text(S.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? S.saving : (editing ? S.save : S.create)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red rounded box with a server/validation message (".form-error").
class FormErrorBox extends StatelessWidget {
  const FormErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppPalette.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: const TextStyle(color: AppPalette.danger, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../core/server_config.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/server.dart';
import '../widgets/board_form.dart';

String serverSourceLabel(ServerSource s) => switch (s) {
  ServerSource.manual => S.serverSourceManual,
  ServerSource.remote => S.serverSourceRemote,
  ServerSource.build => S.serverSourceBuild,
};

/// `/server` (Sazlamalar → Serwer, also linked from the login screen):
/// the current API address, its source, and a way to change it by hand.
class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen({super.key});

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen> {
  final _address = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  ServerNotifier get _server => ref.read(serverProvider.notifier);

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final error = await _server.setManual(_address.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _address.clear();
    showSnack(S.serverSaved);
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    await _server.resetToDefault();
    if (mounted) showSnack(S.serverResetDone);
  }

  Future<void> _recheck() async {
    setState(() => _error = null);
    final r = await _server.refresh();
    if (!mounted) return;
    switch (r) {
      case RefreshResult.switched:
        showSnack('${S.serverSwitchedTo}: ${ref.read(serverProvider).apiUrl}');
      case RefreshResult.unchanged:
        showSnack(S.serverUpToDate);
      case RefreshResult.unreachable:
        setState(() => _error = S.serverOffline);
      case RefreshResult.skipped:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(serverProvider);
    final busy = s.busy;
    final p = AppPalette.of(context);
    final status = switch (s.reachable) {
      true => S.serverStatusOk,
      false => S.serverStatusDown,
      null => S.serverStatusUnknown,
    };

    Widget row(String label, String value, {Key? key, bool strong = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                key: key,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  fontSize: strong ? 17 : 15,
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text(S.server)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          8,
          AppPalette.gutter,
          32,
        ),
        children: [
          Text(S.serverIntro, style: TextStyle(color: p.muted)),
          const SizedBox(height: 16),
          _Box(
            children: [
              row(
                S.serverCurrent,
                s.apiUrl,
                key: const Key('server-current'),
                strong: true,
              ),
              row(
                S.serverSource,
                serverSourceLabel(s.source),
                key: const Key('server-source'),
              ),
              row(S.serverStatus, status),
              row(S.serverWebAddress, s.webUrl),
              row(S.serverDefault, AppConfig.defaultApiUrl),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('server-recheck'),
                  onPressed: busy ? null : _recheck,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text(S.serverRecheck),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Box(
            children: [
              TextField(
                key: const Key('server-field'),
                controller: _address,
                enabled: !busy,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => busy ? null : _save(),
                decoration: const InputDecoration(
                  labelText: S.serverNewAddress,
                  hintText: S.serverAddressHint,
                  helperText: S.serverAddressHelp,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                FormErrorBox(message: _error!),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const Key('server-save'),
                    onPressed: busy ? null : _save,
                    child: Text(busy ? S.serverChecking : S.serverCheckSave),
                  ),
                  ElevatedButton(
                    key: const Key('server-reset'),
                    onPressed: busy ? null : _reset,
                    child: const Text(S.serverResetDefault),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

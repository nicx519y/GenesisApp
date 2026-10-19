import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../platform/session/user_session_store.dart';
import '../../app/debug/rating_prompt_debug_settings.dart';
import '../../app/review/rating_prompt_store.dart';
import '../../ui/genesis_ui.dart';
import 'pending_rating_reward_host.dart';
import 'worldo_rating_dialog.dart';

/// Hide the entire developer rating section until a login identity is confirmed.
class RatingPromptDebugSection extends StatefulWidget {
  const RatingPromptDebugSection({super.key, this.spacing = 12});
  final double spacing;

  @override
  State<RatingPromptDebugSection> createState() =>
      _RatingPromptDebugSectionState();
}

class _RatingPromptDebugSectionState extends State<RatingPromptDebugSection> {
  AppServices? _services;
  Listenable? _changes;
  Future<String?>? _loginUid;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    if (identical(_services, services)) return;
    _changes?.removeListener(_reload);
    _services = services;
    _changes = Listenable.merge([
      services.sessionRevision,
      services.sessionStore.userInfoRevision,
    ])..addListener(_reload);
    _loginUid = services.sessionStore.readLoginUid();
    _generation++;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _loginUid = _services!.sessionStore.readLoginUid();
      _generation++;
    });
  }

  @override
  void dispose() {
    _changes?.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    key: ValueKey(_generation),
    future: _loginUid,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          snapshot.data == null) {
        return const SizedBox.shrink();
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GenesisPrimaryButton(
            key: const ValueKey('developer-rate-button'),
            label: 'Rate Dialog',
            onPressed: () => showWorldoRatingDialog(context),
            backgroundColor: GenesisColors.darkFaintFill,
            foregroundColor: GenesisColors.darkTextPrimary,
          ),
          SizedBox(height: widget.spacing),
          const RatingPromptDebugControl(),
          SizedBox(height: widget.spacing),
        ],
      );
    },
  );
}

/// Developer controls intentionally use fixed English, like Rate Dialog.
class RatingPromptDebugControl extends StatefulWidget {
  const RatingPromptDebugControl({super.key});
  @override
  State<RatingPromptDebugControl> createState() =>
      _RatingPromptDebugControlState();
}

class _RatingPromptDebugControlState extends State<RatingPromptDebugControl> {
  final _controller = TextEditingController();
  bool _busy = true;
  int? _override;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await RatingPromptDebugSettings.read();
      if (!mounted) return;
      _controller.text = value?.toString() ?? '';
      setState(() => _override = value);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load local setting.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool clear = false}) async {
    if (_busy) return;
    final value = clear ? null : int.tryParse(_controller.text.trim());
    if (!clear && (value == null || value < 0)) {
      setState(() => _error = 'Enter a non-negative whole number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await RatingPromptDebugSettings.save(value);
      if (!mounted) return;
      if (clear) _controller.clear();
      setState(() => _override = value);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save local setting.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPrompt() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final services = AppServicesScope.read(context);
      final revision = services.sessionRevision.value;
      final owner = await PendingRatingReward.owner(context);
      if (!mounted || services.sessionRevision.value != revision) return;
      await RatingPromptStore.instance.reset(owner);
      if (!mounted || services.sessionRevision.value != revision) return;
      setState(
        () => _status = 'Reset. Send messages to reach the threshold again.',
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to reset rating prompt.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppServicesScope.read(context).appGlobalConfig,
    builder: (context, config, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rating message threshold',
          style: TextStyle(color: GenesisColors.darkTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Server: ${config.ratingPromptMessageCount} · Local: ${_override ?? "unset"} · Effective: ${_override ?? config.ratingPromptMessageCount}',
          style: const TextStyle(
            color: GenesisColors.darkTextSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('developer-rating-threshold-input'),
          controller: _controller,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: GenesisColors.darkTextPrimary,
            fontSize: 14,
            height: 1.4,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: GenesisColors.darkFaintFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            hintStyle: const TextStyle(
              color: GenesisColors.darkInputPlaceholder,
            ),
            hintText: 'Message count (0 disables)',
            errorText: _error,
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GenesisPrimaryButton(
                label: 'Apply',
                onPressed: _busy ? null : () => _save(),
                backgroundColor: GenesisColors.darkFaintFill,
                disabledBackgroundColor: GenesisColors.darkFaintFill,
                disabledForegroundColor: GenesisColors.darkTextTertiary,
                foregroundColor: GenesisColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GenesisPrimaryButton(
                label: 'Use server',
                onPressed: _busy ? null : () => _save(clear: true),
                backgroundColor: GenesisColors.darkFaintFill,
                disabledBackgroundColor: GenesisColors.darkFaintFill,
                disabledForegroundColor: GenesisColors.darkTextTertiary,
                foregroundColor: GenesisColors.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GenesisPrimaryButton(
          key: const ValueKey('developer-reset-rating-prompt'),
          label: 'Reset rating prompt',
          onPressed: _busy ? null : _resetPrompt,
          backgroundColor: GenesisColors.darkFaintFill,
          disabledBackgroundColor: GenesisColors.darkFaintFill,
          disabledForegroundColor: GenesisColors.darkTextTertiary,
          foregroundColor: GenesisColors.darkTextPrimary,
        ),
        if (_status case final status?) ...[
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              color: GenesisColors.darkTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    ),
  );
}

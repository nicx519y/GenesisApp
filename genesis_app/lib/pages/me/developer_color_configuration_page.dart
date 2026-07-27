import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import '../../components/common/genesis_center_toast.dart';
import '../../ui/genesis_ui.dart';

class DeveloperColorConfigurationPage extends StatefulWidget {
  const DeveloperColorConfigurationPage({super.key});

  @override
  State<DeveloperColorConfigurationPage> createState() =>
      _DeveloperColorConfigurationPageState();
}

class _DeveloperColorConfigurationPageState
    extends State<DeveloperColorConfigurationPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = GenesisColorScope.of(context);
    final brightness = controller.activeBrightness;
    final safeTheme = GenesisTheme.light();

    return Theme(
      data: safeTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Color configuration'),
          actions: [
            IconButton(
              key: const ValueKey<String>('developer-colors-reset-all'),
              tooltip: 'Reset all colors',
              onPressed: () => _confirmResetAll(controller),
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ModeSwitch(controller: controller, brightness: brightness),
              _ContrastPreview(
                config: controller.configFor(brightness),
                brightness: brightness,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  key: const ValueKey<String>('developer-colors-search-field'),
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search token, name or usage',
                    border: OutlineInputBorder(),
                    isCollapsed: false,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey<String>('developer-colors-token-list'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    for (final group in GenesisColorGroup.values)
                      _buildGroup(controller, brightness, group),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'developer-colors-reset-palette',
                      ),
                      onPressed: () =>
                          _confirmResetPalette(controller, brightness),
                      icon: const Icon(Icons.restore),
                      label: Text(
                        'Reset ${_brightnessLabel(brightness)} palette',
                      ),
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

  Widget _buildGroup(
    GenesisColorController controller,
    Brightness brightness,
    GenesisColorGroup group,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();
    final tokens = GenesisColorToken.values
        .where((token) {
          if (token.group != group) return false;
          if (normalizedQuery.isEmpty) return true;
          return token.id.toLowerCase().contains(normalizedQuery) ||
              token.label.toLowerCase().contains(normalizedQuery) ||
              token.description.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    if (tokens.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        initiallyExpanded:
            normalizedQuery.isNotEmpty ||
            group == GenesisColorGroup.surface ||
            group == GenesisColorGroup.textIcon,
        title: Text('${group.label} (${tokens.length})'),
        children: [
          for (final token in tokens)
            _ColorTokenTile(
              token: token,
              color: controller.colorFor(brightness, token),
              defaultColor: controller.defaultColorFor(brightness, token),
              overridden: controller.isOverridden(brightness, token),
              onTap: () => _pickColor(controller, brightness, token),
              onReset: () => _runPersistentAction(
                () => controller.resetToken(brightness, token),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickColor(
    GenesisColorController controller,
    Brightness brightness,
    GenesisColorToken token,
  ) async {
    final current = controller.colorFor(brightness, token);
    final selected = await showColorPickerDialog(
      context,
      current,
      title: Text(token.label),
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.wheel: true,
      },
      enableOpacity: true,
      showColorCode: true,
      colorCodeHasColor: true,
      barrierDismissible: false,
    );
    if (!mounted || selected == current) return;
    await _runPersistentAction(
      () => controller.setColor(brightness, token, selected),
    );
  }

  Future<void> _confirmResetPalette(
    GenesisColorController controller,
    Brightness brightness,
  ) async {
    final confirmed = await _confirm(
      title: 'Reset ${_brightnessLabel(brightness)} palette?',
      content: 'All overrides in this palette will be removed.',
    );
    if (confirmed != true || !mounted) return;
    await _runPersistentAction(() => controller.resetPalette(brightness));
  }

  Future<void> _confirmResetAll(GenesisColorController controller) async {
    final confirmed = await _confirm(
      title: 'Reset all color configuration?',
      content:
          'Light and Dark overrides will be removed and mode returns to Light.',
    );
    if (confirmed != true || !mounted) return;
    await _runPersistentAction(controller.resetAll);
  }

  Future<bool?> _confirm({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _runPersistentAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showGenesisToast(context, 'Color applied, but save failed: $error');
      }
    }
  }

  static String _brightnessLabel(Brightness brightness) =>
      brightness == Brightness.dark ? 'Dark' : 'Light';
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.controller, required this.brightness});

  final GenesisColorController controller;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const ValueKey<String>('developer-colors-dark-mode-switch'),
      title: const Text('Dark mode'),
      subtitle: Text(
        brightness == Brightness.dark
            ? 'Editing and previewing Dark colors'
            : 'Editing and previewing Light colors',
      ),
      value: brightness == Brightness.dark,
      onChanged: (enabled) async {
        try {
          await controller.setMode(
            enabled ? Brightness.dark : Brightness.light,
          );
        } catch (error) {
          if (context.mounted) {
            showGenesisToast(context, 'Mode changed, but save failed: $error');
          }
        }
      },
    );
  }
}

class _ColorTokenTile extends StatelessWidget {
  const _ColorTokenTile({
    required this.token,
    required this.color,
    required this.defaultColor,
    required this.overridden,
    required this.onTap,
    required this.onReset,
  });

  final GenesisColorToken token;
  final Color color;
  final Color defaultColor;
  final bool overridden;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey<String>('developer-color-token-${token.id}'),
      onTap: onTap,
      leading: _ColorSwatch(color: color),
      title: Text(token.label),
      subtitle: Text(
        '${token.id}\n${_hex(color)} · default ${_hex(defaultColor)}\n${token.description}',
      ),
      isThreeLine: true,
      trailing: overridden
          ? IconButton(
              tooltip: 'Reset token',
              onPressed: onReset,
              icon: const Icon(Icons.undo),
            )
          : null,
    );
  }

  static String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox.square(dimension: 42, child: ColoredBox(color: color)),
      ),
    );
  }
}

class _ContrastPreview extends StatelessWidget {
  const _ContrastPreview({required this.config, required this.brightness});

  final GenesisSemanticColorConfig config;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final pairs = <(String, Color, Color)>[
      (
        'Primary / surface',
        config.color(GenesisColorToken.textPrimary),
        config.color(GenesisColorToken.surface),
      ),
      (
        'Secondary / surface',
        config.color(GenesisColorToken.textSecondary),
        config.color(GenesisColorToken.surface),
      ),
      (
        'Inverse / brand',
        config.color(GenesisColorToken.textInverse),
        config.color(GenesisColorToken.brand),
      ),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: pairs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pair = pairs[index];
          final ratio = _contrast(pair.$2, pair.$3);
          return Chip(
            backgroundColor: pair.$3,
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
            label: Text(
              '${pair.$1} ${ratio.toStringAsFixed(1)}:1${ratio < 4.5 ? ' !' : ''}',
              style: TextStyle(color: pair.$2),
            ),
          );
        },
      ),
    );
  }

  static double _contrast(Color foreground, Color background) {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

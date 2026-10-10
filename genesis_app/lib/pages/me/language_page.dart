import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/page_header.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../l10n/app_language_controller.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/genesis_ui.dart';
import '../../ui/theme/genesis_dark_theme.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});
  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool _saving = false;
  Future<void> _select(Locale locale) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await appLanguageController.select(locale);
    } catch (_) {
      if (mounted) {
        showGenesisToast(
          context,
          context.l10n.languageChangeFailed,
          brightness: Brightness.dark,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context);
    return GenesisDarkTheme(
      child: GenesisBottomSystemBarStyleScope(
        style: const GenesisBottomSystemBarStyle(
          color: GenesisColors.darkBackground,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: kGenesisLightSystemUiOverlayStyle,
          child: Scaffold(
            backgroundColor: GenesisColors.darkBackground,
            appBar: GenesisBackAppBar(
              backgroundColor: GenesisColors.darkBackground,
              foregroundColor: GenesisColors.darkTextPrimary,
              systemOverlayStyle: kGenesisLightSystemUiOverlayStyle,
              pageName: context.l10n.settingsLanguage,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    for (final entry in const [
                      (Locale('zh', 'TW'), '繁體中文'),
                      (Locale('en'), 'English'),
                    ]) ...[
                      Semantics(
                        selected: current == entry.$1,
                        button: true,
                        child: InkWell(
                          onTap: _saving ? null : () => _select(entry.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.$2,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: GenesisColors.darkTextPrimary,
                                    ),
                                  ),
                                ),
                                if (current == entry.$1)
                                  Icon(
                                    Icons.check,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(
                        height: 1,
                        color: GenesisColors.darkFaintFill,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

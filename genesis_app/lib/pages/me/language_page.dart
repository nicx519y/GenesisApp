import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/page_header.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../l10n/app_language_controller.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../network/api_exception.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/genesis_ui.dart';
import '../../ui/theme/genesis_dark_theme.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key, this.saveLanguage});
  final Future<void> Function(String language)? saveLanguage;
  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool _saving = false;
  Locale? _localeBeforeSave;
  Locale? _successLocale;
  int _successSequence = 0;
  Future<void> _select(Locale locale) async {
    if (_saving ||
        appLanguageController.settingLanguage ==
            AppLanguageController.codeForLocale(locale) ||
        (appLanguageController.settingLanguage == null &&
            Localizations.localeOf(context) == locale)) {
      return;
    }
    setState(() {
      _localeBeforeSave = Localizations.localeOf(context);
      _saving = true;
    });
    try {
      final saveLanguage =
          widget.saveLanguage ??
          (String language) async {
            final services = AppServicesScope.read(context);
            final deviceId = await services.deviceId.getDeviceId();
            await services.api.v1.device.setLanguage(
              deviceId: deviceId,
              language: language,
            );
          };
      await appLanguageController.select(locale, saveLanguage: saveLanguage);
      if (mounted) {
        setState(() {
          _successLocale = locale;
          _successSequence++;
        });
      }
    } catch (error) {
      if (mounted) {
        showGenesisToast(
          context,
          error is ApiException &&
                  error.kind == ApiExceptionKind.business &&
                  error.message.trim().isNotEmpty
              ? error.message
              : context.l10n.languageChangeFailed,
          brightness: Brightness.dark,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _localeBeforeSave = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _saving
        ? _localeBeforeSave!
        : Localizations.localeOf(context);
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
                child: ListView(
                  children: [
                    const SizedBox(height: 18),
                    for (final entry in const [
                      (Locale('en'), 'English'),
                      (Locale('de'), 'Deutsch'),
                      (Locale('fr'), 'Français'),
                      (Locale('ja'), '日本語'),
                      (Locale('zh', 'TW'), '繁體中文'),
                      (Locale('es'), 'Español'),
                      (Locale('pt'), 'Português'),
                      (Locale('it'), 'Italiano'),
                      (Locale('ko'), '한국어'),
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
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: entry.$2),
                                        TextSpan(
                                          text:
                                              ' (${AppLanguageController.codeForLocale(entry.$1).toUpperCase()})',
                                          style: const TextStyle(
                                            color:
                                                GenesisColors.darkTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: GenesisColors.darkTextPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Center(
                                    child: current == entry.$1
                                        ? TweenAnimationBuilder<double>(
                                            key: ValueKey(
                                              'language-check-${entry.$1}-$_successSequence',
                                            ),
                                            tween: Tween(
                                              begin: _successLocale == entry.$1
                                                  ? 0.5
                                                  : 1,
                                              end: 1,
                                            ),
                                            duration:
                                                MediaQuery.disableAnimationsOf(
                                                  context,
                                                )
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 300,
                                                  ),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, scale, child) =>
                                                Transform.scale(
                                                  key: const ValueKey(
                                                    'language-check-scale',
                                                  ),
                                                  scale: scale,
                                                  child: child,
                                                ),
                                            child: Icon(
                                              Icons.check,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              size: 24,
                                            ),
                                          )
                                        : null,
                                  ),
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

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'genesis_l10n.dart';

extension GenesisLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      GenesisL10n.current;
}

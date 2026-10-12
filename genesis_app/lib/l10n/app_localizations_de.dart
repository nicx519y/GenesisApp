// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get imageGifUnsupported => 'GIF-Animationen werden nicht unterstützt.';

  @override
  String get worldProgressComplete => 'Fortschritt abgeschlossen';

  @override
  String a11ySwitchMode({required String label}) {
    return 'Zum Modus $label wechseln';
  }

  @override
  String a11yEditItem({required String title}) {
    return '$title bearbeiten';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return 'Rollenkarte $index von $count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'Inspiration $index bearbeiten';
  }

  @override
  String a11yInsert({required String label}) {
    return '$label einfügen';
  }

  @override
  String get a11yMembership => 'Mitgliedschaft';

  @override
  String get a11yOpenWorldo => 'Worldo öffnen';

  @override
  String get a11yFilterGender => 'Nach Geschlecht filtern';

  @override
  String get a11ySelectRole => 'Wähle deine Rolle';

  @override
  String get a11yLoadingMap => 'Karte wird geladen';

  @override
  String get a11yBuildingWorld => 'Welt wird erstellt';

  @override
  String get a11yPremiumMembership => 'Premium-Mitgliedschaft';

  @override
  String get a11yProMembership => 'Pro-Mitgliedschaft';

  @override
  String get a11yRecommendedRole => 'Empfohlene Rolle';

  @override
  String get a11yLastMessage => 'Letzte Nachricht';

  @override
  String get a11yRecentChat => 'Letzter Chat';

  @override
  String get a11yAiReplyLoading => 'AI-Antwort wird geladen';

  @override
  String statMessages({required num count, required String amount}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Messages',
      one: 'Message',
      zero: 'Message',
    );
    return '$amount $_temp0';
  }

  @override
  String statPlayers({required num count, required String amount}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spieler',
      one: 'Spieler',
      zero: 'Spieler',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (Hinzugefügt / Maximum)';
  }

  @override
  String get createSixHours => '6 Stunden';

  @override
  String get createTwelveHours => '12 Stunden';

  @override
  String get createOneDay => '1 Tag';

  @override
  String get createOneWeek => '1 Woche';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageChangeFailed =>
      'Sprache konnte nicht geändert werden. Bitte versuche es erneut.';

  @override
  String get purchasingGems => 'Gems werden gekauft';

  @override
  String get purchaseSuccessful => 'Kauf erfolgreich!';

  @override
  String get okAction => 'OK';

  @override
  String get cancelAction => 'Abbrechen';

  @override
  String get requestAction => 'Anfragen';

  @override
  String get requestedStatus => 'Angefragt';

  @override
  String get launchAction => 'Starten';

  @override
  String get tickNowAction => 'Jetzt Tick';

  @override
  String get writePostHint => 'Beitrag schreiben';

  @override
  String get newPostTitle => 'Neuer Beitrag';

  @override
  String get aiIsGenerating => 'AI generiert Inhalte';

  @override
  String get generatingCustomizedWorldWait =>
      'Eine lebendige, persönliche Welt wird für dich erstellt.\nBitte warte einen Moment.';

  @override
  String get approvedStatus => 'Genehmigt';

  @override
  String get rejectedStatus => 'Abgelehnt';

  @override
  String get awaitingApprovalStatus => 'Genehmigung ausstehend';

  @override
  String get awaitingYourApprovalStatus => 'Wartet auf deine Genehmigung';

  @override
  String get liveYourWorld => 'LEBE DEINE WELT';

  @override
  String get signedOutMeDescription =>
      'Spiele in Welten, erstelle worldo, lade Freunde ein\nund setze deine Abenteuer überall fort.';

  @override
  String get gemTaskLaunchWorldHint =>
      'Öffne ein Worldo, das dir gefällt, und starte dann deine eigene Welt.';

  @override
  String get gemTaskInviteFriendHint =>
      'Öffne eine Welt und tippe im Detailbereich auf Einladen.';

  @override
  String get gemTaskWriteCommentHint =>
      'Öffne ein Worldo, das dir gefällt, und schreibe unter Diskussion einen Beitrag.';

  @override
  String get gemTaskRequestJoinHint =>
      'Öffne eine Welt, der du noch nicht beigetreten bist, und frage den Beitritt an.';

  @override
  String get gemTaskSendMessageHint => 'Sende Nachrichten in deiner Welt.';

  @override
  String get gemTaskProgressWorldHint =>
      'Öffne eine Welt, in der du spielst, und tippe auf Jetzt Tick.';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'Welt';

  @override
  String get userLabel => 'Nutzer';

  @override
  String get meLabel => 'Ich';

  @override
  String get locationLabel => 'Ort';

  @override
  String get allLabel => 'Alle';

  @override
  String get maleLabel => 'Männlich';

  @override
  String get femaleLabel => 'Weiblich';

  @override
  String get nonBinaryLabel => 'Nichtbinär';

  @override
  String get forYouLabel => 'Für dich';

  @override
  String get userBlocked => 'Nutzer blockiert';

  @override
  String get purchaseCanceled => 'Kauf abgebrochen.';

  @override
  String get purchasePending => 'Dein Kauf ist ausstehend.';

  @override
  String get purchaseConfirmationDelayed =>
      'Die Kaufbestätigung verzögert sich. Bitte prüfe später erneut.';

  @override
  String get purchaseFailed => 'Kauf fehlgeschlagen.';

  @override
  String get yearlyPlan => 'Jährlich';

  @override
  String get monthlyPlan => 'Monatlich';

  @override
  String get proSubscriptionTagline =>
      'Tauche tiefer in jedes Worldo ein, in dem du spielst.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, jährlich abgerechnet';
  }

  @override
  String expiresOn({required String date}) {
    return 'Läuft am $date ab';
  }

  @override
  String get activeStatus => 'AKTIV';

  @override
  String get expiredStatus => 'Abgelaufen';

  @override
  String updatedAt({required String timestamp}) {
    return 'Aktualisiert $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => 'Laden fehlgeschlagen. Erneut versuchen';

  @override
  String get loadMoreAction => 'Mehr laden';

  @override
  String get gemPurchaseRecord => 'Gem-Kauf';

  @override
  String get taskRewardRecord => 'Aufgabenbelohnung';

  @override
  String get worldProgressRecord => 'Weltfortschritt';

  @override
  String get directMessageRecord => 'Direktnachricht';

  @override
  String get gemRecord => 'Gem-Buchung';

  @override
  String get runATickTask => 'Einen Tick ausführen';

  @override
  String get runATickTaskDescription =>
      'Öffne eine Welt, in der du spielst, und tippe auf Jetzt Tick.';

  @override
  String get someoneFallback => 'Jemand';

  @override
  String get aCharacterFallback => 'ein Charakter';

  @override
  String get thisWorld => 'diese Welt';

  @override
  String get noWorldEventsYet => 'Noch keine Weltereignisse.';

  @override
  String get globalLabel => 'Global';

  @override
  String get eventLabel => 'Ereignis';

  @override
  String get characterDestinations => 'Ziele der Charaktere';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName $direction $locationName';
  }

  @override
  String get cameToDirection => 'kam nach';

  @override
  String get wentToDirection => 'ging nach';

  @override
  String get hasComeToDirection => 'ist angekommen in';

  @override
  String get hasGoneToDirection => 'ist gegangen nach';

  @override
  String get waitForReplyToSendMore =>
      'Warte auf eine Antwort, bevor du weitere Nachrichten sendest';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Nachrichten',
      one: '$count neue Nachricht',
      zero: '$count neue Nachrichten',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation => 'Bitte wähle eine vorgegebene Rolle';

  @override
  String get enterNameValidation => 'Bitte gib einen Namen ein';

  @override
  String get enterIdentityValidation => 'Bitte gib eine Identität ein';

  @override
  String get waitForProfileLoading =>
      'Bitte warte, bis das Profil geladen ist.';

  @override
  String get imageUploadFailed => 'Bild-Upload fehlgeschlagen.';

  @override
  String get photoAccessDenied => 'Zugriff auf Fotos verweigert';

  @override
  String get feedbackSubmitted => 'Feedback gesendet';

  @override
  String get feedbackFailed => 'Feedback konnte nicht gesendet werden';

  @override
  String get worldoDetailUnavailable => 'Worldo-Details sind nicht verfügbar.';

  @override
  String get publishAction => 'Veröffentlichen';

  @override
  String get publishingStatus => 'Wird veröffentlicht...';

  @override
  String get publishFailed => 'Veröffentlichung fehlgeschlagen';

  @override
  String get publishChangesBeforeLeaving =>
      'Änderungen vor dem Verlassen veröffentlichen?';

  @override
  String get noChangesToPublish => 'Keine Änderungen zu veröffentlichen.';

  @override
  String get completeOpeningRequiredToPublish =>
      'Zum Veröffentlichen ist ein vollständiger Einstieg erforderlich';

  @override
  String get publishResponseMissingOriginId =>
      'Die Veröffentlichung hat keine Worldo-ID zurückgegeben.';

  @override
  String get worldoIdRequired => 'Eine Worldo-ID ist erforderlich.';

  @override
  String loadFailedWithReason({required String reason}) {
    return 'Laden fehlgeschlagen: $reason';
  }

  @override
  String get imageSelectionFailed => 'Bildauswahl fehlgeschlagen';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID: $oid\nNeueste Version: $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID: $wid\nBesitzer: $owner';
  }

  @override
  String get sendFailed => 'Senden fehlgeschlagen';

  @override
  String get selectARole => 'Rolle auswählen';

  @override
  String get timeLabel => 'Zeit';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID: $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID: $oid · Ersteller: $creator';
  }

  @override
  String get worldoMetricExplanation =>
      'Dieses worldo aktualisiert bei jedem Fortschritt den {Kennzahlname} jedes Charakters, angegeben in {Einheit}. Jeder Charakter beginnt bei {Startwert}, und der Wert kann sich innerhalb von {Min. Änderung}–{Max. Änderung} verändern.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return 'Starte ein $worldo, um\ndeine eigene Welt zu erstellen';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return 'Geschätzte Kosten der nächsten Nachricht: $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount Gems';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'Welt $worldName löschen';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername spielt als $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName gestartet!';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName erstellt!';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName veröffentlicht!';
  }

  @override
  String get createTimeout => 'Zeitüberschreitung beim Erstellen des Worldos.';

  @override
  String get publishTimeout =>
      'Zeitüberschreitung beim Veröffentlichen des Worldos';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return 'Du hast den Beitritt zu $worldName$worldId angefragt';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge möchte $worldName$worldId beitreten';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge hat dein worldo kommentiert';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge hat dir geantwortet';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge gefällt dein Kommentar';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge hat dir eine Nachricht gesendet';
  }

  @override
  String notificationGenericContent({
    required String senderName,
    required String senderBadge,
    required String content,
  }) {
    return '$senderName$senderBadge $content';
  }

  @override
  String freeInspirationUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Verbleibende kostenlose Inspirationen: $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Verbleibende kostenlose Bearbeitungen: $remaining\n$action';
  }

  @override
  String get getMoreAction => 'Mehr erhalten >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName kam nach $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Mit Worldo kannst du AI-gestützte Welten voller Charaktere, Geschichten und sich entwickelnder Ereignisse erstellen, entdecken und betreten. Chatte mit AI-Charakteren, spiele mit Freunden und entwickle jede Welt durch lebendige Szenen und Entscheidungen weiter.\n\nUnsere App bietet eine neue Art, interaktive Geschichten zu erleben: als Teil der Welt. Bei Fragen kontaktiere uns bitte unter $contactEmail.';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy, $termsOfUse und $endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return 'Indem du fortfährst, stimmst du unseren $terms, unserer $privacyPolicy und unserer $endUserLicenseAgreement zu';
  }

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get terms => 'Bedingungen';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String get endUserLicenseAgreement => 'Endnutzer-Lizenzvereinbarung';

  @override
  String existingAccountSignIn({required String signIn}) {
    return 'Ich habe ein Konto und möchte $signIn';
  }

  @override
  String get signInAction => 'mich anmelden.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return '$gemIcon$grantedAmount Gems wurden gutgeschrieben.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return 'Bis zu $amount Gems monatlich und vollständiger Premium-Zugang.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /Tag';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/Monat';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: Antwort an $replyToName$replyToBadge: $content';
  }

  @override
  String discussReplyLineDirect({
    required String authorName,
    required String authorBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: $content';
  }

  @override
  String get navHome => 'Startseite';

  @override
  String get navWorldo => 'Worldo';

  @override
  String get navCreate => 'Erstellen';

  @override
  String get navInbox => 'Posteingang';

  @override
  String get navMe => 'Profil';

  @override
  String get homeLoadFailed => 'Laden fehlgeschlagen';

  @override
  String get homeRetry => 'Erneut versuchen';

  @override
  String get homeEmptyDescription =>
      'Worldo ist die Vorlage. Starte es, um eine lebendige Welt zu erstellen, die du betreten und weiterentwickeln kannst.';

  @override
  String get homeWorldCharacter => 'Charakter';

  @override
  String get homeWorldSingleOtherPlayer => '· 1 weiterer Spieler';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· $otherPlayerCount weitere Spieler';
  }

  @override
  String get homeSignInUnavailable => 'Anmeldung nicht verfügbar';

  @override
  String get homeSignedOutTitle => 'Alle deine Welten an einem Ort';

  @override
  String get homeSignedOutDescription =>
      'Melde dich an, um Welten zu erstellen und deine Geschichten fortzusetzen.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return 'Besitzer: $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID: $oid  Ersteller: $originator\nKurzbeschreibung: $brief\nNeueste Version: $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID: $wid\nBesitzer: $owner';
  }

  @override
  String get searchHistory => 'Suchverlauf';

  @override
  String get searchFailed => 'Suche fehlgeschlagen';

  @override
  String get searchNoResults => 'Keine Ergebnisse.';

  @override
  String get searchCancel => 'Abbrechen';

  @override
  String get searchHint => 'Worldo, Charakter, Tags';

  @override
  String get worldDetailOnlyWorldsLaunched =>
      'Nur Welten, die du allein gestartet hast, können gelöscht werden.';

  @override
  String get worldDetailDelete => 'Löschen';

  @override
  String get worldDetailNoCharacterStatusYet => 'Noch kein Charakterstatus.';

  @override
  String get worldDetailNoCharactersYet => 'Noch keine Charaktere.';

  @override
  String get worldDetailProgressingWorld => 'Welt schreitet fort';

  @override
  String get worldDetailCompressingRecent =>
      'Aktuelle Erinnerungen werden komprimiert\nWeltzeit wird vorangetrieben\nNächster Handlungsschritt wird generiert\nCharakterorte werden aktualisiert';

  @override
  String get worldModelsDetail => 'Details';

  @override
  String get worldModelsLocations => 'Orte';

  @override
  String get worldModelsEvents => 'Ereignisse';

  @override
  String get worldModelsStatus => 'Status';

  @override
  String get worldDetailUnavailable => 'Nicht verfügbar';

  @override
  String worldActionFailed({required String actionLabel}) {
    return '$actionLabel fehlgeschlagen';
  }

  @override
  String get worldDetailRequestJoinWorld => 'Beitritt zu dieser Welt anfragen?';

  @override
  String get worldDetailRequest => 'Anfragen';

  @override
  String get worldDetailLaunchFailed => 'Start fehlgeschlagen';

  @override
  String get worldDetailNoSavedProfileFound =>
      'Kein gespeichertes Profil gefunden';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return 'Quell-Worldo: $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => 'Einladen';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Tritt meiner Welt „$worldName“ auf Worldo bei!\n$wid\nSuche diese WID auf Worldo, um die Welt zu finden und beizutreten.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'Weltbeschreibung';

  @override
  String get worldDetailCast => 'Besetzung';

  @override
  String get worldDetailLinkCopiedShare =>
      'Link kopiert. Teile ihn mit deinen Freunden.';

  @override
  String get worldMapAction => 'Karte';

  @override
  String get worldInfoAction => 'Info';

  @override
  String worldLocationCount({required String pointsCount}) {
    return 'Orte ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => 'Spieler';

  @override
  String worldDetailGoal({required String goal}) {
    return 'Ziel: $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet => 'Noch keine Charakterdetails.';

  @override
  String get worldDetailNoEventsYet => 'Noch keine Ereignisse.';

  @override
  String get worldDetailLoadEventsFailed =>
      'Ereignisse konnten nicht geladen werden.';

  @override
  String homeLocationID({required String id}) {
    return 'Ort $id';
  }

  @override
  String get homeBuildingWorld => 'WELT WIRD ERSTELLT';

  @override
  String get worldMapLoadFailed => 'Karte konnte nicht geladen werden';

  @override
  String get worldMapZoomIn => 'Karte vergrößern';

  @override
  String get worldMapZoomOut => 'Karte verkleinern';

  @override
  String get worldDetailGlobal => 'Global';

  @override
  String get worldDetailLocation => 'Ort';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => 'Erster Tick wird generiert';

  @override
  String get worldFirstTickStatusLoadFailed =>
      'Generierungsstatus konnte nicht geladen werden.';

  @override
  String get worldDetailNew => 'Neu';

  @override
  String get homeUnknownLocation => 'Unbekannter Ort';

  @override
  String get homeUnknownCharacter => 'Unbekannter Charakter';

  @override
  String get homeNewPlaceEmerged => 'Ein neuer Ort ist entstanden';

  @override
  String get homeNewCharacterAppeared => 'Ein neuer Charakter ist erschienen';

  @override
  String get chatLocationUnavailable => 'Ort ist nicht verfügbar';

  @override
  String get chatRequestApprovalLaunch => 'Genehmigung zum Starten anfragen';

  @override
  String get chatLoading => 'Wird geladen';

  @override
  String get chatQuotaCheckFailed =>
      'Kostenlose Nutzungen konnten nicht geprüft werden. Bitte versuche es erneut.';

  @override
  String get chatInspirationSourceChanged =>
      'Die Inspirationsquelle hat sich geändert. Bitte öffne Inspiration erneut.';

  @override
  String get chatInspiration => 'Inspiration';

  @override
  String get chatMessageCannotSend =>
      'Diese Nachricht kann nicht mehr gesendet werden';

  @override
  String get chatMessageEmpty => 'Die Nachricht ist leer';

  @override
  String get chatConnectionFailed => 'Verbindung zu diesem Chat fehlgeschlagen';

  @override
  String get chatReplyChangedSelect =>
      'Die Antwort hat sich geändert. Bitte wähle Inspiration erneut.';

  @override
  String get chatSendConfirmFailed =>
      'Nachrichtenversand konnte nicht bestätigt werden';

  @override
  String get chatNoNetworkConnection => 'Keine Netzwerkverbindung';

  @override
  String get chatRoundCannotContinue =>
      'Diese Runde kann nicht fortgesetzt werden';

  @override
  String get chatSourceRoundChanged =>
      'Die ursprüngliche Runde hat sich geändert';

  @override
  String get chatGo => 'Fortsetzen';

  @override
  String get chatReplyActionUnavailable =>
      'Diese Antwortaktion ist nicht mehr verfügbar';

  @override
  String get chatRegenerateFailure => 'Neugenerierung fehlgeschlagen';

  @override
  String get chatGoFailure => 'Fortsetzen fehlgeschlagen';

  @override
  String get chatEditFailure => 'Bearbeitung fehlgeschlagen';

  @override
  String get chatInspirationFailure => 'Inspiration fehlgeschlagen';

  @override
  String get chatJoinLocationFailed => 'Beitritt zu diesem Ort fehlgeschlagen';

  @override
  String get chatInactive => 'Dieser Chat ist nicht mehr aktiv';

  @override
  String get chatChatroomUnavailable => 'Chatraum ist nicht verfügbar';

  @override
  String get chatFailedConfirmReplyAction =>
      'Antwortaktion konnte nicht bestätigt werden';

  @override
  String get chatLeastOneMessageMustRemain =>
      'Mindestens eine Nachricht muss erhalten bleiben.';

  @override
  String get chatReplyNotEditable =>
      'Diese Antwort kann nicht bearbeitet werden';

  @override
  String get chatReplyAlreadyFixed => 'Diese Antwort wurde festgelegt';

  @override
  String get chatReplyEditorFrozen => 'Antworteditor ist gesperrt';

  @override
  String get chatResolvePreviousSaveBefore =>
      'Schließe den vorherigen Speichervorgang ab, bevor du seinen Entwurf änderst';

  @override
  String get chatStaleReplyEditor => 'Antworteditor ist veraltet';

  @override
  String get chatPreviousSaveResultUncertain =>
      'Das vorherige Speicherergebnis ist unklar. Lade neu, bevor du erneut bearbeitest';

  @override
  String get chatCandidateMissing => 'Der Vorschlag existiert nicht mehr';

  @override
  String get chatBatchSupportsMost100Changes =>
      'Ein Stapel unterstützt höchstens 100 Änderungen';

  @override
  String get chatMissingStableMessageIdentity =>
      'Stabile Nachrichtenkennung fehlt';

  @override
  String get chatEditTargetHasChanged =>
      'Das Bearbeitungsziel hat sich geändert';

  @override
  String get chatMessageNotEditable =>
      'Diese Nachricht kann nicht bearbeitet werden';

  @override
  String get chatReplyNoLongerEditable =>
      'Diese Antwort kann nicht mehr bearbeitet werden';

  @override
  String get chatEditorOpenFailed => 'Editor konnte nicht geöffnet werden';

  @override
  String get chatInactiveDuringEdit => 'Dieser Chat ist nicht mehr aktiv.';

  @override
  String get chatEditMessage => 'Nachricht bearbeiten';

  @override
  String get chatSave => 'Speichern';

  @override
  String get chatEdit => 'Bearbeiten';

  @override
  String get chatRegenerate => 'Neu generieren';

  @override
  String get chatRegenerateUnavailable =>
      'Diese Runde kann nicht neu generiert werden';

  @override
  String get chatGenerate10Replies =>
      'Du kannst bis zu 10 Antworten generieren.';

  @override
  String get chatPreviousReply => 'Vorherige Antwort';

  @override
  String get chatNextReply => 'Nächste Antwort';

  @override
  String get chatCopy => 'Kopieren';

  @override
  String get chatReport => 'Melden';

  @override
  String get chatCopied => 'Kopiert';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Nachrichten',
      one: '$count neue Nachricht',
      zero: '$count neue Nachrichten',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'Erwähnen';

  @override
  String get chatCharacters => 'Charaktere';

  @override
  String get chatNoCharacters => 'Keine Charaktere';

  @override
  String get chatNoLocations => 'Keine Orte';

  @override
  String get chatHere => 'Hier';

  @override
  String get chatLoadEarlierMessages => 'Ältere Nachrichten laden';

  @override
  String get chatText => 'Nachricht schreiben...';

  @override
  String get chatLocationRoster => 'DU';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'Alle Inhalte sind AI-generiert und fiktiv. Ähnlichkeiten mit realen Personen, Ereignissen oder Orten sind zufällig.';

  @override
  String get homeRecent => 'Kürzlich';

  @override
  String get worldoUnableSavePreference =>
      'Deine Einstellung konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get worldoFilterGender => 'Nach Geschlecht filtern';

  @override
  String get worldoNoData => 'Keine Daten';

  @override
  String get worldoAll => 'Alle';

  @override
  String get worldoDetailSelectRole => 'Wähle deine Rolle';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'Ersteller: $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Worldo bearbeiten';

  @override
  String get worldoDetailWorldoBrief => 'Worldo-Kurzbeschreibung';

  @override
  String get worldoDetailNewPost => 'Neuer Beitrag';

  @override
  String get worldoDetailWritePost => 'Beitrag schreiben';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'Diskussion ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => 'Alle anzeigen >';

  @override
  String get worldoDetailPlayingWorld => 'Laufende Welt';

  @override
  String worldoDetailTickCountSubLabel({
    required String tickCount,
    required String subTickLabel,
    required String messageCountLabel,
  }) {
    return 'Tick $tickCount$subTickLabel · $messageCountLabel';
  }

  @override
  String worldoDetailCharactersLength({required String length}) {
    return 'Charaktere ($length)';
  }

  @override
  String get worldoSend => 'Senden';

  @override
  String get worldoPostFailed => 'Beitrag konnte nicht veröffentlicht werden';

  @override
  String get worldoImageUploadFailed => 'Bild-Upload fehlgeschlagen';

  @override
  String get worldoLoadRepliesFailed =>
      'Antworten konnten nicht geladen werden';

  @override
  String get worldoWriteReply => 'Antwort schreiben';

  @override
  String worldoReplyName({required String replyToName}) {
    return '$replyToName antworten';
  }

  @override
  String get worldoPostDetail => 'Beitragsdetails';

  @override
  String get worldoPostUnavailable => 'Beitrag nicht verfügbar';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'Alle Antworten $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return 'Alle $replyCount Antworten anzeigen';
  }

  @override
  String get worldoLikeFailed => '„Gefällt mir“ konnte nicht gesetzt werden';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return 'Alle $replyCount Antworten anzeigen';
  }

  @override
  String get worldoUser => 'Nutzer';

  @override
  String get worldoViewMore => 'Mehr anzeigen >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'Diskussion ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return 'Alle $remainingReplyCount Antworten anzeigen';
  }

  @override
  String get worldoReply => 'Antworten';

  @override
  String get worldoDiscussTitle => 'Diskussion';

  @override
  String get worldoLaunchLocationComesLife =>
      'Dieser Ort erwacht nach dem Start zum Leben.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      'Starte dieses Worldo, um hier zu erkunden und zu interagieren.';

  @override
  String get worldoLaunchRoleUnavailable =>
      'Diese Rolle ist nicht mehr verfügbar';

  @override
  String get worldoLaunchSelectRole => 'Wähle deine Rolle';

  @override
  String get worldoLaunchProfile => 'Dein Profil';

  @override
  String get worldoLaunchSuggested => 'Vorschläge';

  @override
  String get worldoLaunchName => 'Name';

  @override
  String get worldoLaunchIdentity => 'Identität';

  @override
  String get worldoLaunchPersonality => 'Persönlichkeit';

  @override
  String get worldoLaunchGoal => 'Ziel';

  @override
  String get worldoLaunchSetupRole => 'Richte deine Rolle ein';

  @override
  String get worldoLaunchPreset => 'Vorgegeben';

  @override
  String get worldoLaunchCustom => 'Individuell';

  @override
  String get worldoLaunchNoPresetRole => 'Keine vorgegebene Rolle';

  @override
  String get worldoLaunchFilling => 'Wird ausgefüllt...';

  @override
  String get worldoLaunchFillMyProfile => 'Aus meinem Profil ausfüllen';

  @override
  String get worldoLaunchLaunch => 'Starten';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName gestartet!';
  }

  @override
  String get worldoLaunchEnter => 'Betreten';

  @override
  String get createAction => 'Erstellen';

  @override
  String get createWorldoTitle => 'Worldo erstellen';

  @override
  String get createFailed => 'Erstellung fehlgeschlagen';

  @override
  String get createNotesRequired =>
      'Zum Veröffentlichen sind Versionshinweise erforderlich.';

  @override
  String get createActionInProgress => 'Diese Aktion läuft bereits.';

  @override
  String createCurrentVersion({required String version}) {
    return 'Aktuelle Version: $version';
  }

  @override
  String get createChecking => 'Wird geprüft...';

  @override
  String createSummaryName({required String name}) {
    return 'Worldo-Name: $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Worldo-Kurzbeschreibung: $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'Titelbild: $status';
  }

  @override
  String get createNotUploaded => 'Nicht hochgeladen';

  @override
  String get createUploaded => 'Hochgeladen';

  @override
  String createSummarySettings({required String settings}) {
    return 'Worldo-Einstellungen: $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Worldo-Zeit: $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Worldo-Kennzahl: $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '$count Tag',
      zero: '$count Tage',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 Charaktere';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Charaktere: $names',
      one: '1 Charakter: $names',
      zero: '0 Charaktere: $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'Empfohlen: $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · Region: $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · Gebäude: $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · Raum: $count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse',
      one: '1 Ereignis',
      zero: '$count Ereignisse',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return 'Charakterdialog: $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'Erzähler: $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return 'Bild: $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return '$itemLabel löschen?';
  }

  @override
  String get createItemHasContentDeleteAnyway =>
      'Dieses Element enthält Inhalte. Trotzdem löschen?';

  @override
  String get createImageUploadProgress => 'Bild wird gerade hochgeladen.';

  @override
  String get createBasicsBasics => 'Basisdaten';

  @override
  String get createSaveInProgress => 'Speichern läuft bereits.';

  @override
  String get createRequiredBeforeSave =>
      'Fülle vor dem Speichern alle Pflichtfelder aus.';

  @override
  String get createOpeningOpening => 'Einstieg';

  @override
  String get createCharacterCharactersCreate =>
      'Charaktere: Bitte erstelle mindestens einen Charakter.';

  @override
  String get createCharacterCharactersOnlyOne =>
      'Charaktere: Nur ein Charakter kann empfohlen werden.';

  @override
  String get createBasicsBasicsWorldoName =>
      'Basisdaten: Worldo-Name ist erforderlich.';

  @override
  String get createBasicsBasicsWorldoBrief =>
      'Basisdaten: Worldo-Kurzbeschreibung ist erforderlich.';

  @override
  String get createBasicsBasicsCoverImage =>
      'Basisdaten: Titelbild ist erforderlich.';

  @override
  String get createBasicsBasicsMetricMust =>
      'Basisdaten: Kennzahl muss gültiges JSON sein.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'Charakter #$characterIndex: Name ist erforderlich.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'Charakter #$characterIndex: Identität ist erforderlich.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'Charakter #$characterIndex: Persönlichkeit ist erforderlich.';
  }

  @override
  String get createCharacterCharactersLeast =>
      'Charaktere: Mindestens ein Charakter ist erforderlich.';

  @override
  String get createLocationLocationsCreate =>
      'Orte: Bitte erstelle mindestens einen Ort.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return 'Ort #$locationIndex: Ortsname ist erforderlich.';
  }

  @override
  String get createOpeningOpeningSelect =>
      'Einstieg: Wähle einen Ort und vervollständige jeden Dialogeintrag.';

  @override
  String get createOpeningOpeningSelected =>
      'Einstieg: Der ausgewählte Ort ist nicht mehr verfügbar.';

  @override
  String get createOpeningCharacterOpening =>
      'Einstieg: Ein ausgewählter Charakter ist nicht mehr verfügbar.';

  @override
  String get createOpeningOpeningDialogue =>
      'Einstieg: Ein Dialogcharakter befindet sich nicht am gewählten Ort. Öffne Einstieg, um dies zu korrigieren.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return 'Nicht unterstützter Einstiegsdialog: $type';
  }

  @override
  String get createCreating => 'Wird erstellt...';

  @override
  String get createDiscard => 'Verwerfen';

  @override
  String get createCharactersStep => 'Charaktere (>=1)';

  @override
  String get createLocationsStep => 'Orte (>=1)';

  @override
  String get createStoryEventsOptional => 'Handlungsereignisse (optional)';

  @override
  String get createUpdateNotesRequiredPublish =>
      'Versionshinweise (zum Veröffentlichen erforderlich)';

  @override
  String get createWhatChangedVersion =>
      'Was hat sich in dieser Version geändert?';

  @override
  String get createView => 'Ansehen';

  @override
  String get createNotStartedYet => 'Noch nicht begonnen';

  @override
  String get createEdited => 'Bearbeitet';

  @override
  String get createPublishingWorldo => 'Dein Worldo wird veröffentlicht';

  @override
  String get createCreatingWorldo => 'Dein Worldo wird erstellt';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Deine Worldo-Änderungen werden vorbereitet.\nBitte warte einen Moment.';

  @override
  String get createBringingWorldoLifeWait =>
      'Dein Worldo erwacht zum Leben.\nBitte warte einen Moment.';

  @override
  String get createDescribeIssue => 'Beschreibe das Problem';

  @override
  String get createSubmit => 'Absenden';

  @override
  String get createBasicsWorldoName => 'Worldo-Name *';

  @override
  String get createBasicsNameRequired => 'Worldo-Name ist erforderlich.';

  @override
  String get createBasicsBriefRequired =>
      'Worldo-Kurzbeschreibung ist erforderlich.';

  @override
  String get createBasicsCoverRequired => 'Titelbild ist erforderlich.';

  @override
  String get createBasicsMetricInvalid => 'Kennzahl muss gültiges JSON sein.';

  @override
  String get createBasicsEgMainStreet => 'z. B. Hauptstraße';

  @override
  String get createBasicsWorldoBrief => 'Worldo-Kurzbeschreibung *';

  @override
  String get createBasicsBriefNote =>
      'Der öffentliche Einstieg, den Spieler zuerst sehen: Schauplatz, zentraler Konflikt und das, was neugierig macht.';

  @override
  String get createBasicsHiddenNote =>
      'Verborgene Regeln und Hintergründe, die die Geschichte antreiben: Absichten, Mechaniken und geheime Grenzen.';

  @override
  String get createBasicsEgHalfShopsMain =>
      'z. B. Die Hälfte der Läden in der Hauptstraße ist vernagelt. Am Tag der Arbeit gehört die Stadt dem reichsten Ladenbesitzer.';

  @override
  String get createBasicsCoverImage => 'Titelbild *';

  @override
  String get createBasicsUpload => 'Hochladen';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'Für Karten und Detailseiten. Empfohlen: ca. 768×1024 px. Unterstützte Formate: JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden =>
      'Worldo-Einstellungen – verborgen (optional)';

  @override
  String get createBasicsEgBankerSecretly =>
      'z. B. Der Banker entscheidet heimlich über Kredite; wer sich übernimmt, kann verdrängt werden.';

  @override
  String get createBasicsWorldoTimeOptional => 'Worldo-Zeit (optional)';

  @override
  String get createBasicsWorldoStartsStart =>
      'Dieses worldo beginnt bei {Startzeit}; jedes Tippen auf *Fortschreiten* verschiebt die Zeitlinie um {Zeit pro Fortschritt}.';

  @override
  String get createBasicsStartTime => 'Startzeit';

  @override
  String get createBasicsDateExample => 'z. B. Tag 1, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => 'Zeit pro Fortschritt';

  @override
  String get createBasicsEg8Hours3Days => 'z. B. 8 Stunden / 3 Tage';

  @override
  String get createBasicsWorldoMetricOptional => 'Worldo-Kennzahl (optional)';

  @override
  String get createBasicsMetricLabel => 'Kennzahlname';

  @override
  String get createBasicsEgWealthGoalProgress =>
      'z. B. Vermögen / Zielfortschritt';

  @override
  String get createBasicsLabelNote => 'Hinweis zur Kennzahl';

  @override
  String get createBasicsDescribeWhatMetric =>
      'Beschreibe, was diese Kennzahl misst';

  @override
  String get createBasicsUnit => 'Einheit';

  @override
  String get createBasicsEgCoins => 'z. B. Münzen / %';

  @override
  String get createBasicsRange => 'Wertebereich';

  @override
  String get createBasicsStarting => 'Startwert';

  @override
  String get createBasicsDeltaMin => 'Min. Änderung';

  @override
  String get createBasicsDeltaMax => 'Max. Änderung';

  @override
  String get createBasicsSaving => 'Wird gespeichert...';

  @override
  String get createBasicsAdvancedSettings =>
      'Erweiterte Einstellungen (optional)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'Charakter $index';
  }

  @override
  String get createCharacterSuggest => 'Empfehlen';

  @override
  String get createCharacterAvatarOptional => 'AVATAR\n(optional)';

  @override
  String get createCharacterName => 'Name *';

  @override
  String get createCharactersTitle => 'Charaktere';

  @override
  String createCharacterLimit({required int count}) {
    return 'Du kannst bis zu $count Charaktere hinzufügen.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'Charakter $index: Name ist erforderlich.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'Charakter $index: Identität ist erforderlich.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'Charakter $index: Persönlichkeit ist erforderlich.';
  }

  @override
  String get createCharacterMinOne =>
      'Bitte erstelle mindestens einen Charakter.';

  @override
  String get createCharacterEnterName => 'Name eingeben...';

  @override
  String get createCharacterIdentity => 'Identität *';

  @override
  String get createCharacterEgHometownKidBack =>
      'z. B. Ein Heimkehrer mit einer echten Chance';

  @override
  String get createCharacterPersonality => 'Persönlichkeit *';

  @override
  String get createCharacterEgUnderdog =>
      'z. B. Ein gutmütiger Außenseiter mit wenig Kapital';

  @override
  String get createCharacterGoalOptional => 'Ziel (optional)';

  @override
  String get createCharacterEgRichestOwner =>
      'z. B. Bis zum Tag der Arbeit der reichste Besitzer der Hauptstraße werden';

  @override
  String get createCharacterBackgroundHidden =>
      'Hintergrund – verborgen (optional)';

  @override
  String get createCharacterEgLeftTownYears =>
      'z. B. Verließ die Stadt vor Jahren und kehrt für eine Chance zur vernagelten Hauptstraße zurück.';

  @override
  String get createCharacterAddCharacter => '+ Charakter hinzufügen';

  @override
  String get createLocationImageOptional => 'BILD\n(optional)';

  @override
  String get createCharacterSelectAvailable =>
      'Wähle unten aus den verfügbaren Charakteren';

  @override
  String get createCharacterInitialCharacters => 'Anfangscharaktere (optional)';

  @override
  String get createLocationStartingCharacters =>
      'Die Charaktere, die sich zu Beginn des worldo hier befinden.';

  @override
  String get createCharacterAvailableSelect => 'Zur Auswahl verfügbar';

  @override
  String get createCharacterNoCharactersYet =>
      'Noch keine Charaktere. Erstelle zuerst Charaktere und wähle dann ihre Startorte.';

  @override
  String get createCharacterNoCharacters =>
      'Keine Charaktere verfügbar. Alle Charaktere haben bereits einen Anfangsort.';

  @override
  String get createLocationEveryL2L3Locations =>
      'Alle enthaltenen L2- und L3-Orte werden ebenfalls entfernt.';

  @override
  String get createLocationEveryL3Locations =>
      'Alle enthaltenen L3-Orte werden ebenfalls entfernt.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return '„$displayName“ löschen';
  }

  @override
  String get createLocationOpeningLocation =>
      'Dies ist der Einstiegsort. Beim Löschen wird auch der Einstieg gelöscht.';

  @override
  String get createLocationL1LocationRegion => 'L1-Ort · Region *';

  @override
  String get createLocationL2LocationBuilding => 'L2-Ort · Gebäude *';

  @override
  String get createLocationAddL3Location => 'L3-Ort hinzufügen';

  @override
  String get createLocationsTitle => 'Orte';

  @override
  String get createLocationStatisticsNote =>
      'Deine Welt besteht aus 3 Ebenen:\nL1 · Region     Ein Gebiet deiner Welt – Innenstadt\nL2 · Gebäude   Ein Gebäude darin – Joes Restaurant\nL3 · Raum       Ein Raum im Gebäude – Hinterküche\nJeder Ort braucht alle drei Ebenen. Insgesamt sind bis zu 15 Räume möglich.';

  @override
  String get createLocationL1NameNote =>
      'Ein Gebiet deiner Welt: ein Viertel, eine Stadt oder ein Wald. Kein einzelnes Gebäude.';

  @override
  String get createLocationL2NameNote =>
      'Ein Gebäude in dieser Region: ein Laden, eine Schule oder ein Wohnblock.';

  @override
  String get createLocationL3NameNote =>
      'Ein Raum im Gebäude. Auch Dächer, Innenhöfe und Eingänge sind möglich.';

  @override
  String get createLocationName => 'Name *';

  @override
  String get createLocationL1NameRequired =>
      'Name des L1-Orts ist erforderlich.';

  @override
  String get createLocationL3NameRequired =>
      'Name des L3-Orts ist erforderlich.';

  @override
  String get createLocationThisL1 => 'Dieser L1-Ort';

  @override
  String get createLocationThisL2 => 'Dieser L2-Ort';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel muss mindestens einen L2-Ort enthalten.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel muss mindestens einen L3-Ort enthalten.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel enthält einen L2-Ort, der einen Namen braucht.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel enthält einen L3-Ort, der einen Namen braucht.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'Du kannst bis zu $count L3-Orte hinzufügen.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return 'Du hast alle $count Räume verwendet. Lösche einen, um einen weiteren hinzuzufügen.';
  }

  @override
  String get createLocationAtLeastOneL1 =>
      'Mindestens ein L1-Ort ist erforderlich.';

  @override
  String get createLocationAddL1 => 'Füge mindestens einen L1-Ort hinzu.';

  @override
  String get createLocationMinOne => 'Bitte erstelle mindestens einen Ort.';

  @override
  String get createLocationIdRequired => 'Jeder Ort muss eine ID haben.';

  @override
  String get createLocationIdUnique =>
      'Jeder Ort muss eine eindeutige ID haben.';

  @override
  String get createLocationParentInvalid =>
      'Jeder Ort muss einen gültigen übergeordneten Ort haben.';

  @override
  String get createLocationFieldsRequired =>
      'Fülle vor dem Speichern alle erforderlichen Ortsfelder aus.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Beim Speichern der Orte werden auch $count Einstiegsdialogblasen für die entfernten Charaktere gelöscht.',
      one:
          'Beim Speichern der Orte wird auch 1 Einstiegsdialogblase für die entfernten Charaktere gelöscht.',
      zero:
          'Beim Speichern der Orte werden auch $count Einstiegsdialogblasen für die entfernten Charaktere gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'L3-Ort bearbeiten';

  @override
  String get createLocationPreview => 'Vorschau';

  @override
  String get createLocationCompleteLocation =>
      'Vervollständige diesen Ort oder lösche ihn.';

  @override
  String get createLocationRemoveCharacter =>
      'Charakter aus dem Ort entfernen?';

  @override
  String get createLocationRemove => 'Entfernen';

  @override
  String get createLocationL1Location => 'L1-Ort';

  @override
  String get createLocationL2Location => 'L2-Ort';

  @override
  String get createLocationL3Location => 'L3-Ort';

  @override
  String get createOpeningSelectLocation => 'Ort auswählen';

  @override
  String get createOpeningNoSavedLocations => 'Keine gespeicherten Orte';

  @override
  String get createOpeningSelect => 'Auswählen';

  @override
  String get createOpeningSelectLocationFirst => 'Wähle zuerst einen Ort.';

  @override
  String get createOpeningNoInitialCharacter => 'Kein Anfangscharakter';

  @override
  String get createOpeningLocationsLoading => 'Orte werden noch geladen.';

  @override
  String get createOpeningLoadingLocations => 'Orte werden geladen...';

  @override
  String get createOpeningSwitchingLocations =>
      'Ein Ortswechsel löscht den Dialoginhalt.';

  @override
  String get createOpeningContinue => 'Weiter';

  @override
  String get createOpeningAdd10DialogueItems =>
      'Du kannst bis zu 10 Dialogeinträge hinzufügen.';

  @override
  String get settingsUnableSaveSuggestedRole =>
      'Empfohlene Rolle konnte nicht gespeichert werden.';

  @override
  String get createOpeningUnableSaveOpening =>
      'Einstieg konnte nicht gespeichert werden.';

  @override
  String get createOpeningSelectInitial => 'Anfangsort auswählen';

  @override
  String get createOpeningInitialLocationRequired =>
      'Wähle vor dem Speichern einen Anfangsort.';

  @override
  String get createOpeningAddDialogueFirst =>
      'Füge vor dem Speichern mindestens einen Dialogeintrag hinzu.';

  @override
  String get createOpeningCompleteDialogue =>
      'Vervollständige vor dem Speichern jeden Dialogeintrag.';

  @override
  String get createOpeningDialogue => 'Einstiegsdialog';

  @override
  String get createOpeningLocationRequired =>
      'Wähle zuerst einen Ort und bearbeite dann den Dialog.';

  @override
  String get createOpeningNarrator => 'Erzähler';

  @override
  String get createOpeningImage => 'Bild';

  @override
  String get createOpeningSuggestRoleUser =>
      'Eine Rolle für den Nutzer empfehlen';

  @override
  String get createOpeningNoCharacters => 'Keine Charaktere verfügbar.';

  @override
  String get createOpeningEnterNarrator => 'Erzählerdialog eingeben';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return 'Dialog von $name eingeben';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => 'BILD HOCHLADEN';

  @override
  String get createEventAddEvent => '+ Ereignis hinzufügen';

  @override
  String get createStoryEventsTitle => 'Handlungsereignisse';

  @override
  String createEventLimit({required int count}) {
    return 'Du kannst bis zu $count Ereignisse hinzufügen.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'Ereignis $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      'z. B. Eine nationale Kette sucht ein unbebautes Grundstück und droht, alle lokalen Preise zu unterbieten.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'Ein wichtiger Handlungsschritt, mit dem die AI die Geschichte lenkt.';

  @override
  String get imageCropUploadFailed => 'Upload fehlgeschlagen';

  @override
  String get inboxNotifications => 'Benachrichtigungen';

  @override
  String get inboxNoNotificationsYet => 'Noch keine Benachrichtigungen.';

  @override
  String get inboxFollowers => 'Follower';

  @override
  String get inboxNewFollowers => 'Neue Follower';

  @override
  String get inboxNoNewFollowersYet => 'Noch keine neuen Follower.';

  @override
  String get inboxComments => 'Kommentare';

  @override
  String get inboxNoCommentsYet => 'Noch keine Kommentare.';

  @override
  String get inboxPrivateChats => 'Private Chats';

  @override
  String get inboxChatFriendsWorldo => 'Chatte mit deinen Freunden auf Worldo.';

  @override
  String get inboxUnknownUser => 'Unbekannter Nutzer';

  @override
  String get inboxDirectMessage => 'Direktnachricht';

  @override
  String get inboxJoinRequest => 'Beitrittsanfrage';

  @override
  String get inboxApprove => 'Genehmigen';

  @override
  String get inboxReject => 'Ablehnen';

  @override
  String get inboxOk => 'OK';

  @override
  String get inboxReviewFailed => 'Prüfung fehlgeschlagen';

  @override
  String get inboxLoadMessagesFailed =>
      'Nachrichten konnten nicht geladen werden.';

  @override
  String get inboxNewMessage => 'Neue Nachricht';

  @override
  String get inboxSomeone => 'Jemand';

  @override
  String get inboxWorld => 'diese Welt';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name möchte $world$suffix beitreten';
  }

  @override
  String get inboxCommentWorldo => ' hat dein worldo kommentiert';

  @override
  String get inboxReply => ' hat dir geantwortet';

  @override
  String get inboxLikeComment => ' gefällt dein Kommentar';

  @override
  String get inboxLikedComment => 'gefällt dein Kommentar';

  @override
  String get inboxComment2LikeComment => 'gefällt dein Kommentar';

  @override
  String get inboxReplied => 'hat dir geantwortet';

  @override
  String get inboxYou2Reply => 'hat dir geantwortet';

  @override
  String get inboxCommentedOrigin => 'hat dein Werk kommentiert';

  @override
  String get inboxCommentOrigin => 'hat dein Werk kommentiert';

  @override
  String get inboxSentMessage => ' hat dir eine Nachricht gesendet';

  @override
  String get inboxStartedFollowing => ' folgt dir jetzt.';

  @override
  String get meFailedOpenDiscord => 'Discord konnte nicht geöffnet werden';

  @override
  String get meImagePickFailed => 'Bildauswahl fehlgeschlagen';

  @override
  String get meUpdateFailed => 'Aktualisierung fehlgeschlagen';

  @override
  String get mePlaying => 'Im Spiel';

  @override
  String get meEditName => 'Namen bearbeiten';

  @override
  String get meSignUpReward => 'Registriere dich und erhalte 250 Gems!';

  @override
  String get loginSignUpReward => 'Registriere dich und erhalte 250 Gems!';

  @override
  String get meUnknown => 'Unbekannt';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID: $oid\nNeueste Version: $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID: $displayWid\nBesitzer: $owner';
  }

  @override
  String get meFollows => 'Folgt';

  @override
  String meFollowingCount({required String followingCount}) {
    return 'Folgt $followingCount';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount Follower';
  }

  @override
  String get meNoFollowingYet => 'Du folgst noch niemandem.';

  @override
  String get meNoFollowersYet => 'Noch keine Follower.';

  @override
  String get meBlockFailed =>
      'Blockieren fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get meUserBlockedContentHasReported =>
      'Nutzer blockiert. Dieser Inhalt wurde dem Worldo-Team gemeldet.';

  @override
  String get meBlockUser => 'Diesen Nutzer blockieren?';

  @override
  String get meBlock => 'Blockieren';

  @override
  String get meUnblockFailed =>
      'Entsperren fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get meUnblock => 'Entsperren';

  @override
  String get meFollowing => 'Gefolgt';

  @override
  String get meFollow => 'Folgen';

  @override
  String get meMessage => 'Nachricht';

  @override
  String meUID({required String uid}) {
    return 'UID: $uid';
  }

  @override
  String get meNoWorldoCreatedYet => 'Du hast noch kein Worldo erstellt.';

  @override
  String get meNoWorldoYet => 'Noch keine Worldos.';

  @override
  String get meNoWorldsCreatedYet => 'Du hast noch keine Welt erstellt.';

  @override
  String get meNoWorldsYet => 'Noch keine Welten.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'Rote Gems';

  @override
  String get gemsPink => 'Rosa Gems';

  @override
  String get gemsTop => 'Aufladen';

  @override
  String get gemsBuy => 'Gems kaufen';

  @override
  String get gemsRecords => 'Verlauf';

  @override
  String get gemsUnableLoad => 'Gems konnten nicht geladen werden.';

  @override
  String get settingsLogOutAccount => 'Von deinem Konto abmelden?';

  @override
  String get settingsLogOut => 'Abmelden';

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsAboutUs => 'Über uns';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsBlockedUsers => 'Blockierte Nutzer';

  @override
  String get settingsJoinDiscord => 'Discord beitreten';

  @override
  String get meUserUnblocked => 'Nutzer entsperrt';

  @override
  String get meNoBlockedUsersYet => 'Noch keine blockierten Nutzer.';

  @override
  String get settingsAgreeTermsContinue =>
      'Stimme unseren Bedingungen zu, um fortzufahren.';

  @override
  String get settingsDeleteAccount => 'Dein Konto löschen?';

  @override
  String get settingsAccountDeletionAgreement =>
      'Vereinbarung zur Kontolöschung';

  @override
  String get settingsEnsureSecurityAccount =>
      'Bitte lies die Folgen der Kontolöschung, um die Sicherheit deines Kontos zu gewährleisten.\n\nDas Löschen des Kontos ist nicht dasselbe wie das Abmelden und kann nicht rückgängig gemacht werden. Deine privaten Daten, darunter erstellte Charaktere, Suchverlauf, Chats mit Charakteren, Favoriten, Erinnerungen, Interaktionsdaten und Bestellungen, werden dauerhaft gelöscht und können nicht wiederhergestellt werden.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      'Alle ungenutzten Gems, gekauft oder verdient, gehen dauerhaft verloren. Wenn du fortfährst, verzichtest du freiwillig darauf. Die Kontolöschung berechtigt nicht automatisch zu einer Rückerstattung.\n\nAlle verbleibenden Mitgliedschaftsvorteile gehen ebenfalls dauerhaft verloren und können nicht wiederhergestellt werden. Das Löschen deines Kontos kündigt dein Abonnement nicht.';

  @override
  String get settingsIHaveReadAccountDeletion =>
      'Ich habe die Vereinbarung zur Kontolöschung gelesen';

  @override
  String get settingsCurrentLoginAccount => 'Aktuell angemeldetes Konto:';

  @override
  String get profileSaveFailed =>
      'Dein Profil konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get meSignInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get meCompleteProfileContinue =>
      'Vervollständige dein Profil, um fortzufahren.';

  @override
  String get meSelectGenderAge => 'Bitte wähle dein Geschlecht und Alter.';

  @override
  String get meSelectGender => 'Bitte wähle dein Geschlecht.';

  @override
  String get meSelectAge => 'Bitte wähle dein Alter.';

  @override
  String get meRequired => 'Erforderlich';

  @override
  String get mePersonalizeWorldoExperience =>
      'Personalisiere dein Worldo-Erlebnis';

  @override
  String get meSignIn => 'Anmelden';

  @override
  String get meBack => 'Zurück';

  @override
  String get meSkip => 'Überspringen';

  @override
  String get meContinueGoogle => 'Mit Google fortfahren';

  @override
  String get meContinueApple => 'Mit Apple fortfahren';

  @override
  String get meSignUpClaimPremium => 'Registrieren und Premium erhalten';

  @override
  String get meSignUpContinue => 'Registrieren, um fortzufahren';

  @override
  String get meAccountLoggedAnotherDevice =>
      'Dein Konto ist auf einem anderen Gerät angemeldet.';

  @override
  String get premiumSubscription => 'Abonnement';

  @override
  String get gemsClaimFailed => 'Abholen fehlgeschlagen.';

  @override
  String get gemsCheckFailed => 'Check-in fehlgeschlagen.';

  @override
  String get gemsFollowFailed => 'Folgen fehlgeschlagen.';

  @override
  String get gemsTaskUpdateFailed => 'Aufgabenaktualisierung fehlgeschlagen.';

  @override
  String get gemsClaimSuccessful => 'Erfolgreich abgeholt!';

  @override
  String get gemsUnableLoadGemPacks =>
      'Gem-Pakete konnten nicht geladen werden.';

  @override
  String get gemsNoGemPacksAvailable => 'Keine Gem-Pakete verfügbar.';

  @override
  String get gemsUnableLoadGemTasks =>
      'Gem-Aufgaben konnten nicht geladen werden.';

  @override
  String get gemsJoinUs => 'Mach mit';

  @override
  String get gemsClaim => 'Abholen';

  @override
  String get gemsClaimed => 'Abgeholt';

  @override
  String get meDailyCheck => 'Täglicher Check-in';

  @override
  String get gemsDailyCheckInReward => '100 erhalten';

  @override
  String get meCheck => 'Einchecken';

  @override
  String get meCheckSuccessful => 'Check-in erfolgreich!';

  @override
  String get meGooglePlayUnavailable => 'Google Play ist nicht verfügbar.';

  @override
  String get mePurchaseFailed => 'Kauf fehlgeschlagen.';

  @override
  String get gemsEarned => 'Verdient';

  @override
  String get gemsSpent => 'Ausgegeben';

  @override
  String get gemsPurchase => 'Kauf';

  @override
  String get gemsGemRecords => 'Gem-Verlauf';

  @override
  String get gemsUnableLoadRecords => 'Verlauf konnte nicht geladen werden.';

  @override
  String get gemsNoGemRecordsYet => 'Noch kein Gem-Verlauf.';

  @override
  String get meAbout => 'Über';

  @override
  String get meEmailCopied => 'E-Mail-Adresse kopiert';

  @override
  String get mePurchasingPremium => 'Premium wird gekauft';

  @override
  String get mePurchaseSuccessful => 'Kauf erfolgreich!';

  @override
  String get meWorldoPremiumSubscription =>
      'Dein Worldo-Premium-Abonnement ist jetzt aktiv.';

  @override
  String get meMyBalance => 'Mein Guthaben';

  @override
  String get meSoldOut => 'Ausverkauft';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession =>
      'Für die Modellliste ist eine vollständige Nutzersitzung erforderlich';

  @override
  String get memoryModelListPermissionDenied =>
      'Zugriff auf die Modellliste für diese Welt verweigert';

  @override
  String get memorySaveFailed => 'Speichern fehlgeschlagen';

  @override
  String get memorySaveResultNotConfirmed => 'Speicherergebnis nicht bestätigt';

  @override
  String get memoryChooseModel => 'Modell auswählen';

  @override
  String get memoryMaxTokenLimit => 'Maximales Gedächtnis-Token-Limit';

  @override
  String get memoryNoModelsAvailable => 'Keine Modelle verfügbar';

  @override
  String get memoryRetryRanges => 'Wiederholungsbereiche';

  @override
  String get memoryCurrentUsage => 'Deine aktuelle Gedächtnisnutzung';

  @override
  String memoryMinGems({required String min}) {
    return '$min Gems';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min–$max Gems';
  }

  @override
  String memoryStart({required String memoryStart}) {
    return 'Gedächtnis $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return 'Gedächtnis $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable =>
      'Gedächtniseinstellungen nicht verfügbar';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Play hat zu lange zum Antworten gebraucht. Bitte versuche es erneut.';

  @override
  String get premiumSubscriptionsNotSupported =>
      'Google Play unterstützt auf diesem Gerät keine Abonnements.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'Die Verbindung zu Google Play wurde unterbrochen. Bitte versuche es erneut.';

  @override
  String get premiumPurchaseCanceled => 'Kauf abgebrochen.';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Play ist vorübergehend nicht verfügbar. Bitte versuche es später erneut.';

  @override
  String get premiumGooglePlayBilling =>
      'Google-Play-Abrechnung ist nicht verfügbar. Prüfe dein Play-Konto und deine Zahlungseinstellungen.';

  @override
  String get premiumSubscriptionUnavailable =>
      'Dieses Premium-Abonnement ist derzeit bei Google Play nicht verfügbar.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play konnte diesen Premium-Kauf nicht abschließen. Bitte versuche es erneut.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'Du besitzt dieses Abonnement bereits bei Google Play.';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Play konnte das zu ändernde Abonnement nicht finden. Prüfe „Abonnements verwalten“.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Verbindung zu Google Play fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get premiumInsufficientFunds =>
      'Deine Zahlungsmethode hat nicht genügend Guthaben. Aktualisiere sie in Google Play und versuche es erneut.';

  @override
  String get premiumGoogleAccountIneligible =>
      'Dein Google-Play-Konto ist für dieses Abonnementangebot nicht berechtigt.';

  @override
  String get premiumAppStoreFailedComplete =>
      'Der App Store konnte diesen Premium-Kauf nicht abschließen. Bitte versuche es erneut.';

  @override
  String get premiumFailedConnectAppStore =>
      'Verbindung zum App Store fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get premiumAppStoreTookTooLong =>
      'Der App Store hat zu lange zum Antworten gebraucht. Bitte versuche es erneut.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'Im App Store ist ein Systemfehler aufgetreten. Bitte versuche es später erneut.';

  @override
  String get premiumRegionUnavailable =>
      'Dieses Premium-Abonnement ist in deiner App-Store-Region nicht verfügbar.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'Diese App kann diese App-Store-Anfrage nicht ausführen. Kontaktiere den Support.';

  @override
  String get premiumPurchaseNotSupported =>
      'Dieser Kauf wird auf diesem Gerät oder dieser Systemversion nicht unterstützt.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'Das App-Store-Kauffenster konnte nicht geöffnet werden. Kehre zur App zurück und versuche es erneut.';

  @override
  String get premiumAppStoreFailedAccept =>
      'Der App Store konnte diese Kaufmenge nicht akzeptieren. Kontaktiere den Support.';

  @override
  String get premiumAppStoreUnavailable =>
      'Dieses Premium-Abonnement ist derzeit im App Store nicht verfügbar.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'Käufe sind auf diesem Gerät nicht erlaubt. Prüfe deinen Apple Account und die Kaufbeschränkungen.';

  @override
  String get premiumAppleAccountNotEligible =>
      'Dein Apple Account ist für dieses Abonnementangebot nicht berechtigt.';

  @override
  String get premiumSubscriptionOffer =>
      'Dieses Abonnementangebot ist nicht verfügbar. Aktualisiere die Seite und versuche es erneut.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'Der App Store konnte diesen Angebotspreis nicht akzeptieren. Aktualisiere die Seite und versuche es erneut.';

  @override
  String get premiumAppStoreFailedVerify =>
      'Der App Store konnte dieses Abonnementangebot nicht prüfen. Kontaktiere den Support.';

  @override
  String get premiumSubscriptionOfferFailed =>
      'Dieses Abonnementangebot konnte nicht vorbereitet werden. Aktualisiere die Seite und versuche es erneut.';

  @override
  String get premiumAddPaymentMethodApple =>
      'Füge deinem Apple Account eine Zahlungsmethode hinzu und versuche es erneut.';

  @override
  String get premiumAppCannotMakePurchases =>
      'Diese App kann keine Käufe im App Store durchführen. Kontaktiere den Support.';

  @override
  String get premiumAppStoreRequestRejected =>
      'Der App Store konnte diese Kaufanfrage nicht akzeptieren. Versuche es erneut oder kontaktiere den Support.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'Zugriff auf Apples Cloud-Dienst verweigert. Prüfe die Berechtigungen deines Apple Accounts.';

  @override
  String get premiumFailedConnectApple =>
      'Verbindung zu Apple-Diensten fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get premiumAccess2AppleCloudService =>
      'Zugriff auf Apples Cloud-Dienst widerrufen. Prüfe die Einstellungen deines Apple Accounts.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Akzeptiere die aktuellen Apple-Datenschutzbedingungen in deinem Apple Account und versuche es erneut.';

  @override
  String get premiumAppStoreWindowFailed =>
      'Das App-Store-Fenster konnte nicht eingerichtet werden. Kontaktiere den Support.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'Das App-Store-Fenster hat zu lange zum Öffnen gebraucht. Bitte versuche es erneut.';

  @override
  String get premiumReturnAppTryPurchase =>
      'Kehre zur App zurück und versuche den Kauf erneut.';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Play ist nicht verfügbar. Prüfe, ob es installiert ist und du angemeldet bist.';

  @override
  String get premiumIs4Subscription =>
      'Dieses Premium-Abonnement ist derzeit im Store nicht verfügbar. Aktualisiere die Seite und versuche es erneut.';

  @override
  String get premiumSubscriptionFailed =>
      'Dieses Premium-Abonnement konnte nicht vorbereitet werden. Aktualisiere die Seite und versuche es erneut.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'Der Store konnte diesen Premium-Kauf nicht öffnen. Bitte versuche es erneut.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'Das ursprüngliche Abonnement wurde bei Google Play nicht gefunden. Prüfe „Abonnements verwalten“.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'Dieses Abonnement verwendet eine andere Kaufidentität. Aktualisiere die Seite oder kontaktiere den Support.';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play kann dieses Abonnement noch nicht ändern. Prüfe „Abonnements verwalten“.';

  @override
  String get premiumPlanChangePending =>
      'Ein App-Store-Kauf für diesen Tarif wird noch verarbeitet. Warte, bis er abgeschlossen ist.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'Premium-Tarife konnten nicht aus dem App Store geladen werden. Bitte versuche es erneut.';

  @override
  String get premiumPurchasePreparation =>
      'Die Kaufvorbereitung ist abgelaufen. Bitte versuche es erneut.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'Der App Store hat ein unbekanntes Kaufergebnis zurückgegeben. Prüfe dein Abonnement, bevor du es erneut versuchst.';

  @override
  String get premiumPurchasesUnavailable =>
      'Käufe sind derzeit nicht verfügbar.';

  @override
  String get premiumAutoRenewsCancelAnytime =>
      'Automatische Verlängerung. Jederzeit kündbar.';

  @override
  String get premiumSubscribed => 'Abonniert';

  @override
  String get premiumAlsoIncluded => 'Ebenfalls enthalten';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'Rosa Gems';

  @override
  String get premiumRedGems => 'Rote Gems';

  @override
  String get premiumExtraDailyCheck => 'Zusätzlich beim täglichen Check-in';

  @override
  String get premiumDailyCheck => 'Täglicher Check-in';

  @override
  String get premiumClaimedMonthly => 'Monatlich abgeholt';

  @override
  String get premiumBilledMonthly => 'Monatlich abgerechnet';

  @override
  String premiumSaveSavings({required String savings}) {
    return '$savings% sparen';
  }

  @override
  String get premiumSubscribe => 'Abonnieren';

  @override
  String get premiumActiveYearlySubscription =>
      'Ein aktives jährliches Premium-Abonnement kann nicht auf einen monatlichen Tarif umgestellt werden.';

  @override
  String get premiumAlreadyHaveActive =>
      'Du hast bereits ein aktives Premium-Abonnement.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'Du hast Premium $label bereits abonniert.';
  }

  @override
  String get premiumPreviousPurchasePending =>
      'Dein vorheriger Premium-Kauf wird noch bestätigt.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Nutze den ursprünglichen Store, um dein Premium-Abonnement zu erweitern.';

  @override
  String get premiumResolveCurrent =>
      'Kläre dein aktuelles Abonnement im Store, bevor du einen Kauf tätigst.';

  @override
  String get premiumPurchaseUnavailable =>
      'Premium-Kauf ist derzeit nicht verfügbar.';

  @override
  String get premiumUnableVerifyPurchase =>
      'Kaufberechtigung konnte nicht geprüft werden. Bitte versuche es erneut.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      'Der Store konnte diesen Premium-Kauf nicht prüfen.';

  @override
  String get premiumPurchaseDoesNotMatch =>
      'Dieser Premium-Kauf entspricht nicht dem ausgewählten Tarif.';

  @override
  String get premiumMessagePurchaseCanceled =>
      'Dieser Premium-Kauf wurde abgebrochen.';

  @override
  String get premiumPurchaseRevoked => 'Dieser Premium-Kauf wurde widerrufen.';

  @override
  String get premiumNotification => 'Benachrichtigung';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premium ist in deinem Abonnement aktiv und unterstützt keine Herabstufung.';

  @override
  String get premiumGot => 'Verstanden';

  @override
  String get gemBalancePromptInsufficientGems => 'Nicht genügend Gems';

  @override
  String get gemBalancePromptLowGems => 'Wenige Gems';

  @override
  String get appPressBackExit =>
      'Drücke erneut Zurück, um die App zu verlassen.';

  @override
  String get appReportSubmitted => 'Meldung gesendet';

  @override
  String get appReportFailed => 'Meldung fehlgeschlagen';

  @override
  String get appUpdateRequired => 'Update erforderlich';

  @override
  String get appUpdateContent =>
      'Aktualisiere auf die neueste Version, um Worldo weiter zu nutzen.';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'Version $versionName';
  }

  @override
  String get appUpdateCheckFailed =>
      'Update-Status konnte nicht aktualisiert werden. Aktualisiere die App, um fortzufahren.';

  @override
  String get appUpdate => 'Jetzt aktualisieren';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabel kopiert';
  }

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonImageLoadFailed => 'Bild konnte nicht geladen werden';

  @override
  String get commonPageNotFound => 'Seite nicht gefunden.';

  @override
  String worldDetailTickCount({
    required String tickCount,
    required String subTickSuffix,
  }) {
    return 'Tick $tickCount$subTickSuffix';
  }

  @override
  String worldDetailItemTickNumber({
    required String tickNumber,
    required String subTickSuffix,
  }) {
    return 'Tick $tickNumber$subTickSuffix';
  }

  @override
  String worldDetailHeaderTickNumber({
    required String tickNumber,
    required String subTickSuffix,
    required String dateSuffix,
  }) {
    return 'Tick $tickNumber$subTickSuffix$dateSuffix';
  }

  @override
  String worldFirstTickGenerating({required String progressDots}) {
    return 'Das LLM generiert deinen ersten Tick. Dies kann einen Moment dauern$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return 'Neueste Version: V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return 'Speichere $missingSections vor dem Erstellen.';
  }

  @override
  String get createCharacterRoleHint => 'Die Rolle des Charakters im worldo.';

  @override
  String get createCharacterMannerHint =>
      'Die Sprechweise und das Verhalten des Charakters, die seine Dialoge bestimmen.';

  @override
  String get createCharacterGoalHint =>
      'Das Ziel oder die Verhaltensrichtung des Charakters, die seine Handlungen bestimmen.';

  @override
  String get createCharacterBackgroundHint =>
      'Der Hintergrund und die Beziehungen des Charakters.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return 'Beitrittsanfrage für $world$worldIdSuffix';
  }

  @override
  String get memoryModel => 'Gedächtnis und Modell';

  @override
  String get premiumAccountMismatch =>
      'Die Kontokennungen stimmen nicht mit dem vorherigen Abonnement überein.';

  @override
  String get worldRecap => 'Rückblick';

  @override
  String get inboxMissingJoinRequestId => 'ID der Beitrittsanfrage fehlt';

  @override
  String get loginTimedOut =>
      'Zeitüberschreitung bei der Anmeldung. Bitte versuche es erneut.';

  @override
  String get loginConnectionFailed =>
      'Verbindung fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get loginTemporarilyUnavailable =>
      'Die Anmeldung ist vorübergehend nicht verfügbar. Bitte versuche es später erneut.';

  @override
  String get recapUnlockHeading => 'Schaltet den Rückblick frei';

  @override
  String get recapUpsellDescription =>
      'Hol deine Geschichte mit einem vollständigen Rückblick auf jede Wendung, jede Entscheidung und jeden Charakter nach.';

  @override
  String get recapShowEarlier => 'Frühere Rückblicke anzeigen';

  @override
  String get recapEmpty =>
      'Hier erscheint ein Rückblick, sobald die Geschichte voranschreitet.';

  @override
  String get chatMessageAsNarrator => 'Als Erzähler schreiben';

  @override
  String chatMessageAsCharacter({required String name}) {
    return 'Als $name schreiben';
  }

  @override
  String get chatNarratorSpeaker => 'der Erzähler';

  @override
  String get chatYourCharacterSpeaker => 'dein Charakter';

  @override
  String chatSpeakingAs({required String speaker}) {
    return 'Du sprichst als $speaker';
  }

  @override
  String get chatSwitchCharacter => 'Zum Charakter wechseln';

  @override
  String get chatSwitchNarration => 'Zur Erzählung wechseln';

  @override
  String chatOpenLocation({required String locationName}) {
    return '$locationName öffnen';
  }

  @override
  String get chatRetryMessage => 'Nachricht erneut senden';

  @override
  String get blockedReportFailed =>
      'Der Nutzer wurde blockiert, aber die Meldung ist fehlgeschlagen.';

  @override
  String get storeConnectionFailed =>
      'Verbindung zum Store fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get storeProductUnavailable =>
      'Dieses Produkt ist derzeit nicht verfügbar.';

  @override
  String get storeDevicePurchasesUnavailable =>
      'Auf diesem Gerät sind keine Käufe möglich.';

  @override
  String get worldHistoryRequestFailed =>
      'Weltverlauf konnte nicht geladen werden';

  @override
  String get genericError => 'Ein Fehler ist aufgetreten';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': 'Premium $plan, $price pro Jahr',
      'other': 'Premium $plan, $price pro Monat',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => 'Löschen fehlgeschlagen';

  @override
  String get developerGatewaySignatureFailed =>
      'Gateway-Signaturprüfung fehlgeschlagen';

  @override
  String get developerEndpointsSaved =>
      'Gespeichert. Neue Anfragen verwenden die konfigurierten Endpunkte.';

  @override
  String get developerAdjustRestartRequired =>
      'Starte die App neu, um die Adjust-Umgebung anzuwenden.';

  @override
  String developerRecapSetting({required String mode}) {
    return 'Weltrückblick: $mode';
  }

  @override
  String get developerRecapPreview => 'Vorschau des Weltrückblicks';

  @override
  String get developerRecapPreviewDescription =>
      'Ersetzt vorübergehend den Abo-Status und den Rückblick im Weltbereich. Wird beim Neustart der App zurückgesetzt.';

  @override
  String get developerResetFailed => 'Zurücksetzen fehlgeschlagen';

  @override
  String get developerRecapOff => 'Aus (gemäß Mitgliedschaft)';

  @override
  String get developerRecapLocked => 'Gesperrt · ohne Abo';

  @override
  String get developerRecapEmpty => 'Mit Abo · noch nicht erstellt';

  @override
  String get developerRecapSample => 'Mit Abo · Beispielrückblick';

  @override
  String get developerRecapLive => 'Mit Abo · tatsächlicher Rückblick';

  @override
  String get chatEditFreeUsesExhausted =>
      'Keine kostenlosen Bearbeitungen mehr übrig.';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'Mitgliedschaft: $selection';
  }

  @override
  String get developerMembershipDescription =>
      'Überschreibt vorübergehend den Mitgliedschaftsstatus dieses Kontos auf allen Seiten. Der Server verwendet weiterhin den tatsächlichen Kontostatus. Beim Neustart der App wird die Einstellung zurückgesetzt.';

  @override
  String get developerMembershipOff => 'Aus (tatsächliche Mitgliedschaft)';

  @override
  String get developerMembershipYearly => 'Premium · jährlich';

  @override
  String get developerMembershipMonthly => 'Premium · monatlich';

  @override
  String get developerMembershipNone => 'Keine Mitgliedschaft';

  @override
  String get originStartBySelectingRole => 'Wähle zuerst deine Figur';

  @override
  String originRecommendedStart({required String locationName}) {
    return 'Empfohlener Start: $locationName';
  }

  @override
  String get originStoryOpening => 'Beginn der Geschichte';

  @override
  String get originOpeningLocation => 'Startort';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names sind jetzt in\n$locationName',
      one: '$names ist jetzt in\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return 'Beginn der Geschichte\n$locationName';
  }

  @override
  String get chatCharacterMovement => 'Figurenbewegung';
}

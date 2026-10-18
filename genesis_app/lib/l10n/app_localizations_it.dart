// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get imageGifUnsupported => 'Le animazioni GIF non sono supportate.';

  @override
  String get worldProgressComplete => 'Avanzamento completato';

  @override
  String a11ySwitchMode({required String label}) {
    return 'Passa alla modalità $label';
  }

  @override
  String a11yEditItem({required String title}) {
    return 'Modifica $title';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return 'Scheda ruolo $index di $count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'Modifica ispirazione $index';
  }

  @override
  String a11yInsert({required String label}) {
    return 'Inserisci $label';
  }

  @override
  String get a11yMembership => 'Abbonamento';

  @override
  String get a11yOpenWorldo => 'Apri Worldo';

  @override
  String get a11yFilterGender => 'Filtra per genere';

  @override
  String get a11ySelectRole => 'Scegli il tuo ruolo';

  @override
  String get a11yLoadingMap => 'Caricamento della mappa';

  @override
  String get a11yBuildingWorld => 'Creazione del mondo';

  @override
  String get a11yPremiumMembership => 'Abbonamento Premium';

  @override
  String get a11yProMembership => 'Abbonamento Pro';

  @override
  String get a11yRecommendedRole => 'Ruolo consigliato';

  @override
  String get a11yLastMessage => 'Ultimo messaggio';

  @override
  String get a11yRecentChat => 'Chat recente';

  @override
  String get a11yAiReplyLoading => 'Caricamento della risposta AI';

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
      other: 'giocatori',
      one: 'giocatore',
      zero: 'giocatori',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (Aggiunti / Massimo)';
  }

  @override
  String get createSixHours => '6 ore';

  @override
  String get createTwelveHours => '12 ore';

  @override
  String get createOneDay => '1 giorno';

  @override
  String get createOneWeek => '1 settimana';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get languageChangeFailed => 'Impossibile cambiare lingua. Riprova.';

  @override
  String get purchasingGems => 'Acquisto di gemme in corso';

  @override
  String get purchaseSuccessful => 'Acquisto riuscito!';

  @override
  String get okAction => 'OK';

  @override
  String get cancelAction => 'Annulla';

  @override
  String get requestAction => 'Richiedi';

  @override
  String get requestedStatus => 'Richiesta inviata';

  @override
  String get launchAction => 'Avvia';

  @override
  String get tickNowAction => 'Tick ora';

  @override
  String get writePostHint => 'Scrivi un post';

  @override
  String get newPostTitle => 'Nuovo post';

  @override
  String get aiIsGenerating => 'L’AI sta generando';

  @override
  String get generatingCustomizedWorldWait =>
      'Stiamo creando un mondo vivo e personalizzato per te.\nAttendi un momento.';

  @override
  String get approvedStatus => 'Approvato';

  @override
  String get rejectedStatus => 'Rifiutato';

  @override
  String get awaitingApprovalStatus => 'In attesa di approvazione';

  @override
  String get awaitingYourApprovalStatus => 'In attesa della tua approvazione';

  @override
  String get liveYourWorld => 'VIVI IL TUO MONDO';

  @override
  String get signedOutMeDescription =>
      'Gioca nei mondi, crea worldo, invita gli amici\ne continua le tue avventure ovunque.';

  @override
  String get gemTaskLaunchWorldHint =>
      'Apri un Worldo che ti piace, poi avvia il tuo mondo.';

  @override
  String get gemTaskInviteFriendHint =>
      'Apri un mondo, poi tocca Invita nel pannello dei dettagli.';

  @override
  String get gemTaskWriteCommentHint =>
      'Apri un Worldo che ti piace, poi scrivi un post in Discussione.';

  @override
  String get gemTaskRequestJoinHint =>
      'Apri un mondo a cui non partecipi, poi chiedi di unirti.';

  @override
  String get gemTaskSendMessageHint => 'Invia messaggi nel tuo mondo.';

  @override
  String get gemTaskProgressWorldHint =>
      'Apri un mondo in cui giochi, poi tocca Tick ora.';

  @override
  String get termsOfService => 'Termini di servizio';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'Mondo';

  @override
  String get userLabel => 'Utente';

  @override
  String get meLabel => 'Io';

  @override
  String get locationLabel => 'Luogo';

  @override
  String get allLabel => 'Tutti';

  @override
  String get maleLabel => 'Uomo';

  @override
  String get femaleLabel => 'Donna';

  @override
  String get nonBinaryLabel => 'Non binario';

  @override
  String get forYouLabel => 'Per te';

  @override
  String get userBlocked => 'Utente bloccato';

  @override
  String get purchaseCanceled => 'Acquisto annullato.';

  @override
  String get purchasePending => 'Il tuo acquisto è in sospeso.';

  @override
  String get purchaseConfirmationDelayed =>
      'La conferma dell’acquisto è in ritardo. Controlla di nuovo più tardi.';

  @override
  String get purchaseFailed => 'Acquisto non riuscito.';

  @override
  String get yearlyPlan => 'Annuale';

  @override
  String get monthlyPlan => 'Mensile';

  @override
  String get proSubscriptionTagline =>
      'Esplora più a fondo ogni Worldo in cui giochi.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, fatturati annualmente';
  }

  @override
  String expiresOn({required String date}) {
    return 'Scade il $date';
  }

  @override
  String get activeStatus => 'ATTIVO';

  @override
  String get expiredStatus => 'Scaduto';

  @override
  String updatedAt({required String timestamp}) {
    return 'Aggiornato $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => 'Caricamento non riuscito. Riprova';

  @override
  String get loadMoreAction => 'Carica altro';

  @override
  String get gemPurchaseRecord => 'Acquisto di gemme';

  @override
  String get taskRewardRecord => 'Ricompensa attività';

  @override
  String get worldProgressRecord => 'Avanzamento del mondo';

  @override
  String get directMessageRecord => 'Messaggio diretto';

  @override
  String get gemRecord => 'Movimento gemme';

  @override
  String get runATickTask => 'Esegui un Tick';

  @override
  String get runATickTaskDescription =>
      'Apri un mondo in cui giochi e tocca Tick ora.';

  @override
  String get someoneFallback => 'Qualcuno';

  @override
  String get aCharacterFallback => 'un personaggio';

  @override
  String get thisWorld => 'questo mondo';

  @override
  String get noWorldEventsYet => 'Ancora nessun evento nel mondo.';

  @override
  String get globalLabel => 'Globale';

  @override
  String get eventLabel => 'Evento';

  @override
  String get characterDestinations => 'Destinazioni dei personaggi';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName $direction $locationName';
  }

  @override
  String get cameToDirection => 'arriva a';

  @override
  String get wentToDirection => 'va a';

  @override
  String get hasComeToDirection => 'arriva a';

  @override
  String get hasGoneToDirection => 'va a';

  @override
  String get waitForReplyToSendMore =>
      'Attendi una risposta prima di inviare altri messaggi';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi messaggi',
      one: '$count nuovo messaggio',
      zero: '$count nuovi messaggi',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation => 'Seleziona un ruolo predefinito';

  @override
  String get enterNameValidation => 'Inserisci un nome';

  @override
  String get enterIdentityValidation => 'Inserisci un’identità';

  @override
  String get waitForProfileLoading =>
      'Attendi che il profilo finisca di caricarsi.';

  @override
  String get imageUploadFailed => 'Caricamento dell’immagine non riuscito.';

  @override
  String get photoAccessDenied => 'Accesso alle foto negato';

  @override
  String get feedbackSubmitted => 'Feedback inviato';

  @override
  String get feedbackFailed => 'Invio del feedback non riuscito';

  @override
  String get worldoDetailUnavailable =>
      'I dettagli del Worldo non sono disponibili.';

  @override
  String get publishAction => 'Pubblica';

  @override
  String get publishingStatus => 'Pubblicazione in corso...';

  @override
  String get publishFailed => 'Pubblicazione non riuscita';

  @override
  String get publishChangesBeforeLeaving =>
      'Pubblicare le modifiche prima di uscire?';

  @override
  String get noChangesToPublish => 'Nessuna modifica da pubblicare.';

  @override
  String get completeOpeningRequiredToPublish =>
      'Per pubblicare è necessaria un’apertura completa';

  @override
  String get publishResponseMissingOriginId =>
      'La pubblicazione non ha restituito un ID Worldo.';

  @override
  String get worldoIdRequired => 'È richiesto un ID Worldo.';

  @override
  String loadFailedWithReason({required String reason}) {
    return 'Caricamento non riuscito: $reason';
  }

  @override
  String get imageSelectionFailed => 'Selezione dell’immagine non riuscita';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID: $oid\nUltima versione: $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID: $wid\nProprietario: $owner';
  }

  @override
  String get sendFailed => 'Invio non riuscito';

  @override
  String get selectARole => 'Seleziona un ruolo';

  @override
  String get timeLabel => 'Ora';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID: $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID: $oid · Creatore: $creator';
  }

  @override
  String get worldoMetricExplanation =>
      'Questo worldo aggiorna {Nome indicatore} di ogni personaggio a ogni avanzamento, espresso in {Unità}. Ogni personaggio parte da {Valore iniziale} e il valore può variare tra {Variazione min.} e {Variazione max.}.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return 'Avvia un $worldo per generare\nil tuo mondo';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return 'Costo stimato del prossimo messaggio: $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount gemme';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'Elimina il mondo $worldName';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername interpreta $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName avviato!';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName creato!';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName pubblicato!';
  }

  @override
  String get createTimeout => 'Tempo scaduto per la creazione del Worldo.';

  @override
  String get publishTimeout => 'Tempo scaduto per la pubblicazione del Worldo';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return 'Hai richiesto di unirti a $worldName$worldId';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge ha richiesto di unirsi a $worldName$worldId';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge ha commentato il tuo worldo';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge ti ha risposto';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge ha messo Mi piace al tuo commento';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge ti ha inviato un messaggio';
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
    return 'Utilizzi gratuiti di Ispirazione rimasti: $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Modifiche gratuite rimaste: $remaining\n$action';
  }

  @override
  String get getMoreAction => 'Ottieni di più >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName arriva a $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldo ti permette di creare, scoprire ed esplorare mondi alimentati dall’AI, popolati di personaggi, storie ed eventi in evoluzione. Chatta con personaggi AI, gioca con gli amici e fai avanzare ogni mondo attraverso scene e scelte coinvolgenti.\n\nLa nostra app offre un nuovo modo di vivere le storie interattive: come parte del mondo. Per qualsiasi domanda, contattaci all’indirizzo $contactEmail.';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy, $termsOfUse e $endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return 'Continuando, accetti i nostri $terms, la nostra $privacyPolicy e il nostro $endUserLicenseAgreement';
  }

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get terms => 'Termini';

  @override
  String get termsOfUse => 'Termini di utilizzo';

  @override
  String get endUserLicenseAgreement =>
      'Contratto di licenza con l’utente finale';

  @override
  String existingAccountSignIn({required String signIn}) {
    return 'Hai già un account? $signIn';
  }

  @override
  String get signInAction => 'Accedi.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return 'Sono state assegnate $gemIcon$grantedAmount gemme.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return 'Fino a $amount gemme al mese e accesso Premium completo.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /giorno';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/mese';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: Risposta a $replyToName$replyToBadge: $content';
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
  String get navHome => 'Home';

  @override
  String get navWorldo => 'Worldo';

  @override
  String get navCreate => 'Create';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navMe => 'Me';

  @override
  String get homeLoadFailed => 'Caricamento non riuscito';

  @override
  String get homeRetry => 'Riprova';

  @override
  String get homeEmptyDescription =>
      'Worldo è il modello. Avvialo per creare un mondo vivo da esplorare e far crescere.';

  @override
  String get homeWorldCharacter => 'Personaggio';

  @override
  String get homeWorldSingleOtherPlayer => '· 1 altro giocatore';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· $otherPlayerCount altri giocatori';
  }

  @override
  String get homeSignInUnavailable => 'Accesso non disponibile';

  @override
  String get homeSignedOutTitle => 'Tutti i tuoi mondi in un unico posto';

  @override
  String get homeSignedOutDescription =>
      'Accedi per creare mondi e continuare le tue storie.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return 'Proprietario: $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID: $oid  Creatore: $originator\nSintesi: $brief\nUltima versione: $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID: $wid\nProprietario: $owner';
  }

  @override
  String get searchHistory => 'Cronologia ricerche';

  @override
  String get searchFailed => 'Ricerca non riuscita';

  @override
  String get searchNoResults => 'Nessun risultato.';

  @override
  String get searchCancel => 'Annulla';

  @override
  String get searchHint => 'Worldo, personaggio, tag';

  @override
  String get worldDetailOnlyWorldsLaunched =>
      'Puoi eliminare solo i mondi che hai avviato da solo.';

  @override
  String get worldDetailDelete => 'Elimina';

  @override
  String get worldDetailNoCharacterStatusYet =>
      'Ancora nessuno stato dei personaggi.';

  @override
  String get worldDetailNoCharactersYet => 'Ancora nessun personaggio.';

  @override
  String get worldDetailProgressingWorld => 'Avanzamento del mondo in corso';

  @override
  String get worldDetailCompressingRecent =>
      'Compressione dei ricordi recenti\nAvanzamento della cronologia del mondo\nGenerazione del prossimo sviluppo della storia\nAggiornamento dei luoghi dei personaggi';

  @override
  String get worldModelsDetail => 'Dettagli';

  @override
  String get worldModelsLocations => 'Luoghi';

  @override
  String get worldModelsEvents => 'Eventi';

  @override
  String get worldModelsStatus => 'Stato';

  @override
  String get worldDetailUnavailable => 'Non disponibile';

  @override
  String worldActionFailed({required String actionLabel}) {
    return 'Operazione non riuscita: $actionLabel';
  }

  @override
  String get worldDetailRequestJoinWorld =>
      'Richiedere di unirti a questo mondo?';

  @override
  String get worldDetailRequest => 'Richiedi';

  @override
  String get worldDetailLaunchFailed => 'Avvio non riuscito';

  @override
  String get worldDetailNoSavedProfileFound => 'Nessun profilo salvato trovato';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return 'Worldo di origine: $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => 'Invita';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Unisciti al mio mondo «$worldName» su Worldo!\n$wid\nCerca questo WID su Worldo per trovarlo e unirti.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'Sintesi del mondo';

  @override
  String get worldDetailCast => 'Cast';

  @override
  String get worldDetailLinkCopiedShare =>
      'Link copiato. Condividilo con i tuoi amici.';

  @override
  String get worldMapAction => 'Mappa';

  @override
  String get worldInfoAction => 'Info';

  @override
  String worldLocationCount({required String pointsCount}) {
    return 'Luoghi ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => 'Giocatore';

  @override
  String worldDetailGoal({required String goal}) {
    return 'Obiettivo: $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet =>
      'Ancora nessun dettaglio sui personaggi.';

  @override
  String get worldDetailNoEventsYet => 'Ancora nessun evento.';

  @override
  String get worldDetailLoadEventsFailed =>
      'Caricamento degli eventi non riuscito.';

  @override
  String homeLocationID({required String id}) {
    return 'Luogo $id';
  }

  @override
  String get homeBuildingWorld => 'CREAZIONE DEL MONDO';

  @override
  String get worldMapLoadFailed => 'Caricamento della mappa non riuscito';

  @override
  String get worldMapZoomIn => 'Ingrandisci la mappa';

  @override
  String get worldMapZoomOut => 'Riduci la mappa';

  @override
  String get worldDetailGlobal => 'Globale';

  @override
  String get worldDetailLocation => 'Luogo';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => 'Generazione del primo Tick';

  @override
  String get worldFirstTickStatusLoadFailed =>
      'Impossibile caricare lo stato della generazione.';

  @override
  String get worldDetailNew => 'Nuovo';

  @override
  String get homeUnknownLocation => 'Luogo sconosciuto';

  @override
  String get homeUnknownCharacter => 'Personaggio sconosciuto';

  @override
  String get homeNewPlaceEmerged => 'È apparso un nuovo luogo';

  @override
  String get homeNewCharacterAppeared => 'È apparso un nuovo personaggio';

  @override
  String get chatLocationUnavailable => 'Il luogo non è disponibile';

  @override
  String get chatRequestApprovalLaunch => 'Richiedi l’approvazione per avviare';

  @override
  String get chatLoading => 'Caricamento';

  @override
  String get chatQuotaCheckFailed =>
      'Impossibile verificare gli utilizzi gratuiti. Riprova.';

  @override
  String get chatInspirationSourceChanged =>
      'La fonte dell’ispirazione è cambiata. Riapri Ispirazione.';

  @override
  String get chatInspiration => 'Ispirazione';

  @override
  String get chatMessageCannotSend =>
      'Questo messaggio non può più essere inviato';

  @override
  String get chatMessageEmpty => 'Il messaggio è vuoto';

  @override
  String get chatConnectionFailed => 'Impossibile connettersi a questa chat';

  @override
  String get chatReplyChangedSelect =>
      'La risposta è cambiata. Seleziona di nuovo l’ispirazione.';

  @override
  String get chatSendConfirmFailed =>
      'Impossibile confermare l’invio del messaggio';

  @override
  String get chatNoNetworkConnection => 'Nessuna connessione di rete';

  @override
  String get chatRoundCannotContinue => 'Questo turno non può continuare';

  @override
  String get chatSourceRoundChanged => 'Il turno di origine è cambiato';

  @override
  String get chatGo => 'Continua';

  @override
  String get chatReplyActionUnavailable =>
      'Questa azione sulla risposta non è più disponibile';

  @override
  String get chatRegenerateFailure => 'Rigenerazione non riuscita';

  @override
  String get chatGoFailure => 'Continuazione non riuscita';

  @override
  String get chatEditFailure => 'Modifica non riuscita';

  @override
  String get chatInspirationFailure => 'Ispirazione non riuscita';

  @override
  String get chatJoinLocationFailed => 'Impossibile unirsi a questo luogo';

  @override
  String get chatInactive => 'Questa chat non è più attiva';

  @override
  String get chatChatroomUnavailable => 'La stanza di chat non è disponibile';

  @override
  String get chatFailedConfirmReplyAction =>
      'Impossibile confermare l’azione sulla risposta';

  @override
  String get chatLeastOneMessageMustRemain =>
      'Deve rimanere almeno un messaggio.';

  @override
  String get chatReplyNotEditable => 'Questa risposta non è modificabile';

  @override
  String get chatReplyAlreadyFixed => 'Questa risposta è stata fissata';

  @override
  String get chatReplyEditorFrozen => 'L’editor della risposta è bloccato';

  @override
  String get chatResolvePreviousSaveBefore =>
      'Completa il salvataggio precedente prima di modificarne la bozza';

  @override
  String get chatStaleReplyEditor => 'L’editor della risposta non è aggiornato';

  @override
  String get chatPreviousSaveResultUncertain =>
      'L’esito del salvataggio precedente è incerto; ricarica prima di modificare di nuovo';

  @override
  String get chatCandidateMissing => 'La proposta non esiste più';

  @override
  String get chatBatchSupportsMost100Changes =>
      'Un batch supporta al massimo 100 modifiche';

  @override
  String get chatMissingStableMessageIdentity =>
      'Manca un identificativo stabile del messaggio';

  @override
  String get chatEditTargetHasChanged =>
      'La destinazione della modifica è cambiata';

  @override
  String get chatMessageNotEditable =>
      'Questo messaggio non può essere modificato';

  @override
  String get chatReplyNoLongerEditable =>
      'Questa risposta non può più essere modificata';

  @override
  String get chatEditorOpenFailed => 'Impossibile aprire l’editor';

  @override
  String get chatInactiveDuringEdit => 'Questa chat non è più attiva.';

  @override
  String get chatEditMessage => 'Modifica messaggio';

  @override
  String get chatSave => 'Salva';

  @override
  String get chatEdit => 'Modifica';

  @override
  String get chatRegenerate => 'Rigenera';

  @override
  String get chatRegenerateUnavailable =>
      'Questo turno non può essere rigenerato';

  @override
  String get chatGenerate10Replies => 'Puoi generare fino a 10 risposte.';

  @override
  String get chatPreviousReply => 'Risposta precedente';

  @override
  String get chatNextReply => 'Risposta successiva';

  @override
  String get chatCopy => 'Copia';

  @override
  String get chatReport => 'Segnala';

  @override
  String get chatCopied => 'Copiato';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi messaggi',
      one: '$count nuovo messaggio',
      zero: '$count nuovi messaggi',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'Menziona';

  @override
  String get chatCharacters => 'Personaggi';

  @override
  String get chatNoCharacters => 'Nessun personaggio';

  @override
  String get chatNoLocations => 'Nessun luogo';

  @override
  String get chatHere => 'Qui';

  @override
  String get chatLoadEarlierMessages => 'Carica messaggi precedenti';

  @override
  String get chatText => 'Scrivi un messaggio...';

  @override
  String get chatLocationRoster => 'TU';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'Tutti i contenuti sono generati dall’AI e fittizi. Qualsiasi somiglianza con persone, eventi o luoghi reali è casuale.';

  @override
  String get homeRecent => 'Recenti';

  @override
  String get worldoUnableSavePreference =>
      'Impossibile salvare la tua preferenza. Riprova.';

  @override
  String get worldoFilterGender => 'Filtra per genere';

  @override
  String get worldoNoData => 'Nessun dato';

  @override
  String get worldoAll => 'Tutti';

  @override
  String get worldoDetailSelectRole => 'Scegli il tuo ruolo';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'Creatore: $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Modifica Worldo';

  @override
  String get worldoDetailWorldoBrief => 'Sintesi del Worldo';

  @override
  String get worldoDetailNewPost => 'Nuovo post';

  @override
  String get worldoDetailWritePost => 'Scrivi un post';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'Discussione ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => 'Mostra tutto >';

  @override
  String get worldoDetailPlayingWorld => 'Mondo in corso';

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
    return 'Personaggi ($length)';
  }

  @override
  String get worldoSend => 'Invia';

  @override
  String get worldoPostFailed => 'Pubblicazione del post non riuscita';

  @override
  String get worldoImageUploadFailed =>
      'Caricamento dell’immagine non riuscito';

  @override
  String get worldoLoadRepliesFailed =>
      'Caricamento delle risposte non riuscito';

  @override
  String get worldoWriteReply => 'Scrivi una risposta';

  @override
  String worldoReplyName({required String replyToName}) {
    return 'Rispondi a $replyToName';
  }

  @override
  String get worldoPostDetail => 'Dettagli del post';

  @override
  String get worldoPostUnavailable => 'Post non disponibile';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'Tutte le risposte $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return 'Mostra tutte le $replyCount risposte';
  }

  @override
  String get worldoLikeFailed => 'Impossibile mettere Mi piace';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return 'Mostra tutte le $replyCount risposte';
  }

  @override
  String get worldoUser => 'Utente';

  @override
  String get worldoViewMore => 'Mostra altro >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'Discussione ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return 'Mostra tutte le $remainingReplyCount risposte';
  }

  @override
  String get worldoReply => 'Rispondi';

  @override
  String get worldoDiscussTitle => 'Discussione';

  @override
  String get worldoLaunchLocationComesLife =>
      'Questo luogo prende vita dopo l’avvio.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      'Avvia questo Worldo per esplorare e interagire qui.';

  @override
  String get worldoLaunchRoleUnavailable =>
      'Questo ruolo non è più disponibile';

  @override
  String get worldoLaunchSelectRole => 'Scegli il tuo ruolo';

  @override
  String get worldoLaunchProfile => 'Il tuo profilo';

  @override
  String get worldoLaunchDone => 'Fine';

  @override
  String get worldoLaunchSuggested => 'Consigliati';

  @override
  String get worldoLaunchName => 'Nome';

  @override
  String get worldoLaunchIdentity => 'Identità';

  @override
  String get worldoLaunchPersonality => 'Personalità';

  @override
  String get worldoLaunchGoal => 'Obiettivo';

  @override
  String get worldoLaunchSetupRole => 'Configura il tuo ruolo';

  @override
  String get worldoLaunchPreset => 'Predefinito';

  @override
  String get worldoLaunchCustom => 'Personalizzato';

  @override
  String get worldoLaunchNoPresetRole => 'Nessun ruolo predefinito';

  @override
  String get worldoLaunchFilling => 'Compilazione...';

  @override
  String get worldoLaunchFillMyProfile => 'Compila dal mio profilo';

  @override
  String get worldoLaunchLaunch => 'Avvia';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName avviato!';
  }

  @override
  String get worldoLaunchEnter => 'Entra';

  @override
  String get createAction => 'Crea';

  @override
  String get createWorldoTitle => 'Crea Worldo';

  @override
  String get createFailed => 'Creazione non riuscita';

  @override
  String get createNotesRequired =>
      'Per pubblicare sono richieste le note di aggiornamento.';

  @override
  String get createActionInProgress => 'Questa azione è già in corso.';

  @override
  String createCurrentVersion({required String version}) {
    return 'Versione attuale: $version';
  }

  @override
  String get createChecking => 'Verifica...';

  @override
  String createSummaryName({required String name}) {
    return 'Nome Worldo: $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Sintesi Worldo: $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'Immagine di copertina: $status';
  }

  @override
  String get createNotUploaded => 'Non caricata';

  @override
  String get createUploaded => 'Caricata';

  @override
  String createSummarySettings({required String settings}) {
    return 'Impostazioni Worldo: $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Tempo Worldo: $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Indicatore Worldo: $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '$count giorno',
      zero: '$count giorni',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 personaggi';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personaggi: $names',
      one: '1 personaggio: $names',
      zero: '0 personaggi: $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'Consigliato: $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · Regione: $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · Edificio: $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · Stanza: $count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventi',
      one: '1 evento',
      zero: '$count eventi',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return 'Dialoghi dei personaggi: $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'Narratore: $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return 'Immagine: $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return 'Eliminare $itemLabel?';
  }

  @override
  String get createItemHasContentDeleteAnyway =>
      'Questo elemento contiene contenuti. Eliminarlo comunque?';

  @override
  String get createImageUploadProgress =>
      'Il caricamento dell’immagine è in corso.';

  @override
  String get createBasicsBasics => 'Informazioni di base';

  @override
  String get createSaveInProgress => 'Il salvataggio è già in corso.';

  @override
  String get createRequiredBeforeSave =>
      'Completa tutti i campi obbligatori prima di salvare.';

  @override
  String get createOpeningOpening => 'Apertura';

  @override
  String get createCharacterCharactersCreate =>
      'Personaggi: crea almeno un personaggio.';

  @override
  String get createCharacterCharactersOnlyOne =>
      'Personaggi: è possibile consigliare un solo personaggio.';

  @override
  String get createBasicsBasicsWorldoName =>
      'Informazioni di base: il nome Worldo è obbligatorio.';

  @override
  String get createBasicsBasicsWorldoBrief =>
      'Informazioni di base: la sintesi del Worldo è obbligatoria.';

  @override
  String get createBasicsBasicsCoverImage =>
      'Informazioni di base: l’immagine di copertina è obbligatoria.';

  @override
  String get createBasicsBasicsMetricMust =>
      'Informazioni di base: l’indicatore deve essere un JSON valido.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'Personaggio #$characterIndex: il nome è obbligatorio.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'Personaggio #$characterIndex: l’identità è obbligatoria.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'Personaggio #$characterIndex: la personalità è obbligatoria.';
  }

  @override
  String get createCharacterCharactersLeast =>
      'Personaggi: è richiesto almeno un personaggio.';

  @override
  String get createLocationLocationsCreate => 'Luoghi: crea almeno un luogo.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return 'Luogo #$locationIndex: il nome del luogo è obbligatorio.';
  }

  @override
  String get createOpeningOpeningSelect =>
      'Apertura: seleziona un luogo e completa ogni elemento del dialogo.';

  @override
  String get createOpeningOpeningSelected =>
      'Apertura: il luogo selezionato non è più disponibile.';

  @override
  String get createOpeningCharacterOpening =>
      'Apertura: un personaggio selezionato non è più disponibile.';

  @override
  String get createOpeningOpeningDialogue =>
      'Apertura: un personaggio del dialogo non si trova nel luogo selezionato. Apri Apertura per correggerlo.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return 'Dialogo di apertura non supportato: $type';
  }

  @override
  String get createCreating => 'Creazione...';

  @override
  String get createDiscard => 'Scarta';

  @override
  String get createCharactersStep => 'Personaggi (>=1)';

  @override
  String get createLocationsStep => 'Luoghi (>=1)';

  @override
  String get createStoryEventsOptional => 'Eventi della storia (facoltativo)';

  @override
  String get createUpdateNotesRequiredPublish =>
      'Note di aggiornamento (richieste per pubblicare)';

  @override
  String get createWhatChangedVersion => 'Cosa è cambiato in questa versione?';

  @override
  String get createView => 'Visualizza';

  @override
  String get createNotStartedYet => 'Non ancora iniziato';

  @override
  String get createEdited => 'Modificato';

  @override
  String get createPublishingWorldo => 'Pubblicazione del tuo Worldo';

  @override
  String get createCreatingWorldo => 'Creazione del tuo Worldo';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Preparazione degli aggiornamenti del tuo Worldo.\nAttendi un momento.';

  @override
  String get createBringingWorldoLifeWait =>
      'Il tuo Worldo sta prendendo vita.\nAttendi un momento.';

  @override
  String get createDescribeIssue => 'Descrivi il problema';

  @override
  String get createSubmit => 'Invia';

  @override
  String get createBasicsWorldoName => 'Nome Worldo *';

  @override
  String get createBasicsNameRequired => 'Il nome Worldo è obbligatorio.';

  @override
  String get createBasicsBriefRequired =>
      'La sintesi del Worldo è obbligatoria.';

  @override
  String get createBasicsCoverRequired =>
      'L’immagine di copertina è obbligatoria.';

  @override
  String get createBasicsMetricInvalid =>
      'L’indicatore deve essere un JSON valido.';

  @override
  String get createBasicsEgMainStreet => 'es. Via Principale';

  @override
  String get createBasicsWorldoBrief => 'Sintesi del Worldo *';

  @override
  String get createBasicsBriefNote =>
      'La presentazione pubblica che i giocatori vedono per prima: ambientazione, conflitto centrale e ciò che suscita interesse.';

  @override
  String get createBasicsHiddenNote =>
      'Regole nascoste e retroscena che guidano la storia: intenzioni, meccaniche e limiti segreti.';

  @override
  String get createBasicsEgHalfShopsMain =>
      'es. Metà dei negozi di Via Principale è sbarrata. Entro la Festa del Lavoro, il negoziante più ricco possiederà la città.';

  @override
  String get createBasicsCoverImage => 'Immagine di copertina *';

  @override
  String get createBasicsUpload => 'Carica';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'Usata nelle schede e nelle pagine dei dettagli. Consigliati circa 768×1024 px. Formati supportati: JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden =>
      'Impostazioni Worldo — nascoste (facoltativo)';

  @override
  String get createBasicsEgBankerSecretly =>
      'es. Il banchiere decide in segreto chi ottiene prestiti; chi si espone troppo può essere estromesso.';

  @override
  String get createBasicsWorldoTimeOptional => 'Tempo Worldo (facoltativo)';

  @override
  String get createBasicsWorldoStartsStart =>
      'Questo worldo inizia a {Ora di inizio}; ogni volta che l’utente tocca *avanza*, la cronologia progredisce di {Tempo per avanzamento}.';

  @override
  String get createBasicsStartTime => 'Ora di inizio';

  @override
  String get createBasicsDateExample => 'es. Giorno 1, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => 'Tempo per avanzamento';

  @override
  String get createBasicsEg8Hours3Days => 'es. 8 ore / 3 giorni';

  @override
  String get createBasicsWorldoMetricOptional =>
      'Indicatore Worldo (facoltativo)';

  @override
  String get createBasicsMetricLabel => 'Nome indicatore';

  @override
  String get createBasicsEgWealthGoalProgress =>
      'es. Ricchezza / Avanzamento obiettivo';

  @override
  String get createBasicsLabelNote => 'Nota sull’indicatore';

  @override
  String get createBasicsDescribeWhatMetric =>
      'Descrivi cosa misura questo indicatore';

  @override
  String get createBasicsUnit => 'Unità';

  @override
  String get createBasicsEgCoins => 'es. monete / %';

  @override
  String get createBasicsRange => 'Intervallo valori';

  @override
  String get createBasicsStarting => 'Valore iniziale';

  @override
  String get createBasicsDeltaMin => 'Variazione min.';

  @override
  String get createBasicsDeltaMax => 'Variazione max.';

  @override
  String get createBasicsSaving => 'Salvataggio...';

  @override
  String get createBasicsAdvancedSettings =>
      'Impostazioni avanzate (facoltativo)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'Personaggio $index';
  }

  @override
  String get createCharacterSuggest => 'Consiglia';

  @override
  String get createCharacterAvatarOptional => 'AVATAR\n(facoltativo)';

  @override
  String get createCharacterName => 'Nome *';

  @override
  String get createCharactersTitle => 'Personaggi';

  @override
  String createCharacterLimit({required int count}) {
    return 'Puoi aggiungere fino a $count personaggi.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'Personaggio $index: il nome è obbligatorio.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'Personaggio $index: l’identità è obbligatoria.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'Personaggio $index: la personalità è obbligatoria.';
  }

  @override
  String get createCharacterMinOne => 'Crea almeno un personaggio.';

  @override
  String get createCharacterEnterName => 'Inserisci il nome...';

  @override
  String get createCharacterIdentity => 'Identità *';

  @override
  String get createCharacterEgHometownKidBack =>
      'es. Un ragazzo del posto tornato per una vera occasione';

  @override
  String get createCharacterPersonality => 'Personalità *';

  @override
  String get createCharacterEgUnderdog =>
      'es. Uno sfavorito di buon cuore ma con poco capitale';

  @override
  String get createCharacterGoalOptional => 'Obiettivo (facoltativo)';

  @override
  String get createCharacterEgRichestOwner =>
      'es. Diventare il proprietario più ricco di Via Principale entro la Festa del Lavoro';

  @override
  String get createCharacterBackgroundHidden =>
      'Retroscena — nascosto (facoltativo)';

  @override
  String get createCharacterEgLeftTownYears =>
      'es. Lasciata la città anni fa, torna in una Via Principale sbarrata per cogliere un’occasione.';

  @override
  String get createCharacterAddCharacter => '+ Aggiungi personaggio';

  @override
  String get createLocationImageOptional => 'IMMAGINE\n(facoltativo)';

  @override
  String get createCharacterSelectAvailable =>
      'Seleziona tra i personaggi disponibili qui sotto';

  @override
  String get createCharacterInitialCharacters =>
      'Personaggi iniziali (facoltativo)';

  @override
  String get createLocationStartingCharacters =>
      'I personaggi presenti qui all’inizio del worldo.';

  @override
  String get createCharacterAvailableSelect => 'Disponibili per la selezione';

  @override
  String get createCharacterNoCharactersYet =>
      'Ancora nessun personaggio. Crea prima i personaggi, poi scegli dove iniziano.';

  @override
  String get createCharacterNoCharacters =>
      'Nessun personaggio disponibile. Tutti hanno già un luogo iniziale.';

  @override
  String get createLocationEveryL2L3Locations =>
      'Verranno rimossi anche tutti i luoghi L2 e L3 al suo interno.';

  @override
  String get createLocationEveryL3Locations =>
      'Verranno rimossi anche tutti i luoghi L3 al suo interno.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return 'Elimina «$displayName»';
  }

  @override
  String get createLocationOpeningLocation =>
      'Questo è il luogo dell’apertura. Eliminandolo verrà cancellata anche l’apertura.';

  @override
  String get createLocationL1LocationRegion => 'Luogo L1 · Regione *';

  @override
  String get createLocationL2LocationBuilding => 'Luogo L2 · Edificio *';

  @override
  String get createLocationAddL3Location => 'Aggiungi luogo L3';

  @override
  String get createLocationsTitle => 'Luoghi';

  @override
  String get createLocationStatisticsNote =>
      'Il tuo mondo ha 3 livelli:\nL1 · Regione     Un’area del mondo — Centro città\nL2 · Edificio   Un edificio al suo interno — Ristorante di Joe\nL3 · Stanza       Una stanza nell’edificio — Cucina sul retro\nOgni luogo richiede tutti e tre i livelli. Fino a 15 stanze in totale.';

  @override
  String get createLocationL1NameNote =>
      'Un’area del mondo: un quartiere, una città, una foresta. Non un singolo edificio.';

  @override
  String get createLocationL2NameNote =>
      'Un edificio in questa regione: un negozio, una scuola, un condominio.';

  @override
  String get createLocationL3NameNote =>
      'Una stanza nell’edificio. Vanno bene anche tetti, cortili e ingressi.';

  @override
  String get createLocationName => 'Nome *';

  @override
  String get createLocationL1NameRequired =>
      'Il nome del luogo L1 è obbligatorio.';

  @override
  String get createLocationL3NameRequired =>
      'Il nome del luogo L3 è obbligatorio.';

  @override
  String get createLocationThisL1 => 'Questo luogo L1';

  @override
  String get createLocationThisL2 => 'Questo luogo L2';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel deve contenere almeno un luogo L2.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel deve contenere almeno un luogo L3.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel contiene un luogo L2 che richiede un nome.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel contiene un luogo L3 che richiede un nome.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'Puoi aggiungere fino a $count luoghi L3.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return 'Hai usato tutte le $count stanze. Eliminane una per aggiungerne un’altra.';
  }

  @override
  String get createLocationAtLeastOneL1 => 'È richiesto almeno un luogo L1.';

  @override
  String get createLocationAddL1 => 'Aggiungi almeno un luogo L1.';

  @override
  String get createLocationMinOne => 'Crea almeno un luogo.';

  @override
  String get createLocationIdRequired => 'Ogni luogo deve avere un ID.';

  @override
  String get createLocationIdUnique => 'Ogni luogo deve avere un ID univoco.';

  @override
  String get createLocationParentInvalid =>
      'Ogni luogo deve avere un elemento padre valido.';

  @override
  String get createLocationFieldsRequired =>
      'Completa tutti i campi obbligatori dei luoghi prima di salvare.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Salvando i luoghi verranno eliminate anche $count bolle di dialogo dell’apertura per i personaggi rimossi.',
      one:
          'Salvando i luoghi verrà eliminata anche 1 bolla di dialogo dell’apertura per i personaggi rimossi.',
      zero:
          'Salvando i luoghi verranno eliminate anche $count bolle di dialogo dell’apertura per i personaggi rimossi.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'Modifica luogo L3';

  @override
  String get createLocationPreview => 'Anteprima';

  @override
  String get createLocationCompleteLocation =>
      'Completa questo luogo o eliminalo.';

  @override
  String get createLocationRemoveCharacter =>
      'Rimuovere il personaggio dal luogo?';

  @override
  String get createLocationRemove => 'Rimuovi';

  @override
  String get createLocationL1Location => 'Luogo L1';

  @override
  String get createLocationL2Location => 'Luogo L2';

  @override
  String get createLocationL3Location => 'Luogo L3';

  @override
  String get createOpeningSelectLocation => 'Seleziona luogo';

  @override
  String get createOpeningNoSavedLocations => 'Nessun luogo salvato';

  @override
  String get createOpeningSelect => 'Seleziona';

  @override
  String get createOpeningSelectLocationFirst => 'Seleziona prima un luogo.';

  @override
  String get createOpeningNoInitialCharacter => 'Nessun personaggio iniziale';

  @override
  String get createOpeningLocationsLoading =>
      'I luoghi sono ancora in caricamento.';

  @override
  String get createOpeningLoadingLocations => 'Caricamento dei luoghi...';

  @override
  String get createOpeningSwitchingLocations =>
      'Cambiare luogo cancellerà il contenuto del dialogo.';

  @override
  String get createOpeningContinue => 'Continua';

  @override
  String get createOpeningAdd10DialogueItems =>
      'Puoi aggiungere fino a 10 elementi di dialogo.';

  @override
  String get settingsUnableSaveSuggestedRole =>
      'Impossibile salvare il ruolo consigliato.';

  @override
  String get createOpeningUnableSaveOpening =>
      'Impossibile salvare l’apertura.';

  @override
  String get createOpeningSelectInitial => 'Seleziona il luogo iniziale';

  @override
  String get createOpeningInitialLocationRequired =>
      'Seleziona un luogo iniziale prima di salvare.';

  @override
  String get createOpeningAddDialogueFirst =>
      'Aggiungi almeno un elemento di dialogo prima di salvare.';

  @override
  String get createOpeningCompleteDialogue =>
      'Completa ogni elemento di dialogo prima di salvare.';

  @override
  String get createOpeningDialogue => 'Dialogo di apertura';

  @override
  String get createOpeningLocationRequired =>
      'Seleziona prima un luogo, poi modifica il dialogo.';

  @override
  String get createOpeningNarrator => 'Narratore';

  @override
  String get createOpeningImage => 'Immagine';

  @override
  String get createOpeningSuggestRoleUser => 'Consiglia un ruolo all’utente';

  @override
  String get createOpeningNoCharacters => 'Nessun personaggio disponibile.';

  @override
  String get createOpeningEnterNarrator => 'Inserisci il dialogo del narratore';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return 'Inserisci il dialogo di $name';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => 'CARICA IMMAGINE';

  @override
  String get createEventAddEvent => '+ Aggiungi evento';

  @override
  String get createStoryEventsTitle => 'Eventi della storia';

  @override
  String createEventLimit({required int count}) {
    return 'Puoi aggiungere fino a $count eventi.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'Evento $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      'es. Una catena nazionale valuta un terreno libero e minaccia di battere i prezzi di tutti i negozi locali.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'Uno sviluppo chiave che l’AI usa per guidare la storia.';

  @override
  String get imageCropUploadFailed => 'Caricamento non riuscito';

  @override
  String get inboxNotifications => 'Notifiche';

  @override
  String get inboxNoNotificationsYet => 'Ancora nessuna notifica.';

  @override
  String get inboxFollowers => 'Follower';

  @override
  String get inboxNewFollowers => 'Nuovi follower';

  @override
  String get inboxNoNewFollowersYet => 'Ancora nessun nuovo follower.';

  @override
  String get inboxComments => 'Commenti';

  @override
  String get inboxNoCommentsYet => 'Ancora nessun commento.';

  @override
  String get inboxPrivateChats => 'Chat private';

  @override
  String get inboxChatFriendsWorldo => 'Chatta con i tuoi amici su Worldo.';

  @override
  String get inboxUnknownUser => 'Utente sconosciuto';

  @override
  String get inboxDirectMessage => 'Messaggio diretto';

  @override
  String get inboxJoinRequest => 'Richiesta di partecipazione';

  @override
  String get inboxApprove => 'Approva';

  @override
  String get inboxReject => 'Rifiuta';

  @override
  String get inboxOk => 'OK';

  @override
  String get inboxReviewFailed => 'Revisione non riuscita';

  @override
  String get inboxLoadMessagesFailed =>
      'Caricamento dei messaggi non riuscito.';

  @override
  String get inboxNewMessage => 'Nuovo messaggio';

  @override
  String get inboxSomeone => 'Qualcuno';

  @override
  String get inboxWorld => 'questo mondo';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name ha richiesto di unirsi a $world$suffix';
  }

  @override
  String get inboxCommentWorldo => ' ha commentato il tuo worldo';

  @override
  String get inboxReply => ' ti ha risposto';

  @override
  String get inboxLikeComment => ' ha messo Mi piace al tuo commento';

  @override
  String get inboxLikedComment => 'ha messo Mi piace al tuo commento';

  @override
  String get inboxComment2LikeComment => 'ha messo Mi piace al tuo commento';

  @override
  String get inboxReplied => 'ti ha risposto';

  @override
  String get inboxYou2Reply => 'ti ha risposto';

  @override
  String get inboxCommentedOrigin => 'ha commentato la tua creazione';

  @override
  String get inboxCommentOrigin => 'ha commentato la tua creazione';

  @override
  String get inboxSentMessage => ' ti ha inviato un messaggio';

  @override
  String get inboxStartedFollowing => ' ha iniziato a seguirti.';

  @override
  String get meFailedOpenDiscord => 'Impossibile aprire Discord';

  @override
  String get meImagePickFailed => 'Selezione dell’immagine non riuscita';

  @override
  String get meUpdateFailed => 'Aggiornamento non riuscito';

  @override
  String get mePlaying => 'In corso';

  @override
  String get meEditName => 'Modifica nome';

  @override
  String get meSignUpReward => 'Registrati e ricevi 250 gemme!';

  @override
  String get loginSignUpReward => 'Registrati e ricevi 250 gemme!';

  @override
  String get meUnknown => 'Sconosciuto';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID: $oid\nUltima versione: $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID: $displayWid\nProprietario: $owner';
  }

  @override
  String get meFollows => 'Seguiti';

  @override
  String meFollowingCount({required String followingCount}) {
    return '$followingCount seguiti';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount follower';
  }

  @override
  String get meNoFollowingYet => 'Non segui ancora nessuno.';

  @override
  String get meNoFollowersYet => 'Ancora nessun follower.';

  @override
  String get meBlockFailed => 'Blocco non riuscito. Riprova.';

  @override
  String get meUserBlockedContentHasReported =>
      'Utente bloccato. Questo contenuto è stato segnalato al team Worldo.';

  @override
  String get meBlockUser => 'Bloccare questo utente?';

  @override
  String get meBlock => 'Blocca';

  @override
  String get meUnblockFailed => 'Sblocco non riuscito. Riprova.';

  @override
  String get meUnblock => 'Sblocca';

  @override
  String get meFollowing => 'Segui già';

  @override
  String get meFollow => 'Segui';

  @override
  String get meMessage => 'Messaggio';

  @override
  String meUID({required String uid}) {
    return 'UID: $uid';
  }

  @override
  String get meNoWorldoCreatedYet => 'Non hai ancora creato nessun Worldo.';

  @override
  String get meNoWorldoYet => 'Ancora nessun Worldo.';

  @override
  String get meNoWorldsCreatedYet => 'Non hai ancora creato nessun mondo.';

  @override
  String get meNoWorldsYet => 'Ancora nessun mondo.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'Gemme rosse';

  @override
  String get gemsPink => 'Gemme rosa';

  @override
  String get gemsTop => 'Ricarica';

  @override
  String get gemsBuy => 'Acquista gemme';

  @override
  String get gemsRecords => 'Cronologia';

  @override
  String get gemsUnableLoad => 'Impossibile caricare le gemme.';

  @override
  String get settingsLogOutAccount => 'Uscire dal tuo account?';

  @override
  String get settingsLogOut => 'Esci';

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String get settings => 'Impostazioni';

  @override
  String get settingsAboutUs => 'Chi siamo';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsBlockedUsers => 'Utenti bloccati';

  @override
  String get settingsJoinDiscord => 'Unisciti a Discord';

  @override
  String get meUserUnblocked => 'Utente sbloccato';

  @override
  String get meNoBlockedUsersYet => 'Ancora nessun utente bloccato.';

  @override
  String get settingsAgreeTermsContinue =>
      'Accetta i nostri termini per continuare.';

  @override
  String get settingsDeleteAccount => 'Eliminare il tuo account?';

  @override
  String get settingsAccountDeletionAgreement =>
      'Accordo per l’eliminazione dell’account';

  @override
  String get settingsEnsureSecurityAccount =>
      'Per garantire la sicurezza del tuo account, leggi le conseguenze della sua eliminazione.\n\nEliminare l’account non equivale a disconnettersi e non è reversibile. I tuoi dati privati, inclusi personaggi creati, cronologia ricerche, chat con i personaggi, preferiti, ricordi, dati di interazione e ordini, verranno eliminati definitivamente e non potranno essere recuperati.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      'Tutte le gemme inutilizzate, acquistate o guadagnate, andranno perse definitivamente. Continuando, vi rinunci volontariamente; l’eliminazione dell’account non dà automaticamente diritto a un rimborso.\n\nAnche tutti i benefici residui dell’abbonamento andranno persi definitivamente e non potranno essere ripristinati. Eliminare l’account non annulla l’abbonamento.';

  @override
  String get settingsIHaveReadAccountDeletion =>
      'Ho letto l’accordo per l’eliminazione dell’account';

  @override
  String get settingsCurrentLoginAccount => 'Account attualmente connesso:';

  @override
  String get profileSaveFailed =>
      'Impossibile salvare il tuo profilo. Riprova.';

  @override
  String get meSignInFailed => 'Accesso non riuscito. Riprova.';

  @override
  String get meCompleteProfileContinue =>
      'Completa il tuo profilo per continuare.';

  @override
  String get meSelectGenderAge => 'Seleziona il tuo genere e la tua età.';

  @override
  String get meSelectGender => 'Seleziona il tuo genere.';

  @override
  String get meSelectAge => 'Seleziona la tua età.';

  @override
  String get meRequired => 'Obbligatorio';

  @override
  String get mePersonalizeWorldoExperience =>
      'Personalizza la tua esperienza Worldo';

  @override
  String get meSignIn => 'Accedi';

  @override
  String get meBack => 'Indietro';

  @override
  String get meSkip => 'Salta';

  @override
  String get meContinueGoogle => 'Continua con Google';

  @override
  String get meContinueApple => 'Continua con Apple';

  @override
  String get meSignUpClaimPremium => 'Registrati per ottenere Premium';

  @override
  String get meSignUpContinue => 'Registrati per continuare';

  @override
  String get meAccountLoggedAnotherDevice =>
      'Il tuo account è connesso su un altro dispositivo.';

  @override
  String get premiumSubscription => 'Abbonamento';

  @override
  String get gemsClaimFailed => 'Riscatto non riuscito.';

  @override
  String get gemsCheckFailed => 'Check-in non riuscito.';

  @override
  String get gemsFollowFailed => 'Impossibile seguire l’utente.';

  @override
  String get gemsTaskUpdateFailed =>
      'Aggiornamento dell’attività non riuscito.';

  @override
  String get gemsClaimSuccessful => 'Riscatto riuscito!';

  @override
  String get gemsUnableLoadGemPacks =>
      'Impossibile caricare i pacchetti di gemme.';

  @override
  String get gemsNoGemPacksAvailable =>
      'Nessun pacchetto di gemme disponibile.';

  @override
  String get gemsUnableLoadGemTasks =>
      'Impossibile caricare le attività per le gemme.';

  @override
  String get gemsJoinUs => 'unisciti a noi';

  @override
  String get gemsClaim => 'Riscatta';

  @override
  String get gemsClaimed => 'Riscattato';

  @override
  String get meDailyCheck => 'Check-in giornaliero';

  @override
  String get gemsDailyCheckInReward => 'Ottieni 100';

  @override
  String get meCheck => 'Fai il check-in';

  @override
  String get meCheckSuccessful => 'Check-in riuscito!';

  @override
  String get meGooglePlayUnavailable => 'Google Play non è disponibile.';

  @override
  String get mePurchaseFailed => 'Acquisto non riuscito.';

  @override
  String get gemsEarned => 'Guadagnate';

  @override
  String get gemsSpent => 'Spese';

  @override
  String get gemsPurchase => 'Acquisto';

  @override
  String get gemsGemRecords => 'Cronologia gemme';

  @override
  String get gemsUnableLoadRecords => 'Impossibile caricare la cronologia.';

  @override
  String get gemsNoGemRecordsYet =>
      'Ancora nessuna voce nella cronologia gemme.';

  @override
  String get meAbout => 'Informazioni';

  @override
  String get meEmailCopied => 'Email copiata';

  @override
  String get mePurchasingPremium => 'Acquisto di Premium in corso';

  @override
  String get mePurchaseSuccessful => 'Acquisto riuscito!';

  @override
  String get meWorldoPremiumSubscription =>
      'Il tuo abbonamento Worldo Premium è ora attivo.';

  @override
  String get meMyBalance => 'Il mio saldo';

  @override
  String get meSoldOut => 'Esaurito';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession =>
      'Per l’elenco dei modelli è richiesta una sessione utente completa';

  @override
  String get memoryModelListPermissionDenied =>
      'Accesso all’elenco dei modelli negato per questo mondo';

  @override
  String get memorySaveFailed => 'Salvataggio non riuscito';

  @override
  String get memorySaveResultNotConfirmed =>
      'Esito del salvataggio non confermato';

  @override
  String get memoryChooseModel => 'Scegli modello';

  @override
  String get memoryMaxTokenLimit => 'Limite massimo di token di memoria';

  @override
  String get memoryNoModelsAvailable => 'Nessun modello disponibile';

  @override
  String get memoryRetryRanges => 'Intervalli di nuovo tentativo';

  @override
  String get memoryCurrentUsage => 'Utilizzo attuale della memoria';

  @override
  String memoryMinGems({required String min}) {
    return '$min gemme';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min–$max gemme';
  }

  @override
  String memoryStart({required String memoryStart}) {
    return 'memoria $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return 'memoria $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable =>
      'Impostazioni di memoria non disponibili';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Play ha impiegato troppo tempo a rispondere. Riprova.';

  @override
  String get premiumSubscriptionsNotSupported =>
      'Google Play non supporta gli abbonamenti su questo dispositivo.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'La connessione a Google Play è stata interrotta. Riprova.';

  @override
  String get premiumPurchaseCanceled => 'Acquisto annullato.';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Play è temporaneamente non disponibile. Riprova più tardi.';

  @override
  String get premiumGooglePlayBilling =>
      'La fatturazione Google Play non è disponibile. Controlla il tuo account Play e le impostazioni di pagamento.';

  @override
  String get premiumSubscriptionUnavailable =>
      'Questo abbonamento Premium non è attualmente disponibile su Google Play.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play non ha potuto completare questo acquisto Premium. Riprova.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'Possiedi già questo abbonamento su Google Play.';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Play non ha trovato l’abbonamento da modificare. Controlla Gestisci abbonamenti.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Impossibile connettersi a Google Play. Controlla la connessione Internet e riprova.';

  @override
  String get premiumInsufficientFunds =>
      'Il tuo metodo di pagamento non ha fondi sufficienti. Aggiornalo in Google Play e riprova.';

  @override
  String get premiumGoogleAccountIneligible =>
      'Il tuo account Google Play non è idoneo a questa offerta di abbonamento.';

  @override
  String get premiumAppStoreFailedComplete =>
      'L’App Store non ha potuto completare questo acquisto Premium. Riprova.';

  @override
  String get premiumFailedConnectAppStore =>
      'Impossibile connettersi all’App Store. Controlla la connessione Internet e riprova.';

  @override
  String get premiumAppStoreTookTooLong =>
      'L’App Store ha impiegato troppo tempo a rispondere. Riprova.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'L’App Store ha riscontrato un errore di sistema. Riprova più tardi.';

  @override
  String get premiumRegionUnavailable =>
      'Questo abbonamento Premium non è disponibile nella regione del tuo App Store.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'Questa app non può effettuare questa richiesta all’App Store. Contatta l’assistenza.';

  @override
  String get premiumPurchaseNotSupported =>
      'Questo acquisto non è supportato su questo dispositivo o versione del sistema.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'Impossibile aprire la finestra di acquisto dell’App Store. Torna all’app e riprova.';

  @override
  String get premiumAppStoreFailedAccept =>
      'L’App Store non ha accettato questa quantità di acquisto. Contatta l’assistenza.';

  @override
  String get premiumAppStoreUnavailable =>
      'Questo abbonamento Premium non è attualmente disponibile sull’App Store.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'Gli acquisti non sono consentiti su questo dispositivo. Controlla il tuo Account Apple e le restrizioni sugli acquisti.';

  @override
  String get premiumAppleAccountNotEligible =>
      'Il tuo Account Apple non è idoneo a questa offerta di abbonamento.';

  @override
  String get premiumSubscriptionOffer =>
      'Questa offerta di abbonamento non è disponibile. Aggiorna la pagina e riprova.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'L’App Store non ha accettato il prezzo di questa offerta. Aggiorna la pagina e riprova.';

  @override
  String get premiumAppStoreFailedVerify =>
      'L’App Store non ha potuto verificare questa offerta di abbonamento. Contatta l’assistenza.';

  @override
  String get premiumSubscriptionOfferFailed =>
      'Impossibile preparare questa offerta di abbonamento. Aggiorna la pagina e riprova.';

  @override
  String get premiumAddPaymentMethodApple =>
      'Aggiungi un metodo di pagamento al tuo Account Apple, poi riprova.';

  @override
  String get premiumAppCannotMakePurchases =>
      'Questa app non può effettuare acquisti sull’App Store. Contatta l’assistenza.';

  @override
  String get premiumAppStoreRequestRejected =>
      'L’App Store non ha accettato questa richiesta di acquisto. Riprova o contatta l’assistenza.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'Accesso al servizio cloud Apple negato. Controlla le autorizzazioni del tuo Account Apple.';

  @override
  String get premiumFailedConnectApple =>
      'Impossibile connettersi ai servizi Apple. Controlla la connessione Internet e riprova.';

  @override
  String get premiumAccess2AppleCloudService =>
      'L’accesso al servizio cloud Apple è stato revocato. Controlla le impostazioni del tuo Account Apple.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Accetta gli ultimi termini sulla privacy Apple nel tuo Account Apple, poi riprova.';

  @override
  String get premiumAppStoreWindowFailed =>
      'Impossibile configurare la finestra dell’App Store. Contatta l’assistenza.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'La finestra dell’App Store ha impiegato troppo tempo ad aprirsi. Riprova.';

  @override
  String get premiumReturnAppTryPurchase =>
      'Torna all’app e riprova l’acquisto.';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Play non è disponibile. Verifica che sia installato e che tu abbia effettuato l’accesso.';

  @override
  String get premiumIs4Subscription =>
      'Questo abbonamento Premium non è attualmente disponibile nello store. Aggiorna la pagina e riprova.';

  @override
  String get premiumSubscriptionFailed =>
      'Impossibile preparare questo abbonamento Premium. Aggiorna la pagina e riprova.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'Lo store non ha potuto aprire questo acquisto Premium. Riprova.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'L’abbonamento originale non è stato trovato in Google Play. Controlla Gestisci abbonamenti.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'Questo abbonamento usa un’identità di acquisto diversa. Aggiorna la pagina o contatta l’assistenza.';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play non può ancora modificare questo abbonamento. Controlla Gestisci abbonamenti.';

  @override
  String get premiumPlanChangePending =>
      'Un acquisto App Store per questo piano è ancora in elaborazione. Attendi che termini.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'Impossibile caricare i piani Premium dall’App Store. Riprova.';

  @override
  String get premiumPurchasePreparation =>
      'La preparazione dell’acquisto è scaduta. Riprova.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'L’App Store ha restituito un esito di acquisto sconosciuto. Controlla il tuo abbonamento prima di riprovare.';

  @override
  String get premiumPurchasesUnavailable =>
      'Gli acquisti non sono attualmente disponibili.';

  @override
  String get premiumAutoRenewsCancelAnytime =>
      'Rinnovo automatico. Annulla quando vuoi.';

  @override
  String get premiumSubscribed => 'Abbonato';

  @override
  String get premiumAlsoIncluded => 'Include anche';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'Gemme rosa';

  @override
  String get premiumRedGems => 'Gemme rosse';

  @override
  String get premiumExtraDailyCheck => 'Extra con il check-in giornaliero';

  @override
  String get premiumDailyCheck => 'Check-in giornaliero';

  @override
  String get premiumClaimedMonthly => 'Riscattate mensilmente';

  @override
  String get premiumBilledMonthly => 'Fatturazione mensile';

  @override
  String premiumSaveSavings({required String savings}) {
    return 'Risparmia il $savings%';
  }

  @override
  String get premiumSubscribe => 'Abbonati';

  @override
  String get premiumActiveYearlySubscription =>
      'Un abbonamento Premium annuale attivo non può essere cambiato in un piano mensile.';

  @override
  String get premiumAlreadyHaveActive =>
      'Hai già un abbonamento Premium attivo.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'Hai già un abbonamento a Premium $label.';
  }

  @override
  String get premiumPreviousPurchasePending =>
      'Il tuo precedente acquisto Premium è ancora in fase di conferma.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Usa lo store originale per passare a un abbonamento Premium superiore.';

  @override
  String get premiumResolveCurrent =>
      'Risolvi la situazione del tuo abbonamento attuale nello store prima di acquistare.';

  @override
  String get premiumPurchaseUnavailable =>
      'L’acquisto di Premium non è attualmente disponibile.';

  @override
  String get premiumUnableVerifyPurchase =>
      'Impossibile verificare l’idoneità all’acquisto. Riprova.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      'Lo store non ha potuto verificare questo acquisto Premium.';

  @override
  String get premiumPurchaseDoesNotMatch =>
      'Questo acquisto Premium non corrisponde al piano selezionato.';

  @override
  String get premiumMessagePurchaseCanceled =>
      'Questo acquisto Premium è stato annullato.';

  @override
  String get premiumPurchaseRevoked =>
      'Questo acquisto Premium è stato revocato.';

  @override
  String get premiumNotification => 'Notifica';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premium è attivo nel tuo abbonamento e non consente il passaggio a un piano inferiore.';

  @override
  String get premiumGot => 'Ho capito';

  @override
  String get gemBalancePromptInsufficientGems => 'Gemme insufficienti';

  @override
  String get gemBalancePromptLowGems => 'Poche gemme';

  @override
  String get appPressBackExit => 'Premi di nuovo Indietro per uscire.';

  @override
  String get appReportSubmitted => 'Segnalazione inviata';

  @override
  String get appReportFailed => 'Segnalazione non riuscita';

  @override
  String get appUpdateRequired => 'Aggiornamento richiesto';

  @override
  String get appUpdateContent =>
      'Aggiorna all’ultima versione per continuare a usare Worldo.';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'Versione $versionName';
  }

  @override
  String get appUpdateCheckFailed =>
      'Impossibile aggiornare lo stato dell’aggiornamento. Aggiorna per continuare.';

  @override
  String get appUpdate => 'Aggiorna ora';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabel copiato';
  }

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonImageLoadFailed => 'Caricamento dell’immagine non riuscito';

  @override
  String get commonPageNotFound => 'Pagina non trovata.';

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
    return 'L’LLM sta generando il tuo primo Tick. Potrebbe volerci un momento$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return 'Ultima versione: V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return 'Salva $missingSections prima di creare.';
  }

  @override
  String get createCharacterRoleHint => 'Il ruolo del personaggio nel worldo.';

  @override
  String get createCharacterMannerHint =>
      'Il modo di parlare e comportarsi del personaggio, che guida i suoi dialoghi.';

  @override
  String get createCharacterGoalHint =>
      'L’obiettivo o la direzione comportamentale del personaggio, che guida le sue azioni.';

  @override
  String get createCharacterBackgroundHint =>
      'Il passato e le relazioni del personaggio.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return 'richiesta di unirsi a $world$worldIdSuffix';
  }

  @override
  String get memoryModel => 'Memoria e modello';

  @override
  String get premiumAccountMismatch =>
      'Gli identificativi dell’account non corrispondono all’abbonamento precedente.';

  @override
  String get worldRecap => 'Riepilogo';

  @override
  String get inboxMissingJoinRequestId =>
      'ID della richiesta di partecipazione mancante';

  @override
  String get loginTimedOut => 'Tempo di accesso scaduto. Riprova.';

  @override
  String get loginConnectionFailed =>
      'Impossibile connettersi. Controlla la connessione Internet e riprova.';

  @override
  String get loginTemporarilyUnavailable =>
      'L’accesso non è disponibile al momento. Riprova più tardi.';

  @override
  String get recapUnlockHeading => 'Sblocca il riepilogo';

  @override
  String get recapUpsellDescription =>
      'Riprendi il filo della tua storia con un riepilogo completo di ogni svolta, scelta e personaggio incontrato.';

  @override
  String get recapShowEarlier => 'Vedi i riepiloghi precedenti';

  @override
  String get recapEmpty =>
      'Il riepilogo apparirà qui man mano che la storia prosegue.';

  @override
  String get chatMessageAsNarrator => 'Invia un messaggio come narratore';

  @override
  String chatMessageAsCharacter({required String name}) {
    return 'Invia un messaggio come $name';
  }

  @override
  String get chatNarratorSpeaker => 'il narratore';

  @override
  String get chatYourCharacterSpeaker => 'il tuo personaggio';

  @override
  String chatSpeakingAs({required String speaker}) {
    return 'Stai parlando come $speaker';
  }

  @override
  String get chatSwitchCharacter => 'Passa al personaggio';

  @override
  String get chatSwitchNarration => 'Passa alla narrazione';

  @override
  String chatOpenLocation({required String locationName}) {
    return 'Apri $locationName';
  }

  @override
  String get chatRetryMessage => 'Riprova a inviare il messaggio';

  @override
  String get blockedReportFailed =>
      'L’utente è stato bloccato, ma la segnalazione non è riuscita.';

  @override
  String get storeConnectionFailed =>
      'Impossibile connettersi allo store. Riprova.';

  @override
  String get storeProductUnavailable =>
      'Questo prodotto non è disponibile al momento.';

  @override
  String get storeDevicePurchasesUnavailable =>
      'Gli acquisti non sono disponibili su questo dispositivo.';

  @override
  String get worldHistoryRequestFailed =>
      'Impossibile caricare la cronologia del mondo';

  @override
  String get genericError => 'Si è verificato un errore';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': 'Premium $plan, $price all’anno',
      'other': 'Premium $plan, $price al mese',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => 'Impossibile cancellare';

  @override
  String get developerGatewaySignatureFailed =>
      'Verifica della firma del Gateway non riuscita';

  @override
  String get developerEndpointsSaved =>
      'Salvato. Le nuove richieste useranno gli endpoint configurati.';

  @override
  String get developerAdjustRestartRequired =>
      'Riavvia l’app per applicare l’ambiente Adjust.';

  @override
  String developerRecapSetting({required String mode}) {
    return 'Riepilogo del mondo: $mode';
  }

  @override
  String get developerRecapPreview => 'Anteprima del riepilogo del mondo';

  @override
  String get developerRecapPreviewDescription =>
      'Sostituisce temporaneamente lo stato dell’abbonamento e il riepilogo nel pannello del mondo. Si ripristina al riavvio dell’app.';

  @override
  String get developerResetFailed => 'Impossibile reimpostare';

  @override
  String get developerRecapOff => 'Disattivato (in base all’abbonamento)';

  @override
  String get developerRecapLocked => 'Bloccato · senza abbonamento';

  @override
  String get developerRecapEmpty => 'Abbonato · non ancora generato';

  @override
  String get developerRecapSample => 'Abbonato · riepilogo di esempio';

  @override
  String get developerRecapLive => 'Abbonato · riepilogo reale';

  @override
  String get chatEditFreeUsesExhausted => 'Hai esaurito le modifiche gratuite.';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'Abbonamento: $selection';
  }

  @override
  String get developerMembershipDescription =>
      'Modifica temporaneamente lo stato dell’abbonamento di questo account in tutte le schermate. Il server continua a usare lo stato reale dell’account. La modifica viene annullata al riavvio dell’app.';

  @override
  String get developerMembershipOff => 'Disattivato (abbonamento reale)';

  @override
  String get developerMembershipYearly => 'Premium · annuale';

  @override
  String get developerMembershipMonthly => 'Premium · mensile';

  @override
  String get developerMembershipNone => 'Senza abbonamento';

  @override
  String get originStartBySelectingRole =>
      'Inizia scegliendo il tuo personaggio';

  @override
  String get originRecommendedStart => 'Punto di partenza consigliato';

  @override
  String get originStoryOpening => 'Inizio della storia';

  @override
  String get originOpeningLocation => 'Luogo iniziale';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names si trovano ora a\n$locationName',
      one: '$names si trova ora a\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return 'Inizio della storia\n$locationName';
  }

  @override
  String get chatHistoryExpand => 'Espandi';

  @override
  String get chatHistoryCollapse => 'Comprimi';

  @override
  String get chatCharacterMovement => 'Spostamento dei personaggi';
}

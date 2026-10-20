// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get imageGifUnsupported =>
      'Les animations GIF ne sont pas prises en charge.';

  @override
  String get worldProgressComplete => 'Progression terminée';

  @override
  String a11ySwitchMode({required String label}) {
    return 'Passer au mode $label';
  }

  @override
  String a11yEditItem({required String title}) {
    return 'Modifier $title';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return 'Fiche de rôle $index sur $count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'Modifier l’inspiration $index';
  }

  @override
  String a11yInsert({required String label}) {
    return 'Insérer $label';
  }

  @override
  String get a11yMembership => 'Abonnement';

  @override
  String get a11yOpenWorldo => 'Ouvrir Worldo';

  @override
  String get a11yFilterGender => 'Filtrer par genre';

  @override
  String get a11ySelectRole => 'Choisissez votre rôle';

  @override
  String get a11yLoadingMap => 'Chargement de la carte';

  @override
  String get a11yBuildingWorld => 'Création du monde';

  @override
  String get a11yPremiumMembership => 'Abonnement Premium';

  @override
  String get a11yProMembership => 'Abonnement Pro';

  @override
  String get a11yRecommendedRole => 'Rôle recommandé';

  @override
  String get a11yLastMessage => 'Dernier message';

  @override
  String get a11yRecentChat => 'Conversation récente';

  @override
  String get a11yAiReplyLoading => 'Chargement de la réponse de l’AI';

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
      other: 'joueurs',
      one: 'joueur',
      zero: 'joueur',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (Ajoutés / Maximum)';
  }

  @override
  String get createSixHours => '6 heures';

  @override
  String get createTwelveHours => '12 heures';

  @override
  String get createOneDay => '1 jour';

  @override
  String get createOneWeek => '1 semaine';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageChangeFailed =>
      'Impossible de changer de langue. Veuillez réessayer.';

  @override
  String get purchasingGems => 'Achat de gemmes en cours';

  @override
  String get purchaseSuccessful => 'Achat réussi !';

  @override
  String get okAction => 'OK';

  @override
  String get cancelAction => 'Annuler';

  @override
  String get requestAction => 'Demander';

  @override
  String get requestedStatus => 'Demande envoyée';

  @override
  String get launchAction => 'Lancer';

  @override
  String get tickNowAction => 'Tick maintenant';

  @override
  String get writePostHint => 'Écrire une publication';

  @override
  String get newPostTitle => 'Nouvelle publication';

  @override
  String get aiIsGenerating => 'L’AI génère le contenu';

  @override
  String get generatingCustomizedWorldWait =>
      'Création d’un monde vivant et personnalisé pour vous.\nVeuillez patienter un instant.';

  @override
  String get approvedStatus => 'Approuvé';

  @override
  String get rejectedStatus => 'Refusé';

  @override
  String get awaitingApprovalStatus => 'En attente d’approbation';

  @override
  String get awaitingYourApprovalStatus => 'En attente de votre approbation';

  @override
  String get liveYourWorld => 'VIVEZ VOTRE MONDE';

  @override
  String get signedOutMeDescription =>
      'Explorez des mondes, créez des worldo, invitez vos amis\net poursuivez vos aventures partout.';

  @override
  String get gemTaskLaunchWorldHint =>
      'Ouvrez un Worldo qui vous plaît, puis lancez votre propre monde.';

  @override
  String get gemTaskInviteFriendHint =>
      'Ouvrez un monde, puis appuyez sur Inviter dans le panneau de détails.';

  @override
  String get gemTaskWriteCommentHint =>
      'Ouvrez un Worldo qui vous plaît, puis écrivez une publication dans Discussion.';

  @override
  String get gemTaskRequestJoinHint =>
      'Ouvrez un monde que vous n’avez pas rejoint, puis demandez à le rejoindre.';

  @override
  String get gemTaskSendMessageHint => 'Envoyez des messages dans votre monde.';

  @override
  String get gemTaskProgressWorldHint =>
      'Ouvrez un monde auquel vous jouez, puis appuyez sur Tick maintenant.';

  @override
  String get termsOfService => 'Conditions générales d’utilisation';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'Monde';

  @override
  String get userLabel => 'Utilisateur';

  @override
  String get meLabel => 'Moi';

  @override
  String get locationLabel => 'Lieu';

  @override
  String get allLabel => 'Tous';

  @override
  String get maleLabel => 'Homme';

  @override
  String get femaleLabel => 'Femme';

  @override
  String get nonBinaryLabel => 'Non binaire';

  @override
  String get forYouLabel => 'Pour vous';

  @override
  String get userBlocked => 'Utilisateur bloqué';

  @override
  String get purchaseCanceled => 'Achat annulé.';

  @override
  String get gemsProductUnavailable => 'Ce produit n’est pas disponible.';

  @override
  String get gemsTypeUnsupported =>
      'Ce type de produit n’est pas pris en charge.';

  @override
  String get gemsPurchaseTimeout =>
      'Le délai de l’achat a expiré. Veuillez réessayer.';

  @override
  String get gemsPaymentUnavailable =>
      'Le service de paiement est indisponible.';

  @override
  String get gemsPaymentPending => 'Le paiement est en attente.';

  @override
  String get gemsPaymentConfirming =>
      'La confirmation du paiement est en cours.';

  @override
  String get gemsPurchaseRefunded => 'L’achat a été remboursé.';

  @override
  String get purchasePending => 'Votre achat est en attente.';

  @override
  String get purchaseConfirmationDelayed =>
      'La confirmation de l’achat prend du temps. Veuillez vérifier à nouveau plus tard.';

  @override
  String get purchaseFailed => 'Échec de l’achat.';

  @override
  String get yearlyPlan => 'Annuel';

  @override
  String get monthlyPlan => 'Mensuel';

  @override
  String get proSubscriptionTagline =>
      'Explorez davantage chaque Worldo auquel vous jouez.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, facturés annuellement';
  }

  @override
  String expiresOn({required String date}) {
    return 'Expire le $date';
  }

  @override
  String get activeStatus => 'ACTIF';

  @override
  String get expiredStatus => 'Expiré';

  @override
  String updatedAt({required String timestamp}) {
    return 'Mis à jour $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => 'Échec du chargement. Réessayer';

  @override
  String get loadMoreAction => 'Charger plus';

  @override
  String get gemPurchaseRecord => 'Achat de gemmes';

  @override
  String get taskRewardRecord => 'Récompense de tâche';

  @override
  String get worldProgressRecord => 'Progression du monde';

  @override
  String get directMessageRecord => 'Message privé';

  @override
  String get gemRecord => 'Opération de gemmes';

  @override
  String get runATickTask => 'Lancer un Tick';

  @override
  String get runATickTaskDescription =>
      'Ouvrez un monde auquel vous jouez et appuyez sur Tick maintenant.';

  @override
  String get someoneFallback => 'Quelqu’un';

  @override
  String get aCharacterFallback => 'un personnage';

  @override
  String get thisWorld => 'ce monde';

  @override
  String get noWorldEventsYet =>
      'Aucun événement dans ce monde pour le moment.';

  @override
  String get globalLabel => 'Global';

  @override
  String get eventLabel => 'Événement';

  @override
  String get characterDestinations => 'Destinations des personnages';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName $direction $locationName';
  }

  @override
  String get cameToDirection => 'arrive à';

  @override
  String get wentToDirection => 'se rend à';

  @override
  String get hasComeToDirection => 'arrive à';

  @override
  String get hasGoneToDirection => 'se rend à';

  @override
  String get waitForReplyToSendMore =>
      'Attendez une réponse avant d’envoyer d’autres messages';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux messages',
      one: '$count nouveau message',
      zero: '$count nouveaux messages',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation =>
      'Veuillez sélectionner un rôle prédéfini';

  @override
  String get enterNameValidation => 'Veuillez saisir un nom';

  @override
  String get enterIdentityValidation => 'Veuillez saisir une identité';

  @override
  String get waitForProfileLoading =>
      'Veuillez attendre la fin du chargement du profil.';

  @override
  String get imageUploadFailed => 'Échec de l’envoi de l’image.';

  @override
  String get photoAccessDenied => 'Accès aux photos refusé';

  @override
  String get feedbackSubmitted => 'Commentaires envoyés';

  @override
  String get feedbackFailed => 'Échec de l’envoi des commentaires';

  @override
  String get worldoDetailUnavailable =>
      'Les détails du Worldo sont indisponibles.';

  @override
  String get publishAction => 'Publier';

  @override
  String get publishingStatus => 'Publication en cours...';

  @override
  String get publishFailed => 'Échec de la publication';

  @override
  String get publishChangesBeforeLeaving =>
      'Publier les modifications avant de quitter ?';

  @override
  String get noChangesToPublish => 'Aucune modification à publier.';

  @override
  String get completeOpeningRequiredToPublish =>
      'Une ouverture complète est nécessaire pour publier';

  @override
  String get publishResponseMissingOriginId =>
      'La publication n’a renvoyé aucun identifiant de Worldo.';

  @override
  String get worldoIdRequired => 'Un identifiant de Worldo est requis.';

  @override
  String loadFailedWithReason({required String reason}) {
    return 'Échec du chargement : $reason';
  }

  @override
  String get imageSelectionFailed => 'Échec de la sélection de l’image';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID : $oid\nDernière version : $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID : $wid\nPropriétaire : $owner';
  }

  @override
  String get sendFailed => 'Échec de l’envoi';

  @override
  String get selectARole => 'Sélectionner un rôle';

  @override
  String get timeLabel => 'Heure';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID : $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID : $oid · Créateur : $creator';
  }

  @override
  String get worldoMetricExplanation =>
      'Ce worldo met à jour l’indicateur {Libellé de l’indicateur} de chaque personnage à chaque progression, dans l’unité {Unité}. Chaque personnage commence à {Valeur initiale}, et la valeur peut varier de {Variation min.} à {Variation max.}.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return 'Lancez un $worldo pour créer\nvotre propre monde';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return 'Prochain message estimé à $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount gemmes';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'Supprimer le monde $worldName';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername joue le rôle de $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName lancé !';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName créé !';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName publié !';
  }

  @override
  String get createTimeout => 'La création du Worldo a expiré.';

  @override
  String get publishTimeout => 'La publication du Worldo a expiré';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return 'Vous demandez à rejoindre $worldName$worldId';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge demande à rejoindre $worldName$worldId';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge a commenté votre worldo';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge vous a répondu';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge a aimé votre commentaire';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge vous a envoyé un message';
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
    return 'Utilisations gratuites d’Inspiration restantes : $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Utilisations gratuites d’Édition restantes : $remaining\n$action';
  }

  @override
  String get getMoreAction => 'En obtenir plus >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName arrive à $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldo vous permet de créer, de découvrir et d’explorer des mondes alimentés par l’AI, peuplés de personnages, d’histoires et d’événements qui évoluent. Discutez avec des personnages AI, jouez avec vos amis et faites progresser chaque monde à travers des scènes et des choix immersifs.\n\nNotre application propose une nouvelle façon de vivre les histoires interactives : en faisant partie du monde. Pour toute question, veuillez nous contacter à $contactEmail.';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy, $termsOfUse et $endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return 'En continuant, vous acceptez nos $terms, notre $privacyPolicy et notre $endUserLicenseAgreement';
  }

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get terms => 'Conditions';

  @override
  String get termsOfUse => 'Conditions d’utilisation';

  @override
  String get endUserLicenseAgreement => 'Contrat de licence utilisateur final';

  @override
  String existingAccountSignIn({required String signIn}) {
    return 'Vous avez déjà un compte ? $signIn';
  }

  @override
  String get signInAction => 'Se connecter.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return '$gemIcon$grantedAmount gemmes ont été attribuées.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return 'Jusqu’à $amount gemmes par mois, avec un accès Premium complet.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /jour';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/mois';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge : Réponse à $replyToName$replyToBadge : $content';
  }

  @override
  String discussReplyLineDirect({
    required String authorName,
    required String authorBadge,
    required String content,
  }) {
    return '$authorName$authorBadge : $content';
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
  String get homeLoadFailed => 'Échec du chargement';

  @override
  String get homeRetry => 'Réessayer';

  @override
  String get homeEmptyDescription =>
      'Worldo est le modèle. Lancez-le pour créer un monde vivant à explorer et à faire évoluer.';

  @override
  String get homeWorldCharacter => 'Personnage';

  @override
  String get homeWorldSingleOtherPlayer => '· 1 autre joueur';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· $otherPlayerCount autres joueurs';
  }

  @override
  String get homeSignInUnavailable => 'Connexion indisponible';

  @override
  String get homeSignedOutTitle => 'Tous vos mondes au même endroit';

  @override
  String get homeSignedOutDescription =>
      'Connectez-vous pour créer des mondes et poursuivre vos histoires.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return 'Propriétaire : $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID : $oid  Créateur : $originator\nRésumé : $brief\nDernière version : $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID : $wid\nPropriétaire : $owner';
  }

  @override
  String get searchHistory => 'Historique de recherche';

  @override
  String get searchFailed => 'Échec de la recherche';

  @override
  String get searchNoResults => 'Aucun résultat.';

  @override
  String get searchCancel => 'Annuler';

  @override
  String get searchHint => 'Worldo, personnage, tags';

  @override
  String get worldDetailOnlyWorldsLaunched =>
      'Seuls les mondes que vous avez lancés en solo peuvent être supprimés.';

  @override
  String get worldDetailDelete => 'Supprimer';

  @override
  String get worldDetailNoCharacterStatusYet =>
      'Aucun état de personnage pour le moment.';

  @override
  String get worldDetailNoCharactersYet => 'Aucun personnage pour le moment.';

  @override
  String get worldDetailProgressingWorld => 'Progression du monde en cours';

  @override
  String get worldDetailCompressingRecent =>
      'Compression des souvenirs récents\nAvancée de la chronologie du monde\nGénération de la prochaine étape de l’histoire\nMise à jour des lieux des personnages';

  @override
  String get worldModelsDetail => 'Détails';

  @override
  String get worldModelsLocations => 'Lieux';

  @override
  String get worldModelsEvents => 'Événements';

  @override
  String get worldModelsStatus => 'État';

  @override
  String get worldDetailUnavailable => 'Indisponible';

  @override
  String worldActionFailed({required String actionLabel}) {
    return 'Échec de l’action : $actionLabel';
  }

  @override
  String get worldDetailRequestJoinWorld => 'Demander à rejoindre ce monde ?';

  @override
  String get worldDetailRequest => 'Demander';

  @override
  String get worldDetailLaunchFailed => 'Échec du lancement';

  @override
  String get worldDetailNoSavedProfileFound => 'Aucun profil enregistré trouvé';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return 'Worldo source : $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => 'Inviter';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Rejoignez mon monde « $worldName » sur Worldo !\n$wid\nRecherchez ce WID sur Worldo pour le trouver et le rejoindre.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'Résumé du monde';

  @override
  String get worldDetailCast => 'Distribution';

  @override
  String get worldDetailLinkCopiedShare =>
      'Lien copié. Partagez-le avec vos amis.';

  @override
  String get worldMapAction => 'Carte';

  @override
  String get worldInfoAction => 'Infos';

  @override
  String worldLocationCount({required String pointsCount}) {
    return 'Lieux ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => 'Joueur';

  @override
  String worldDetailGoal({required String goal}) {
    return 'Objectif : $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet =>
      'Aucun détail de personnage pour le moment.';

  @override
  String get worldDetailNoEventsYet => 'Aucun événement pour le moment.';

  @override
  String get worldDetailLoadEventsFailed =>
      'Échec du chargement des événements.';

  @override
  String homeLocationID({required String id}) {
    return 'Lieu $id';
  }

  @override
  String get homeBuildingWorld => 'CRÉATION DU MONDE';

  @override
  String get worldMapLoadFailed => 'Échec du chargement de la carte';

  @override
  String get worldMapZoomIn => 'Zoomer sur la carte';

  @override
  String get worldMapZoomOut => 'Dézoomer sur la carte';

  @override
  String get worldDetailGlobal => 'Global';

  @override
  String get worldDetailLocation => 'Lieu';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => 'Génération du premier Tick';

  @override
  String get worldFirstTickStatusLoadFailed =>
      'Impossible de charger l’état de génération.';

  @override
  String get worldDetailNew => 'Nouveau';

  @override
  String get homeUnknownLocation => 'Lieu inconnu';

  @override
  String get homeUnknownCharacter => 'Personnage inconnu';

  @override
  String get homeNewPlaceEmerged => 'Un nouveau lieu est apparu';

  @override
  String get homeNewCharacterAppeared => 'Un nouveau personnage est apparu';

  @override
  String get chatLocationUnavailable => 'Le lieu est indisponible';

  @override
  String get chatRequestApprovalLaunch => 'Demander l’autorisation de lancer';

  @override
  String get chatLoading => 'Chargement';

  @override
  String get chatQuotaCheckFailed =>
      'Impossible de vérifier les utilisations gratuites. Veuillez réessayer.';

  @override
  String get chatInspirationSourceChanged =>
      'La source d’inspiration a changé. Veuillez rouvrir Inspiration.';

  @override
  String get chatInspiration => 'Inspiration';

  @override
  String get chatMessageCannotSend => 'Ce message ne peut plus être envoyé';

  @override
  String get chatMessageEmpty => 'Le message est vide';

  @override
  String get chatConnectionFailed =>
      'Impossible de se connecter à cette conversation';

  @override
  String get chatReplyChangedSelect =>
      'La réponse a changé. Veuillez sélectionner à nouveau une inspiration.';

  @override
  String get chatSendConfirmFailed =>
      'Impossible de confirmer l’envoi du message';

  @override
  String get chatNoNetworkConnection => 'Aucune connexion réseau';

  @override
  String get chatRoundCannotContinue => 'Ce tour ne peut pas continuer';

  @override
  String get chatSourceRoundChanged => 'Le tour source a changé';

  @override
  String get chatGo => 'Continuer';

  @override
  String get chatReplyActionUnavailable =>
      'Cette action sur la réponse n’est plus disponible';

  @override
  String get chatRegenerateFailure => 'Échec de la régénération';

  @override
  String get chatGoFailure => 'Échec de la continuation';

  @override
  String get chatEditFailure => 'Échec de la modification';

  @override
  String get chatInspirationFailure => 'Échec de l’inspiration';

  @override
  String get chatJoinLocationFailed => 'Impossible de rejoindre ce lieu';

  @override
  String get chatInactive => 'Cette conversation n’est plus active';

  @override
  String get chatChatroomUnavailable =>
      'Le salon de discussion est indisponible';

  @override
  String get chatFailedConfirmReplyAction =>
      'Impossible de confirmer l’action sur la réponse';

  @override
  String get chatLeastOneMessageMustRemain =>
      'Au moins un message doit être conservé.';

  @override
  String get chatReplyNotEditable => 'Cette réponse ne peut pas être modifiée';

  @override
  String get chatReplyAlreadyFixed => 'Cette réponse a été figée';

  @override
  String get chatReplyEditorFrozen => 'L’éditeur de réponse est bloqué';

  @override
  String get chatResolvePreviousSaveBefore =>
      'Terminez l’enregistrement précédent avant de modifier son brouillon';

  @override
  String get chatStaleReplyEditor => 'L’éditeur de réponse n’est plus à jour';

  @override
  String get chatPreviousSaveResultUncertain =>
      'Le résultat de l’enregistrement précédent est incertain ; rechargez avant de modifier à nouveau';

  @override
  String get chatCandidateMissing => 'La proposition n’existe plus';

  @override
  String get chatBatchSupportsMost100Changes =>
      'Un lot peut contenir au maximum 100 modifications';

  @override
  String get chatMissingStableMessageIdentity =>
      'L’identifiant stable du message est manquant';

  @override
  String get chatEditTargetHasChanged => 'La cible de la modification a changé';

  @override
  String get chatMessageNotEditable => 'Ce message ne peut pas être modifié';

  @override
  String get chatReplyNoLongerEditable =>
      'Cette réponse ne peut plus être modifiée';

  @override
  String get chatEditorOpenFailed => 'Impossible d’ouvrir l’éditeur';

  @override
  String get chatInactiveDuringEdit => 'Cette conversation n’est plus active.';

  @override
  String get chatEditMessage => 'Modifier le message';

  @override
  String get chatSave => 'Enregistrer';

  @override
  String get chatEdit => 'Modifier';

  @override
  String get chatRegenerate => 'Régénérer';

  @override
  String get chatRegenerateUnavailable => 'Ce tour ne peut pas être régénéré';

  @override
  String get chatGenerate10Replies =>
      'Vous pouvez générer jusqu’à 10 réponses.';

  @override
  String get chatPreviousReply => 'Réponse précédente';

  @override
  String get chatNextReply => 'Réponse suivante';

  @override
  String get chatCopy => 'Copier';

  @override
  String get chatReport => 'Signaler';

  @override
  String get chatCopied => 'Copié';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux messages',
      one: '$count nouveau message',
      zero: '$count nouveaux messages',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'Mentionner';

  @override
  String get chatCharacters => 'Personnages';

  @override
  String get chatNoCharacters => 'Aucun personnage';

  @override
  String get chatNoLocations => 'Aucun lieu';

  @override
  String get chatHere => 'Ici';

  @override
  String get chatLoadEarlierMessages => 'Charger les messages précédents';

  @override
  String get chatText => 'Écrire un message...';

  @override
  String get chatLocationRoster => 'VOUS';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'Tout le contenu est généré par l’AI et fictif. Toute ressemblance avec des personnes, des événements ou des lieux réels est fortuite.';

  @override
  String get homeRecent => 'Récent';

  @override
  String get worldoUnableSavePreference =>
      'Impossible d’enregistrer votre préférence. Veuillez réessayer.';

  @override
  String get worldoFilterGender => 'Filtrer par genre';

  @override
  String get worldoNoData => 'Aucune donnée';

  @override
  String get worldoAll => 'Tous';

  @override
  String get worldoDetailSelectRole => 'Choisissez votre rôle';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'Créateur : $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Modifier le Worldo';

  @override
  String get worldoDetailWorldoBrief => 'Résumé du Worldo';

  @override
  String get worldoDetailNewPost => 'Nouvelle publication';

  @override
  String get worldoDetailWritePost => 'Écrire une publication';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'Discussion ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => 'Tout voir >';

  @override
  String get worldoDetailPlayingWorld => 'Monde en cours';

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
    return 'Personnages ($length)';
  }

  @override
  String get worldoSend => 'Envoyer';

  @override
  String get worldoPostFailed => 'Échec de la publication';

  @override
  String get worldoImageUploadFailed => 'Échec de l’envoi de l’image';

  @override
  String get worldoLoadRepliesFailed => 'Échec du chargement des réponses';

  @override
  String get worldoWriteReply => 'Écrire une réponse';

  @override
  String worldoReplyName({required String replyToName}) {
    return 'Répondre à $replyToName';
  }

  @override
  String get worldoPostDetail => 'Détails de la publication';

  @override
  String get worldoPostUnavailable => 'Publication indisponible';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'Toutes les réponses $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return 'Voir les $replyCount réponses';
  }

  @override
  String get worldoLikeFailed => 'Impossible d’ajouter un J’aime';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return 'Voir les $replyCount réponses';
  }

  @override
  String get worldoUser => 'Utilisateur';

  @override
  String get worldoViewMore => 'Voir plus >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'Discussion ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return 'Voir les $remainingReplyCount réponses';
  }

  @override
  String get worldoReply => 'Répondre';

  @override
  String get worldoDiscussTitle => 'Discussion';

  @override
  String get worldoLaunchLocationComesLife =>
      'Ce lieu prend vie après le lancement.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      'Lancez ce Worldo pour explorer ce lieu et y interagir.';

  @override
  String get worldoLaunchRoleUnavailable => 'Ce rôle n’est plus disponible';

  @override
  String get worldoLaunchSelectRole => 'Choisissez votre rôle';

  @override
  String get worldoLaunchProfile => 'Votre profil';

  @override
  String get worldoLaunchDone => 'Terminé';

  @override
  String get worldoLaunchSuggested => 'Suggestions';

  @override
  String get worldoLaunchName => 'Nom';

  @override
  String get worldoLaunchIdentity => 'Identité';

  @override
  String get worldoLaunchPersonality => 'Personnalité';

  @override
  String get worldoLaunchGoal => 'Objectif';

  @override
  String get worldoLaunchSetupRole => 'Configurez votre rôle';

  @override
  String get worldoLaunchPreset => 'Prédéfini';

  @override
  String get worldoLaunchCustom => 'Personnalisé';

  @override
  String get worldoLaunchNoPresetRole => 'Aucun rôle prédéfini';

  @override
  String get worldoLaunchFilling => 'Remplissage en cours...';

  @override
  String get worldoLaunchFillMyProfile => 'Remplir à partir de mon profil';

  @override
  String get worldoLaunchLaunch => 'Lancer';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName lancé !';
  }

  @override
  String get worldoLaunchEnter => 'Entrer';

  @override
  String get createAction => 'Créer';

  @override
  String get createWorldoTitle => 'Créer un Worldo';

  @override
  String get createFailed => 'Échec de la création';

  @override
  String get createNotesRequired =>
      'Des notes de mise à jour sont nécessaires pour publier.';

  @override
  String get createActionInProgress => 'Cette action est déjà en cours.';

  @override
  String createCurrentVersion({required String version}) {
    return 'Version actuelle : $version';
  }

  @override
  String get createChecking => 'Vérification...';

  @override
  String createSummaryName({required String name}) {
    return 'Nom du Worldo : $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Résumé du Worldo : $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'Image de couverture : $status';
  }

  @override
  String get createNotUploaded => 'Non envoyée';

  @override
  String get createUploaded => 'Envoyée';

  @override
  String createSummarySettings({required String settings}) {
    return 'Paramètres du Worldo : $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Temps du Worldo : $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Indicateur du Worldo : $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
      zero: '$count jours',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 personnage';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnages : $names',
      one: '1 personnage : $names',
      zero: '0 personnage : $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'Suggestion : $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · Région : $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · Bâtiment : $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · Pièce : $count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
      zero: '$count événement',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return 'Dialogue de personnage : $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'Narrateur : $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return 'Image : $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return 'Supprimer $itemLabel ?';
  }

  @override
  String get createItemHasContentDeleteAnyway =>
      'Cet élément contient du contenu. Le supprimer quand même ?';

  @override
  String get createImageUploadProgress => 'L’envoi de l’image est en cours.';

  @override
  String get createBasicsBasics => 'Informations de base';

  @override
  String get createSaveInProgress => 'L’enregistrement est déjà en cours.';

  @override
  String get createRequiredBeforeSave =>
      'Remplissez tous les champs obligatoires avant d’enregistrer.';

  @override
  String get createOpeningOpening => 'Ouverture';

  @override
  String get createCharacterCharactersCreate =>
      'Personnages : veuillez créer au moins un personnage.';

  @override
  String get createCharacterCharactersOnlyOne =>
      'Personnages : un seul personnage peut être recommandé.';

  @override
  String get createBasicsBasicsWorldoName =>
      'Informations de base : le nom du Worldo est requis.';

  @override
  String get createBasicsBasicsWorldoBrief =>
      'Informations de base : le résumé du Worldo est requis.';

  @override
  String get createBasicsBasicsCoverImage =>
      'Informations de base : l’image de couverture est requise.';

  @override
  String get createBasicsBasicsMetricMust =>
      'Informations de base : l’indicateur doit être au format JSON valide.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'Personnage #$characterIndex : le nom est requis.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'Personnage #$characterIndex : l’identité est requise.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'Personnage #$characterIndex : la personnalité est requise.';
  }

  @override
  String get createCharacterCharactersLeast =>
      'Personnages : au moins un personnage est requis.';

  @override
  String get createLocationLocationsCreate =>
      'Lieux : veuillez créer au moins un lieu.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return 'Lieu #$locationIndex : le nom du lieu est requis.';
  }

  @override
  String get createOpeningOpeningSelect =>
      'Ouverture : sélectionnez un lieu et complétez chaque élément du dialogue.';

  @override
  String get createOpeningOpeningSelected =>
      'Ouverture : le lieu sélectionné n’est plus disponible.';

  @override
  String get createOpeningCharacterOpening =>
      'Ouverture : un personnage sélectionné n’est plus disponible.';

  @override
  String get createOpeningOpeningDialogue =>
      'Ouverture : un personnage du dialogue n’est pas dans le lieu sélectionné. Ouvrez Ouverture pour corriger cela.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return 'Dialogue d’ouverture non pris en charge : $type';
  }

  @override
  String get createCreating => 'Création en cours...';

  @override
  String get createDiscard => 'Abandonner';

  @override
  String get createCharactersStep => 'Personnages (>=1)';

  @override
  String get createLocationsStep => 'Lieux (>=1)';

  @override
  String get createStoryEventsOptional =>
      'Événements de l’histoire (facultatif)';

  @override
  String get createUpdateNotesRequiredPublish =>
      'Notes de mise à jour (requises pour publier)';

  @override
  String get createWhatChangedVersion =>
      'Qu’est-ce qui a changé dans cette version ?';

  @override
  String get createView => 'Voir';

  @override
  String get createNotStartedYet => 'Pas encore commencé';

  @override
  String get createEdited => 'Modifié';

  @override
  String get createPublishingWorldo => 'Publication de votre Worldo';

  @override
  String get createCreatingWorldo => 'Création de votre Worldo';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Préparation des mises à jour de votre Worldo.\nVeuillez patienter un instant.';

  @override
  String get createBringingWorldoLifeWait =>
      'Votre Worldo prend vie.\nVeuillez patienter un instant.';

  @override
  String get createDescribeIssue => 'Décrivez le problème';

  @override
  String get createSubmit => 'Envoyer';

  @override
  String get createBasicsWorldoName => 'Nom du Worldo *';

  @override
  String get createBasicsNameRequired => 'Le nom du Worldo est requis.';

  @override
  String get createBasicsBriefRequired => 'Le résumé du Worldo est requis.';

  @override
  String get createBasicsCoverRequired => 'L’image de couverture est requise.';

  @override
  String get createBasicsMetricInvalid =>
      'L’indicateur doit être au format JSON valide.';

  @override
  String get createBasicsEgMainStreet => 'Ex. : Rue principale';

  @override
  String get createBasicsWorldoBrief => 'Résumé du Worldo *';

  @override
  String get createBasicsBriefNote =>
      'L’accroche publique que les joueurs découvrent en premier : le cadre, le conflit central et ce qui le rend intrigant.';

  @override
  String get createBasicsHiddenNote =>
      'Les règles cachées et le contexte qui font avancer l’histoire : intentions, mécanismes et limites secrètes.';

  @override
  String get createBasicsEgHalfShopsMain =>
      'Ex. : La moitié des commerces de la rue principale sont condamnés. À la fête du Travail, le propriétaire du commerce le plus riche dirigera la ville.';

  @override
  String get createBasicsCoverImage => 'Image de couverture *';

  @override
  String get createBasicsUpload => 'Importer';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'Utilisée sur les cartes et les pages de détails. Environ 768×1024 px recommandés. Formats pris en charge : JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden =>
      'Paramètres du Worldo — cachés (facultatif)';

  @override
  String get createBasicsEgBankerSecretly =>
      'Ex. : Le banquier décide en secret qui obtient un prêt ; ceux qui s’endettent trop peuvent être évincés.';

  @override
  String get createBasicsWorldoTimeOptional => 'Temps du Worldo (facultatif)';

  @override
  String get createBasicsWorldoStartsStart =>
      'Ce worldo commence à {Heure de début} ; chaque fois que l’utilisateur appuie sur *progresser*, la chronologie avance de {Temps par progression}.';

  @override
  String get createBasicsStartTime => 'Heure de début';

  @override
  String get createBasicsDateExample => 'Ex. : Jour 1, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => 'Temps par progression';

  @override
  String get createBasicsEg8Hours3Days => 'Ex. : 8 heures / 3 jours';

  @override
  String get createBasicsWorldoMetricOptional =>
      'Indicateur du Worldo (facultatif)';

  @override
  String get createBasicsMetricLabel => 'Libellé de l’indicateur';

  @override
  String get createBasicsEgWealthGoalProgress =>
      'Ex. : Richesse / Progression de l’objectif';

  @override
  String get createBasicsLabelNote => 'Note sur le libellé';

  @override
  String get createBasicsDescribeWhatMetric =>
      'Décrivez ce que mesure cet indicateur';

  @override
  String get createBasicsUnit => 'Unité';

  @override
  String get createBasicsEgCoins => 'Ex. : pièces / %';

  @override
  String get createBasicsRange => 'Plage de valeurs';

  @override
  String get createBasicsStarting => 'Valeur initiale';

  @override
  String get createBasicsDeltaMin => 'Variation min.';

  @override
  String get createBasicsDeltaMax => 'Variation max.';

  @override
  String get createBasicsSaving => 'Enregistrement...';

  @override
  String get createBasicsAdvancedSettings => 'Paramètres avancés (facultatif)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'Personnage $index';
  }

  @override
  String get createCharacterSuggest => 'Recommander';

  @override
  String get createCharacterAvatarOptional => 'AVATAR\n(facultatif)';

  @override
  String get createCharacterName => 'Nom *';

  @override
  String get createCharactersTitle => 'Personnages';

  @override
  String createCharacterLimit({required int count}) {
    return 'Vous pouvez ajouter jusqu’à $count personnages.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'Personnage $index : le nom est requis.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'Personnage $index : l’identité est requise.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'Personnage $index : la personnalité est requise.';
  }

  @override
  String get createCharacterMinOne => 'Veuillez créer au moins un personnage.';

  @override
  String get createCharacterEnterName => 'Saisissez un nom...';

  @override
  String get createCharacterIdentity => 'Identité *';

  @override
  String get createCharacterEgHometownKidBack =>
      'Ex. : Un enfant du pays de retour pour tenter sa chance';

  @override
  String get createCharacterPersonality => 'Personnalité *';

  @override
  String get createCharacterEgUnderdog =>
      'Ex. : Un outsider bienveillant avec peu de moyens';

  @override
  String get createCharacterGoalOptional => 'Objectif (facultatif)';

  @override
  String get createCharacterEgRichestOwner =>
      'Ex. : Devenir le propriétaire le plus riche de la rue principale d’ici la fête du Travail';

  @override
  String get createCharacterBackgroundHidden => 'Passé — caché (facultatif)';

  @override
  String get createCharacterEgLeftTownYears =>
      'Ex. : Parti de la ville il y a des années, il revient dans une rue principale aux commerces fermés pour tenter sa chance.';

  @override
  String get createCharacterAddCharacter => '+ Ajouter un personnage';

  @override
  String get createLocationImageOptional => 'IMAGE\n(facultatif)';

  @override
  String get createCharacterSelectAvailable =>
      'Sélectionnez parmi les personnages disponibles ci-dessous';

  @override
  String get createCharacterInitialCharacters =>
      'Personnages initiaux (facultatif)';

  @override
  String get createLocationStartingCharacters =>
      'Les personnages présents ici au début du worldo.';

  @override
  String get createCharacterAvailableSelect => 'Disponibles';

  @override
  String get createCharacterNoCharactersYet =>
      'Aucun personnage pour le moment. Créez d’abord des personnages, puis choisissez leur lieu de départ.';

  @override
  String get createCharacterNoCharacters =>
      'Aucun personnage disponible. Tous les personnages ont déjà un lieu initial.';

  @override
  String get createLocationEveryL2L3Locations =>
      'Tous les lieux L2 et L3 qu’il contient seront également supprimés.';

  @override
  String get createLocationEveryL3Locations =>
      'Tous les lieux L3 qu’il contient seront également supprimés.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return 'Supprimer « $displayName »';
  }

  @override
  String get createLocationOpeningLocation =>
      'C’est le lieu de l’ouverture. Le supprimer effacera également l’ouverture.';

  @override
  String get createLocationL1LocationRegion => 'Lieu L1 · Région *';

  @override
  String get createLocationL2LocationBuilding => 'Lieu L2 · Bâtiment *';

  @override
  String get createLocationAddL3Location => 'Ajouter un lieu L3';

  @override
  String get createLocationsTitle => 'Lieux';

  @override
  String get createLocationStatisticsNote =>
      'Votre monde est construit sur 3 niveaux :\nL1 · Région     Une zone de votre monde — Centre-ville\nL2 · Bâtiment   Un bâtiment de cette zone — Restaurant de Joe\nL3 · Pièce       Une pièce du bâtiment — Arrière-cuisine\nChaque lieu doit avoir les trois niveaux. Jusqu’à 15 pièces au total.';

  @override
  String get createLocationL1NameNote =>
      'Une zone de votre monde : un quartier, une ville, une forêt. Pas un seul bâtiment.';

  @override
  String get createLocationL2NameNote =>
      'Un bâtiment dans cette région : une boutique, une école, un immeuble.';

  @override
  String get createLocationL3NameNote =>
      'Une pièce dans le bâtiment. Les toits, cours et entrées conviennent aussi.';

  @override
  String get createLocationName => 'Nom *';

  @override
  String get createLocationL1NameRequired => 'Le nom du lieu L1 est requis.';

  @override
  String get createLocationL3NameRequired => 'Le nom du lieu L3 est requis.';

  @override
  String get createLocationThisL1 => 'Ce lieu L1';

  @override
  String get createLocationThisL2 => 'Ce lieu L2';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel doit contenir au moins un lieu L2.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel doit contenir au moins un lieu L3.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel contient un lieu L2 qui doit être nommé.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel contient un lieu L3 qui doit être nommé.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'Vous pouvez ajouter jusqu’à $count lieux L3.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return 'Vous avez utilisé les $count pièces. Supprimez-en une pour en ajouter une autre.';
  }

  @override
  String get createLocationAtLeastOneL1 => 'Au moins un lieu L1 est requis.';

  @override
  String get createLocationAddL1 => 'Ajoutez au moins un lieu L1.';

  @override
  String get createLocationMinOne => 'Veuillez créer au moins un lieu.';

  @override
  String get createLocationIdRequired =>
      'Chaque lieu doit avoir un identifiant.';

  @override
  String get createLocationIdUnique =>
      'Chaque lieu doit avoir un identifiant unique.';

  @override
  String get createLocationParentInvalid =>
      'Chaque lieu doit avoir un parent valide.';

  @override
  String get createLocationFieldsRequired =>
      'Remplissez tous les champs obligatoires des lieux avant d’enregistrer.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'L’enregistrement des lieux supprimera également $count bulles de dialogue d’ouverture pour les personnages retirés.',
      one:
          'L’enregistrement des lieux supprimera également 1 bulle de dialogue d’ouverture pour les personnages retirés.',
      zero:
          'L’enregistrement des lieux supprimera également $count bulles de dialogue d’ouverture pour les personnages retirés.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'Modifier le lieu L3';

  @override
  String get createLocationPreview => 'Aperçu';

  @override
  String get createLocationCompleteLocation =>
      'Veuillez compléter ce lieu ou le supprimer.';

  @override
  String get createLocationRemoveCharacter =>
      'Retirer le personnage de ce lieu ?';

  @override
  String get createLocationRemove => 'Retirer';

  @override
  String get createLocationL1Location => 'Lieu L1';

  @override
  String get createLocationL2Location => 'Lieu L2';

  @override
  String get createLocationL3Location => 'Lieu L3';

  @override
  String get createOpeningSelectLocation => 'Sélectionner un lieu';

  @override
  String get createOpeningNoSavedLocations => 'Aucun lieu enregistré';

  @override
  String get createOpeningSelect => 'Sélectionner';

  @override
  String get createOpeningSelectLocationFirst =>
      'Sélectionnez d’abord un lieu.';

  @override
  String get createOpeningNoInitialCharacter => 'Aucun personnage initial';

  @override
  String get createOpeningLocationsLoading =>
      'Les lieux sont encore en cours de chargement.';

  @override
  String get createOpeningLoadingLocations => 'Chargement des lieux...';

  @override
  String get createOpeningSwitchingLocations =>
      'Changer de lieu effacera le contenu du dialogue.';

  @override
  String get createOpeningContinue => 'Continuer';

  @override
  String get createOpeningAdd10DialogueItems =>
      'Vous pouvez ajouter jusqu’à 10 éléments de dialogue.';

  @override
  String get settingsUnableSaveSuggestedRole =>
      'Impossible d’enregistrer le rôle recommandé.';

  @override
  String get createOpeningUnableSaveOpening =>
      'Impossible d’enregistrer l’ouverture.';

  @override
  String get createOpeningSelectInitial => 'Sélectionner le lieu initial';

  @override
  String get createOpeningInitialLocationRequired =>
      'Sélectionnez un lieu initial avant d’enregistrer.';

  @override
  String get createOpeningAddDialogueFirst =>
      'Ajoutez au moins un élément de dialogue avant d’enregistrer.';

  @override
  String get createOpeningCompleteDialogue =>
      'Complétez chaque élément de dialogue avant d’enregistrer.';

  @override
  String get createOpeningDialogue => 'Dialogue d’ouverture';

  @override
  String get createOpeningLocationRequired =>
      'Sélectionnez d’abord un lieu, puis modifiez le dialogue.';

  @override
  String get createOpeningNarrator => 'Narrateur';

  @override
  String get createOpeningImage => 'Image';

  @override
  String get createOpeningSuggestRoleUser =>
      'Recommander un rôle à l’utilisateur';

  @override
  String get createOpeningNoCharacters => 'Aucun personnage disponible.';

  @override
  String get createOpeningEnterNarrator => 'Saisissez le dialogue du narrateur';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return 'Saisissez le dialogue de $name';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => 'IMPORTER UNE IMAGE';

  @override
  String get createEventAddEvent => '+ Ajouter un événement';

  @override
  String get createStoryEventsTitle => 'Événements de l’histoire';

  @override
  String createEventLimit({required int count}) {
    return 'Vous pouvez ajouter jusqu’à $count événements.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'Événement $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      'Ex. : Une chaîne nationale convoite un terrain vacant et menace de casser les prix de tous les commerces locaux.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'Un moment clé que l’AI utilise pour orienter l’histoire.';

  @override
  String get imageCropUploadFailed => 'Échec de l’importation';

  @override
  String get inboxNotifications => 'Notifications';

  @override
  String get inboxNoNotificationsYet => 'Aucune notification pour le moment.';

  @override
  String get inboxFollowers => 'Abonnés';

  @override
  String get inboxNewFollowers => 'Nouveaux abonnés';

  @override
  String get inboxNoNewFollowersYet => 'Aucun nouvel abonné pour le moment.';

  @override
  String get inboxComments => 'Commentaires';

  @override
  String get inboxNoCommentsYet => 'Aucun commentaire pour le moment.';

  @override
  String get inboxPrivateChats => 'Conversations privées';

  @override
  String get inboxChatFriendsWorldo => 'Discutez avec vos amis sur Worldo.';

  @override
  String get inboxUnknownUser => 'Utilisateur inconnu';

  @override
  String get inboxDirectMessage => 'Message privé';

  @override
  String get inboxJoinRequest => 'Demande pour rejoindre';

  @override
  String get inboxApprove => 'Approuver';

  @override
  String get inboxReject => 'Refuser';

  @override
  String get inboxOk => 'OK';

  @override
  String get inboxReviewFailed => 'Échec de l’examen';

  @override
  String get inboxLoadMessagesFailed => 'Échec du chargement des messages.';

  @override
  String get inboxNewMessage => 'Nouveau message';

  @override
  String get inboxSomeone => 'Quelqu’un';

  @override
  String get inboxWorld => 'ce monde';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name demande à rejoindre $world$suffix';
  }

  @override
  String get inboxCommentWorldo => ' a commenté votre worldo';

  @override
  String get inboxReply => ' vous a répondu';

  @override
  String get inboxLikeComment => ' a aimé votre commentaire';

  @override
  String get inboxLikedComment => 'a aimé votre commentaire';

  @override
  String get inboxComment2LikeComment => 'a aimé votre commentaire';

  @override
  String get inboxReplied => 'vous a répondu';

  @override
  String get inboxYou2Reply => 'vous a répondu';

  @override
  String get inboxCommentedOrigin => 'a commenté votre création';

  @override
  String get inboxCommentOrigin => 'a commenté votre création';

  @override
  String get inboxSentMessage => ' vous a envoyé un message';

  @override
  String get inboxStartedFollowing => ' a commencé à vous suivre.';

  @override
  String get meFailedOpenDiscord => 'Impossible d’ouvrir Discord';

  @override
  String get meImagePickFailed => 'Échec de la sélection de l’image';

  @override
  String get meUpdateFailed => 'Échec de la mise à jour';

  @override
  String get mePlaying => 'En cours';

  @override
  String get meEditName => 'Modifier le nom';

  @override
  String get meSignUpReward => 'Inscrivez-vous et recevez 250 gemmes !';

  @override
  String get loginSignUpReward => 'Inscrivez-vous et recevez 250 gemmes !';

  @override
  String get meUnknown => 'Inconnu';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID : $oid\nDernière version : $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID : $displayWid\nPropriétaire : $owner';
  }

  @override
  String get meFollows => 'Abonnements';

  @override
  String meFollowingCount({required String followingCount}) {
    return '$followingCount abonnements';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount abonnés';
  }

  @override
  String get meNoFollowingYet => 'Aucun abonnement pour le moment.';

  @override
  String get meNoFollowersYet => 'Aucun abonné pour le moment.';

  @override
  String get meBlockFailed => 'Le blocage a échoué. Veuillez réessayer.';

  @override
  String get meUserBlockedContentHasReported =>
      'Utilisateur bloqué. Ce contenu a été signalé à l’équipe Worldo.';

  @override
  String get meBlockUser => 'Bloquer cet utilisateur ?';

  @override
  String get meBlock => 'Bloquer';

  @override
  String get meUnblockFailed => 'Le déblocage a échoué. Veuillez réessayer.';

  @override
  String get meUnblock => 'Débloquer';

  @override
  String get meFollowing => 'Abonné';

  @override
  String get meFollow => 'Suivre';

  @override
  String get meMessage => 'Message';

  @override
  String meUID({required String uid}) {
    return 'UID : $uid';
  }

  @override
  String get meNoWorldoCreatedYet => 'Vous n’avez encore créé aucun Worldo.';

  @override
  String get meNoWorldoYet => 'Aucun Worldo pour le moment.';

  @override
  String get meNoWorldsCreatedYet => 'Vous n’avez encore créé aucun monde.';

  @override
  String get meNoWorldsYet => 'Aucun monde pour le moment.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'Gemmes rouges';

  @override
  String get gemsPink => 'Gemmes roses';

  @override
  String get gemsTop => 'Recharger';

  @override
  String get gemsBuy => 'Acheter des gemmes';

  @override
  String get gemsRecords => 'Historique';

  @override
  String get gemsUnableLoad => 'Impossible de charger les gemmes.';

  @override
  String get settingsLogOutAccount => 'Vous déconnecter de votre compte ?';

  @override
  String get settingsLogOut => 'Se déconnecter';

  @override
  String get settingsFeedback => 'Commentaires';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsAboutUs => 'À propos de nous';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsBlockedUsers => 'Utilisateurs bloqués';

  @override
  String get settingsJoinDiscord => 'Rejoindre Discord';

  @override
  String get meUserUnblocked => 'Utilisateur débloqué';

  @override
  String get meNoBlockedUsersYet => 'Aucun utilisateur bloqué pour le moment.';

  @override
  String get settingsAgreeTermsContinue =>
      'Acceptez nos conditions pour continuer.';

  @override
  String get settingsDeleteAccount => 'Supprimer votre compte ?';

  @override
  String get settingsAccountDeletionAgreement =>
      'Accord de suppression du compte';

  @override
  String get settingsEnsureSecurityAccount =>
      'Pour assurer la sécurité de votre compte, veuillez prendre connaissance des conséquences de sa suppression.\n\nLa suppression du compte est différente de la déconnexion et ne peut pas être annulée. Vos données privées, notamment les personnages créés, l’historique de recherche, les conversations avec les personnages, vos favoris, vos souvenirs, les données d’interaction et les commandes, seront définitivement supprimées et ne pourront pas être récupérées.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      'Toutes les gemmes inutilisées, achetées ou obtenues, seront définitivement perdues. En continuant, vous y renoncez volontairement. La suppression du compte ne donne pas automatiquement droit à un remboursement.\n\nTous les avantages restants de votre abonnement seront également définitivement perdus et ne pourront pas être rétablis. Supprimer votre compte n’annule pas votre abonnement.';

  @override
  String get settingsIHaveReadAccountDeletion =>
      'J’ai lu l’accord de suppression du compte';

  @override
  String get settingsCurrentLoginAccount => 'Compte actuellement connecté :';

  @override
  String get profileSaveFailed =>
      'Impossible d’enregistrer votre profil. Veuillez réessayer.';

  @override
  String get meSignInFailed => 'Échec de la connexion. Veuillez réessayer.';

  @override
  String get meCompleteProfileContinue =>
      'Complétez votre profil pour continuer.';

  @override
  String get meSelectGenderAge =>
      'Veuillez sélectionner votre genre et votre âge.';

  @override
  String get meSelectGender => 'Veuillez sélectionner votre genre.';

  @override
  String get meSelectAge => 'Veuillez sélectionner votre âge.';

  @override
  String get meRequired => 'Obligatoire';

  @override
  String get mePersonalizeWorldoExperience =>
      'Personnalisez votre expérience Worldo';

  @override
  String get meSignIn => 'Se connecter';

  @override
  String get meBack => 'Retour';

  @override
  String get meSkip => 'Passer';

  @override
  String get meContinueGoogle => 'Continuer avec Google';

  @override
  String get meContinueApple => 'Continuer avec Apple';

  @override
  String get meSignUpClaimPremium => 'Inscrivez-vous pour obtenir Premium';

  @override
  String get meSignUpContinue => 'Inscrivez-vous pour continuer';

  @override
  String get meAccountLoggedAnotherDevice =>
      'Votre compte est connecté sur un autre appareil.';

  @override
  String get premiumSubscription => 'Abonnement';

  @override
  String get gemsClaimFailed => 'Échec de l’obtention.';

  @override
  String get gemsCheckFailed => 'Échec du check-in.';

  @override
  String get gemsFollowFailed => 'Impossible de suivre cet utilisateur.';

  @override
  String get gemsTaskUpdateFailed => 'Échec de la mise à jour de la tâche.';

  @override
  String get gemsClaimSuccessful => 'Récompense obtenue !';

  @override
  String get gemsUnableLoadGemPacks =>
      'Impossible de charger les packs de gemmes.';

  @override
  String get gemsNoGemPacksAvailable => 'Aucun pack de gemmes disponible.';

  @override
  String get gemsUnableLoadGemTasks =>
      'Impossible de charger les tâches de gemmes.';

  @override
  String get gemsJoinUs => 'rejoignez-nous';

  @override
  String get gemsClaim => 'Obtenir';

  @override
  String get gemsClaimed => 'Obtenu';

  @override
  String get meDailyCheck => 'Check-in quotidien';

  @override
  String get gemsDailyCheckInReward => 'Obtenez 100';

  @override
  String get meCheck => 'Faire le check-in';

  @override
  String get meCheckSuccessful => 'Check-in effectué !';

  @override
  String get meGooglePlayUnavailable => 'Google Play est indisponible.';

  @override
  String get mePurchaseFailed => 'Échec de l’achat.';

  @override
  String get gemsEarned => 'Obtenues';

  @override
  String get gemsSpent => 'Dépensées';

  @override
  String get gemsPurchase => 'Achat';

  @override
  String get gemsGemRecords => 'Historique des gemmes';

  @override
  String get gemsUnableLoadRecords => 'Impossible de charger l’historique.';

  @override
  String get gemsNoGemRecordsYet =>
      'Aucun historique de gemmes pour le moment.';

  @override
  String get meAbout => 'À propos';

  @override
  String get meEmailCopied => 'Adresse e-mail copiée';

  @override
  String get mePurchasingPremium => 'Achat de Premium en cours';

  @override
  String get mePurchaseSuccessful => 'Achat réussi !';

  @override
  String get meWorldoPremiumSubscription =>
      'Votre abonnement Worldo Premium est désormais actif.';

  @override
  String get meMyBalance => 'Mon solde';

  @override
  String get meSoldOut => 'Épuisé';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession =>
      'Une session utilisateur complète est requise pour la liste des modèles';

  @override
  String get memoryModelListPermissionDenied =>
      'Accès à la liste des modèles refusé pour ce monde';

  @override
  String get memorySaveFailed => 'Échec de l’enregistrement';

  @override
  String get memorySaveResultNotConfirmed =>
      'Résultat de l’enregistrement non confirmé';

  @override
  String get memoryChooseModel => 'Choisir un modèle';

  @override
  String get memoryMaxTokenLimit => 'Limite maximale de tokens de mémoire';

  @override
  String get memoryNoModelsAvailable => 'Aucun modèle disponible';

  @override
  String get memoryRetryRanges => 'Plages de nouvelle tentative';

  @override
  String get memoryCurrentUsage => 'Votre utilisation actuelle de la mémoire';

  @override
  String memoryMinGems({required String min}) {
    return '$min gemmes';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min–$max gemmes';
  }

  @override
  String memoryStart({required String memoryStart}) {
    return 'mémoire $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return 'mémoire $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable => 'Paramètres de mémoire indisponibles';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Play a mis trop de temps à répondre. Veuillez réessayer.';

  @override
  String get premiumSubscriptionsNotSupported =>
      'Les abonnements ne sont pas pris en charge par Google Play sur cet appareil.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'La connexion à Google Play a été perdue. Veuillez réessayer.';

  @override
  String get premiumPurchaseCanceled => 'Achat annulé.';

  @override
  String get premiumReportFailed => 'Échec de la transmission de l’achat.';

  @override
  String get premiumVerifyFailed =>
      'Nous n’avons pas pu vérifier votre abonnement. Veuillez contacter l’assistance.';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Play est temporairement indisponible. Veuillez réessayer plus tard.';

  @override
  String get premiumGooglePlayBilling =>
      'La facturation Google Play est indisponible. Veuillez vérifier votre compte Play et vos paramètres de paiement.';

  @override
  String get premiumSubscriptionUnavailable =>
      'Cet abonnement Premium est actuellement indisponible sur Google Play.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play n’a pas pu effectuer cet achat Premium. Veuillez réessayer.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'Vous possédez déjà cet abonnement sur Google Play.';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Play n’a pas trouvé l’abonnement à modifier. Veuillez consulter Gérer les abonnements.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Impossible de se connecter à Google Play. Vérifiez votre connexion Internet et réessayez.';

  @override
  String get premiumInsufficientFunds =>
      'Le solde de votre moyen de paiement est insuffisant. Mettez-le à jour dans Google Play et réessayez.';

  @override
  String get premiumGoogleAccountIneligible =>
      'Votre compte Google Play n’est pas éligible à cette offre d’abonnement.';

  @override
  String get premiumAppStoreFailedComplete =>
      'L’App Store n’a pas pu effectuer cet achat Premium. Veuillez réessayer.';

  @override
  String get premiumFailedConnectAppStore =>
      'Impossible de se connecter à l’App Store. Vérifiez votre connexion Internet et réessayez.';

  @override
  String get premiumAppStoreTookTooLong =>
      'L’App Store a mis trop de temps à répondre. Veuillez réessayer.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'L’App Store a rencontré une erreur système. Veuillez réessayer plus tard.';

  @override
  String get premiumRegionUnavailable =>
      'Cet abonnement Premium n’est pas disponible dans la région de votre App Store.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'Cette application ne peut pas effectuer cette demande à l’App Store. Contactez l’assistance.';

  @override
  String get premiumPurchaseNotSupported =>
      'Cet achat n’est pas pris en charge sur cet appareil ou cette version du système.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'La fenêtre d’achat de l’App Store n’a pas pu s’ouvrir. Revenez dans l’application et réessayez.';

  @override
  String get premiumAppStoreFailedAccept =>
      'L’App Store n’a pas pu accepter cette quantité d’achat. Contactez l’assistance.';

  @override
  String get premiumAppStoreUnavailable =>
      'Cet abonnement Premium est actuellement indisponible sur l’App Store.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'Les achats ne sont pas autorisés sur cet appareil. Vérifiez votre compte Apple et les restrictions d’achat.';

  @override
  String get premiumAppleAccountNotEligible =>
      'Votre compte Apple n’est pas éligible à cette offre d’abonnement.';

  @override
  String get premiumSubscriptionOffer =>
      'Cette offre d’abonnement est indisponible. Actualisez la page et réessayez.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'L’App Store n’a pas pu accepter le prix de cette offre. Actualisez la page et réessayez.';

  @override
  String get premiumAppStoreFailedVerify =>
      'L’App Store n’a pas pu vérifier cette offre d’abonnement. Contactez l’assistance.';

  @override
  String get premiumSubscriptionOfferFailed =>
      'Cette offre d’abonnement n’a pas pu être préparée. Actualisez la page et réessayez.';

  @override
  String get premiumAddPaymentMethodApple =>
      'Ajoutez un moyen de paiement à votre compte Apple, puis réessayez.';

  @override
  String get premiumAppCannotMakePurchases =>
      'Cette application ne peut pas effectuer d’achats sur l’App Store. Contactez l’assistance.';

  @override
  String get premiumAppStoreRequestRejected =>
      'L’App Store n’a pas pu accepter cette demande d’achat. Réessayez ou contactez l’assistance.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'L’accès au service cloud Apple a été refusé. Vérifiez les autorisations de votre compte Apple.';

  @override
  String get premiumFailedConnectApple =>
      'Impossible de se connecter aux services Apple. Vérifiez votre connexion Internet et réessayez.';

  @override
  String get premiumAccess2AppleCloudService =>
      'L’accès au service cloud Apple a été révoqué. Vérifiez les paramètres de votre compte Apple.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Acceptez les dernières conditions de confidentialité Apple dans votre compte Apple, puis réessayez.';

  @override
  String get premiumAppStoreWindowFailed =>
      'La fenêtre de l’App Store n’a pas pu être configurée. Contactez l’assistance.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'La fenêtre de l’App Store a mis trop de temps à s’ouvrir. Veuillez réessayer.';

  @override
  String get premiumReturnAppTryPurchase =>
      'Revenez dans l’application et réessayez votre achat.';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Play est indisponible. Vérifiez qu’il est installé et que vous êtes connecté.';

  @override
  String get premiumIs4Subscription =>
      'Cet abonnement Premium est actuellement indisponible dans la boutique. Actualisez la page et réessayez.';

  @override
  String get premiumSubscriptionFailed =>
      'Cet abonnement Premium n’a pas pu être préparé. Actualisez la page et réessayez.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'La boutique n’a pas pu ouvrir cet achat Premium. Veuillez réessayer.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'L’abonnement d’origine n’a pas été trouvé dans Google Play. Veuillez consulter Gérer les abonnements.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'Cet abonnement utilise une autre identité d’achat. Actualisez la page ou contactez l’assistance.';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play ne peut pas encore modifier cet abonnement. Veuillez consulter Gérer les abonnements.';

  @override
  String get premiumPlanChangePending =>
      'Un achat App Store pour cette formule est encore en cours de traitement. Attendez qu’il se termine.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'Impossible de charger les formules Premium depuis l’App Store. Veuillez réessayer.';

  @override
  String get premiumPurchasePreparation =>
      'La préparation de l’achat a expiré. Veuillez réessayer.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'L’App Store a renvoyé un résultat d’achat inconnu. Vérifiez votre abonnement avant de réessayer.';

  @override
  String get premiumPurchasesUnavailable =>
      'Les achats sont actuellement indisponibles.';

  @override
  String get premiumAutoRenewsCancelAnytime =>
      'Renouvellement automatique. Résiliation à tout moment.';

  @override
  String get premiumSubscribed => 'Abonné';

  @override
  String get premiumAlsoIncluded => 'Également inclus';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'Gemmes roses';

  @override
  String get premiumRedGems => 'Gemmes rouges';

  @override
  String get premiumExtraDailyCheck => 'Bonus de check-in quotidien';

  @override
  String get premiumDailyCheck => 'Check-in quotidien';

  @override
  String get premiumClaimedMonthly => 'Obtenues chaque mois';

  @override
  String get premiumBilledMonthly => 'Facturé chaque mois';

  @override
  String premiumSaveSavings({required String savings}) {
    return 'Économisez $savings %';
  }

  @override
  String get premiumSubscribe => 'S’abonner';

  @override
  String get premiumActiveYearlySubscription =>
      'Un abonnement Premium annuel actif ne peut pas être remplacé par une formule mensuelle.';

  @override
  String get premiumAlreadyHaveActive =>
      'Vous avez déjà un abonnement Premium actif.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'Vous êtes déjà abonné à Premium $label.';
  }

  @override
  String get premiumPreviousPurchasePending =>
      'Votre précédent achat Premium est encore en cours de confirmation.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Utilisez la boutique d’origine pour passer à une formule Premium supérieure.';

  @override
  String get premiumResolveCurrent =>
      'Réglez la situation de votre abonnement actuel dans la boutique avant d’effectuer un achat.';

  @override
  String get premiumPurchaseUnavailable =>
      'L’achat de Premium est actuellement indisponible.';

  @override
  String get premiumUnableVerifyPurchase =>
      'Impossible de vérifier votre éligibilité à l’achat. Veuillez réessayer.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      'La boutique n’a pas pu vérifier cet achat Premium.';

  @override
  String get premiumPurchaseDoesNotMatch =>
      'Cet achat Premium ne correspond pas à la formule sélectionnée.';

  @override
  String get premiumMessagePurchaseCanceled =>
      'Cet achat Premium a été annulé.';

  @override
  String get premiumPurchaseRevoked => 'Cet achat Premium a été révoqué.';

  @override
  String get premiumNotification => 'Notification';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premium est actif dans votre abonnement et ne permet pas de passer à une formule inférieure.';

  @override
  String get premiumGot => 'Compris';

  @override
  String get gemBalancePromptInsufficientGems => 'Gemmes insuffisantes';

  @override
  String get gemBalancePromptLowGems => 'Peu de gemmes';

  @override
  String get appPressBackExit => 'Appuyez à nouveau sur Retour pour quitter.';

  @override
  String get appReportSubmitted => 'Signalement envoyé';

  @override
  String get appReportFailed => 'Échec du signalement';

  @override
  String get appUpdateRequired => 'Mise à jour requise';

  @override
  String get appUpdateContent =>
      'Mettez à jour vers la dernière version pour continuer à utiliser Worldo.';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'Version $versionName';
  }

  @override
  String get appUpdateCheckFailed =>
      'Impossible d’actualiser l’état de mise à jour. Mettez à jour pour continuer.';

  @override
  String get appUpdate => 'Mettre à jour maintenant';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabel copié';
  }

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonImageLoadFailed => 'Échec du chargement de l’image';

  @override
  String get commonPageNotFound => 'Page introuvable.';

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
    return 'Le LLM génère votre premier Tick. Cela peut prendre un instant$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return 'Dernière version : V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return 'Enregistrez $missingSections avant de créer.';
  }

  @override
  String get createCharacterRoleHint => 'Le rôle du personnage dans le worldo.';

  @override
  String get createCharacterMannerHint =>
      'La façon de parler et de se comporter du personnage, qui détermine ses dialogues.';

  @override
  String get createCharacterGoalHint =>
      'L’objectif ou l’orientation comportementale du personnage, qui détermine ses actions.';

  @override
  String get createCharacterBackgroundHint =>
      'Le passé et les relations du personnage.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return 'demande à rejoindre $world$worldIdSuffix';
  }

  @override
  String get memoryModel => 'Mémoire et modèle';

  @override
  String get premiumAccountMismatch =>
      'Les identifiants du compte ne correspondent pas à ceux de l’abonnement précédent.';

  @override
  String get worldRecap => 'Récapitulatif';

  @override
  String get inboxMissingJoinRequestId =>
      'Identifiant de la demande de participation manquant';

  @override
  String get loginTimedOut =>
      'Le délai de connexion a expiré. Veuillez réessayer.';

  @override
  String get loginConnectionFailed =>
      'Connexion impossible. Vérifiez votre connexion Internet et réessayez.';

  @override
  String get loginTemporarilyUnavailable =>
      'La connexion est temporairement indisponible. Veuillez réessayer plus tard.';

  @override
  String get recapUnlockHeading => 'Débloque le récapitulatif';

  @override
  String get recapUpsellDescription =>
      'Retrouvez le fil de votre histoire grâce à un récapitulatif complet de chaque rebondissement, choix et personnage rencontré.';

  @override
  String get recapShowEarlier => 'Voir les récapitulatifs précédents';

  @override
  String get recapEmpty =>
      'Le récapitulatif apparaîtra ici au fil de l’histoire.';

  @override
  String get chatMessageAsNarrator =>
      'Envoyer un message en tant que narrateur';

  @override
  String chatMessageAsCharacter({required String name}) {
    return 'Envoyer un message en tant que $name';
  }

  @override
  String get chatNarratorSpeaker => 'le narrateur';

  @override
  String get chatYourCharacterSpeaker => 'votre personnage';

  @override
  String chatSpeakingAs({required String speaker}) {
    return 'Vous parlez en tant que $speaker';
  }

  @override
  String get chatSwitchCharacter => 'Passer au personnage';

  @override
  String get chatSwitchNarration => 'Passer à la narration';

  @override
  String chatOpenLocation({required String locationName}) {
    return 'Ouvrir $locationName';
  }

  @override
  String get chatRetryMessage => 'Réessayer d’envoyer le message';

  @override
  String get blockedReportFailed =>
      'L’utilisateur a été bloqué, mais le signalement a échoué.';

  @override
  String get storeConnectionFailed =>
      'Connexion à la boutique impossible. Veuillez réessayer.';

  @override
  String get storeProductUnavailable =>
      'Ce produit est actuellement indisponible.';

  @override
  String get storeDevicePurchasesUnavailable =>
      'Les achats ne sont pas disponibles sur cet appareil.';

  @override
  String get worldHistoryRequestFailed =>
      'Échec du chargement de l’historique du monde';

  @override
  String get genericError => 'Une erreur s’est produite';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': 'Premium $plan, $price par an',
      'other': 'Premium $plan, $price par mois',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => 'Échec de la suppression';

  @override
  String get developerGatewaySignatureFailed =>
      'Échec de la vérification de la signature du Gateway';

  @override
  String get developerEndpointsSaved =>
      'Enregistré. Les nouvelles requêtes utiliseront les points de terminaison configurés.';

  @override
  String get developerAdjustRestartRequired =>
      'Redémarrez l’application pour appliquer l’environnement Adjust.';

  @override
  String developerRecapSetting({required String mode}) {
    return 'Récapitulatif du monde : $mode';
  }

  @override
  String get developerRecapPreview => 'Aperçu du récapitulatif du monde';

  @override
  String get developerRecapPreviewDescription =>
      'Remplace temporairement le statut d’abonnement et le récapitulatif dans le panneau du monde. Se réinitialise au redémarrage de l’application.';

  @override
  String get developerResetFailed => 'Échec de la réinitialisation';

  @override
  String get developerRecapOff => 'Désactivé (selon l’abonnement)';

  @override
  String get developerRecapLocked => 'Verrouillé · sans abonnement';

  @override
  String get developerRecapEmpty => 'Abonné · pas encore généré';

  @override
  String get developerRecapSample => 'Abonné · exemple de récapitulatif';

  @override
  String get developerRecapLive => 'Abonné · récapitulatif réel';

  @override
  String get chatEditFreeUsesExhausted =>
      'Vous n’avez plus de modifications gratuites.';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'Abonnement : $selection';
  }

  @override
  String get developerMembershipDescription =>
      'Modifie temporairement le statut d’abonnement de ce compte sur tous les écrans. Le serveur utilise toujours le statut réel du compte. Le statut est rétabli au redémarrage de l’app.';

  @override
  String get developerMembershipOff => 'Désactivé (abonnement réel)';

  @override
  String get developerMembershipYearly => 'Premium · annuel';

  @override
  String get developerMembershipMonthly => 'Premium · mensuel';

  @override
  String get developerMembershipNone => 'Sans abonnement';

  @override
  String get originStartBySelectingRole =>
      'Commencez par choisir votre personnage';

  @override
  String get originRecommendedStart => 'Départ recommandé';

  @override
  String get originStoryOpening => 'Début de l’histoire';

  @override
  String get originOpeningLocation => 'Lieu de départ';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names se trouvent actuellement à\n$locationName',
      one: '$names se trouve actuellement à\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return 'Début de l’histoire\n$locationName';
  }

  @override
  String get chatCharacterMovement => 'Déplacement des personnages';

  @override
  String get rateWorldoTitle => 'Évaluez Worldo';

  @override
  String get rateWorldoMessage =>
      'Que pensez-vous de Worldo ? Votre avis compte pour nous.';

  @override
  String rateWorldoStars({required int count}) {
    return '$count étoiles';
  }

  @override
  String get rateWorldoFeedbackHint =>
      'Dites-nous comment améliorer votre expérience';

  @override
  String get rateWorldoThanks => 'Merci pour votre avis !';

  @override
  String get rateWorldoFeedbackSaved => 'Votre avis a été enregistré.';

  @override
  String rateWorldoRewardMessage({required int gems}) {
    return 'Votre avis nous aide à nous améliorer. Recevez $gems Gemmes pour vous remercier.';
  }

  @override
  String get rateWorldoStoreFailed =>
      'Impossible d’ouvrir la boutique d’applications. Veuillez réessayer.';

  @override
  String gemsDailyResetsIn({required String time}) {
    return 'Réinitialisation dans $time';
  }
}

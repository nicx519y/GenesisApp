// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get imageGifUnsupported => 'Las animaciones GIF no son compatibles.';

  @override
  String get worldProgressComplete => 'Avance completado';

  @override
  String a11ySwitchMode({required String label}) {
    return 'Cambiar al modo $label';
  }

  @override
  String a11yEditItem({required String title}) {
    return 'Editar $title';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return 'Tarjeta de personaje $index de $count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'Editar inspiración $index';
  }

  @override
  String a11yInsert({required String label}) {
    return 'Insertar $label';
  }

  @override
  String get a11yMembership => 'Membresía';

  @override
  String get a11yOpenWorldo => 'Abrir Worldo';

  @override
  String get a11yFilterGender => 'Filtrar por género';

  @override
  String get a11ySelectRole => 'Elige tu personaje';

  @override
  String get a11yLoadingMap => 'Cargando mapa';

  @override
  String get a11yBuildingWorld => 'Construyendo el mundo';

  @override
  String get a11yPremiumMembership => 'Membresía Premium';

  @override
  String get a11yProMembership => 'Membresía Pro';

  @override
  String get a11yRecommendedRole => 'Personaje recomendado';

  @override
  String get a11yLastMessage => 'Último mensaje';

  @override
  String get a11yRecentChat => 'Chat reciente';

  @override
  String get a11yAiReplyLoading => 'Cargando respuesta de AI';

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
      other: 'jugadores',
      one: 'jugador',
      zero: 'jugadores',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (Agregados / Máximo)';
  }

  @override
  String get createSixHours => '6 horas';

  @override
  String get createTwelveHours => '12 horas';

  @override
  String get createOneDay => '1 día';

  @override
  String get createOneWeek => '1 semana';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageChangeFailed =>
      'No se pudo cambiar el idioma. Inténtalo de nuevo.';

  @override
  String get purchasingGems => 'Comprando gemas';

  @override
  String get purchaseSuccessful => '¡Compra realizada!';

  @override
  String get okAction => 'Aceptar';

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get requestAction => 'Solicitar';

  @override
  String get requestedStatus => 'Solicitado';

  @override
  String get launchAction => 'Iniciar mundo';

  @override
  String get tickNowAction => 'Tick ahora';

  @override
  String get writePostHint => 'Escribe una publicación';

  @override
  String get newPostTitle => 'Nueva publicación';

  @override
  String get aiIsGenerating => 'La AI está generando';

  @override
  String get generatingCustomizedWorldWait =>
      'Generando un mundo vivo y personalizado para ti.\nEspera un momento.';

  @override
  String get approvedStatus => 'Aprobado';

  @override
  String get rejectedStatus => 'Rechazado';

  @override
  String get awaitingApprovalStatus => 'Pendiente de aprobación';

  @override
  String get awaitingYourApprovalStatus => 'Pendiente de tu aprobación';

  @override
  String get liveYourWorld => 'VIVE TU MUNDO';

  @override
  String get signedOutMeDescription =>
      'Juega en mundos, crea worldo e invita a tus amigos,\ny continúa donde estés.';

  @override
  String get gemTaskLaunchWorldHint =>
      'Abre un Worldo que te guste e inicia tu propio mundo.';

  @override
  String get gemTaskInviteFriendHint =>
      'Abre un mundo y toca Invitar en el panel de detalles.';

  @override
  String get gemTaskWriteCommentHint =>
      'Abre un Worldo que te guste y escribe una publicación en Discusión.';

  @override
  String get gemTaskRequestJoinHint =>
      'Abre un mundo al que aún no te hayas unido y solicita unirte.';

  @override
  String get gemTaskSendMessageHint => 'Envía mensajes en tu mundo.';

  @override
  String get gemTaskProgressWorldHint =>
      'Abre un mundo en el que estés jugando y toca Tick ahora.';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'Mundo';

  @override
  String get userLabel => 'Usuario';

  @override
  String get meLabel => 'Yo';

  @override
  String get locationLabel => 'Ubicación';

  @override
  String get allLabel => 'Todos';

  @override
  String get maleLabel => 'Masculino';

  @override
  String get femaleLabel => 'Femenino';

  @override
  String get nonBinaryLabel => 'No binario';

  @override
  String get forYouLabel => 'Para ti';

  @override
  String get userBlocked => 'Usuario bloqueado';

  @override
  String get purchaseCanceled => 'Compra cancelada.';

  @override
  String get purchasePending => 'Tu compra está pendiente.';

  @override
  String get purchaseConfirmationDelayed =>
      'La confirmación de la compra se está demorando. Vuelve a consultar más tarde.';

  @override
  String get purchaseFailed => 'La compra falló.';

  @override
  String get yearlyPlan => 'Anual';

  @override
  String get monthlyPlan => 'Mensual';

  @override
  String get proSubscriptionTagline => 'Profundiza en cada Worldo que juegas.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, con facturación anual';
  }

  @override
  String expiresOn({required String date}) {
    return 'Vence el $date';
  }

  @override
  String get activeStatus => 'ACTIVA';

  @override
  String get expiredStatus => 'Vencida';

  @override
  String updatedAt({required String timestamp}) {
    return 'Actualizado $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => 'No se pudo cargar. Reintentar';

  @override
  String get loadMoreAction => 'Cargar más';

  @override
  String get gemPurchaseRecord => 'Compra de gemas';

  @override
  String get taskRewardRecord => 'Recompensa de tarea';

  @override
  String get worldProgressRecord => 'Avance del mundo';

  @override
  String get directMessageRecord => 'Mensaje directo';

  @override
  String get gemRecord => 'Registro de gemas';

  @override
  String get runATickTask => 'Haz un Tick';

  @override
  String get runATickTaskDescription =>
      'Abre un mundo en el que estés jugando y toca Tick ahora.';

  @override
  String get someoneFallback => 'Alguien';

  @override
  String get aCharacterFallback => 'un personaje';

  @override
  String get thisWorld => 'este mundo';

  @override
  String get noWorldEventsYet => 'Aún no hay eventos en el mundo.';

  @override
  String get globalLabel => 'Global';

  @override
  String get eventLabel => 'Evento';

  @override
  String get characterDestinations => 'Destinos de los personajes';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName $direction $locationName';
  }

  @override
  String get cameToDirection => 'llegó a';

  @override
  String get wentToDirection => 'fue a';

  @override
  String get hasComeToDirection => 'ha llegado a';

  @override
  String get hasGoneToDirection => 'ha ido a';

  @override
  String get waitForReplyToSendMore =>
      'Espera una respuesta para enviar más mensajes';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes nuevos',
      one: '$count mensaje nuevo',
      zero: '$count mensajes nuevos',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation =>
      'Selecciona un personaje predefinido';

  @override
  String get enterNameValidation => 'Ingresa un nombre';

  @override
  String get enterIdentityValidation => 'Ingresa una identidad';

  @override
  String get waitForProfileLoading =>
      'Espera a que termine de cargar el perfil.';

  @override
  String get imageUploadFailed => 'No se pudo subir la imagen.';

  @override
  String get photoAccessDenied => 'Acceso a las fotos denegado';

  @override
  String get feedbackSubmitted => 'Comentarios enviados';

  @override
  String get feedbackFailed => 'No se pudieron enviar los comentarios';

  @override
  String get worldoDetailUnavailable =>
      'Los detalles de Worldo no están disponibles.';

  @override
  String get publishAction => 'Publicar';

  @override
  String get publishingStatus => 'Publicando...';

  @override
  String get publishFailed => 'No se pudo publicar';

  @override
  String get publishChangesBeforeLeaving =>
      '¿Publicar los cambios antes de salir?';

  @override
  String get noChangesToPublish => 'No hay cambios para publicar.';

  @override
  String get completeOpeningRequiredToPublish =>
      'Se necesita una apertura completa para publicar';

  @override
  String get publishResponseMissingOriginId =>
      'La publicación no devolvió un ID de Worldo.';

  @override
  String get worldoIdRequired => 'Se necesita un ID de Worldo.';

  @override
  String loadFailedWithReason({required String reason}) {
    return 'No se pudo cargar: $reason';
  }

  @override
  String get imageSelectionFailed => 'No se pudo seleccionar la imagen';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID: $oid\nÚltima versión: $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID: $wid\nPropietario: $owner';
  }

  @override
  String get sendFailed => 'No se pudo enviar';

  @override
  String get selectARole => 'Selecciona un personaje';

  @override
  String get timeLabel => 'Tiempo';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID: $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID: $oid · Creador: $creator';
  }

  @override
  String get worldoMetricExplanation =>
      'Este worldo actualiza el {Nombre del indicador} de cada personaje en cada avance, expresado en {Unidad}. Cada personaje comienza en {Valor inicial}, y el valor puede cambiar entre {Cambio mínimo} y {Cambio máximo}.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return 'Inicia un $worldo para generar\ntu propio mundo';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return 'Costo estimado del próximo mensaje: $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount gemas';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'Eliminar mundo $worldName';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername juega como $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return '¡Worldo $worldName iniciado!';
  }

  @override
  String worldoCreated({required String worldName}) {
    return '¡Worldo $worldName creado!';
  }

  @override
  String worldoPublished({required String worldName}) {
    return '¡Worldo $worldName publicado!';
  }

  @override
  String get createTimeout => 'Se agotó el tiempo para crear Worldo.';

  @override
  String get publishTimeout => 'Se agotó el tiempo para publicar Worldo';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return 'Solicitaste unirte a $worldName$worldId';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge solicita unirse a $worldName$worldId';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge comentó en tu worldo';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge te respondió';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge indicó que le gusta tu comentario';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge te envió un mensaje';
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
    return 'Usos gratuitos de inspiración restantes: $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Usos gratuitos de edición restantes: $remaining\n$action';
  }

  @override
  String get getMoreAction => 'Obtener más >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName llegó a $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldo te permite crear, descubrir y entrar en mundos impulsados por AI, llenos de personajes, historias y eventos en evolución. Chatea con personajes de AI, juega con amigos y haz avanzar cada mundo mediante escenas y decisiones inmersivas.\n\nNuestra app ofrece una nueva forma de vivir historias interactivas: participando desde dentro del mundo, además de leerlas. Si tienes alguna pregunta, contáctanos en $contactEmail.';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy, $termsOfUse y $endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return 'Al continuar, aceptas nuestros $terms, $privacyPolicy y $endUserLicenseAgreement';
  }

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get terms => 'Términos';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get endUserLicenseAgreement => 'Acuerdo de licencia de usuario final';

  @override
  String existingAccountSignIn({required String signIn}) {
    return '¿Ya tienes una cuenta? $signIn';
  }

  @override
  String get signInAction => 'Inicia sesión.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return 'Has recibido $gemIcon$grantedAmount gemas.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return 'Hasta $amount gemas al mes y acceso completo a Premium.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /día';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/mes';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: Respuesta a $replyToName$replyToBadge: $content';
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
  String get homeLoadFailed => 'No se pudo cargar';

  @override
  String get homeRetry => 'Reintentar';

  @override
  String get homeEmptyDescription =>
      'Worldo es el punto de partida. Inícialo para crear un mundo vivo al que puedas entrar y hacer crecer.';

  @override
  String get homeWorldCharacter => 'Personaje';

  @override
  String get homeWorldSingleOtherPlayer => '· 1 jugador más';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· $otherPlayerCount jugadores más';
  }

  @override
  String get homeSignInUnavailable => 'Inicio de sesión no disponible';

  @override
  String get homeSignedOutTitle => 'Todos tus mundos en un solo lugar';

  @override
  String get homeSignedOutDescription =>
      'Inicia sesión para crear mundos y continuar tus historias.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return 'Propietario: $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID: $oid  Creador: $originator\nDescripción: $brief\nÚltima versión: $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID: $wid\nPropietario: $owner';
  }

  @override
  String get searchHistory => 'Historial de búsqueda';

  @override
  String get searchFailed => 'La búsqueda falló';

  @override
  String get searchNoResults => 'Sin resultados.';

  @override
  String get searchCancel => 'Cancelar';

  @override
  String get searchHint => 'Worldo, personajes, etiquetas';

  @override
  String get worldDetailOnlyWorldsLaunched =>
      'Solo puedes eliminar mundos que hayas iniciado tú solo.';

  @override
  String get worldDetailDelete => 'Eliminar';

  @override
  String get worldDetailNoCharacterStatusYet =>
      'Aún no hay estados de personajes.';

  @override
  String get worldDetailNoCharactersYet => 'Aún no hay personajes.';

  @override
  String get worldDetailProgressingWorld => 'Avanzando el mundo';

  @override
  String get worldDetailCompressingRecent =>
      'Comprimiendo recuerdos recientes\nAvanzando la línea temporal del mundo\nGenerando el siguiente momento de la historia\nActualizando las ubicaciones de los personajes';

  @override
  String get worldModelsDetail => 'Detalles';

  @override
  String get worldModelsLocations => 'Ubicaciones';

  @override
  String get worldModelsEvents => 'Eventos';

  @override
  String get worldModelsStatus => 'Estado';

  @override
  String get worldDetailUnavailable => 'No disponible';

  @override
  String worldActionFailed({required String actionLabel}) {
    return 'No se pudo completar: $actionLabel';
  }

  @override
  String get worldDetailRequestJoinWorld => '¿Solicitar unirte a este mundo?';

  @override
  String get worldDetailRequest => 'Solicitar';

  @override
  String get worldDetailLaunchFailed => 'No se pudo iniciar el mundo';

  @override
  String get worldDetailNoSavedProfileFound =>
      'No se encontró ningún perfil guardado';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return 'Worldo de origen: $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => 'Invitar';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return '¡Únete a mi mundo \"$worldName\" en Worldo!\n$wid\nBusca este WID en Worldo para encontrarlo y unirte.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'Descripción del mundo';

  @override
  String get worldDetailCast => 'Personajes';

  @override
  String get worldDetailLinkCopiedShare =>
      'Enlace copiado. Compártelo con tus amigos.';

  @override
  String get worldMapAction => 'Mapa';

  @override
  String get worldInfoAction => 'Información';

  @override
  String worldLocationCount({required String pointsCount}) {
    return 'Ubicaciones ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => 'Jugador';

  @override
  String worldDetailGoal({required String goal}) {
    return 'Objetivo: $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet =>
      'Aún no hay detalles de los personajes.';

  @override
  String get worldDetailNoEventsYet => 'Aún no hay eventos.';

  @override
  String get worldDetailLoadEventsFailed =>
      'No se pudieron cargar los eventos.';

  @override
  String homeLocationID({required String id}) {
    return 'Ubicación $id';
  }

  @override
  String get homeBuildingWorld => 'CONSTRUYENDO EL MUNDO';

  @override
  String get worldMapLoadFailed => 'No se pudo cargar el mapa';

  @override
  String get worldMapZoomIn => 'Acercar el mapa';

  @override
  String get worldMapZoomOut => 'Alejar el mapa';

  @override
  String get worldDetailGlobal => 'Global';

  @override
  String get worldDetailLocation => 'Ubicación';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => 'Generando el primer Tick';

  @override
  String get worldFirstTickStatusLoadFailed =>
      'No se pudo cargar el estado de generación.';

  @override
  String get worldDetailNew => 'Nuevo';

  @override
  String get homeUnknownLocation => 'Ubicación desconocida';

  @override
  String get homeUnknownCharacter => 'Personaje desconocido';

  @override
  String get homeNewPlaceEmerged => 'Apareció un lugar nuevo';

  @override
  String get homeNewCharacterAppeared => 'Apareció un personaje nuevo';

  @override
  String get chatLocationUnavailable => 'Ubicación no disponible';

  @override
  String get chatRequestApprovalLaunch => 'Solicitar aprobación para iniciar';

  @override
  String get chatLoading => 'Cargando';

  @override
  String get chatQuotaCheckFailed =>
      'No se pudieron consultar los usos gratuitos. Inténtalo de nuevo.';

  @override
  String get chatInspirationSourceChanged =>
      'La fuente de inspiración cambió. Vuelve a abrir Inspiración.';

  @override
  String get chatInspiration => 'Inspiración';

  @override
  String get chatMessageCannotSend => 'Este mensaje ya no se puede enviar';

  @override
  String get chatMessageEmpty => 'El mensaje está vacío';

  @override
  String get chatConnectionFailed => 'No se pudo conectar con este chat';

  @override
  String get chatReplyChangedSelect =>
      'La respuesta cambió. Selecciona inspiración de nuevo.';

  @override
  String get chatSendConfirmFailed =>
      'No se pudo confirmar el envío del mensaje';

  @override
  String get chatNoNetworkConnection => 'Sin conexión a internet';

  @override
  String get chatRoundCannotContinue => 'Este turno no puede continuar';

  @override
  String get chatSourceRoundChanged => 'El turno de origen cambió';

  @override
  String get chatGo => 'Continuar';

  @override
  String get chatReplyActionUnavailable =>
      'Esta acción de respuesta ya no está disponible';

  @override
  String get chatRegenerateFailure => 'No se pudo regenerar';

  @override
  String get chatGoFailure => 'No se pudo continuar';

  @override
  String get chatEditFailure => 'No se pudo editar';

  @override
  String get chatInspirationFailure => 'No se pudo generar inspiración';

  @override
  String get chatJoinLocationFailed => 'No se pudo acceder a esta ubicación';

  @override
  String get chatInactive => 'Este chat ya no está activo';

  @override
  String get chatChatroomUnavailable => 'Sala de chat no disponible';

  @override
  String get chatFailedConfirmReplyAction =>
      'No se pudo confirmar la acción de respuesta';

  @override
  String get chatLeastOneMessageMustRemain =>
      'Debe quedar al menos un mensaje.';

  @override
  String get chatReplyNotEditable => 'Esta respuesta no se puede editar';

  @override
  String get chatReplyAlreadyFixed => 'Esta respuesta ya es definitiva';

  @override
  String get chatReplyEditorFrozen => 'El editor de respuestas está bloqueado';

  @override
  String get chatResolvePreviousSaveBefore =>
      'Resuelve el guardado anterior antes de modificar su borrador';

  @override
  String get chatStaleReplyEditor =>
      'El editor de respuestas está desactualizado';

  @override
  String get chatPreviousSaveResultUncertain =>
      'El resultado del guardado anterior es incierto; vuelve a cargar antes de editar';

  @override
  String get chatCandidateMissing => 'La opción ya no existe';

  @override
  String get chatBatchSupportsMost100Changes =>
      'Un lote admite como máximo 100 cambios';

  @override
  String get chatMissingStableMessageIdentity =>
      'Falta un identificador estable del mensaje';

  @override
  String get chatEditTargetHasChanged =>
      'El elemento que estás editando cambió';

  @override
  String get chatMessageNotEditable => 'Este mensaje no se puede editar';

  @override
  String get chatReplyNoLongerEditable =>
      'Esta respuesta ya no se puede editar';

  @override
  String get chatEditorOpenFailed => 'No se pudo abrir el editor';

  @override
  String get chatInactiveDuringEdit => 'Este chat ya no está activo.';

  @override
  String get chatEditMessage => 'Editar mensaje';

  @override
  String get chatSave => 'Guardar';

  @override
  String get chatEdit => 'Editar';

  @override
  String get chatRegenerate => 'Regenerar';

  @override
  String get chatRegenerateUnavailable => 'Este turno no se puede regenerar';

  @override
  String get chatGenerate10Replies => 'Puedes generar hasta 10 respuestas.';

  @override
  String get chatPreviousReply => 'Respuesta anterior';

  @override
  String get chatNextReply => 'Respuesta siguiente';

  @override
  String get chatCopy => 'Copiar';

  @override
  String get chatReport => 'Reportar';

  @override
  String get chatCopied => 'Copiado';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes nuevos',
      one: '$count mensaje nuevo',
      zero: '$count mensajes nuevos',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'Mencionar';

  @override
  String get chatCharacters => 'Personajes';

  @override
  String get chatNoCharacters => 'Sin personajes';

  @override
  String get chatNoLocations => 'Sin ubicaciones';

  @override
  String get chatHere => 'Aquí';

  @override
  String get chatLoadEarlierMessages => 'Cargar mensajes anteriores';

  @override
  String get chatText => 'Escribe...';

  @override
  String get chatLocationRoster => 'TÚ';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'Todo el contenido se genera con AI y es ficticio. Cualquier parecido con personas, eventos o lugares reales es coincidencia.';

  @override
  String get homeRecent => 'Reciente';

  @override
  String get worldoUnableSavePreference =>
      'No se pudo guardar tu preferencia. Inténtalo de nuevo.';

  @override
  String get worldoFilterGender => 'Filtrar por género';

  @override
  String get worldoNoData => 'Sin datos';

  @override
  String get worldoAll => 'Todos';

  @override
  String get worldoDetailSelectRole => 'Elige tu personaje';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'Creador: $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Editar Worldo';

  @override
  String get worldoDetailWorldoBrief => 'Descripción de Worldo';

  @override
  String get worldoDetailNewPost => 'Nueva publicación';

  @override
  String get worldoDetailWritePost => 'Escribe una publicación';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'Discusión ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => 'Ver todo >';

  @override
  String get worldoDetailPlayingWorld => 'Mundo en curso';

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
    return 'Personajes ($length)';
  }

  @override
  String get worldoSend => 'Enviar';

  @override
  String get worldoPostFailed => 'No se pudo publicar';

  @override
  String get worldoImageUploadFailed => 'No se pudo subir la imagen';

  @override
  String get worldoLoadRepliesFailed => 'No se pudieron cargar las respuestas';

  @override
  String get worldoWriteReply => 'Escribe una respuesta';

  @override
  String worldoReplyName({required String replyToName}) {
    return 'Responder a $replyToName';
  }

  @override
  String get worldoPostDetail => 'Detalles de la publicación';

  @override
  String get worldoPostUnavailable => 'Publicación no disponible';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'Todas las respuestas $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return 'Ver las $replyCount respuestas';
  }

  @override
  String get worldoLikeFailed => 'No se pudo indicar Me gusta';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return 'Ver las $replyCount respuestas';
  }

  @override
  String get worldoUser => 'Usuario';

  @override
  String get worldoViewMore => 'Ver más >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'Discusión ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return 'Ver las $remainingReplyCount respuestas';
  }

  @override
  String get worldoReply => 'Responder';

  @override
  String get worldoDiscussTitle => 'Discusión';

  @override
  String get worldoLaunchLocationComesLife =>
      'Esta ubicación cobra vida cuando inicias el mundo.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      'Inicia este Worldo para explorar e interactuar aquí.';

  @override
  String get worldoLaunchRoleUnavailable =>
      'Este personaje ya no está disponible';

  @override
  String get worldoLaunchSelectRole => 'Elige tu personaje';

  @override
  String get worldoLaunchProfile => 'Tu perfil';

  @override
  String get worldoLaunchSuggested => 'Sugerido';

  @override
  String get worldoLaunchName => 'Nombre';

  @override
  String get worldoLaunchIdentity => 'Identidad';

  @override
  String get worldoLaunchPersonality => 'Personalidad';

  @override
  String get worldoLaunchGoal => 'Objetivo';

  @override
  String get worldoLaunchSetupRole => 'Configura tu personaje';

  @override
  String get worldoLaunchPreset => 'Predefinido';

  @override
  String get worldoLaunchCustom => 'Personalizado';

  @override
  String get worldoLaunchNoPresetRole => 'Sin personaje predefinido';

  @override
  String get worldoLaunchFilling => 'Completando...';

  @override
  String get worldoLaunchFillMyProfile => 'Completar con mi perfil';

  @override
  String get worldoLaunchLaunch => 'Iniciar mundo';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return '¡Worldo #$worldName iniciado!';
  }

  @override
  String get worldoLaunchEnter => 'Entrar';

  @override
  String get createAction => 'Crear';

  @override
  String get createWorldoTitle => 'Crear Worldo';

  @override
  String get createFailed => 'No se pudo crear';

  @override
  String get createNotesRequired =>
      'Se necesitan notas de actualización para publicar.';

  @override
  String get createActionInProgress => 'Esta acción ya está en curso.';

  @override
  String createCurrentVersion({required String version}) {
    return 'Versión actual: $version';
  }

  @override
  String get createChecking => 'Verificando...';

  @override
  String createSummaryName({required String name}) {
    return 'Nombre de Worldo: $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Descripción de Worldo: $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'Imagen de portada: $status';
  }

  @override
  String get createNotUploaded => 'No subida';

  @override
  String get createUploaded => 'Subida';

  @override
  String createSummarySettings({required String settings}) {
    return 'Configuración de Worldo: $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Tiempo de Worldo: $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Indicador de Worldo: $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
      zero: '$count días',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 personajes';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personajes: $names',
      one: '1 personaje: $names',
      zero: '0 personajes: $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'Sugerido: $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · Región: $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · Edificio: $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · Habitación: $count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
      zero: '$count eventos',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return 'Diálogo de personajes: $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'Narrador: $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return 'Imagen: $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return '¿Eliminar $itemLabel?';
  }

  @override
  String get createItemHasContentDeleteAnyway =>
      'Este elemento tiene contenido. ¿Eliminarlo de todos modos?';

  @override
  String get createImageUploadProgress => 'Se está subiendo la imagen.';

  @override
  String get createBasicsBasics => 'Datos básicos';

  @override
  String get createSaveInProgress => 'Ya se está guardando.';

  @override
  String get createRequiredBeforeSave =>
      'Completa todos los campos obligatorios antes de guardar.';

  @override
  String get createOpeningOpening => 'Apertura';

  @override
  String get createCharacterCharactersCreate =>
      'Personajes: Crea al menos un personaje.';

  @override
  String get createCharacterCharactersOnlyOne =>
      'Personajes: Solo se puede recomendar un personaje.';

  @override
  String get createBasicsBasicsWorldoName =>
      'Datos básicos: El nombre de Worldo es obligatorio.';

  @override
  String get createBasicsBasicsWorldoBrief =>
      'Datos básicos: La descripción de Worldo es obligatoria.';

  @override
  String get createBasicsBasicsCoverImage =>
      'Datos básicos: La imagen de portada es obligatoria.';

  @override
  String get createBasicsBasicsMetricMust =>
      'Datos básicos: El indicador debe ser JSON válido.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'Personaje #$characterIndex: El nombre es obligatorio.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'Personaje #$characterIndex: La identidad es obligatoria.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'Personaje #$characterIndex: La personalidad es obligatoria.';
  }

  @override
  String get createCharacterCharactersLeast =>
      'Personajes: Se necesita al menos un personaje.';

  @override
  String get createLocationLocationsCreate =>
      'Ubicaciones: Crea al menos una ubicación.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return 'Ubicación #$locationIndex: El nombre es obligatorio.';
  }

  @override
  String get createOpeningOpeningSelect =>
      'Apertura: Selecciona una ubicación y completa todos los elementos del diálogo.';

  @override
  String get createOpeningOpeningSelected =>
      'Apertura: La ubicación seleccionada ya no está disponible.';

  @override
  String get createOpeningCharacterOpening =>
      'Apertura: Un personaje seleccionado ya no está disponible.';

  @override
  String get createOpeningOpeningDialogue =>
      'Apertura: Un personaje del diálogo no está en la ubicación seleccionada. Abre Apertura para corregirlo.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return 'Diálogo de apertura no compatible: $type';
  }

  @override
  String get createCreating => 'Creando...';

  @override
  String get createDiscard => 'Descartar';

  @override
  String get createCharactersStep => 'Personajes (>=1)';

  @override
  String get createLocationsStep => 'Ubicaciones (>=1)';

  @override
  String get createStoryEventsOptional => 'Eventos de la historia (opcional)';

  @override
  String get createUpdateNotesRequiredPublish =>
      'Notas de actualización (obligatorias para publicar)';

  @override
  String get createWhatChangedVersion => '¿Qué cambió en esta versión?';

  @override
  String get createView => 'Ver';

  @override
  String get createNotStartedYet => 'Aún no se ha iniciado';

  @override
  String get createEdited => 'Editado';

  @override
  String get createPublishingWorldo => 'Publicando tu Worldo';

  @override
  String get createCreatingWorldo => 'Creando tu Worldo';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Preparando las actualizaciones de tu Worldo.\nEspera un momento.';

  @override
  String get createBringingWorldoLifeWait =>
      'Dando vida a tu Worldo.\nEspera un momento.';

  @override
  String get createDescribeIssue => 'Describe el problema';

  @override
  String get createSubmit => 'Enviar';

  @override
  String get createBasicsWorldoName => 'Nombre de Worldo *';

  @override
  String get createBasicsNameRequired => 'El nombre de Worldo es obligatorio.';

  @override
  String get createBasicsBriefRequired =>
      'La descripción de Worldo es obligatoria.';

  @override
  String get createBasicsCoverRequired =>
      'La imagen de portada es obligatoria.';

  @override
  String get createBasicsMetricInvalid => 'El indicador debe ser JSON válido.';

  @override
  String get createBasicsEgMainStreet => 'p. ej., Calle Principal';

  @override
  String get createBasicsWorldoBrief => 'Descripción de Worldo *';

  @override
  String get createBasicsBriefNote =>
      'Lo primero que ven los jugadores: el escenario, el conflicto central y lo que lo hace intrigante.';

  @override
  String get createBasicsHiddenNote =>
      'Las reglas ocultas y los antecedentes que impulsan la historia: intenciones, mecánicas y límites secretos.';

  @override
  String get createBasicsEgHalfShopsMain =>
      'p. ej., La mitad de las tiendas de la Calle Principal están tapiadas. Para el Día del Trabajo, el comercio más rico será dueño del pueblo.';

  @override
  String get createBasicsCoverImage => 'Imagen de portada *';

  @override
  String get createBasicsUpload => 'Subir';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'Se usa en tarjetas y páginas de detalles. Se recomienda ~768×1024 px. Formatos compatibles: JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden =>
      'Configuración de Worldo: oculta (opcional)';

  @override
  String get createBasicsEgBankerSecretly =>
      'p. ej., El banquero controla en secreto quién obtiene préstamos; quien se endeude demasiado puede quedar fuera.';

  @override
  String get createBasicsWorldoTimeOptional => 'Tiempo de Worldo (opcional)';

  @override
  String get createBasicsWorldoStartsStart =>
      'Este worldo comienza en {Hora de inicio}; cada vez que el usuario toca *avanzar*, la línea temporal avanza según {Tiempo por avance}.';

  @override
  String get createBasicsStartTime => 'Hora de inicio';

  @override
  String get createBasicsDateExample => 'p. ej., Día 1, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => 'Tiempo por avance';

  @override
  String get createBasicsEg8Hours3Days => 'p. ej., 8 horas / 3 días';

  @override
  String get createBasicsWorldoMetricOptional =>
      'Indicador de Worldo (opcional)';

  @override
  String get createBasicsMetricLabel => 'Nombre del indicador';

  @override
  String get createBasicsEgWealthGoalProgress =>
      'p. ej., Riqueza / Avance del objetivo';

  @override
  String get createBasicsLabelNote => 'Descripción del indicador';

  @override
  String get createBasicsDescribeWhatMetric =>
      'Describe qué mide este indicador';

  @override
  String get createBasicsUnit => 'Unidad';

  @override
  String get createBasicsEgCoins => 'p. ej., monedas / %';

  @override
  String get createBasicsRange => 'Rango de valores';

  @override
  String get createBasicsStarting => 'Valor inicial';

  @override
  String get createBasicsDeltaMin => 'Cambio mínimo';

  @override
  String get createBasicsDeltaMax => 'Cambio máximo';

  @override
  String get createBasicsSaving => 'Guardando...';

  @override
  String get createBasicsAdvancedSettings =>
      'Configuración avanzada (opcional)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'Personaje $index';
  }

  @override
  String get createCharacterSuggest => 'Recomendar';

  @override
  String get createCharacterAvatarOptional => 'AVATAR\n(opcional)';

  @override
  String get createCharacterName => 'Nombre *';

  @override
  String get createCharactersTitle => 'Personajes';

  @override
  String createCharacterLimit({required int count}) {
    return 'Puedes agregar hasta $count personajes.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'Personaje $index: El nombre es obligatorio.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'Personaje $index: La identidad es obligatoria.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'Personaje $index: La personalidad es obligatoria.';
  }

  @override
  String get createCharacterMinOne => 'Crea al menos un personaje.';

  @override
  String get createCharacterEnterName => 'Ingresa un nombre...';

  @override
  String get createCharacterIdentity => 'Identidad *';

  @override
  String get createCharacterEgHometownKidBack =>
      'p. ej., Alguien que regresa a su pueblo con una verdadera oportunidad';

  @override
  String get createCharacterPersonality => 'Personalidad *';

  @override
  String get createCharacterEgUnderdog =>
      'p. ej., Alguien en desventaja, con buenas intenciones pero poco capital';

  @override
  String get createCharacterGoalOptional => 'Objetivo (opcional)';

  @override
  String get createCharacterEgRichestOwner =>
      'p. ej., Ser el propietario más rico de la Calle Principal para el Día del Trabajo';

  @override
  String get createCharacterBackgroundHidden =>
      'Antecedentes: ocultos (opcional)';

  @override
  String get createCharacterEgLeftTownYears =>
      'p. ej., Se fue del pueblo hace años y volvió a una Calle Principal tapiada buscando una oportunidad.';

  @override
  String get createCharacterAddCharacter => '+ Agregar personaje';

  @override
  String get createLocationImageOptional => 'IMAGEN\n(opcional)';

  @override
  String get createCharacterSelectAvailable =>
      'Selecciona entre los personajes disponibles abajo';

  @override
  String get createCharacterInitialCharacters =>
      'Personajes iniciales (opcional)';

  @override
  String get createLocationStartingCharacters =>
      'Los personajes que comienzan aquí cuando empieza el worldo.';

  @override
  String get createCharacterAvailableSelect => 'Disponibles para seleccionar';

  @override
  String get createCharacterNoCharactersYet =>
      'Aún no hay personajes. Crea personajes y luego elige dónde comienzan.';

  @override
  String get createCharacterNoCharacters =>
      'No hay personajes disponibles. Todos ya tienen una ubicación inicial.';

  @override
  String get createLocationEveryL2L3Locations =>
      'También se eliminarán todas las ubicaciones L2 y L3 que contiene.';

  @override
  String get createLocationEveryL3Locations =>
      'También se eliminarán todas las ubicaciones L3 que contiene.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return 'Eliminar \"$displayName\"';
  }

  @override
  String get createLocationOpeningLocation =>
      'Esta es la ubicación de la apertura. Eliminarla también borrará la apertura.';

  @override
  String get createLocationL1LocationRegion => 'Ubicación L1 · Región *';

  @override
  String get createLocationL2LocationBuilding => 'Ubicación L2 · Edificio *';

  @override
  String get createLocationAddL3Location => 'Agregar ubicación L3';

  @override
  String get createLocationsTitle => 'Ubicaciones';

  @override
  String get createLocationStatisticsNote =>
      'Tu mundo se construye en 3 niveles:\nL1 · Región     Una zona de tu mundo: el centro\nL2 · Edificio   Un edificio dentro de ella: el restaurante de Joe\nL3 · Habitación Una habitación del edificio: la cocina trasera\nCada ubicación necesita los tres niveles. Hasta 15 habitaciones en total.';

  @override
  String get createLocationL1NameNote =>
      'Una zona de tu mundo: un distrito, un pueblo o un bosque. No un edificio individual.';

  @override
  String get createLocationL2NameNote =>
      'Un edificio dentro de esta región: una tienda, una escuela o un bloque de apartamentos.';

  @override
  String get createLocationL3NameNote =>
      'Una habitación dentro del edificio. También puede ser una azotea, un patio o una entrada.';

  @override
  String get createLocationName => 'Nombre *';

  @override
  String get createLocationL1NameRequired =>
      'El nombre de la ubicación L1 es obligatorio.';

  @override
  String get createLocationL3NameRequired =>
      'El nombre de la ubicación L3 es obligatorio.';

  @override
  String get createLocationThisL1 => 'Esta ubicación L1';

  @override
  String get createLocationThisL2 => 'Esta ubicación L2';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel debe contener al menos una ubicación L2.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel debe contener al menos una ubicación L3.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel tiene una ubicación L2 que necesita un nombre.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel tiene una ubicación L3 que necesita un nombre.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'Puedes agregar hasta $count ubicaciones L3.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return 'Ya usaste las $count habitaciones. Elimina una para agregar otra.';
  }

  @override
  String get createLocationAtLeastOneL1 =>
      'Se necesita al menos una ubicación L1.';

  @override
  String get createLocationAddL1 => 'Agrega al menos una ubicación L1.';

  @override
  String get createLocationMinOne => 'Crea al menos una ubicación.';

  @override
  String get createLocationIdRequired => 'Cada ubicación debe tener un ID.';

  @override
  String get createLocationIdUnique => 'Cada ubicación debe tener un ID único.';

  @override
  String get createLocationParentInvalid =>
      'Cada ubicación debe tener una ubicación superior válida.';

  @override
  String get createLocationFieldsRequired =>
      'Completa todos los campos obligatorios de las ubicaciones antes de guardar.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Guardar las ubicaciones también eliminará $count burbujas de diálogo de la apertura correspondientes a los personajes eliminados.',
      one:
          'Guardar las ubicaciones también eliminará 1 burbuja de diálogo de la apertura correspondiente a los personajes eliminados.',
      zero:
          'Guardar las ubicaciones también eliminará $count burbujas de diálogo de la apertura correspondientes a los personajes eliminados.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'Editar ubicación L3';

  @override
  String get createLocationPreview => 'Vista previa';

  @override
  String get createLocationCompleteLocation =>
      'Completa esta ubicación o elimínala.';

  @override
  String get createLocationRemoveCharacter =>
      '¿Quitar al personaje de esta ubicación?';

  @override
  String get createLocationRemove => 'Quitar';

  @override
  String get createLocationL1Location => 'Ubicación L1';

  @override
  String get createLocationL2Location => 'Ubicación L2';

  @override
  String get createLocationL3Location => 'Ubicación L3';

  @override
  String get createOpeningSelectLocation => 'Selecciona una ubicación';

  @override
  String get createOpeningNoSavedLocations => 'No hay ubicaciones guardadas';

  @override
  String get createOpeningSelect => 'Seleccionar';

  @override
  String get createOpeningSelectLocationFirst =>
      'Primero selecciona una ubicación.';

  @override
  String get createOpeningNoInitialCharacter => 'Sin personaje inicial';

  @override
  String get createOpeningLocationsLoading =>
      'Las ubicaciones aún se están cargando.';

  @override
  String get createOpeningLoadingLocations => 'Cargando ubicaciones...';

  @override
  String get createOpeningSwitchingLocations =>
      'Cambiar de ubicación borrará el contenido del diálogo.';

  @override
  String get createOpeningContinue => 'Continuar';

  @override
  String get createOpeningAdd10DialogueItems =>
      'Puedes agregar hasta 10 elementos de diálogo.';

  @override
  String get settingsUnableSaveSuggestedRole =>
      'No se pudo guardar el personaje recomendado.';

  @override
  String get createOpeningUnableSaveOpening =>
      'No se pudo guardar la apertura.';

  @override
  String get createOpeningSelectInitial => 'Selecciona la ubicación inicial';

  @override
  String get createOpeningInitialLocationRequired =>
      'Selecciona una ubicación inicial antes de guardar.';

  @override
  String get createOpeningAddDialogueFirst =>
      'Agrega al menos un elemento de diálogo antes de guardar.';

  @override
  String get createOpeningCompleteDialogue =>
      'Completa todos los elementos de diálogo antes de guardar.';

  @override
  String get createOpeningDialogue => 'Diálogo de apertura';

  @override
  String get createOpeningLocationRequired =>
      'Primero selecciona una ubicación y luego edita el diálogo.';

  @override
  String get createOpeningNarrator => 'Narrador';

  @override
  String get createOpeningImage => 'Imagen';

  @override
  String get createOpeningSuggestRoleUser =>
      'Recomendar un personaje al usuario';

  @override
  String get createOpeningNoCharacters => 'No hay personajes disponibles.';

  @override
  String get createOpeningEnterNarrator => 'Ingresa el diálogo del narrador';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return 'Ingresa el diálogo de $name';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => 'SUBIR IMAGEN';

  @override
  String get createEventAddEvent => '+ Agregar evento';

  @override
  String get createStoryEventsTitle => 'Eventos de la historia';

  @override
  String createEventLimit({required int count}) {
    return 'Puedes agregar hasta $count eventos.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'Evento $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      'p. ej., Una cadena nacional busca un terreno vacío y amenaza con ofrecer precios más bajos que todos los negocios locales.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'Un momento clave que la AI utiliza para dirigir la historia.';

  @override
  String get imageCropUploadFailed => 'No se pudo subir';

  @override
  String get inboxNotifications => 'Notificaciones';

  @override
  String get inboxNoNotificationsYet => 'Aún no hay notificaciones.';

  @override
  String get inboxFollowers => 'Seguidores';

  @override
  String get inboxNewFollowers => 'Nuevos seguidores';

  @override
  String get inboxNoNewFollowersYet => 'Aún no hay nuevos seguidores.';

  @override
  String get inboxComments => 'Comentarios';

  @override
  String get inboxNoCommentsYet => 'Aún no hay comentarios.';

  @override
  String get inboxPrivateChats => 'Chats privados';

  @override
  String get inboxChatFriendsWorldo => 'Chatea con tus amigos en Worldo.';

  @override
  String get inboxUnknownUser => 'Usuario desconocido';

  @override
  String get inboxDirectMessage => 'Mensaje directo';

  @override
  String get inboxJoinRequest => 'Solicitud para unirse';

  @override
  String get inboxApprove => 'Aprobar';

  @override
  String get inboxReject => 'Rechazar';

  @override
  String get inboxOk => 'Aceptar';

  @override
  String get inboxReviewFailed => 'No se pudo revisar';

  @override
  String get inboxLoadMessagesFailed => 'No se pudieron cargar los mensajes.';

  @override
  String get inboxNewMessage => 'Nuevo mensaje';

  @override
  String get inboxSomeone => 'Alguien';

  @override
  String get inboxWorld => 'este mundo';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name solicita unirse a $world$suffix';
  }

  @override
  String get inboxCommentWorldo => ' comentó en tu worldo';

  @override
  String get inboxReply => ' te respondió';

  @override
  String get inboxLikeComment => ' indicó que le gusta tu comentario';

  @override
  String get inboxLikedComment => 'indicó que le gusta tu comentario';

  @override
  String get inboxComment2LikeComment => 'indicó que le gusta tu comentario';

  @override
  String get inboxReplied => 'te respondió';

  @override
  String get inboxYou2Reply => 'te respondió';

  @override
  String get inboxCommentedOrigin => 'comentó en tu creación';

  @override
  String get inboxCommentOrigin => 'comentó en tu creación';

  @override
  String get inboxSentMessage => ' te envió un mensaje';

  @override
  String get inboxStartedFollowing => ' comenzó a seguirte.';

  @override
  String get meFailedOpenDiscord => 'No se pudo abrir Discord';

  @override
  String get meImagePickFailed => 'No se pudo elegir la imagen';

  @override
  String get meUpdateFailed => 'No se pudo actualizar';

  @override
  String get mePlaying => 'Jugando';

  @override
  String get meEditName => 'Editar nombre';

  @override
  String get meSignUpReward => '¡Regístrate y recibe 250 gemas!';

  @override
  String get loginSignUpReward => '¡Regístrate y recibe 250 gemas!';

  @override
  String get meUnknown => 'Desconocido';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID: $oid\nÚltima versión: $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID: $displayWid\nPropietario: $owner';
  }

  @override
  String get meFollows => 'Seguimientos';

  @override
  String meFollowingCount({required String followingCount}) {
    return '$followingCount seguidos';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount seguidores';
  }

  @override
  String get meNoFollowingYet => 'Aún no sigues a nadie.';

  @override
  String get meNoFollowersYet => 'Aún no tienes seguidores.';

  @override
  String get meBlockFailed => 'No se pudo bloquear. Inténtalo de nuevo.';

  @override
  String get meUserBlockedContentHasReported =>
      'Usuario bloqueado. Se ha reportado este contenido al equipo de Worldo.';

  @override
  String get meBlockUser => '¿Bloquear a este usuario?';

  @override
  String get meBlock => 'Bloquear';

  @override
  String get meUnblockFailed => 'No se pudo desbloquear. Inténtalo de nuevo.';

  @override
  String get meUnblock => 'Desbloquear';

  @override
  String get meFollowing => 'Siguiendo';

  @override
  String get meFollow => 'Seguir';

  @override
  String get meMessage => 'Mensaje';

  @override
  String meUID({required String uid}) {
    return 'UID: $uid';
  }

  @override
  String get meNoWorldoCreatedYet => 'Aún no has creado ningún Worldo.';

  @override
  String get meNoWorldoYet => 'Aún no hay Worldo.';

  @override
  String get meNoWorldsCreatedYet => 'Aún no has creado ningún mundo.';

  @override
  String get meNoWorldsYet => 'Aún no hay mundos.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'Gemas rojas';

  @override
  String get gemsPink => 'Gemas rosas';

  @override
  String get gemsTop => 'Recargar';

  @override
  String get gemsBuy => 'Comprar gemas';

  @override
  String get gemsRecords => 'Registros';

  @override
  String get gemsUnableLoad => 'No se pudieron cargar las gemas.';

  @override
  String get settingsLogOutAccount => '¿Cerrar sesión en tu cuenta?';

  @override
  String get settingsLogOut => 'Cerrar sesión';

  @override
  String get settingsFeedback => 'Comentarios';

  @override
  String get settings => 'Configuración';

  @override
  String get settingsAboutUs => 'Acerca de nosotros';

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsBlockedUsers => 'Usuarios bloqueados';

  @override
  String get settingsJoinDiscord => 'Unirse a Discord';

  @override
  String get meUserUnblocked => 'Usuario desbloqueado';

  @override
  String get meNoBlockedUsersYet => 'Aún no hay usuarios bloqueados.';

  @override
  String get settingsAgreeTermsContinue =>
      'Acepta nuestros términos para continuar.';

  @override
  String get settingsDeleteAccount => '¿Eliminar tu cuenta?';

  @override
  String get settingsAccountDeletionAgreement =>
      'Acuerdo de eliminación de cuenta';

  @override
  String get settingsEnsureSecurityAccount =>
      'Para garantizar la seguridad de tu cuenta, lee las consecuencias de eliminarla.\n\nEliminar tu cuenta no es lo mismo que cerrar sesión y no se puede deshacer. Tus datos privados, incluidos personajes creados, historial de búsqueda, chats con personajes, favoritos, recuerdos, datos de interacción y registros de pedidos, se eliminarán de forma irreversible y no podrán recuperarse.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      'Todas las gemas sin usar, incluidas las compradas y obtenidas, se perderán de forma permanente. Al continuar, renuncias voluntariamente a ellas; eliminar tu cuenta no te da derecho automático a un reembolso.\n\nTambién perderás de forma permanente todos los beneficios restantes de la membresía y no podrán recuperarse. Eliminar tu cuenta no cancela tu suscripción.';

  @override
  String get settingsIHaveReadAccountDeletion =>
      'He leído el Acuerdo de eliminación de cuenta';

  @override
  String get settingsCurrentLoginAccount => 'Cuenta con sesión iniciada:';

  @override
  String get profileSaveFailed =>
      'No se pudo guardar tu perfil. Inténtalo de nuevo.';

  @override
  String get meSignInFailed => 'No se pudo iniciar sesión. Inténtalo de nuevo.';

  @override
  String get meCompleteProfileContinue => 'Completa tu perfil para continuar.';

  @override
  String get meSelectGenderAge => 'Selecciona tu género y edad.';

  @override
  String get meSelectGender => 'Selecciona tu género.';

  @override
  String get meSelectAge => 'Selecciona tu edad.';

  @override
  String get meRequired => 'Obligatorio';

  @override
  String get mePersonalizeWorldoExperience =>
      'Personaliza tu experiencia en Worldo';

  @override
  String get meSignIn => 'Iniciar sesión';

  @override
  String get meBack => 'Atrás';

  @override
  String get meSkip => 'Omitir';

  @override
  String get meContinueGoogle => 'Continuar con Google';

  @override
  String get meContinueApple => 'Continuar con Apple';

  @override
  String get meSignUpClaimPremium => 'Regístrate para obtener Premium';

  @override
  String get meSignUpContinue => 'Regístrate para continuar';

  @override
  String get meAccountLoggedAnotherDevice =>
      'Tu cuenta tiene una sesión iniciada en otro dispositivo.';

  @override
  String get premiumSubscription => 'Suscripción';

  @override
  String get gemsClaimFailed => 'No se pudo obtener la recompensa.';

  @override
  String get gemsCheckFailed => 'No se pudo hacer el check-in.';

  @override
  String get gemsFollowFailed => 'No se pudo seguir.';

  @override
  String get gemsTaskUpdateFailed => 'No se pudo actualizar la tarea.';

  @override
  String get gemsClaimSuccessful => '¡Recompensa obtenida!';

  @override
  String get gemsUnableLoadGemPacks =>
      'No se pudieron cargar los paquetes de gemas.';

  @override
  String get gemsNoGemPacksAvailable => 'No hay paquetes de gemas disponibles.';

  @override
  String get gemsUnableLoadGemTasks =>
      'No se pudieron cargar las tareas de gemas.';

  @override
  String get gemsJoinUs => 'únete a nosotros';

  @override
  String get gemsClaim => 'Obtener';

  @override
  String get gemsClaimed => 'Obtenida';

  @override
  String get meDailyCheck => 'Check-in diario';

  @override
  String get gemsDailyCheckInReward => 'Obtén 100';

  @override
  String get meCheck => 'Hacer check-in';

  @override
  String get meCheckSuccessful => '¡Check-in completado!';

  @override
  String get meGooglePlayUnavailable => 'Google Play no está disponible.';

  @override
  String get mePurchaseFailed => 'La compra falló.';

  @override
  String get gemsEarned => 'Obtenidas';

  @override
  String get gemsSpent => 'Gastadas';

  @override
  String get gemsPurchase => 'Compra';

  @override
  String get gemsGemRecords => 'Registros de gemas';

  @override
  String get gemsUnableLoadRecords => 'No se pudieron cargar los registros.';

  @override
  String get gemsNoGemRecordsYet => 'Aún no hay registros de gemas.';

  @override
  String get meAbout => 'Acerca de';

  @override
  String get meEmailCopied => 'Correo copiado';

  @override
  String get mePurchasingPremium => 'Comprando Premium';

  @override
  String get mePurchaseSuccessful => '¡Compra realizada!';

  @override
  String get meWorldoPremiumSubscription =>
      'Tu suscripción a Worldo Premium ya está activa.';

  @override
  String get meMyBalance => 'Mi saldo';

  @override
  String get meSoldOut => 'Agotado';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession =>
      'Se necesita una sesión de usuario completa para consultar los modelos';

  @override
  String get memoryModelListPermissionDenied =>
      'No tienes permiso para consultar los modelos de este mundo';

  @override
  String get memorySaveFailed => 'No se pudo guardar';

  @override
  String get memorySaveResultNotConfirmed =>
      'No se confirmó el resultado del guardado';

  @override
  String get memoryChooseModel => 'Elegir modelo';

  @override
  String get memoryMaxTokenLimit => 'Límite máximo de tokens de memoria';

  @override
  String get memoryNoModelsAvailable => 'No hay modelos disponibles';

  @override
  String get memoryRetryRanges => 'Reintentar rangos';

  @override
  String get memoryCurrentUsage => 'Tu uso actual de memoria';

  @override
  String memoryMinGems({required String min}) {
    return '$min gemas';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min–$max gemas';
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
      'Configuración de memoria no disponible';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Play tardó demasiado en responder. Inténtalo de nuevo.';

  @override
  String get premiumSubscriptionsNotSupported =>
      'Google Play no admite suscripciones en este dispositivo.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'Se perdió la conexión con Google Play. Inténtalo de nuevo.';

  @override
  String get premiumPurchaseCanceled => 'Compra cancelada.';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Play no está disponible temporalmente. Inténtalo más tarde.';

  @override
  String get premiumGooglePlayBilling =>
      'La facturación de Google Play no está disponible. Revisa tu cuenta de Play y la configuración de pagos.';

  @override
  String get premiumSubscriptionUnavailable =>
      'Esta suscripción Premium no está disponible actualmente en Google Play.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play no pudo completar esta compra de Premium. Inténtalo de nuevo.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'Ya tienes esta suscripción en Google Play.';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Play no encontró la suscripción que quieres cambiar. Revisa Administrar suscripciones.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'No se pudo conectar con Google Play. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get premiumInsufficientFunds =>
      'Tu método de pago no tiene fondos suficientes. Actualízalo en Google Play e inténtalo de nuevo.';

  @override
  String get premiumGoogleAccountIneligible =>
      'Tu cuenta de Google Play no cumple los requisitos para esta oferta de suscripción.';

  @override
  String get premiumAppStoreFailedComplete =>
      'App Store no pudo completar esta compra de Premium. Inténtalo de nuevo.';

  @override
  String get premiumFailedConnectAppStore =>
      'No se pudo conectar con App Store. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get premiumAppStoreTookTooLong =>
      'App Store tardó demasiado en responder. Inténtalo de nuevo.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'App Store encontró un error del sistema. Inténtalo más tarde.';

  @override
  String get premiumRegionUnavailable =>
      'Esta suscripción Premium no está disponible en tu región de App Store.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'Esta app no puede realizar esta solicitud a App Store. Contacta con soporte.';

  @override
  String get premiumPurchaseNotSupported =>
      'Esta compra no es compatible con este dispositivo o versión del sistema.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'No se pudo abrir la ventana de compra de App Store. Vuelve a la app e inténtalo de nuevo.';

  @override
  String get premiumAppStoreFailedAccept =>
      'App Store no pudo aceptar esta cantidad de compra. Contacta con soporte.';

  @override
  String get premiumAppStoreUnavailable =>
      'Esta suscripción Premium no está disponible actualmente en App Store.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'No se permiten compras en este dispositivo. Revisa tu cuenta de Apple y las restricciones de compra.';

  @override
  String get premiumAppleAccountNotEligible =>
      'Tu cuenta de Apple no cumple los requisitos para esta oferta de suscripción.';

  @override
  String get premiumSubscriptionOffer =>
      'Esta oferta de suscripción no está disponible. Actualiza la página e inténtalo de nuevo.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'App Store no pudo aceptar el precio de esta oferta. Actualiza la página e inténtalo de nuevo.';

  @override
  String get premiumAppStoreFailedVerify =>
      'App Store no pudo verificar esta oferta de suscripción. Contacta con soporte.';

  @override
  String get premiumSubscriptionOfferFailed =>
      'No se pudo preparar esta oferta de suscripción. Actualiza la página e inténtalo de nuevo.';

  @override
  String get premiumAddPaymentMethodApple =>
      'Agrega un método de pago a tu cuenta de Apple e inténtalo de nuevo.';

  @override
  String get premiumAppCannotMakePurchases =>
      'Esta app no puede realizar compras en App Store. Contacta con soporte.';

  @override
  String get premiumAppStoreRequestRejected =>
      'App Store no pudo aceptar esta solicitud de compra. Inténtalo de nuevo o contacta con soporte.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'Se denegó el acceso a los servicios en la nube de Apple. Revisa los permisos de tu cuenta de Apple.';

  @override
  String get premiumFailedConnectApple =>
      'No se pudo conectar con los servicios de Apple. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get premiumAccess2AppleCloudService =>
      'Se revocó el acceso a los servicios en la nube de Apple. Revisa la configuración de tu cuenta de Apple.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Acepta los términos de privacidad más recientes de Apple en tu cuenta de Apple e inténtalo de nuevo.';

  @override
  String get premiumAppStoreWindowFailed =>
      'No se pudo configurar la ventana de App Store. Contacta con soporte.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'La ventana de App Store tardó demasiado en abrirse. Inténtalo de nuevo.';

  @override
  String get premiumReturnAppTryPurchase =>
      'Vuelve a la app e intenta realizar la compra de nuevo.';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Play no está disponible. Comprueba que esté instalado y que hayas iniciado sesión.';

  @override
  String get premiumIs4Subscription =>
      'Esta suscripción Premium no está disponible actualmente en la tienda. Actualiza la página e inténtalo de nuevo.';

  @override
  String get premiumSubscriptionFailed =>
      'No se pudo preparar esta suscripción Premium. Actualiza la página e inténtalo de nuevo.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'La tienda no pudo abrir esta compra de Premium. Inténtalo de nuevo.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'No se encontró la suscripción original en Google Play. Revisa Administrar suscripciones.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'Esta suscripción usa una identidad de compra diferente. Actualiza la página o contacta con soporte.';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play aún no puede cambiar esta suscripción. Revisa Administrar suscripciones.';

  @override
  String get premiumPlanChangePending =>
      'App Store aún está procesando una compra de este plan. Espera a que termine.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'No se pudieron cargar los planes Premium de App Store. Inténtalo de nuevo.';

  @override
  String get premiumPurchasePreparation =>
      'La preparación de la compra venció. Inténtalo de nuevo.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'App Store devolvió un resultado de compra desconocido. Revisa tu suscripción antes de intentarlo de nuevo.';

  @override
  String get premiumPurchasesUnavailable =>
      'Las compras no están disponibles actualmente.';

  @override
  String get premiumAutoRenewsCancelAnytime =>
      'Renovación automática. Cancela cuando quieras.';

  @override
  String get premiumSubscribed => 'Suscrito';

  @override
  String get premiumAlsoIncluded => 'También incluye';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'Gemas rosas';

  @override
  String get premiumRedGems => 'Gemas rojas';

  @override
  String get premiumExtraDailyCheck => 'Extra por check-in diario';

  @override
  String get premiumDailyCheck => 'Check-in diario';

  @override
  String get premiumClaimedMonthly => 'Se obtiene cada mes';

  @override
  String get premiumBilledMonthly => 'Facturación mensual';

  @override
  String premiumSaveSavings({required String savings}) {
    return 'Ahorra $savings%';
  }

  @override
  String get premiumSubscribe => 'Suscribirse';

  @override
  String get premiumActiveYearlySubscription =>
      'Una suscripción anual Premium activa no se puede cambiar a un plan mensual.';

  @override
  String get premiumAlreadyHaveActive =>
      'Ya tienes una suscripción Premium activa.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'Ya tienes una suscripción a Premium $label.';
  }

  @override
  String get premiumPreviousPurchasePending =>
      'Tu compra anterior de Premium aún se está confirmando.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Usa la tienda original para mejorar tu suscripción Premium.';

  @override
  String get premiumResolveCurrent =>
      'Resuelve tu suscripción actual en la tienda antes de comprar.';

  @override
  String get premiumPurchaseUnavailable =>
      'La compra de Premium no está disponible actualmente.';

  @override
  String get premiumUnableVerifyPurchase =>
      'No se pudo verificar si cumples los requisitos para comprar. Inténtalo de nuevo.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      'La tienda no pudo verificar esta compra de Premium.';

  @override
  String get premiumPurchaseDoesNotMatch =>
      'La compra de Premium no coincide con el plan seleccionado.';

  @override
  String get premiumMessagePurchaseCanceled =>
      'Se canceló esta compra de Premium.';

  @override
  String get premiumPurchaseRevoked => 'Se revocó esta compra de Premium.';

  @override
  String get premiumNotification => 'Notificación';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premium está activo en tu suscripción y no admite cambiar a un plan inferior.';

  @override
  String get premiumGot => 'Entendido';

  @override
  String get gemBalancePromptInsufficientGems => 'Gemas insuficientes';

  @override
  String get gemBalancePromptLowGems => 'Pocas gemas';

  @override
  String get appPressBackExit => 'Presiona Atrás otra vez para salir.';

  @override
  String get appReportSubmitted => 'Reporte enviado';

  @override
  String get appReportFailed => 'No se pudo enviar el reporte';

  @override
  String get appUpdateRequired => 'Se necesita una actualización';

  @override
  String get appUpdateContent =>
      'Actualiza a la última versión para seguir usando Worldo.';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'Versión $versionName';
  }

  @override
  String get appUpdateCheckFailed =>
      'No se pudo actualizar el estado de la actualización. Actualiza la app para continuar.';

  @override
  String get appUpdate => 'Actualizar ahora';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return 'Se copió $normalizedLabel';
  }

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonImageLoadFailed => 'No se pudo cargar la imagen';

  @override
  String get commonPageNotFound => 'Página no encontrada.';

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
    return 'El LLM está generando tu primer Tick. Esto puede tardar un momento$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return 'Última versión: V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return 'Guarda $missingSections antes de crear.';
  }

  @override
  String get createCharacterRoleHint => 'El papel del personaje en el worldo.';

  @override
  String get createCharacterMannerHint =>
      'La forma de hablar y comportarse del personaje, que determina sus diálogos.';

  @override
  String get createCharacterGoalHint =>
      'El objetivo o la orientación del comportamiento del personaje, que determina sus acciones.';

  @override
  String get createCharacterBackgroundHint =>
      'Los antecedentes y las relaciones del personaje.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return 'solicita unirse a $world$worldIdSuffix';
  }

  @override
  String get memoryModel => 'Memoria y modelo';

  @override
  String get premiumAccountMismatch =>
      'Los identificadores de cuenta no coinciden con los de la suscripción anterior.';

  @override
  String get worldRecap => 'Resumen';

  @override
  String get inboxMissingJoinRequestId =>
      'Falta el ID de la solicitud para unirse';

  @override
  String get loginTimedOut =>
      'Se agotó el tiempo para iniciar sesión. Inténtalo de nuevo.';

  @override
  String get loginConnectionFailed =>
      'No se pudo conectar. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get loginTemporarilyUnavailable =>
      'No puedes iniciar sesión por el momento. Inténtalo más tarde.';

  @override
  String get recapUnlockHeading => 'Desbloquea el resumen';

  @override
  String get recapUpsellDescription =>
      'Ponte al día con tu historia con un resumen completo de cada giro, decisión y personaje que te acompaña.';

  @override
  String get recapShowEarlier => 'Ver resúmenes anteriores';

  @override
  String get recapEmpty =>
      'Aquí aparecerá el resumen a medida que avance la historia.';

  @override
  String get chatMessageAsNarrator => 'Enviar un mensaje como narrador';

  @override
  String chatMessageAsCharacter({required String name}) {
    return 'Enviar un mensaje como $name';
  }

  @override
  String get chatNarratorSpeaker => 'el narrador';

  @override
  String get chatYourCharacterSpeaker => 'tu personaje';

  @override
  String chatSpeakingAs({required String speaker}) {
    return 'Hablando como $speaker';
  }

  @override
  String get chatSwitchCharacter => 'Cambiar a personaje';

  @override
  String get chatSwitchNarration => 'Cambiar a narración';

  @override
  String chatOpenLocation({required String locationName}) {
    return 'Abrir $locationName';
  }

  @override
  String get chatRetryMessage => 'Reintentar mensaje';

  @override
  String get blockedReportFailed =>
      'Se bloqueó al usuario, pero no se pudo enviar el reporte.';

  @override
  String get storeConnectionFailed =>
      'No se pudo conectar con la tienda. Inténtalo de nuevo.';

  @override
  String get storeProductUnavailable =>
      'Este producto no está disponible por el momento.';

  @override
  String get storeDevicePurchasesUnavailable =>
      'No puedes realizar compras en este dispositivo.';

  @override
  String get worldHistoryRequestFailed =>
      'No se pudo cargar el historial del mundo';

  @override
  String get genericError => 'Ocurrió un error';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': 'Premium $plan, $price por año',
      'other': 'Premium $plan, $price por mes',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => 'No se pudo borrar';

  @override
  String get developerGatewaySignatureFailed =>
      'No se pudo verificar la firma del Gateway';

  @override
  String get developerEndpointsSaved =>
      'Guardado. Las nuevas solicitudes usarán los endpoints configurados.';

  @override
  String get developerAdjustRestartRequired =>
      'Reinicia la app para aplicar el entorno de Adjust.';

  @override
  String developerRecapSetting({required String mode}) {
    return 'Resumen del mundo: $mode';
  }

  @override
  String get developerRecapPreview => 'Vista previa del resumen del mundo';

  @override
  String get developerRecapPreviewDescription =>
      'Reemplaza temporalmente el estado de suscripción y el contenido del resumen en el panel del mundo. Se restablece al reiniciar la app.';

  @override
  String get developerResetFailed => 'No se pudo restablecer';

  @override
  String get developerRecapOff => 'Desactivado (según la membresía)';

  @override
  String get developerRecapLocked => 'Bloqueado · sin suscripción';

  @override
  String get developerRecapEmpty => 'Con suscripción · aún sin generar';

  @override
  String get developerRecapSample => 'Con suscripción · resumen de ejemplo';

  @override
  String get developerRecapLive => 'Con suscripción · resumen real';

  @override
  String get chatEditFreeUsesExhausted => 'No te quedan ediciones gratuitas.';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'Membresía: $selection';
  }

  @override
  String get developerMembershipDescription =>
      'Cambia temporalmente el estado de membresía de esta cuenta en todas las pantallas. El servidor sigue usando el estado real de la cuenta. Se restablece al reiniciar la app.';

  @override
  String get developerMembershipOff => 'Desactivado (membresía real)';

  @override
  String get developerMembershipYearly => 'Premium · anual';

  @override
  String get developerMembershipMonthly => 'Premium · mensual';

  @override
  String get developerMembershipNone => 'Sin membresía';

  @override
  String get originStartBySelectingRole => 'Empieza por elegir tu personaje';

  @override
  String get originRecommendedStart => 'Inicio recomendado';

  @override
  String get originStoryOpening => 'Inicio de la historia';

  @override
  String get originOpeningLocation => 'Ubicación inicial';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names están ahora en\n$locationName',
      one: '$names está ahora en\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return 'Inicio de la historia\n$locationName';
  }

  @override
  String get chatCharacterMovement => 'Movimiento de personajes';
}

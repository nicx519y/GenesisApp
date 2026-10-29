// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get imageGifUnsupported => 'Animações GIF não são compatíveis.';

  @override
  String get worldProgressComplete => 'Avanço concluído';

  @override
  String a11ySwitchMode({required String label}) {
    return 'Mudar para o modo $label';
  }

  @override
  String a11yEditItem({required String title}) {
    return 'Editar $title';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return 'Carta de personagem $index de $count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'Editar inspiração $index';
  }

  @override
  String a11yInsert({required String label}) {
    return 'Inserir $label';
  }

  @override
  String get a11yMembership => 'Assinatura';

  @override
  String get a11yOpenWorldo => 'Abrir Worldo';

  @override
  String get a11yFilterGender => 'Filtrar por gênero';

  @override
  String get a11ySelectRole => 'Escolha seu personagem';

  @override
  String get a11yLoadingMap => 'Carregando mapa';

  @override
  String get a11yBuildingWorld => 'Construindo o mundo';

  @override
  String get a11yPremiumMembership => 'Assinatura Premium';

  @override
  String get a11yProMembership => 'Assinatura Pro';

  @override
  String get a11yRecommendedRole => 'Personagem recomendado';

  @override
  String get a11yLastMessage => 'Última mensagem';

  @override
  String get a11yRecentChat => 'Conversa recente';

  @override
  String get a11yAiReplyLoading => 'Carregando resposta de AI';

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
      other: 'jogadores',
      one: 'jogador',
      zero: 'jogadores',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (Adicionados / Máximo)';
  }

  @override
  String get createSixHours => '6 horas';

  @override
  String get createTwelveHours => '12 horas';

  @override
  String get createOneDay => '1 dia';

  @override
  String get createOneWeek => '1 semana';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageChangeFailed =>
      'Não foi possível mudar o idioma. Tente novamente.';

  @override
  String get purchasingGems => 'Comprando gemas';

  @override
  String get purchaseSuccessful => 'Compra realizada!';

  @override
  String get okAction => 'OK';

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get requestAction => 'Solicitar';

  @override
  String get requestedStatus => 'Solicitado';

  @override
  String get launchAction => 'Iniciar mundo';

  @override
  String get tickNowAction => 'Tick agora';

  @override
  String get writePostHint => 'Escreva uma publicação';

  @override
  String get newPostTitle => 'Nova publicação';

  @override
  String get aiIsGenerating => 'A AI está gerando';

  @override
  String get generatingCustomizedWorldWait =>
      'Gerando um mundo vivo e personalizado para você.\nAguarde um momento.';

  @override
  String get approvedStatus => 'Aprovado';

  @override
  String get rejectedStatus => 'Recusado';

  @override
  String get awaitingApprovalStatus => 'Aguardando aprovação';

  @override
  String get awaitingYourApprovalStatus => 'Aguardando sua aprovação';

  @override
  String get liveYourWorld => 'VIVA SEU MUNDO';

  @override
  String get signedOutMeDescription =>
      'Jogue em mundos, crie worldo e convide amigos,\ne continue onde estiver.';

  @override
  String get gemTaskLaunchWorldHint =>
      'Abra um Worldo de que você goste e inicie seu próprio mundo.';

  @override
  String get gemTaskInviteFriendHint =>
      'Abra um mundo e toque em Convidar no painel de detalhes.';

  @override
  String get gemTaskWriteCommentHint =>
      'Abra um Worldo de que você goste e escreva uma publicação em Discussão.';

  @override
  String get gemTaskRequestJoinHint =>
      'Abra um mundo do qual você ainda não participa e solicite a entrada.';

  @override
  String get gemTaskSendMessageHint => 'Envie mensagens no seu mundo.';

  @override
  String get gemTaskProgressWorldHint =>
      'Abra um mundo em que você está jogando e toque em Tick agora.';

  @override
  String get termsOfService => 'Termos de serviço';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'Mundo';

  @override
  String get userLabel => 'Usuário';

  @override
  String get meLabel => 'Eu';

  @override
  String get locationLabel => 'Local';

  @override
  String get allLabel => 'Todos';

  @override
  String get maleLabel => 'Masculino';

  @override
  String get femaleLabel => 'Feminino';

  @override
  String get nonBinaryLabel => 'Não binário';

  @override
  String get forYouLabel => 'Para você';

  @override
  String get userBlocked => 'Usuário bloqueado';

  @override
  String get purchaseCanceled => 'Compra cancelada.';

  @override
  String get purchasePending => 'Sua compra está pendente.';

  @override
  String get purchaseConfirmationDelayed =>
      'A confirmação da compra está demorando. Confira novamente mais tarde.';

  @override
  String get purchaseFailed => 'A compra falhou.';

  @override
  String get yearlyPlan => 'Anual';

  @override
  String get monthlyPlan => 'Mensal';

  @override
  String get proSubscriptionTagline =>
      'Explore mais a fundo cada Worldo em que você joga.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, com cobrança anual';
  }

  @override
  String expiresOn({required String date}) {
    return 'Expira em $date';
  }

  @override
  String get activeStatus => 'ATIVA';

  @override
  String get expiredStatus => 'Expirada';

  @override
  String updatedAt({required String timestamp}) {
    return 'Atualizado $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => 'Falha ao carregar. Tentar novamente';

  @override
  String get loadMoreAction => 'Carregar mais';

  @override
  String get gemPurchaseRecord => 'Compra de gemas';

  @override
  String get taskRewardRecord => 'Recompensa de tarefa';

  @override
  String get worldProgressRecord => 'Avanço do mundo';

  @override
  String get directMessageRecord => 'Mensagem direta';

  @override
  String get gemRecord => 'Registro de gemas';

  @override
  String get runATickTask => 'Faça um Tick';

  @override
  String get runATickTaskDescription =>
      'Abra um mundo em que você está jogando e toque em Tick agora.';

  @override
  String get someoneFallback => 'Alguém';

  @override
  String get aCharacterFallback => 'um personagem';

  @override
  String get thisWorld => 'este mundo';

  @override
  String get noWorldEventsYet => 'Ainda não há eventos no mundo.';

  @override
  String get globalLabel => 'Global';

  @override
  String get eventLabel => 'Evento';

  @override
  String get characterDestinations => 'Destinos dos personagens';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName $direction $locationName';
  }

  @override
  String get cameToDirection => 'chegou a';

  @override
  String get wentToDirection => 'foi para';

  @override
  String get hasComeToDirection => 'chegou a';

  @override
  String get hasGoneToDirection => 'foi para';

  @override
  String get waitForReplyToSendMore =>
      'Aguarde uma resposta para enviar mais mensagens';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novas mensagens',
      one: '$count nova mensagem',
      zero: '$count novas mensagens',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation =>
      'Selecione um personagem predefinido';

  @override
  String get enterNameValidation => 'Digite um nome';

  @override
  String get enterIdentityValidation => 'Digite uma identidade';

  @override
  String get waitForProfileLoading =>
      'Aguarde o carregamento do perfil terminar.';

  @override
  String get imageUploadFailed => 'Falha ao enviar a imagem.';

  @override
  String get photoAccessDenied => 'Acesso às fotos negado';

  @override
  String get feedbackSubmitted => 'Feedback enviado';

  @override
  String get feedbackFailed => 'Falha ao enviar feedback';

  @override
  String get worldoDetailUnavailable =>
      'Os detalhes do Worldo não estão disponíveis.';

  @override
  String get publishAction => 'Publicar';

  @override
  String get publishingStatus => 'Publicando...';

  @override
  String get publishFailed => 'Falha ao publicar';

  @override
  String get publishChangesBeforeLeaving =>
      'Publicar as alterações antes de sair?';

  @override
  String get noChangesToPublish => 'Não há alterações para publicar.';

  @override
  String get completeOpeningRequiredToPublish =>
      'É necessário concluir a abertura para publicar';

  @override
  String get publishResponseMissingOriginId =>
      'A publicação não retornou um ID de Worldo.';

  @override
  String get worldoIdRequired => 'É necessário um ID de Worldo.';

  @override
  String loadFailedWithReason({required String reason}) {
    return 'Falha ao carregar: $reason';
  }

  @override
  String get imageSelectionFailed => 'Falha ao selecionar imagem';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID: $oid\nÚltima versão: $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID: $wid\nProprietário: $owner';
  }

  @override
  String get sendFailed => 'Falha ao enviar';

  @override
  String get selectARole => 'Selecione um personagem';

  @override
  String get timeLabel => 'Tempo';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID: $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID: $oid · Criador: $creator';
  }

  @override
  String get worldoMetricExplanation =>
      'Este worldo atualiza o {Nome do indicador} de cada personagem a cada avanço, exibido em {Unidade}. Cada personagem começa em {Valor inicial}, e o valor pode variar entre {Variação mínima} e {Variação máxima}.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return 'Inicie um $worldo para gerar\nseu próprio mundo';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return 'Custo estimado da próxima mensagem: $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount gemas';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'Excluir mundo $worldName';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername joga como $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName iniciado!';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName criado!';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName publicado!';
  }

  @override
  String get createTimeout => 'O tempo para criar o Worldo esgotou.';

  @override
  String get publishTimeout => 'O tempo para publicar o Worldo esgotou';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return 'Você solicitou entrar em $worldName$worldId';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge solicita entrar em $worldName$worldId';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge comentou no seu worldo';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge respondeu a você';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge curtiu seu comentário';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge enviou uma mensagem para você';
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
    return 'Usos gratuitos de inspiração restantes: $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Usos gratuitos de edição restantes: $remaining\n$action';
  }

  @override
  String get getMoreAction => 'Obter mais >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName chegou a $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'O Worldo permite criar, descobrir e entrar em mundos movidos por AI, repletos de personagens, histórias e eventos em evolução. Converse com personagens de AI, jogue com amigos e faça cada mundo avançar por cenas e escolhas imersivas.\n\nNosso app oferece uma nova forma de vivenciar histórias interativas: além de ler, você participa de dentro do mundo. Se tiver dúvidas, entre em contato pelo e-mail $contactEmail.';
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
    return 'Ao continuar, você concorda com nossos $terms, $privacyPolicy e $endUserLicenseAgreement';
  }

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get terms => 'Termos';

  @override
  String get termsOfUse => 'Termos de uso';

  @override
  String get endUserLicenseAgreement => 'Contrato de licença do usuário final';

  @override
  String existingAccountSignIn({required String signIn}) {
    return 'Já tem uma conta? $signIn';
  }

  @override
  String get signInAction => 'Entrar.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return 'Você recebeu $gemIcon$grantedAmount gemas.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return 'Até $amount gemas por mês e acesso completo ao Premium.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /dia';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/mês';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: Resposta a $replyToName$replyToBadge: $content';
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
  String get homeLoadFailed => 'Falha ao carregar';

  @override
  String get homeRetry => 'Tentar novamente';

  @override
  String get homeEmptyDescription =>
      'O Worldo é o ponto de partida. Inicie-o para criar um mundo vivo em que você possa entrar e que possa desenvolver.';

  @override
  String get homeWorldCharacter => 'Personagem';

  @override
  String get homeWorldSingleOtherPlayer => '· 1 outro jogador';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· $otherPlayerCount outros jogadores';
  }

  @override
  String get homeSignInUnavailable => 'Login indisponível';

  @override
  String get homeSignedOutTitle => 'Seus mundos em um só lugar';

  @override
  String get homeSignedOutDescription =>
      'Entre para criar mundos e continuar suas histórias.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return 'Proprietário: $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID: $oid  Criador: $originator\nDescrição: $brief\nÚltima versão: $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID: $wid\nProprietário: $owner';
  }

  @override
  String get searchHistory => 'Histórico de pesquisa';

  @override
  String get searchFailed => 'Falha na pesquisa';

  @override
  String get searchNoResults => 'Nenhum resultado.';

  @override
  String get searchCancel => 'Cancelar';

  @override
  String get searchHint => 'Worldo, personagens, tags';

  @override
  String get worldDetailOnlyWorldsLaunched =>
      'Só é possível excluir mundos iniciados apenas por você.';

  @override
  String get worldDetailDelete => 'Excluir';

  @override
  String get worldDetailNoCharacterStatusYet =>
      'Ainda não há estados de personagens.';

  @override
  String get worldDetailNoCharactersYet => 'Ainda não há personagens.';

  @override
  String get worldDetailProgressingWorld => 'Avançando o mundo';

  @override
  String get worldDetailCompressingRecent =>
      'Comprimindo memórias recentes\nAvançando a linha do tempo do mundo\nGerando o próximo acontecimento da história\nAtualizando os locais dos personagens';

  @override
  String get worldModelsDetail => 'Detalhes';

  @override
  String get worldModelsLocations => 'Locais';

  @override
  String get worldModelsEvents => 'Eventos';

  @override
  String get worldModelsStatus => 'Estado';

  @override
  String get worldDetailUnavailable => 'Indisponível';

  @override
  String worldActionFailed({required String actionLabel}) {
    return 'Falha na ação: $actionLabel';
  }

  @override
  String get worldDetailRequestJoinWorld => 'Solicitar entrada neste mundo?';

  @override
  String get worldDetailRequest => 'Solicitar';

  @override
  String get worldDetailLaunchFailed => 'Falha ao iniciar o mundo';

  @override
  String get worldDetailNoSavedProfileFound => 'Nenhum perfil salvo encontrado';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return 'Worldo de origem: $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => 'Convidar';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Entre no meu mundo \"$worldName\" no Worldo!\n$wid\nPesquise este WID no Worldo para encontrar o mundo e entrar.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'Descrição do mundo';

  @override
  String get worldDetailCast => 'Personagens';

  @override
  String get worldDetailLinkCopiedShare =>
      'Link copiado. Compartilhe com seus amigos.';

  @override
  String get worldMapAction => 'Mapa';

  @override
  String get worldInfoAction => 'Informações';

  @override
  String worldLocationCount({required String pointsCount}) {
    return 'Locais ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => 'Jogador';

  @override
  String worldDetailGoal({required String goal}) {
    return 'Objetivo: $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet =>
      'Ainda não há detalhes dos personagens.';

  @override
  String get worldDetailNoEventsYet => 'Ainda não há eventos.';

  @override
  String get worldDetailLoadEventsFailed => 'Falha ao carregar eventos.';

  @override
  String homeLocationID({required String id}) {
    return 'Local $id';
  }

  @override
  String get homeBuildingWorld => 'CONSTRUINDO O MUNDO';

  @override
  String get worldMapLoadFailed => 'Falha ao carregar o mapa';

  @override
  String get worldMapZoomIn => 'Ampliar mapa';

  @override
  String get worldMapZoomOut => 'Reduzir mapa';

  @override
  String get worldDetailGlobal => 'Global';

  @override
  String get worldDetailLocation => 'Local';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => 'Gerando o primeiro Tick';

  @override
  String get worldFirstTickStatusLoadFailed =>
      'Não foi possível carregar o estado da geração.';

  @override
  String get worldDetailNew => 'Novo';

  @override
  String get homeUnknownLocation => 'Local desconhecido';

  @override
  String get homeUnknownCharacter => 'Personagem desconhecido';

  @override
  String get homeNewPlaceEmerged => 'Um novo lugar surgiu';

  @override
  String get homeNewCharacterAppeared => 'Um novo personagem surgiu';

  @override
  String get chatLocationUnavailable => 'Local indisponível';

  @override
  String get chatRequestApprovalLaunch => 'Solicitar aprovação para iniciar';

  @override
  String get chatLoading => 'Carregando';

  @override
  String get chatQuotaCheckFailed =>
      'Não foi possível verificar os usos gratuitos. Tente novamente.';

  @override
  String get chatInspirationSourceChanged =>
      'A fonte de inspiração mudou. Abra Inspiração novamente.';

  @override
  String get chatInspiration => 'Inspiração';

  @override
  String get chatMessageCannotSend => 'Esta mensagem não pode mais ser enviada';

  @override
  String get chatMessageEmpty => 'A mensagem está vazia';

  @override
  String get chatConnectionFailed =>
      'Não foi possível conectar a esta conversa';

  @override
  String get chatReplyChangedSelect =>
      'A resposta mudou. Selecione a inspiração novamente.';

  @override
  String get chatSendConfirmFailed =>
      'Não foi possível confirmar o envio da mensagem';

  @override
  String get chatNoNetworkConnection =>
      'Rede indisponível. Verifique sua conexão de rede.';

  @override
  String get chatRoundCannotContinue => 'Este turno não pode continuar';

  @override
  String get chatSourceRoundChanged => 'O turno de origem mudou';

  @override
  String get chatGo => 'Continuar';

  @override
  String get chatReplyActionUnavailable =>
      'Esta ação de resposta não está mais disponível';

  @override
  String get chatRegenerateFailure => 'Falha ao gerar novamente';

  @override
  String get chatGoFailure => 'Falha ao continuar';

  @override
  String get chatEditFailure => 'Falha ao editar';

  @override
  String get chatInspirationFailure => 'Falha ao gerar inspiração';

  @override
  String get chatJoinLocationFailed => 'Falha ao entrar neste local';

  @override
  String get chatInactive => 'Esta conversa não está mais ativa';

  @override
  String get chatChatroomUnavailable => 'Sala de conversa indisponível';

  @override
  String get chatFailedConfirmReplyAction =>
      'Não foi possível confirmar a ação de resposta';

  @override
  String get chatLeastOneMessageMustRemain =>
      'É necessário manter pelo menos uma mensagem.';

  @override
  String get chatReplyNotEditable => 'Esta resposta não pode ser editada';

  @override
  String get chatReplyAlreadyFixed => 'Esta resposta já foi finalizada';

  @override
  String get chatReplyEditorFrozen => 'O editor de respostas está bloqueado';

  @override
  String get chatResolvePreviousSaveBefore =>
      'Resolva o salvamento anterior antes de alterar o rascunho';

  @override
  String get chatStaleReplyEditor => 'Editor de respostas desatualizado';

  @override
  String get chatPreviousSaveResultUncertain =>
      'O resultado do salvamento anterior é incerto; recarregue antes de editar novamente';

  @override
  String get chatCandidateMissing => 'A opção não existe mais';

  @override
  String get chatBatchSupportsMost100Changes =>
      'Um lote aceita no máximo 100 alterações';

  @override
  String get chatMissingStableMessageIdentity =>
      'Falta um identificador estável da mensagem';

  @override
  String get chatEditTargetHasChanged => 'O alvo da edição mudou';

  @override
  String get chatMessageNotEditable => 'Esta mensagem não pode ser editada';

  @override
  String get chatReplyNoLongerEditable =>
      'Esta resposta não pode mais ser editada';

  @override
  String get chatEditorOpenFailed => 'Não foi possível abrir o editor';

  @override
  String get chatInactiveDuringEdit => 'Esta conversa não está mais ativa.';

  @override
  String get chatEditMessage => 'Editar mensagem';

  @override
  String get chatSave => 'Salvar';

  @override
  String get chatEdit => 'Editar';

  @override
  String get chatRegenerate => 'Gerar novamente';

  @override
  String get chatRegenerateUnavailable =>
      'Este turno não pode ser gerado novamente';

  @override
  String get chatGenerate10Replies => 'Você pode gerar até 10 respostas.';

  @override
  String get chatPreviousReply => 'Resposta anterior';

  @override
  String get chatNextReply => 'Próxima resposta';

  @override
  String get chatCopy => 'Copiar';

  @override
  String get chatReport => 'Denunciar';

  @override
  String get chatCopied => 'Copiado';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novas mensagens',
      one: '$count nova mensagem',
      zero: '$count novas mensagens',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'Mencionar';

  @override
  String get chatCharacters => 'Personagens';

  @override
  String get chatNoCharacters => 'Sem personagens';

  @override
  String get chatNoLocations => 'Sem locais';

  @override
  String get chatHere => 'Aqui';

  @override
  String get chatLoadEarlierMessages => 'Carregar mensagens anteriores';

  @override
  String get chatText => 'Digite...';

  @override
  String get chatLocationRoster => 'VOCÊ';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'Todo o conteúdo é gerado por AI e é fictício. Qualquer semelhança com pessoas, eventos ou lugares reais é mera coincidência.';

  @override
  String get homeRecent => 'Recente';

  @override
  String get worldoUnableSavePreference =>
      'Não foi possível salvar sua preferência. Tente novamente.';

  @override
  String get worldoFilterGender => 'Filtrar por gênero';

  @override
  String get worldoNoData => 'Sem dados';

  @override
  String get worldoAll => 'Todos';

  @override
  String get worldoDetailSelectRole => 'Escolha seu personagem';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'Criador: $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Editar Worldo';

  @override
  String get worldoDetailWorldoBrief => 'Descrição do Worldo';

  @override
  String get worldoDetailNewPost => 'Nova publicação';

  @override
  String get worldoDetailWritePost => 'Escreva uma publicação';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'Discussão ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => 'Ver tudo >';

  @override
  String get worldoDetailPlayingWorld => 'Mundo em andamento';

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
    return 'Personagens ($length)';
  }

  @override
  String get worldoSend => 'Enviar';

  @override
  String get worldoPostFailed => 'Falha ao publicar';

  @override
  String get worldoImageUploadFailed => 'Falha ao enviar imagem';

  @override
  String get worldoLoadRepliesFailed => 'Falha ao carregar respostas';

  @override
  String get worldoWriteReply => 'Escreva uma resposta';

  @override
  String worldoReplyName({required String replyToName}) {
    return 'Responder a $replyToName';
  }

  @override
  String get worldoPostDetail => 'Detalhes da publicação';

  @override
  String get worldoPostUnavailable => 'Publicação indisponível';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'Todas as respostas $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return 'Ver todas as $replyCount respostas';
  }

  @override
  String get worldoLikeFailed => 'Falha ao curtir';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return 'Ver todas as $replyCount respostas';
  }

  @override
  String get worldoUser => 'Usuário';

  @override
  String get worldoViewMore => 'Ver mais >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'Discussão ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return 'Ver todas as $remainingReplyCount respostas';
  }

  @override
  String get worldoReply => 'Responder';

  @override
  String get worldoDiscussTitle => 'Discussão';

  @override
  String get worldoLaunchLocationComesLife =>
      'Este local ganha vida quando o mundo é iniciado.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      'Inicie este Worldo para explorar e interagir aqui.';

  @override
  String get worldoLaunchRoleUnavailable =>
      'Este personagem não está mais disponível';

  @override
  String get worldoLaunchSelectRole => 'Escolha seu personagem';

  @override
  String get worldoLaunchProfile => 'Seu perfil';

  @override
  String get worldoLaunchDone => 'Concluído';

  @override
  String get worldoLaunchSuggested => 'Sugerido';

  @override
  String get worldoLaunchName => 'Nome';

  @override
  String get worldoLaunchIdentity => 'Identidade';

  @override
  String get worldoLaunchPersonality => 'Personalidade';

  @override
  String get worldoLaunchGoal => 'Objetivo';

  @override
  String get worldoLaunchSetupRole => 'Configure seu personagem';

  @override
  String get worldoLaunchPreset => 'Predefinido';

  @override
  String get worldoLaunchCustom => 'Personalizado';

  @override
  String get worldoLaunchNoPresetRole => 'Sem personagem predefinido';

  @override
  String get worldoLaunchFilling => 'Preenchendo...';

  @override
  String get worldoLaunchFillMyProfile => 'Preencher com meu perfil';

  @override
  String get worldoLaunchLaunch => 'Iniciar mundo';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName iniciado!';
  }

  @override
  String get worldoLaunchEnter => 'Entrar';

  @override
  String get createAction => 'Criar';

  @override
  String get createWorldoTitle => 'Criar Worldo';

  @override
  String get createFailed => 'Falha ao criar';

  @override
  String get createNotesRequired =>
      'As notas da atualização são necessárias para publicar.';

  @override
  String get createActionInProgress => 'Esta ação já está em andamento.';

  @override
  String createCurrentVersion({required String version}) {
    return 'Versão atual: $version';
  }

  @override
  String get createChecking => 'Verificando...';

  @override
  String createSummaryName({required String name}) {
    return 'Nome do Worldo: $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Descrição do Worldo: $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'Imagem de capa: $status';
  }

  @override
  String get createNotUploaded => 'Não enviada';

  @override
  String get createUploaded => 'Enviada';

  @override
  String createSummarySettings({required String settings}) {
    return 'Configurações do Worldo: $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Tempo do Worldo: $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Indicador do Worldo: $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
      zero: '$count dias',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 personagens';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personagens: $names',
      one: '1 personagem: $names',
      zero: '0 personagens: $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'Sugerido: $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · Região: $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · Edifício: $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · Cômodo: $count';
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
    return 'Diálogo dos personagens: $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'Narrador: $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return 'Imagem: $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return 'Excluir $itemLabel?';
  }

  @override
  String get createItemHasContentDeleteAnyway =>
      'Este item tem conteúdo. Excluir mesmo assim?';

  @override
  String get createImageUploadProgress => 'A imagem está sendo enviada.';

  @override
  String get createBasicsBasics => 'Dados básicos';

  @override
  String get createSaveInProgress => 'Já há um salvamento em andamento.';

  @override
  String get createRequiredBeforeSave =>
      'Preencha todos os campos obrigatórios antes de salvar.';

  @override
  String get createOpeningOpening => 'Abertura';

  @override
  String get createCharacterCharactersCreate =>
      'Personagens: Crie pelo menos um personagem.';

  @override
  String get createCharacterCharactersOnlyOne =>
      'Personagens: Apenas um personagem pode ser recomendado.';

  @override
  String get createBasicsBasicsWorldoName =>
      'Dados básicos: O nome do Worldo é obrigatório.';

  @override
  String get createBasicsBasicsWorldoBrief =>
      'Dados básicos: A descrição do Worldo é obrigatória.';

  @override
  String get createBasicsBasicsCoverImage =>
      'Dados básicos: A imagem de capa é obrigatória.';

  @override
  String get createBasicsBasicsMetricMust =>
      'Dados básicos: O indicador deve ser um JSON válido.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'Personagem #$characterIndex: O nome é obrigatório.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'Personagem #$characterIndex: A identidade é obrigatória.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'Personagem #$characterIndex: A personalidade é obrigatória.';
  }

  @override
  String get createCharacterCharactersLeast =>
      'Personagens: É necessário pelo menos um personagem.';

  @override
  String get createLocationLocationsCreate =>
      'Locais: Crie pelo menos um local.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return 'Local #$locationIndex: O nome é obrigatório.';
  }

  @override
  String get createOpeningOpeningSelect =>
      'Abertura: Selecione um local e preencha todos os itens de diálogo.';

  @override
  String get createOpeningOpeningSelected =>
      'Abertura: O local selecionado não está mais disponível.';

  @override
  String get createOpeningCharacterOpening =>
      'Abertura: Um personagem selecionado não está mais disponível.';

  @override
  String get createOpeningOpeningDialogue =>
      'Abertura: Um personagem do diálogo não está no local selecionado. Abra Abertura para corrigir.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return 'Diálogo de abertura incompatível: $type';
  }

  @override
  String get createCreating => 'Criando...';

  @override
  String get createDiscard => 'Descartar';

  @override
  String get createCharactersStep => 'Personagens (>=1)';

  @override
  String get createLocationsStep => 'Locais (>=1)';

  @override
  String get createStoryEventsOptional => 'Eventos da história (opcional)';

  @override
  String get createUpdateNotesRequiredPublish =>
      'Notas da atualização (obrigatórias para publicar)';

  @override
  String get createWhatChangedVersion => 'O que mudou nesta versão?';

  @override
  String get createView => 'Ver';

  @override
  String get createNotStartedYet => 'Ainda não iniciado';

  @override
  String get createEdited => 'Editado';

  @override
  String get createPublishingWorldo => 'Publicando seu Worldo';

  @override
  String get createCreatingWorldo => 'Criando seu Worldo';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Preparando as atualizações do seu Worldo.\nAguarde um momento.';

  @override
  String get createBringingWorldoLifeWait =>
      'Dando vida ao seu Worldo.\nAguarde um momento.';

  @override
  String get createDescribeIssue => 'Descreva o problema';

  @override
  String get createSubmit => 'Enviar';

  @override
  String get createBasicsWorldoName => 'Nome do Worldo *';

  @override
  String get createBasicsNameRequired => 'O nome do Worldo é obrigatório.';

  @override
  String get createBasicsBriefRequired =>
      'A descrição do Worldo é obrigatória.';

  @override
  String get createBasicsCoverRequired => 'A imagem de capa é obrigatória.';

  @override
  String get createBasicsMetricInvalid =>
      'O indicador deve ser um JSON válido.';

  @override
  String get createBasicsEgMainStreet => 'ex.: Rua Principal';

  @override
  String get createBasicsWorldoBrief => 'Descrição do Worldo *';

  @override
  String get createBasicsBriefNote =>
      'O que os jogadores veem primeiro: o cenário, o conflito central e o que torna a história intrigante.';

  @override
  String get createBasicsHiddenNote =>
      'As regras ocultas e os antecedentes que movem a história: intenções, mecânicas e limites secretos.';

  @override
  String get createBasicsEgHalfShopsMain =>
      'ex.: Metade das lojas da Rua Principal está fechada com tábuas. Até o Dia do Trabalho, o comércio mais rico será dono da cidade.';

  @override
  String get createBasicsCoverImage => 'Imagem de capa *';

  @override
  String get createBasicsUpload => 'Enviar imagem';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'Usada em cartões e páginas de detalhes. Recomendamos ~768×1024 px. Formatos compatíveis: JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden =>
      'Configurações do Worldo: ocultas (opcional)';

  @override
  String get createBasicsEgBankerSecretly =>
      'ex.: O banqueiro controla em segredo quem recebe empréstimos; quem se endividar demais pode ser forçado a sair.';

  @override
  String get createBasicsWorldoTimeOptional => 'Tempo do Worldo (opcional)';

  @override
  String get createBasicsWorldoStartsStart =>
      'Este worldo começa em {Hora inicial}; sempre que o usuário toca em *avançar*, a linha do tempo avança por {Tempo por avanço}.';

  @override
  String get createBasicsStartTime => 'Hora inicial';

  @override
  String get createBasicsDateExample => 'ex.: Dia 1, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => 'Tempo por avanço';

  @override
  String get createBasicsEg8Hours3Days => 'ex.: 8 horas / 3 dias';

  @override
  String get createBasicsWorldoMetricOptional =>
      'Indicador do Worldo (opcional)';

  @override
  String get createBasicsMetricLabel => 'Nome do indicador';

  @override
  String get createBasicsEgWealthGoalProgress =>
      'ex.: Riqueza / Progresso do objetivo';

  @override
  String get createBasicsLabelNote => 'Descrição do indicador';

  @override
  String get createBasicsDescribeWhatMetric =>
      'Descreva o que este indicador mede';

  @override
  String get createBasicsUnit => 'Unidade';

  @override
  String get createBasicsEgCoins => 'ex.: moedas / %';

  @override
  String get createBasicsRange => 'Intervalo de valores';

  @override
  String get createBasicsStarting => 'Valor inicial';

  @override
  String get createBasicsDeltaMin => 'Variação mínima';

  @override
  String get createBasicsDeltaMax => 'Variação máxima';

  @override
  String get createBasicsSaving => 'Salvando...';

  @override
  String get createBasicsAdvancedSettings =>
      'Configurações avançadas (opcional)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'Personagem $index';
  }

  @override
  String get createCharacterSuggest => 'Recomendar';

  @override
  String get createCharacterAvatarOptional => 'AVATAR\n(opcional)';

  @override
  String get createCharacterName => 'Nome *';

  @override
  String get createCharactersTitle => 'Personagens';

  @override
  String createCharacterLimit({required int count}) {
    return 'Você pode adicionar até $count personagens.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'Personagem $index: O nome é obrigatório.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'Personagem $index: A identidade é obrigatória.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'Personagem $index: A personalidade é obrigatória.';
  }

  @override
  String get createCharacterMinOne => 'Crie pelo menos um personagem.';

  @override
  String get createCharacterEnterName => 'Digite o nome...';

  @override
  String get createCharacterIdentity => 'Identidade *';

  @override
  String get createCharacterEgHometownKidBack =>
      'ex.: Alguém que voltou à cidade natal por uma chance de verdade';

  @override
  String get createCharacterPersonality => 'Personalidade *';

  @override
  String get createCharacterEgUnderdog =>
      'ex.: Alguém em desvantagem, com boa vontade, mas pouco capital';

  @override
  String get createCharacterGoalOptional => 'Objetivo (opcional)';

  @override
  String get createCharacterEgRichestOwner =>
      'ex.: Ser o proprietário mais rico da Rua Principal até o Dia do Trabalho';

  @override
  String get createCharacterBackgroundHidden =>
      'Antecedentes: ocultos (opcional)';

  @override
  String get createCharacterEgLeftTownYears =>
      'ex.: Saiu da cidade há anos e voltou a uma Rua Principal fechada com tábuas em busca de uma chance.';

  @override
  String get createCharacterAddCharacter => '+ Adicionar personagem';

  @override
  String get createLocationImageOptional => 'IMAGEM\n(opcional)';

  @override
  String get createCharacterSelectAvailable =>
      'Selecione entre os personagens disponíveis abaixo';

  @override
  String get createCharacterInitialCharacters =>
      'Personagens iniciais (opcional)';

  @override
  String get createLocationStartingCharacters =>
      'Os personagens que começam aqui quando o worldo se inicia.';

  @override
  String get createCharacterAvailableSelect => 'Disponíveis para selecionar';

  @override
  String get createCharacterNoCharactersYet =>
      'Ainda não há personagens. Crie os personagens e depois escolha onde começam.';

  @override
  String get createCharacterNoCharacters =>
      'Não há personagens disponíveis. Todos já têm um local inicial.';

  @override
  String get createLocationEveryL2L3Locations =>
      'Todos os locais L2 e L3 contidos nele também serão removidos.';

  @override
  String get createLocationEveryL3Locations =>
      'Todos os locais L3 contidos nele também serão removidos.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return 'Excluir \"$displayName\"';
  }

  @override
  String get createLocationOpeningLocation =>
      'Este é o local da abertura. Excluí-lo também limpará a abertura.';

  @override
  String get createLocationL1LocationRegion => 'Local L1 · Região *';

  @override
  String get createLocationL2LocationBuilding => 'Local L2 · Edifício *';

  @override
  String get createLocationAddL3Location => 'Adicionar local L3';

  @override
  String get createLocationsTitle => 'Locais';

  @override
  String get createLocationStatisticsNote =>
      'Seu mundo é construído em 3 níveis:\nL1 · Região     Uma área do mundo — Centro\nL2 · Edifício   Um edifício nela — Lanchonete do Joe\nL3 · Cômodo     Um cômodo no edifício — Cozinha dos fundos\nCada local precisa dos três níveis. Até 15 cômodos no total.';

  @override
  String get createLocationL1NameNote =>
      'Uma área do seu mundo: um bairro, uma cidade ou uma floresta. Não um único edifício.';

  @override
  String get createLocationL2NameNote =>
      'Um edifício nesta região: uma loja, uma escola ou um prédio de apartamentos.';

  @override
  String get createLocationL3NameNote =>
      'Um cômodo no edifício. Terraços, pátios e entradas também podem ser usados.';

  @override
  String get createLocationName => 'Nome *';

  @override
  String get createLocationL1NameRequired =>
      'O nome do local L1 é obrigatório.';

  @override
  String get createLocationL3NameRequired =>
      'O nome do local L3 é obrigatório.';

  @override
  String get createLocationThisL1 => 'Este local L1';

  @override
  String get createLocationThisL2 => 'Este local L2';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel deve conter pelo menos um local L2.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel deve conter pelo menos um local L3.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel tem um local L2 que precisa de nome.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel tem um local L3 que precisa de nome.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'Você pode adicionar até $count locais L3.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return 'Você já usou todos os $count cômodos. Exclua um para adicionar outro.';
  }

  @override
  String get createLocationAtLeastOneL1 =>
      'É necessário pelo menos um local L1.';

  @override
  String get createLocationAddL1 => 'Adicione pelo menos um local L1.';

  @override
  String get createLocationMinOne => 'Crie pelo menos um local.';

  @override
  String get createLocationIdRequired => 'Cada local deve ter um ID.';

  @override
  String get createLocationIdUnique => 'Cada local deve ter um ID único.';

  @override
  String get createLocationParentInvalid =>
      'Cada local deve ter um local superior válido.';

  @override
  String get createLocationFieldsRequired =>
      'Preencha todos os campos obrigatórios dos locais antes de salvar.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Salvar os locais também excluirá $count balões de diálogo da abertura dos personagens removidos.',
      one:
          'Salvar os locais também excluirá 1 balão de diálogo da abertura dos personagens removidos.',
      zero:
          'Salvar os locais também excluirá $count balões de diálogo da abertura dos personagens removidos.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'Editar local L3';

  @override
  String get createLocationPreview => 'Prévia';

  @override
  String get createLocationCompleteLocation =>
      'Complete este local ou exclua-o.';

  @override
  String get createLocationRemoveCharacter => 'Remover personagem deste local?';

  @override
  String get createLocationRemove => 'Remover';

  @override
  String get createLocationL1Location => 'Local L1';

  @override
  String get createLocationL2Location => 'Local L2';

  @override
  String get createLocationL3Location => 'Local L3';

  @override
  String get createOpeningSelectLocation => 'Selecionar local';

  @override
  String get createOpeningNoSavedLocations => 'Nenhum local salvo';

  @override
  String get createOpeningSelect => 'Selecionar';

  @override
  String get createOpeningSelectLocationFirst => 'Selecione um local primeiro.';

  @override
  String get createOpeningNoInitialCharacter => 'Sem personagem inicial';

  @override
  String get createOpeningLocationsLoading =>
      'Os locais ainda estão carregando.';

  @override
  String get createOpeningLoadingLocations => 'Carregando locais...';

  @override
  String get createOpeningSwitchingLocations =>
      'Mudar de local limpará o conteúdo do diálogo.';

  @override
  String get createOpeningContinue => 'Continuar';

  @override
  String get createOpeningAdd10DialogueItems =>
      'Você pode adicionar até 10 itens de diálogo.';

  @override
  String get settingsUnableSaveSuggestedRole =>
      'Não foi possível salvar o personagem recomendado.';

  @override
  String get createOpeningUnableSaveOpening =>
      'Não foi possível salvar a abertura.';

  @override
  String get createOpeningSelectInitial => 'Selecionar local inicial';

  @override
  String get createOpeningInitialLocationRequired =>
      'Selecione um local inicial antes de salvar.';

  @override
  String get createOpeningAddDialogueFirst =>
      'Adicione pelo menos um item de diálogo antes de salvar.';

  @override
  String get createOpeningCompleteDialogue =>
      'Complete todos os itens de diálogo antes de salvar.';

  @override
  String get createOpeningDialogue => 'Diálogo de abertura';

  @override
  String get createOpeningLocationRequired =>
      'Selecione um local primeiro e depois edite o diálogo.';

  @override
  String get createOpeningNarrator => 'Narrador';

  @override
  String get createOpeningImage => 'Imagem';

  @override
  String get createOpeningSuggestRoleUser =>
      'Recomendar um personagem ao usuário';

  @override
  String get createOpeningNoCharacters => 'Nenhum personagem disponível.';

  @override
  String get createOpeningEnterNarrator => 'Digite o diálogo do narrador';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return 'Digite o diálogo de $name';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => 'ENVIAR IMAGEM';

  @override
  String get createEventAddEvent => '+ Adicionar evento';

  @override
  String get createStoryEventsTitle => 'Eventos da história';

  @override
  String createEventLimit({required int count}) {
    return 'Você pode adicionar até $count eventos.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'Evento $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      'ex.: Uma rede nacional procura um terreno vazio e ameaça cobrar menos que todos os negócios locais.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'Um acontecimento importante que a AI usa para conduzir a história.';

  @override
  String get imageCropUploadFailed => 'Falha no envio';

  @override
  String get inboxNotifications => 'Notificações';

  @override
  String get inboxNoNotificationsYet => 'Ainda não há notificações.';

  @override
  String get inboxFollowers => 'Seguidores';

  @override
  String get inboxNewFollowers => 'Novos seguidores';

  @override
  String get inboxNoNewFollowersYet => 'Ainda não há novos seguidores.';

  @override
  String get inboxComments => 'Comentários';

  @override
  String get inboxNoCommentsYet => 'Ainda não há comentários.';

  @override
  String get inboxPrivateChats => 'Conversas privadas';

  @override
  String get inboxChatFriendsWorldo => 'Converse com seus amigos no Worldo.';

  @override
  String get inboxUnknownUser => 'Usuário desconhecido';

  @override
  String get inboxDirectMessage => 'Mensagem direta';

  @override
  String get inboxJoinRequest => 'Solicitação de entrada';

  @override
  String get inboxApprove => 'Aprovar';

  @override
  String get inboxReject => 'Recusar';

  @override
  String get inboxOk => 'OK';

  @override
  String get inboxReviewFailed => 'Falha ao analisar';

  @override
  String get inboxLoadMessagesFailed => 'Falha ao carregar mensagens.';

  @override
  String get inboxNewMessage => 'Nova mensagem';

  @override
  String get inboxSomeone => 'Alguém';

  @override
  String get inboxWorld => 'este mundo';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name solicita entrar em $world$suffix';
  }

  @override
  String get inboxCommentWorldo => ' comentou no seu worldo';

  @override
  String get inboxReply => ' respondeu a você';

  @override
  String get inboxLikeComment => ' curtiu seu comentário';

  @override
  String get inboxLikedComment => 'curtiu seu comentário';

  @override
  String get inboxComment2LikeComment => 'curtiu seu comentário';

  @override
  String get inboxReplied => 'respondeu a você';

  @override
  String get inboxYou2Reply => 'respondeu a você';

  @override
  String get inboxCommentedOrigin => 'comentou na sua criação';

  @override
  String get inboxCommentOrigin => 'comentou na sua criação';

  @override
  String get inboxSentMessage => ' enviou uma mensagem para você';

  @override
  String get inboxStartedFollowing => ' começou a seguir você.';

  @override
  String get meFailedOpenDiscord => 'Não foi possível abrir o Discord';

  @override
  String get meImagePickFailed => 'Falha ao escolher imagem';

  @override
  String get meUpdateFailed => 'Falha ao atualizar';

  @override
  String get mePlaying => 'Jogando';

  @override
  String get meEditName => 'Editar nome';

  @override
  String get meSignUpReward => 'Cadastre-se e ganhe 250 gemas!';

  @override
  String get loginSignUpReward => 'Cadastre-se e ganhe 250 gemas!';

  @override
  String get meUnknown => 'Desconhecido';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID: $oid\nÚltima versão: $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID: $displayWid\nProprietário: $owner';
  }

  @override
  String get meFollows => 'Conexões';

  @override
  String meFollowingCount({required String followingCount}) {
    return 'Seguindo $followingCount';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount seguidores';
  }

  @override
  String get meNoFollowingYet => 'Você ainda não segue ninguém.';

  @override
  String get meNoFollowersYet => 'Você ainda não tem seguidores.';

  @override
  String get meBlockFailed => 'Não foi possível bloquear. Tente novamente.';

  @override
  String get meUserBlockedContentHasReported =>
      'Usuário bloqueado. Este conteúdo foi denunciado à equipe do Worldo.';

  @override
  String get meBlockUser => 'Bloquear este usuário?';

  @override
  String get meBlock => 'Bloquear';

  @override
  String get meUnblockFailed =>
      'Não foi possível desbloquear. Tente novamente.';

  @override
  String get meUnblock => 'Desbloquear';

  @override
  String get meFollowing => 'Seguindo';

  @override
  String get meFollow => 'Seguir';

  @override
  String get meMessage => 'Mensagem';

  @override
  String meUID({required String uid}) {
    return 'UID: $uid';
  }

  @override
  String get meNoWorldoCreatedYet => 'Você ainda não criou nenhum Worldo.';

  @override
  String get meNoWorldoYet => 'Ainda não há Worldo.';

  @override
  String get meNoWorldsCreatedYet => 'Você ainda não criou nenhum mundo.';

  @override
  String get meNoWorldsYet => 'Ainda não há mundos.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'Gemas vermelhas';

  @override
  String get gemsPink => 'Gemas rosas';

  @override
  String get gemsTop => 'Recarregar';

  @override
  String get gemsBuy => 'Comprar gemas';

  @override
  String get gemsRecords => 'Registros';

  @override
  String get gemsUnableLoad => 'Não foi possível carregar as gemas.';

  @override
  String get settingsLogOutAccount => 'Sair da sua conta?';

  @override
  String get settingsLogOut => 'Sair';

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String get settings => 'Configurações';

  @override
  String get settingsAboutUs => 'Sobre nós';

  @override
  String get settingsAccount => 'Conta';

  @override
  String get settingsBlockedUsers => 'Usuários bloqueados';

  @override
  String get settingsJoinDiscord => 'Entrar no Discord';

  @override
  String get meUserUnblocked => 'Usuário desbloqueado';

  @override
  String get meNoBlockedUsersYet => 'Ainda não há usuários bloqueados.';

  @override
  String get settingsAgreeTermsContinue =>
      'Concorde com nossos termos para continuar.';

  @override
  String get settingsDeleteAccount => 'Excluir sua conta?';

  @override
  String get settingsAccountDeletionAgreement => 'Acordo de exclusão de conta';

  @override
  String get settingsEnsureSecurityAccount =>
      'Para garantir a segurança da sua conta, leia as consequências de excluí-la.\n\nExcluir a conta não é o mesmo que sair dela e não pode ser desfeito. Seus dados privados, incluindo personagens criados, histórico de pesquisa, conversas com personagens, favoritos, memórias, dados de interação e registros de pedidos, serão excluídos de forma irreversível e não poderão ser recuperados.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      'Todas as gemas não utilizadas, compradas ou obtidas, serão perdidas permanentemente. Ao continuar, você renuncia voluntariamente a elas; excluir a conta não dá direito automático a reembolso.\n\nTodos os benefícios restantes da assinatura também serão perdidos permanentemente e não poderão ser restaurados. Excluir sua conta não cancela sua assinatura.';

  @override
  String get settingsIHaveReadAccountDeletion =>
      'Li o Acordo de exclusão de conta';

  @override
  String get settingsCurrentLoginAccount => 'Conta conectada atualmente:';

  @override
  String get settingsNotSignedIn => 'Você não fez login';

  @override
  String get settingsAccountSignIn => 'Entrar';

  @override
  String get settingsAccountSignInDescription =>
      'Entre para gerenciar sua conta';

  @override
  String get profileSaveFailed =>
      'Não foi possível salvar seu perfil. Tente novamente.';

  @override
  String get meSignInFailed => 'Falha ao entrar. Tente novamente.';

  @override
  String get meCompleteProfileContinue => 'Complete seu perfil para continuar.';

  @override
  String get meSelectGenderAge => 'Selecione seu gênero e sua idade.';

  @override
  String get meSelectGender => 'Selecione seu gênero.';

  @override
  String get meSelectAge => 'Selecione sua idade.';

  @override
  String get meRequired => 'Obrigatório';

  @override
  String get mePersonalizeWorldoExperience =>
      'Personalize sua experiência no Worldo';

  @override
  String get meSignIn => 'Entrar';

  @override
  String get meBack => 'Voltar';

  @override
  String get meSkip => 'Pular';

  @override
  String get meContinueGoogle => 'Continuar com Google';

  @override
  String get meContinueApple => 'Continuar com Apple';

  @override
  String get meSignUpClaimPremium => 'Cadastre-se para obter Premium';

  @override
  String get meSignUpContinue => 'Cadastre-se para continuar';

  @override
  String get meAccountLoggedAnotherDevice =>
      'Sua conta está conectada em outro dispositivo.';

  @override
  String get premiumSubscription => 'Assinatura';

  @override
  String get gemsClaimFailed => 'Falha ao resgatar.';

  @override
  String get gemsCheckFailed => 'Falha no check-in.';

  @override
  String get gemsFollowFailed => 'Falha ao seguir.';

  @override
  String get gemsTaskUpdateFailed => 'Falha ao atualizar tarefa.';

  @override
  String get gemsClaimSuccessful => 'Recompensa resgatada!';

  @override
  String get gemsUnableLoadGemPacks =>
      'Não foi possível carregar os pacotes de gemas.';

  @override
  String get gemsNoGemPacksAvailable => 'Nenhum pacote de gemas disponível.';

  @override
  String get gemsUnableLoadGemTasks =>
      'Não foi possível carregar as tarefas de gemas.';

  @override
  String get gemsJoinUs => 'junte-se a nós';

  @override
  String get gemsClaim => 'Resgatar';

  @override
  String get gemsClaimed => 'Resgatado';

  @override
  String get meDailyCheck => 'Check-in diário';

  @override
  String get gemsDailyCheckInReward => 'Receba 100';

  @override
  String get meCheck => 'Fazer check-in';

  @override
  String get meCheckSuccessful => 'Check-in realizado!';

  @override
  String get meGooglePlayUnavailable => 'O Google Play está indisponível.';

  @override
  String get mePurchaseFailed => 'A compra falhou.';

  @override
  String get gemsEarned => 'Recebidas';

  @override
  String get gemsSpent => 'Gastas';

  @override
  String get gemsPurchase => 'Compra';

  @override
  String get gemsGemRecords => 'Registros de gemas';

  @override
  String get gemsUnableLoadRecords => 'Não foi possível carregar os registros.';

  @override
  String get gemsNoGemRecordsYet => 'Ainda não há registros de gemas.';

  @override
  String get meAbout => 'Sobre';

  @override
  String get meEmailCopied => 'E-mail copiado';

  @override
  String get mePurchasingPremium => 'Comprando Premium';

  @override
  String get mePurchaseSuccessful => 'Compra realizada!';

  @override
  String get meWorldoPremiumSubscription =>
      'Sua assinatura Worldo Premium está ativa.';

  @override
  String get meMyBalance => 'Meu saldo';

  @override
  String get meSoldOut => 'Esgotado';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession =>
      'É necessária uma sessão de usuário completa para consultar os modelos';

  @override
  String get memoryModelListPermissionDenied =>
      'Sem permissão para consultar os modelos deste mundo';

  @override
  String get memorySaveFailed => 'Falha ao salvar';

  @override
  String get memorySaveResultNotConfirmed =>
      'Resultado do salvamento não confirmado';

  @override
  String get memoryChooseModel => 'Escolher modelo';

  @override
  String get memoryMaxTokenLimit => 'Limite máximo de tokens de memória';

  @override
  String get memoryNoModelsAvailable => 'Nenhum modelo disponível';

  @override
  String get memoryRetryRanges => 'Tentar intervalos novamente';

  @override
  String get memoryCurrentUsage => 'Seu uso atual de memória';

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
    return 'memória $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return 'memória $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable =>
      'Configurações de memória indisponíveis';

  @override
  String get premiumGooglePlayTookTooLong =>
      'O Google Play demorou a responder. Tente novamente.';

  @override
  String get premiumSubscriptionsNotSupported =>
      'O Google Play não oferece assinaturas neste dispositivo.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'A conexão com o Google Play foi perdida. Tente novamente.';

  @override
  String get premiumPurchaseCanceled => 'Compra cancelada.';

  @override
  String get premiumGooglePlayTemporarily =>
      'O Google Play está temporariamente indisponível. Tente mais tarde.';

  @override
  String get premiumGooglePlayBilling =>
      'A cobrança do Google Play está indisponível. Confira sua conta do Play e as configurações de pagamento.';

  @override
  String get premiumSubscriptionUnavailable =>
      'Esta assinatura Premium está indisponível no Google Play no momento.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'O Google Play não conseguiu concluir esta compra de Premium. Tente novamente.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'Você já tem esta assinatura no Google Play.';

  @override
  String get premiumGooglePlayFailedFind =>
      'O Google Play não encontrou a assinatura a alterar. Confira Gerenciar assinaturas.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Não foi possível conectar ao Google Play. Confira sua conexão com a internet e tente novamente.';

  @override
  String get premiumInsufficientFunds =>
      'Seu método de pagamento não tem saldo suficiente. Atualize-o no Google Play e tente novamente.';

  @override
  String get premiumGoogleAccountIneligible =>
      'Sua conta do Google Play não é elegível para esta oferta de assinatura.';

  @override
  String get premiumAppStoreFailedComplete =>
      'A App Store não conseguiu concluir esta compra de Premium. Tente novamente.';

  @override
  String get premiumFailedConnectAppStore =>
      'Não foi possível conectar à App Store. Confira sua conexão com a internet e tente novamente.';

  @override
  String get premiumAppStoreTookTooLong =>
      'A App Store demorou a responder. Tente novamente.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'A App Store encontrou um erro de sistema. Tente mais tarde.';

  @override
  String get premiumRegionUnavailable =>
      'Esta assinatura Premium não está disponível na sua região da App Store.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'Este app não pode fazer esta solicitação à App Store. Entre em contato com o suporte.';

  @override
  String get premiumPurchaseNotSupported =>
      'Esta compra não é compatível com este dispositivo ou versão do sistema.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'A janela de compra da App Store não abriu. Volte ao app e tente novamente.';

  @override
  String get premiumAppStoreFailedAccept =>
      'A App Store não aceitou esta quantidade de compra. Entre em contato com o suporte.';

  @override
  String get premiumAppStoreUnavailable =>
      'Esta assinatura Premium está indisponível na App Store no momento.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'Compras não são permitidas neste dispositivo. Confira sua Conta Apple e as restrições de compra.';

  @override
  String get premiumAppleAccountNotEligible =>
      'Sua Conta Apple não é elegível para esta oferta de assinatura.';

  @override
  String get premiumSubscriptionOffer =>
      'Esta oferta de assinatura está indisponível. Atualize a página e tente novamente.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'A App Store não aceitou o preço desta oferta. Atualize a página e tente novamente.';

  @override
  String get premiumAppStoreFailedVerify =>
      'A App Store não conseguiu verificar esta oferta de assinatura. Entre em contato com o suporte.';

  @override
  String get premiumSubscriptionOfferFailed =>
      'Não foi possível preparar esta oferta de assinatura. Atualize a página e tente novamente.';

  @override
  String get premiumAddPaymentMethodApple =>
      'Adicione um método de pagamento à sua Conta Apple e tente novamente.';

  @override
  String get premiumAppCannotMakePurchases =>
      'Este app não pode fazer compras na App Store. Entre em contato com o suporte.';

  @override
  String get premiumAppStoreRequestRejected =>
      'A App Store não aceitou esta solicitação de compra. Tente novamente ou contate o suporte.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'O acesso aos serviços de nuvem da Apple foi negado. Confira as permissões da sua Conta Apple.';

  @override
  String get premiumFailedConnectApple =>
      'Não foi possível conectar aos serviços da Apple. Confira sua conexão com a internet e tente novamente.';

  @override
  String get premiumAccess2AppleCloudService =>
      'O acesso aos serviços de nuvem da Apple foi revogado. Confira as configurações da sua Conta Apple.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Aceite os termos de privacidade mais recentes da Apple na sua Conta Apple e tente novamente.';

  @override
  String get premiumAppStoreWindowFailed =>
      'Não foi possível configurar a janela da App Store. Entre em contato com o suporte.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'A janela da App Store demorou a abrir. Tente novamente.';

  @override
  String get premiumReturnAppTryPurchase =>
      'Volte ao app e tente comprar novamente.';

  @override
  String get premiumGooglePlayUnavailable =>
      'O Google Play está indisponível. Confira se está instalado e se você está conectado.';

  @override
  String get premiumIs4Subscription =>
      'Esta assinatura Premium está indisponível na loja no momento. Atualize a página e tente novamente.';

  @override
  String get premiumSubscriptionFailed =>
      'Não foi possível preparar esta assinatura Premium. Atualize a página e tente novamente.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'A loja não conseguiu abrir esta compra de Premium. Tente novamente.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'A assinatura original não foi encontrada no Google Play. Confira Gerenciar assinaturas.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'Esta assinatura usa outra identidade de compra. Atualize a página ou contate o suporte.';

  @override
  String get premiumGooglePlayCannotChange =>
      'O Google Play ainda não pode alterar esta assinatura. Confira Gerenciar assinaturas.';

  @override
  String get premiumPlanChangePending =>
      'A App Store ainda está processando uma compra deste plano. Aguarde a conclusão.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'Não foi possível carregar os planos Premium da App Store. Tente novamente.';

  @override
  String get premiumPurchasePreparation =>
      'A preparação da compra expirou. Tente novamente.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'A App Store retornou um resultado de compra desconhecido. Confira sua assinatura antes de tentar novamente.';

  @override
  String get premiumPurchasesUnavailable =>
      'As compras estão indisponíveis no momento.';

  @override
  String get premiumAutoRenewsCancelAnytime =>
      'Renovação automática. Cancele quando quiser.';

  @override
  String get premiumSubscribed => 'Assinado';

  @override
  String get premiumAlsoIncluded => 'Também inclui';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'Gemas rosas';

  @override
  String get premiumRedGems => 'Gemas vermelhas';

  @override
  String get premiumExtraDailyCheck => 'Extra no check-in diário';

  @override
  String get premiumDailyCheck => 'Check-in diário';

  @override
  String get premiumClaimedMonthly => 'Resgate mensal';

  @override
  String get premiumBilledMonthly => 'Cobrança mensal';

  @override
  String premiumSaveSavings({required String savings}) {
    return 'Economize $savings%';
  }

  @override
  String get premiumSubscribe => 'Assinar';

  @override
  String get premiumActiveYearlySubscription =>
      'Uma assinatura anual Premium ativa não pode ser alterada para um plano mensal.';

  @override
  String get premiumAlreadyHaveActive =>
      'Você já tem uma assinatura Premium ativa.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'Você já assina Premium $label.';
  }

  @override
  String get premiumPreviousPurchasePending =>
      'Sua compra anterior de Premium ainda está sendo confirmada.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Use a loja original para fazer upgrade da sua assinatura Premium.';

  @override
  String get premiumResolveCurrent =>
      'Resolva sua assinatura atual na loja antes de comprar.';

  @override
  String get premiumPurchaseUnavailable =>
      'A compra de Premium está indisponível no momento.';

  @override
  String get premiumUnableVerifyPurchase =>
      'Não foi possível verificar sua elegibilidade para comprar. Tente novamente.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      'A loja não conseguiu verificar esta compra de Premium.';

  @override
  String get premiumPurchaseDoesNotMatch =>
      'A compra de Premium não corresponde ao plano selecionado.';

  @override
  String get premiumMessagePurchaseCanceled =>
      'Esta compra de Premium foi cancelada.';

  @override
  String get premiumPurchaseRevoked => 'Esta compra de Premium foi revogada.';

  @override
  String get premiumNotification => 'Notificação';

  @override
  String get premiumWorldoActiveSubscription =>
      'O Worldo Premium está ativo na sua assinatura e não permite mudar para um plano inferior.';

  @override
  String get premiumGot => 'Entendi';

  @override
  String get gemBalancePromptInsufficientGems => 'Gemas insuficientes';

  @override
  String get gemBalancePromptLowGems => 'Poucas gemas';

  @override
  String get appPressBackExit => 'Pressione Voltar novamente para sair.';

  @override
  String get appReportSubmitted => 'Denúncia enviada';

  @override
  String get appReportFailed => 'Falha ao enviar denúncia';

  @override
  String get appUpdateRequired => 'Atualização necessária';

  @override
  String get appUpdateContent =>
      'Atualize para a versão mais recente para continuar usando o Worldo.';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'Versão $versionName';
  }

  @override
  String get appUpdateCheckFailed =>
      'Não foi possível atualizar o estado da atualização. Atualize o app para continuar.';

  @override
  String get appUpdate => 'Atualizar agora';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabel copiado';
  }

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonImageLoadFailed => 'Falha ao carregar imagem';

  @override
  String get commonPageNotFound => 'Página não encontrada.';

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
    return 'O LLM está gerando seu primeiro Tick. Isso pode levar um momento$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return 'Última versão: V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return 'Salve $missingSections antes de criar.';
  }

  @override
  String get createCharacterRoleHint => 'O papel do personagem no worldo.';

  @override
  String get createCharacterMannerHint =>
      'A forma de falar e agir do personagem, que orienta seus diálogos.';

  @override
  String get createCharacterGoalHint =>
      'O objetivo ou a orientação comportamental do personagem, que guia suas ações.';

  @override
  String get createCharacterBackgroundHint =>
      'Os antecedentes e os relacionamentos do personagem.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return 'solicita entrar em $world$worldIdSuffix';
  }

  @override
  String get memoryModel => 'Memória e modelo';

  @override
  String get premiumAccountMismatch =>
      'Os identificadores da conta não correspondem aos da assinatura anterior.';

  @override
  String get worldRecap => 'Resumo';

  @override
  String get inboxMissingJoinRequestId =>
      'ID da solicitação de entrada ausente';

  @override
  String get loginTimedOut => 'O tempo para entrar esgotou. Tente novamente.';

  @override
  String get loginConnectionFailed =>
      'Não foi possível conectar. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get loginTemporarilyUnavailable =>
      'Não é possível entrar no momento. Tente novamente mais tarde.';

  @override
  String get recapUnlockHeading => 'Desbloqueia o resumo';

  @override
  String get recapUpsellDescription =>
      'Acompanhe sua história com um resumo completo de cada reviravolta, escolha e personagem ao longo do caminho.';

  @override
  String get recapShowEarlier => 'Ver resumos anteriores';

  @override
  String get recapEmpty =>
      'O resumo aparecerá aqui conforme a história avançar.';

  @override
  String get chatMessageAsNarrator => 'Enviar mensagem como narrador';

  @override
  String chatMessageAsCharacter({required String name}) {
    return 'Enviar mensagem como $name';
  }

  @override
  String get chatNarratorSpeaker => 'o narrador';

  @override
  String get chatYourCharacterSpeaker => 'seu personagem';

  @override
  String chatSpeakingAs({required String speaker}) {
    return 'Falando como $speaker';
  }

  @override
  String get chatSwitchCharacter => 'Mudar para personagem';

  @override
  String get chatSwitchNarration => 'Mudar para narração';

  @override
  String chatOpenLocation({required String locationName}) {
    return 'Abrir $locationName';
  }

  @override
  String get chatRetryMessage => 'Tentar enviar a mensagem novamente';

  @override
  String get blockedReportFailed =>
      'Usuário bloqueado, mas não foi possível enviar a denúncia.';

  @override
  String get storeConnectionFailed =>
      'Não foi possível conectar à loja. Tente novamente.';

  @override
  String get storeProductUnavailable =>
      'Este produto não está disponível no momento.';

  @override
  String get storeDevicePurchasesUnavailable =>
      'Não é possível fazer compras neste dispositivo.';

  @override
  String get worldHistoryRequestFailed =>
      'Não foi possível carregar o histórico do mundo';

  @override
  String get genericError => 'Ocorreu um erro';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': 'Premium $plan, $price por ano',
      'other': 'Premium $plan, $price por mês',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => 'Não foi possível limpar';

  @override
  String get developerGatewaySignatureFailed =>
      'Falha na verificação da assinatura do Gateway';

  @override
  String get developerEndpointsSaved =>
      'Salvo. As novas solicitações usarão os endpoints configurados.';

  @override
  String get developerAdjustRestartRequired =>
      'Reinicie o app para aplicar o ambiente do Adjust.';

  @override
  String developerRecapSetting({required String mode}) {
    return 'Resumo do mundo: $mode';
  }

  @override
  String get developerRecapPreview => 'Prévia do resumo do mundo';

  @override
  String get developerRecapPreviewDescription =>
      'Substitui temporariamente o status da assinatura e o conteúdo do resumo no painel do mundo. É redefinido ao reiniciar o app.';

  @override
  String get developerResetFailed => 'Não foi possível redefinir';

  @override
  String get developerRecapOff => 'Desativado (conforme a assinatura)';

  @override
  String get developerRecapLocked => 'Bloqueado · sem assinatura';

  @override
  String get developerRecapEmpty => 'Assinante · ainda não gerado';

  @override
  String get developerRecapSample => 'Assinante · resumo de exemplo';

  @override
  String get developerRecapLive => 'Assinante · resumo real';

  @override
  String get chatEditFreeUsesExhausted =>
      'Você não tem mais edições gratuitas.';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'Assinatura: $selection';
  }

  @override
  String get developerMembershipDescription =>
      'Altera temporariamente o status da assinatura desta conta em todas as telas. O servidor continua usando o status real da conta. A alteração é desfeita ao reiniciar o app.';

  @override
  String get developerMembershipOff => 'Desativado (assinatura real)';

  @override
  String get developerMembershipYearly => 'Premium · anual';

  @override
  String get developerMembershipMonthly => 'Premium · mensal';

  @override
  String get developerMembershipNone => 'Sem assinatura';

  @override
  String get originStartBySelectingRole => 'Comece escolhendo seu personagem';

  @override
  String get originRecommendedStart => 'Início recomendado';

  @override
  String get originStoryOpening => 'Início da história';

  @override
  String get originOpeningLocation => 'Local inicial';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names estão agora em\n$locationName',
      one: '$names está agora em\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return 'Início da história\n$locationName';
  }

  @override
  String get chatHistoryExpand => 'Expandir';

  @override
  String get chatHistoryCollapse => 'Recolher';

  @override
  String get worldHistory => 'Histórico';

  @override
  String get worldHistoryEmpty =>
      'O histórico de chat do seu mundo aparecerá aqui.';

  @override
  String get worldHistoryContinueHere => 'Continue aqui';

  @override
  String get chatCharacterMovement => 'Movimentação de personagens';

  @override
  String get miniPhoneCreatePost => 'Criar publicação';

  @override
  String get miniPhoneCreate => 'Criar';

  @override
  String get miniPhonePostHint => 'No que você está pensando?';

  @override
  String get miniPhonePhotoOptional => 'Foto (opcional)';

  @override
  String get miniPhoneChoosePhoto => 'Escolher foto';

  @override
  String get miniPhoneReplacePhoto => 'Trocar foto';

  @override
  String get miniPhoneRemovePhoto => 'Remover foto';

  @override
  String get miniPhonePublish => 'Publicar';

  @override
  String get miniPhoneComingSoon => 'Em breve.';

  @override
  String get miniPhoneViewAllComments => 'Ver todos os comentários';

  @override
  String get miniPhoneMessages => 'Mensagens';

  @override
  String get miniPhonePosts => 'Publicações';

  @override
  String get miniPhonePhotos => 'Fotos';

  @override
  String get miniPhoneSettings => 'Configurações';

  @override
  String get miniPhoneMusic => 'Música';

  @override
  String get miniPhoneComments => 'Comentários';

  @override
  String get miniPhoneCamera => 'Câmera';

  @override
  String get miniPhoneMaps => 'Mapas';

  @override
  String get miniPhoneCalendar => 'Calendário';

  @override
  String get miniPhonePublishedPost => 'Fez uma publicação';

  @override
  String get miniPhoneLikedPost => 'Curtiu uma publicação';

  @override
  String get miniPhoneCommentedPost => 'Comentou uma publicação';

  @override
  String get miniPhoneRepliedComment => 'Respondeu a um comentário';

  @override
  String get miniPhonePostActivity => 'Atividade de publicações';

  @override
  String get miniPhoneShowLess => 'Mostrar menos';

  @override
  String get miniPhoneShowAll => 'Mostrar tudo';

  @override
  String get miniPhoneClose => 'Fechar minitelefone';

  @override
  String get miniPhoneYou => 'Você';

  @override
  String get miniPhoneUnknown => 'Desconhecido';

  @override
  String miniPhoneOwnMessage({required String message}) {
    return 'Você: $message';
  }

  @override
  String get miniPhonePrivateConversation => 'Conversa privada';

  @override
  String get miniPhoneNewMessages => 'Novas mensagens ↓';

  @override
  String get miniPhoneReconnecting => 'Reconectando… Aguardando confirmação';

  @override
  String miniPhoneTyping({required String name}) {
    return '$name está digitando…';
  }

  @override
  String get miniPhoneSend => 'Enviar';

  @override
  String miniPhoneMessageHint({required String name}) {
    return 'Envie uma mensagem para $name…';
  }

  @override
  String get miniPhoneAwaitingConfirmation => 'Aguardando confirmação';

  @override
  String miniPhoneCommentCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentários',
      one: '1 comentário',
      zero: '0 comentários',
    );
    return '$_temp0';
  }

  @override
  String get miniPhoneFirstComment =>
      'Seja a primeira pessoa a compartilhar o que pensa.';

  @override
  String get miniPhoneCommentHint => 'Escreva um comentário…';

  @override
  String miniPhoneReplyHint({required String name}) {
    return 'Responda a $name…';
  }

  @override
  String get miniPhoneLike => 'Curtir';

  @override
  String get miniPhoneAllAuthors => 'Todos os autores';

  @override
  String get miniPhoneWallpaper => 'Papel de parede';

  @override
  String get miniPhoneUpload => 'Enviar';

  @override
  String get miniPhoneApplyWallpaper => 'Aplicar papel de parede';

  @override
  String get miniPhoneSettingsSubtitle => 'Deixe este telefone com a sua cara.';

  @override
  String get miniPhonePhotoOpenFailed =>
      'Não foi possível abrir esta foto. Tente outra.';

  @override
  String get miniPhoneWallpaperApplied => 'Papel de parede aplicado.';

  @override
  String miniPhoneFromWorldo({required String name}) {
    return 'De $name';
  }

  @override
  String get miniPhonePreviousTrack => 'Faixa anterior';

  @override
  String get miniPhoneNextTrack => 'Próxima faixa';

  @override
  String get miniPhonePlay => 'Reproduzir';

  @override
  String get miniPhonePause => 'Pausar';

  @override
  String miniPhoneLikeTrack({required String title}) {
    return 'Curtir $title';
  }

  @override
  String miniPhoneUnlikeTrack({required String title}) {
    return 'Descurtir $title';
  }

  @override
  String miniPhoneOpenMusic({required String title}) {
    return 'Abrir música: $title';
  }

  @override
  String get miniPhonePlayMusic => 'Reproduzir música';

  @override
  String get miniPhonePauseMusic => 'Pausar música';

  @override
  String miniPhoneOpenUnread({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abrir minitelefone, $count mensagens não lidas',
      one: 'Abrir minitelefone, 1 mensagem não lida',
      zero: 'Abrir minitelefone, 0 mensagens não lidas',
    );
    return '$_temp0';
  }

  @override
  String miniPhoneHomePosition({required int position}) {
    return 'Página inicial $position';
  }

  @override
  String miniPhoneLockedApp({required String name}) {
    return '$name, bloqueado';
  }

  @override
  String miniPhoneWorldDay({required int day}) {
    return 'Dia $day';
  }

  @override
  String get miniPhoneModel => 'Modelo';

  @override
  String get miniPhoneLoadFailed =>
      'Não foi possível carregar. Tente novamente.';

  @override
  String get miniPhoneAccountFailed =>
      'Não foi possível ler sua conta. Tente novamente.';

  @override
  String get miniPhoneOpenFromWorld =>
      'Entre na sua conta e abra o minitelefone a partir de um Mundo.';

  @override
  String get miniPhoneSaveMessagesFailed =>
      'Não foi possível salvar as mensagens neste dispositivo. Tente novamente.';

  @override
  String get miniPhoneLoadSavedMessagesFailed =>
      'Não foi possível carregar as mensagens salvas. Tente novamente.';

  @override
  String get miniPhoneLoadDeviceMessagesFailed =>
      'Não foi possível carregar as mensagens salvas neste dispositivo. Tente novamente.';

  @override
  String get miniPhoneSaveRequestsFailed =>
      'Não foi possível salvar as solicitações do telefone neste dispositivo. Tente novamente.';

  @override
  String get miniPhonePreviousRequestPending =>
      'A solicitação anterior ainda aguarda confirmação.';

  @override
  String get miniPhoneReplyFailed => 'Não foi possível gerar a resposta.';

  @override
  String get miniPhonePreparePhotoFailed =>
      'Não foi possível preparar esta foto. Tente novamente.';

  @override
  String get miniPhoneUploadPhotoFailed =>
      'Não foi possível enviar esta foto. Tente novamente.';

  @override
  String get miniPhoneTextTooLong =>
      'O texto do telefone não pode exceder 65535 bytes em UTF-8';

  @override
  String get miniPhoneLoadWallpapersFailed =>
      'Não foi possível carregar os papéis de parede. Tente novamente.';

  @override
  String get miniPhoneSaveWallpaperFailed =>
      'Não foi possível salvar o papel de parede. Tente novamente.';

  @override
  String get miniPhoneMusicLikeFailed =>
      'Não foi possível atualizar o status de curtida da música. Tente novamente.';

  @override
  String get miniPhoneLoadMusicFailed =>
      'Não foi possível carregar a música. Tente novamente.';

  @override
  String get miniPhonePlayMusicFailed =>
      'Não foi possível reproduzir esta faixa. Toque em reproduzir para tentar novamente.';

  @override
  String get miniPhoneInvalidResponse => 'Resposta inválida do minitelefone';

  @override
  String miniPhoneContactAdded({required String name}) {
    return 'Você adicionou $name.';
  }

  @override
  String miniPhoneCharacterIntroduction({required String name}) {
    return 'Sou $name.';
  }

  @override
  String get miniPhonePostsEmpty =>
      'Ainda não há publicações. Compartilhe um momento da sua história.';

  @override
  String get gemsProductUnavailable => 'Este produto não está disponível.';

  @override
  String get gemsTypeUnsupported => 'Este tipo de produto não é compatível.';

  @override
  String get gemsPurchaseTimeout =>
      'A compra excedeu o tempo limite. Tente novamente.';

  @override
  String get gemsPaymentUnavailable =>
      'O serviço de pagamento está indisponível.';

  @override
  String get gemsPaymentPending => 'O pagamento está pendente.';

  @override
  String get gemsPaymentConfirming => 'O pagamento está sendo confirmado.';

  @override
  String get gemsPurchaseRefunded => 'A compra foi reembolsada.';

  @override
  String get premiumReportFailed => 'Falha ao informar a compra.';

  @override
  String get premiumVerifyFailed =>
      'Não foi possível verificar sua assinatura. Entre em contato com o suporte.';

  @override
  String get rateWorldoTitle => 'Avalie o Worldo';

  @override
  String get rateWorldoMessage =>
      'Está gostando do Worldo? Sua opinião é importante para nós.';

  @override
  String rateWorldoStars({required int count}) {
    return '$count estrelas';
  }

  @override
  String get rateWorldoFeedbackHint =>
      'Conte como podemos melhorar sua experiência';

  @override
  String get rateWorldoThanks => 'Obrigado pela sua opinião!';

  @override
  String get rateWorldoFeedbackSaved => 'Sua opinião foi salva.';

  @override
  String rateWorldoRewardMessage({required int gems}) {
    return 'Sua opinião nos ajuda a melhorar. Resgate $gems Gemas como agradecimento.';
  }

  @override
  String get rateWorldoStoreFailed =>
      'Não foi possível abrir a loja de aplicativos. Tente novamente.';

  @override
  String gemsDailyResetsIn({required String time}) {
    return 'Reinicia em $time';
  }

  @override
  String get privacyChoicesSettings => 'Configurações de privacidade';

  @override
  String get privacyChoicesTitle => 'Configurações de privacidade';

  @override
  String privacyChoicesIntro({required String privacyPolicy}) {
    return 'Escolha como seus dados são usados no Worldo: Firebase Analytics para analisar o uso do app, Google para medir o desempenho de anúncios e personalizá-los, e Adjust para medir o desempenho de anúncios e a atribuição. Leia nossa $privacyPolicy.';
  }

  @override
  String get privacyChoicesConsent => 'Concordar';

  @override
  String get privacyChoicesReject => 'Não concordar';

  @override
  String get privacyChoicesManage => 'Gerenciar opções';

  @override
  String get privacyChoicesAcceptAll => 'Aceitar tudo';

  @override
  String get privacyChoicesConfirm => 'Confirmar escolhas';

  @override
  String get privacyChoicesAdStorage => 'Armazenamento publicitário';

  @override
  String get privacyChoicesAdStorageDescription =>
      'Permita que informações relacionadas à publicidade sejam armazenadas e acessadas no seu dispositivo.';

  @override
  String get privacyChoicesAdUserData =>
      'Compartilhamento de dados publicitários';

  @override
  String get privacyChoicesAdUserDataDescription =>
      'Permita que o Google use seus dados para medir o desempenho publicitário.';

  @override
  String get privacyChoicesPersonalization => 'Anúncios personalizados';

  @override
  String get privacyChoicesPersonalizationDescription =>
      'Permita que o Google use seus dados para mostrar anúncios personalizados.';

  @override
  String get privacyChoicesAnalytics => 'Análise de uso';

  @override
  String get privacyChoicesAnalyticsDescription =>
      'Permita que o Firebase Analytics armazene e use informações sobre como você usa o Worldo para nos ajudar a melhorar o app.';

  @override
  String get privacyChoicesPartners => 'Nossos parceiros';

  @override
  String privacyChoicesPartnersDescription({required String privacyPolicy}) {
    return 'O Firebase Analytics analisa o uso do app, o Google mede o desempenho de anúncios e os personaliza, e a Adjust mede o desempenho de anúncios e a atribuição. Saiba mais em nossa $privacyPolicy.';
  }

  @override
  String get privacyChoicesLoadError =>
      'Não foi possível carregar as opções de privacidade.';

  @override
  String get privacyChoicesSaveError =>
      'Não foi possível salvar as opções de privacidade. Tente novamente.';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get imageGifUnsupported => 'GIF 애니메이션은 지원하지 않습니다.';

  @override
  String get worldProgressComplete => '진행 완료';

  @override
  String a11ySwitchMode({required String label}) {
    return '$label 모드로 전환';
  }

  @override
  String a11yEditItem({required String title}) {
    return '$title 편집';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return '역할 카드 $index/$count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return '영감 $index 편집';
  }

  @override
  String a11yInsert({required String label}) {
    return '$label 삽입';
  }

  @override
  String get a11yMembership => '멤버십';

  @override
  String get a11yOpenWorldo => 'Worldo 열기';

  @override
  String get a11yFilterGender => '성별로 필터링';

  @override
  String get a11ySelectRole => '내 역할 선택';

  @override
  String get a11yLoadingMap => '지도 불러오는 중';

  @override
  String get a11yBuildingWorld => '월드 생성 중';

  @override
  String get a11yPremiumMembership => 'Premium 멤버십';

  @override
  String get a11yProMembership => 'Pro 멤버십';

  @override
  String get a11yRecommendedRole => '추천 역할';

  @override
  String get a11yLastMessage => '마지막 메시지';

  @override
  String get a11yRecentChat => '최근 채팅';

  @override
  String get a11yAiReplyLoading => 'AI 답변 불러오는 중';

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
      other: '플레이어',
      one: '플레이어',
      zero: '플레이어',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (추가됨 / 최대)';
  }

  @override
  String get createSixHours => '6시간';

  @override
  String get createTwelveHours => '12시간';

  @override
  String get createOneDay => '1일';

  @override
  String get createOneWeek => '1주';

  @override
  String get settingsLanguage => '언어';

  @override
  String get languageChangeFailed => '언어를 변경하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get purchasingGems => '젬 구매 중';

  @override
  String get purchaseSuccessful => '구매 완료!';

  @override
  String get okAction => '확인';

  @override
  String get cancelAction => '취소';

  @override
  String get requestAction => '신청';

  @override
  String get requestedStatus => '신청됨';

  @override
  String get launchAction => '시작';

  @override
  String get tickNowAction => '지금 Tick';

  @override
  String get writePostHint => '게시물 작성';

  @override
  String get newPostTitle => '새 게시물';

  @override
  String get aiIsGenerating => 'AI 생성 중';

  @override
  String get generatingCustomizedWorldWait =>
      '나만의 살아 있는 월드를 생성하고 있습니다.\n잠시 기다려 주세요.';

  @override
  String get approvedStatus => '승인됨';

  @override
  String get rejectedStatus => '거절됨';

  @override
  String get awaitingApprovalStatus => '승인 대기 중';

  @override
  String get awaitingYourApprovalStatus => '내 승인 대기 중';

  @override
  String get liveYourWorld => '나만의 월드를 살아보세요';

  @override
  String get signedOutMeDescription =>
      '월드에서 플레이하고, worldo를 만들고, 친구를 초대하세요.\n어디서든 이야기를 이어갈 수 있습니다.';

  @override
  String get gemTaskLaunchWorldHint => '마음에 드는 Worldo를 열고 시작하여 나만의 월드를 만드세요.';

  @override
  String get gemTaskInviteFriendHint => '월드를 열고 상세 패널에서 초대를 누르세요.';

  @override
  String get gemTaskWriteCommentHint => '마음에 드는 Worldo를 열고 토론에서 게시물을 작성하세요.';

  @override
  String get gemTaskRequestJoinHint => '아직 참여하지 않은 월드를 열고 참여를 신청하세요.';

  @override
  String get gemTaskSendMessageHint => '내 월드에서 메시지를 보내세요.';

  @override
  String get gemTaskProgressWorldHint => '플레이 중인 월드를 열고 지금 Tick을 누르세요.';

  @override
  String get termsOfService => '서비스 이용약관';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => '월드';

  @override
  String get userLabel => '사용자';

  @override
  String get meLabel => '나';

  @override
  String get locationLabel => '장소';

  @override
  String get allLabel => '전체';

  @override
  String get maleLabel => '남성';

  @override
  String get femaleLabel => '여성';

  @override
  String get nonBinaryLabel => '논바이너리';

  @override
  String get forYouLabel => '추천';

  @override
  String get userBlocked => '사용자를 차단했습니다';

  @override
  String get purchaseCanceled => '구매가 취소되었습니다.';

  @override
  String get purchasePending => '구매가 대기 중입니다.';

  @override
  String get purchaseConfirmationDelayed => '구매 확인이 지연되고 있습니다. 나중에 다시 확인해 주세요.';

  @override
  String get purchaseFailed => '구매에 실패했습니다.';

  @override
  String get yearlyPlan => '연간';

  @override
  String get monthlyPlan => '월간';

  @override
  String get proSubscriptionTagline => '플레이하는 모든 Worldo를 더 깊이 즐겨보세요.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, 연간 결제';
  }

  @override
  String expiresOn({required String date}) {
    return '만료일: $date';
  }

  @override
  String get activeStatus => '활성';

  @override
  String get expiredStatus => '만료됨';

  @override
  String updatedAt({required String timestamp}) {
    return '업데이트: $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => '불러오기 실패. 다시 시도';

  @override
  String get loadMoreAction => '더 불러오기';

  @override
  String get gemPurchaseRecord => '젬 구매';

  @override
  String get taskRewardRecord => '과제 보상';

  @override
  String get worldProgressRecord => '월드 진행';

  @override
  String get directMessageRecord => '개인 메시지';

  @override
  String get gemRecord => '젬 기록';

  @override
  String get runATickTask => 'Tick 1회 실행';

  @override
  String get runATickTaskDescription => '플레이 중인 월드를 열고 지금 Tick을 누르세요.';

  @override
  String get someoneFallback => '누군가';

  @override
  String get aCharacterFallback => '캐릭터';

  @override
  String get thisWorld => '이 월드';

  @override
  String get noWorldEventsYet => '아직 월드 이벤트가 없습니다.';

  @override
  String get globalLabel => '전체';

  @override
  String get eventLabel => '이벤트';

  @override
  String get characterDestinations => '캐릭터 목적지';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName: $locationName에 $direction';
  }

  @override
  String get cameToDirection => '도착했습니다';

  @override
  String get wentToDirection => '이동했습니다';

  @override
  String get hasComeToDirection => '도착했습니다';

  @override
  String get hasGoneToDirection => '이동했습니다';

  @override
  String get waitForReplyToSendMore => '답변을 받은 후 다음 메시지를 보내세요';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새 메시지 $count개',
      one: '새 메시지 $count개',
      zero: '새 메시지 $count개',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation => '기본 역할을 선택해 주세요';

  @override
  String get enterNameValidation => '이름을 입력해 주세요';

  @override
  String get enterIdentityValidation => '신분을 입력해 주세요';

  @override
  String get waitForProfileLoading => '프로필을 모두 불러올 때까지 기다려 주세요.';

  @override
  String get imageUploadFailed => '이미지 업로드에 실패했습니다.';

  @override
  String get photoAccessDenied => '사진 접근이 거부되었습니다';

  @override
  String get feedbackSubmitted => '의견을 보냈습니다';

  @override
  String get feedbackFailed => '의견 전송에 실패했습니다';

  @override
  String get worldoDetailUnavailable => 'Worldo 상세 정보를 볼 수 없습니다.';

  @override
  String get publishAction => '공개';

  @override
  String get publishingStatus => '공개 중...';

  @override
  String get publishFailed => '공개에 실패했습니다';

  @override
  String get publishChangesBeforeLeaving => '나가기 전에 변경 사항을 공개할까요?';

  @override
  String get noChangesToPublish => '공개할 변경 사항이 없습니다.';

  @override
  String get completeOpeningRequiredToPublish => '공개하려면 도입부를 완성해야 합니다';

  @override
  String get publishResponseMissingOriginId => '공개 결과에 Worldo ID가 없습니다.';

  @override
  String get worldoIdRequired => 'Worldo ID가 필요합니다.';

  @override
  String loadFailedWithReason({required String reason}) {
    return '불러오기 실패: $reason';
  }

  @override
  String get imageSelectionFailed => '이미지 선택에 실패했습니다';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID: $oid\n최신 버전: $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID: $wid\n소유자: $owner';
  }

  @override
  String get sendFailed => '전송에 실패했습니다';

  @override
  String get selectARole => '역할 선택';

  @override
  String get timeLabel => '시간';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID: $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID: $oid · 크리에이터: $creator';
  }

  @override
  String get worldoMetricExplanation =>
      '이 worldo는 진행할 때마다 각 캐릭터의 {지표 이름}을 업데이트하고 {단위}로 표시합니다. 각 캐릭터는 {초기값}에서 시작하며, 값은 {최소 변동값}~{최대 변동값} 범위에서 변할 수 있습니다.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return '$worldo 시작으로\n나만의 월드 생성';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return '다음 메시지 예상 비용: $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '젬 $amount개';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return '월드 $worldName 삭제';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername님이 $characterName 역할로 플레이 중';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName 시작 완료!';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName 생성 완료!';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName 공개 완료!';
  }

  @override
  String get createTimeout => 'Worldo 생성 시간이 초과되었습니다.';

  @override
  String get publishTimeout => 'Worldo 공개 시간이 초과되었습니다';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return '$worldName$worldId 참여를 신청했습니다';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge님이 $worldName$worldId 참여를 신청했습니다';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge님이 내 worldo에 댓글을 남겼습니다';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge님이 내게 답글을 남겼습니다';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge님이 내 댓글에 좋아요를 눌렀습니다';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge님이 메시지를 보냈습니다';
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
    return '남은 무료 영감 사용 횟수: $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return '남은 무료 편집 횟수: $remaining\n$action';
  }

  @override
  String get getMoreAction => '더 받기 >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName: $locationName에 도착했습니다';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldo에서 캐릭터와 이야기, 변화하는 이벤트로 가득한 AI 월드를 만들고 발견하고 탐험할 수 있습니다. AI 캐릭터와 대화하고 친구들과 플레이하며, 몰입감 있는 장면과 선택으로 각 월드를 진행해 보세요.\n\n이 앱은 독자로서뿐 아니라 월드의 일원으로서 인터랙티브 스토리를 경험하는 새로운 방법을 제공합니다. 궁금한 점은 $contactEmail로 문의해 주세요.';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy, $termsOfUse 및 $endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return '계속하면 $terms, $privacyPolicy 및 $endUserLicenseAgreement에 동의하게 됩니다';
  }

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get terms => '약관';

  @override
  String get termsOfUse => '이용약관';

  @override
  String get endUserLicenseAgreement => '최종 사용자 라이선스 계약';

  @override
  String existingAccountSignIn({required String signIn}) {
    return '계정이 있다면 $signIn';
  }

  @override
  String get signInAction => '로그인하세요.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return '$gemIcon젬 $grantedAmount개가 지급되었습니다.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return '매월 최대 젬 $amount개와 모든 Premium 기능 이용.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /일';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/월';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: $replyToName$replyToBadge님에게 답글: $content';
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
  String get homeLoadFailed => '불러오기에 실패했습니다';

  @override
  String get homeRetry => '다시 시도';

  @override
  String get homeEmptyDescription =>
      'Worldo는 설계도입니다. 시작하면 직접 들어가 발전시킬 수 있는 살아 있는 월드가 생성됩니다.';

  @override
  String get homeWorldCharacter => '캐릭터';

  @override
  String get homeWorldSingleOtherPlayer => '· 다른 플레이어 1명';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· 다른 플레이어 $otherPlayerCount명';
  }

  @override
  String get homeSignInUnavailable => '로그인할 수 없습니다';

  @override
  String get homeSignedOutTitle => '내 모든 월드를 한곳에서';

  @override
  String get homeSignedOutDescription => '로그인하여 월드를 만들고 이야기를 이어가세요.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return '소유자: $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID: $oid  크리에이터: $originator\n소개: $brief\n최신 버전: $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID: $wid\n소유자: $owner';
  }

  @override
  String get searchHistory => '검색 기록';

  @override
  String get searchFailed => '검색에 실패했습니다';

  @override
  String get searchNoResults => '결과가 없습니다.';

  @override
  String get searchCancel => '취소';

  @override
  String get searchHint => 'Worldo, 캐릭터, 태그';

  @override
  String get worldDetailOnlyWorldsLaunched => '혼자 시작한 월드만 삭제할 수 있습니다.';

  @override
  String get worldDetailDelete => '삭제';

  @override
  String get worldDetailNoCharacterStatusYet => '아직 캐릭터 상태가 없습니다.';

  @override
  String get worldDetailNoCharactersYet => '아직 캐릭터가 없습니다.';

  @override
  String get worldDetailProgressingWorld => '월드 진행 중';

  @override
  String get worldDetailCompressingRecent =>
      '최근 기억 압축 중\n월드 시간축 진행 중\n다음 이야기 전개 생성 중\n캐릭터 위치 업데이트 중';

  @override
  String get worldModelsDetail => '상세 정보';

  @override
  String get worldModelsLocations => '장소';

  @override
  String get worldModelsEvents => '이벤트';

  @override
  String get worldModelsStatus => '상태';

  @override
  String get worldDetailUnavailable => '이용할 수 없습니다';

  @override
  String worldActionFailed({required String actionLabel}) {
    return '$actionLabel 실패';
  }

  @override
  String get worldDetailRequestJoinWorld => '이 월드에 참여를 신청할까요?';

  @override
  String get worldDetailRequest => '신청';

  @override
  String get worldDetailLaunchFailed => '시작에 실패했습니다';

  @override
  String get worldDetailNoSavedProfileFound => '저장된 프로필을 찾지 못했습니다';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return '원본 Worldo: $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => '초대';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Worldo에서 내 월드 \"$worldName\"에 참여하세요!\n$wid\nWorldo에서 이 WID를 검색하여 월드를 찾고 참여하세요.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => '월드 소개';

  @override
  String get worldDetailCast => '등장인물';

  @override
  String get worldDetailLinkCopiedShare => '링크를 복사했습니다. 친구들에게 공유하세요.';

  @override
  String get worldMapAction => '지도';

  @override
  String get worldInfoAction => '정보';

  @override
  String worldLocationCount({required String pointsCount}) {
    return '장소 ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => '플레이어';

  @override
  String worldDetailGoal({required String goal}) {
    return '목표: $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet => '아직 캐릭터 상세 정보가 없습니다.';

  @override
  String get worldDetailNoEventsYet => '아직 이벤트가 없습니다.';

  @override
  String get worldDetailLoadEventsFailed => '이벤트를 불러오지 못했습니다.';

  @override
  String homeLocationID({required String id}) {
    return '장소 $id';
  }

  @override
  String get homeBuildingWorld => '월드 생성 중';

  @override
  String get worldMapLoadFailed => '지도를 불러오지 못했습니다';

  @override
  String get worldMapZoomIn => '지도 확대';

  @override
  String get worldMapZoomOut => '지도 축소';

  @override
  String get worldDetailGlobal => '전체';

  @override
  String get worldDetailLocation => '장소';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => '첫 번째 Tick 생성 중';

  @override
  String get worldFirstTickStatusLoadFailed => '생성 상태를 불러오지 못했습니다.';

  @override
  String get worldDetailNew => '새 항목';

  @override
  String get homeUnknownLocation => '알 수 없는 장소';

  @override
  String get homeUnknownCharacter => '알 수 없는 캐릭터';

  @override
  String get homeNewPlaceEmerged => '새로운 장소가 나타났습니다';

  @override
  String get homeNewCharacterAppeared => '새로운 캐릭터가 나타났습니다';

  @override
  String get chatLocationUnavailable => '장소를 이용할 수 없습니다';

  @override
  String get chatRequestApprovalLaunch => '시작 승인 요청';

  @override
  String get chatLoading => '불러오는 중';

  @override
  String get chatQuotaCheckFailed => '무료 사용 횟수를 확인하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get chatInspirationSourceChanged => '영감의 원본이 변경되었습니다. 영감을 다시 열어 주세요.';

  @override
  String get chatInspiration => '영감';

  @override
  String get chatMessageCannotSend => '이 메시지는 더 이상 보낼 수 없습니다';

  @override
  String get chatMessageEmpty => '메시지가 비어 있습니다';

  @override
  String get chatConnectionFailed => '이 채팅에 연결할 수 없습니다';

  @override
  String get chatReplyChangedSelect => '답변이 변경되었습니다. 영감을 다시 선택해 주세요.';

  @override
  String get chatSendConfirmFailed => '메시지 전송을 확인할 수 없습니다';

  @override
  String get chatNoNetworkConnection => '네트워크에 연결되어 있지 않습니다';

  @override
  String get chatRoundCannotContinue => '이 라운드를 계속할 수 없습니다';

  @override
  String get chatSourceRoundChanged => '원본 라운드가 변경되었습니다';

  @override
  String get chatGo => '계속하기';

  @override
  String get chatReplyActionUnavailable => '이 답변 작업은 더 이상 사용할 수 없습니다';

  @override
  String get chatRegenerateFailure => '재생성에 실패했습니다';

  @override
  String get chatGoFailure => '계속하기에 실패했습니다';

  @override
  String get chatEditFailure => '편집에 실패했습니다';

  @override
  String get chatInspirationFailure => '영감 생성에 실패했습니다';

  @override
  String get chatJoinLocationFailed => '이 장소에 참여하지 못했습니다';

  @override
  String get chatInactive => '이 채팅은 더 이상 활성 상태가 아닙니다';

  @override
  String get chatChatroomUnavailable => '채팅방을 이용할 수 없습니다';

  @override
  String get chatFailedConfirmReplyAction => '답변 작업을 확인할 수 없습니다';

  @override
  String get chatLeastOneMessageMustRemain => '최소 하나의 메시지는 남아 있어야 합니다.';

  @override
  String get chatReplyNotEditable => '이 답변은 편집할 수 없습니다';

  @override
  String get chatReplyAlreadyFixed => '이 답변은 확정되었습니다';

  @override
  String get chatReplyEditorFrozen => '답변 편집기가 잠겨 있습니다';

  @override
  String get chatResolvePreviousSaveBefore => '이전 저장을 마친 후 해당 초안을 변경하세요';

  @override
  String get chatStaleReplyEditor => '답변 편집기가 최신 상태가 아닙니다';

  @override
  String get chatPreviousSaveResultUncertain =>
      '이전 저장 결과가 불확실합니다. 다시 불러온 후 편집하세요';

  @override
  String get chatCandidateMissing => '후보가 더 이상 존재하지 않습니다';

  @override
  String get chatBatchSupportsMost100Changes =>
      '한 번의 일괄 처리에는 최대 100개 변경이 가능합니다';

  @override
  String get chatMissingStableMessageIdentity => '메시지의 고정 식별자가 없습니다';

  @override
  String get chatEditTargetHasChanged => '편집 대상이 변경되었습니다';

  @override
  String get chatMessageNotEditable => '이 메시지는 편집할 수 없습니다';

  @override
  String get chatReplyNoLongerEditable => '이 답변은 더 이상 편집할 수 없습니다';

  @override
  String get chatEditorOpenFailed => '편집기를 열지 못했습니다';

  @override
  String get chatInactiveDuringEdit => '이 채팅은 더 이상 활성 상태가 아닙니다.';

  @override
  String get chatEditMessage => '메시지 편집';

  @override
  String get chatSave => '저장';

  @override
  String get chatEdit => '편집';

  @override
  String get chatRegenerate => '재생성';

  @override
  String get chatRegenerateUnavailable => '이 라운드는 재생성할 수 없습니다';

  @override
  String get chatGenerate10Replies => '답변을 최대 10개 생성할 수 있습니다.';

  @override
  String get chatPreviousReply => '이전 답변';

  @override
  String get chatNextReply => '다음 답변';

  @override
  String get chatCopy => '복사';

  @override
  String get chatReport => '신고';

  @override
  String get chatCopied => '복사했습니다';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새 메시지 $count개',
      one: '새 메시지 $count개',
      zero: '새 메시지 $count개',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => '멘션';

  @override
  String get chatCharacters => '캐릭터';

  @override
  String get chatNoCharacters => '캐릭터 없음';

  @override
  String get chatNoLocations => '장소 없음';

  @override
  String get chatHere => '여기';

  @override
  String get chatLoadEarlierMessages => '이전 메시지 불러오기';

  @override
  String get chatText => '메시지 입력...';

  @override
  String get chatLocationRoster => '나';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      '모든 콘텐츠는 AI가 생성한 허구입니다. 실제 인물, 사건 또는 장소와의 유사성은 우연입니다.';

  @override
  String get homeRecent => '최근';

  @override
  String get worldoUnableSavePreference => '설정을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get worldoFilterGender => '성별로 필터링';

  @override
  String get worldoNoData => '데이터 없음';

  @override
  String get worldoAll => '전체';

  @override
  String get worldoDetailSelectRole => '내 역할 선택';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return '크리에이터: $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Worldo 편집';

  @override
  String get worldoDetailWorldoBrief => 'Worldo 소개';

  @override
  String get worldoDetailNewPost => '새 게시물';

  @override
  String get worldoDetailWritePost => '게시물 작성';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return '토론 ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => '모두 보기 >';

  @override
  String get worldoDetailPlayingWorld => '플레이 중인 월드';

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
    return '캐릭터 ($length)';
  }

  @override
  String get worldoSend => '보내기';

  @override
  String get worldoPostFailed => '게시물 등록에 실패했습니다';

  @override
  String get worldoImageUploadFailed => '이미지 업로드에 실패했습니다';

  @override
  String get worldoLoadRepliesFailed => '답글을 불러오지 못했습니다';

  @override
  String get worldoWriteReply => '답글 작성';

  @override
  String worldoReplyName({required String replyToName}) {
    return '$replyToName님에게 답글';
  }

  @override
  String get worldoPostDetail => '게시물 상세';

  @override
  String get worldoPostUnavailable => '게시물을 볼 수 없습니다';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return '모든 답글 $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return '답글 $replyCount개 모두 보기';
  }

  @override
  String get worldoLikeFailed => '좋아요에 실패했습니다';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return '답글 $replyCount개 모두 보기';
  }

  @override
  String get worldoUser => '사용자';

  @override
  String get worldoViewMore => '더 보기 >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return '토론 ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return '답글 $remainingReplyCount개 모두 보기';
  }

  @override
  String get worldoReply => '답글';

  @override
  String get worldoDiscussTitle => '토론';

  @override
  String get worldoLaunchLocationComesLife => '시작하면 이 장소가 살아 움직입니다.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      '이 Worldo를 시작하여 이곳을 탐험하고 교류하세요.';

  @override
  String get worldoLaunchRoleUnavailable => '이 역할은 더 이상 이용할 수 없습니다';

  @override
  String get worldoLaunchSelectRole => '내 역할 선택';

  @override
  String get worldoLaunchProfile => '내 프로필';

  @override
  String get worldoLaunchSuggested => '추천';

  @override
  String get worldoLaunchName => '이름';

  @override
  String get worldoLaunchIdentity => '신분';

  @override
  String get worldoLaunchPersonality => '성격';

  @override
  String get worldoLaunchGoal => '목표';

  @override
  String get worldoLaunchSetupRole => '내 역할 설정';

  @override
  String get worldoLaunchPreset => '프리셋';

  @override
  String get worldoLaunchCustom => '직접 설정';

  @override
  String get worldoLaunchNoPresetRole => '기본 역할 없음';

  @override
  String get worldoLaunchFilling => '입력 중...';

  @override
  String get worldoLaunchFillMyProfile => '내 프로필에서 채우기';

  @override
  String get worldoLaunchLaunch => '시작';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName 시작 완료!';
  }

  @override
  String get worldoLaunchEnter => '입장';

  @override
  String get createAction => '만들기';

  @override
  String get createWorldoTitle => 'Worldo 만들기';

  @override
  String get createFailed => '생성에 실패했습니다';

  @override
  String get createNotesRequired => '공개하려면 업데이트 내용이 필요합니다.';

  @override
  String get createActionInProgress => '이 작업은 이미 진행 중입니다.';

  @override
  String createCurrentVersion({required String version}) {
    return '현재 버전: $version';
  }

  @override
  String get createChecking => '확인 중...';

  @override
  String createSummaryName({required String name}) {
    return 'Worldo 이름: $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Worldo 소개: $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return '커버 이미지: $status';
  }

  @override
  String get createNotUploaded => '업로드 안 됨';

  @override
  String get createUploaded => '업로드됨';

  @override
  String createSummarySettings({required String settings}) {
    return 'Worldo 설정: $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Worldo 시간: $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Worldo 지표: $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일',
      one: '$count일',
      zero: '$count일',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '캐릭터 0명';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '캐릭터 $count명: $names',
      one: '캐릭터 1명: $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return '추천: $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · 지역: $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · 건물: $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · 방: $count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이벤트 $count개',
      one: '이벤트 1개',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return '캐릭터 대사: $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return '내레이터: $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return '이미지: $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return '\"$itemLabel\"을(를) 삭제할까요?';
  }

  @override
  String get createItemHasContentDeleteAnyway => '이 항목에는 내용이 있습니다. 그래도 삭제할까요?';

  @override
  String get createImageUploadProgress => '이미지를 업로드하고 있습니다.';

  @override
  String get createBasicsBasics => '기본 정보';

  @override
  String get createSaveInProgress => '이미 저장 중입니다.';

  @override
  String get createRequiredBeforeSave => '저장하기 전에 모든 필수 항목을 입력하세요.';

  @override
  String get createOpeningOpening => '도입부';

  @override
  String get createCharacterCharactersCreate => '캐릭터: 최소 한 명의 캐릭터를 만드세요.';

  @override
  String get createCharacterCharactersOnlyOne => '캐릭터: 한 명만 추천할 수 있습니다.';

  @override
  String get createBasicsBasicsWorldoName => '기본 정보: Worldo 이름이 필요합니다.';

  @override
  String get createBasicsBasicsWorldoBrief => '기본 정보: Worldo 소개가 필요합니다.';

  @override
  String get createBasicsBasicsCoverImage => '기본 정보: 커버 이미지가 필요합니다.';

  @override
  String get createBasicsBasicsMetricMust => '기본 정보: 지표는 유효한 JSON이어야 합니다.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return '캐릭터 #$characterIndex: 이름이 필요합니다.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return '캐릭터 #$characterIndex: 신분이 필요합니다.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return '캐릭터 #$characterIndex: 성격이 필요합니다.';
  }

  @override
  String get createCharacterCharactersLeast => '캐릭터: 최소 한 명이 필요합니다.';

  @override
  String get createLocationLocationsCreate => '장소: 최소 한 곳을 만드세요.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return '장소 #$locationIndex: 장소 이름이 필요합니다.';
  }

  @override
  String get createOpeningOpeningSelect => '도입부: 장소를 선택하고 모든 대사 항목을 완성하세요.';

  @override
  String get createOpeningOpeningSelected => '도입부: 선택한 장소는 더 이상 이용할 수 없습니다.';

  @override
  String get createOpeningCharacterOpening => '도입부: 선택한 캐릭터는 더 이상 이용할 수 없습니다.';

  @override
  String get createOpeningOpeningDialogue =>
      '도입부: 대사의 캐릭터가 선택한 장소에 없습니다. 도입부를 열어 수정하세요.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return '지원하지 않는 도입부 대사: $type';
  }

  @override
  String get createCreating => '생성 중...';

  @override
  String get createDiscard => '버리기';

  @override
  String get createCharactersStep => '캐릭터 (1명 이상)';

  @override
  String get createLocationsStep => '장소 (1곳 이상)';

  @override
  String get createStoryEventsOptional => '스토리 이벤트 (선택)';

  @override
  String get createUpdateNotesRequiredPublish => '업데이트 내용 (공개 시 필수)';

  @override
  String get createWhatChangedVersion => '이번 버전에서 무엇이 바뀌었나요?';

  @override
  String get createView => '보기';

  @override
  String get createNotStartedYet => '아직 시작하지 않음';

  @override
  String get createEdited => '편집됨';

  @override
  String get createPublishingWorldo => 'Worldo 공개 중';

  @override
  String get createCreatingWorldo => 'Worldo 생성 중';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Worldo 업데이트를 준비하고 있습니다.\n잠시 기다려 주세요.';

  @override
  String get createBringingWorldoLifeWait =>
      'Worldo에 생명을 불어넣고 있습니다.\n잠시 기다려 주세요.';

  @override
  String get createDescribeIssue => '문제를 설명하세요';

  @override
  String get createSubmit => '제출';

  @override
  String get createBasicsWorldoName => 'Worldo 이름 *';

  @override
  String get createBasicsNameRequired => 'Worldo 이름이 필요합니다.';

  @override
  String get createBasicsBriefRequired => 'Worldo 소개가 필요합니다.';

  @override
  String get createBasicsCoverRequired => '커버 이미지가 필요합니다.';

  @override
  String get createBasicsMetricInvalid => '지표는 유효한 JSON이어야 합니다.';

  @override
  String get createBasicsEgMainStreet => '예: 메인 스트리트';

  @override
  String get createBasicsWorldoBrief => 'Worldo 소개 *';

  @override
  String get createBasicsBriefNote =>
      '플레이어가 처음 보는 공개 소개입니다. 배경, 핵심 갈등, 흥미로운 요소를 설명하세요.';

  @override
  String get createBasicsHiddenNote =>
      '이야기를 이끄는 숨겨진 규칙과 배경입니다. 의도, 작동 방식, 비밀 제한을 설명하세요.';

  @override
  String get createBasicsEgHalfShopsMain =>
      '예: 메인 스트리트 상점 절반이 판자로 막혀 있다. 노동절이 되면 가장 부유한 상점 주인이 마을을 차지한다.';

  @override
  String get createBasicsCoverImage => '커버 이미지 *';

  @override
  String get createBasicsUpload => '업로드';

  @override
  String get createBasicsUsedCardsDetailPages =>
      '카드와 상세 페이지에 사용됩니다. 약 768×1024 px 권장. 지원 형식: JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden => 'Worldo 설정 — 숨김 (선택)';

  @override
  String get createBasicsEgBankerSecretly =>
      '예: 은행가가 대출 대상을 몰래 결정한다. 무리하게 빚을 진 사람은 쫓겨날 수 있다.';

  @override
  String get createBasicsWorldoTimeOptional => 'Worldo 시간 (선택)';

  @override
  String get createBasicsWorldoStartsStart =>
      '이 worldo는 {시작 시간}에 시작하며, 사용자가 *진행*을 누를 때마다 시간축이 {진행당 시간}만큼 앞으로 이동합니다.';

  @override
  String get createBasicsStartTime => '시작 시간';

  @override
  String get createBasicsDateExample => '예: 1일 차, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => '진행당 시간';

  @override
  String get createBasicsEg8Hours3Days => '예: 8시간 / 3일';

  @override
  String get createBasicsWorldoMetricOptional => 'Worldo 지표 (선택)';

  @override
  String get createBasicsMetricLabel => '지표 이름';

  @override
  String get createBasicsEgWealthGoalProgress => '예: 재산 / 목표 달성도';

  @override
  String get createBasicsLabelNote => '지표 설명';

  @override
  String get createBasicsDescribeWhatMetric => '이 지표가 무엇을 측정하는지 설명하세요';

  @override
  String get createBasicsUnit => '단위';

  @override
  String get createBasicsEgCoins => '예: 코인 / %';

  @override
  String get createBasicsRange => '값 범위';

  @override
  String get createBasicsStarting => '초기값';

  @override
  String get createBasicsDeltaMin => '최소 변동값';

  @override
  String get createBasicsDeltaMax => '최대 변동값';

  @override
  String get createBasicsSaving => '저장 중...';

  @override
  String get createBasicsAdvancedSettings => '고급 설정 (선택)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return '캐릭터 $index';
  }

  @override
  String get createCharacterSuggest => '추천하기';

  @override
  String get createCharacterAvatarOptional => '아바타\n(선택)';

  @override
  String get createCharacterName => '이름 *';

  @override
  String get createCharactersTitle => '캐릭터';

  @override
  String createCharacterLimit({required int count}) {
    return '캐릭터를 최대 $count명 추가할 수 있습니다.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return '캐릭터 $index: 이름이 필요합니다.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return '캐릭터 $index: 신분이 필요합니다.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return '캐릭터 $index: 성격이 필요합니다.';
  }

  @override
  String get createCharacterMinOne => '최소 한 명의 캐릭터를 만드세요.';

  @override
  String get createCharacterEnterName => '이름 입력...';

  @override
  String get createCharacterIdentity => '신분 *';

  @override
  String get createCharacterEgHometownKidBack => '예: 진정한 기회를 찾아 고향으로 돌아온 청년';

  @override
  String get createCharacterPersonality => '성격 *';

  @override
  String get createCharacterEgUnderdog => '예: 마음은 따뜻하지만 자본은 부족한 도전자';

  @override
  String get createCharacterGoalOptional => '목표 (선택)';

  @override
  String get createCharacterEgRichestOwner =>
      '예: 노동절까지 메인 스트리트에서 가장 부유한 상점 주인이 되기';

  @override
  String get createCharacterBackgroundHidden => '배경 — 숨김 (선택)';

  @override
  String get createCharacterEgLeftTownYears =>
      '예: 몇 년 전 마을을 떠났다가, 기회를 찾아 문을 닫은 메인 스트리트로 돌아왔다.';

  @override
  String get createCharacterAddCharacter => '+ 캐릭터 추가';

  @override
  String get createLocationImageOptional => '이미지\n(선택)';

  @override
  String get createCharacterSelectAvailable => '아래의 이용 가능한 캐릭터에서 선택하세요';

  @override
  String get createCharacterInitialCharacters => '초기 캐릭터 (선택)';

  @override
  String get createLocationStartingCharacters => 'worldo가 시작될 때 이곳에 있는 캐릭터입니다.';

  @override
  String get createCharacterAvailableSelect => '선택 가능';

  @override
  String get createCharacterNoCharactersYet =>
      '아직 캐릭터가 없습니다. 먼저 캐릭터를 만든 다음 시작 장소를 선택하세요.';

  @override
  String get createCharacterNoCharacters =>
      '선택 가능한 캐릭터가 없습니다. 모든 캐릭터에 초기 장소가 지정되어 있습니다.';

  @override
  String get createLocationEveryL2L3Locations => '안에 있는 모든 L2 및 L3 장소도 삭제됩니다.';

  @override
  String get createLocationEveryL3Locations => '안에 있는 모든 L3 장소도 삭제됩니다.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return '\"$displayName\" 삭제';
  }

  @override
  String get createLocationOpeningLocation => '이곳은 도입부 장소입니다. 삭제하면 도입부도 지워집니다.';

  @override
  String get createLocationL1LocationRegion => 'L1 장소 · 지역 *';

  @override
  String get createLocationL2LocationBuilding => 'L2 장소 · 건물 *';

  @override
  String get createLocationAddL3Location => 'L3 장소 추가';

  @override
  String get createLocationsTitle => '장소';

  @override
  String get createLocationStatisticsNote =>
      '월드는 3개 계층으로 구성됩니다:\nL1 · 지역     월드의 구역 — 도심\nL2 · 건물   그 안의 건물 — 조의 식당\nL3 · 방       건물 안의 방 — 뒤쪽 주방\n모든 장소에 세 계층이 필요합니다. 총 15개의 방까지 만들 수 있습니다.';

  @override
  String get createLocationL1NameNote =>
      '구역, 마을, 숲처럼 월드의 한 지역입니다. 단일 건물이 아닙니다.';

  @override
  String get createLocationL2NameNote => '상점, 학교, 아파트처럼 이 지역 안의 건물입니다.';

  @override
  String get createLocationL3NameNote => '건물 안의 방입니다. 옥상, 안뜰, 입구도 가능합니다.';

  @override
  String get createLocationName => '이름 *';

  @override
  String get createLocationL1NameRequired => 'L1 장소 이름이 필요합니다.';

  @override
  String get createLocationL3NameRequired => 'L3 장소 이름이 필요합니다.';

  @override
  String get createLocationThisL1 => '이 L1 장소';

  @override
  String get createLocationThisL2 => '이 L2 장소';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel에는 최소 하나의 L2 장소가 있어야 합니다.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel에는 최소 하나의 L3 장소가 있어야 합니다.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel에 이름이 필요한 L2 장소가 있습니다.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel에 이름이 필요한 L3 장소가 있습니다.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'L3 장소를 최대 $count개 추가할 수 있습니다.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return '$count개의 방을 모두 사용했습니다. 하나를 삭제한 후 추가하세요.';
  }

  @override
  String get createLocationAtLeastOneL1 => '최소 하나의 L1 장소가 필요합니다.';

  @override
  String get createLocationAddL1 => '최소 하나의 L1 장소를 추가하세요.';

  @override
  String get createLocationMinOne => '최소 한 곳의 장소를 만드세요.';

  @override
  String get createLocationIdRequired => '모든 장소에는 ID가 있어야 합니다.';

  @override
  String get createLocationIdUnique => '모든 장소에는 고유한 ID가 있어야 합니다.';

  @override
  String get createLocationParentInvalid => '모든 장소에는 유효한 상위 항목이 있어야 합니다.';

  @override
  String get createLocationFieldsRequired => '저장하기 전에 장소의 모든 필수 항목을 입력하세요.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '장소를 저장하면 제거된 캐릭터의 도입부 대사 말풍선 $count개도 삭제됩니다.',
      one: '장소를 저장하면 제거된 캐릭터의 도입부 대사 말풍선 1개도 삭제됩니다.',
      zero: '장소를 저장하면 제거된 캐릭터의 도입부 대사 말풍선 $count개도 삭제됩니다.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'L3 장소 편집';

  @override
  String get createLocationPreview => '미리 보기';

  @override
  String get createLocationCompleteLocation => '이 장소를 완성하거나 삭제하세요.';

  @override
  String get createLocationRemoveCharacter => '장소에서 캐릭터를 제거할까요?';

  @override
  String get createLocationRemove => '제거';

  @override
  String get createLocationL1Location => 'L1 장소';

  @override
  String get createLocationL2Location => 'L2 장소';

  @override
  String get createLocationL3Location => 'L3 장소';

  @override
  String get createOpeningSelectLocation => '장소 선택';

  @override
  String get createOpeningNoSavedLocations => '저장된 장소 없음';

  @override
  String get createOpeningSelect => '선택';

  @override
  String get createOpeningSelectLocationFirst => '먼저 장소를 선택하세요.';

  @override
  String get createOpeningNoInitialCharacter => '초기 캐릭터 없음';

  @override
  String get createOpeningLocationsLoading => '장소를 아직 불러오는 중입니다.';

  @override
  String get createOpeningLoadingLocations => '장소 불러오는 중...';

  @override
  String get createOpeningSwitchingLocations => '장소를 바꾸면 대사 내용이 지워집니다.';

  @override
  String get createOpeningContinue => '계속';

  @override
  String get createOpeningAdd10DialogueItems => '대사 항목을 최대 10개 추가할 수 있습니다.';

  @override
  String get settingsUnableSaveSuggestedRole => '추천 역할을 저장할 수 없습니다.';

  @override
  String get createOpeningUnableSaveOpening => '도입부를 저장할 수 없습니다.';

  @override
  String get createOpeningSelectInitial => '초기 장소 선택';

  @override
  String get createOpeningInitialLocationRequired => '저장하기 전에 초기 장소를 선택하세요.';

  @override
  String get createOpeningAddDialogueFirst => '저장하기 전에 최소 하나의 대사 항목을 추가하세요.';

  @override
  String get createOpeningCompleteDialogue => '저장하기 전에 모든 대사 항목을 완성하세요.';

  @override
  String get createOpeningDialogue => '도입부 대사';

  @override
  String get createOpeningLocationRequired => '먼저 장소를 선택한 다음 대사를 편집하세요.';

  @override
  String get createOpeningNarrator => '내레이터';

  @override
  String get createOpeningImage => '이미지';

  @override
  String get createOpeningSuggestRoleUser => '사용자 역할 추천';

  @override
  String get createOpeningNoCharacters => '이용 가능한 캐릭터가 없습니다.';

  @override
  String get createOpeningEnterNarrator => '내레이터 대사 입력';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return '$name 대사 입력';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => '이미지 업로드';

  @override
  String get createEventAddEvent => '+ 이벤트 추가';

  @override
  String get createStoryEventsTitle => '스토리 이벤트';

  @override
  String createEventLimit({required int count}) {
    return '이벤트를 최대 $count개 추가할 수 있습니다.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return '이벤트 $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      '예: 전국 체인이 빈 땅을 물색하며 모든 지역 상점보다 낮은 가격을 내세우려 한다.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'AI가 이야기의 흐름을 이끄는 데 사용하는 핵심 전개입니다.';

  @override
  String get imageCropUploadFailed => '업로드에 실패했습니다';

  @override
  String get inboxNotifications => '알림';

  @override
  String get inboxNoNotificationsYet => '아직 알림이 없습니다.';

  @override
  String get inboxFollowers => '팔로워';

  @override
  String get inboxNewFollowers => '새 팔로워';

  @override
  String get inboxNoNewFollowersYet => '아직 새 팔로워가 없습니다.';

  @override
  String get inboxComments => '댓글';

  @override
  String get inboxNoCommentsYet => '아직 댓글이 없습니다.';

  @override
  String get inboxPrivateChats => '개인 채팅';

  @override
  String get inboxChatFriendsWorldo => 'Worldo에서 친구들과 채팅하세요.';

  @override
  String get inboxUnknownUser => '알 수 없는 사용자';

  @override
  String get inboxDirectMessage => '개인 메시지';

  @override
  String get inboxJoinRequest => '참여 신청';

  @override
  String get inboxApprove => '승인';

  @override
  String get inboxReject => '거절';

  @override
  String get inboxOk => '확인';

  @override
  String get inboxReviewFailed => '검토에 실패했습니다';

  @override
  String get inboxLoadMessagesFailed => '메시지를 불러오지 못했습니다.';

  @override
  String get inboxNewMessage => '새 메시지';

  @override
  String get inboxSomeone => '누군가';

  @override
  String get inboxWorld => '이 월드';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name님이 $world$suffix 참여를 신청했습니다';
  }

  @override
  String get inboxCommentWorldo => ' 님이 내 worldo에 댓글을 남겼습니다';

  @override
  String get inboxReply => ' 님이 내게 답글을 남겼습니다';

  @override
  String get inboxLikeComment => ' 님이 내 댓글에 좋아요를 눌렀습니다';

  @override
  String get inboxLikedComment => '님이 내 댓글에 좋아요를 눌렀습니다';

  @override
  String get inboxComment2LikeComment => '님이 내 댓글에 좋아요를 눌렀습니다';

  @override
  String get inboxReplied => '님이 내게 답글을 남겼습니다';

  @override
  String get inboxYou2Reply => '님이 내게 답글을 남겼습니다';

  @override
  String get inboxCommentedOrigin => '님이 내 작품에 댓글을 남겼습니다';

  @override
  String get inboxCommentOrigin => '님이 내 작품에 댓글을 남겼습니다';

  @override
  String get inboxSentMessage => ' 님이 메시지를 보냈습니다';

  @override
  String get inboxStartedFollowing => ' 님이 나를 팔로우하기 시작했습니다.';

  @override
  String get meFailedOpenDiscord => 'Discord를 열지 못했습니다';

  @override
  String get meImagePickFailed => '이미지 선택에 실패했습니다';

  @override
  String get meUpdateFailed => '업데이트에 실패했습니다';

  @override
  String get mePlaying => '플레이 중';

  @override
  String get meEditName => '이름 편집';

  @override
  String get meSignUpReward => '가입하고 젬 250개를 받으세요!';

  @override
  String get loginSignUpReward => '가입하고 젬 250개를 받으세요!';

  @override
  String get meUnknown => '알 수 없음';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID: $oid\n최신 버전: $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID: $displayWid\n소유자: $owner';
  }

  @override
  String get meFollows => '팔로우';

  @override
  String meFollowingCount({required String followingCount}) {
    return '팔로잉 $followingCount명';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '팔로워 $followersCount명';
  }

  @override
  String get meNoFollowingYet => '아직 팔로우하는 사람이 없습니다.';

  @override
  String get meNoFollowersYet => '아직 팔로워가 없습니다.';

  @override
  String get meBlockFailed => '차단하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get meUserBlockedContentHasReported =>
      '사용자를 차단했습니다. 이 콘텐츠를 Worldo 팀에 신고했습니다.';

  @override
  String get meBlockUser => '이 사용자를 차단할까요?';

  @override
  String get meBlock => '차단';

  @override
  String get meUnblockFailed => '차단을 해제하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get meUnblock => '차단 해제';

  @override
  String get meFollowing => '팔로잉';

  @override
  String get meFollow => '팔로우';

  @override
  String get meMessage => '메시지';

  @override
  String meUID({required String uid}) {
    return 'UID: $uid';
  }

  @override
  String get meNoWorldoCreatedYet => '아직 만든 Worldo가 없습니다.';

  @override
  String get meNoWorldoYet => '아직 Worldo가 없습니다.';

  @override
  String get meNoWorldsCreatedYet => '아직 만든 월드가 없습니다.';

  @override
  String get meNoWorldsYet => '아직 월드가 없습니다.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => '레드 젬';

  @override
  String get gemsPink => '핑크 젬';

  @override
  String get gemsTop => '충전';

  @override
  String get gemsBuy => '젬 구매';

  @override
  String get gemsRecords => '내역';

  @override
  String get gemsUnableLoad => '젬을 불러올 수 없습니다.';

  @override
  String get settingsLogOutAccount => '계정에서 로그아웃할까요?';

  @override
  String get settingsLogOut => '로그아웃';

  @override
  String get settingsFeedback => '의견 보내기';

  @override
  String get settings => '설정';

  @override
  String get settingsAboutUs => '회사 소개';

  @override
  String get settingsAccount => '계정';

  @override
  String get settingsBlockedUsers => '차단한 사용자';

  @override
  String get settingsJoinDiscord => 'Discord 참여';

  @override
  String get meUserUnblocked => '사용자 차단을 해제했습니다';

  @override
  String get meNoBlockedUsersYet => '아직 차단한 사용자가 없습니다.';

  @override
  String get settingsAgreeTermsContinue => '계속하려면 약관에 동의하세요.';

  @override
  String get settingsDeleteAccount => '계정을 삭제할까요?';

  @override
  String get settingsAccountDeletionAgreement => '계정 삭제 동의서';

  @override
  String get settingsEnsureSecurityAccount =>
      '계정 보안을 위해 계정 삭제의 결과를 읽어 주세요.\n\n계정 삭제는 로그아웃과 다르며 되돌릴 수 없습니다. 생성한 캐릭터, 검색 기록, 캐릭터와의 채팅 기록, 즐겨찾기, 기억, 상호작용 데이터, 주문 내역 등 개인 데이터가 영구적으로 삭제되며 복구할 수 없습니다.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      '구매하거나 획득한 모든 미사용 젬이 영구적으로 사라집니다. 계속하면 자발적으로 포기하는 것이며, 계정 삭제로 자동 환불 권리가 발생하지 않습니다.\n\n남은 멤버십 혜택도 모두 영구적으로 사라지며 복구할 수 없습니다. 계정을 삭제해도 구독은 취소되지 않습니다.';

  @override
  String get settingsIHaveReadAccountDeletion => '계정 삭제 동의서를 읽었습니다';

  @override
  String get settingsCurrentLoginAccount => '현재 로그인 계정:';

  @override
  String get profileSaveFailed => '프로필을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get meSignInFailed => '로그인에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get meCompleteProfileContinue => '프로필을 완성한 후 계속하세요.';

  @override
  String get meSelectGenderAge => '성별과 나이를 선택해 주세요.';

  @override
  String get meSelectGender => '성별을 선택해 주세요.';

  @override
  String get meSelectAge => '나이를 선택해 주세요.';

  @override
  String get meRequired => '필수';

  @override
  String get mePersonalizeWorldoExperience => '나만의 Worldo 경험 설정';

  @override
  String get meSignIn => '로그인';

  @override
  String get meBack => '뒤로';

  @override
  String get meSkip => '건너뛰기';

  @override
  String get meContinueGoogle => 'Google로 계속';

  @override
  String get meContinueApple => 'Apple로 계속';

  @override
  String get meSignUpClaimPremium => '가입하고 Premium 받기';

  @override
  String get meSignUpContinue => '가입하여 계속';

  @override
  String get meAccountLoggedAnotherDevice => '다른 기기에서 내 계정에 로그인했습니다.';

  @override
  String get premiumSubscription => '구독';

  @override
  String get gemsClaimFailed => '받기에 실패했습니다.';

  @override
  String get gemsCheckFailed => '체크인에 실패했습니다.';

  @override
  String get gemsFollowFailed => '팔로우에 실패했습니다.';

  @override
  String get gemsTaskUpdateFailed => '과제 업데이트에 실패했습니다.';

  @override
  String get gemsClaimSuccessful => '받기 완료!';

  @override
  String get gemsUnableLoadGemPacks => '젬 패키지를 불러올 수 없습니다.';

  @override
  String get gemsNoGemPacksAvailable => '이용 가능한 젬 패키지가 없습니다.';

  @override
  String get gemsUnableLoadGemTasks => '젬 과제를 불러올 수 없습니다.';

  @override
  String get gemsJoinUs => '함께하세요';

  @override
  String get gemsClaim => '받기';

  @override
  String get gemsClaimed => '받음';

  @override
  String get meDailyCheck => '매일 체크인';

  @override
  String get gemsDailyCheckInReward => '100 받기';

  @override
  String get meCheck => '체크인';

  @override
  String get meCheckSuccessful => '체크인 완료!';

  @override
  String get meGooglePlayUnavailable => 'Google Play를 이용할 수 없습니다.';

  @override
  String get mePurchaseFailed => '구매에 실패했습니다.';

  @override
  String get gemsEarned => '획득';

  @override
  String get gemsSpent => '사용';

  @override
  String get gemsPurchase => '구매';

  @override
  String get gemsGemRecords => '젬 내역';

  @override
  String get gemsUnableLoadRecords => '내역을 불러올 수 없습니다.';

  @override
  String get gemsNoGemRecordsYet => '아직 젬 내역이 없습니다.';

  @override
  String get meAbout => '정보';

  @override
  String get meEmailCopied => '이메일을 복사했습니다';

  @override
  String get mePurchasingPremium => 'Premium 구매 중';

  @override
  String get mePurchaseSuccessful => '구매 완료!';

  @override
  String get meWorldoPremiumSubscription => 'Worldo Premium 구독이 활성화되었습니다.';

  @override
  String get meMyBalance => '내 잔액';

  @override
  String get meSoldOut => '품절';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession => '모델 목록에는 완전한 사용자 세션이 필요합니다';

  @override
  String get memoryModelListPermissionDenied => '이 월드의 모델 목록 접근이 거부되었습니다';

  @override
  String get memorySaveFailed => '저장에 실패했습니다';

  @override
  String get memorySaveResultNotConfirmed => '저장 결과를 확인하지 못했습니다';

  @override
  String get memoryChooseModel => '모델 선택';

  @override
  String get memoryMaxTokenLimit => '최대 기억 토큰 한도';

  @override
  String get memoryNoModelsAvailable => '이용 가능한 모델 없음';

  @override
  String get memoryRetryRanges => '재시도 범위';

  @override
  String get memoryCurrentUsage => '현재 기억 사용량';

  @override
  String memoryMinGems({required String min}) {
    return '젬 $min개';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '젬 $min~$max개';
  }

  @override
  String memoryStart({required String memoryStart}) {
    return '기억 $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return '기억 $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable => '기억 설정을 이용할 수 없습니다';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Play 응답 시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get premiumSubscriptionsNotSupported =>
      '이 기기의 Google Play에서는 구독을 지원하지 않습니다.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'Google Play 연결이 끊어졌습니다. 다시 시도해 주세요.';

  @override
  String get premiumPurchaseCanceled => '구매가 취소되었습니다.';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Play를 일시적으로 이용할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get premiumGooglePlayBilling =>
      'Google Play 결제를 이용할 수 없습니다. Play 계정과 결제 설정을 확인하세요.';

  @override
  String get premiumSubscriptionUnavailable =>
      '현재 Google Play에서 이 Premium 구독을 이용할 수 없습니다.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play에서 Premium 구매를 완료하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'Google Play에서 이미 이 구독을 보유하고 있습니다.';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Play에서 변경할 구독을 찾지 못했습니다. 구독 관리를 확인하세요.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Google Play에 연결할 수 없습니다. 인터넷 연결을 확인하고 다시 시도하세요.';

  @override
  String get premiumInsufficientFunds =>
      '결제 수단의 잔액이 부족합니다. Google Play에서 업데이트한 후 다시 시도하세요.';

  @override
  String get premiumGoogleAccountIneligible =>
      '내 Google Play 계정은 이 구독 혜택의 대상이 아닙니다.';

  @override
  String get premiumAppStoreFailedComplete =>
      'App Store에서 Premium 구매를 완료하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get premiumFailedConnectAppStore =>
      'App Store에 연결할 수 없습니다. 인터넷 연결을 확인하고 다시 시도하세요.';

  @override
  String get premiumAppStoreTookTooLong =>
      'App Store 응답 시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'App Store에서 시스템 오류가 발생했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get premiumRegionUnavailable =>
      '내 App Store 지역에서는 이 Premium 구독을 이용할 수 없습니다.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      '이 앱에서는 해당 App Store 요청을 수행할 수 없습니다. 지원팀에 문의하세요.';

  @override
  String get premiumPurchaseNotSupported =>
      '이 기기 또는 시스템 버전에서는 이 구매를 지원하지 않습니다.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'App Store 구매 창을 열지 못했습니다. 앱으로 돌아와 다시 시도하세요.';

  @override
  String get premiumAppStoreFailedAccept =>
      'App Store에서 이 구매 수량을 수락하지 못했습니다. 지원팀에 문의하세요.';

  @override
  String get premiumAppStoreUnavailable =>
      '현재 App Store에서 이 Premium 구독을 이용할 수 없습니다.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      '이 기기에서는 구매가 허용되지 않습니다. Apple 계정과 구매 제한을 확인하세요.';

  @override
  String get premiumAppleAccountNotEligible => '내 Apple 계정은 이 구독 혜택의 대상이 아닙니다.';

  @override
  String get premiumSubscriptionOffer =>
      '이 구독 혜택을 이용할 수 없습니다. 페이지를 새로고침한 후 다시 시도하세요.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'App Store에서 이 혜택 가격을 수락하지 못했습니다. 페이지를 새로고침한 후 다시 시도하세요.';

  @override
  String get premiumAppStoreFailedVerify =>
      'App Store에서 이 구독 혜택을 검증하지 못했습니다. 지원팀에 문의하세요.';

  @override
  String get premiumSubscriptionOfferFailed =>
      '이 구독 혜택을 준비하지 못했습니다. 페이지를 새로고침한 후 다시 시도하세요.';

  @override
  String get premiumAddPaymentMethodApple => 'Apple 계정에 결제 수단을 추가한 후 다시 시도하세요.';

  @override
  String get premiumAppCannotMakePurchases =>
      '이 앱에서는 App Store 구매를 할 수 없습니다. 지원팀에 문의하세요.';

  @override
  String get premiumAppStoreRequestRejected =>
      'App Store에서 구매 요청을 수락하지 못했습니다. 다시 시도하거나 지원팀에 문의하세요.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'Apple 클라우드 서비스 접근이 거부되었습니다. Apple 계정 권한을 확인하세요.';

  @override
  String get premiumFailedConnectApple =>
      'Apple 서비스에 연결할 수 없습니다. 인터넷 연결을 확인하고 다시 시도하세요.';

  @override
  String get premiumAccess2AppleCloudService =>
      'Apple 클라우드 서비스 접근 권한이 철회되었습니다. Apple 계정 설정을 확인하세요.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Apple 계정에서 최신 Apple 개인정보 보호 약관에 동의한 후 다시 시도하세요.';

  @override
  String get premiumAppStoreWindowFailed =>
      'App Store 창을 설정하지 못했습니다. 지원팀에 문의하세요.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'App Store 창을 여는 시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get premiumReturnAppTryPurchase => '앱으로 돌아와 구매를 다시 시도하세요.';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Play를 이용할 수 없습니다. 설치 여부와 로그인 상태를 확인하세요.';

  @override
  String get premiumIs4Subscription =>
      '현재 스토어에서 이 Premium 구독을 이용할 수 없습니다. 페이지를 새로고침한 후 다시 시도하세요.';

  @override
  String get premiumSubscriptionFailed =>
      '이 Premium 구독을 준비하지 못했습니다. 페이지를 새로고침한 후 다시 시도하세요.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      '스토어에서 Premium 구매를 시작하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'Google Play에서 원래 구독을 찾지 못했습니다. 구독 관리를 확인하세요.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      '이 구독은 다른 구매 식별 정보를 사용합니다. 페이지를 새로고침하거나 지원팀에 문의하세요.';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play에서 아직 이 구독을 변경할 수 없습니다. 구독 관리를 확인하세요.';

  @override
  String get premiumPlanChangePending =>
      '이 플랜의 App Store 구매가 아직 처리 중입니다. 완료될 때까지 기다려 주세요.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'App Store에서 Premium 플랜을 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get premiumPurchasePreparation => '구매 준비가 만료되었습니다. 다시 시도해 주세요.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'App Store에서 알 수 없는 구매 결과를 반환했습니다. 다시 시도하기 전에 구독을 확인하세요.';

  @override
  String get premiumPurchasesUnavailable => '현재 구매를 이용할 수 없습니다.';

  @override
  String get premiumAutoRenewsCancelAnytime => '자동 갱신. 언제든 취소할 수 있습니다.';

  @override
  String get premiumSubscribed => '구독 중';

  @override
  String get premiumAlsoIncluded => '추가 포함';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => '핑크 젬';

  @override
  String get premiumRedGems => '레드 젬';

  @override
  String get premiumExtraDailyCheck => '매일 체크인으로 추가 획득';

  @override
  String get premiumDailyCheck => '매일 체크인';

  @override
  String get premiumClaimedMonthly => '매월 받기';

  @override
  String get premiumBilledMonthly => '매월 결제';

  @override
  String premiumSaveSavings({required String savings}) {
    return '$savings% 절약';
  }

  @override
  String get premiumSubscribe => '구독하기';

  @override
  String get premiumActiveYearlySubscription =>
      '활성 상태의 연간 Premium 구독을 월간 플랜으로 변경할 수 없습니다.';

  @override
  String get premiumAlreadyHaveActive => '이미 활성 Premium 구독이 있습니다.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return '이미 구독 중인 플랜: Premium $label.';
  }

  @override
  String get premiumPreviousPurchasePending => '이전 Premium 구매를 아직 확인 중입니다.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Premium 구독을 업그레이드하려면 원래 구매한 스토어를 이용하세요.';

  @override
  String get premiumResolveCurrent => '구매 전에 스토어에서 현재 구독 문제를 해결하세요.';

  @override
  String get premiumPurchaseUnavailable => '현재 Premium 구매를 이용할 수 없습니다.';

  @override
  String get premiumUnableVerifyPurchase => '구매 자격을 확인할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      '스토어에서 이 Premium 구매를 검증하지 못했습니다.';

  @override
  String get premiumPurchaseDoesNotMatch => '이 Premium 구매는 선택한 플랜과 일치하지 않습니다.';

  @override
  String get premiumMessagePurchaseCanceled => '이 Premium 구매가 취소되었습니다.';

  @override
  String get premiumPurchaseRevoked => '이 Premium 구매가 철회되었습니다.';

  @override
  String get premiumNotification => '알림';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premium 구독이 활성 상태이며 다운그레이드를 지원하지 않습니다.';

  @override
  String get premiumGot => '알겠습니다';

  @override
  String get gemBalancePromptInsufficientGems => '젬 부족';

  @override
  String get gemBalancePromptLowGems => '젬 잔액이 적습니다';

  @override
  String get appPressBackExit => '뒤로를 한 번 더 누르면 종료됩니다.';

  @override
  String get appReportSubmitted => '신고를 제출했습니다';

  @override
  String get appReportFailed => '신고에 실패했습니다';

  @override
  String get appUpdateRequired => '업데이트 필요';

  @override
  String get appUpdateContent => 'Worldo를 계속 사용하려면 최신 버전으로 업데이트하세요.';

  @override
  String appUpdateVersion({required String versionName}) {
    return '버전 $versionName';
  }

  @override
  String get appUpdateCheckFailed => '업데이트 상태를 새로고침할 수 없습니다. 업데이트한 후 계속하세요.';

  @override
  String get appUpdate => '지금 업데이트';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabel 복사됨';
  }

  @override
  String get commonClose => '닫기';

  @override
  String get commonImageLoadFailed => '이미지 불러오기에 실패했습니다';

  @override
  String get commonPageNotFound => '페이지를 찾을 수 없습니다.';

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
    return 'LLM이 첫 번째 Tick을 생성하고 있습니다. 잠시 기다려 주세요$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return '최신 버전: V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return '생성하기 전에 다음 항목을 저장하세요: $missingSections.';
  }

  @override
  String get createCharacterRoleHint => 'worldo에서 캐릭터의 역할입니다.';

  @override
  String get createCharacterMannerHint => '대사를 결정하는 캐릭터의 말투와 행동 방식입니다.';

  @override
  String get createCharacterGoalHint => '행동을 결정하는 캐릭터의 목표 또는 행동 방향입니다.';

  @override
  String get createCharacterBackgroundHint => '캐릭터의 배경과 관계입니다.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return '$world$worldIdSuffix 참여 신청';
  }

  @override
  String get memoryModel => '기억 및 모델';

  @override
  String get premiumAccountMismatch => '계정 식별 정보가 이전 구독과 일치하지 않습니다.';

  @override
  String get worldRecap => '스토리 요약';

  @override
  String get inboxMissingJoinRequestId => '참여 요청 ID가 없습니다';

  @override
  String get loginTimedOut => '로그인 시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get loginConnectionFailed => '연결할 수 없습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get loginTemporarilyUnavailable => '지금은 로그인할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get recapUnlockHeading => '스토리 요약 이용 가능';

  @override
  String get recapUpsellDescription =>
      '이야기의 반전과 선택, 함께한 캐릭터를 담은 전체 요약으로 지금까지의 스토리를 확인하세요.';

  @override
  String get recapShowEarlier => '이전 요약 보기';

  @override
  String get recapEmpty => '스토리가 진행되면 여기에 요약이 표시됩니다.';

  @override
  String get chatMessageAsNarrator => '내레이터로 메시지 보내기';

  @override
  String chatMessageAsCharacter({required String name}) {
    return '$name 이름으로 메시지 보내기';
  }

  @override
  String get chatNarratorSpeaker => '내레이터';

  @override
  String get chatYourCharacterSpeaker => '내 캐릭터';

  @override
  String chatSpeakingAs({required String speaker}) {
    return '현재 발언: $speaker';
  }

  @override
  String get chatSwitchCharacter => '캐릭터로 전환';

  @override
  String get chatSwitchNarration => '내레이션으로 전환';

  @override
  String chatOpenLocation({required String locationName}) {
    return '$locationName 열기';
  }

  @override
  String get chatRetryMessage => '메시지 다시 보내기';

  @override
  String get blockedReportFailed => '사용자를 차단했지만 신고하지 못했습니다.';

  @override
  String get storeConnectionFailed => '스토어에 연결할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get storeProductUnavailable => '현재 이 상품을 구매할 수 없습니다.';

  @override
  String get storeDevicePurchasesUnavailable => '이 기기에서는 구매할 수 없습니다.';

  @override
  String get worldHistoryRequestFailed => '월드 기록을 불러오지 못했습니다';

  @override
  String get genericError => '오류가 발생했습니다';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': '$plan Premium, 연간 $price',
      'other': '$plan Premium, 월간 $price',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => '삭제하지 못했습니다';

  @override
  String get developerGatewaySignatureFailed => 'Gateway 서명 검증에 실패했습니다';

  @override
  String get developerEndpointsSaved => '저장했습니다. 새 요청에는 설정한 엔드포인트가 적용됩니다.';

  @override
  String get developerAdjustRestartRequired =>
      'Adjust 환경을 적용하려면 앱을 다시 시작해 주세요.';

  @override
  String developerRecapSetting({required String mode}) {
    return '월드 요약: $mode';
  }

  @override
  String get developerRecapPreview => '월드 요약 미리보기';

  @override
  String get developerRecapPreviewDescription =>
      '월드 패널의 구독 상태와 요약 내용을 임시로 대체합니다. 앱을 다시 시작하면 초기화됩니다.';

  @override
  String get developerResetFailed => '초기화하지 못했습니다';

  @override
  String get developerRecapOff => '끄기(멤버십 상태 따름)';

  @override
  String get developerRecapLocked => '잠김 · 구독하지 않음';

  @override
  String get developerRecapEmpty => '구독 중 · 아직 생성되지 않음';

  @override
  String get developerRecapSample => '구독 중 · 예시 요약';

  @override
  String get developerRecapLive => '구독 중 · 실제 요약';

  @override
  String get chatEditFreeUsesExhausted => '무료 편집 횟수를 모두 사용했습니다.';

  @override
  String developerMembershipSetting({required String selection}) {
    return '멤버십: $selection';
  }

  @override
  String get developerMembershipDescription =>
      '모든 화면에서 이 계정의 멤버십 상태를 임시로 변경합니다. 서버에서는 실제 계정 상태를 계속 사용합니다. 앱을 다시 시작하면 원래 상태로 돌아갑니다.';

  @override
  String get developerMembershipOff => '끄기(실제 멤버십)';

  @override
  String get developerMembershipYearly => 'Premium · 연간';

  @override
  String get developerMembershipMonthly => 'Premium · 월간';

  @override
  String get developerMembershipNone => '미가입';

  @override
  String get originStartBySelectingRole => '먼저 내 역할을 선택하세요';

  @override
  String get originRecommendedStart => '추천 시작 지점';

  @override
  String get originStoryOpening => '이야기의 시작';

  @override
  String get originOpeningLocation => '시작 장소';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names의 현재 위치:\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return '이야기의 시작\n$locationName';
  }

  @override
  String get chatCharacterMovement => '캐릭터 이동';
}

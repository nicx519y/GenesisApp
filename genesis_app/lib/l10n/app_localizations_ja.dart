// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get imageGifUnsupported => 'GIFアニメーションには対応していません。';

  @override
  String get worldProgressComplete => '進行完了';

  @override
  String a11ySwitchMode({required String label}) {
    return '$labelモードに切り替え';
  }

  @override
  String a11yEditItem({required String title}) {
    return '$titleを編集';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return 'ロールカード $index/$count';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'インスピレーション$indexを編集';
  }

  @override
  String a11yInsert({required String label}) {
    return '$labelを挿入';
  }

  @override
  String get a11yMembership => 'メンバーシップ';

  @override
  String get a11yOpenWorldo => 'Worldoを開く';

  @override
  String get a11yFilterGender => '性別で絞り込み';

  @override
  String get a11ySelectRole => '自分のロールを選択';

  @override
  String get a11yLoadingMap => 'マップを読み込み中';

  @override
  String get a11yBuildingWorld => 'ワールドを作成中';

  @override
  String get a11yPremiumMembership => 'Premiumメンバーシップ';

  @override
  String get a11yProMembership => 'Proメンバーシップ';

  @override
  String get a11yRecommendedRole => 'おすすめのロール';

  @override
  String get a11yLastMessage => '最新のメッセージ';

  @override
  String get a11yRecentChat => '最近のチャット';

  @override
  String get a11yAiReplyLoading => 'AIの返信を読み込み中';

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
      other: 'プレイヤー',
      one: 'プレイヤー',
      zero: 'プレイヤー',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max（追加済み / 上限）';
  }

  @override
  String get createSixHours => '6時間';

  @override
  String get createTwelveHours => '12時間';

  @override
  String get createOneDay => '1日';

  @override
  String get createOneWeek => '1週間';

  @override
  String get settingsLanguage => '言語';

  @override
  String get languageChangeFailed => '言語を変更できませんでした。もう一度お試しください。';

  @override
  String get purchasingGems => 'ジェムを購入中';

  @override
  String get purchaseSuccessful => '購入が完了しました！';

  @override
  String get okAction => 'OK';

  @override
  String get cancelAction => 'キャンセル';

  @override
  String get requestAction => '申請';

  @override
  String get requestedStatus => '申請済み';

  @override
  String get launchAction => '起動';

  @override
  String get tickNowAction => '今すぐTick';

  @override
  String get writePostHint => '投稿を書く';

  @override
  String get newPostTitle => '新しい投稿';

  @override
  String get aiIsGenerating => 'AIが生成中';

  @override
  String get generatingCustomizedWorldWait =>
      'あなた専用の、生きたワールドを生成しています。\nしばらくお待ちください。';

  @override
  String get approvedStatus => '承認済み';

  @override
  String get rejectedStatus => '却下済み';

  @override
  String get awaitingApprovalStatus => '承認待ち';

  @override
  String get awaitingYourApprovalStatus => 'あなたの承認待ち';

  @override
  String get liveYourWorld => '自分のワールドを生きよう';

  @override
  String get signedOutMeDescription =>
      'ワールドで遊び、worldoを作り、友達を招待して、\nどこからでも続きを楽しもう。';

  @override
  String get gemTaskLaunchWorldHint => '好きなWorldoを開き、起動して自分のワールドを作りましょう。';

  @override
  String get gemTaskInviteFriendHint => 'ワールドを開き、詳細パネルの「招待」をタップしましょう。';

  @override
  String get gemTaskWriteCommentHint => '好きなWorldoを開き、「ディスカッション」で投稿を書きましょう。';

  @override
  String get gemTaskRequestJoinHint => 'まだ参加していないワールドを開き、参加を申請しましょう。';

  @override
  String get gemTaskSendMessageHint => '自分のワールドでメッセージを送りましょう。';

  @override
  String get gemTaskProgressWorldHint => 'プレイ中のワールドを開き、「今すぐTick」をタップしましょう。';

  @override
  String get termsOfService => '利用規約';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'ワールド';

  @override
  String get userLabel => 'ユーザー';

  @override
  String get meLabel => '自分';

  @override
  String get locationLabel => '場所';

  @override
  String get allLabel => 'すべて';

  @override
  String get maleLabel => '男性';

  @override
  String get femaleLabel => '女性';

  @override
  String get nonBinaryLabel => 'ノンバイナリー';

  @override
  String get forYouLabel => 'おすすめ';

  @override
  String get userBlocked => 'ユーザーをブロックしました';

  @override
  String get purchaseCanceled => '購入はキャンセルされました。';

  @override
  String get purchasePending => '購入は保留中です。';

  @override
  String get purchaseConfirmationDelayed => '購入の確認に時間がかかっています。後でもう一度ご確認ください。';

  @override
  String get purchaseFailed => '購入に失敗しました。';

  @override
  String get yearlyPlan => '年額';

  @override
  String get monthlyPlan => '月額';

  @override
  String get proSubscriptionTagline => 'プレイするすべてのWorldoを、もっと深く楽しもう。';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price、年ごとに請求';
  }

  @override
  String expiresOn({required String date}) {
    return '有効期限：$date';
  }

  @override
  String get activeStatus => '有効';

  @override
  String get expiredStatus => '期限切れ';

  @override
  String updatedAt({required String timestamp}) {
    return '更新：$timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => '読み込み失敗。再試行';

  @override
  String get loadMoreAction => 'さらに読み込む';

  @override
  String get gemPurchaseRecord => 'ジェム購入';

  @override
  String get taskRewardRecord => 'タスク報酬';

  @override
  String get worldProgressRecord => 'ワールドの進行';

  @override
  String get directMessageRecord => 'ダイレクトメッセージ';

  @override
  String get gemRecord => 'ジェムの記録';

  @override
  String get runATickTask => 'Tickを1回実行';

  @override
  String get runATickTaskDescription => 'プレイ中のワールドを開き、「今すぐTick」をタップしてください。';

  @override
  String get someoneFallback => '誰か';

  @override
  String get aCharacterFallback => 'キャラクター';

  @override
  String get thisWorld => 'このワールド';

  @override
  String get noWorldEventsYet => 'ワールドのイベントはまだありません。';

  @override
  String get globalLabel => '全体';

  @override
  String get eventLabel => 'イベント';

  @override
  String get characterDestinations => 'キャラクターの行き先';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterNameが$locationNameに$direction';
  }

  @override
  String get cameToDirection => '到着しました';

  @override
  String get wentToDirection => '向かいました';

  @override
  String get hasComeToDirection => '到着しました';

  @override
  String get hasGoneToDirection => '向かいました';

  @override
  String get waitForReplyToSendMore => '返信を待ってから次のメッセージを送ってください';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新着メッセージ$count件',
      one: '新着メッセージ$count件',
      zero: '新着メッセージ$count件',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation => 'プリセットのロールを選択してください';

  @override
  String get enterNameValidation => '名前を入力してください';

  @override
  String get enterIdentityValidation => '身分を入力してください';

  @override
  String get waitForProfileLoading => 'プロフィールの読み込みが完了するまでお待ちください。';

  @override
  String get imageUploadFailed => '画像のアップロードに失敗しました。';

  @override
  String get photoAccessDenied => '写真へのアクセスが拒否されました';

  @override
  String get feedbackSubmitted => 'フィードバックを送信しました';

  @override
  String get feedbackFailed => 'フィードバックの送信に失敗しました';

  @override
  String get worldoDetailUnavailable => 'Worldoの詳細を表示できません。';

  @override
  String get publishAction => '公開';

  @override
  String get publishingStatus => '公開中...';

  @override
  String get publishFailed => '公開に失敗しました';

  @override
  String get publishChangesBeforeLeaving => 'このページを離れる前に変更を公開しますか？';

  @override
  String get noChangesToPublish => '公開する変更はありません。';

  @override
  String get completeOpeningRequiredToPublish => '公開するには導入を完成させてください';

  @override
  String get publishResponseMissingOriginId => '公開結果にWorldo IDがありませんでした。';

  @override
  String get worldoIdRequired => 'Worldo IDが必要です。';

  @override
  String loadFailedWithReason({required String reason}) {
    return '読み込みに失敗しました：$reason';
  }

  @override
  String get imageSelectionFailed => '画像の選択に失敗しました';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID：$oid\n最新バージョン：$version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID：$wid\n所有者：$owner';
  }

  @override
  String get sendFailed => '送信に失敗しました';

  @override
  String get selectARole => 'ロールを選択';

  @override
  String get timeLabel => '時刻';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID：$oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID：$oid · クリエイター：$creator';
  }

  @override
  String get worldoMetricExplanation =>
      'このworldoでは、進行するたびに各キャラクターの{指標名}が更新され、{単位}で表示されます。各キャラクターは{初期値}から始まり、値は{最小変動値}～{最大変動値}の範囲で変動します。';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return '$worldoを起動して\n自分のワールドを生成';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return '次のメッセージの推定コスト：$cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amountジェム';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'ワールド$worldNameを削除';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsernameは$characterNameとしてプレイ中';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldNameを起動しました！';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldNameを作成しました！';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldNameを公開しました！';
  }

  @override
  String get createTimeout => 'Worldoの作成がタイムアウトしました。';

  @override
  String get publishTimeout => 'Worldoの公開がタイムアウトしました';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return '$worldName$worldIdへの参加を申請しました';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadgeが$worldName$worldIdへの参加を申請しました';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadgeがあなたのworldoにコメントしました';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadgeがあなたに返信しました';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadgeがあなたのコメントにいいねしました';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadgeからメッセージが届きました';
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
    return 'インスピレーションの無料利用残り回数：$remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return '編集の無料利用残り回数：$remaining\n$action';
  }

  @override
  String get getMoreAction => 'もっと獲得 >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterNameが$locationNameに到着しました';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldoでは、キャラクター、物語、変化するイベントに満ちたAIワールドを作成、発見し、その中に入ることができます。AIキャラクターとチャットし、友達と遊び、臨場感のあるシーンや選択を通じてワールドを進めましょう。\n\nこのアプリは、読者としてだけでなく、ワールドの一員としてインタラクティブな物語を体験する新しい方法を提供します。ご質問は$contactEmailまでお問い合わせください。';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy、$termsOfUse、$endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return '続行すると、$terms、$privacyPolicy、$endUserLicenseAgreementに同意したものとみなされます';
  }

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get terms => '規約';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get endUserLicenseAgreement => 'エンドユーザー使用許諾契約';

  @override
  String existingAccountSignIn({required String signIn}) {
    return 'アカウントをお持ちの方は$signIn';
  }

  @override
  String get signInAction => 'ログイン。';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return '$gemIcon$grantedAmountジェムが付与されました。';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return '毎月最大$amountジェムと、すべてのPremium機能へのアクセス。';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /日';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/月';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge：$replyToName$replyToBadgeへの返信：$content';
  }

  @override
  String discussReplyLineDirect({
    required String authorName,
    required String authorBadge,
    required String content,
  }) {
    return '$authorName$authorBadge：$content';
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
  String get homeLoadFailed => '読み込みに失敗しました';

  @override
  String get homeRetry => '再試行';

  @override
  String get homeEmptyDescription =>
      'Worldoは設計図です。起動すると、入って成長させられる生きたワールドが作られます。';

  @override
  String get homeWorldCharacter => 'キャラクター';

  @override
  String get homeWorldSingleOtherPlayer => '· 他のプレイヤー1人';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· 他のプレイヤー$otherPlayerCount人';
  }

  @override
  String get homeSignInUnavailable => 'ログインできません';

  @override
  String get homeSignedOutTitle => 'あなたのワールドを、ひとつの場所に';

  @override
  String get homeSignedOutDescription => 'ログインしてワールドを作成し、物語を続けましょう。';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return '所有者：$owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID：$oid  クリエイター：$originator\n概要：$brief\n最新バージョン：$version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID：$wid\n所有者：$owner';
  }

  @override
  String get searchHistory => '検索履歴';

  @override
  String get searchFailed => '検索に失敗しました';

  @override
  String get searchNoResults => '結果がありません。';

  @override
  String get searchCancel => 'キャンセル';

  @override
  String get searchHint => 'Worldo、キャラクター、タグ';

  @override
  String get worldDetailOnlyWorldsLaunched => '自分が単独で起動したワールドのみ削除できます。';

  @override
  String get worldDetailDelete => '削除';

  @override
  String get worldDetailNoCharacterStatusYet => 'キャラクターの状態はまだありません。';

  @override
  String get worldDetailNoCharactersYet => 'キャラクターはまだいません。';

  @override
  String get worldDetailProgressingWorld => 'ワールドを進行中';

  @override
  String get worldDetailCompressingRecent =>
      '最近の記憶を圧縮中\nワールドの時間軸を進行中\n物語の次の展開を生成中\nキャラクターの場所を更新中';

  @override
  String get worldModelsDetail => '詳細';

  @override
  String get worldModelsLocations => '場所';

  @override
  String get worldModelsEvents => 'イベント';

  @override
  String get worldModelsStatus => '状態';

  @override
  String get worldDetailUnavailable => '利用できません';

  @override
  String worldActionFailed({required String actionLabel}) {
    return '$actionLabelに失敗しました';
  }

  @override
  String get worldDetailRequestJoinWorld => 'このワールドへの参加を申請しますか？';

  @override
  String get worldDetailRequest => '申請';

  @override
  String get worldDetailLaunchFailed => '起動に失敗しました';

  @override
  String get worldDetailNoSavedProfileFound => '保存済みプロフィールが見つかりません';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return '元のWorldo：$sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => '招待';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Worldoで私のワールド「$worldName」に参加しよう！\n$wid\nこのWIDをWorldoで検索して、ワールドを見つけて参加してください。\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'ワールド概要';

  @override
  String get worldDetailCast => '登場人物';

  @override
  String get worldDetailLinkCopiedShare => 'リンクをコピーしました。友達に共有しましょう。';

  @override
  String get worldMapAction => 'マップ';

  @override
  String get worldInfoAction => '情報';

  @override
  String worldLocationCount({required String pointsCount}) {
    return '場所（$pointsCount）';
  }

  @override
  String get worldDetailPlayer => 'プレイヤー';

  @override
  String worldDetailGoal({required String goal}) {
    return '目標：$goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet => 'キャラクターの詳細はまだありません。';

  @override
  String get worldDetailNoEventsYet => 'イベントはまだありません。';

  @override
  String get worldDetailLoadEventsFailed => 'イベントの読み込みに失敗しました。';

  @override
  String homeLocationID({required String id}) {
    return '場所$id';
  }

  @override
  String get homeBuildingWorld => 'ワールドを作成中';

  @override
  String get worldMapLoadFailed => 'マップの読み込みに失敗しました';

  @override
  String get worldMapZoomIn => 'マップを拡大';

  @override
  String get worldMapZoomOut => 'マップを縮小';

  @override
  String get worldDetailGlobal => '全体';

  @override
  String get worldDetailLocation => '場所';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => '最初のTickを生成中';

  @override
  String get worldFirstTickStatusLoadFailed => '生成状況を読み込めませんでした。';

  @override
  String get worldDetailNew => '新着';

  @override
  String get homeUnknownLocation => '不明な場所';

  @override
  String get homeUnknownCharacter => '不明なキャラクター';

  @override
  String get homeNewPlaceEmerged => '新しい場所が出現しました';

  @override
  String get homeNewCharacterAppeared => '新しいキャラクターが登場しました';

  @override
  String get chatLocationUnavailable => '場所を利用できません';

  @override
  String get chatRequestApprovalLaunch => '起動の承認を申請';

  @override
  String get chatLoading => '読み込み中';

  @override
  String get chatQuotaCheckFailed => '無料利用回数を確認できませんでした。もう一度お試しください。';

  @override
  String get chatInspirationSourceChanged =>
      'インスピレーションの元が変更されました。インスピレーションを開き直してください。';

  @override
  String get chatInspiration => 'インスピレーション';

  @override
  String get chatMessageCannotSend => 'このメッセージは送信できなくなりました';

  @override
  String get chatMessageEmpty => 'メッセージが空です';

  @override
  String get chatConnectionFailed => 'このチャットに接続できません';

  @override
  String get chatReplyChangedSelect => '返信が変更されました。インスピレーションを選び直してください。';

  @override
  String get chatSendConfirmFailed => 'メッセージの送信を確認できません';

  @override
  String get chatNoNetworkConnection => 'ネットワーク接続がありません';

  @override
  String get chatRoundCannotContinue => 'このラウンドは続行できません';

  @override
  String get chatSourceRoundChanged => '元のラウンドが変更されました';

  @override
  String get chatGo => '続ける';

  @override
  String get chatReplyActionUnavailable => 'この返信操作は利用できなくなりました';

  @override
  String get chatRegenerateFailure => '再生成に失敗しました';

  @override
  String get chatGoFailure => '続行に失敗しました';

  @override
  String get chatEditFailure => '編集に失敗しました';

  @override
  String get chatInspirationFailure => 'インスピレーションの生成に失敗しました';

  @override
  String get chatJoinLocationFailed => 'この場所への参加に失敗しました';

  @override
  String get chatInactive => 'このチャットは有効ではありません';

  @override
  String get chatChatroomUnavailable => 'チャットルームを利用できません';

  @override
  String get chatFailedConfirmReplyAction => '返信操作を確認できません';

  @override
  String get chatLeastOneMessageMustRemain => '少なくとも1件のメッセージを残してください。';

  @override
  String get chatReplyNotEditable => 'この返信は編集できません';

  @override
  String get chatReplyAlreadyFixed => 'この返信は確定済みです';

  @override
  String get chatReplyEditorFrozen => '返信エディターはロックされています';

  @override
  String get chatResolvePreviousSaveBefore => '前の保存を完了させてから、その下書きを変更してください';

  @override
  String get chatStaleReplyEditor => '返信エディターの内容が古くなっています';

  @override
  String get chatPreviousSaveResultUncertain =>
      '前の保存結果が不明です。再編集する前に再読み込みしてください';

  @override
  String get chatCandidateMissing => '候補が存在しません';

  @override
  String get chatBatchSupportsMost100Changes => '1回の一括処理で変更できるのは最大100件です';

  @override
  String get chatMissingStableMessageIdentity => 'メッセージの固定識別子がありません';

  @override
  String get chatEditTargetHasChanged => '編集対象が変更されました';

  @override
  String get chatMessageNotEditable => 'このメッセージは編集できません';

  @override
  String get chatReplyNoLongerEditable => 'この返信は編集できなくなりました';

  @override
  String get chatEditorOpenFailed => 'エディターを開けませんでした';

  @override
  String get chatInactiveDuringEdit => 'このチャットは有効ではありません。';

  @override
  String get chatEditMessage => 'メッセージを編集';

  @override
  String get chatSave => '保存';

  @override
  String get chatEdit => '編集';

  @override
  String get chatRegenerate => '再生成';

  @override
  String get chatRegenerateUnavailable => 'このラウンドは再生成できません';

  @override
  String get chatGenerate10Replies => '返信は最大10件生成できます。';

  @override
  String get chatPreviousReply => '前の返信';

  @override
  String get chatNextReply => '次の返信';

  @override
  String get chatCopy => 'コピー';

  @override
  String get chatReport => '通報';

  @override
  String get chatCopied => 'コピーしました';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新着メッセージ$count件',
      one: '新着メッセージ$count件',
      zero: '新着メッセージ$count件',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'メンション';

  @override
  String get chatCharacters => 'キャラクター';

  @override
  String get chatNoCharacters => 'キャラクターがいません';

  @override
  String get chatNoLocations => '場所がありません';

  @override
  String get chatHere => 'ここ';

  @override
  String get chatLoadEarlierMessages => '過去のメッセージを読み込む';

  @override
  String get chatText => 'メッセージを入力...';

  @override
  String get chatLocationRoster => 'あなた';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'すべてのコンテンツはAIが生成したフィクションです。実在の人物、出来事、場所との類似は偶然です。';

  @override
  String get homeRecent => '最近';

  @override
  String get worldoUnableSavePreference => '設定を保存できませんでした。もう一度お試しください。';

  @override
  String get worldoFilterGender => '性別で絞り込み';

  @override
  String get worldoNoData => 'データがありません';

  @override
  String get worldoAll => 'すべて';

  @override
  String get worldoDetailSelectRole => '自分のロールを選択';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'クリエイター：$creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Worldoを編集';

  @override
  String get worldoDetailWorldoBrief => 'Worldo概要';

  @override
  String get worldoDetailNewPost => '新しい投稿';

  @override
  String get worldoDetailWritePost => '投稿を書く';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'ディスカッション（$discussCount）';
  }

  @override
  String get worldoDetailViewAll => 'すべて表示 >';

  @override
  String get worldoDetailPlayingWorld => 'プレイ中のワールド';

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
    return 'キャラクター（$length）';
  }

  @override
  String get worldoSend => '送信';

  @override
  String get worldoPostFailed => '投稿に失敗しました';

  @override
  String get worldoImageUploadFailed => '画像のアップロードに失敗しました';

  @override
  String get worldoLoadRepliesFailed => '返信の読み込みに失敗しました';

  @override
  String get worldoWriteReply => '返信を書く';

  @override
  String worldoReplyName({required String replyToName}) {
    return '$replyToNameに返信';
  }

  @override
  String get worldoPostDetail => '投稿詳細';

  @override
  String get worldoPostUnavailable => '投稿を表示できません';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'すべての返信 $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return '返信$replyCount件をすべて表示';
  }

  @override
  String get worldoLikeFailed => 'いいねに失敗しました';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return '返信$replyCount件をすべて表示';
  }

  @override
  String get worldoUser => 'ユーザー';

  @override
  String get worldoViewMore => 'もっと見る >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'ディスカッション（$discussCount）';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return '返信$remainingReplyCount件をすべて表示';
  }

  @override
  String get worldoReply => '返信';

  @override
  String get worldoDiscussTitle => 'ディスカッション';

  @override
  String get worldoLaunchLocationComesLife => '起動すると、この場所が動き出します。';

  @override
  String get worldoLaunchLaunchWorldoExplore => 'このWorldoを起動して、ここを探索し、交流しましょう。';

  @override
  String get worldoLaunchRoleUnavailable => 'このロールは利用できなくなりました';

  @override
  String get worldoLaunchSelectRole => '自分のロールを選択';

  @override
  String get worldoLaunchProfile => 'あなたのプロフィール';

  @override
  String get worldoLaunchDone => '完了';

  @override
  String get worldoLaunchSuggested => 'おすすめ';

  @override
  String get worldoLaunchName => '名前';

  @override
  String get worldoLaunchIdentity => '身分';

  @override
  String get worldoLaunchPersonality => '性格';

  @override
  String get worldoLaunchGoal => '目標';

  @override
  String get worldoLaunchSetupRole => '自分のロールを設定';

  @override
  String get worldoLaunchPreset => 'プリセット';

  @override
  String get worldoLaunchCustom => 'カスタム';

  @override
  String get worldoLaunchNoPresetRole => 'プリセットのロールがありません';

  @override
  String get worldoLaunchFilling => '入力中...';

  @override
  String get worldoLaunchFillMyProfile => '自分のプロフィールから入力';

  @override
  String get worldoLaunchLaunch => '起動';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldNameを起動しました！';
  }

  @override
  String get worldoLaunchEnter => '入る';

  @override
  String get createAction => '作成';

  @override
  String get createWorldoTitle => 'Worldoを作成';

  @override
  String get createFailed => '作成に失敗しました';

  @override
  String get createNotesRequired => '公開するには更新内容が必要です。';

  @override
  String get createActionInProgress => 'この操作はすでに実行中です。';

  @override
  String createCurrentVersion({required String version}) {
    return '現在のバージョン：$version';
  }

  @override
  String get createChecking => '確認中...';

  @override
  String createSummaryName({required String name}) {
    return 'Worldo名：$name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Worldo概要：$brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'カバー画像：$status';
  }

  @override
  String get createNotUploaded => '未アップロード';

  @override
  String get createUploaded => 'アップロード済み';

  @override
  String createSummarySettings({required String settings}) {
    return 'Worldo設定：$settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Worldo時間：$time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Worldo指標：$metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
      one: '$count日',
      zero: '$count日',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => 'キャラクター0人';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'キャラクター$count人：$names',
      one: 'キャラクター1人：$names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'おすすめ：$name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · 地域：$count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · 建物：$count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · 部屋：$count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'イベント$count件',
      one: 'イベント1件',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return 'キャラクターのセリフ：$count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'ナレーター：$count';
  }

  @override
  String createSummaryImage({required int count}) {
    return '画像：$count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return '$itemLabelを削除しますか？';
  }

  @override
  String get createItemHasContentDeleteAnyway => 'この項目には内容があります。それでも削除しますか？';

  @override
  String get createImageUploadProgress => '画像をアップロード中です。';

  @override
  String get createBasicsBasics => '基本情報';

  @override
  String get createSaveInProgress => 'すでに保存中です。';

  @override
  String get createRequiredBeforeSave => '必須項目をすべて入力してから保存してください。';

  @override
  String get createOpeningOpening => '導入';

  @override
  String get createCharacterCharactersCreate => 'キャラクター：少なくとも1人作成してください。';

  @override
  String get createCharacterCharactersOnlyOne => 'キャラクター：おすすめにできるのは1人だけです。';

  @override
  String get createBasicsBasicsWorldoName => '基本情報：Worldo名は必須です。';

  @override
  String get createBasicsBasicsWorldoBrief => '基本情報：Worldo概要は必須です。';

  @override
  String get createBasicsBasicsCoverImage => '基本情報：カバー画像は必須です。';

  @override
  String get createBasicsBasicsMetricMust => '基本情報：指標は有効なJSONである必要があります。';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'キャラクター#$characterIndex：名前は必須です。';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'キャラクター#$characterIndex：身分は必須です。';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'キャラクター#$characterIndex：性格は必須です。';
  }

  @override
  String get createCharacterCharactersLeast => 'キャラクター：少なくとも1人必要です。';

  @override
  String get createLocationLocationsCreate => '場所：少なくとも1か所作成してください。';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return '場所#$locationIndex：場所名は必須です。';
  }

  @override
  String get createOpeningOpeningSelect => '導入：場所を選択し、すべてのセリフ項目を完成させてください。';

  @override
  String get createOpeningOpeningSelected => '導入：選択した場所は利用できなくなりました。';

  @override
  String get createOpeningCharacterOpening => '導入：選択したキャラクターは利用できなくなりました。';

  @override
  String get createOpeningOpeningDialogue =>
      '導入：セリフのキャラクターが選択した場所にいません。「導入」を開いて修正してください。';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return '対応していない導入のセリフ：$type';
  }

  @override
  String get createCreating => '作成中...';

  @override
  String get createDiscard => '破棄';

  @override
  String get createCharactersStep => 'キャラクター（1人以上）';

  @override
  String get createLocationsStep => '場所（1か所以上）';

  @override
  String get createStoryEventsOptional => 'ストーリーイベント（任意）';

  @override
  String get createUpdateNotesRequiredPublish => '更新内容（公開に必要）';

  @override
  String get createWhatChangedVersion => 'このバージョンの変更内容は？';

  @override
  String get createView => '表示';

  @override
  String get createNotStartedYet => '未開始';

  @override
  String get createEdited => '編集済み';

  @override
  String get createPublishingWorldo => 'Worldoを公開中';

  @override
  String get createCreatingWorldo => 'Worldoを作成中';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Worldoの更新を準備しています。\nしばらくお待ちください。';

  @override
  String get createBringingWorldoLifeWait => 'Worldoに命を吹き込んでいます。\nしばらくお待ちください。';

  @override
  String get createDescribeIssue => '問題を説明してください';

  @override
  String get createSubmit => '送信';

  @override
  String get createBasicsWorldoName => 'Worldo名 *';

  @override
  String get createBasicsNameRequired => 'Worldo名は必須です。';

  @override
  String get createBasicsBriefRequired => 'Worldo概要は必須です。';

  @override
  String get createBasicsCoverRequired => 'カバー画像は必須です。';

  @override
  String get createBasicsMetricInvalid => '指標は有効なJSONである必要があります。';

  @override
  String get createBasicsEgMainStreet => '例：メインストリート';

  @override
  String get createBasicsWorldoBrief => 'Worldo概要 *';

  @override
  String get createBasicsBriefNote =>
      'プレイヤーが最初に見る紹介文。舞台、中心となる対立、興味を引く要素を記述します。';

  @override
  String get createBasicsHiddenNote => '物語を動かす隠されたルールや背景。思惑、仕組み、秘密の制約を記述します。';

  @override
  String get createBasicsEgHalfShopsMain =>
      '例：メインストリートの店の半分は板で塞がれている。労働者の日までに、最も裕福な店主が街を支配する。';

  @override
  String get createBasicsCoverImage => 'カバー画像 *';

  @override
  String get createBasicsUpload => 'アップロード';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'カードや詳細ページに使用します。推奨サイズは約768×1024 px。対応形式：JPG、PNG、WEBP。';

  @override
  String get createBasicsWorldoSettingsHidden => 'Worldo設定 — 非表示（任意）';

  @override
  String get createBasicsEgBankerSecretly =>
      '例：銀行家が融資先を密かに決めており、借りすぎた者は追い出される可能性がある。';

  @override
  String get createBasicsWorldoTimeOptional => 'Worldo時間（任意）';

  @override
  String get createBasicsWorldoStartsStart =>
      'このworldoは{開始時刻}に始まり、ユーザーが*進行*をタップするたびに、時間軸が{進行ごとの時間}だけ進みます。';

  @override
  String get createBasicsStartTime => '開始時刻';

  @override
  String get createBasicsDateExample => '例：1日目、09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => '進行ごとの時間';

  @override
  String get createBasicsEg8Hours3Days => '例：8時間 / 3日';

  @override
  String get createBasicsWorldoMetricOptional => 'Worldo指標（任意）';

  @override
  String get createBasicsMetricLabel => '指標名';

  @override
  String get createBasicsEgWealthGoalProgress => '例：資産 / 目標達成度';

  @override
  String get createBasicsLabelNote => '指標の説明';

  @override
  String get createBasicsDescribeWhatMetric => 'この指標が何を測定するか説明してください';

  @override
  String get createBasicsUnit => '単位';

  @override
  String get createBasicsEgCoins => '例：コイン / %';

  @override
  String get createBasicsRange => '値の範囲';

  @override
  String get createBasicsStarting => '初期値';

  @override
  String get createBasicsDeltaMin => '最小変動値';

  @override
  String get createBasicsDeltaMax => '最大変動値';

  @override
  String get createBasicsSaving => '保存中...';

  @override
  String get createBasicsAdvancedSettings => '詳細設定（任意）';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'キャラクター$index';
  }

  @override
  String get createCharacterSuggest => 'おすすめにする';

  @override
  String get createCharacterAvatarOptional => 'アバター\n（任意）';

  @override
  String get createCharacterName => '名前 *';

  @override
  String get createCharactersTitle => 'キャラクター';

  @override
  String createCharacterLimit({required int count}) {
    return 'キャラクターは最大$count人追加できます。';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'キャラクター$index：名前は必須です。';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'キャラクター$index：身分は必須です。';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'キャラクター$index：性格は必須です。';
  }

  @override
  String get createCharacterMinOne => '少なくとも1人のキャラクターを作成してください。';

  @override
  String get createCharacterEnterName => '名前を入力...';

  @override
  String get createCharacterIdentity => '身分 *';

  @override
  String get createCharacterEgHometownKidBack => '例：本当のチャンスを求めて故郷に戻った若者';

  @override
  String get createCharacterPersonality => '性格 *';

  @override
  String get createCharacterEgUnderdog => '例：善意はあるが資金の少ない挑戦者';

  @override
  String get createCharacterGoalOptional => '目標（任意）';

  @override
  String get createCharacterEgRichestOwner => '例：労働者の日までにメインストリートで最も裕福な店主になる';

  @override
  String get createCharacterBackgroundHidden => '背景 — 非表示（任意）';

  @override
  String get createCharacterEgLeftTownYears =>
      '例：何年も前に街を離れ、チャンスを求めて閉鎖されたメインストリートに戻ってきた。';

  @override
  String get createCharacterAddCharacter => '+ キャラクターを追加';

  @override
  String get createLocationImageOptional => '画像\n（任意）';

  @override
  String get createCharacterSelectAvailable => '以下の利用可能なキャラクターから選択';

  @override
  String get createCharacterInitialCharacters => '初期キャラクター（任意）';

  @override
  String get createLocationStartingCharacters => 'worldoが始まるときに、ここにいるキャラクター。';

  @override
  String get createCharacterAvailableSelect => '選択可能';

  @override
  String get createCharacterNoCharactersYet =>
      'キャラクターはまだいません。先に作成してから開始場所を選んでください。';

  @override
  String get createCharacterNoCharacters =>
      '選択できるキャラクターがいません。全員に初期場所が設定されています。';

  @override
  String get createLocationEveryL2L3Locations => '中にあるすべてのL2とL3の場所も削除されます。';

  @override
  String get createLocationEveryL3Locations => '中にあるすべてのL3の場所も削除されます。';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return '「$displayName」を削除';
  }

  @override
  String get createLocationOpeningLocation => 'ここは導入の場所です。削除すると導入も消去されます。';

  @override
  String get createLocationL1LocationRegion => 'L1の場所 · 地域 *';

  @override
  String get createLocationL2LocationBuilding => 'L2の場所 · 建物 *';

  @override
  String get createLocationAddL3Location => 'L3の場所を追加';

  @override
  String get createLocationsTitle => '場所';

  @override
  String get createLocationStatisticsNote =>
      'ワールドは3つの階層で構成されます：\nL1 · 地域     ワールド内のエリア — 中心街\nL2 · 建物   その中の建物 — ジョーの食堂\nL3 · 部屋       建物内の部屋 — 奥の厨房\nすべての場所に3階層が必要です。部屋は合計15室まで作成できます。';

  @override
  String get createLocationL1NameNote => '地区、街、森など、ワールド内のエリア。単独の建物ではありません。';

  @override
  String get createLocationL2NameNote => '店、学校、集合住宅など、その地域内の建物。';

  @override
  String get createLocationL3NameNote => '建物内の部屋。屋上、中庭、入口も設定できます。';

  @override
  String get createLocationName => '名前 *';

  @override
  String get createLocationL1NameRequired => 'L1の場所名は必須です。';

  @override
  String get createLocationL3NameRequired => 'L3の場所名は必須です。';

  @override
  String get createLocationThisL1 => 'このL1の場所';

  @override
  String get createLocationThisL2 => 'このL2の場所';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabelには少なくとも1つのL2の場所が必要です。';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabelには少なくとも1つのL3の場所が必要です。';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabelに名前のないL2の場所があります。';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabelに名前のないL3の場所があります。';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'L3の場所は最大$countか所追加できます。';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return '$count室すべてを使用しています。追加するには1室削除してください。';
  }

  @override
  String get createLocationAtLeastOneL1 => '少なくとも1つのL1の場所が必要です。';

  @override
  String get createLocationAddL1 => '少なくとも1つのL1の場所を追加してください。';

  @override
  String get createLocationMinOne => '少なくとも1か所の場所を作成してください。';

  @override
  String get createLocationIdRequired => 'すべての場所にIDが必要です。';

  @override
  String get createLocationIdUnique => 'すべての場所に固有のIDが必要です。';

  @override
  String get createLocationParentInvalid => 'すべての場所に有効な親が必要です。';

  @override
  String get createLocationFieldsRequired => '場所の必須項目をすべて入力してから保存してください。';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '場所を保存すると、削除されたキャラクターの導入のセリフ吹き出しも$count件削除されます。',
      one: '場所を保存すると、削除されたキャラクターの導入のセリフ吹き出しも1件削除されます。',
      zero: '場所を保存すると、削除されたキャラクターの導入のセリフ吹き出しも$count件削除されます。',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'L3の場所を編集';

  @override
  String get createLocationPreview => 'プレビュー';

  @override
  String get createLocationCompleteLocation => 'この場所を完成させるか、削除してください。';

  @override
  String get createLocationRemoveCharacter => 'この場所からキャラクターを外しますか？';

  @override
  String get createLocationRemove => '外す';

  @override
  String get createLocationL1Location => 'L1の場所';

  @override
  String get createLocationL2Location => 'L2の場所';

  @override
  String get createLocationL3Location => 'L3の場所';

  @override
  String get createOpeningSelectLocation => '場所を選択';

  @override
  String get createOpeningNoSavedLocations => '保存済みの場所がありません';

  @override
  String get createOpeningSelect => '選択';

  @override
  String get createOpeningSelectLocationFirst => '先に場所を選択してください。';

  @override
  String get createOpeningNoInitialCharacter => '初期キャラクターがいません';

  @override
  String get createOpeningLocationsLoading => '場所を読み込み中です。';

  @override
  String get createOpeningLoadingLocations => '場所を読み込み中...';

  @override
  String get createOpeningSwitchingLocations => '場所を切り替えると、セリフの内容が消去されます。';

  @override
  String get createOpeningContinue => '続行';

  @override
  String get createOpeningAdd10DialogueItems => 'セリフ項目は最大10件追加できます。';

  @override
  String get settingsUnableSaveSuggestedRole => 'おすすめのロールを保存できませんでした。';

  @override
  String get createOpeningUnableSaveOpening => '導入を保存できませんでした。';

  @override
  String get createOpeningSelectInitial => '初期場所を選択';

  @override
  String get createOpeningInitialLocationRequired => '初期場所を選択してから保存してください。';

  @override
  String get createOpeningAddDialogueFirst => '少なくとも1件のセリフ項目を追加してから保存してください。';

  @override
  String get createOpeningCompleteDialogue => 'すべてのセリフ項目を完成させてから保存してください。';

  @override
  String get createOpeningDialogue => '導入のセリフ';

  @override
  String get createOpeningLocationRequired => '先に場所を選択してからセリフを編集してください。';

  @override
  String get createOpeningNarrator => 'ナレーター';

  @override
  String get createOpeningImage => '画像';

  @override
  String get createOpeningSuggestRoleUser => 'ユーザーにロールをおすすめ';

  @override
  String get createOpeningNoCharacters => '利用可能なキャラクターがいません。';

  @override
  String get createOpeningEnterNarrator => 'ナレーターのセリフを入力';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return '$nameのセリフを入力';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => '画像をアップロード';

  @override
  String get createEventAddEvent => '+ イベントを追加';

  @override
  String get createStoryEventsTitle => 'ストーリーイベント';

  @override
  String createEventLimit({required int count}) {
    return 'イベントは最大$count件追加できます。';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'イベント$index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      '例：全国チェーンが空き地を狙い、地元の全店舗を価格で圧倒しようとしている。';

  @override
  String get createEventKeyStoryBeatAIUses => 'AIが物語の方向を決めるために使う、重要な展開。';

  @override
  String get imageCropUploadFailed => 'アップロードに失敗しました';

  @override
  String get inboxNotifications => '通知';

  @override
  String get inboxNoNotificationsYet => '通知はまだありません。';

  @override
  String get inboxFollowers => 'フォロワー';

  @override
  String get inboxNewFollowers => '新しいフォロワー';

  @override
  String get inboxNoNewFollowersYet => '新しいフォロワーはまだいません。';

  @override
  String get inboxComments => 'コメント';

  @override
  String get inboxNoCommentsYet => 'コメントはまだありません。';

  @override
  String get inboxPrivateChats => 'プライベートチャット';

  @override
  String get inboxChatFriendsWorldo => 'Worldoで友達とチャットしましょう。';

  @override
  String get inboxUnknownUser => '不明なユーザー';

  @override
  String get inboxDirectMessage => 'ダイレクトメッセージ';

  @override
  String get inboxJoinRequest => '参加申請';

  @override
  String get inboxApprove => '承認';

  @override
  String get inboxReject => '却下';

  @override
  String get inboxOk => 'OK';

  @override
  String get inboxReviewFailed => '審査に失敗しました';

  @override
  String get inboxLoadMessagesFailed => 'メッセージを読み込めませんでした。';

  @override
  String get inboxNewMessage => '新しいメッセージ';

  @override
  String get inboxSomeone => '誰か';

  @override
  String get inboxWorld => 'このワールド';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$nameが$world$suffixへの参加を申請しました';
  }

  @override
  String get inboxCommentWorldo => ' があなたのworldoにコメントしました';

  @override
  String get inboxReply => ' があなたに返信しました';

  @override
  String get inboxLikeComment => ' があなたのコメントにいいねしました';

  @override
  String get inboxLikedComment => 'があなたのコメントにいいねしました';

  @override
  String get inboxComment2LikeComment => 'があなたのコメントにいいねしました';

  @override
  String get inboxReplied => 'があなたに返信しました';

  @override
  String get inboxYou2Reply => 'があなたに返信しました';

  @override
  String get inboxCommentedOrigin => 'があなたの作品にコメントしました';

  @override
  String get inboxCommentOrigin => 'があなたの作品にコメントしました';

  @override
  String get inboxSentMessage => ' があなたにメッセージを送りました';

  @override
  String get inboxStartedFollowing => ' があなたをフォローしました。';

  @override
  String get meFailedOpenDiscord => 'Discordを開けませんでした';

  @override
  String get meImagePickFailed => '画像の選択に失敗しました';

  @override
  String get meUpdateFailed => '更新に失敗しました';

  @override
  String get mePlaying => 'プレイ中';

  @override
  String get meEditName => '名前を編集';

  @override
  String get meSignUpReward => '登録して250ジェムを獲得！';

  @override
  String get loginSignUpReward => '登録して250ジェムを獲得！';

  @override
  String get meUnknown => '不明';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID：$oid\n最新バージョン：$version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID：$displayWid\n所有者：$owner';
  }

  @override
  String get meFollows => 'フォロー';

  @override
  String meFollowingCount({required String followingCount}) {
    return '$followingCountフォロー中';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCountフォロワー';
  }

  @override
  String get meNoFollowingYet => 'まだ誰もフォローしていません。';

  @override
  String get meNoFollowersYet => 'フォロワーはまだいません。';

  @override
  String get meBlockFailed => 'ブロックできませんでした。もう一度お試しください。';

  @override
  String get meUserBlockedContentHasReported =>
      'ユーザーをブロックしました。このコンテンツをWorldoチームに通報しました。';

  @override
  String get meBlockUser => 'このユーザーをブロックしますか？';

  @override
  String get meBlock => 'ブロック';

  @override
  String get meUnblockFailed => 'ブロックを解除できませんでした。もう一度お試しください。';

  @override
  String get meUnblock => 'ブロック解除';

  @override
  String get meFollowing => 'フォロー中';

  @override
  String get meFollow => 'フォロー';

  @override
  String get meMessage => 'メッセージ';

  @override
  String meUID({required String uid}) {
    return 'UID：$uid';
  }

  @override
  String get meNoWorldoCreatedYet => '作成したWorldoはまだありません。';

  @override
  String get meNoWorldoYet => 'Worldoはまだありません。';

  @override
  String get meNoWorldsCreatedYet => '作成したワールドはまだありません。';

  @override
  String get meNoWorldsYet => 'ワールドはまだありません。';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'レッドジェム';

  @override
  String get gemsPink => 'ピンクジェム';

  @override
  String get gemsTop => 'チャージ';

  @override
  String get gemsBuy => 'ジェムを購入';

  @override
  String get gemsRecords => '履歴';

  @override
  String get gemsUnableLoad => 'ジェムを読み込めません。';

  @override
  String get settingsLogOutAccount => 'アカウントからログアウトしますか？';

  @override
  String get settingsLogOut => 'ログアウト';

  @override
  String get settingsFeedback => 'フィードバック';

  @override
  String get settings => '設定';

  @override
  String get settingsAboutUs => '私たちについて';

  @override
  String get settingsAccount => 'アカウント';

  @override
  String get settingsBlockedUsers => 'ブロックしたユーザー';

  @override
  String get settingsJoinDiscord => 'Discordに参加';

  @override
  String get meUserUnblocked => 'ユーザーのブロックを解除しました';

  @override
  String get meNoBlockedUsersYet => 'ブロックしたユーザーはまだいません。';

  @override
  String get settingsAgreeTermsContinue => '続行するには規約に同意してください。';

  @override
  String get settingsDeleteAccount => 'アカウントを削除しますか？';

  @override
  String get settingsAccountDeletionAgreement => 'アカウント削除に関する同意事項';

  @override
  String get settingsEnsureSecurityAccount =>
      'アカウントの安全のため、削除による影響をお読みください。\n\nアカウントの削除はログアウトとは異なり、取り消せません。作成したキャラクター、検索履歴、キャラクターとのチャット履歴、お気に入り、記憶、交流データ、注文履歴などの個人データは完全に削除され、復元できなくなります。';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      '購入または獲得した未使用のジェムはすべて永久に失われます。続行すると自発的に放棄したものとみなされ、アカウント削除によって自動的に返金を受ける権利は生じません。\n\n残りのメンバーシップ特典もすべて永久に失われ、復元できません。アカウントを削除してもサブスクリプションは解約されません。';

  @override
  String get settingsIHaveReadAccountDeletion => 'アカウント削除に関する同意事項を読みました';

  @override
  String get settingsCurrentLoginAccount => '現在ログイン中のアカウント：';

  @override
  String get profileSaveFailed => 'プロフィールを保存できませんでした。もう一度お試しください。';

  @override
  String get meSignInFailed => 'ログインに失敗しました。もう一度お試しください。';

  @override
  String get meCompleteProfileContinue => 'プロフィールを完成させて続行してください。';

  @override
  String get meSelectGenderAge => '性別と年齢を選択してください。';

  @override
  String get meSelectGender => '性別を選択してください。';

  @override
  String get meSelectAge => '年齢を選択してください。';

  @override
  String get meRequired => '必須';

  @override
  String get mePersonalizeWorldoExperience => 'Worldo体験を自分好みに';

  @override
  String get meSignIn => 'ログイン';

  @override
  String get meBack => '戻る';

  @override
  String get meSkip => 'スキップ';

  @override
  String get meContinueGoogle => 'Googleで続行';

  @override
  String get meContinueApple => 'Appleで続行';

  @override
  String get meSignUpClaimPremium => '登録してPremiumを受け取る';

  @override
  String get meSignUpContinue => '登録して続行';

  @override
  String get meAccountLoggedAnotherDevice => '別の端末でアカウントにログインされています。';

  @override
  String get premiumSubscription => 'サブスクリプション';

  @override
  String get gemsClaimFailed => '受け取りに失敗しました。';

  @override
  String get gemsCheckFailed => 'チェックインに失敗しました。';

  @override
  String get gemsFollowFailed => 'フォローに失敗しました。';

  @override
  String get gemsTaskUpdateFailed => 'タスクの更新に失敗しました。';

  @override
  String get gemsClaimSuccessful => '受け取りました！';

  @override
  String get gemsUnableLoadGemPacks => 'ジェムパックを読み込めません。';

  @override
  String get gemsNoGemPacksAvailable => '利用できるジェムパックがありません。';

  @override
  String get gemsUnableLoadGemTasks => 'ジェムのタスクを読み込めません。';

  @override
  String get gemsJoinUs => '参加しよう';

  @override
  String get gemsClaim => '受け取る';

  @override
  String get gemsClaimed => '受け取り済み';

  @override
  String get meDailyCheck => 'デイリーチェックイン';

  @override
  String get gemsDailyCheckInReward => '100獲得';

  @override
  String get meCheck => 'チェックイン';

  @override
  String get meCheckSuccessful => 'チェックインしました！';

  @override
  String get meGooglePlayUnavailable => 'Google Playを利用できません。';

  @override
  String get mePurchaseFailed => '購入に失敗しました。';

  @override
  String get gemsEarned => '獲得';

  @override
  String get gemsSpent => '消費';

  @override
  String get gemsPurchase => '購入';

  @override
  String get gemsGemRecords => 'ジェム履歴';

  @override
  String get gemsUnableLoadRecords => '履歴を読み込めません。';

  @override
  String get gemsNoGemRecordsYet => 'ジェム履歴はまだありません。';

  @override
  String get meAbout => 'このアプリについて';

  @override
  String get meEmailCopied => 'メールアドレスをコピーしました';

  @override
  String get mePurchasingPremium => 'Premiumを購入中';

  @override
  String get mePurchaseSuccessful => '購入が完了しました！';

  @override
  String get meWorldoPremiumSubscription =>
      'Worldo Premiumのサブスクリプションが有効になりました。';

  @override
  String get meMyBalance => '残高';

  @override
  String get meSoldOut => '売り切れ';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession => 'モデル一覧には完全なユーザーセッションが必要です';

  @override
  String get memoryModelListPermissionDenied => 'このワールドのモデル一覧へのアクセスが拒否されました';

  @override
  String get memorySaveFailed => '保存に失敗しました';

  @override
  String get memorySaveResultNotConfirmed => '保存結果を確認できません';

  @override
  String get memoryChooseModel => 'モデルを選択';

  @override
  String get memoryMaxTokenLimit => '記憶トークンの上限';

  @override
  String get memoryNoModelsAvailable => '利用可能なモデルがありません';

  @override
  String get memoryRetryRanges => '再試行範囲';

  @override
  String get memoryCurrentUsage => '現在の記憶使用量';

  @override
  String memoryMinGems({required String min}) {
    return '$minジェム';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min～$maxジェム';
  }

  @override
  String memoryStart({required String memoryStart}) {
    return '記憶 $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return '記憶 $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable => '記憶設定を利用できません';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Playの応答に時間がかかりすぎました。もう一度お試しください。';

  @override
  String get premiumSubscriptionsNotSupported =>
      'この端末のGoogle Playではサブスクリプションに対応していません。';

  @override
  String get premiumConnectionGooglePlayLost =>
      'Google Playへの接続が切れました。もう一度お試しください。';

  @override
  String get premiumPurchaseCanceled => '購入はキャンセルされました。';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Playを一時的に利用できません。後でもう一度お試しください。';

  @override
  String get premiumGooglePlayBilling =>
      'Google Playの課金を利用できません。Playアカウントと支払い設定をご確認ください。';

  @override
  String get premiumSubscriptionUnavailable =>
      'このPremiumサブスクリプションは現在Google Playで利用できません。';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google PlayでPremiumの購入を完了できませんでした。もう一度お試しください。';

  @override
  String get premiumAlreadyOwnSubscription =>
      'このサブスクリプションはGoogle Playですでに購入済みです。';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Playで変更対象のサブスクリプションが見つかりません。「定期購入の管理」をご確認ください。';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Google Playに接続できません。インターネット接続を確認して、もう一度お試しください。';

  @override
  String get premiumInsufficientFunds =>
      '支払い方法の残高が不足しています。Google Playで更新して、もう一度お試しください。';

  @override
  String get premiumGoogleAccountIneligible =>
      'このGoogle Playアカウントはサブスクリプション特典の対象外です。';

  @override
  String get premiumAppStoreFailedComplete =>
      'App StoreでPremiumの購入を完了できませんでした。もう一度お試しください。';

  @override
  String get premiumFailedConnectAppStore =>
      'App Storeに接続できません。インターネット接続を確認して、もう一度お試しください。';

  @override
  String get premiumAppStoreTookTooLong =>
      'App Storeの応答に時間がかかりすぎました。もう一度お試しください。';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'App Storeでシステムエラーが発生しました。後でもう一度お試しください。';

  @override
  String get premiumRegionUnavailable =>
      'このPremiumサブスクリプションは、App Storeの設定地域では利用できません。';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'このアプリではこのApp Storeリクエストを実行できません。サポートにお問い合わせください。';

  @override
  String get premiumPurchaseNotSupported => 'この端末またはシステムバージョンでは、この購入に対応していません。';

  @override
  String get premiumAppStorePurchaseWindow =>
      'App Storeの購入画面を開けませんでした。アプリに戻って、もう一度お試しください。';

  @override
  String get premiumAppStoreFailedAccept =>
      'App Storeでこの購入数量を受け付けられませんでした。サポートにお問い合わせください。';

  @override
  String get premiumAppStoreUnavailable =>
      'このPremiumサブスクリプションは現在App Storeで利用できません。';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'この端末では購入が許可されていません。Apple Accountと購入制限をご確認ください。';

  @override
  String get premiumAppleAccountNotEligible =>
      'このApple Accountはサブスクリプション特典の対象外です。';

  @override
  String get premiumSubscriptionOffer =>
      'このサブスクリプション特典は利用できません。ページを更新して、もう一度お試しください。';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'App Storeでこの特典価格を受け付けられませんでした。ページを更新して、もう一度お試しください。';

  @override
  String get premiumAppStoreFailedVerify =>
      'App Storeでこのサブスクリプション特典を検証できませんでした。サポートにお問い合わせください。';

  @override
  String get premiumSubscriptionOfferFailed =>
      'このサブスクリプション特典を準備できませんでした。ページを更新して、もう一度お試しください。';

  @override
  String get premiumAddPaymentMethodApple =>
      'Apple Accountに支払い方法を追加して、もう一度お試しください。';

  @override
  String get premiumAppCannotMakePurchases =>
      'このアプリではApp Storeでの購入を行えません。サポートにお問い合わせください。';

  @override
  String get premiumAppStoreRequestRejected =>
      'App Storeでこの購入リクエストを受け付けられませんでした。再試行するか、サポートにお問い合わせください。';

  @override
  String get premiumAppleCloudServiceAccess =>
      'Appleのクラウドサービスへのアクセスが拒否されました。Apple Accountの権限をご確認ください。';

  @override
  String get premiumFailedConnectApple =>
      'Appleのサービスに接続できません。インターネット接続を確認して、もう一度お試しください。';

  @override
  String get premiumAccess2AppleCloudService =>
      'Appleのクラウドサービスへのアクセスが取り消されました。Apple Accountの設定をご確認ください。';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Apple Accountで最新のAppleプライバシー規約に同意して、もう一度お試しください。';

  @override
  String get premiumAppStoreWindowFailed =>
      'App Storeの画面を設定できませんでした。サポートにお問い合わせください。';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'App Storeの画面を開くのに時間がかかりすぎました。もう一度お試しください。';

  @override
  String get premiumReturnAppTryPurchase => 'アプリに戻って、もう一度購入をお試しください。';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Playを利用できません。インストール済みでログインしていることをご確認ください。';

  @override
  String get premiumIs4Subscription =>
      'このPremiumサブスクリプションは現在ストアで利用できません。ページを更新して、もう一度お試しください。';

  @override
  String get premiumSubscriptionFailed =>
      'このPremiumサブスクリプションを準備できませんでした。ページを更新して、もう一度お試しください。';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'ストアでこのPremiumの購入を開始できませんでした。もう一度お試しください。';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'Google Playで元のサブスクリプションが見つかりません。「定期購入の管理」をご確認ください。';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'このサブスクリプションは別の購入識別情報を使用しています。ページを更新するか、サポートにお問い合わせください。';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Playでこのサブスクリプションをまだ変更できません。「定期購入の管理」をご確認ください。';

  @override
  String get premiumPlanChangePending =>
      'このプランのApp Store購入は処理中です。完了するまでお待ちください。';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'App StoreからPremiumプランを読み込めませんでした。もう一度お試しください。';

  @override
  String get premiumPurchasePreparation => '購入準備の有効期限が切れました。もう一度お試しください。';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'App Storeから不明な購入結果が返されました。再試行する前にサブスクリプションをご確認ください。';

  @override
  String get premiumPurchasesUnavailable => '現在、購入を利用できません。';

  @override
  String get premiumAutoRenewsCancelAnytime => '自動更新。いつでも解約できます。';

  @override
  String get premiumSubscribed => '登録済み';

  @override
  String get premiumAlsoIncluded => 'こちらも含まれます';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'ピンクジェム';

  @override
  String get premiumRedGems => 'レッドジェム';

  @override
  String get premiumExtraDailyCheck => 'デイリーチェックインで追加獲得';

  @override
  String get premiumDailyCheck => 'デイリーチェックイン';

  @override
  String get premiumClaimedMonthly => '毎月受け取り';

  @override
  String get premiumBilledMonthly => '毎月請求';

  @override
  String premiumSaveSavings({required String savings}) {
    return '$savings%お得';
  }

  @override
  String get premiumSubscribe => '登録する';

  @override
  String get premiumActiveYearlySubscription =>
      '有効な年額Premiumサブスクリプションを月額プランに変更することはできません。';

  @override
  String get premiumAlreadyHaveActive => 'すでに有効なPremiumサブスクリプションがあります。';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'Premium $labelにはすでに登録しています。';
  }

  @override
  String get premiumPreviousPurchasePending => '前回のPremium購入をまだ確認中です。';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Premiumサブスクリプションのアップグレードは、購入したストアで行ってください。';

  @override
  String get premiumResolveCurrent => '購入前に、ストアで現在のサブスクリプションの問題を解決してください。';

  @override
  String get premiumPurchaseUnavailable => '現在、Premiumを購入できません。';

  @override
  String get premiumUnableVerifyPurchase => '購入資格を確認できません。もう一度お試しください。';

  @override
  String get premiumStoreFailedVerifyPurchase => 'ストアでこのPremium購入を検証できませんでした。';

  @override
  String get premiumPurchaseDoesNotMatch => 'このPremium購入は選択したプランと一致しません。';

  @override
  String get premiumMessagePurchaseCanceled => 'このPremium購入はキャンセルされました。';

  @override
  String get premiumPurchaseRevoked => 'このPremium購入は取り消されました。';

  @override
  String get premiumNotification => '通知';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premiumは現在のサブスクリプションで有効です。ダウングレードには対応していません。';

  @override
  String get premiumGot => '了解';

  @override
  String get gemBalancePromptInsufficientGems => 'ジェム不足';

  @override
  String get gemBalancePromptLowGems => 'ジェム残高が少なくなっています';

  @override
  String get appPressBackExit => 'もう一度戻るを押すと終了します。';

  @override
  String get appReportSubmitted => '通報を送信しました';

  @override
  String get appReportFailed => '通報に失敗しました';

  @override
  String get appUpdateRequired => '更新が必要です';

  @override
  String get appUpdateContent => 'Worldoを引き続き利用するには、最新バージョンに更新してください。';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'バージョン$versionName';
  }

  @override
  String get appUpdateCheckFailed => '更新状況を再取得できません。更新して続行してください。';

  @override
  String get appUpdate => '今すぐ更新';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabelをコピーしました';
  }

  @override
  String get commonClose => '閉じる';

  @override
  String get commonImageLoadFailed => '画像の読み込みに失敗しました';

  @override
  String get commonPageNotFound => 'ページが見つかりません。';

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
    return 'LLMが最初のTickを生成しています。しばらくお待ちください$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return '最新バージョン：V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return '作成する前に$missingSectionsを保存してください。';
  }

  @override
  String get createCharacterRoleHint => 'worldo内でのキャラクターの役割。';

  @override
  String get createCharacterMannerHint => 'セリフを決める、キャラクターの話し方や振る舞い。';

  @override
  String get createCharacterGoalHint => '行動を決める、キャラクターの目標や行動方針。';

  @override
  String get createCharacterBackgroundHint => 'キャラクターの背景と人間関係。';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return '$world$worldIdSuffixへの参加申請';
  }

  @override
  String get memoryModel => '記憶とモデル';

  @override
  String get premiumAccountMismatch => 'アカウントの識別情報が以前のサブスクリプションと一致しません。';

  @override
  String get worldRecap => 'ストーリーの振り返り';

  @override
  String get inboxMissingJoinRequestId => '参加申請IDがありません';

  @override
  String get loginTimedOut => 'ログインがタイムアウトしました。もう一度お試しください。';

  @override
  String get loginConnectionFailed => '接続できません。インターネット接続を確認して、もう一度お試しください。';

  @override
  String get loginTemporarilyUnavailable => '現在ログインできません。しばらくしてからお試しください。';

  @override
  String get recapUnlockHeading => 'ストーリーの振り返りを解放';

  @override
  String get recapUpsellDescription =>
      '物語の展開や選択、登場人物をまとめた振り返りで、これまでのストーリーを確認できます。';

  @override
  String get recapShowEarlier => '以前の振り返りを見る';

  @override
  String get recapEmpty => 'ストーリーが進むと、ここに振り返りが表示されます。';

  @override
  String get chatMessageAsNarrator => 'ナレーターとしてメッセージを送信';

  @override
  String chatMessageAsCharacter({required String name}) {
    return '$nameとしてメッセージを送信';
  }

  @override
  String get chatNarratorSpeaker => 'ナレーター';

  @override
  String get chatYourCharacterSpeaker => '自分のキャラクター';

  @override
  String chatSpeakingAs({required String speaker}) {
    return '$speakerとして発言中';
  }

  @override
  String get chatSwitchCharacter => 'キャラクターに切り替え';

  @override
  String get chatSwitchNarration => 'ナレーションに切り替え';

  @override
  String chatOpenLocation({required String locationName}) {
    return '$locationNameを開く';
  }

  @override
  String get chatRetryMessage => 'メッセージを再送信';

  @override
  String get blockedReportFailed => 'ユーザーをブロックしましたが、通報できませんでした。';

  @override
  String get storeConnectionFailed => 'ストアに接続できません。もう一度お試しください。';

  @override
  String get storeProductUnavailable => 'この商品は現在購入できません。';

  @override
  String get storeDevicePurchasesUnavailable => 'このデバイスでは購入できません。';

  @override
  String get worldHistoryRequestFailed => 'ワールドの履歴を取得できませんでした';

  @override
  String get genericError => 'エラーが発生しました';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': '$plan Premium、年額 $price',
      'other': '$plan Premium、月額 $price',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => '消去できませんでした';

  @override
  String get developerGatewaySignatureFailed => 'Gatewayの署名検証に失敗しました';

  @override
  String get developerEndpointsSaved => '保存しました。新しいリクエストには設定したエンドポイントを使用します。';

  @override
  String get developerAdjustRestartRequired => 'Adjust環境を適用するには、アプリを再起動してください。';

  @override
  String developerRecapSetting({required String mode}) {
    return 'ワールドの振り返り：$mode';
  }

  @override
  String get developerRecapPreview => 'ワールドの振り返りプレビュー';

  @override
  String get developerRecapPreviewDescription =>
      'ワールドのパネルでメンバーシップ状態と振り返りの内容を一時的に置き換えます。アプリの再起動でリセットされます。';

  @override
  String get developerResetFailed => 'リセットできませんでした';

  @override
  String get developerRecapOff => 'オフ（メンバーシップに従う）';

  @override
  String get developerRecapLocked => 'ロック中 · メンバーではない';

  @override
  String get developerRecapEmpty => 'メンバー · 未生成';

  @override
  String get developerRecapSample => 'メンバー · サンプルの振り返り';

  @override
  String get developerRecapLive => 'メンバー · 実際の振り返り';

  @override
  String get chatEditFreeUsesExhausted => '無料の編集回数が残っていません。';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'メンバーシップ：$selection';
  }

  @override
  String get developerMembershipDescription =>
      'すべての画面で、このアカウントのメンバーシップ状態を一時的に変更します。サーバーでは実際のアカウント状態が使われます。App を再起動すると元に戻ります。';

  @override
  String get developerMembershipOff => 'オフ（実際のメンバーシップ）';

  @override
  String get developerMembershipYearly => 'Premium · 年払い';

  @override
  String get developerMembershipMonthly => 'Premium · 月払い';

  @override
  String get developerMembershipNone => '未加入';

  @override
  String get originStartBySelectingRole => 'まず自分の役を選びましょう';

  @override
  String get originRecommendedStart => 'おすすめの開始地点';

  @override
  String get originStoryOpening => '物語の始まり';

  @override
  String get originOpeningLocation => '開始地点';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$namesは現在、\n$locationNameにいます',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return '物語の始まり\n$locationName';
  }

  @override
  String get chatHistoryExpand => '展開';

  @override
  String get chatHistoryCollapse => '折りたたむ';

  @override
  String get chatCharacterMovement => 'キャラクターの移動';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get imageGifUnsupported => 'GIF animations are not supported.';

  @override
  String get worldProgressComplete => 'Progress complete';

  @override
  String a11ySwitchMode({required String label}) {
    return 'Switch to $label mode';
  }

  @override
  String a11yEditItem({required String title}) {
    return 'Edit $title';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return '$index of $count role cards';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return 'Edit inspiration $index';
  }

  @override
  String a11yInsert({required String label}) {
    return 'Insert $label';
  }

  @override
  String get a11yMembership => 'Membership';

  @override
  String get a11yOpenWorldo => 'Open Worldo';

  @override
  String get a11yFilterGender => 'Filter by gender';

  @override
  String get a11ySelectRole => 'Select Your Role';

  @override
  String get a11yLoadingMap => 'Loading map';

  @override
  String get a11yBuildingWorld => 'Building the world';

  @override
  String get a11yPremiumMembership => 'Premium membership';

  @override
  String get a11yProMembership => 'Pro membership';

  @override
  String get a11yRecommendedRole => 'Recommended role';

  @override
  String get a11yLastMessage => 'Last Message';

  @override
  String get a11yRecentChat => 'Recent chat';

  @override
  String get a11yAiReplyLoading => 'AI reply loading';

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
      other: 'Players',
      one: 'Player',
      zero: 'Player',
    );
    return '$amount $_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max (Added / Max)';
  }

  @override
  String get createSixHours => '6 hours';

  @override
  String get createTwelveHours => '12 hours';

  @override
  String get createOneDay => '1 day';

  @override
  String get createOneWeek => '1 week';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageChangeFailed =>
      'Could not change language. Please try again.';

  @override
  String get purchasingGems => 'Purchasing Gems';

  @override
  String get purchaseSuccessful => 'Purchase successful!';

  @override
  String get okAction => 'OK';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get requestAction => 'Request';

  @override
  String get requestedStatus => 'Requested';

  @override
  String get launchAction => 'Launch';

  @override
  String get tickNowAction => 'Tick now';

  @override
  String get writePostHint => 'Write a post';

  @override
  String get newPostTitle => 'New post';

  @override
  String get aiIsGenerating => 'AI is generating';

  @override
  String get generatingCustomizedWorldWait =>
      'Generating a live and customized world for you.\nPlease wait for a moment.';

  @override
  String get approvedStatus => 'Approved';

  @override
  String get rejectedStatus => 'Rejected';

  @override
  String get awaitingApprovalStatus => 'Awaiting approval';

  @override
  String get awaitingYourApprovalStatus => 'Awaiting your approval';

  @override
  String get liveYourWorld => 'LIVE YOUR WORLD';

  @override
  String get signedOutMeDescription =>
      'Play world, create worldo, invite friends,\nand continue them anywhere.';

  @override
  String get gemTaskLaunchWorldHint =>
      'Open a Worldo you like, then Launch your own world.';

  @override
  String get gemTaskInviteFriendHint =>
      'Open a World, then tap Invite in the detail panel.';

  @override
  String get gemTaskWriteCommentHint =>
      'Open a Worldo you liked, then write a post in Discuss.';

  @override
  String get gemTaskRequestJoinHint =>
      'Open a World you haven’t joined, then request to join it.';

  @override
  String get gemTaskSendMessageHint => 'Send messages in your world.';

  @override
  String get gemTaskProgressWorldHint =>
      'Open your playing World, then tap Tick Now.';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => 'World';

  @override
  String get userLabel => 'User';

  @override
  String get meLabel => 'Me';

  @override
  String get locationLabel => 'Location';

  @override
  String get allLabel => 'All';

  @override
  String get maleLabel => 'Male';

  @override
  String get femaleLabel => 'Female';

  @override
  String get nonBinaryLabel => 'Non binary';

  @override
  String get forYouLabel => 'For you';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get purchaseCanceled => 'Purchase canceled.';

  @override
  String get purchasePending => 'Your purchase is pending.';

  @override
  String get purchaseConfirmationDelayed =>
      'Purchase confirmation is delayed. Please check again later.';

  @override
  String get purchaseFailed => 'Purchase failed.';

  @override
  String get yearlyPlan => 'Yearly';

  @override
  String get monthlyPlan => 'Monthly';

  @override
  String get proSubscriptionTagline => 'Go deeper into every Worldo you play.';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price, Billed annually';
  }

  @override
  String expiresOn({required String date}) {
    return 'Expires $date';
  }

  @override
  String get activeStatus => 'ACTIVE';

  @override
  String get expiredStatus => 'Expired';

  @override
  String updatedAt({required String timestamp}) {
    return 'Updated $timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => 'Load failed. Retry';

  @override
  String get loadMoreAction => 'Load more';

  @override
  String get gemPurchaseRecord => 'Gem purchase';

  @override
  String get taskRewardRecord => 'Task reward';

  @override
  String get worldProgressRecord => 'World progress';

  @override
  String get directMessageRecord => 'Direct message';

  @override
  String get gemRecord => 'Gem record';

  @override
  String get runATickTask => 'Run a Tick';

  @override
  String get runATickTaskDescription =>
      'Open one of your playing Worlds and tap Tick Now.';

  @override
  String get someoneFallback => 'Someone';

  @override
  String get aCharacterFallback => 'a character';

  @override
  String get thisWorld => 'this World';

  @override
  String get noWorldEventsYet => 'No world events yet.';

  @override
  String get globalLabel => 'Global';

  @override
  String get eventLabel => 'Event';

  @override
  String get characterDestinations => 'Character destinations';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName $direction $locationName';
  }

  @override
  String get cameToDirection => 'came to';

  @override
  String get wentToDirection => 'went to';

  @override
  String get hasComeToDirection => 'has come to';

  @override
  String get hasGoneToDirection => 'has gone to';

  @override
  String get waitForReplyToSendMore => 'Wait for a reply to send more';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation => 'Please select a preset role';

  @override
  String get enterNameValidation => 'Please enter a name';

  @override
  String get enterIdentityValidation => 'Please enter an identity';

  @override
  String get waitForProfileLoading =>
      'Please wait for the profile to finish loading.';

  @override
  String get imageUploadFailed => 'Image upload failed.';

  @override
  String get photoAccessDenied => 'Photo access denied';

  @override
  String get feedbackSubmitted => 'Feedback submitted';

  @override
  String get feedbackFailed => 'Feedback failed';

  @override
  String get worldoDetailUnavailable => 'Worldo detail is unavailable.';

  @override
  String get publishAction => 'Publish';

  @override
  String get publishingStatus => 'Publishing...';

  @override
  String get publishFailed => 'Publish failed';

  @override
  String get publishChangesBeforeLeaving => 'Publish changes before leaving?';

  @override
  String get noChangesToPublish => 'No changes to publish.';

  @override
  String get completeOpeningRequiredToPublish =>
      'A complete Opening is required to publish';

  @override
  String get publishResponseMissingOriginId =>
      'Publishing did not return a Worldo ID.';

  @override
  String get worldoIdRequired => 'A Worldo ID is required.';

  @override
  String loadFailedWithReason({required String reason}) {
    return 'Load failed: $reason';
  }

  @override
  String get imageSelectionFailed => 'Image selection failed';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID: $oid\nLatest Version: $version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID: $wid\nOwner: $owner';
  }

  @override
  String get sendFailed => 'Send failed';

  @override
  String get selectARole => 'Select a role';

  @override
  String get timeLabel => 'Time';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID: $oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID: $oid · Creator: $creator';
  }

  @override
  String get worldoMetricExplanation =>
      'This worldo updates each character\'s {Metric Label} every progress, shown in {Unit}. Each character starts at {Starting}, and the value can move within {Delta Min}–{Delta Max}.';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return 'Launch a $worldo to generate\nyour own World';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return 'Estimated next message $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount Gems';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return 'Delete world $worldName';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername playing as $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName launched!';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName created!';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName published!';
  }

  @override
  String get createTimeout => 'Worldo creation timed out.';

  @override
  String get publishTimeout => 'Worldo publishing timed out';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return 'You requested to join $worldName$worldId';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge requested to join $worldName$worldId';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge commented on your worldo';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge replied to you';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge liked your comment';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge sent you a message';
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
    return 'Free inspiration uses left: $remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return 'Free Edition uses left: $remaining\n$action';
  }

  @override
  String get getMoreAction => 'Get more >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName came to $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldo lets you create, discover, and enter AI-powered worlds filled with characters, stories, and evolving events. Chat with AI characters, play with friends, and progress each world through immersive scenes and choices.\n\nOur app offers a new way to experience interactive stories — not just as a reader, but as someone inside the world. If you have any questions, please contact us at $contactEmail.';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy , $termsOfUse and $endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return 'By continuing, you agree to our $terms, $privacyPolicy, and $endUserLicenseAgreement';
  }

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get terms => 'Terms';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get endUserLicenseAgreement => 'End User License Agreement';

  @override
  String existingAccountSignIn({required String signIn}) {
    return 'Already have an account? $signIn';
  }

  @override
  String get signInAction => 'Sign in.';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return '$gemIcon$grantedAmount Gems have been granted.';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return 'Up to $amount Gems monthly, plus full premium access.';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount /day';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price/mo';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge: Reply to $replyToName$replyToBadge: $content';
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
  String get homeLoadFailed => 'Load failed';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeEmptyDescription =>
      'Worldo is the blueprint. Launch to create a live World you can enter and grow.';

  @override
  String get homeWorldCharacter => 'Character';

  @override
  String get homeWorldSingleOtherPlayer => '· 1 other Player';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· $otherPlayerCount other Players';
  }

  @override
  String get homeSignInUnavailable => 'Sign-in unavailable';

  @override
  String get homeSignedOutTitle => 'Your worlds, all in one place';

  @override
  String get homeSignedOutDescription =>
      'Sign in to create worlds and continue your stories.';

  @override
  String get searchUID => 'UID: ';

  @override
  String get searchOID => 'OID: ';

  @override
  String get searchWID => 'WID: ';

  @override
  String searchOwner({required String owner}) {
    return 'Owner: $owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID: $oid  Creator: $originator\nBrief: $brief\nLatest Version: $version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID: $wid\nOwner: $owner';
  }

  @override
  String get searchHistory => 'Search history';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get searchNoResults => 'No results.';

  @override
  String get searchCancel => 'Cancel';

  @override
  String get searchHint => 'Worldo, Character, Tags';

  @override
  String get worldDetailOnlyWorldsLaunched =>
      'Only worlds launched by you alone can be deleted.';

  @override
  String get worldDetailDelete => 'Delete';

  @override
  String get worldDetailNoCharacterStatusYet => 'No character status yet.';

  @override
  String get worldDetailNoCharactersYet => 'No characters yet.';

  @override
  String get worldDetailProgressingWorld => 'Progressing the World';

  @override
  String get worldDetailCompressingRecent =>
      'Compressing recent memories\nAdvancing the world timeline\nGenerating the next story beat\nUpdating character locations';

  @override
  String get worldModelsDetail => 'Detail';

  @override
  String get worldModelsLocations => 'Locations';

  @override
  String get worldModelsEvents => 'Events';

  @override
  String get worldModelsStatus => 'Status';

  @override
  String get worldDetailUnavailable => 'Unavailable';

  @override
  String worldActionFailed({required String actionLabel}) {
    return '$actionLabel failed';
  }

  @override
  String get worldDetailRequestJoinWorld => 'Request to join this World?';

  @override
  String get worldDetailRequest => 'Request';

  @override
  String get worldDetailLaunchFailed => 'Launch failed';

  @override
  String get worldDetailNoSavedProfileFound => 'No saved profile found';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return 'Source Worldo: $sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => 'Invite';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return 'Join my world \"$worldName\" on Worldo!\n$wid\nSearch this WID on Worldo to find and join.\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => 'World Brief';

  @override
  String get worldDetailCast => 'Cast';

  @override
  String get worldDetailLinkCopiedShare =>
      'Link copied. Share it with your friends.';

  @override
  String get worldMapAction => 'Map';

  @override
  String get worldInfoAction => 'Info.';

  @override
  String worldLocationCount({required String pointsCount}) {
    return 'Location ($pointsCount)';
  }

  @override
  String get worldDetailPlayer => 'Player';

  @override
  String worldDetailGoal({required String goal}) {
    return 'Goal: $goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet => 'No character details yet.';

  @override
  String get worldDetailNoEventsYet => 'No events yet.';

  @override
  String get worldDetailLoadEventsFailed => 'Load events failed.';

  @override
  String homeLocationID({required String id}) {
    return 'Location $id';
  }

  @override
  String get homeBuildingWorld => 'BUILDING THE WORLD';

  @override
  String get worldMapLoadFailed => 'Map failed to load';

  @override
  String get worldMapZoomIn => 'Zoom in on map';

  @override
  String get worldMapZoomOut => 'Zoom out of map';

  @override
  String get worldDetailGlobal => 'Global';

  @override
  String get worldDetailLocation => 'Location';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => 'Generating first tick';

  @override
  String get worldFirstTickStatusLoadFailed =>
      'Generation status could not be loaded.';

  @override
  String get worldDetailNew => 'New';

  @override
  String get homeUnknownLocation => 'Unknown location';

  @override
  String get homeUnknownCharacter => 'Unknown character';

  @override
  String get homeNewPlaceEmerged => 'New Place Emerged';

  @override
  String get homeNewCharacterAppeared => 'New Character Appeared';

  @override
  String get chatLocationUnavailable => 'Location is unavailable';

  @override
  String get chatRequestApprovalLaunch => 'Request approval to launch';

  @override
  String get chatLoading => 'Loading';

  @override
  String get chatQuotaCheckFailed =>
      'Could not check free uses. Please try again.';

  @override
  String get chatInspirationSourceChanged =>
      'The inspiration source changed. Please reopen inspiration.';

  @override
  String get chatInspiration => 'Inspiration';

  @override
  String get chatMessageCannotSend => 'This message can no longer be sent';

  @override
  String get chatMessageEmpty => 'The message is empty';

  @override
  String get chatConnectionFailed => 'Could not connect to this chat';

  @override
  String get chatReplyChangedSelect =>
      'The reply changed. Please select inspiration again.';

  @override
  String get chatSendConfirmFailed => 'Could not confirm the message send';

  @override
  String get chatNoNetworkConnection => 'No network connection';

  @override
  String get chatRoundCannotContinue => 'This round cannot continue';

  @override
  String get chatSourceRoundChanged => 'The source round changed';

  @override
  String get chatGo => 'Go on';

  @override
  String get chatReplyActionUnavailable =>
      'This reply action is no longer available';

  @override
  String get chatRegenerateFailure => 'Regenerate failure';

  @override
  String get chatGoFailure => 'Go on failure';

  @override
  String get chatEditFailure => 'Edit failure';

  @override
  String get chatInspirationFailure => 'Inspiration failure';

  @override
  String get chatJoinLocationFailed => 'Failed to join this location';

  @override
  String get chatInactive => 'This chat is no longer active';

  @override
  String get chatChatroomUnavailable => 'Chatroom is unavailable';

  @override
  String get chatFailedConfirmReplyAction =>
      'Could not confirm the reply action';

  @override
  String get chatLeastOneMessageMustRemain =>
      'At least one message must remain.';

  @override
  String get chatReplyNotEditable => 'This reply is not editable';

  @override
  String get chatReplyAlreadyFixed => 'This reply has been fixed';

  @override
  String get chatReplyEditorFrozen => 'Reply editor is frozen';

  @override
  String get chatResolvePreviousSaveBefore =>
      'Resolve the previous save before changing its draft';

  @override
  String get chatStaleReplyEditor => 'Stale reply editor';

  @override
  String get chatPreviousSaveResultUncertain =>
      'The previous save result is uncertain; reload before editing again';

  @override
  String get chatCandidateMissing => 'The candidate no longer exists';

  @override
  String get chatBatchSupportsMost100Changes =>
      'A batch supports at most 100 changes';

  @override
  String get chatMissingStableMessageIdentity =>
      'Missing stable message identity';

  @override
  String get chatEditTargetHasChanged => 'The edit target has changed';

  @override
  String get chatMessageNotEditable => 'This message cannot be edited';

  @override
  String get chatReplyNoLongerEditable => 'This reply is no longer editable';

  @override
  String get chatEditorOpenFailed => 'The editor could not be opened';

  @override
  String get chatInactiveDuringEdit => 'This chat is no longer active.';

  @override
  String get chatEditMessage => 'Edit Message';

  @override
  String get chatSave => 'Save';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatRegenerate => 'Regenerate';

  @override
  String get chatRegenerateUnavailable => 'This round cannot be regenerated';

  @override
  String get chatGenerate10Replies => 'You can generate up to 10 replies.';

  @override
  String get chatPreviousReply => 'Previous reply';

  @override
  String get chatNextReply => 'Next reply';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatReport => 'Report';

  @override
  String get chatCopied => 'Copied';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => 'Mention';

  @override
  String get chatCharacters => 'Characters';

  @override
  String get chatNoCharacters => 'No characters';

  @override
  String get chatNoLocations => 'No locations';

  @override
  String get chatHere => 'Here';

  @override
  String get chatLoadEarlierMessages => 'Load earlier messages';

  @override
  String get chatText => 'Text...';

  @override
  String get chatLocationRoster => 'YOU';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer =>
      'All content is AI-generated and fictional. Any resemblance to real people, events, or places is coincidental.';

  @override
  String get homeRecent => 'Recent';

  @override
  String get worldoUnableSavePreference =>
      'Unable to save your preference. Please try again.';

  @override
  String get worldoFilterGender => 'Filter by gender';

  @override
  String get worldoNoData => 'No data';

  @override
  String get worldoAll => 'All';

  @override
  String get worldoDetailSelectRole => 'Select your role';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return 'Creator: $creatorName';
  }

  @override
  String get worldoDetailEditWorldo => 'Edit Worldo';

  @override
  String get worldoDetailWorldoBrief => 'Worldo Brief';

  @override
  String get worldoDetailNewPost => 'New post';

  @override
  String get worldoDetailWritePost => 'Write a post';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return 'Discuss ($discussCount)';
  }

  @override
  String get worldoDetailViewAll => 'View all >';

  @override
  String get worldoDetailPlayingWorld => 'Playing World';

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
    return 'Characters ($length)';
  }

  @override
  String get worldoSend => 'Send';

  @override
  String get worldoPostFailed => 'Post failed';

  @override
  String get worldoImageUploadFailed => 'Image upload failed';

  @override
  String get worldoLoadRepliesFailed => 'Load replies failed';

  @override
  String get worldoWriteReply => 'Write a reply';

  @override
  String worldoReplyName({required String replyToName}) {
    return 'Reply to $replyToName';
  }

  @override
  String get worldoPostDetail => 'Post Detail';

  @override
  String get worldoPostUnavailable => 'Post unavailable';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return 'All Replies $replyCount';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return 'View all $replyCount replies';
  }

  @override
  String get worldoLikeFailed => 'Like failed';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return 'View all $replyCount replies';
  }

  @override
  String get worldoUser => 'User';

  @override
  String get worldoViewMore => 'View More >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return 'Discuss ($discussCount)';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return 'View all $remainingReplyCount replies';
  }

  @override
  String get worldoReply => 'Reply';

  @override
  String get worldoDiscussTitle => 'Discuss';

  @override
  String get worldoLaunchLocationComesLife =>
      'This location comes to life after launch.';

  @override
  String get worldoLaunchLaunchWorldoExplore =>
      'Launch this Worldo to explore and interact here.';

  @override
  String get worldoLaunchRoleUnavailable => 'This role is no longer available';

  @override
  String get worldoLaunchSelectRole => 'Select Your Role';

  @override
  String get worldoLaunchProfile => 'Your Profile';

  @override
  String get worldoLaunchDone => 'Done';

  @override
  String get worldoLaunchSuggested => 'Suggested';

  @override
  String get worldoLaunchName => 'Name';

  @override
  String get worldoLaunchIdentity => 'Identity';

  @override
  String get worldoLaunchPersonality => 'Personality';

  @override
  String get worldoLaunchGoal => 'Goal';

  @override
  String get worldoLaunchSetupRole => 'Setup Your Role';

  @override
  String get worldoLaunchPreset => 'Preset';

  @override
  String get worldoLaunchCustom => 'Custom';

  @override
  String get worldoLaunchNoPresetRole => 'No preset role';

  @override
  String get worldoLaunchFilling => 'Filling...';

  @override
  String get worldoLaunchFillMyProfile => 'Fill from my profile';

  @override
  String get worldoLaunchLaunch => 'Launch';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName launched!';
  }

  @override
  String get worldoLaunchEnter => 'Enter';

  @override
  String get createAction => 'Create';

  @override
  String get createWorldoTitle => 'Create Worldo';

  @override
  String get createFailed => 'Create failed';

  @override
  String get createNotesRequired => 'Update notes are required to publish.';

  @override
  String get createActionInProgress => 'This action is already in progress.';

  @override
  String createCurrentVersion({required String version}) {
    return 'Current Version: $version';
  }

  @override
  String get createChecking => 'Checking...';

  @override
  String createSummaryName({required String name}) {
    return 'Worldo Name: $name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Worldo Brief: $brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return 'Cover Image: $status';
  }

  @override
  String get createNotUploaded => 'Not uploaded';

  @override
  String get createUploaded => 'Uploaded';

  @override
  String createSummarySettings({required String settings}) {
    return 'Worldo Settings: $settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Worldo Time: $time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Worldo Metric: $metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 characters';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters: $names',
      one: '1 character: $names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return 'Suggested: $name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · Region: $count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · Building: $count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · Room: $count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return 'Character dialogue: $count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return 'Narrator: $count';
  }

  @override
  String createSummaryImage({required int count}) {
    return 'Image: $count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return 'Delete $itemLabel?';
  }

  @override
  String get createItemHasContentDeleteAnyway =>
      'This item has content. Delete it anyway?';

  @override
  String get createImageUploadProgress => 'Image upload is in progress.';

  @override
  String get createBasicsBasics => 'Basics';

  @override
  String get createSaveInProgress => 'Saving is already in progress.';

  @override
  String get createRequiredBeforeSave =>
      'Complete all required fields before saving.';

  @override
  String get createOpeningOpening => 'Opening';

  @override
  String get createCharacterCharactersCreate =>
      'Characters: Please create at least one character.';

  @override
  String get createCharacterCharactersOnlyOne =>
      'Characters: Only one character can be recommended.';

  @override
  String get createBasicsBasicsWorldoName => 'Basics: Worldo Name is required.';

  @override
  String get createBasicsBasicsWorldoBrief =>
      'Basics: Worldo Brief is required.';

  @override
  String get createBasicsBasicsCoverImage => 'Basics: Cover Image is required.';

  @override
  String get createBasicsBasicsMetricMust =>
      'Basics: Metric must be valid JSON.';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return 'Characters #$characterIndex: Name is required.';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return 'Characters #$characterIndex: Identity is required.';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return 'Characters #$characterIndex: Personality is required.';
  }

  @override
  String get createCharacterCharactersLeast =>
      'Characters: At least one character is required.';

  @override
  String get createLocationLocationsCreate =>
      'Locations: Please create at least one location.';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return 'Locations #$locationIndex: Location Name is required.';
  }

  @override
  String get createOpeningOpeningSelect =>
      'Opening: Select a location and complete every dialogue item.';

  @override
  String get createOpeningOpeningSelected =>
      'Opening: The selected location is no longer available.';

  @override
  String get createOpeningCharacterOpening =>
      'Opening: A selected character is no longer available.';

  @override
  String get createOpeningOpeningDialogue =>
      'Opening: A dialogue character is not in the selected location. Open Opening to fix it.';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return 'Unsupported opening dialogue: $type';
  }

  @override
  String get createCreating => 'Creating...';

  @override
  String get createDiscard => 'Discard';

  @override
  String get createCharactersStep => 'Characters (>=1)';

  @override
  String get createLocationsStep => 'Locations (>=1)';

  @override
  String get createStoryEventsOptional => 'Story Events (Optional)';

  @override
  String get createUpdateNotesRequiredPublish =>
      'Update notes (required to publish)';

  @override
  String get createWhatChangedVersion => 'What changed in this version?';

  @override
  String get createView => 'View';

  @override
  String get createNotStartedYet => 'Not started yet';

  @override
  String get createEdited => 'Edited';

  @override
  String get createPublishingWorldo => 'Publishing your Worldo';

  @override
  String get createCreatingWorldo => 'Creating your Worldo';

  @override
  String get createPreparingWorldoUpdatesWait =>
      'Preparing your Worldo updates.\nPlease wait for a moment.';

  @override
  String get createBringingWorldoLifeWait =>
      'Bringing your Worldo to life.\nPlease wait for a moment.';

  @override
  String get createDescribeIssue => 'Describe the issue';

  @override
  String get createSubmit => 'Submit';

  @override
  String get createBasicsWorldoName => 'Worldo Name *';

  @override
  String get createBasicsNameRequired => 'Worldo Name is required.';

  @override
  String get createBasicsBriefRequired => 'Worldo Brief is required.';

  @override
  String get createBasicsCoverRequired => 'Cover Image is required.';

  @override
  String get createBasicsMetricInvalid => 'Metric must be valid JSON.';

  @override
  String get createBasicsEgMainStreet => 'eg. Main Street';

  @override
  String get createBasicsWorldoBrief => 'Worldo Brief *';

  @override
  String get createBasicsBriefNote =>
      'The public hook players see first — the setting, the core conflict, and what makes it intriguing.';

  @override
  String get createBasicsHiddenNote =>
      'The hidden rules and backstory that drive the story — agendas, mechanics, and secret limits.';

  @override
  String get createBasicsEgHalfShopsMain =>
      'eg. Half the shops on Main Street are boarded up. By Labor Day, the richest storefront owns the town.';

  @override
  String get createBasicsCoverImage => 'Cover Image *';

  @override
  String get createBasicsUpload => 'Upload';

  @override
  String get createBasicsUsedCardsDetailPages =>
      'Used for cards and detail pages. Recommend ~768×1024 px. Supported formats: JPG, PNG, WEBP.';

  @override
  String get createBasicsWorldoSettingsHidden =>
      'Worldo Settings - Hidden (Optional)';

  @override
  String get createBasicsEgBankerSecretly =>
      'eg. The banker secretly controls who gets loans; whoever overextends can be squeezed out.';

  @override
  String get createBasicsWorldoTimeOptional => 'Worldo Time (Optional)';

  @override
  String get createBasicsWorldoStartsStart =>
      'This worldo starts at {Start Time}; each time the user taps *progress*, the timeline moves forward by {Time per Progress}.';

  @override
  String get createBasicsStartTime => 'Start Time';

  @override
  String get createBasicsDateExample => 'eg. Day 1, 09:00 / 2026-01-01';

  @override
  String get createBasicsTimePerProgress => 'Time per Progress';

  @override
  String get createBasicsEg8Hours3Days => 'eg. 8 hours / 3 days';

  @override
  String get createBasicsWorldoMetricOptional => 'Worldo Metric (Optional)';

  @override
  String get createBasicsMetricLabel => 'Metric Label';

  @override
  String get createBasicsEgWealthGoalProgress => 'eg. Wealth / Goal Progress';

  @override
  String get createBasicsLabelNote => 'Label note';

  @override
  String get createBasicsDescribeWhatMetric =>
      'Describe what this metric measures';

  @override
  String get createBasicsUnit => 'Unit';

  @override
  String get createBasicsEgCoins => 'eg. coins / %';

  @override
  String get createBasicsRange => 'Value Range';

  @override
  String get createBasicsStarting => 'Starting';

  @override
  String get createBasicsDeltaMin => 'Delta Min';

  @override
  String get createBasicsDeltaMax => 'Delta Max';

  @override
  String get createBasicsSaving => 'Saving...';

  @override
  String get createBasicsAdvancedSettings => 'Advanced Settings (Optional)';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return 'Character $index';
  }

  @override
  String get createCharacterSuggest => 'Suggest';

  @override
  String get createCharacterAvatarOptional => 'AVATAR\n(Optional)';

  @override
  String get createCharacterName => 'Name *';

  @override
  String get createCharactersTitle => 'Characters';

  @override
  String createCharacterLimit({required int count}) {
    return 'You can add up to $count characters.';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return 'Character $index: Name is required.';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return 'Character $index: Identity is required.';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return 'Character $index: Personality is required.';
  }

  @override
  String get createCharacterMinOne => 'Please create at least one character.';

  @override
  String get createCharacterEnterName => 'Enter name...';

  @override
  String get createCharacterIdentity => 'Identity *';

  @override
  String get createCharacterEgHometownKidBack =>
      'eg. A hometown kid back for one real shot';

  @override
  String get createCharacterPersonality => 'Personality *';

  @override
  String get createCharacterEgUnderdog =>
      'eg. Underdog with goodwill but little capital';

  @override
  String get createCharacterGoalOptional => 'Goal (Optional)';

  @override
  String get createCharacterEgRichestOwner =>
      'eg. Be the richest owner on Main Street by Labor Day';

  @override
  String get createCharacterBackgroundHidden =>
      'Background - Hidden (Optional)';

  @override
  String get createCharacterEgLeftTownYears =>
      'eg. Left town years ago; returned to a boarded-up Main Street for one chance.';

  @override
  String get createCharacterAddCharacter => '+ Add Character';

  @override
  String get createLocationImageOptional => 'IMAGE\n(Optional)';

  @override
  String get createCharacterSelectAvailable =>
      'Select from available characters below';

  @override
  String get createCharacterInitialCharacters =>
      'Initial Characters (Optional)';

  @override
  String get createLocationStartingCharacters =>
      'The characters who start here when the worldo begins.';

  @override
  String get createCharacterAvailableSelect => 'Available to select';

  @override
  String get createCharacterNoCharactersYet =>
      'No characters yet. Create characters first, then choose where they start.';

  @override
  String get createCharacterNoCharacters =>
      'No characters available. All characters already have an initial location.';

  @override
  String get createLocationEveryL2L3Locations =>
      'All L2 and L3 locations inside it will be removed too.';

  @override
  String get createLocationEveryL3Locations =>
      'All L3 locations inside it will be removed too.';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return 'Delete \"$displayName\"';
  }

  @override
  String get createLocationOpeningLocation =>
      'This is the Opening location. Deleting it will also clear the Opening.';

  @override
  String get createLocationL1LocationRegion => 'L1 Location · Region *';

  @override
  String get createLocationL2LocationBuilding => 'L2 Location · Building *';

  @override
  String get createLocationAddL3Location => 'Add L3 Location';

  @override
  String get createLocationsTitle => 'Locations';

  @override
  String get createLocationStatisticsNote =>
      'Your world is built in 3 levels:\nL1 · Region     An area of your world — Downtown\nL2 · Building   A building inside it — Joe\'s Diner\nL3 · Room       A room inside that building — The Back Kitchen\nEvery location needs all three levels. Up to 15 rooms in total.';

  @override
  String get createLocationL1NameNote =>
      'An area of your world — a district, a town, a forest. Not a single building.';

  @override
  String get createLocationL2NameNote =>
      'A building inside this region — a shop, a school, an apartment block.';

  @override
  String get createLocationL3NameNote =>
      'A room inside the building. Rooftops, courtyards and entrances work too.';

  @override
  String get createLocationName => 'Name *';

  @override
  String get createLocationL1NameRequired => 'L1 location name is required.';

  @override
  String get createLocationL3NameRequired => 'L3 location name is required.';

  @override
  String get createLocationThisL1 => 'This L1 location';

  @override
  String get createLocationThisL2 => 'This L2 location';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel must contain at least one L2 location.';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel must contain at least one L3 location.';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel has an L2 location that needs a name.';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel has an L3 location that needs a name.';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return 'You can add up to $count L3 locations.';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return 'You\'ve used all $count rooms. Delete one to add another.';
  }

  @override
  String get createLocationAtLeastOneL1 =>
      'At least one L1 location is required.';

  @override
  String get createLocationAddL1 => 'Add at least one L1 location.';

  @override
  String get createLocationMinOne => 'Please create at least one location.';

  @override
  String get createLocationIdRequired => 'Every location must have an ID.';

  @override
  String get createLocationIdUnique => 'Every location must have a unique ID.';

  @override
  String get createLocationParentInvalid =>
      'Every location must have a valid parent.';

  @override
  String get createLocationFieldsRequired =>
      'Complete all required location fields before saving.';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Saving Locations will also delete $count Opening dialogue bubbles for the removed characters.',
      one:
          'Saving Locations will also delete 1 Opening dialogue bubble for the removed characters.',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => 'Edit L3 Location';

  @override
  String get createLocationPreview => 'Preview';

  @override
  String get createLocationCompleteLocation =>
      'Please complete this location or delete it.';

  @override
  String get createLocationRemoveCharacter => 'Remove character from location?';

  @override
  String get createLocationRemove => 'Remove';

  @override
  String get createLocationL1Location => 'L1 Location';

  @override
  String get createLocationL2Location => 'L2 Location';

  @override
  String get createLocationL3Location => 'L3 Location';

  @override
  String get createOpeningSelectLocation => 'Select Location';

  @override
  String get createOpeningNoSavedLocations => 'No saved locations';

  @override
  String get createOpeningSelect => 'Select';

  @override
  String get createOpeningSelectLocationFirst => 'Select a location first.';

  @override
  String get createOpeningNoInitialCharacter => 'No initial character';

  @override
  String get createOpeningLocationsLoading => 'Locations are still loading.';

  @override
  String get createOpeningLoadingLocations => 'Loading locations...';

  @override
  String get createOpeningSwitchingLocations =>
      'Switching locations will clear the dialogue content.';

  @override
  String get createOpeningContinue => 'Continue';

  @override
  String get createOpeningAdd10DialogueItems =>
      'You can add up to 10 dialogue items.';

  @override
  String get settingsUnableSaveSuggestedRole =>
      'Unable to save suggested role.';

  @override
  String get createOpeningUnableSaveOpening => 'Unable to save Opening.';

  @override
  String get createOpeningSelectInitial => 'Select initial location';

  @override
  String get createOpeningInitialLocationRequired =>
      'Select an initial location before saving.';

  @override
  String get createOpeningAddDialogueFirst =>
      'Add at least one dialogue item before saving.';

  @override
  String get createOpeningCompleteDialogue =>
      'Complete every dialogue item before saving.';

  @override
  String get createOpeningDialogue => 'Opening dialogue';

  @override
  String get createOpeningLocationRequired =>
      'Select a location first, then edit the dialogue.';

  @override
  String get createOpeningNarrator => 'Narrator';

  @override
  String get createOpeningImage => 'Image';

  @override
  String get createOpeningSuggestRoleUser => 'Suggest a role for user';

  @override
  String get createOpeningNoCharacters => 'No characters available.';

  @override
  String get createOpeningEnterNarrator => 'Enter narrator dialogue';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return 'Enter $name dialogue';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => 'UPLOAD IMAGE';

  @override
  String get createEventAddEvent => '+ Add Event';

  @override
  String get createStoryEventsTitle => 'Story Events';

  @override
  String createEventLimit({required int count}) {
    return 'You can add up to $count events.';
  }

  @override
  String createEventEventIndex({required String index}) {
    return 'Event $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      'eg. A national chain scouts a vacant lot, threatening to undercut every local on price.';

  @override
  String get createEventKeyStoryBeatAIUses =>
      'A key story beat the AI uses to steer the storyline.';

  @override
  String get imageCropUploadFailed => 'Upload failed';

  @override
  String get inboxNotifications => 'Notifications';

  @override
  String get inboxNoNotificationsYet => 'No notifications yet.';

  @override
  String get inboxFollowers => 'Followers';

  @override
  String get inboxNewFollowers => 'New followers';

  @override
  String get inboxNoNewFollowersYet => 'No new followers yet.';

  @override
  String get inboxComments => 'Comments';

  @override
  String get inboxNoCommentsYet => 'No comments yet.';

  @override
  String get inboxPrivateChats => 'Private Chats';

  @override
  String get inboxChatFriendsWorldo => 'Chat with your friends on Worldo.';

  @override
  String get inboxUnknownUser => 'Unknown user';

  @override
  String get inboxDirectMessage => 'Direct message';

  @override
  String get inboxJoinRequest => 'Join request';

  @override
  String get inboxApprove => 'Approve';

  @override
  String get inboxReject => 'Reject';

  @override
  String get inboxOk => 'OK';

  @override
  String get inboxReviewFailed => 'Review failed';

  @override
  String get inboxLoadMessagesFailed => 'Failed to load messages.';

  @override
  String get inboxNewMessage => 'New message';

  @override
  String get inboxSomeone => 'Someone';

  @override
  String get inboxWorld => 'this world';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name requested to join $world$suffix';
  }

  @override
  String get inboxCommentWorldo => ' commented on your worldo';

  @override
  String get inboxReply => ' replied to you';

  @override
  String get inboxLikeComment => ' liked your comment';

  @override
  String get inboxLikedComment => 'liked your comment';

  @override
  String get inboxComment2LikeComment => 'liked your comment';

  @override
  String get inboxReplied => 'replied to you';

  @override
  String get inboxYou2Reply => 'replied to you';

  @override
  String get inboxCommentedOrigin => 'commented on your origin';

  @override
  String get inboxCommentOrigin => 'commented on your origin';

  @override
  String get inboxSentMessage => ' sent you a message';

  @override
  String get inboxStartedFollowing => ' started following you.';

  @override
  String get meFailedOpenDiscord => 'Could not open Discord';

  @override
  String get meImagePickFailed => 'Image pick failed';

  @override
  String get meUpdateFailed => 'Update failed';

  @override
  String get mePlaying => 'Playing';

  @override
  String get meEditName => 'Edit name';

  @override
  String get meSignUpReward => 'Sign up and get 250 Gems!';

  @override
  String get loginSignUpReward => 'Sign up and get 250 Gems!';

  @override
  String get meUnknown => 'Unknown';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID: $oid\nLatest Version: $version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID: $displayWid\nOwner: $owner';
  }

  @override
  String get meFollows => 'Follows';

  @override
  String meFollowingCount({required String followingCount}) {
    return '$followingCount Following';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount Followers';
  }

  @override
  String get meNoFollowingYet => 'No following yet.';

  @override
  String get meNoFollowersYet => 'No followers yet.';

  @override
  String get meBlockFailed => 'Block failed. Please try again.';

  @override
  String get meUserBlockedContentHasReported =>
      'User blocked. This content has been reported to Worldo team.';

  @override
  String get meBlockUser => 'Block this user?';

  @override
  String get meBlock => 'Block';

  @override
  String get meUnblockFailed => 'Unblock failed. Please try again.';

  @override
  String get meUnblock => 'Unblock';

  @override
  String get meFollowing => 'Following';

  @override
  String get meFollow => 'Follow';

  @override
  String get meMessage => 'Message';

  @override
  String meUID({required String uid}) {
    return 'UID: $uid';
  }

  @override
  String get meNoWorldoCreatedYet => 'No Worldo you created yet.';

  @override
  String get meNoWorldoYet => 'No Worldo yet.';

  @override
  String get meNoWorldsCreatedYet => 'No Worlds you created yet.';

  @override
  String get meNoWorldsYet => 'No Worlds yet.';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => 'Red gems';

  @override
  String get gemsPink => 'Pink gems';

  @override
  String get gemsTop => 'Top up';

  @override
  String get gemsBuy => 'Buy Gems';

  @override
  String get gemsRecords => 'Records';

  @override
  String get gemsUnableLoad => 'Unable to load gems.';

  @override
  String get settingsLogOutAccount => 'Log out of your account?';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String get settings => 'Settings';

  @override
  String get settingsAboutUs => 'About us';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsBlockedUsers => 'Blocked users';

  @override
  String get settingsJoinDiscord => 'Join Discord';

  @override
  String get meUserUnblocked => 'User unblocked';

  @override
  String get meNoBlockedUsersYet => 'No blocked users yet.';

  @override
  String get settingsAgreeTermsContinue => 'Agree to our terms to continue.';

  @override
  String get settingsDeleteAccount => 'Delete your account?';

  @override
  String get settingsAccountDeletionAgreement => 'Account Deletion Agreement';

  @override
  String get settingsEnsureSecurityAccount =>
      'To ensure the security of your account, please read about the consequences of account deletion.\n\nAccount deletion is not the same as logging out, and once canceled, it cannot be undone. Your private data, including created characters, search history, chat logs with any characters, your favorites, your memories, interaction data, and order records, will be irreversibly deleted and cannot be recovered upon account deletion.';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      'All unused Gems, including purchased and earned Gems, will be permanently lost. By continuing, you voluntarily waive them, and account deletion does not automatically entitle you to a refund.\n\nAll remaining membership benefits will also be permanently lost and cannot be restored. Deleting your account does not cancel your subscription.';

  @override
  String get settingsIHaveReadAccountDeletion =>
      'I have read the Account Deletion Agreement';

  @override
  String get settingsCurrentLoginAccount => 'Current login account:';

  @override
  String get profileSaveFailed =>
      'Could not save your profile. Please try again.';

  @override
  String get meSignInFailed => 'Sign-in failed. Please try again.';

  @override
  String get meCompleteProfileContinue => 'Complete your profile to continue.';

  @override
  String get meSelectGenderAge => 'Please select your gender and age.';

  @override
  String get meSelectGender => 'Please select your gender.';

  @override
  String get meSelectAge => 'Please select your age.';

  @override
  String get meRequired => 'Required';

  @override
  String get mePersonalizeWorldoExperience =>
      'Personalize Your Worldo Experience';

  @override
  String get meSignIn => 'Sign in';

  @override
  String get meBack => 'Back';

  @override
  String get meSkip => 'Skip';

  @override
  String get meContinueGoogle => 'Continue with Google';

  @override
  String get meContinueApple => 'Continue with Apple';

  @override
  String get meSignUpClaimPremium => 'Sign up to claim Premium';

  @override
  String get meSignUpContinue => 'Sign up to continue';

  @override
  String get meAccountLoggedAnotherDevice =>
      'Your account is logged in on another device.';

  @override
  String get premiumSubscription => 'Subscription';

  @override
  String get gemsClaimFailed => 'Claim failed.';

  @override
  String get gemsCheckFailed => 'Check in failed.';

  @override
  String get gemsFollowFailed => 'Follow failed.';

  @override
  String get gemsTaskUpdateFailed => 'Task update failed.';

  @override
  String get gemsClaimSuccessful => 'Claim successful!';

  @override
  String get gemsUnableLoadGemPacks => 'Unable to load gem packs.';

  @override
  String get gemsNoGemPacksAvailable => 'No gem packs available.';

  @override
  String get gemsUnableLoadGemTasks => 'Unable to load gem tasks.';

  @override
  String get gemsJoinUs => 'join us';

  @override
  String get gemsClaim => 'Claim';

  @override
  String get gemsClaimed => 'Claimed';

  @override
  String get meDailyCheck => 'Daily Check-in';

  @override
  String get gemsDailyCheckInReward => 'Get 100';

  @override
  String get meCheck => 'Check in';

  @override
  String get meCheckSuccessful => 'Check in successful!';

  @override
  String get meGooglePlayUnavailable => 'Google Play is unavailable.';

  @override
  String get mePurchaseFailed => 'Purchase failed.';

  @override
  String get gemsEarned => 'Earned';

  @override
  String get gemsSpent => 'Spent';

  @override
  String get gemsPurchase => 'Purchase';

  @override
  String get gemsGemRecords => 'Gem Records';

  @override
  String get gemsUnableLoadRecords => 'Unable to load records.';

  @override
  String get gemsNoGemRecordsYet => 'No gem records yet.';

  @override
  String get meAbout => 'About';

  @override
  String get meEmailCopied => 'Email copied';

  @override
  String get mePurchasingPremium => 'Purchasing Premium';

  @override
  String get mePurchaseSuccessful => 'Purchase successful!';

  @override
  String get meWorldoPremiumSubscription =>
      'Your Worldo Premium subscription is now active.';

  @override
  String get meMyBalance => 'My Balance';

  @override
  String get meSoldOut => 'Sold Out';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession =>
      'Complete user session is required for model list';

  @override
  String get memoryModelListPermissionDenied =>
      'Model list permission denied for this World';

  @override
  String get memorySaveFailed => 'Save failed';

  @override
  String get memorySaveResultNotConfirmed => 'Save result not confirmed';

  @override
  String get memoryChooseModel => 'Choose model';

  @override
  String get memoryMaxTokenLimit => 'Max memory token limit';

  @override
  String get memoryNoModelsAvailable => 'No models available';

  @override
  String get memoryRetryRanges => 'Retry ranges';

  @override
  String get memoryCurrentUsage => 'Your current memory usage';

  @override
  String memoryMinGems({required String min}) {
    return '$min gems';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min–$max gems';
  }

  @override
  String memoryStart({required String memoryStart}) {
    return 'memory $memoryStart';
  }

  @override
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  }) {
    return 'memory $memoryStart → $memoryEnd';
  }

  @override
  String get memorySettingsUnavailable => 'Memory settings unavailable';

  @override
  String get premiumGooglePlayTookTooLong =>
      'Google Play took too long to respond. Please try again.';

  @override
  String get premiumSubscriptionsNotSupported =>
      'Subscriptions are not supported by Google Play on this device.';

  @override
  String get premiumConnectionGooglePlayLost =>
      'The connection to Google Play was lost. Please try again.';

  @override
  String get premiumPurchaseCanceled => 'Purchase canceled.';

  @override
  String get premiumGooglePlayTemporarily =>
      'Google Play is temporarily unavailable. Please try again later.';

  @override
  String get premiumGooglePlayBilling =>
      'Google Play billing is unavailable. Please check your Play account and payment settings.';

  @override
  String get premiumSubscriptionUnavailable =>
      'This Premium subscription is currently unavailable on Google Play.';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play could not complete this Premium purchase. Please try again.';

  @override
  String get premiumAlreadyOwnSubscription =>
      'You already own this subscription on Google Play.';

  @override
  String get premiumGooglePlayFailedFind =>
      'Google Play could not find the subscription to change. Please check Manage subscriptions.';

  @override
  String get premiumFailedConnectGooglePlay =>
      'Could not connect to Google Play. Please check your internet connection and try again.';

  @override
  String get premiumInsufficientFunds =>
      'Your payment method has insufficient funds. Please update it in Google Play and try again.';

  @override
  String get premiumGoogleAccountIneligible =>
      'Your Google Play account is not eligible for this subscription offer.';

  @override
  String get premiumAppStoreFailedComplete =>
      'The App Store could not complete this Premium purchase. Please try again.';

  @override
  String get premiumFailedConnectAppStore =>
      'Could not connect to the App Store. Please check your internet connection and try again.';

  @override
  String get premiumAppStoreTookTooLong =>
      'The App Store took too long to respond. Please try again.';

  @override
  String get premiumAppStoreEncounteredSystem =>
      'The App Store encountered a system error. Please try again later.';

  @override
  String get premiumRegionUnavailable =>
      'This Premium subscription is not available in your App Store region.';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      'This app cannot make this App Store request. Please contact support.';

  @override
  String get premiumPurchaseNotSupported =>
      'This purchase is not supported on this device or system version.';

  @override
  String get premiumAppStorePurchaseWindow =>
      'The App Store purchase window could not open. Please return to the app and try again.';

  @override
  String get premiumAppStoreFailedAccept =>
      'The App Store could not accept this purchase quantity. Please contact support.';

  @override
  String get premiumAppStoreUnavailable =>
      'This Premium subscription is currently unavailable on the App Store.';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      'Purchases are not allowed on this device. Please check your Apple Account and purchase restrictions.';

  @override
  String get premiumAppleAccountNotEligible =>
      'Your Apple Account is not eligible for this subscription offer.';

  @override
  String get premiumSubscriptionOffer =>
      'This subscription offer is unavailable. Please refresh the page and try again.';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'The App Store could not accept this offer price. Please refresh the page and try again.';

  @override
  String get premiumAppStoreFailedVerify =>
      'The App Store could not verify this subscription offer. Please contact support.';

  @override
  String get premiumSubscriptionOfferFailed =>
      'This subscription offer could not be prepared. Please refresh the page and try again.';

  @override
  String get premiumAddPaymentMethodApple =>
      'Please add a payment method to your Apple Account, then try again.';

  @override
  String get premiumAppCannotMakePurchases =>
      'This app cannot make purchases on the App Store. Please contact support.';

  @override
  String get premiumAppStoreRequestRejected =>
      'The App Store could not accept this purchase request. Please try again or contact support.';

  @override
  String get premiumAppleCloudServiceAccess =>
      'Apple cloud service access was denied. Please check your Apple Account permissions.';

  @override
  String get premiumFailedConnectApple =>
      'Could not connect to Apple services. Please check your internet connection and try again.';

  @override
  String get premiumAccess2AppleCloudService =>
      'Apple cloud service access was revoked. Please check your Apple Account settings.';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      'Please accept the latest Apple privacy terms in your Apple Account, then try again.';

  @override
  String get premiumAppStoreWindowFailed =>
      'The App Store window could not be configured. Please contact support.';

  @override
  String get premiumAppStoreWindowTookTooLong =>
      'The App Store window took too long to open. Please try again.';

  @override
  String get premiumReturnAppTryPurchase =>
      'Please return to the app and try your purchase again.';

  @override
  String get premiumGooglePlayUnavailable =>
      'Google Play is unavailable. Please check that it is installed and you are signed in.';

  @override
  String get premiumIs4Subscription =>
      'This Premium subscription is currently unavailable in the store. Please refresh the page and try again.';

  @override
  String get premiumSubscriptionFailed =>
      'This Premium subscription could not be prepared. Please refresh the page and try again.';

  @override
  String get premiumStoreFailedOpenPurchase =>
      'The store could not open this Premium purchase. Please try again.';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'The original subscription was not found in Google Play. Please check Manage subscriptions.';

  @override
  String get premiumSubscriptionUsesDifferent =>
      'This subscription uses a different purchase identity. Please refresh the page or contact support.';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play cannot change this subscription yet. Please check Manage subscriptions.';

  @override
  String get premiumPlanChangePending =>
      'An App Store purchase for this plan is still being processed. Please wait for it to finish.';

  @override
  String get premiumFailedLoadPlansAppStore =>
      'Could not load Premium plans from the App Store. Please try again.';

  @override
  String get premiumPurchasePreparation =>
      'Purchase preparation expired. Please try again.';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'The App Store returned an unknown purchase result. Please check your subscription before trying again.';

  @override
  String get premiumPurchasesUnavailable =>
      'Purchases are currently unavailable.';

  @override
  String get premiumAutoRenewsCancelAnytime => 'Auto-renews. Cancel anytime.';

  @override
  String get premiumSubscribed => 'Subscribed';

  @override
  String get premiumAlsoIncluded => 'Also included';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => 'Pink Gems';

  @override
  String get premiumRedGems => 'Red Gems';

  @override
  String get premiumExtraDailyCheck => 'Extra, daily check-in';

  @override
  String get premiumDailyCheck => 'Daily check-in';

  @override
  String get premiumClaimedMonthly => 'Claimed monthly';

  @override
  String get premiumBilledMonthly => 'Billed monthly';

  @override
  String premiumSaveSavings({required String savings}) {
    return 'Save $savings%';
  }

  @override
  String get premiumSubscribe => 'Subscribe';

  @override
  String get premiumActiveYearlySubscription =>
      'An active yearly Premium subscription cannot be changed to a monthly plan.';

  @override
  String get premiumAlreadyHaveActive =>
      'You already have an active Premium subscription.';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return 'You’re already subscribed to Premium $label.';
  }

  @override
  String get premiumPreviousPurchasePending =>
      'Your previous Premium purchase is still being confirmed.';

  @override
  String get premiumUseOriginalStoreUpgrade =>
      'Please use the original store to upgrade your Premium subscription.';

  @override
  String get premiumResolveCurrent =>
      'Please resolve your current subscription in the store before purchasing.';

  @override
  String get premiumPurchaseUnavailable =>
      'Premium purchase is currently unavailable.';

  @override
  String get premiumUnableVerifyPurchase =>
      'Unable to verify purchase eligibility. Please try again.';

  @override
  String get premiumStoreFailedVerifyPurchase =>
      'The store could not verify this Premium purchase.';

  @override
  String get premiumPurchaseDoesNotMatch =>
      'The Premium purchase does not match the selected plan.';

  @override
  String get premiumMessagePurchaseCanceled =>
      'This Premium purchase was canceled.';

  @override
  String get premiumPurchaseRevoked => 'This Premium purchase was revoked.';

  @override
  String get premiumNotification => 'Notification';

  @override
  String get premiumWorldoActiveSubscription =>
      'Worldo Premium is active in your subscription and does not support downgrades.';

  @override
  String get premiumGot => 'Got It';

  @override
  String get gemBalancePromptInsufficientGems => 'Insufficient Gems';

  @override
  String get gemBalancePromptLowGems => 'Low Gems';

  @override
  String get appPressBackExit => 'Press back again to exit.';

  @override
  String get appReportSubmitted => 'Report submitted';

  @override
  String get appReportFailed => 'Report failed';

  @override
  String get appUpdateRequired => 'Update required';

  @override
  String get appUpdateContent =>
      'Please update to the latest version to continue using Worldo.';

  @override
  String appUpdateVersion({required String versionName}) {
    return 'Version $versionName';
  }

  @override
  String get appUpdateCheckFailed =>
      'Unable to refresh update status. Please update to continue.';

  @override
  String get appUpdate => 'Update now';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '$normalizedLabel copied';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get commonImageLoadFailed => 'Image load failed';

  @override
  String get commonPageNotFound => 'Page not found.';

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
    return 'LLM is generating your first tick. This may take a moment$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return 'Latest Version: V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return 'Please save $missingSections before creating.';
  }

  @override
  String get createCharacterRoleHint => 'The character\'s role in the worldo.';

  @override
  String get createCharacterMannerHint =>
      'The character\'s manner of speaking and behaving, which drives their dialogue.';

  @override
  String get createCharacterGoalHint =>
      'The character\'s goal or behavioral direction, which drives how they act.';

  @override
  String get createCharacterBackgroundHint =>
      'The character\'s background and relationships.';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return 'request to $world$worldIdSuffix';
  }

  @override
  String get memoryModel => 'Memory & Model';

  @override
  String get premiumAccountMismatch =>
      'Account identifiers don\'t match the previous subscription.';

  @override
  String get worldRecap => 'Recap';

  @override
  String get inboxMissingJoinRequestId => 'Missing join request ID';

  @override
  String get loginTimedOut => 'Sign-in timed out. Please try again.';

  @override
  String get loginConnectionFailed =>
      'Unable to connect. Check your internet connection and try again.';

  @override
  String get loginTemporarilyUnavailable =>
      'Sign-in is temporarily unavailable. Please try again later.';

  @override
  String get recapUnlockHeading => 'Unlocks Recap';

  @override
  String get recapUpsellDescription =>
      'Catch up on your story with a full recap of every twist, choice, and character along the way.';

  @override
  String get recapShowEarlier => 'Show earlier recap';

  @override
  String get recapEmpty =>
      'Story recap will appear here as the story moves forward.';

  @override
  String get chatMessageAsNarrator => 'Message as the Narrator';

  @override
  String chatMessageAsCharacter({required String name}) {
    return 'Message as $name';
  }

  @override
  String get chatNarratorSpeaker => 'the Narrator';

  @override
  String get chatYourCharacterSpeaker => 'your character';

  @override
  String chatSpeakingAs({required String speaker}) {
    return 'Speaking as $speaker';
  }

  @override
  String get chatSwitchCharacter => 'Switch to character';

  @override
  String get chatSwitchNarration => 'Switch to narration';

  @override
  String chatOpenLocation({required String locationName}) {
    return 'Open $locationName';
  }

  @override
  String get chatRetryMessage => 'Retry message';

  @override
  String get blockedReportFailed => 'User blocked, but reporting failed.';

  @override
  String get storeConnectionFailed =>
      'Unable to connect to the store. Please try again.';

  @override
  String get storeProductUnavailable =>
      'This product is currently unavailable.';

  @override
  String get storeDevicePurchasesUnavailable =>
      'Purchases are unavailable on this device.';

  @override
  String get worldHistoryRequestFailed => 'World History request failed';

  @override
  String get genericError => 'Something went wrong';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': '$plan Premium, $price per year',
      'other': '$plan Premium, $price per month',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => 'Clear failed';

  @override
  String get developerGatewaySignatureFailed =>
      'Gateway signature verification failed';

  @override
  String get developerEndpointsSaved => 'Saved. New requests use endpoints.';

  @override
  String get developerAdjustRestartRequired =>
      'Restart app to apply Adjust environment.';

  @override
  String developerRecapSetting({required String mode}) {
    return 'World recap: $mode';
  }

  @override
  String get developerRecapPreview => 'World recap preview';

  @override
  String get developerRecapPreviewDescription =>
      'Stands in for membership and recap content on the World sheet. Resets when the app restarts.';

  @override
  String get developerResetFailed => 'Reset failed';

  @override
  String get developerRecapOff => 'Off (follows membership)';

  @override
  String get developerRecapLocked => 'Locked · non-member';

  @override
  String get developerRecapEmpty => 'Member · not generated yet';

  @override
  String get developerRecapSample => 'Member · sample recap';

  @override
  String get developerRecapLive => 'Member · live recap';

  @override
  String get chatEditFreeUsesExhausted => 'No free edits remaining.';

  @override
  String developerMembershipSetting({required String selection}) {
    return 'Membership: $selection';
  }

  @override
  String get developerMembershipDescription =>
      'Temporarily overrides this account’s membership on every screen. The server still uses the real account status. Resets when the app restarts.';

  @override
  String get developerMembershipOff => 'Off (real membership)';

  @override
  String get developerMembershipYearly => 'Premium · yearly';

  @override
  String get developerMembershipMonthly => 'Premium · monthly';

  @override
  String get developerMembershipNone => 'Non-member';

  @override
  String get originStartBySelectingRole => 'Start by selecting your role';

  @override
  String get originRecommendedStart => 'Recommended start';

  @override
  String get originStoryOpening => 'Story Opening';

  @override
  String get originOpeningLocation => 'Opening location';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names are now at\n$locationName',
      one: '$names is now at\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return 'Story Opening\n$locationName';
  }

  @override
  String get chatHistoryExpand => 'Expand';

  @override
  String get chatHistoryCollapse => 'Collapse';

  @override
  String get worldHistory => 'History';

  @override
  String get worldHistoryEmpty => 'Your World’s chat history will appear here.';

  @override
  String get worldHistoryContinueHere => 'Continue here';

  @override
  String get chatCharacterMovement => 'Character movement';

  @override
  String get miniPhoneCreatePost => 'Create post';

  @override
  String get miniPhoneCreate => 'Create';

  @override
  String get miniPhonePostHint => 'What’s on your mind?';

  @override
  String get miniPhonePhotoOptional => 'Photo (Optional)';

  @override
  String get miniPhoneChoosePhoto => 'Choose photo';

  @override
  String get miniPhoneReplacePhoto => 'Replace photo';

  @override
  String get miniPhoneRemovePhoto => 'Remove photo';

  @override
  String get miniPhonePublish => 'Post';

  @override
  String get miniPhoneViewAllComments => 'View all comments';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get imageGifUnsupported => '不支援 GIF 動畫。';

  @override
  String get worldProgressComplete => '推進完成';

  @override
  String a11ySwitchMode({required String label}) {
    return '切換至$label模式';
  }

  @override
  String a11yEditItem({required String title}) {
    return '編輯$title';
  }

  @override
  String a11yRoleCards({required int index, required int count}) {
    return '角色卡片，第 $index 張，共 $count 張';
  }

  @override
  String a11yEditInspiration({required int index}) {
    return '編輯第 $index 個靈感';
  }

  @override
  String a11yInsert({required String label}) {
    return '插入$label';
  }

  @override
  String get a11yMembership => '會員';

  @override
  String get a11yOpenWorldo => '開啟 Worldo';

  @override
  String get a11yFilterGender => '依性別篩選';

  @override
  String get a11ySelectRole => '選擇你的角色';

  @override
  String get a11yLoadingMap => '正在載入地圖';

  @override
  String get a11yBuildingWorld => '正在建立世界';

  @override
  String get a11yPremiumMembership => 'Premium 會員';

  @override
  String get a11yProMembership => 'Pro 會員';

  @override
  String get a11yRecommendedRole => '推薦角色';

  @override
  String get a11yLastMessage => '最新訊息';

  @override
  String get a11yRecentChat => '最近的聊天';

  @override
  String get a11yAiReplyLoading => '正在產生 AI 回覆';

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
      other: '$amount 位玩家',
    );
    return '$_temp0';
  }

  @override
  String createAddedMax({required int added, required int max}) {
    return '$added/$max（已新增／上限）';
  }

  @override
  String get createSixHours => '6 小時';

  @override
  String get createTwelveHours => '12 小時';

  @override
  String get createOneDay => '1 天';

  @override
  String get createOneWeek => '1 週';

  @override
  String get settingsLanguage => '語言';

  @override
  String get languageChangeFailed => '無法切換語言，請再試一次。';

  @override
  String get purchasingGems => '正在購買寶石';

  @override
  String get purchaseSuccessful => '購買成功！';

  @override
  String get okAction => '確定';

  @override
  String get cancelAction => '取消';

  @override
  String get requestAction => '申請';

  @override
  String get requestedStatus => '已申請';

  @override
  String get launchAction => '啟動世界';

  @override
  String get tickNowAction => '立即 Tick';

  @override
  String get writePostHint => '撰寫貼文';

  @override
  String get newPostTitle => '新增貼文';

  @override
  String get aiIsGenerating => 'AI 正在生成';

  @override
  String get generatingCustomizedWorldWait => '正在為你生成專屬的世界。\n請稍候。';

  @override
  String get approvedStatus => '已核准';

  @override
  String get rejectedStatus => '已拒絕';

  @override
  String get awaitingApprovalStatus => '等待審核中';

  @override
  String get awaitingYourApprovalStatus => '等待你審核';

  @override
  String get liveYourWorld => '活出你的世界';

  @override
  String get signedOutMeDescription => '暢玩世界、創作 worldo、邀請朋友，\n隨時隨地延續你的故事。';

  @override
  String get gemTaskLaunchWorldHint => '開啟你喜歡的 Worldo，再啟動自己的世界。';

  @override
  String get gemTaskInviteFriendHint => '開啟一個世界，然後在詳細資料面板點選「邀請」。';

  @override
  String get gemTaskWriteCommentHint => '開啟你喜歡的 Worldo，然後在討論區發表貼文。';

  @override
  String get gemTaskRequestJoinHint => '開啟一個你尚未加入的世界，然後申請加入。';

  @override
  String get gemTaskSendMessageHint => '在你的世界中傳送訊息。';

  @override
  String get gemTaskProgressWorldHint => '開啟你正在遊玩的世界，然後點選「立即 Tick」。';

  @override
  String get termsOfService => '服務條款';

  @override
  String get worldoLabel => 'Worldo';

  @override
  String get worldoHashtagLabel => '#Worldo';

  @override
  String get worldLabel => '世界';

  @override
  String get userLabel => '使用者';

  @override
  String get meLabel => '我';

  @override
  String get locationLabel => '地點';

  @override
  String get allLabel => '全部';

  @override
  String get maleLabel => '男性';

  @override
  String get femaleLabel => '女性';

  @override
  String get nonBinaryLabel => '非二元性別';

  @override
  String get forYouLabel => '為你推薦';

  @override
  String get userBlocked => '已封鎖使用者';

  @override
  String get purchaseCanceled => '已取消購買。';

  @override
  String get purchasePending => '你的購買交易正在處理中。';

  @override
  String get purchaseConfirmationDelayed => '購買交易確認延遲，請稍後再查看。';

  @override
  String get purchaseFailed => '購買失敗。';

  @override
  String get yearlyPlan => '年繳';

  @override
  String get monthlyPlan => '月繳';

  @override
  String get proSubscriptionTagline => '深入探索你遊玩的每個 Worldo。';

  @override
  String get eulaShort => 'EULA';

  @override
  String billedAnnually({required String price}) {
    return '$price，每年收費';
  }

  @override
  String expiresOn({required String date}) {
    return '$date 到期';
  }

  @override
  String get activeStatus => '使用中';

  @override
  String get expiredStatus => '已到期';

  @override
  String updatedAt({required String timestamp}) {
    return '更新時間：$timestamp';
  }

  @override
  String get tickLabel => 'Tick';

  @override
  String tickNumber({required String tick, required String suffix}) {
    return 'Tick $tick$suffix';
  }

  @override
  String get loadFailedRetry => '載入失敗，請重試';

  @override
  String get loadMoreAction => '載入更多';

  @override
  String get gemPurchaseRecord => '購買寶石';

  @override
  String get taskRewardRecord => '任務獎勵';

  @override
  String get worldProgressRecord => '世界進度';

  @override
  String get directMessageRecord => '私訊';

  @override
  String get gemRecord => '寶石紀錄';

  @override
  String get runATickTask => '執行一次 Tick';

  @override
  String get runATickTaskDescription => '開啟一個你正在遊玩的世界，然後點選「立即 Tick」。';

  @override
  String get someoneFallback => '某人';

  @override
  String get aCharacterFallback => '某個角色';

  @override
  String get thisWorld => '這個世界';

  @override
  String get noWorldEventsYet => '目前還沒有世界事件。';

  @override
  String get globalLabel => '全域';

  @override
  String get eventLabel => '事件';

  @override
  String get characterDestinations => '角色目的地';

  @override
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  }) {
    return '$characterName$direction$locationName';
  }

  @override
  String get cameToDirection => '來到';

  @override
  String get wentToDirection => '前往';

  @override
  String get hasComeToDirection => '已來到';

  @override
  String get hasGoneToDirection => '已前往';

  @override
  String get waitForReplyToSendMore => '等待對方回覆後才能傳送更多訊息';

  @override
  String newMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則新訊息',
      one: '1 則新訊息',
    );
    return '$_temp0';
  }

  @override
  String get selectPresetRoleValidation => '請選擇預設角色';

  @override
  String get enterNameValidation => '請輸入名稱';

  @override
  String get enterIdentityValidation => '請輸入身分';

  @override
  String get waitForProfileLoading => '請等待個人檔案載入完成。';

  @override
  String get imageUploadFailed => '圖片上傳失敗。';

  @override
  String get photoAccessDenied => '無法存取照片';

  @override
  String get feedbackSubmitted => '意見回饋已送出';

  @override
  String get feedbackFailed => '意見回饋送出失敗';

  @override
  String get worldoDetailUnavailable => '無法取得 Worldo 詳細資料。';

  @override
  String get publishAction => '發布';

  @override
  String get publishingStatus => '發布中…';

  @override
  String get publishFailed => '發布失敗';

  @override
  String get publishChangesBeforeLeaving => '離開前要發布變更嗎？';

  @override
  String get noChangesToPublish => '沒有可發布的變更。';

  @override
  String get completeOpeningRequiredToPublish => '必須完成開場內容才能發布';

  @override
  String get publishResponseMissingOriginId => '發布後未取得 Worldo ID。';

  @override
  String get worldoIdRequired => '必須提供 Worldo ID。';

  @override
  String loadFailedWithReason({required String reason}) {
    return '載入失敗：$reason';
  }

  @override
  String get imageSelectionFailed => '選取圖片失敗';

  @override
  String profileOriginSubtitle({required String oid, required String version}) {
    return 'OID：$oid\n最新版本：$version';
  }

  @override
  String profileWorldSubtitle({required String wid, required String owner}) {
    return 'WID：$wid\n擁有者：$owner';
  }

  @override
  String get sendFailed => '傳送失敗';

  @override
  String get selectARole => '選擇角色';

  @override
  String get timeLabel => '時間';

  @override
  String discussOriginSummary({required String oid}) {
    return 'OID：$oid';
  }

  @override
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  }) {
    return 'OID：$oid · 創作者：$creator';
  }

  @override
  String get worldoMetricExplanation =>
      '這個 worldo 每次推進時都會更新各角色的「{指標名稱}」，並以「{單位}」顯示。每個角色的起始值為「{起始值}」，數值可在「{最小變動值}」至「{最大變動值}」之間變動。';

  @override
  String homeMyWorldsEmptyTitle({required String worldo}) {
    return '啟動一個 $worldo，打造\n屬於你的世界';
  }

  @override
  String memoryEstimatedNextMessageCost({required String cost}) {
    return '下一則訊息預估花費 $cost';
  }

  @override
  String gemsAmount({required String amount}) {
    return '$amount 顆寶石';
  }

  @override
  String worldDeleteConfirmation({required String worldName}) {
    return '刪除世界 $worldName';
  }

  @override
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  }) {
    return '$playerUsername 扮演 $characterName';
  }

  @override
  String worldoLaunched({required String worldName}) {
    return 'Worldo $worldName 已啟動！';
  }

  @override
  String worldoCreated({required String worldName}) {
    return 'Worldo $worldName 已建立！';
  }

  @override
  String worldoPublished({required String worldName}) {
    return 'Worldo $worldName 已發布！';
  }

  @override
  String get createTimeout => '建立 Worldo 逾時。';

  @override
  String get publishTimeout => '發布 Worldo 逾時';

  @override
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  }) {
    return '你申請加入 $worldName$worldId';
  }

  @override
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  }) {
    return '$requesterName$requesterBadge 申請加入 $worldName$worldId';
  }

  @override
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge 在你的 worldo 留言';
  }

  @override
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge 回覆了你';
  }

  @override
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge 對你的留言按讚';
  }

  @override
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  }) {
    return '$senderName$senderBadge 傳送了一則訊息給你';
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
    return '剩餘免費靈感次數：$remaining\n$action';
  }

  @override
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  }) {
    return '剩餘免費編輯次數：$remaining\n$action';
  }

  @override
  String get getMoreAction => '取得更多 >';

  @override
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  }) {
    return '$characterName 來到 $locationName';
  }

  @override
  String aboutDescription({required String contactEmail}) {
    return 'Worldo 讓你建立、探索並進入由 AI 驅動的世界，與角色、故事和不斷演變的事件互動。你可以與 AI 角色聊天、和朋友一起遊玩，透過沉浸式場景與選擇推進每個世界。\n\n我們提供一種體驗互動故事的新方式：你不只是讀者，更是世界中的一員。如有任何問題，請透過 $contactEmail 與我們聯絡。';
  }

  @override
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  }) {
    return '$privacyPolicy、$termsOfUse及$endUserLicenseAgreement';
  }

  @override
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  }) {
    return '繼續即表示你同意我們的$terms、$privacyPolicy及$endUserLicenseAgreement';
  }

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get terms => '條款';

  @override
  String get termsOfUse => '使用條款';

  @override
  String get endUserLicenseAgreement => '終端使用者授權合約';

  @override
  String existingAccountSignIn({required String signIn}) {
    return '已有帳號？$signIn';
  }

  @override
  String get signInAction => '登入。';

  @override
  String gemsGranted({required String gemIcon, required String grantedAmount}) {
    return '已發放 $gemIcon$grantedAmount 顆寶石。';
  }

  @override
  String premiumMonthlyOffer({required String amount}) {
    return '每月最多可獲得 $amount 顆寶石，並享有完整 Premium 權益。';
  }

  @override
  String gemsPerDay({required String amount}) {
    return '$amount／天';
  }

  @override
  String monthlyPrice({required String price}) {
    return '$price／月';
  }

  @override
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  }) {
    return '$authorName$authorBadge：回覆 $replyToName$replyToBadge：$content';
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
  String get homeLoadFailed => '載入失敗';

  @override
  String get homeRetry => '重試';

  @override
  String get homeEmptyDescription => 'Worldo 是藍圖。啟動後，你就能進入親手打造的世界，並讓它持續發展。';

  @override
  String get homeWorldCharacter => '角色';

  @override
  String get homeWorldSingleOtherPlayer => '· 另有 1 位玩家';

  @override
  String homeWorldOtherPlayers({required String otherPlayerCount}) {
    return '· 另有 $otherPlayerCount 位玩家';
  }

  @override
  String get homeSignInUnavailable => '目前無法登入';

  @override
  String get homeSignedOutTitle => '你的世界，都在這裡';

  @override
  String get homeSignedOutDescription => '登入即可建立世界，繼續你的故事。';

  @override
  String get searchUID => 'UID：';

  @override
  String get searchOID => 'OID：';

  @override
  String get searchWID => 'WID：';

  @override
  String searchOwner({required String owner}) {
    return '擁有者：$owner';
  }

  @override
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  }) {
    return 'OID：$oid  創作者：$originator\n簡介：$brief\n最新版本：$version';
  }

  @override
  String searchWIDOwner({required String wid, required String owner}) {
    return 'WID：$wid\n擁有者：$owner';
  }

  @override
  String get searchHistory => '搜尋紀錄';

  @override
  String get searchFailed => '搜尋失敗';

  @override
  String get searchNoResults => '找不到結果。';

  @override
  String get searchCancel => '取消';

  @override
  String get searchHint => 'Worldo、角色、標籤';

  @override
  String get worldDetailOnlyWorldsLaunched => '只有你獨自啟動的世界可以刪除。';

  @override
  String get worldDetailDelete => '刪除';

  @override
  String get worldDetailNoCharacterStatusYet => '目前還沒有角色狀態。';

  @override
  String get worldDetailNoCharactersYet => '目前還沒有角色。';

  @override
  String get worldDetailProgressingWorld => '正在推進世界';

  @override
  String get worldDetailCompressingRecent =>
      '正在整理近期記憶\n推進世界時間線\n生成下一段劇情\n更新角色位置';

  @override
  String get worldModelsDetail => '詳細資料';

  @override
  String get worldModelsLocations => '地點';

  @override
  String get worldModelsEvents => '事件';

  @override
  String get worldModelsStatus => '狀態';

  @override
  String get worldDetailUnavailable => '無法使用';

  @override
  String worldActionFailed({required String actionLabel}) {
    return '$actionLabel失敗';
  }

  @override
  String get worldDetailRequestJoinWorld => '要申請加入這個世界嗎？';

  @override
  String get worldDetailRequest => '申請';

  @override
  String get worldDetailLaunchFailed => '啟動失敗';

  @override
  String get worldDetailNoSavedProfileFound => '找不到已儲存的個人檔案';

  @override
  String get worldDetailWID => 'WID';

  @override
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  }) {
    return '來源 Worldo：$sourceOid · V$version';
  }

  @override
  String get worldDetailInvite => '邀請';

  @override
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  }) {
    return '來 Worldo 加入我的世界「$worldName」！\n$wid\n在 Worldo 搜尋這組 WID，即可找到並加入。\n$downloadUrl';
  }

  @override
  String get worldDetailWorldBrief => '世界簡介';

  @override
  String get worldDetailCast => '角色陣容';

  @override
  String get worldDetailLinkCopiedShare => '連結已複製，快分享給朋友。';

  @override
  String get worldMapAction => '地圖';

  @override
  String get worldInfoAction => '資訊';

  @override
  String worldLocationCount({required String pointsCount}) {
    return '地點（$pointsCount）';
  }

  @override
  String get worldDetailPlayer => '玩家';

  @override
  String worldDetailGoal({required String goal}) {
    return '目標：$goal';
  }

  @override
  String get worldDetailNoCharacterDetailsYet => '目前還沒有角色詳細資料。';

  @override
  String get worldDetailNoEventsYet => '目前還沒有事件。';

  @override
  String get worldDetailLoadEventsFailed => '載入事件失敗。';

  @override
  String homeLocationID({required String id}) {
    return '地點 $id';
  }

  @override
  String get homeBuildingWorld => '正在建構世界';

  @override
  String get worldMapLoadFailed => '地圖載入失敗';

  @override
  String get worldMapZoomIn => '放大地圖';

  @override
  String get worldMapZoomOut => '縮小地圖';

  @override
  String get worldDetailGlobal => '全域';

  @override
  String get worldDetailLocation => '地點';

  @override
  String worldDetailTickNumber({required String tickNumber}) {
    return 'Tick $tickNumber';
  }

  @override
  String get homeGeneratingFirstTick => '正在生成第一個 Tick';

  @override
  String get worldFirstTickStatusLoadFailed => '無法載入生成狀態。';

  @override
  String get worldDetailNew => '新';

  @override
  String get homeUnknownLocation => '未知地點';

  @override
  String get homeUnknownCharacter => '未知角色';

  @override
  String get homeNewPlaceEmerged => '出現新地點';

  @override
  String get homeNewCharacterAppeared => '出現新角色';

  @override
  String get chatLocationUnavailable => '無法使用此地點';

  @override
  String get chatRequestApprovalLaunch => '申請核准啟動';

  @override
  String get chatLoading => '載入中';

  @override
  String get chatQuotaCheckFailed => '無法查詢剩餘免費次數，請再試一次。';

  @override
  String get chatInspirationSourceChanged => '靈感來源已變更，請重新開啟靈感功能。';

  @override
  String get chatInspiration => '靈感';

  @override
  String get chatMessageCannotSend => '這則訊息已無法傳送';

  @override
  String get chatMessageEmpty => '訊息內容為空';

  @override
  String get chatConnectionFailed => '無法連線至這個聊天室';

  @override
  String get chatReplyChangedSelect => '回覆內容已變更，請重新選擇靈感。';

  @override
  String get chatSendConfirmFailed => '無法確認訊息是否已送出';

  @override
  String get chatNoNetworkConnection => '沒有網路連線';

  @override
  String get chatRoundCannotContinue => '無法繼續這一回合';

  @override
  String get chatSourceRoundChanged => '來源回合已變更';

  @override
  String get chatGo => '繼續';

  @override
  String get chatReplyActionUnavailable => '這項回覆操作已無法使用';

  @override
  String get chatRegenerateFailure => '重新生成失敗';

  @override
  String get chatGoFailure => '繼續失敗';

  @override
  String get chatEditFailure => '編輯失敗';

  @override
  String get chatInspirationFailure => '無法產生靈感';

  @override
  String get chatJoinLocationFailed => '無法加入此地點';

  @override
  String get chatInactive => '這個聊天室已停用';

  @override
  String get chatChatroomUnavailable => '聊天室無法使用';

  @override
  String get chatFailedConfirmReplyAction => '無法確認回覆操作';

  @override
  String get chatLeastOneMessageMustRemain => '至少必須保留一則訊息。';

  @override
  String get chatReplyNotEditable => '這則回覆無法編輯';

  @override
  String get chatReplyAlreadyFixed => '這則回覆已固定';

  @override
  String get chatReplyEditorFrozen => '回覆編輯器已凍結';

  @override
  String get chatResolvePreviousSaveBefore => '請先處理上次儲存結果，再修改草稿';

  @override
  String get chatStaleReplyEditor => '回覆編輯器已過期';

  @override
  String get chatPreviousSaveResultUncertain => '無法確認上次儲存結果，請重新載入後再編輯';

  @override
  String get chatCandidateMissing => '候選內容已不存在';

  @override
  String get chatBatchSupportsMost100Changes => '每批最多支援 100 項變更';

  @override
  String get chatMissingStableMessageIdentity => '缺少穩定的訊息識別資訊';

  @override
  String get chatEditTargetHasChanged => '編輯目標已變更';

  @override
  String get chatMessageNotEditable => '這則訊息無法編輯';

  @override
  String get chatReplyNoLongerEditable => '這則回覆已無法編輯';

  @override
  String get chatEditorOpenFailed => '無法開啟編輯器';

  @override
  String get chatInactiveDuringEdit => '這個聊天室已停用。';

  @override
  String get chatEditMessage => '編輯訊息';

  @override
  String get chatSave => '儲存';

  @override
  String get chatEdit => '編輯';

  @override
  String get chatRegenerate => '重新生成';

  @override
  String get chatRegenerateUnavailable => '這一回合無法重新生成';

  @override
  String get chatGenerate10Replies => '最多可生成 10 則回覆。';

  @override
  String get chatPreviousReply => '上一則回覆';

  @override
  String get chatNextReply => '下一則回覆';

  @override
  String get chatCopy => '複製';

  @override
  String get chatReport => '檢舉';

  @override
  String get chatCopied => '已複製';

  @override
  String chatCountNewMessage({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則新訊息',
      one: '1 則新訊息',
    );
    return '$_temp0';
  }

  @override
  String get chatMention => '提及';

  @override
  String get chatCharacters => '角色';

  @override
  String get chatNoCharacters => '沒有角色';

  @override
  String get chatNoLocations => '沒有地點';

  @override
  String get chatHere => '這裡';

  @override
  String get chatLoadEarlierMessages => '載入更早的訊息';

  @override
  String get chatText => '輸入訊息…';

  @override
  String get chatLocationRoster => '你';

  @override
  String get homeNpc => 'NPC';

  @override
  String get commonAiDisclaimer => '所有內容均由 AI 生成，純屬虛構。如與真實人物、事件或地點雷同，純屬巧合。';

  @override
  String get homeRecent => '最近';

  @override
  String get worldoUnableSavePreference => '無法儲存你的偏好設定，請再試一次。';

  @override
  String get worldoFilterGender => '依性別篩選';

  @override
  String get worldoNoData => '沒有資料';

  @override
  String get worldoAll => '全部';

  @override
  String get worldoDetailSelectRole => '選擇你的角色';

  @override
  String get worldoDetailOID => 'OID';

  @override
  String worldoDetailCreator({required String creatorName}) {
    return '創作者：$creatorName';
  }

  @override
  String get worldoDetailEditWorldo => '編輯 Worldo';

  @override
  String get worldoDetailWorldoBrief => 'Worldo 簡介';

  @override
  String get worldoDetailNewPost => '新增貼文';

  @override
  String get worldoDetailWritePost => '撰寫貼文';

  @override
  String worldoDetailDiscussCount({required String discussCount}) {
    return '討論（$discussCount）';
  }

  @override
  String get worldoDetailViewAll => '查看全部 >';

  @override
  String get worldoDetailPlayingWorld => '遊玩中的世界';

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
    return '角色（$length）';
  }

  @override
  String get worldoSend => '傳送';

  @override
  String get worldoPostFailed => '發布貼文失敗';

  @override
  String get worldoImageUploadFailed => '圖片上傳失敗';

  @override
  String get worldoLoadRepliesFailed => '載入回覆失敗';

  @override
  String get worldoWriteReply => '撰寫回覆';

  @override
  String worldoReplyName({required String replyToName}) {
    return '回覆 $replyToName';
  }

  @override
  String get worldoPostDetail => '貼文詳細資料';

  @override
  String get worldoPostUnavailable => '無法查看貼文';

  @override
  String worldoAllRepliesReplyCount({required String replyCount}) {
    return '所有回覆（$replyCount）';
  }

  @override
  String worldoViewAllReplies({required String replyCount}) {
    return '查看全部 $replyCount 則回覆';
  }

  @override
  String get worldoLikeFailed => '按讚失敗';

  @override
  String worldoViewAllReplyCountReplies({required String replyCount}) {
    return '查看全部 $replyCount 則回覆';
  }

  @override
  String get worldoUser => '使用者';

  @override
  String get worldoViewMore => '查看更多 >';

  @override
  String worldoDiscuss({required String discussCount}) {
    return '討論（$discussCount）';
  }

  @override
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  }) {
    return '查看其餘 $remainingReplyCount 則回覆';
  }

  @override
  String get worldoReply => '回覆';

  @override
  String get worldoDiscussTitle => '討論區';

  @override
  String get worldoLaunchLocationComesLife => '啟動後，這個地點就會活躍起來。';

  @override
  String get worldoLaunchLaunchWorldoExplore => '啟動這個 Worldo，即可在這裡探索和互動。';

  @override
  String get worldoLaunchRoleUnavailable => '這個角色已無法選用';

  @override
  String get worldoLaunchSelectRole => '選擇你的角色';

  @override
  String get worldoLaunchProfile => '你的角色資料';

  @override
  String get worldoLaunchDone => '完成';

  @override
  String get worldoLaunchSuggested => '建議';

  @override
  String get worldoLaunchName => '名稱';

  @override
  String get worldoLaunchIdentity => '身分';

  @override
  String get worldoLaunchPersonality => '個性';

  @override
  String get worldoLaunchGoal => '目標';

  @override
  String get worldoLaunchSetupRole => '設定你的角色';

  @override
  String get worldoLaunchPreset => '預設';

  @override
  String get worldoLaunchCustom => '自訂';

  @override
  String get worldoLaunchNoPresetRole => '沒有預設角色';

  @override
  String get worldoLaunchFilling => '填入中…';

  @override
  String get worldoLaunchFillMyProfile => '從我的個人檔案填入';

  @override
  String get worldoLaunchLaunch => '啟動世界';

  @override
  String worldoLaunchWorldoWorldName({required String worldName}) {
    return 'Worldo #$worldName 已啟動！';
  }

  @override
  String get worldoLaunchEnter => '進入';

  @override
  String get createAction => '建立';

  @override
  String get createWorldoTitle => '建立 Worldo';

  @override
  String get createFailed => '建立失敗';

  @override
  String get createNotesRequired => '發布前必須填寫更新說明。';

  @override
  String get createActionInProgress => '這項操作正在進行中。';

  @override
  String createCurrentVersion({required String version}) {
    return '目前版本：$version';
  }

  @override
  String get createChecking => '檢查中…';

  @override
  String createSummaryName({required String name}) {
    return 'Worldo 名稱：$name';
  }

  @override
  String createSummaryBrief({required String brief}) {
    return 'Worldo 簡介：$brief';
  }

  @override
  String createSummaryCover({required String status}) {
    return '封面圖片：$status';
  }

  @override
  String get createNotUploaded => '尚未上傳';

  @override
  String get createUploaded => '已上傳';

  @override
  String createSummarySettings({required String settings}) {
    return 'Worldo 設定：$settings';
  }

  @override
  String createSummaryTime({required String time}) {
    return 'Worldo 時間：$time';
  }

  @override
  String createSummaryMetric({required String metric}) {
    return 'Worldo 指標：$metric';
  }

  @override
  String createDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
      one: '1 天',
    );
    return '$_temp0';
  }

  @override
  String get createSummaryNoCharacters => '0 位角色';

  @override
  String createSummaryCharacters({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位角色：$names',
      one: '1 位角色：$names',
    );
    return '$_temp0';
  }

  @override
  String createSummarySuggested({required String name}) {
    return '建議：$name';
  }

  @override
  String createSummaryRegion({required int count}) {
    return 'L1 · 區域：$count';
  }

  @override
  String createSummaryBuilding({required int count}) {
    return 'L2 · 建築：$count';
  }

  @override
  String createSummaryRoom({required int count}) {
    return 'L3 · 房間：$count';
  }

  @override
  String createSummaryEvents({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個事件',
      one: '1 個事件',
    );
    return '$_temp0';
  }

  @override
  String createSummaryDialogue({required int count}) {
    return '角色對話：$count';
  }

  @override
  String createSummaryNarrator({required int count}) {
    return '旁白：$count';
  }

  @override
  String createSummaryImage({required int count}) {
    return '圖片：$count';
  }

  @override
  String createDeleteItemLabel({required String itemLabel}) {
    return '要刪除$itemLabel嗎？';
  }

  @override
  String get createItemHasContentDeleteAnyway => '這個項目包含內容，仍要刪除嗎？';

  @override
  String get createImageUploadProgress => '圖片正在上傳。';

  @override
  String get createBasicsBasics => '基本資料';

  @override
  String get createSaveInProgress => '正在儲存，請稍候。';

  @override
  String get createRequiredBeforeSave => '請填妥所有必填欄位後再儲存。';

  @override
  String get createOpeningOpening => '開場';

  @override
  String get createCharacterCharactersCreate => '角色：請至少建立一位角色。';

  @override
  String get createCharacterCharactersOnlyOne => '角色：只能推薦一位角色。';

  @override
  String get createBasicsBasicsWorldoName => '基本資料：必須填寫 Worldo 名稱。';

  @override
  String get createBasicsBasicsWorldoBrief => '基本資料：必須填寫 Worldo 簡介。';

  @override
  String get createBasicsBasicsCoverImage => '基本資料：必須上傳封面圖片。';

  @override
  String get createBasicsBasicsMetricMust => '基本資料：指標必須是有效的 JSON。';

  @override
  String createCharacterCharactersName({required String characterIndex}) {
    return '角色 #$characterIndex：必須填寫名稱。';
  }

  @override
  String createCharacterCharacters({required String characterIndex}) {
    return '角色 #$characterIndex：必須填寫身分。';
  }

  @override
  String createCharacterRequired({required String characterIndex}) {
    return '角色 #$characterIndex：必須填寫個性。';
  }

  @override
  String get createCharacterCharactersLeast => '角色：至少需要一位角色。';

  @override
  String get createLocationLocationsCreate => '地點：請至少建立一個地點。';

  @override
  String createLocationLocationsLocation({required String locationIndex}) {
    return '地點 #$locationIndex：必須填寫地點名稱。';
  }

  @override
  String get createOpeningOpeningSelect => '開場：請選擇地點，並完成每個對話項目。';

  @override
  String get createOpeningOpeningSelected => '開場：所選地點已無法使用。';

  @override
  String get createOpeningCharacterOpening => '開場：所選角色已無法使用。';

  @override
  String get createOpeningOpeningDialogue => '開場：對話角色不在所選地點。請開啟「開場」修正。';

  @override
  String createUnsupportedOpeningDialogue({required String type}) {
    return '不支援的開場對話類型：$type';
  }

  @override
  String get createCreating => '建立中…';

  @override
  String get createDiscard => '捨棄';

  @override
  String get createCharactersStep => '角色（至少 1 位）';

  @override
  String get createLocationsStep => '地點（至少 1 個）';

  @override
  String get createStoryEventsOptional => '故事事件（選填）';

  @override
  String get createUpdateNotesRequiredPublish => '更新說明（發布時必填）';

  @override
  String get createWhatChangedVersion => '這個版本有哪些變更？';

  @override
  String get createView => '查看';

  @override
  String get createNotStartedYet => '尚未開始';

  @override
  String get createEdited => '已編輯';

  @override
  String get createPublishingWorldo => '正在發布你的 Worldo';

  @override
  String get createCreatingWorldo => '正在建立你的 Worldo';

  @override
  String get createPreparingWorldoUpdatesWait => '正在準備 Worldo 更新。\n請稍候。';

  @override
  String get createBringingWorldoLifeWait => '正在讓你的 Worldo 活起來。\n請稍候。';

  @override
  String get createDescribeIssue => '描述問題';

  @override
  String get createSubmit => '送出';

  @override
  String get createBasicsWorldoName => 'Worldo 名稱 *';

  @override
  String get createBasicsNameRequired => '必須填寫 Worldo 名稱。';

  @override
  String get createBasicsBriefRequired => '必須填寫 Worldo 簡介。';

  @override
  String get createBasicsCoverRequired => '必須上傳封面圖片。';

  @override
  String get createBasicsMetricInvalid => '指標必須是有效的 JSON。';

  @override
  String get createBasicsEgMainStreet => '例如：主街';

  @override
  String get createBasicsWorldoBrief => 'Worldo 簡介 *';

  @override
  String get createBasicsBriefNote => '玩家最先看到的公開介紹：世界設定、核心衝突，以及吸引人的地方。';

  @override
  String get createBasicsHiddenNote => '推動故事發展的隱藏規則與背景：各方意圖、運作機制及秘密限制。';

  @override
  String get createBasicsEgHalfShopsMain =>
      '例如：主街上有一半店面已用木板封起。到了勞動節，最有錢的店家將掌控整個小鎮。';

  @override
  String get createBasicsCoverImage => '封面圖片 *';

  @override
  String get createBasicsUpload => '上傳';

  @override
  String get createBasicsUsedCardsDetailPages =>
      '用於卡片和詳細資料頁面。建議尺寸約為 768×1024 px。支援格式：JPG、PNG、WEBP。';

  @override
  String get createBasicsWorldoSettingsHidden => 'Worldo 設定－隱藏（選填）';

  @override
  String get createBasicsEgBankerSecretly => '例如：銀行家暗中決定誰能取得貸款；借貸過度的人可能會被排擠出局。';

  @override
  String get createBasicsWorldoTimeOptional => 'Worldo 時間（選填）';

  @override
  String get createBasicsWorldoStartsStart =>
      '這個 worldo 從「{開始時間}」開始；每當使用者點選「推進」，時間線就會前進「{每次推進的時間}」。';

  @override
  String get createBasicsStartTime => '開始時間';

  @override
  String get createBasicsDateExample => '例如：第 1 天，09:00／2026-01-01';

  @override
  String get createBasicsTimePerProgress => '每次推進的時間';

  @override
  String get createBasicsEg8Hours3Days => '例如：8 小時／3 天';

  @override
  String get createBasicsWorldoMetricOptional => 'Worldo 指標（選填）';

  @override
  String get createBasicsMetricLabel => '指標名稱';

  @override
  String get createBasicsEgWealthGoalProgress => '例如：財富／目標進度';

  @override
  String get createBasicsLabelNote => '名稱說明';

  @override
  String get createBasicsDescribeWhatMetric => '說明這項指標衡量的內容';

  @override
  String get createBasicsUnit => '單位';

  @override
  String get createBasicsEgCoins => '例如：硬幣／%';

  @override
  String get createBasicsRange => '數值範圍';

  @override
  String get createBasicsStarting => '起始值';

  @override
  String get createBasicsDeltaMin => '最小變動值';

  @override
  String get createBasicsDeltaMax => '最大變動值';

  @override
  String get createBasicsSaving => '儲存中…';

  @override
  String get createBasicsAdvancedSettings => '進階設定（選填）';

  @override
  String createCharacterCharacterIndex({required String index}) {
    return '角色 $index';
  }

  @override
  String get createCharacterSuggest => '建議';

  @override
  String get createCharacterAvatarOptional => '頭像\n（選填）';

  @override
  String get createCharacterName => '名稱 *';

  @override
  String get createCharactersTitle => '角色';

  @override
  String createCharacterLimit({required int count}) {
    return '最多可新增 $count 位角色。';
  }

  @override
  String createCharacterNameRequired({required int index}) {
    return '角色 $index：必須填寫名稱。';
  }

  @override
  String createCharacterIdentityRequired({required int index}) {
    return '角色 $index：必須填寫身分。';
  }

  @override
  String createCharacterPersonalityRequired({required int index}) {
    return '角色 $index：必須填寫個性。';
  }

  @override
  String get createCharacterMinOne => '請至少建立一位角色。';

  @override
  String get createCharacterEnterName => '輸入名稱…';

  @override
  String get createCharacterIdentity => '身分 *';

  @override
  String get createCharacterEgHometownKidBack => '例如：返鄉尋找最後一次機會的在地青年';

  @override
  String get createCharacterPersonality => '個性 *';

  @override
  String get createCharacterEgUnderdog => '例如：人緣好但資金不足的弱勢挑戰者';

  @override
  String get createCharacterGoalOptional => '目標（選填）';

  @override
  String get createCharacterEgRichestOwner => '例如：在勞動節前成為主街上最富有的店主';

  @override
  String get createCharacterBackgroundHidden => '背景－隱藏（選填）';

  @override
  String get createCharacterEgLeftTownYears => '例如：多年前離開小鎮，如今回到店面荒廢的主街，尋求一次機會。';

  @override
  String get createCharacterAddCharacter => '+ 新增角色';

  @override
  String get createLocationImageOptional => '圖片\n（選填）';

  @override
  String get createCharacterSelectAvailable => '從下方可用角色中選擇';

  @override
  String get createCharacterInitialCharacters => '初始角色（選填）';

  @override
  String get createLocationStartingCharacters => 'worldo 開始時位於這裡的角色。';

  @override
  String get createCharacterAvailableSelect => '可選擇的角色';

  @override
  String get createCharacterNoCharactersYet => '目前還沒有角色。請先建立角色，再選擇他們的起始地點。';

  @override
  String get createCharacterNoCharacters => '沒有可選擇的角色。所有角色都已有初始地點。';

  @override
  String get createLocationEveryL2L3Locations => '其中所有 L2 和 L3 地點也會一併移除。';

  @override
  String get createLocationEveryL3Locations => '其中所有 L3 地點也會一併移除。';

  @override
  String createLocationDeleteDisplayName({required String displayName}) {
    return '刪除「$displayName」';
  }

  @override
  String get createLocationOpeningLocation => '這是開場地點。刪除此地點也會清除開場內容。';

  @override
  String get createLocationL1LocationRegion => 'L1 地點 · 區域 *';

  @override
  String get createLocationL2LocationBuilding => 'L2 地點 · 建築 *';

  @override
  String get createLocationAddL3Location => '新增 L3 地點';

  @override
  String get createLocationsTitle => '地點';

  @override
  String get createLocationStatisticsNote =>
      '你的世界分為 3 個層級：\nL1 · 區域     世界中的一個區域，例如市中心\nL2 · 建築     區域內的一棟建築，例如喬的小餐館\nL3 · 房間     建築內的一個房間，例如後廚房\n每個地點都需要具備這三個層級。房間總數最多 15 個。';

  @override
  String get createLocationL1NameNote => '世界中的一個區域，例如街區、小鎮或森林，而不是單一建築。';

  @override
  String get createLocationL2NameNote => '這個區域內的一棟建築，例如商店、學校或公寓大樓。';

  @override
  String get createLocationL3NameNote => '建築內的一個房間。屋頂、庭院和入口也可以。';

  @override
  String get createLocationName => '名稱 *';

  @override
  String get createLocationL1NameRequired => '必須填寫 L1 地點名稱。';

  @override
  String get createLocationL3NameRequired => '必須填寫 L3 地點名稱。';

  @override
  String get createLocationThisL1 => '這個 L1 地點';

  @override
  String get createLocationThisL2 => '這個 L2 地點';

  @override
  String createLocationL1NeedsL2({required String locationLabel}) {
    return '$locationLabel 必須至少包含一個 L2 地點。';
  }

  @override
  String createLocationL2NeedsL3({required String locationLabel}) {
    return '$locationLabel 必須至少包含一個 L3 地點。';
  }

  @override
  String createLocationL2NameNeeded({required String locationLabel}) {
    return '$locationLabel 中有一個 L2 地點尚未命名。';
  }

  @override
  String createLocationL3NameNeeded({required String locationLabel}) {
    return '$locationLabel 中有一個 L3 地點尚未命名。';
  }

  @override
  String createLocationMaxL3({required int count}) {
    return '最多可新增 $count 個 L3 地點。';
  }

  @override
  String createLocationRoomsFull({required int count}) {
    return '$count 個房間已全數用完。請先刪除一個，才能新增房間。';
  }

  @override
  String get createLocationAtLeastOneL1 => '至少需要一個 L1 地點。';

  @override
  String get createLocationAddL1 => '請至少新增一個 L1 地點。';

  @override
  String get createLocationMinOne => '請至少建立一個地點。';

  @override
  String get createLocationIdRequired => '每個地點都必須有 ID。';

  @override
  String get createLocationIdUnique => '每個地點都必須有不重複的 ID。';

  @override
  String get createLocationParentInvalid => '每個地點都必須有有效的上層地點。';

  @override
  String get createLocationFieldsRequired => '請填妥所有必填地點欄位後再儲存。';

  @override
  String createLocationDeleteBubbles({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '儲存地點也會刪除已移除角色的 $count 個開場對話氣泡。',
      one: '儲存地點也會刪除已移除角色的 1 個開場對話氣泡。',
    );
    return '$_temp0';
  }

  @override
  String get createLocationEditL3Location => '編輯 L3 地點';

  @override
  String get createLocationPreview => '預覽';

  @override
  String get createLocationCompleteLocation => '請完成這個地點的資料，或將其刪除。';

  @override
  String get createLocationRemoveCharacter => '要將角色從地點移除嗎？';

  @override
  String get createLocationRemove => '移除';

  @override
  String get createLocationL1Location => 'L1 地點';

  @override
  String get createLocationL2Location => 'L2 地點';

  @override
  String get createLocationL3Location => 'L3 地點';

  @override
  String get createOpeningSelectLocation => '選擇地點';

  @override
  String get createOpeningNoSavedLocations => '沒有已儲存的地點';

  @override
  String get createOpeningSelect => '選擇';

  @override
  String get createOpeningSelectLocationFirst => '請先選擇地點。';

  @override
  String get createOpeningNoInitialCharacter => '沒有初始角色';

  @override
  String get createOpeningLocationsLoading => '地點仍在載入中。';

  @override
  String get createOpeningLoadingLocations => '正在載入地點…';

  @override
  String get createOpeningSwitchingLocations => '切換地點會清除對話內容。';

  @override
  String get createOpeningContinue => '繼續';

  @override
  String get createOpeningAdd10DialogueItems => '最多可新增 10 個對話項目。';

  @override
  String get settingsUnableSaveSuggestedRole => '無法儲存推薦角色。';

  @override
  String get createOpeningUnableSaveOpening => '無法儲存開場內容。';

  @override
  String get createOpeningSelectInitial => '選擇初始地點';

  @override
  String get createOpeningInitialLocationRequired => '儲存前請先選擇初始地點。';

  @override
  String get createOpeningAddDialogueFirst => '儲存前請至少新增一個對話項目。';

  @override
  String get createOpeningCompleteDialogue => '儲存前請完成所有對話項目。';

  @override
  String get createOpeningDialogue => '開場對話';

  @override
  String get createOpeningLocationRequired => '請先選擇地點，再編輯對話。';

  @override
  String get createOpeningNarrator => '旁白';

  @override
  String get createOpeningImage => '圖片';

  @override
  String get createOpeningSuggestRoleUser => '向使用者推薦角色';

  @override
  String get createOpeningNoCharacters => '沒有可用角色。';

  @override
  String get createOpeningEnterNarrator => '輸入旁白內容';

  @override
  String createOpeningEnterNameDialogue({required String name}) {
    return '輸入 $name 的對話';
  }

  @override
  String get createOpeningUser => '{{user}}';

  @override
  String get createOpeningUploadImage => '上傳圖片';

  @override
  String get createEventAddEvent => '+ 新增事件';

  @override
  String get createStoryEventsTitle => '故事事件';

  @override
  String createEventLimit({required int count}) {
    return '最多可新增 $count 個事件。';
  }

  @override
  String createEventEventIndex({required String index}) {
    return '事件 $index';
  }

  @override
  String get createEventEgNationalChainScouts =>
      '例如：全國連鎖店相中一塊空地，打算以低價搶走所有在地店家的生意。';

  @override
  String get createEventKeyStoryBeatAIUses => 'AI 用來引導故事發展的關鍵劇情。';

  @override
  String get imageCropUploadFailed => '上傳失敗';

  @override
  String get inboxNotifications => '通知';

  @override
  String get inboxNoNotificationsYet => '目前沒有通知。';

  @override
  String get inboxFollowers => '粉絲';

  @override
  String get inboxNewFollowers => '新粉絲';

  @override
  String get inboxNoNewFollowersYet => '目前沒有新粉絲。';

  @override
  String get inboxComments => '留言';

  @override
  String get inboxNoCommentsYet => '目前沒有留言。';

  @override
  String get inboxPrivateChats => '私訊';

  @override
  String get inboxChatFriendsWorldo => '在 Worldo 與朋友聊天。';

  @override
  String get inboxUnknownUser => '未知使用者';

  @override
  String get inboxDirectMessage => '私訊';

  @override
  String get inboxJoinRequest => '加入申請';

  @override
  String get inboxApprove => '核准';

  @override
  String get inboxReject => '拒絕';

  @override
  String get inboxOk => '確定';

  @override
  String get inboxReviewFailed => '審核失敗';

  @override
  String get inboxLoadMessagesFailed => '載入訊息失敗。';

  @override
  String get inboxNewMessage => '新訊息';

  @override
  String get inboxSomeone => '某人';

  @override
  String get inboxWorld => '這個世界';

  @override
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  }) {
    return '$name 申請加入 $world$suffix';
  }

  @override
  String get inboxCommentWorldo => ' 在你的 worldo 留言';

  @override
  String get inboxReply => ' 回覆了你';

  @override
  String get inboxLikeComment => ' 對你的留言按讚';

  @override
  String get inboxLikedComment => '對你的留言按讚';

  @override
  String get inboxComment2LikeComment => '對你的留言按讚';

  @override
  String get inboxReplied => '回覆了你';

  @override
  String get inboxYou2Reply => '回覆了你';

  @override
  String get inboxCommentedOrigin => '在你的原創內容留言';

  @override
  String get inboxCommentOrigin => '在你的原創內容留言';

  @override
  String get inboxSentMessage => ' 傳送了一則訊息給你';

  @override
  String get inboxStartedFollowing => ' 開始追蹤你。';

  @override
  String get meFailedOpenDiscord => '無法開啟 Discord';

  @override
  String get meImagePickFailed => '選取圖片失敗';

  @override
  String get meUpdateFailed => '更新失敗';

  @override
  String get mePlaying => '遊玩中';

  @override
  String get meEditName => '編輯名稱';

  @override
  String get meSignUpReward => '註冊即可獲得 250 顆寶石！';

  @override
  String get loginSignUpReward => '註冊即可獲得 250 顆寶石！';

  @override
  String get meUnknown => '未知';

  @override
  String meOIDLatestVersion({required String oid, required String version}) {
    return 'OID：$oid\n最新版本：$version';
  }

  @override
  String meWIDDisplayOwner({
    required String displayWid,
    required String owner,
  }) {
    return 'WID：$displayWid\n擁有者：$owner';
  }

  @override
  String get meFollows => '追蹤';

  @override
  String meFollowingCount({required String followingCount}) {
    return '$followingCount 追蹤中';
  }

  @override
  String meFollowersCount({required String followersCount}) {
    return '$followersCount 位粉絲';
  }

  @override
  String get meNoFollowingYet => '目前尚未追蹤任何人。';

  @override
  String get meNoFollowersYet => '目前還沒有粉絲。';

  @override
  String get meBlockFailed => '封鎖失敗，請再試一次。';

  @override
  String get meUserBlockedContentHasReported => '已封鎖使用者，並向 Worldo 團隊檢舉此內容。';

  @override
  String get meBlockUser => '要封鎖這位使用者嗎？';

  @override
  String get meBlock => '封鎖';

  @override
  String get meUnblockFailed => '解除封鎖失敗，請再試一次。';

  @override
  String get meUnblock => '解除封鎖';

  @override
  String get meFollowing => '追蹤中';

  @override
  String get meFollow => '追蹤';

  @override
  String get meMessage => '傳訊息';

  @override
  String meUID({required String uid}) {
    return 'UID：$uid';
  }

  @override
  String get meNoWorldoCreatedYet => '你目前還沒有建立 Worldo。';

  @override
  String get meNoWorldoYet => '目前還沒有 Worldo。';

  @override
  String get meNoWorldsCreatedYet => '你目前還沒有建立世界。';

  @override
  String get meNoWorldsYet => '目前還沒有世界。';

  @override
  String get profileUID => 'UID';

  @override
  String get gemsRed => '紅寶石';

  @override
  String get gemsPink => '粉寶石';

  @override
  String get gemsTop => '儲值';

  @override
  String get gemsBuy => '購買寶石';

  @override
  String get gemsRecords => '紀錄';

  @override
  String get gemsUnableLoad => '無法載入寶石資料。';

  @override
  String get settingsLogOutAccount => '要登出帳號嗎？';

  @override
  String get settingsLogOut => '登出';

  @override
  String get settingsFeedback => '意見回饋';

  @override
  String get settings => '設定';

  @override
  String get settingsAboutUs => '關於我們';

  @override
  String get settingsAccount => '帳號';

  @override
  String get settingsBlockedUsers => '已封鎖的使用者';

  @override
  String get settingsJoinDiscord => '加入 Discord';

  @override
  String get meUserUnblocked => '已解除封鎖使用者';

  @override
  String get meNoBlockedUsersYet => '目前沒有已封鎖的使用者。';

  @override
  String get settingsAgreeTermsContinue => '請同意條款後繼續。';

  @override
  String get settingsDeleteAccount => '要刪除帳號嗎？';

  @override
  String get settingsAccountDeletionAgreement => '帳號刪除協議';

  @override
  String get settingsEnsureSecurityAccount =>
      '為確保帳號安全，請先閱讀刪除帳號的相關後果。\n\n刪除帳號不同於登出。帳號刪除後無法復原。刪除帳號後，你的私人資料，包括已建立的角色、搜尋紀錄、與任何角色的聊天紀錄、收藏項目、記憶、互動資料及訂單紀錄，都將永久刪除，無法恢復。';

  @override
  String get gemsAllUnusedIncludingPurchased =>
      '所有尚未使用的寶石，包括購買和賺取的寶石，都將永久失效。繼續操作即表示你自願放棄這些寶石；刪除帳號並不代表你自動享有退款權利。\n\n所有剩餘的會員權益也將永久失效，無法恢復。刪除帳號不會取消訂閱。';

  @override
  String get settingsIHaveReadAccountDeletion => '我已閱讀帳號刪除協議';

  @override
  String get settingsCurrentLoginAccount => '目前登入的帳號：';

  @override
  String get profileSaveFailed => '無法儲存個人檔案，請再試一次。';

  @override
  String get meSignInFailed => '登入失敗，請再試一次。';

  @override
  String get meCompleteProfileContinue => '請完成個人檔案後繼續。';

  @override
  String get meSelectGenderAge => '請選擇性別和年齡。';

  @override
  String get meSelectGender => '請選擇性別。';

  @override
  String get meSelectAge => '請選擇年齡。';

  @override
  String get meRequired => '必填';

  @override
  String get mePersonalizeWorldoExperience => '打造專屬的 Worldo 體驗';

  @override
  String get meSignIn => '登入';

  @override
  String get meBack => '返回';

  @override
  String get meSkip => '略過';

  @override
  String get meContinueGoogle => '使用 Google 繼續';

  @override
  String get meContinueApple => '使用 Apple 繼續';

  @override
  String get meSignUpClaimPremium => '註冊以領取 Premium';

  @override
  String get meSignUpContinue => '註冊後繼續';

  @override
  String get meAccountLoggedAnotherDevice => '你的帳號已在其他裝置登入。';

  @override
  String get premiumSubscription => '訂閱';

  @override
  String get gemsClaimFailed => '領取失敗。';

  @override
  String get gemsCheckFailed => '簽到失敗。';

  @override
  String get gemsFollowFailed => '追蹤失敗。';

  @override
  String get gemsTaskUpdateFailed => '任務更新失敗。';

  @override
  String get gemsClaimSuccessful => '領取成功！';

  @override
  String get gemsUnableLoadGemPacks => '無法載入寶石組合包。';

  @override
  String get gemsNoGemPacksAvailable => '目前沒有可購買的寶石組合包。';

  @override
  String get gemsUnableLoadGemTasks => '無法載入寶石任務。';

  @override
  String get gemsJoinUs => '加入我們';

  @override
  String get gemsClaim => '領取';

  @override
  String get gemsClaimed => '已領取';

  @override
  String get meDailyCheck => '每日簽到';

  @override
  String get gemsDailyCheckInReward => '領取 100';

  @override
  String get meCheck => '簽到';

  @override
  String get meCheckSuccessful => '簽到成功！';

  @override
  String get meGooglePlayUnavailable => 'Google Play 無法使用。';

  @override
  String get mePurchaseFailed => '購買失敗。';

  @override
  String get gemsEarned => '獲得';

  @override
  String get gemsSpent => '支出';

  @override
  String get gemsPurchase => '購買';

  @override
  String get gemsGemRecords => '寶石紀錄';

  @override
  String get gemsUnableLoadRecords => '無法載入紀錄。';

  @override
  String get gemsNoGemRecordsYet => '目前沒有寶石紀錄。';

  @override
  String get meAbout => '關於';

  @override
  String get meEmailCopied => '電子郵件地址已複製';

  @override
  String get mePurchasingPremium => '正在購買 Premium';

  @override
  String get mePurchaseSuccessful => '購買成功！';

  @override
  String get meWorldoPremiumSubscription => '你的 Worldo Premium 訂閱現已生效。';

  @override
  String get meMyBalance => '我的餘額';

  @override
  String get meSoldOut => '已售完';

  @override
  String get meUsd => 'USD';

  @override
  String get memoryCompleteUserSession => '需要完整的使用者工作階段才能取得模型清單';

  @override
  String get memoryModelListPermissionDenied => '沒有權限查看這個世界的模型清單';

  @override
  String get memorySaveFailed => '儲存失敗';

  @override
  String get memorySaveResultNotConfirmed => '無法確認儲存結果';

  @override
  String get memoryChooseModel => '選擇模型';

  @override
  String get memoryMaxTokenLimit => '記憶 Token 上限';

  @override
  String get memoryNoModelsAvailable => '沒有可用模型';

  @override
  String get memoryRetryRanges => '重試範圍';

  @override
  String get memoryCurrentUsage => '目前的記憶用量';

  @override
  String memoryMinGems({required String min}) {
    return '$min 顆寶石';
  }

  @override
  String memoryMinMaxGems({required String min, required String max}) {
    return '$min–$max 顆寶石';
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
  String get memorySettingsUnavailable => '記憶設定無法使用';

  @override
  String get premiumGooglePlayTookTooLong => 'Google Play 回應時間過長，請再試一次。';

  @override
  String get premiumSubscriptionsNotSupported => '此裝置上的 Google Play 不支援訂閱。';

  @override
  String get premiumConnectionGooglePlayLost => '與 Google Play 的連線已中斷，請再試一次。';

  @override
  String get premiumPurchaseCanceled => '已取消購買。';

  @override
  String get premiumGooglePlayTemporarily => 'Google Play 暫時無法使用，請稍後再試。';

  @override
  String get premiumGooglePlayBilling => 'Google Play 無法處理付款。請檢查 Play 帳號及付款設定。';

  @override
  String get premiumSubscriptionUnavailable =>
      '這項 Premium 訂閱目前無法在 Google Play 購買。';

  @override
  String get premiumGooglePlayFailedComplete =>
      'Google Play 無法完成這筆 Premium 購買交易，請再試一次。';

  @override
  String get premiumAlreadyOwnSubscription => '你已在 Google Play 擁有這項訂閱。';

  @override
  String get premiumGooglePlayFailedFind => 'Google Play 找不到要變更的訂閱。請查看「管理訂閱」。';

  @override
  String get premiumFailedConnectGooglePlay =>
      '無法連線至 Google Play，請檢查網路連線後再試一次。';

  @override
  String get premiumInsufficientFunds =>
      '你的付款方式餘額不足。請在 Google Play 更新付款方式後再試一次。';

  @override
  String get premiumGoogleAccountIneligible => '你的 Google Play 帳號不符合這項訂閱優惠資格。';

  @override
  String get premiumAppStoreFailedComplete =>
      'App Store 無法完成這筆 Premium 購買交易，請再試一次。';

  @override
  String get premiumFailedConnectAppStore => '無法連線至 App Store，請檢查網路連線後再試一次。';

  @override
  String get premiumAppStoreTookTooLong => 'App Store 回應時間過長，請再試一次。';

  @override
  String get premiumAppStoreEncounteredSystem => 'App Store 發生系統錯誤，請稍後再試。';

  @override
  String get premiumRegionUnavailable => '你的 App Store 地區無法購買這項 Premium 訂閱。';

  @override
  String get premiumAppCannotMakeStoreRequest =>
      '此 App 無法向 App Store 發出這項請求，請聯絡客服。';

  @override
  String get premiumPurchaseNotSupported => '此裝置或系統版本不支援這項購買。';

  @override
  String get premiumAppStorePurchaseWindow =>
      '無法開啟 App Store 購買視窗。請返回 App 再試一次。';

  @override
  String get premiumAppStoreFailedAccept => 'App Store 無法接受這項購買數量，請聯絡客服。';

  @override
  String get premiumAppStoreUnavailable => '這項 Premium 訂閱目前無法在 App Store 購買。';

  @override
  String get premiumPurchasesNotAllowedDevice =>
      '此裝置不允許購買。請檢查 Apple 帳號 與購買限制設定。';

  @override
  String get premiumAppleAccountNotEligible => '你的 Apple 帳號 不符合這項訂閱優惠資格。';

  @override
  String get premiumSubscriptionOffer => '這項訂閱優惠無法使用。請重新整理頁面後再試一次。';

  @override
  String get premiumAppStoreFailedAcceptOffer =>
      'App Store 無法接受這項優惠價格。請重新整理頁面後再試一次。';

  @override
  String get premiumAppStoreFailedVerify => 'App Store 無法驗證這項訂閱優惠，請聯絡客服。';

  @override
  String get premiumSubscriptionOfferFailed => '無法準備這項訂閱優惠。請重新整理頁面後再試一次。';

  @override
  String get premiumAddPaymentMethodApple => '請先在 Apple 帳號 新增付款方式，然後再試一次。';

  @override
  String get premiumAppCannotMakePurchases => '此 App 無法透過 App Store 購買，請聯絡客服。';

  @override
  String get premiumAppStoreRequestRejected =>
      'App Store 無法接受這項購買請求。請再試一次或聯絡客服。';

  @override
  String get premiumAppleCloudServiceAccess =>
      '無法存取 Apple 雲端服務，請檢查 Apple 帳號 權限。';

  @override
  String get premiumFailedConnectApple => '無法連線至 Apple 服務，請檢查網路連線後再試一次。';

  @override
  String get premiumAccess2AppleCloudService =>
      'Apple 雲端服務的存取權限已遭撤銷，請檢查 Apple 帳號 設定。';

  @override
  String get premiumAcceptLatestApplePrivacy =>
      '請先在 Apple 帳號 同意最新的 Apple 隱私權條款，再試一次。';

  @override
  String get premiumAppStoreWindowFailed => '無法設定 App Store 視窗，請聯絡客服。';

  @override
  String get premiumAppStoreWindowTookTooLong => 'App Store 視窗開啟時間過長，請再試一次。';

  @override
  String get premiumReturnAppTryPurchase => '請返回 App，再試一次購買。';

  @override
  String get premiumGooglePlayUnavailable => 'Google Play 無法使用。請確認已安裝並登入。';

  @override
  String get premiumIs4Subscription => '商店目前沒有這項 Premium 訂閱。請重新整理頁面後再試一次。';

  @override
  String get premiumSubscriptionFailed => '無法準備這項 Premium 訂閱。請重新整理頁面後再試一次。';

  @override
  String get premiumStoreFailedOpenPurchase => '商店無法開啟這筆 Premium 購買交易，請再試一次。';

  @override
  String get premiumOriginalSubscriptionMissing =>
      'Google Play 找不到原本的訂閱。請查看「管理訂閱」。';

  @override
  String get premiumSubscriptionUsesDifferent => '這項訂閱使用不同的購買身分。請重新整理頁面或聯絡客服。';

  @override
  String get premiumGooglePlayCannotChange =>
      'Google Play 目前無法變更這項訂閱。請查看「管理訂閱」。';

  @override
  String get premiumPlanChangePending => 'App Store 仍在處理這項方案的購買交易，請等待處理完成。';

  @override
  String get premiumFailedLoadPlansAppStore =>
      '無法從 App Store 載入 Premium 方案，請再試一次。';

  @override
  String get premiumPurchasePreparation => '購買準備階段已逾時，請再試一次。';

  @override
  String get premiumAppStoreReturnedUnknown =>
      'App Store 回傳未知的購買結果。再次嘗試前，請先查看你的訂閱狀態。';

  @override
  String get premiumPurchasesUnavailable => '目前無法購買。';

  @override
  String get premiumAutoRenewsCancelAnytime => '自動續訂，隨時可取消。';

  @override
  String get premiumSubscribed => '已訂閱';

  @override
  String get premiumAlsoIncluded => '另包含';

  @override
  String get premiumWorldo => 'Worldo Premium';

  @override
  String get premiumPinkGems => '粉寶石';

  @override
  String get premiumRedGems => '紅寶石';

  @override
  String get premiumExtraDailyCheck => '額外每日簽到';

  @override
  String get premiumDailyCheck => '每日簽到';

  @override
  String get premiumClaimedMonthly => '每月領取';

  @override
  String get premiumBilledMonthly => '按月收費';

  @override
  String premiumSaveSavings({required String savings}) {
    return '省下 $savings%';
  }

  @override
  String get premiumSubscribe => '訂閱';

  @override
  String get premiumActiveYearlySubscription => '有效的 Premium 年繳訂閱無法改成月繳方案。';

  @override
  String get premiumAlreadyHaveActive => '你已擁有有效的 Premium 訂閱。';

  @override
  String premiumReAlreadySubscribedLabel({required String label}) {
    return '你已訂閱 Premium $label。';
  }

  @override
  String get premiumPreviousPurchasePending => '上一筆 Premium 購買交易仍在確認中。';

  @override
  String get premiumUseOriginalStoreUpgrade => '請透過原購買商店升級 Premium 訂閱。';

  @override
  String get premiumResolveCurrent => '購買前，請先到商店處理目前的訂閱。';

  @override
  String get premiumPurchaseUnavailable => '目前無法購買 Premium。';

  @override
  String get premiumUnableVerifyPurchase => '無法驗證購買資格，請再試一次。';

  @override
  String get premiumStoreFailedVerifyPurchase => '商店無法驗證這筆 Premium 購買交易。';

  @override
  String get premiumPurchaseDoesNotMatch => '這筆 Premium 購買交易與所選方案不符。';

  @override
  String get premiumMessagePurchaseCanceled => '這筆 Premium 購買交易已取消。';

  @override
  String get premiumPurchaseRevoked => '這筆 Premium 購買交易已遭撤銷。';

  @override
  String get premiumNotification => '通知';

  @override
  String get premiumWorldoActiveSubscription =>
      '你的 Worldo Premium 訂閱目前有效，不支援降級。';

  @override
  String get premiumGot => '知道了';

  @override
  String get gemBalancePromptInsufficientGems => '寶石不足';

  @override
  String get gemBalancePromptLowGems => '寶石餘額偏低';

  @override
  String get appPressBackExit => '再按一次返回鍵即可退出。';

  @override
  String get appReportSubmitted => '檢舉已送出';

  @override
  String get appReportFailed => '檢舉失敗';

  @override
  String get appUpdateRequired => '需要更新';

  @override
  String get appUpdateContent => '請更新至最新版本，才能繼續使用 Worldo。';

  @override
  String appUpdateVersion({required String versionName}) {
    return '版本 $versionName';
  }

  @override
  String get appUpdateCheckFailed => '無法更新版本檢查狀態。請更新後繼續使用。';

  @override
  String get appUpdate => '立即更新';

  @override
  String commonIdCopied({required String normalizedLabel}) {
    return '已複製 $normalizedLabel';
  }

  @override
  String get commonClose => '關閉';

  @override
  String get commonImageLoadFailed => '圖片載入失敗';

  @override
  String get commonPageNotFound => '找不到頁面。';

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
    return 'LLM 正在生成第一個 Tick，可能需要一點時間$progressDots';
  }

  @override
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  }) {
    return '最新版本：V$version$ageSuffix';
  }

  @override
  String createSaveBeforeCreating({required String missingSections}) {
    return '建立前請先儲存 $missingSections。';
  }

  @override
  String get createCharacterRoleHint => '角色在 worldo 中的身分。';

  @override
  String get createCharacterMannerHint => '角色說話與行事的方式，會影響其對話。';

  @override
  String get createCharacterGoalHint => '角色的目標或行動方向，會影響其行為。';

  @override
  String get createCharacterBackgroundHint => '角色的背景與人際關係。';

  @override
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  }) {
    return '申請加入 $world$worldIdSuffix';
  }

  @override
  String get memoryModel => '記憶與模型';

  @override
  String get premiumAccountMismatch => '帳號識別資訊與先前的訂閱不符。';

  @override
  String get worldRecap => '故事回顧';

  @override
  String get inboxMissingJoinRequestId => '缺少加入申請 ID';

  @override
  String get loginTimedOut => '登入逾時，請再試一次。';

  @override
  String get loginConnectionFailed => '無法連線，請檢查網路連線後再試一次。';

  @override
  String get loginTemporarilyUnavailable => '暫時無法登入，請稍後再試。';

  @override
  String get recapUnlockHeading => '解鎖故事回顧';

  @override
  String get recapUpsellDescription => '透過完整的故事回顧，重溫每個轉折、選擇，以及一路相伴的角色。';

  @override
  String get recapShowEarlier => '查看較早的故事回顧';

  @override
  String get recapEmpty => '隨著故事發展，這裡會顯示故事回顧。';

  @override
  String get chatMessageAsNarrator => '以旁白身分發送訊息';

  @override
  String chatMessageAsCharacter({required String name}) {
    return '以 $name 的身分發送訊息';
  }

  @override
  String get chatNarratorSpeaker => '旁白';

  @override
  String get chatYourCharacterSpeaker => '你的角色';

  @override
  String chatSpeakingAs({required String speaker}) {
    return '目前以 $speaker 的身分發言';
  }

  @override
  String get chatSwitchCharacter => '切換為角色';

  @override
  String get chatSwitchNarration => '切換為旁白';

  @override
  String chatOpenLocation({required String locationName}) {
    return '開啟 $locationName';
  }

  @override
  String get chatRetryMessage => '重試訊息';

  @override
  String get blockedReportFailed => '已封鎖使用者，但檢舉失敗。';

  @override
  String get storeConnectionFailed => '無法連線至商店，請再試一次。';

  @override
  String get storeProductUnavailable => '目前無法購買此商品。';

  @override
  String get storeDevicePurchasesUnavailable => '此裝置無法進行購買。';

  @override
  String get worldHistoryRequestFailed => '世界歷史紀錄請求失敗';

  @override
  String get genericError => '發生錯誤';

  @override
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  }) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'year': '$plan Premium，每年 $price',
      'other': '$plan Premium，每月 $price',
    });
    return '$_temp0';
  }

  @override
  String get developerClearFailed => '清除失敗';

  @override
  String get developerGatewaySignatureFailed => 'Gateway 簽章驗證失敗';

  @override
  String get developerEndpointsSaved => '已儲存，新請求將使用已設定的端點。';

  @override
  String get developerAdjustRestartRequired => '請重新啟動 App，以套用 Adjust 環境。';

  @override
  String developerRecapSetting({required String mode}) {
    return '世界故事回顧：$mode';
  }

  @override
  String get developerRecapPreview => '世界故事回顧預覽';

  @override
  String get developerRecapPreviewDescription =>
      '暫時替代世界頁面中的會員狀態與故事回顧內容，重新啟動 App 後會重設。';

  @override
  String get developerResetFailed => '重設失敗';

  @override
  String get developerRecapOff => '關閉（依會員狀態）';

  @override
  String get developerRecapLocked => '未解鎖 · 非會員';

  @override
  String get developerRecapEmpty => '會員 · 尚未產生回顧';

  @override
  String get developerRecapSample => '會員 · 範例回顧';

  @override
  String get developerRecapLive => '會員 · 實際回顧';

  @override
  String get chatEditFreeUsesExhausted => '免費編輯次數不足';

  @override
  String developerMembershipSetting({required String selection}) {
    return '會員狀態：$selection';
  }

  @override
  String get developerMembershipDescription =>
      '暫時覆寫此帳號在所有畫面中的會員狀態。伺服器仍使用帳號的實際狀態，重新啟動 App 後即恢復。';

  @override
  String get developerMembershipOff => '關閉（實際會員狀態）';

  @override
  String get developerMembershipYearly => 'Premium · 年繳';

  @override
  String get developerMembershipMonthly => 'Premium · 月繳';

  @override
  String get developerMembershipNone => '非會員';

  @override
  String get originStartBySelectingRole => '先選擇你的角色';

  @override
  String get originRecommendedStart => '建議起點';

  @override
  String get originStoryOpening => '故事開場';

  @override
  String get originOpeningLocation => '開場地點';

  @override
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names目前位於\n$locationName',
    );
    return '$_temp0';
  }

  @override
  String originOpeningJump({required String locationName}) {
    return '故事開場\n$locationName';
  }

  @override
  String get chatHistoryExpand => '展開';

  @override
  String get chatHistoryCollapse => '收合';

  @override
  String get worldHistory => '歷史紀錄';

  @override
  String get worldHistoryEmpty => '你的世界聊天紀錄會顯示在這裡。';

  @override
  String get worldHistoryContinueHere => '在這裡繼續';

  @override
  String get chatCharacterMovement => '角色移動';

  @override
  String get miniPhoneCreatePost => '建立貼文';

  @override
  String get miniPhoneCreate => '建立';

  @override
  String get miniPhonePostHint => '分享你的想法…';

  @override
  String get miniPhonePhotoOptional => '照片（選填）';

  @override
  String get miniPhoneChoosePhoto => '選擇照片';

  @override
  String get miniPhoneReplacePhoto => '更換照片';

  @override
  String get miniPhoneRemovePhoto => '移除照片';

  @override
  String get miniPhonePublish => '發布';

  @override
  String get miniPhoneViewAllComments => '查看所有留言';
}

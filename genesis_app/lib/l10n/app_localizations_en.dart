// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get miniPhoneComingSoon => 'Coming soon.';

  @override
  String get miniPhoneViewAllComments => 'View all comments';

  @override
  String get miniPhoneMessages => 'Messages';

  @override
  String get miniPhonePosts => 'Posts';

  @override
  String get miniPhonePhotos => 'Photos';

  @override
  String get miniPhoneSettings => 'Settings';

  @override
  String get miniPhoneMusic => 'Music';

  @override
  String get miniPhoneComments => 'Comments';

  @override
  String get miniPhoneCamera => 'Camera';

  @override
  String get miniPhoneMaps => 'Maps';

  @override
  String get miniPhoneCalendar => 'Calendar';

  @override
  String get miniPhonePublishedPost => 'Published a post';

  @override
  String get miniPhoneLikedPost => 'Liked a post';

  @override
  String get miniPhoneCommentedPost => 'Commented on a post';

  @override
  String get miniPhoneRepliedComment => 'Replied to a comment';

  @override
  String get miniPhonePostActivity => 'Post activity';

  @override
  String get miniPhoneShowLess => 'Show less';

  @override
  String get miniPhoneShowAll => 'Show all';

  @override
  String get miniPhoneClose => 'Close mini phone';

  @override
  String get miniPhoneYou => 'You';

  @override
  String get miniPhoneUnknown => 'Unknown';

  @override
  String miniPhoneOwnMessage({required String message}) {
    return 'You: $message';
  }

  @override
  String get miniPhonePrivateConversation => 'Private conversation';

  @override
  String get miniPhoneNewMessages => 'New messages ↓';

  @override
  String get miniPhoneReconnecting => 'Reconnecting… Waiting for confirmation';

  @override
  String miniPhoneTyping({required String name}) {
    return '$name is typing…';
  }

  @override
  String get miniPhoneSend => 'Send';

  @override
  String miniPhoneMessageHint({required String name}) {
    return 'Message $name…';
  }

  @override
  String get miniPhoneAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String miniPhoneCommentCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: '0 comments',
    );
    return '$_temp0';
  }

  @override
  String get miniPhoneFirstComment => 'Be the first to share your thoughts.';

  @override
  String get miniPhoneCommentHint => 'Write a comment…';

  @override
  String miniPhoneReplyHint({required String name}) {
    return 'Reply to $name…';
  }

  @override
  String get miniPhoneLike => 'Like';

  @override
  String get miniPhoneAllAuthors => 'All authors';

  @override
  String get miniPhoneWallpaper => 'Wallpaper';

  @override
  String get miniPhoneUpload => 'Upload';

  @override
  String get miniPhoneApplyWallpaper => 'Apply wallpaper';

  @override
  String get miniPhoneSettingsSubtitle => 'Make this phone feel like yours.';

  @override
  String get miniPhonePhotoOpenFailed =>
      'Could not open this photo. Please try another.';

  @override
  String get miniPhoneWallpaperApplied => 'Wallpaper applied. See it on Home.';

  @override
  String miniPhoneFromWorldo({required String name}) {
    return 'From $name';
  }

  @override
  String get miniPhonePreviousTrack => 'Previous track';

  @override
  String get miniPhoneNextTrack => 'Next track';

  @override
  String get miniPhonePlay => 'Play';

  @override
  String get miniPhonePause => 'Pause';

  @override
  String miniPhoneLikeTrack({required String title}) {
    return 'Like $title';
  }

  @override
  String miniPhoneUnlikeTrack({required String title}) {
    return 'Unlike $title';
  }

  @override
  String miniPhoneOpenMusic({required String title}) {
    return 'Open Music: $title';
  }

  @override
  String get miniPhonePlayMusic => 'Play music';

  @override
  String get miniPhonePauseMusic => 'Pause music';

  @override
  String miniPhoneOpenUnread({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Open Mini phone, $count unread messages',
      one: 'Open Mini phone, 1 unread message',
      zero: 'Open Mini phone, 0 unread messages',
    );
    return '$_temp0';
  }

  @override
  String miniPhoneHomePosition({required int position}) {
    return 'Home position $position';
  }

  @override
  String miniPhoneLockedApp({required String name}) {
    return '$name, locked';
  }

  @override
  String miniPhoneWorldDay({required int day}) {
    return 'Day $day';
  }

  @override
  String get miniPhoneModel => 'Model';

  @override
  String get miniPhoneLoadFailed => 'Unable to load. Please try again.';

  @override
  String get miniPhoneAccountFailed =>
      'Unable to read your account. Please try again.';

  @override
  String get miniPhoneOpenFromWorld =>
      'Sign in and open Mini phone from a World.';

  @override
  String get miniPhoneSaveMessagesFailed =>
      'Unable to save messages on this device. Please try again.';

  @override
  String get miniPhoneLoadSavedMessagesFailed =>
      'Unable to load saved messages. Please try again.';

  @override
  String get miniPhoneLoadDeviceMessagesFailed =>
      'Unable to load messages saved on this device. Please try again.';

  @override
  String get miniPhoneSaveRequestsFailed =>
      'Unable to save phone requests on this device. Please try again.';

  @override
  String get miniPhonePreviousRequestPending =>
      'The previous request is still awaiting confirmation.';

  @override
  String get miniPhoneReplyFailed => 'Reply generation failed.';

  @override
  String get miniPhonePreparePhotoFailed =>
      'Unable to prepare this photo. Please try again.';

  @override
  String get miniPhoneUploadPhotoFailed =>
      'Unable to upload this photo. Please try again.';

  @override
  String get miniPhoneTextTooLong =>
      'Phone text must not exceed 65535 UTF-8 bytes';

  @override
  String get miniPhoneLoadWallpapersFailed =>
      'Unable to load wallpapers. Please retry.';

  @override
  String get miniPhoneSaveWallpaperFailed =>
      'Unable to save wallpaper. Please retry.';

  @override
  String get miniPhoneMusicLikeFailed =>
      'Unable to update music like status. Please retry.';

  @override
  String get miniPhoneLoadMusicFailed => 'Unable to load music. Please retry.';

  @override
  String get miniPhonePlayMusicFailed =>
      'Unable to play this track. Tap play to retry.';

  @override
  String get miniPhoneInvalidResponse => 'Invalid MiniPhone response';
}

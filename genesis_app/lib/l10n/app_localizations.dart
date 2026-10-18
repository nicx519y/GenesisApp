import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'GIF animations are not supported.'**
  String get imageGifUnsupported;

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Progress complete'**
  String get worldProgressComplete;

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Switch to {label} mode'**
  String a11ySwitchMode({required String label});

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Edit {title}'**
  String a11yEditItem({required String title});

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count} role cards'**
  String a11yRoleCards({required int index, required int count});

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Edit inspiration {index}'**
  String a11yEditInspiration({required int index});

  /// Client UI message or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Insert {label}'**
  String a11yInsert({required String label});

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get a11yMembership;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Open Worldo'**
  String get a11yOpenWorldo;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Filter by gender'**
  String get a11yFilterGender;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Select Your Role'**
  String get a11ySelectRole;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Loading map'**
  String get a11yLoadingMap;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Building the world'**
  String get a11yBuildingWorld;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Premium membership'**
  String get a11yPremiumMembership;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Pro membership'**
  String get a11yProMembership;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Recommended role'**
  String get a11yRecommendedRole;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Last Message'**
  String get a11yLastMessage;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Recent chat'**
  String get a11yRecentChat;

  /// Accessibility label.
  ///
  /// In en, this message translates to:
  /// **'AI reply loading'**
  String get a11yAiReplyLoading;

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'{amount} {count, plural, =0{Message} =1{Message} other{Messages}}'**
  String statMessages({required num count, required String amount});

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'{amount} {count, plural, =0{Player} =1{Player} other{Players}}'**
  String statPlayers({required num count, required String amount});

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'{added}/{max} (Added / Max)'**
  String createAddedMax({required int added, required int max});

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get createSixHours;

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get createTwelveHours;

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get createOneDay;

  /// Localized UI label for statistics or Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get createOneWeek;

  /// Settings language entry and language page title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language preference save failure.
  ///
  /// In en, this message translates to:
  /// **'Could not change language. Please try again.'**
  String get languageChangeFailed;

  /// Gems purchase progress dialog title.
  ///
  /// In en, this message translates to:
  /// **'Purchasing Gems'**
  String get purchasingGems;

  /// Generic purchase success dialog title.
  ///
  /// In en, this message translates to:
  /// **'Purchase successful!'**
  String get purchaseSuccessful;

  /// Generic confirmation action.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okAction;

  /// Generic cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Action for requesting to join a World.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get requestAction;

  /// Status after a World join request has been sent.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requestedStatus;

  /// Action for launching a World from a Worldo.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launchAction;

  /// Action for progressing a World immediately.
  ///
  /// In en, this message translates to:
  /// **'Tick now'**
  String get tickNowAction;

  /// Placeholder for a new discussion post.
  ///
  /// In en, this message translates to:
  /// **'Write a post'**
  String get writePostHint;

  /// Title of the new discussion post composer.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPostTitle;

  /// Title of the AI generation wait overlay.
  ///
  /// In en, this message translates to:
  /// **'AI is generating'**
  String get aiIsGenerating;

  /// Message in the AI generation wait overlay.
  ///
  /// In en, this message translates to:
  /// **'Generating a live and customized world for you.\nPlease wait for a moment.'**
  String get generatingCustomizedWorldWait;

  /// Approved status for a World join request.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvedStatus;

  /// Rejected status for a World join request.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejectedStatus;

  /// Status while the user's join request is being reviewed.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get awaitingApprovalStatus;

  /// Status for a join request the user needs to review.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your approval'**
  String get awaitingYourApprovalStatus;

  /// Signed-out Me page headline.
  ///
  /// In en, this message translates to:
  /// **'LIVE YOUR WORLD'**
  String get liveYourWorld;

  /// Signed-out Me page introductory copy.
  ///
  /// In en, this message translates to:
  /// **'Play world, create worldo, invite friends,\nand continue them anywhere.'**
  String get signedOutMeDescription;

  /// Gems task guidance for launching the first World.
  ///
  /// In en, this message translates to:
  /// **'Open a Worldo you like, then Launch your own world.'**
  String get gemTaskLaunchWorldHint;

  /// Gems task guidance for inviting a friend.
  ///
  /// In en, this message translates to:
  /// **'Open a World, then tap Invite in the detail panel.'**
  String get gemTaskInviteFriendHint;

  /// Gems task guidance for writing a discussion post.
  ///
  /// In en, this message translates to:
  /// **'Open a Worldo you liked, then write a post in Discuss.'**
  String get gemTaskWriteCommentHint;

  /// Gems task guidance for requesting to join a World.
  ///
  /// In en, this message translates to:
  /// **'Open a World you haven’t joined, then request to join it.'**
  String get gemTaskRequestJoinHint;

  /// Gems task guidance for sending messages.
  ///
  /// In en, this message translates to:
  /// **'Send messages in your world.'**
  String get gemTaskSendMessageHint;

  /// Gems task guidance for progressing a World.
  ///
  /// In en, this message translates to:
  /// **'Open your playing World, then tap Tick Now.'**
  String get gemTaskProgressWorldHint;

  /// Terms of Service document title.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Worldo content-type label.
  ///
  /// In en, this message translates to:
  /// **'Worldo'**
  String get worldoLabel;

  /// Worldo profile collection tab label.
  ///
  /// In en, this message translates to:
  /// **'#Worldo'**
  String get worldoHashtagLabel;

  /// World content-type label.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get worldLabel;

  /// Generic user label and missing-name fallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userLabel;

  /// Current-user sender name fallback.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get meLabel;

  /// Missing location-name fallback.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// All option in the Worldo audience filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allLabel;

  /// Male option in the Worldo audience filter.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get maleLabel;

  /// Female option in the Worldo audience filter.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get femaleLabel;

  /// Non-binary option in the Worldo audience filter.
  ///
  /// In en, this message translates to:
  /// **'Non binary'**
  String get nonBinaryLabel;

  /// For You tab on the Worldo feed.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYouLabel;

  /// Profile collection message after a user is blocked.
  ///
  /// In en, this message translates to:
  /// **'User blocked'**
  String get userBlocked;

  /// Canceled subscription purchase result.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled.'**
  String get purchaseCanceled;

  /// Pending subscription purchase result.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is pending.'**
  String get purchasePending;

  /// Deferred subscription purchase result.
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmation is delayed. Please check again later.'**
  String get purchaseConfirmationDelayed;

  /// Generic subscription purchase failure result.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed.'**
  String get purchaseFailed;

  /// Yearly Premium plan label.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearlyPlan;

  /// Monthly Premium plan label.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyPlan;

  /// Premium subscription page tagline.
  ///
  /// In en, this message translates to:
  /// **'Go deeper into every Worldo you play.'**
  String get proSubscriptionTagline;

  /// Short End User License Agreement link label.
  ///
  /// In en, this message translates to:
  /// **'EULA'**
  String get eulaShort;

  /// Yearly Premium plan billing note.
  ///
  /// In en, this message translates to:
  /// **'{price}, Billed annually'**
  String billedAnnually({required String price});

  /// Premium membership expiry line.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresOn({required String date});

  /// Active Premium membership status.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get activeStatus;

  /// Expired Premium membership status.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredStatus;

  /// World or Worldo card last-updated line.
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String updatedAt({required String timestamp});

  /// Tick label without a number.
  ///
  /// In en, this message translates to:
  /// **'Tick'**
  String get tickLabel;

  /// Tick label with optional sub-tick suffix.
  ///
  /// In en, this message translates to:
  /// **'Tick {tick}{suffix}'**
  String tickNumber({required String tick, required String suffix});

  /// Retry action after loading more profile items fails.
  ///
  /// In en, this message translates to:
  /// **'Load failed. Retry'**
  String get loadFailedRetry;

  /// Action to load more list items.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMoreAction;

  /// Fallback title for a Gems purchase record.
  ///
  /// In en, this message translates to:
  /// **'Gem purchase'**
  String get gemPurchaseRecord;

  /// Fallback title for a Gems task reward record.
  ///
  /// In en, this message translates to:
  /// **'Task reward'**
  String get taskRewardRecord;

  /// Fallback title for a World progress Gems record.
  ///
  /// In en, this message translates to:
  /// **'World progress'**
  String get worldProgressRecord;

  /// Fallback title for a direct-message Gems record.
  ///
  /// In en, this message translates to:
  /// **'Direct message'**
  String get directMessageRecord;

  /// Generic fallback title for a Gems record.
  ///
  /// In en, this message translates to:
  /// **'Gem record'**
  String get gemRecord;

  /// Gems task title for progressing a World.
  ///
  /// In en, this message translates to:
  /// **'Run a Tick'**
  String get runATickTask;

  /// Gems task instructions for progressing a World.
  ///
  /// In en, this message translates to:
  /// **'Open one of your playing Worlds and tap Tick Now.'**
  String get runATickTaskDescription;

  /// Missing player-name fallback.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someoneFallback;

  /// Missing character-name fallback inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'a character'**
  String get aCharacterFallback;

  /// Missing World-name fallback inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'this World'**
  String get thisWorld;

  /// World character events empty state.
  ///
  /// In en, this message translates to:
  /// **'No world events yet.'**
  String get noWorldEventsYet;

  /// Global section label in copied Tick content.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get globalLabel;

  /// Event section label in copied Tick content.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventLabel;

  /// Character movement section label in copied Tick content.
  ///
  /// In en, this message translates to:
  /// **'Character destinations'**
  String get characterDestinations;

  /// Character movement sentence with styled or copied parts.
  ///
  /// In en, this message translates to:
  /// **'{characterName} {direction} {locationName}'**
  String characterMovementSentence({
    required String characterName,
    required String direction,
    required String locationName,
  });

  /// Character movement direction in past tense.
  ///
  /// In en, this message translates to:
  /// **'came to'**
  String get cameToDirection;

  /// Character movement direction away in past tense.
  ///
  /// In en, this message translates to:
  /// **'went to'**
  String get wentToDirection;

  /// Character movement direction for the current location.
  ///
  /// In en, this message translates to:
  /// **'has come to'**
  String get hasComeToDirection;

  /// Character movement direction away from the current location.
  ///
  /// In en, this message translates to:
  /// **'has gone to'**
  String get hasGoneToDirection;

  /// Direct-message composer gate while awaiting a reply.
  ///
  /// In en, this message translates to:
  /// **'Wait for a reply to send more'**
  String get waitForReplyToSendMore;

  /// Count of new direct messages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new message} other{{count} new messages}}'**
  String newMessages({required int count});

  /// Role launch validation message.
  ///
  /// In en, this message translates to:
  /// **'Please select a preset role'**
  String get selectPresetRoleValidation;

  /// Character-name validation message.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get enterNameValidation;

  /// Character-identity validation message.
  ///
  /// In en, this message translates to:
  /// **'Please enter an identity'**
  String get enterIdentityValidation;

  /// Role launch message while profile data is loading.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the profile to finish loading.'**
  String get waitForProfileLoading;

  /// Image upload failure shown in the Worldo editor.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed.'**
  String get imageUploadFailed;

  /// Discussion image picker permission error.
  ///
  /// In en, this message translates to:
  /// **'Photo access denied'**
  String get photoAccessDenied;

  /// Settings feedback submission success.
  ///
  /// In en, this message translates to:
  /// **'Feedback submitted'**
  String get feedbackSubmitted;

  /// Settings feedback submission failure.
  ///
  /// In en, this message translates to:
  /// **'Feedback failed'**
  String get feedbackFailed;

  /// Worldo editor load failure fallback.
  ///
  /// In en, this message translates to:
  /// **'Worldo detail is unavailable.'**
  String get worldoDetailUnavailable;

  /// Publish Worldo action.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishAction;

  /// Worldo publishing progress label.
  ///
  /// In en, this message translates to:
  /// **'Publishing...'**
  String get publishingStatus;

  /// Worldo publishing failure prefix.
  ///
  /// In en, this message translates to:
  /// **'Publish failed'**
  String get publishFailed;

  /// Worldo editor leave confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Publish changes before leaving?'**
  String get publishChangesBeforeLeaving;

  /// Worldo editor submit-disabled message.
  ///
  /// In en, this message translates to:
  /// **'No changes to publish.'**
  String get noChangesToPublish;

  /// Worldo editor validation error before publishing.
  ///
  /// In en, this message translates to:
  /// **'A complete Opening is required to publish'**
  String get completeOpeningRequiredToPublish;

  /// Worldo editor publishing response error.
  ///
  /// In en, this message translates to:
  /// **'Publishing did not return a Worldo ID.'**
  String get publishResponseMissingOriginId;

  /// Worldo editor cannot load without an ID.
  ///
  /// In en, this message translates to:
  /// **'A Worldo ID is required.'**
  String get worldoIdRequired;

  /// Load failure with a technical reason.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {reason}'**
  String loadFailedWithReason({required String reason});

  /// Discussion image picker generic failure.
  ///
  /// In en, this message translates to:
  /// **'Image selection failed'**
  String get imageSelectionFailed;

  /// Worldo summary in another user's profile.
  ///
  /// In en, this message translates to:
  /// **'OID: {oid}\nLatest Version: {version}'**
  String profileOriginSubtitle({required String oid, required String version});

  /// World summary in another user's profile.
  ///
  /// In en, this message translates to:
  /// **'WID: {wid}\nOwner: {owner}'**
  String profileWorldSubtitle({required String wid, required String owner});

  /// Direct-message send failure.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get sendFailed;

  /// Role picker empty selection label.
  ///
  /// In en, this message translates to:
  /// **'Select a role'**
  String get selectARole;

  /// Sender name for a World timeline message.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// Worldo identifier in a discussion page summary.
  ///
  /// In en, this message translates to:
  /// **'OID: {oid}'**
  String discussOriginSummary({required String oid});

  /// Worldo identifier and creator in a discussion page summary.
  ///
  /// In en, this message translates to:
  /// **'OID: {oid} · Creator: {creator}'**
  String discussOriginSummaryWithCreator({
    required String oid,
    required String creator,
  });

  /// Worldo Metric field explanation with literal field-name braces.
  ///
  /// In en, this message translates to:
  /// **'This worldo updates each character\'\'s \'{Metric Label}\' every progress, shown in \'{Unit}\'. Each character starts at \'{Starting}\', and the value can move within \'{Delta Min}\'–\'{Delta Max}\'.'**
  String get worldoMetricExplanation;

  /// Home My Worlds empty-state title.
  ///
  /// In en, this message translates to:
  /// **'Launch a {worldo} to generate\nyour own World'**
  String homeMyWorldsEmptyTitle({required String worldo});

  /// Estimated Gems cost under an AI model option.
  ///
  /// In en, this message translates to:
  /// **'Estimated next message {cost}'**
  String memoryEstimatedNextMessageCost({required String cost});

  /// A formatted amount followed by the Gems unit.
  ///
  /// In en, this message translates to:
  /// **'{amount} Gems'**
  String gemsAmount({required String amount});

  /// World deletion confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete world {worldName}'**
  String worldDeleteConfirmation({required String worldName});

  /// World detail notice describing a player's character.
  ///
  /// In en, this message translates to:
  /// **'{playerUsername} playing as {characterName}'**
  String worldPlayerPlayingAs({
    required String playerUsername,
    required String characterName,
  });

  /// Success dialog after launching a Worldo.
  ///
  /// In en, this message translates to:
  /// **'Worldo {worldName} launched!'**
  String worldoLaunched({required String worldName});

  /// Success dialog after creating a Worldo.
  ///
  /// In en, this message translates to:
  /// **'Worldo {worldName} created!'**
  String worldoCreated({required String worldName});

  /// Success dialog after publishing a Worldo.
  ///
  /// In en, this message translates to:
  /// **'Worldo {worldName} published!'**
  String worldoPublished({required String worldName});

  /// Create Worldo 提交后等待创建结果超时的提示
  ///
  /// In en, this message translates to:
  /// **'Worldo creation timed out.'**
  String get createTimeout;

  /// Publish Worldo 提交后等待发布结果超时的提示
  ///
  /// In en, this message translates to:
  /// **'Worldo publishing timed out'**
  String get publishTimeout;

  /// Inbox summary for the current user's World join request.
  ///
  /// In en, this message translates to:
  /// **'You requested to join {worldName}{worldId}'**
  String joinRequestSelfSummary({
    required String worldName,
    required String worldId,
  });

  /// Inbox summary for another user's World join request.
  ///
  /// In en, this message translates to:
  /// **'{requesterName}{requesterBadge} requested to join {worldName}{worldId}'**
  String joinRequestIncomingSummary({
    required String requesterName,
    required String requesterBadge,
    required String worldName,
    required String worldId,
  });

  /// Inbox comment notification title.
  ///
  /// In en, this message translates to:
  /// **'{senderName}{senderBadge} commented on your worldo'**
  String notificationCommentedOnWorldo({
    required String senderName,
    required String senderBadge,
  });

  /// Inbox reply notification title.
  ///
  /// In en, this message translates to:
  /// **'{senderName}{senderBadge} replied to you'**
  String notificationRepliedToYou({
    required String senderName,
    required String senderBadge,
  });

  /// Inbox comment-like notification title.
  ///
  /// In en, this message translates to:
  /// **'{senderName}{senderBadge} liked your comment'**
  String notificationLikedComment({
    required String senderName,
    required String senderBadge,
  });

  /// Inbox generic message notification title.
  ///
  /// In en, this message translates to:
  /// **'{senderName}{senderBadge} sent you a message'**
  String notificationSentMessage({
    required String senderName,
    required String senderBadge,
  });

  /// Inbox notification title using content supplied by the server.
  ///
  /// In en, this message translates to:
  /// **'{senderName}{senderBadge} {content}'**
  String notificationGenericContent({
    required String senderName,
    required String senderBadge,
    required String content,
  });

  /// Location chat free Inspiration quota prompt.
  ///
  /// In en, this message translates to:
  /// **'Free inspiration uses left: {remaining}\n{action}'**
  String freeInspirationUsesLeft({
    required String remaining,
    required String action,
  });

  /// Location chat free Edit quota prompt.
  ///
  /// In en, this message translates to:
  /// **'Free Edition uses left: {remaining}\n{action}'**
  String freeEditionUsesLeft({
    required String remaining,
    required String action,
  });

  /// Action that opens subscription options.
  ///
  /// In en, this message translates to:
  /// **'Get more >'**
  String get getMoreAction;

  /// Location chat system message for entering a location.
  ///
  /// In en, this message translates to:
  /// **'{characterName} came to {locationName}'**
  String characterCameToLocation({
    required String characterName,
    required String locationName,
  });

  /// About page product description and contact sentence.
  ///
  /// In en, this message translates to:
  /// **'Worldo lets you create, discover, and enter AI-powered worlds filled with characters, stories, and evolving events. Chat with AI characters, play with friends, and progress each world through immersive scenes and choices.\n\nOur app offers a new way to experience interactive stories — not just as a reader, but as someone inside the world. If you have any questions, please contact us at {contactEmail}.'**
  String aboutDescription({required String contactEmail});

  /// About page legal-document links.
  ///
  /// In en, this message translates to:
  /// **'{privacyPolicy} , {termsOfUse} and {endUserLicenseAgreement}'**
  String legalLinksSentence({
    required String privacyPolicy,
    required String termsOfUse,
    required String endUserLicenseAgreement,
  });

  /// Legal agreement below login provider buttons.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our {terms}, {privacyPolicy}, and {endUserLicenseAgreement}'**
  String loginLegalAgreement({
    required String terms,
    required String privacyPolicy,
    required String endUserLicenseAgreement,
  });

  /// Privacy Policy document title.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Short Terms document title.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// Terms of Use document title.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// End User License Agreement document title.
  ///
  /// In en, this message translates to:
  /// **'End User License Agreement'**
  String get endUserLicenseAgreement;

  /// Personalization sheet sign-in sentence.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? {signIn}'**
  String existingAccountSignIn({required String signIn});

  /// Sign-in link label inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'Sign in.'**
  String get signInAction;

  /// Gems purchase success message.
  ///
  /// In en, this message translates to:
  /// **'{gemIcon}{grantedAmount} Gems have been granted.'**
  String gemsGranted({required String gemIcon, required String grantedAmount});

  /// Premium offer shown on the profile membership card.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount} Gems monthly, plus full premium access.'**
  String premiumMonthlyOffer({required String amount});

  /// Daily Gems amount in a subscription benefit card.
  ///
  /// In en, this message translates to:
  /// **'{amount} /day'**
  String gemsPerDay({required String amount});

  /// Monthly equivalent subscription price.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String monthlyPrice({required String price});

  /// Discussion reply preview that replies to another user.
  ///
  /// In en, this message translates to:
  /// **'{authorName}{authorBadge}: Reply to {replyToName}{replyToBadge}: {content}'**
  String discussReplyLine({
    required String authorName,
    required String authorBadge,
    required String replyToName,
    required String replyToBadge,
    required String content,
  });

  /// Discussion reply preview without a reply target.
  ///
  /// In en, this message translates to:
  /// **'{authorName}{authorBadge}: {content}'**
  String discussReplyLineDirect({
    required String authorName,
    required String authorBadge,
    required String content,
  });

  /// App shell bottom navigation: fixed English label "Home" in every language. Do not translate. Inbox and Me page headings share these labels and also stay English.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// App shell bottom navigation: fixed English label "Worldo" in every language. Do not translate. Inbox and Me page headings share these labels and also stay English.
  ///
  /// In en, this message translates to:
  /// **'Worldo'**
  String get navWorldo;

  /// App shell bottom navigation: fixed English label "Create" in every language. Do not translate. Create is icon-only; this text is its accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// App shell bottom navigation: fixed English label "Inbox" in every language. Do not translate. Inbox and Me page headings share these labels and also stay English.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// App shell bottom navigation: fixed English label "Me" in every language. Do not translate. Inbox and Me page headings share these labels and also stay English.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navMe;

  /// 首页 - Home，My Worlds 列表状态
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get homeLoadFailed;

  /// 首页 - Home，My Worlds 列表状态
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;

  /// 首页 - Home，My Worlds 空状态
  ///
  /// In en, this message translates to:
  /// **'Worldo is the blueprint. Launch to create a live World you can enter and grow.'**
  String get homeEmptyDescription;

  /// 首页 - Home，World 卡片中的状态信息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get homeWorldCharacter;

  /// 首页 - Home，World 卡片中的状态信息的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'· 1 other Player'**
  String get homeWorldSingleOtherPlayer;

  /// 首页 - Home，World 卡片中的状态信息的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'· {otherPlayerCount} other Players'**
  String homeWorldOtherPlayers({required String otherPlayerCount});

  /// 首页 - Home，登录失败提示
  ///
  /// In en, this message translates to:
  /// **'Sign-in unavailable'**
  String get homeSignInUnavailable;

  /// 首页 - Home，页面标题/登录状态
  ///
  /// In en, this message translates to:
  /// **'Your worlds, all in one place'**
  String get homeSignedOutTitle;

  /// 首页 - Home，页面标题/登录状态
  ///
  /// In en, this message translates to:
  /// **'Sign in to create worlds and continue your stories.'**
  String get homeSignedOutDescription;

  /// 首页 - Home → 搜索页，搜索结果卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'UID: '**
  String get searchUID;

  /// 首页 - Home → 搜索页，Worldo 结果元信息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'OID: '**
  String get searchOID;

  /// 首页 - Home → 搜索页，World 结果元信息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'WID: '**
  String get searchWID;

  /// 首页 - Home → 搜索页，World 结果元信息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Owner: {owner}'**
  String searchOwner({required String owner});

  /// 首页 - Home → 搜索页，Worldo 搜索结果卡片的 OID、创建者、简介和最新版本
  ///
  /// In en, this message translates to:
  /// **'OID: {oid}  Creator: {originator}\nBrief: {brief}\nLatest Version: {version}'**
  String searchOIDCreatorOriginatorBrief({
    required String oid,
    required String originator,
    required String brief,
    required String version,
  });

  /// 首页 - Home → 搜索页，World 搜索结果卡片的 WID 和拥有者
  ///
  /// In en, this message translates to:
  /// **'WID: {wid}\nOwner: {owner}'**
  String searchWIDOwner({required String wid, required String owner});

  /// 首页 - Home → 搜索页，搜索历史中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistory;

  /// 首页 - Home → 搜索页，搜索结果列表/空状态
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// 首页 - Home → 搜索页，搜索结果列表/空状态
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get searchNoResults;

  /// 首页 - Home → 搜索页，搜索输入与结果状态
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get searchCancel;

  /// 首页 - Home → 搜索页，搜索输入框中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Worldo, Character, Tags'**
  String get searchHint;

  /// 首页 - Home → World 操作弹窗，World 详情页删除 World时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Only worlds launched by you alone can be deleted.'**
  String get worldDetailOnlyWorldsLaunched;

  /// 首页 - Home → World 操作弹窗，World 详情页删除 World的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get worldDetailDelete;

  /// 首页 - Home → World 详情页，World 详情面板的 Cast 或 Status 空状态
  ///
  /// In en, this message translates to:
  /// **'No character status yet.'**
  String get worldDetailNoCharacterStatusYet;

  /// 首页 - Home → World 详情页，World 详情面板的 Cast 或 Status 空状态
  ///
  /// In en, this message translates to:
  /// **'No characters yet.'**
  String get worldDetailNoCharactersYet;

  /// 首页 - Home → World 详情页，World 详情页主体中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Progressing the World'**
  String get worldDetailProgressingWorld;

  /// 首页 - Home → World 详情页，World 详情页主体中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Compressing recent memories\nAdvancing the world timeline\nGenerating the next story beat\nUpdating character locations'**
  String get worldDetailCompressingRecent;

  /// 首页 - Home → World 详情页，World 详情页的操作状态
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get worldModelsDetail;

  /// 首页 - Home → World 详情页，World 详情页的操作状态
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get worldModelsLocations;

  /// 首页 - Home → World 详情页，World 详情页的操作状态
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get worldModelsEvents;

  /// 首页 - Home → World 详情页，World 详情页的操作状态
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get worldModelsStatus;

  /// 首页 - Home → World 详情页，World 详情页的操作状态
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get worldDetailUnavailable;

  /// 首页 - Home → World 详情页，申请加入或推进操作失败时的提示
  ///
  /// In en, this message translates to:
  /// **'{actionLabel} failed'**
  String worldActionFailed({required String actionLabel});

  /// 首页 - Home → World 详情页的推进或加入操作，World 详情页申请加入或推进 World的标题
  ///
  /// In en, this message translates to:
  /// **'Request to join this World?'**
  String get worldDetailRequestJoinWorld;

  /// 首页 - Home → World 详情页的推进或加入操作，World 详情页申请加入或推进 World的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get worldDetailRequest;

  /// 首页 - Home → World 详情页的推进或加入操作，World 详情页申请加入或推进 World时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Launch failed'**
  String get worldDetailLaunchFailed;

  /// 首页 - Home → World 详情页的推进或加入操作，World 详情页申请加入或推进 World时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No saved profile found'**
  String get worldDetailNoSavedProfileFound;

  /// 首页 - Home → World 详情页，World 详情页的 Detail 区域的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'WID'**
  String get worldDetailWID;

  /// 首页 - Home → World 详情页，World 详情页的 Detail 区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Source Worldo: {sourceOid} · V{version}'**
  String worldDetailSourceWorldoOIDV({
    required String sourceOid,
    required String version,
  });

  /// 首页 - Home → World 详情页，World 详情页的 Detail 区域的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get worldDetailInvite;

  /// 首页 - Home → World 详情页，点击 Invite 后系统分享面板中的邀请正文
  ///
  /// In en, this message translates to:
  /// **'Join my world \"{worldName}\" on Worldo!\n{wid}\nSearch this WID on Worldo to find and join.\n{downloadUrl}'**
  String worldInviteText({
    required String worldName,
    required String wid,
    required String downloadUrl,
  });

  /// 首页 - Home → World 详情页，World 详情页的 Detail 区域的标题
  ///
  /// In en, this message translates to:
  /// **'World Brief'**
  String get worldDetailWorldBrief;

  /// 首页 - Home → World 详情页，World 详情页的 Detail 区域的标题
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get worldDetailCast;

  /// 首页 - Home → World 详情页，World 详情页复制邀请链接完成
  ///
  /// In en, this message translates to:
  /// **'Link copied. Share it with your friends.'**
  String get worldDetailLinkCopiedShare;

  /// 首页 - Home → World 地图，World 地图顶部操作栏中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get worldMapAction;

  /// 首页 - Home → World 地图，World 地图顶部操作栏中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Info.'**
  String get worldInfoAction;

  /// 首页 - Home → World 地图，World 地图顶部操作栏中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Location ({pointsCount})'**
  String worldLocationCount({required String pointsCount});

  /// 首页 - Home → World 详情页，World 详情页的 Characters 角色列表的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get worldDetailPlayer;

  /// 首页 - Home → World 详情页，World 详情页的 Characters 角色列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal}'**
  String worldDetailGoal({required String goal});

  /// 首页 - Home → World 详情页，World 详情页的 Characters 角色列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No character details yet.'**
  String get worldDetailNoCharacterDetailsYet;

  /// 首页 - Home → World 详情页，World 详情页的 Events 事件列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get worldDetailNoEventsYet;

  /// 首页 - Home → World 详情页，World 详情页的 Events 事件列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Load events failed.'**
  String get worldDetailLoadEventsFailed;

  /// 首页 - Home → World 地图，World 地图地点名称缺失中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Location {id}'**
  String homeLocationID({required String id});

  /// 首页 - Home → World 地图，列表项或卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'BUILDING THE WORLD'**
  String get homeBuildingWorld;

  /// 首页 - Home → World 地图，操作失败或内容加载失败
  ///
  /// In en, this message translates to:
  /// **'Map failed to load'**
  String get worldMapLoadFailed;

  /// 首页 - Home → World 地图，页面内容区域的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Zoom in on map'**
  String get worldMapZoomIn;

  /// 首页 - Home → World 地图，页面内容区域的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Zoom out of map'**
  String get worldMapZoomOut;

  /// 首页 - Home → World Tick 卡片，World 详情页的 Tick 事件卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get worldDetailGlobal;

  /// 首页 - Home → World Tick 卡片，World 详情页的 Tick 事件卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get worldDetailLocation;

  /// 首页 - Home → World 详情页，World 详情页尚未完成的 Tick 卡片的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Tick {tickNumber}'**
  String worldDetailTickNumber({required String tickNumber});

  /// 首页 - Home → 首次 Tick 等待弹窗，首次 Tick 生成中的等待弹窗
  ///
  /// In en, this message translates to:
  /// **'Generating first tick'**
  String get homeGeneratingFirstTick;

  /// 首页 - Home → 首次 Tick 等待弹窗，首次 Tick 生成中的等待弹窗
  ///
  /// In en, this message translates to:
  /// **'Generation status could not be loaded.'**
  String get worldFirstTickStatusLoadFailed;

  /// 首页 - Home → World 新内容标记，World 详情页的新内容标记中显示的文字
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get worldDetailNew;

  /// 首页 - Home → World 更新通知，World 更新后顶部出现的通知条中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get homeUnknownLocation;

  /// 首页 - Home → World 更新通知，World 更新后顶部出现的通知条中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Unknown character'**
  String get homeUnknownCharacter;

  /// 首页 - Home → World 更新通知，World 更新后顶部出现的通知条中显示的文字
  ///
  /// In en, this message translates to:
  /// **'New Place Emerged'**
  String get homeNewPlaceEmerged;

  /// 首页 - Home → World 更新通知，World 更新后顶部出现的通知条中显示的文字
  ///
  /// In en, this message translates to:
  /// **'New Character Appeared'**
  String get homeNewCharacterAppeared;

  /// 首页 - Home → World 地图进入地点，从 World 地图进入地点聊天室时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Location is unavailable'**
  String get chatLocationUnavailable;

  /// 首页 - Home → World 地图进入地点，从 World 地图进入地点聊天室时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Request approval to launch'**
  String get chatRequestApprovalLaunch;

  /// 首页 - Home → World 地图进入地点，进入 World 地点聊天室的加载页面中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get chatLoading;

  /// 首页 - Home → 地点聊天室 - Inspiration，AI 回复功能剩余次数不足
  ///
  /// In en, this message translates to:
  /// **'Could not check free uses. Please try again.'**
  String get chatQuotaCheckFailed;

  /// 首页 - Home → 地点聊天室 - 回复操作，使用 Inspiration 生成回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The inspiration source changed. Please reopen inspiration.'**
  String get chatInspirationSourceChanged;

  /// 首页 - Home → 地点聊天室 - 回复操作，使用 Inspiration 生成回复的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Inspiration'**
  String get chatInspiration;

  /// 首页 - Home → 地点聊天室 - 回复操作，地点聊天室发送消息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This message can no longer be sent'**
  String get chatMessageCannotSend;

  /// 首页 - Home → 地点聊天室 - 回复操作，地点聊天室发送消息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The message is empty'**
  String get chatMessageEmpty;

  /// 首页 - Home → 地点聊天室 - 回复操作，地点聊天室发送消息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Could not connect to this chat'**
  String get chatConnectionFailed;

  /// 首页 - Home → 地点聊天室 - 回复操作，地点聊天室发送消息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The reply changed. Please select inspiration again.'**
  String get chatReplyChangedSelect;

  /// 首页 - Home → 地点聊天室 - 回复操作，地点聊天室发送消息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the message send'**
  String get chatSendConfirmFailed;

  /// 首页 - Home → 地点聊天室 - 回复操作，地点聊天室发送消息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No network connection'**
  String get chatNoNetworkConnection;

  /// 首页 - Home → 地点聊天室 - 回复操作，点击 Go On 继续生成回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This round cannot continue'**
  String get chatRoundCannotContinue;

  /// 首页 - Home → 地点聊天室 - 回复操作，点击 Go On 继续生成回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The source round changed'**
  String get chatSourceRoundChanged;

  /// 首页 - Home → 地点聊天室 - 回复操作，点击 Go On 继续生成回复的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Go on'**
  String get chatGo;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This reply action is no longer available'**
  String get chatReplyActionUnavailable;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Regenerate failure'**
  String get chatRegenerateFailure;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Go on failure'**
  String get chatGoFailure;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Edit failure'**
  String get chatEditFailure;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Inspiration failure'**
  String get chatInspirationFailure;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Failed to join this location'**
  String get chatJoinLocationFailed;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This chat is no longer active'**
  String get chatInactive;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Chatroom is unavailable'**
  String get chatChatroomUnavailable;

  /// 首页 - Home → 地点聊天室 - 回复操作，生成 AI 回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the reply action'**
  String get chatFailedConfirmReplyAction;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'At least one message must remain.'**
  String get chatLeastOneMessageMustRemain;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This reply is not editable'**
  String get chatReplyNotEditable;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This reply has been fixed'**
  String get chatReplyAlreadyFixed;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Reply editor is frozen'**
  String get chatReplyEditorFrozen;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Resolve the previous save before changing its draft'**
  String get chatResolvePreviousSaveBefore;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Stale reply editor'**
  String get chatStaleReplyEditor;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The previous save result is uncertain; reload before editing again'**
  String get chatPreviousSaveResultUncertain;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The candidate no longer exists'**
  String get chatCandidateMissing;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'A batch supports at most 100 changes'**
  String get chatBatchSupportsMost100Changes;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Missing stable message identity'**
  String get chatMissingStableMessageIdentity;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The edit target has changed'**
  String get chatEditTargetHasChanged;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This message cannot be edited'**
  String get chatMessageNotEditable;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This reply is no longer editable'**
  String get chatReplyNoLongerEditable;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The editor could not be opened'**
  String get chatEditorOpenFailed;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This chat is no longer active.'**
  String get chatInactiveDuringEdit;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复页面的标题
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get chatEditMessage;

  /// 首页 - Home → 地点聊天室 - 回复操作，编辑聊天回复页面的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatSave;

  /// 首页 - Home → 地点聊天室 - 回复操作，聊天回复旁的 Edit 按钮
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEdit;

  /// 首页 - Home → 地点聊天室 - 回复操作，聊天回复旁的 Regenerate 按钮
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatRegenerate;

  /// 首页 - Home → 地点聊天室 - 回复操作，重新生成聊天回复中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This round cannot be regenerated'**
  String get chatRegenerateUnavailable;

  /// 首页 - Home → 地点聊天室 - 回复操作，重新生成聊天回复时显示的提示
  ///
  /// In en, this message translates to:
  /// **'You can generate up to 10 replies.'**
  String get chatGenerate10Replies;

  /// 首页 - Home → 地点聊天室，AI 回复的翻页按钮
  ///
  /// In en, this message translates to:
  /// **'Previous reply'**
  String get chatPreviousReply;

  /// 首页 - Home → 地点聊天室，AI 回复的翻页按钮
  ///
  /// In en, this message translates to:
  /// **'Next reply'**
  String get chatNextReply;

  /// 首页 - Home → 地点聊天室，地点聊天室长按消息后的操作菜单的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// 首页 - Home → 地点聊天室，地点聊天室长按消息后的操作菜单的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// 首页 - Home → 地点聊天室，地点聊天室复制消息完成
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// 首页 - Home → 地点聊天室，地点聊天室收到新消息时的提示条中显示的文字
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new message} other{{count} new messages}}'**
  String chatCountNewMessage({required int count});

  /// 首页 - Home → 地点聊天室，地点聊天室的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Mention'**
  String get chatMention;

  /// 首页 - Home → 地点聊天室，地点聊天室的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get chatCharacters;

  /// 首页 - Home → 地点聊天室，地点聊天室的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No characters'**
  String get chatNoCharacters;

  /// 首页 - Home → 地点聊天室，地点聊天室的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No locations'**
  String get chatNoLocations;

  /// 首页 - Home → 地点聊天室，地点聊天室消息中的当前位置标记中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get chatHere;

  /// 首页 - Home → 地点聊天室，地点聊天室消息列表的加载状态
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get chatLoadEarlierMessages;

  /// 首页 - Home → 地点聊天室，地点聊天室消息输入区域的输入框提示
  ///
  /// In en, this message translates to:
  /// **'Text...'**
  String get chatText;

  /// 首页 - Home → 地点聊天室，地点聊天室顶部的角色列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get chatLocationRoster;

  /// 首页 - Home → 聊天消息，聊天消息中的角色头像中显示的文字
  ///
  /// In en, this message translates to:
  /// **'NPC'**
  String get homeNpc;

  /// 首页 - Home → 聊天页 - AI 内容免责声明，聊天消息下方的 AI 内容免责声明中显示的文字
  ///
  /// In en, this message translates to:
  /// **'All content is AI-generated and fictional. Any resemblance to real people, events, or places is coincidental.'**
  String get commonAiDisclaimer;

  /// 首页 - Home → 聊天页 - 最近消息标记，聊天室最近消息标记中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecent;

  /// 首页 - Worldo，Worldo 列表页的性别筛选菜单时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to save your preference. Please try again.'**
  String get worldoUnableSavePreference;

  /// 首页 - Worldo，Worldo 列表页的性别筛选菜单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Filter by gender'**
  String get worldoFilterGender;

  /// 首页 - Worldo，Worldo 列表的加载和空状态
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get worldoNoData;

  /// 首页 - Me → Gems 钱包 → Gems 明细页，顶部记录筛选栏的 All 选项
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get worldoAll;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情面板的基础信息中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Select your role'**
  String get worldoDetailSelectRole;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情面板顶部信息的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'OID'**
  String get worldoDetailOID;

  /// 首页 - Home → 搜索结果的 Worldo 卡片，创建者名称；首页 - Worldo → Worldo 详情面板，创建者名称
  ///
  /// In en, this message translates to:
  /// **'Creator: {creatorName}'**
  String worldoDetailCreator({required String creatorName});

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情面板中的编辑入口的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Edit Worldo'**
  String get worldoDetailEditWorldo;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的 World 区域的标题
  ///
  /// In en, this message translates to:
  /// **'Worldo Brief'**
  String get worldoDetailWorldoBrief;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的 Discuss 区域的标题
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get worldoDetailNewPost;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的 Discuss 区域的输入框提示
  ///
  /// In en, this message translates to:
  /// **'Write a post'**
  String get worldoDetailWritePost;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的 Discuss 区域的标题
  ///
  /// In en, this message translates to:
  /// **'Discuss ({discussCount})'**
  String worldoDetailDiscussCount({required String discussCount});

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的 Discuss 区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'View all >'**
  String get worldoDetailViewAll;

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的已创建 World 列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Playing World'**
  String get worldoDetailPlayingWorld;

  /// 首页 - Worldo → 已创建 World 列表，World 项的 Tick 编号和消息数量
  ///
  /// In en, this message translates to:
  /// **'Tick {tickCount}{subTickLabel} · {messageCountLabel}'**
  String worldoDetailTickCountSubLabel({
    required String tickCount,
    required String subTickLabel,
    required String messageCountLabel,
  });

  /// 首页 - Worldo → Worldo 详情页，Worldo 详情页的角色列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Characters ({length})'**
  String worldoDetailCharactersLength({required String length});

  /// 首页 - Worldo → 发帖弹窗，发布 Discuss 帖子中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get worldoSend;

  /// 首页 - Worldo → 发帖弹窗，发布 Discuss 帖子时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Post failed'**
  String get worldoPostFailed;

  /// 首页 - Worldo → 发帖弹窗，发布 Discuss 帖子时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get worldoImageUploadFailed;

  /// 首页 - Worldo → 帖子详情页，帖子详情页的回复列表时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Load replies failed'**
  String get worldoLoadRepliesFailed;

  /// 首页 - Worldo → 帖子详情页，回复评论时的输入框的输入框提示
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get worldoWriteReply;

  /// 首页 - Worldo → 帖子详情页，回复评论时的输入框的输入框提示
  ///
  /// In en, this message translates to:
  /// **'Reply to {replyToName}'**
  String worldoReplyName({required String replyToName});

  /// 首页 - Worldo → 帖子详情页，帖子详情页中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Post Detail'**
  String get worldoPostDetail;

  /// 首页 - Worldo → 帖子详情页，帖子详情页中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Post unavailable'**
  String get worldoPostUnavailable;

  /// 首页 - Worldo → 帖子详情页，帖子详情页的回复列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'All Replies {replyCount}'**
  String worldoAllRepliesReplyCount({required String replyCount});

  /// 首页 - Worldo → 帖子详情页，回复列表底部的查看全部回复按钮
  ///
  /// In en, this message translates to:
  /// **'View all {replyCount} replies'**
  String worldoViewAllReplies({required String replyCount});

  /// 首页 - Worldo → 帖子详情页，帖子详情页时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Like failed'**
  String get worldoLikeFailed;

  /// 首页 - Worldo → 讨论/回复区，Discuss 帖子的评论和回复区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'View all {replyCount} replies'**
  String worldoViewAllReplyCountReplies({required String replyCount});

  /// 首页 - Worldo → 讨论/回复区，Discuss 帖子的评论和回复区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get worldoUser;

  /// 首页 - Worldo → 讨论/回复区，Discuss 帖子的评论和回复区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'View More >'**
  String get worldoViewMore;

  /// 首页 - Worldo → Worldo 讨论区，Discuss 入口旁的数量
  ///
  /// In en, this message translates to:
  /// **'Discuss ({discussCount})'**
  String worldoDiscuss({required String discussCount});

  /// 首页 - Worldo → 讨论/回复区，Discuss 帖子的评论和回复区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'View all {remainingReplyCount} replies'**
  String worldoViewAllRemainingReplyCount({
    required String remainingReplyCount,
  });

  /// 首页 - Worldo → 讨论/回复区，Discuss 帖子的评论和回复区域的标题
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get worldoReply;

  /// 首页 - Worldo → 讨论列表页，Discuss 讨论列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Discuss'**
  String get worldoDiscussTitle;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时的开场消息和角色选择中显示的文字
  ///
  /// In en, this message translates to:
  /// **'This location comes to life after launch.'**
  String get worldoLaunchLocationComesLife;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时的开场消息和角色选择中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Launch this Worldo to explore and interact here.'**
  String get worldoLaunchLaunchWorldoExplore;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时的开场消息和角色选择时显示的提示
  ///
  /// In en, this message translates to:
  /// **'This role is no longer available'**
  String get worldoLaunchRoleUnavailable;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Select Your Role'**
  String get worldoLaunchSelectRole;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get worldoLaunchProfile;

  /// Worldo detail sheet: top-right button on the Your Profile card while inline editing. Confirms the role draft for this Worldo and exits editing; does not update the account profile. Keep this completion action short.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get worldoLaunchDone;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get worldoLaunchSuggested;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get worldoLaunchName;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get worldoLaunchIdentity;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Personality'**
  String get worldoLaunchPersonality;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 时选择或编辑角色的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get worldoLaunchGoal;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板的标题
  ///
  /// In en, this message translates to:
  /// **'Setup Your Role'**
  String get worldoLaunchSetupRole;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get worldoLaunchPreset;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get worldoLaunchCustom;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No preset role'**
  String get worldoLaunchNoPresetRole;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Filling...'**
  String get worldoLaunchFilling;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Fill from my profile'**
  String get worldoLaunchFillMyProfile;

  /// 首页 - Worldo → Worldo Launch，Launch Worldo 的角色选择面板的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get worldoLaunchLaunch;

  /// 首页 - Worldo → Worldo Launch，Worldo Launch 完成后的弹窗
  ///
  /// In en, this message translates to:
  /// **'Worldo #{worldName} launched!'**
  String worldoLaunchWorldoWorldName({required String worldName});

  /// 首页 - Worldo → Worldo Launch，Worldo Launch 完成后的弹窗
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get worldoLaunchEnter;

  /// 首页 - Create → Create Worldo 页面，底部最终提交按钮
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createAction;

  /// 首页 - Create → Create Worldo 页面，顶部标题
  ///
  /// In en, this message translates to:
  /// **'Create Worldo'**
  String get createWorldoTitle;

  /// 首页 - Create → Create Worldo 页面，提交异常时的提示
  ///
  /// In en, this message translates to:
  /// **'Create failed'**
  String get createFailed;

  /// 首页 - Create → Edit Worldo 页面，发布时未填写更新说明的提示
  ///
  /// In en, this message translates to:
  /// **'Update notes are required to publish.'**
  String get createNotesRequired;

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，重复点击提交时的提示
  ///
  /// In en, this message translates to:
  /// **'This action is already in progress.'**
  String get createActionInProgress;

  /// 首页 - Create → Edit Worldo 页面，摘要顶部显示当前版本
  ///
  /// In en, this message translates to:
  /// **'Current Version: {version}'**
  String createCurrentVersion({required String version});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，检查待处理提交时的底部按钮
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get createChecking;

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中的 Worldo 名称
  ///
  /// In en, this message translates to:
  /// **'Worldo Name: {name}'**
  String createSummaryName({required String name});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中的 Worldo 简介
  ///
  /// In en, this message translates to:
  /// **'Worldo Brief: {brief}'**
  String createSummaryBrief({required String brief});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中的封面状态
  ///
  /// In en, this message translates to:
  /// **'Cover Image: {status}'**
  String createSummaryCover({required String status});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中封面未上传状态
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get createNotUploaded;

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中封面已上传状态
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get createUploaded;

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中的世界设定
  ///
  /// In en, this message translates to:
  /// **'Worldo Settings: {settings}'**
  String createSummarySettings({required String settings});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中的时间设定
  ///
  /// In en, this message translates to:
  /// **'Worldo Time: {time}'**
  String createSummaryTime({required String time});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中的数值设定
  ///
  /// In en, this message translates to:
  /// **'Worldo Metric: {metric}'**
  String createSummaryMetric({required String metric});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics 摘要中时间间隔的天数
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String createDays({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Characters 摘要中无已填写角色
  ///
  /// In en, this message translates to:
  /// **'0 characters'**
  String get createSummaryNoCharacters;

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Characters 摘要中的角色数量和名称
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 character: {names}} other{{count} characters: {names}}}'**
  String createSummaryCharacters({required int count, required String names});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Characters 摘要中的推荐角色
  ///
  /// In en, this message translates to:
  /// **'Suggested: {name}'**
  String createSummarySuggested({required String name});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Locations 摘要中的一级地点数量
  ///
  /// In en, this message translates to:
  /// **'L1 · Region: {count}'**
  String createSummaryRegion({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Locations 摘要中的二级地点数量
  ///
  /// In en, this message translates to:
  /// **'L2 · Building: {count}'**
  String createSummaryBuilding({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Locations 摘要中的三级地点数量
  ///
  /// In en, this message translates to:
  /// **'L3 · Room: {count}'**
  String createSummaryRoom({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Story Events 摘要中的事件数量
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event} other{{count} events}}'**
  String createSummaryEvents({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Opening 摘要中的角色对话数量
  ///
  /// In en, this message translates to:
  /// **'Character dialogue: {count}'**
  String createSummaryDialogue({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Opening 摘要中的旁白数量
  ///
  /// In en, this message translates to:
  /// **'Narrator: {count}'**
  String createSummaryNarrator({required int count});

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Opening 摘要中的图片数量
  ///
  /// In en, this message translates to:
  /// **'Image: {count}'**
  String createSummaryImage({required int count});

  /// 首页 - Create，“Delete ${itemLabel}?”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Delete {itemLabel}?'**
  String createDeleteItemLabel({required String itemLabel});

  /// 首页 - Create，删除条目确认弹窗
  ///
  /// In en, this message translates to:
  /// **'This item has content. Delete it anyway?'**
  String get createItemHasContentDeleteAnyway;

  /// 首页 - Create，封面上传区时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Image upload is in progress.'**
  String get createImageUploadProgress;

  /// 首页 - Create → Create Worldo / Edit Worldo 的 Basics 页标题；提交前校验提示中的 Basics 名称
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get createBasicsBasics;

  /// 首页 - Create → Worldo 的 Basics、Characters、Locations、Opening、Story Events 编辑页，保存过程中再次点击禁用的 Save 按钮
  ///
  /// In en, this message translates to:
  /// **'Saving is already in progress.'**
  String get createSaveInProgress;

  /// 首页 - Create → Worldo 的 Basics 或 Opening 编辑页，必填项未完成时点击 Save 按钮
  ///
  /// In en, this message translates to:
  /// **'Complete all required fields before saving.'**
  String get createRequiredBeforeSave;

  /// 首页 - Create → Create Worldo / Edit Worldo 的 Opening 页标题；提交前校验提示中的 Opening 名称
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get createOpeningOpening;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Characters: Please create at least one character.'**
  String get createCharacterCharactersCreate;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Characters: Only one character can be recommended.'**
  String get createCharacterCharactersOnlyOne;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Basics: Worldo Name is required.'**
  String get createBasicsBasicsWorldoName;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Basics: Worldo Brief is required.'**
  String get createBasicsBasicsWorldoBrief;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Basics: Cover Image is required.'**
  String get createBasicsBasicsCoverImage;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Basics: Metric must be valid JSON.'**
  String get createBasicsBasicsMetricMust;

  /// Create Worldo / Edit Worldo 页，提交时第 N 个角色缺少 Name 的提示
  ///
  /// In en, this message translates to:
  /// **'Characters #{characterIndex}: Name is required.'**
  String createCharacterCharactersName({required String characterIndex});

  /// Create Worldo / Edit Worldo 页，提交时第 N 个角色缺少 Identity 的提示
  ///
  /// In en, this message translates to:
  /// **'Characters #{characterIndex}: Identity is required.'**
  String createCharacterCharacters({required String characterIndex});

  /// Create Worldo / Edit Worldo 页，提交时第 N 个角色缺少 Personality 的提示
  ///
  /// In en, this message translates to:
  /// **'Characters #{characterIndex}: Personality is required.'**
  String createCharacterRequired({required String characterIndex});

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Characters: At least one character is required.'**
  String get createCharacterCharactersLeast;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Locations: Please create at least one location.'**
  String get createLocationLocationsCreate;

  /// Create Worldo / Edit Worldo 页，提交时第 N 个地点缺少 Location Name 的提示
  ///
  /// In en, this message translates to:
  /// **'Locations #{locationIndex}: Location Name is required.'**
  String createLocationLocationsLocation({required String locationIndex});

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Opening: Select a location and complete every dialogue item.'**
  String get createOpeningOpeningSelect;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Opening: The selected location is no longer available.'**
  String get createOpeningOpeningSelected;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Opening: A selected character is no longer available.'**
  String get createOpeningCharacterOpening;

  /// 首页 - Create，表单校验，提交前字段校验中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Opening: A dialogue character is not in the selected location. Open Opening to fix it.'**
  String get createOpeningOpeningDialogue;

  /// 首页 - Create，表单校验，“Unsupported opening dialogue: ${type}”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Unsupported opening dialogue: {type}'**
  String createUnsupportedOpeningDialogue({required String type});

  /// 首页 - Create，页面标题/登录限制中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get createCreating;

  /// 首页 - Create → Worldo 编辑页，未保存离开确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get createDiscard;

  /// 首页 - Create → Worldo 编辑页，步骤页标题/状态
  ///
  /// In en, this message translates to:
  /// **'Characters (>=1)'**
  String get createCharactersStep;

  /// 首页 - Create → Worldo 编辑页，步骤页标题/状态
  ///
  /// In en, this message translates to:
  /// **'Locations (>=1)'**
  String get createLocationsStep;

  /// 首页 - Create → Worldo 编辑页，步骤页标题/状态
  ///
  /// In en, this message translates to:
  /// **'Story Events (Optional)'**
  String get createStoryEventsOptional;

  /// 首页 - Create → Worldo 编辑页，Update Notes 字段标题
  ///
  /// In en, this message translates to:
  /// **'Update notes (required to publish)'**
  String get createUpdateNotesRequiredPublish;

  /// 首页 - Create → Worldo 编辑页，Update Notes 输入框的输入框提示
  ///
  /// In en, this message translates to:
  /// **'What changed in this version?'**
  String get createWhatChangedVersion;

  /// 首页 - Create → Worldo 编辑页，Worldo 提交处理完成后的弹窗
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get createView;

  /// 首页 - Create → Create Worldo / Edit Worldo 页面，Basics、Characters、Locations、Opening、Story Events 尚未保存时的模块摘要
  ///
  /// In en, this message translates to:
  /// **'Not started yet'**
  String get createNotStartedYet;

  /// 首页 - Create → Worldo 编辑页，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get createEdited;

  /// 首页 - Create → Worldo 编辑页，页面内容区域的标题
  ///
  /// In en, this message translates to:
  /// **'Publishing your Worldo'**
  String get createPublishingWorldo;

  /// 首页 - Create → Worldo 编辑页，页面内容区域的标题
  ///
  /// In en, this message translates to:
  /// **'Creating your Worldo'**
  String get createCreatingWorldo;

  /// 首页 - Create → Worldo 编辑页，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Preparing your Worldo updates.\nPlease wait for a moment.'**
  String get createPreparingWorldoUpdatesWait;

  /// 首页 - Create → Worldo 编辑页，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Bringing your Worldo to life.\nPlease wait for a moment.'**
  String get createBringingWorldoLifeWait;

  /// 首页 - Create → 内容提交弹窗，提交内容时填写说明的弹窗
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get createDescribeIssue;

  /// 首页 - Create → 内容提交弹窗，提交内容时填写说明的弹窗
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get createSubmit;

  /// 首页 - Create → Worldo 编辑 - Basics，“Worldo Name”字段标题
  ///
  /// In en, this message translates to:
  /// **'Worldo Name *'**
  String get createBasicsWorldoName;

  /// 首页 - Create → Worldo 编辑 - Basics，Worldo Name 为空时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Worldo Name is required.'**
  String get createBasicsNameRequired;

  /// 首页 - Create → Worldo 编辑 - Basics，Worldo Brief 为空时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Worldo Brief is required.'**
  String get createBasicsBriefRequired;

  /// 首页 - Create → Worldo 编辑 - Basics，Cover Image 为空时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Cover Image is required.'**
  String get createBasicsCoverRequired;

  /// 首页 - Create → Worldo 编辑 - Basics，Metric JSON 无效时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Metric must be valid JSON.'**
  String get createBasicsMetricInvalid;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. Main Street”
  ///
  /// In en, this message translates to:
  /// **'eg. Main Street'**
  String get createBasicsEgMainStreet;

  /// 首页 - Create → Worldo 编辑 - Basics，“Worldo Brief”字段标题
  ///
  /// In en, this message translates to:
  /// **'Worldo Brief *'**
  String get createBasicsWorldoBrief;

  /// 首页 - Create → Worldo 编辑 - Basics，Worldo Brief 输入框下的说明
  ///
  /// In en, this message translates to:
  /// **'The public hook players see first — the setting, the core conflict, and what makes it intriguing.'**
  String get createBasicsBriefNote;

  /// 首页 - Create → Worldo 编辑 - Basics，Worldo Settings - Hidden 输入框下的说明
  ///
  /// In en, this message translates to:
  /// **'The hidden rules and backstory that drive the story — agendas, mechanics, and secret limits.'**
  String get createBasicsHiddenNote;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. Half the shops on Main Street are boarded up. By Labor Day, the richest storefront owns the town.”
  ///
  /// In en, this message translates to:
  /// **'eg. Half the shops on Main Street are boarded up. By Labor Day, the richest storefront owns the town.'**
  String get createBasicsEgHalfShopsMain;

  /// 首页 - Create → Worldo 编辑 - Basics，“Cover Image”字段标题
  ///
  /// In en, this message translates to:
  /// **'Cover Image *'**
  String get createBasicsCoverImage;

  /// 首页 - Create → Worldo 编辑 - Basics，封面图片上传按钮
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get createBasicsUpload;

  /// 首页 - Create → Worldo 编辑 - Basics，封面图片尺寸和格式说明
  ///
  /// In en, this message translates to:
  /// **'Used for cards and detail pages. Recommend ~768×1024 px. Supported formats: JPG, PNG, WEBP.'**
  String get createBasicsUsedCardsDetailPages;

  /// 首页 - Create → Worldo 编辑 - Basics，“Worldo Settings - Hidden (Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Worldo Settings - Hidden (Optional)'**
  String get createBasicsWorldoSettingsHidden;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. The banker secretly controls who gets loans; whoever overextends can be squeezed out.”
  ///
  /// In en, this message translates to:
  /// **'eg. The banker secretly controls who gets loans; whoever overextends can be squeezed out.'**
  String get createBasicsEgBankerSecretly;

  /// 首页 - Create → Worldo 编辑 - Basics，“Worldo Time (Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Worldo Time (Optional)'**
  String get createBasicsWorldoTimeOptional;

  /// 首页 - Create → Worldo 编辑 - Basics，Worldo Time 字段下方的说明
  ///
  /// In en, this message translates to:
  /// **'This worldo starts at \'{Start Time}\'; each time the user taps *progress*, the timeline moves forward by \'{Time per Progress}\'.'**
  String get createBasicsWorldoStartsStart;

  /// 首页 - Create → Worldo 编辑 - Basics，“Start Time”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get createBasicsStartTime;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. Day 1, 09:00 / 2026-01-01”
  ///
  /// In en, this message translates to:
  /// **'eg. Day 1, 09:00 / 2026-01-01'**
  String get createBasicsDateExample;

  /// 首页 - Create → Worldo 编辑 - Basics，“Time per Progress”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Time per Progress'**
  String get createBasicsTimePerProgress;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. 8 hours / 3 days”
  ///
  /// In en, this message translates to:
  /// **'eg. 8 hours / 3 days'**
  String get createBasicsEg8Hours3Days;

  /// 首页 - Create → Worldo 编辑 - Basics，“Worldo Metric (Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Worldo Metric (Optional)'**
  String get createBasicsWorldoMetricOptional;

  /// 首页 - Create → Worldo 编辑 - Basics，“Metric Label”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Metric Label'**
  String get createBasicsMetricLabel;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. Wealth / Goal Progress”
  ///
  /// In en, this message translates to:
  /// **'eg. Wealth / Goal Progress'**
  String get createBasicsEgWealthGoalProgress;

  /// 首页 - Create → Worldo 编辑 - Basics，“Label note”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Label note'**
  String get createBasicsLabelNote;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“Describe what this metric measures”
  ///
  /// In en, this message translates to:
  /// **'Describe what this metric measures'**
  String get createBasicsDescribeWhatMetric;

  /// 首页 - Create → Worldo 编辑 - Basics，“Unit”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get createBasicsUnit;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“eg. coins / %”
  ///
  /// In en, this message translates to:
  /// **'eg. coins / %'**
  String get createBasicsEgCoins;

  /// 首页 - Create → Worldo 编辑 - Basics，“Value Range”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Value Range'**
  String get createBasicsRange;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“Starting”
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get createBasicsStarting;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“Delta Min”
  ///
  /// In en, this message translates to:
  /// **'Delta Min'**
  String get createBasicsDeltaMin;

  /// 首页 - Create → Worldo 编辑 - Basics，输入框内的示例提示“Delta Max”
  ///
  /// In en, this message translates to:
  /// **'Delta Max'**
  String get createBasicsDeltaMax;

  /// 首页 - Create → Worldo 编辑 - Basics，保存按钮
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get createBasicsSaving;

  /// 首页 - Create → Worldo 编辑 - Basics，Advanced Settings 分隔标题
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings (Optional)'**
  String get createBasicsAdvancedSettings;

  /// 首页 - Create → Worldo 编辑 - Characters，角色卡片的标题
  ///
  /// In en, this message translates to:
  /// **'Character {index}'**
  String createCharacterCharacterIndex({required String index});

  /// 首页 - Create → Worldo 编辑 - Characters，Best Role 选择区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Suggest'**
  String get createCharacterSuggest;

  /// 首页 - Create → Worldo 编辑 - Characters，“AVATAR\n(Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'AVATAR\n(Optional)'**
  String get createCharacterAvatarOptional;

  /// 首页 - Create → Worldo 编辑 - Characters，“Name”字段标题
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get createCharacterName;

  /// 首页 - Create → Create Worldo / Edit Worldo 的 Characters 编辑页顶部标题
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get createCharactersTitle;

  /// 首页 - Create → Worldo 编辑 - Characters，超过角色数量上限时的提示
  ///
  /// In en, this message translates to:
  /// **'You can add up to {count} characters.'**
  String createCharacterLimit({required int count});

  /// 首页 - Create → Worldo 编辑 - Characters，第 N 个角色缺少 Name 时保存的提示
  ///
  /// In en, this message translates to:
  /// **'Character {index}: Name is required.'**
  String createCharacterNameRequired({required int index});

  /// 首页 - Create → Worldo 编辑 - Characters，第 N 个角色缺少 Identity 时保存的提示
  ///
  /// In en, this message translates to:
  /// **'Character {index}: Identity is required.'**
  String createCharacterIdentityRequired({required int index});

  /// 首页 - Create → Worldo 编辑 - Characters，第 N 个角色缺少 Personality 时保存的提示
  ///
  /// In en, this message translates to:
  /// **'Character {index}: Personality is required.'**
  String createCharacterPersonalityRequired({required int index});

  /// 首页 - Create → Worldo 编辑 - Characters，没有角色时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Please create at least one character.'**
  String get createCharacterMinOne;

  /// 首页 - Create → Worldo 编辑 - Characters，输入框内的示例提示“Enter name...”
  ///
  /// In en, this message translates to:
  /// **'Enter name...'**
  String get createCharacterEnterName;

  /// 首页 - Create → Worldo 编辑 - Characters，“Identity”字段标题
  ///
  /// In en, this message translates to:
  /// **'Identity *'**
  String get createCharacterIdentity;

  /// 首页 - Create → Worldo 编辑 - Characters，输入框内的示例提示“eg. A hometown kid back for one real shot”
  ///
  /// In en, this message translates to:
  /// **'eg. A hometown kid back for one real shot'**
  String get createCharacterEgHometownKidBack;

  /// 首页 - Create → Worldo 编辑 - Characters，“Personality”字段标题
  ///
  /// In en, this message translates to:
  /// **'Personality *'**
  String get createCharacterPersonality;

  /// 首页 - Create → Worldo 编辑 - Characters，输入框内的示例提示“eg. Underdog with goodwill but little capital”
  ///
  /// In en, this message translates to:
  /// **'eg. Underdog with goodwill but little capital'**
  String get createCharacterEgUnderdog;

  /// 首页 - Create → Worldo 编辑 - Characters，“Goal (Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Goal (Optional)'**
  String get createCharacterGoalOptional;

  /// 首页 - Create → Worldo 编辑 - Characters，输入框内的示例提示“eg. Be the richest owner on Main Street by Labor Day”
  ///
  /// In en, this message translates to:
  /// **'eg. Be the richest owner on Main Street by Labor Day'**
  String get createCharacterEgRichestOwner;

  /// 首页 - Create → Worldo 编辑 - Characters，“Background - Hidden (Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Background - Hidden (Optional)'**
  String get createCharacterBackgroundHidden;

  /// 首页 - Create → Worldo 编辑 - Characters，输入框内的示例提示“eg. Left town years ago; returned to a boarded-up Main Street for one chance.”
  ///
  /// In en, this message translates to:
  /// **'eg. Left town years ago; returned to a boarded-up Main Street for one chance.'**
  String get createCharacterEgLeftTownYears;

  /// 首页 - Create → Worldo 编辑 - Characters，角色列表/保存操作的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'+ Add Character'**
  String get createCharacterAddCharacter;

  /// 首页 - Create → Worldo 编辑 - Locations，“IMAGE\n(Optional)”字段或选项
  ///
  /// In en, this message translates to:
  /// **'IMAGE\n(Optional)'**
  String get createLocationImageOptional;

  /// 首页 - Create → Worldo 编辑 - Locations，Initial Characters 字段中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Select from available characters below'**
  String get createCharacterSelectAvailable;

  /// 首页 - Create → Worldo 编辑 - Locations，Initial Characters 字段中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Initial Characters (Optional)'**
  String get createCharacterInitialCharacters;

  /// 首页 - Create → Worldo 编辑 - Locations，Initial Characters 字段中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The characters who start here when the worldo begins.'**
  String get createLocationStartingCharacters;

  /// 首页 - Create → Worldo 编辑 - Locations，Initial Characters 字段中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Available to select'**
  String get createCharacterAvailableSelect;

  /// 首页 - Create → Worldo 编辑 - Locations，Initial Characters 字段中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No characters yet. Create characters first, then choose where they start.'**
  String get createCharacterNoCharactersYet;

  /// 首页 - Create → Worldo 编辑 - Locations，Initial Characters 字段中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No characters available. All characters already have an initial location.'**
  String get createCharacterNoCharacters;

  /// 首页 - Create → Worldo 编辑 - Locations，删除地点分支确认弹窗
  ///
  /// In en, this message translates to:
  /// **'All L2 and L3 locations inside it will be removed too.'**
  String get createLocationEveryL2L3Locations;

  /// 首页 - Create → Worldo 编辑 - Locations，删除地点分支确认弹窗
  ///
  /// In en, this message translates to:
  /// **'All L3 locations inside it will be removed too.'**
  String get createLocationEveryL3Locations;

  /// 首页 - Create → Worldo 编辑 - Locations，删除地点分支确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Delete \"{displayName}\"'**
  String createLocationDeleteDisplayName({required String displayName});

  /// 首页 - Create → Worldo 编辑 - Locations，删除 Opening 地点确认弹窗
  ///
  /// In en, this message translates to:
  /// **'This is the Opening location. Deleting it will also clear the Opening.'**
  String get createLocationOpeningLocation;

  /// 首页 - Create → Worldo 编辑 - Locations，地点树节点标题
  ///
  /// In en, this message translates to:
  /// **'L1 Location · Region *'**
  String get createLocationL1LocationRegion;

  /// 首页 - Create → Worldo 编辑 - Locations，地点树节点标题
  ///
  /// In en, this message translates to:
  /// **'L2 Location · Building *'**
  String get createLocationL2LocationBuilding;

  /// 首页 - Create → Worldo 编辑 - Locations，L3 地点编辑 Sheet的标题
  ///
  /// In en, this message translates to:
  /// **'Add L3 Location'**
  String get createLocationAddL3Location;

  /// 首页 - Create → Create Worldo / Edit Worldo 的 Locations 编辑页顶部标题
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get createLocationsTitle;

  /// 首页 - Create → Worldo 编辑 - Locations，Preview 页面地点层级说明
  ///
  /// In en, this message translates to:
  /// **'Your world is built in 3 levels:\nL1 · Region     An area of your world — Downtown\nL2 · Building   A building inside it — Joe\'\'s Diner\nL3 · Room       A room inside that building — The Back Kitchen\nEvery location needs all three levels. Up to 15 rooms in total.'**
  String get createLocationStatisticsNote;

  /// 首页 - Create → Worldo 编辑 - Locations，L1 地点名称输入框下的说明
  ///
  /// In en, this message translates to:
  /// **'An area of your world — a district, a town, a forest. Not a single building.'**
  String get createLocationL1NameNote;

  /// 首页 - Create → Worldo 编辑 - Locations，L2 地点名称输入框下的说明
  ///
  /// In en, this message translates to:
  /// **'A building inside this region — a shop, a school, an apartment block.'**
  String get createLocationL2NameNote;

  /// 首页 - Create → Worldo 编辑 - Locations，L3 地点名称输入框下的说明
  ///
  /// In en, this message translates to:
  /// **'A room inside the building. Rooftops, courtyards and entrances work too.'**
  String get createLocationL3NameNote;

  /// 首页 - Create → Worldo 编辑 - Locations，L3 地点编辑 Sheet 的名称字段标题
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get createLocationName;

  /// 首页 - Create → Worldo 编辑 - Locations，L1 地点名称为空时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'L1 location name is required.'**
  String get createLocationL1NameRequired;

  /// 首页 - Create → Worldo 编辑 - Locations，L3 地点名称为空时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'L3 location name is required.'**
  String get createLocationL3NameRequired;

  /// 首页 - Create → Worldo 编辑 - Locations，L1 地点尚未命名时校验提示中的地点称呼
  ///
  /// In en, this message translates to:
  /// **'This L1 location'**
  String get createLocationThisL1;

  /// 首页 - Create → Worldo 编辑 - Locations，L2 地点尚未命名时校验提示中的地点称呼
  ///
  /// In en, this message translates to:
  /// **'This L2 location'**
  String get createLocationThisL2;

  /// 首页 - Create → Worldo 编辑 - Locations，L1 地点缺少 L2 子地点时的提示
  ///
  /// In en, this message translates to:
  /// **'{locationLabel} must contain at least one L2 location.'**
  String createLocationL1NeedsL2({required String locationLabel});

  /// 首页 - Create → Worldo 编辑 - Locations，L2 地点缺少 L3 子地点时的提示
  ///
  /// In en, this message translates to:
  /// **'{locationLabel} must contain at least one L3 location.'**
  String createLocationL2NeedsL3({required String locationLabel});

  /// 首页 - Create → Worldo 编辑 - Locations，L1 下的 L2 地点缺少名称时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'{locationLabel} has an L2 location that needs a name.'**
  String createLocationL2NameNeeded({required String locationLabel});

  /// 首页 - Create → Worldo 编辑 - Locations，L2 下的 L3 地点缺少名称时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'{locationLabel} has an L3 location that needs a name.'**
  String createLocationL3NameNeeded({required String locationLabel});

  /// 首页 - Create → Worldo 编辑 - Locations，新增地点达到 L3 总数上限时的提示
  ///
  /// In en, this message translates to:
  /// **'You can add up to {count} L3 locations.'**
  String createLocationMaxL3({required int count});

  /// 首页 - Create → Worldo 编辑 - Locations，新增 L3 地点时房间已满的提示
  ///
  /// In en, this message translates to:
  /// **'You\'\'ve used all {count} rooms. Delete one to add another.'**
  String createLocationRoomsFull({required int count});

  /// 首页 - Create → Worldo 编辑 - Locations，尝试删除最后一个 L1 地点时的提示
  ///
  /// In en, this message translates to:
  /// **'At least one L1 location is required.'**
  String get createLocationAtLeastOneL1;

  /// 首页 - Create → Worldo 编辑 - Locations，没有 L1 地点时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Add at least one L1 location.'**
  String get createLocationAddL1;

  /// 首页 - Create → Worldo 编辑 - Locations，没有地点时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Please create at least one location.'**
  String get createLocationMinOne;

  /// 首页 - Create → Worldo 编辑 - Locations，保存时地点 ID 缺失的提示
  ///
  /// In en, this message translates to:
  /// **'Every location must have an ID.'**
  String get createLocationIdRequired;

  /// 首页 - Create → Worldo 编辑 - Locations，保存时地点 ID 重复的提示
  ///
  /// In en, this message translates to:
  /// **'Every location must have a unique ID.'**
  String get createLocationIdUnique;

  /// 首页 - Create → Worldo 编辑 - Locations，保存时地点上级无效的提示
  ///
  /// In en, this message translates to:
  /// **'Every location must have a valid parent.'**
  String get createLocationParentInvalid;

  /// 首页 - Create → Worldo 编辑 - Locations，必填地点字段未完成时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Complete all required location fields before saving.'**
  String get createLocationFieldsRequired;

  /// 首页 - Create → Worldo 编辑 - Locations，保存时移除角色会连带删除 Opening 对话的确认弹窗正文
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saving Locations will also delete 1 Opening dialogue bubble for the removed characters.} other{Saving Locations will also delete {count} Opening dialogue bubbles for the removed characters.}}'**
  String createLocationDeleteBubbles({required int count});

  /// 首页 - Create → Worldo 编辑 - Locations，L3 地点编辑 Sheet的标题
  ///
  /// In en, this message translates to:
  /// **'Edit L3 Location'**
  String get createLocationEditL3Location;

  /// 首页 - Create → Worldo 编辑 - Locations，编辑模式切换中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get createLocationPreview;

  /// 首页 - Create → Worldo 编辑 - Locations，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Please complete this location or delete it.'**
  String get createLocationCompleteLocation;

  /// 首页 - Create → Worldo 编辑 - Locations，移除 Opening 角色确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Remove character from location?'**
  String get createLocationRemoveCharacter;

  /// 首页 - Create → Worldo 编辑 - Locations，移除 Opening 角色确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get createLocationRemove;

  /// 首页 - Create → Worldo 编辑 - Locations，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'L1 Location'**
  String get createLocationL1Location;

  /// 首页 - Create → Worldo 编辑 - Locations，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'L2 Location'**
  String get createLocationL2Location;

  /// 首页 - Create → Worldo 编辑 - Locations，页面内容区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'L3 Location'**
  String get createLocationL3Location;

  /// 首页 - Create → Worldo 编辑 - Opening，弹窗或底部面板的标题
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get createOpeningSelectLocation;

  /// 首页 - Create → Worldo 编辑 - Opening，弹窗或底部面板中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No saved locations'**
  String get createOpeningNoSavedLocations;

  /// 首页 - Create → Worldo 编辑 - Opening，弹窗或底部面板的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get createOpeningSelect;

  /// 首页 - Create → Worldo 编辑 - Opening，弹窗或底部面板时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Select a location first.'**
  String get createOpeningSelectLocationFirst;

  /// 首页 - Create → Worldo 编辑 - Opening，列表项或卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No initial character'**
  String get createOpeningNoInitialCharacter;

  /// 首页 - Create → Worldo 编辑 - Opening，表单输入区域时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Locations are still loading.'**
  String get createOpeningLocationsLoading;

  /// 首页 - Create → Worldo 编辑 - Opening，表单输入区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Loading locations...'**
  String get createOpeningLoadingLocations;

  /// 首页 - Create → Worldo 编辑 - Opening，起始地点选择结果
  ///
  /// In en, this message translates to:
  /// **'Switching locations will clear the dialogue content.'**
  String get createOpeningSwitchingLocations;

  /// 首页 - Create → Worldo 编辑 - Opening，起始地点选择结果
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createOpeningContinue;

  /// 首页 - Create → Worldo 编辑 - Opening，添加对话条目时显示的提示
  ///
  /// In en, this message translates to:
  /// **'You can add up to 10 dialogue items.'**
  String get createOpeningAdd10DialogueItems;

  /// 首页 - Create → Worldo 编辑 - Opening，Best Role 设置时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to save suggested role.'**
  String get settingsUnableSaveSuggestedRole;

  /// 首页 - Create → Worldo 编辑 - Opening，保存结果
  ///
  /// In en, this message translates to:
  /// **'Unable to save Opening.'**
  String get createOpeningUnableSaveOpening;

  /// 首页 - Create → Worldo 编辑 - Opening，“Select initial location”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Select initial location'**
  String get createOpeningSelectInitial;

  /// 首页 - Create → Worldo 编辑 - Opening，未选择初始地点时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Select an initial location before saving.'**
  String get createOpeningInitialLocationRequired;

  /// 首页 - Create → Worldo 编辑 - Opening，没有对话条目时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Add at least one dialogue item before saving.'**
  String get createOpeningAddDialogueFirst;

  /// 首页 - Create → Worldo 编辑 - Opening，有未完成对话条目时点击 Save 的提示
  ///
  /// In en, this message translates to:
  /// **'Complete every dialogue item before saving.'**
  String get createOpeningCompleteDialogue;

  /// 首页 - Create → Worldo 编辑 - Opening，“Opening dialogue”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Opening dialogue'**
  String get createOpeningDialogue;

  /// 首页 - Create → Worldo 编辑 - Opening，Opening 内容表单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Select a location first, then edit the dialogue.'**
  String get createOpeningLocationRequired;

  /// 首页 - Create → Worldo 编辑 - Opening，Dialogue 对话编辑区的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get createOpeningNarrator;

  /// 首页 - Create → Worldo 编辑 - Opening，Dialogue 对话编辑区的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get createOpeningImage;

  /// 首页 - Create → Worldo 编辑 - Opening，Best Role 选择器中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Suggest a role for user'**
  String get createOpeningSuggestRoleUser;

  /// 首页 - Create → Worldo 编辑 - Opening，Best Role 选择器中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No characters available.'**
  String get createOpeningNoCharacters;

  /// 首页 - Create → Worldo 编辑 - Opening，Narrator 对话条目的输入框提示
  ///
  /// In en, this message translates to:
  /// **'Enter narrator dialogue'**
  String get createOpeningEnterNarrator;

  /// 首页 - Create → Worldo 编辑 - Opening，Character 对话条目的输入框提示
  ///
  /// In en, this message translates to:
  /// **'Enter {name} dialogue'**
  String createOpeningEnterNameDialogue({required String name});

  /// 首页 - Create → Worldo 编辑 - Opening，Dialogue 文本输入框的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'\'{{user}}\''**
  String get createOpeningUser;

  /// 首页 - Create → Worldo 编辑 - Opening，Image 对话条目的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'UPLOAD IMAGE'**
  String get createOpeningUploadImage;

  /// 首页 - Create → Worldo 编辑 - Story Events，事件列表/保存操作的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'+ Add Event'**
  String get createEventAddEvent;

  /// 首页 - Create → Create Worldo / Edit Worldo 的 Story Events 编辑页顶部标题
  ///
  /// In en, this message translates to:
  /// **'Story Events'**
  String get createStoryEventsTitle;

  /// 首页 - Create → Worldo 编辑 - Story Events，新增事件达到上限时的提示
  ///
  /// In en, this message translates to:
  /// **'You can add up to {count} events.'**
  String createEventLimit({required int count});

  /// 首页 - Create → Worldo 编辑 - Story Events，事件卡片的标题
  ///
  /// In en, this message translates to:
  /// **'Event {index}'**
  String createEventEventIndex({required String index});

  /// 首页 - Create → Worldo 编辑 - Story Events，事件卡片的输入框提示
  ///
  /// In en, this message translates to:
  /// **'eg. A national chain scouts a vacant lot, threatening to undercut every local on price.'**
  String get createEventEgNationalChainScouts;

  /// 首页 - Create → Worldo 编辑 - Story Events，事件卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'A key story beat the AI uses to steer the storyline.'**
  String get createEventKeyStoryBeatAIUses;

  /// 首页 - Create → 图片裁剪/上传页，图片裁剪或上传失败
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get imageCropUploadFailed;

  /// 首页 - Inbox，Notifications 消息分类入口；Notifications 分类页顶部标题
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get inboxNotifications;

  /// 首页 - Inbox → Notifications 分类页，无通知时的空状态
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get inboxNoNotificationsYet;

  /// 首页 - Inbox，会话列表/空状态/筛选的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get inboxFollowers;

  /// 首页 - Inbox → New followers 消息分类页，顶部标题
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get inboxNewFollowers;

  /// 首页 - Inbox → New followers 分类页，无新关注时的空状态
  ///
  /// In en, this message translates to:
  /// **'No new followers yet.'**
  String get inboxNoNewFollowersYet;

  /// 首页 - Inbox，Comments 消息分类入口；Comments 分类页顶部标题
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get inboxComments;

  /// 首页 - Inbox → Comments 分类页，无评论时的空状态
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get inboxNoCommentsYet;

  /// 首页 - Inbox，会话列表/空状态/筛选中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Private Chats'**
  String get inboxPrivateChats;

  /// 首页 - Inbox，会话列表/空状态/筛选中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Chat with your friends on Worldo.'**
  String get inboxChatFriendsWorldo;

  /// 首页 - Inbox，会话列表项中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get inboxUnknownUser;

  /// 首页 - Inbox → 私聊页，私聊页面的空状态或加载状态
  ///
  /// In en, this message translates to:
  /// **'Direct message'**
  String get inboxDirectMessage;

  /// 首页 - Inbox → 通知/加入申请，列表项中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Join request'**
  String get inboxJoinRequest;

  /// 首页 - Inbox → 通知/加入申请，操作菜单的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get inboxApprove;

  /// 首页 - Inbox → 通知/加入申请，操作菜单的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get inboxReject;

  /// 首页 - Inbox → 通知/加入申请，详情弹窗
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get inboxOk;

  /// 首页 - Inbox → 通知/加入申请，审核结果
  ///
  /// In en, this message translates to:
  /// **'Review failed'**
  String get inboxReviewFailed;

  /// 首页 - Inbox → 通知/加入申请，通知列表/空状态
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages.'**
  String get inboxLoadMessagesFailed;

  /// 首页 - Inbox → 通知文案，列表项或卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get inboxNewMessage;

  /// 首页 - Inbox → 通知文案，发送者名称兜底中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get inboxSomeone;

  /// 首页 - Inbox → 通知文案，World 请求摘要中显示的文字
  ///
  /// In en, this message translates to:
  /// **'this world'**
  String get inboxWorld;

  /// 首页 - Inbox → 通知文案，Join Request 摘要中显示的文字
  ///
  /// In en, this message translates to:
  /// **'{name} requested to join {world}{suffix}'**
  String inboxNameRequestJoinWorldSuffix({
    required String name,
    required String world,
    required String suffix,
  });

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **' commented on your worldo'**
  String get inboxCommentWorldo;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **' replied to you'**
  String get inboxReply;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **' liked your comment'**
  String get inboxLikeComment;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **'liked your comment'**
  String get inboxLikedComment;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **'liked your comment'**
  String get inboxComment2LikeComment;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **'replied to you'**
  String get inboxReplied;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **'replied to you'**
  String get inboxYou2Reply;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **'commented on your origin'**
  String get inboxCommentedOrigin;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **'commented on your origin'**
  String get inboxCommentOrigin;

  /// 首页 - Inbox → 通知文案，Discuss 互动通知标题
  ///
  /// In en, this message translates to:
  /// **' sent you a message'**
  String get inboxSentMessage;

  /// 首页 - Inbox → 通知文案，Follow 通知用户名中显示的文字
  ///
  /// In en, this message translates to:
  /// **' started following you.'**
  String get inboxStartedFollowing;

  /// 首页 - Me，Discord 跳转结果
  ///
  /// In en, this message translates to:
  /// **'Could not open Discord'**
  String get meFailedOpenDiscord;

  /// 首页 - Me，头像编辑结果
  ///
  /// In en, this message translates to:
  /// **'Image pick failed'**
  String get meImagePickFailed;

  /// 首页 - Me，昵称修改结果
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get meUpdateFailed;

  /// 首页 - Me，个人信息/菜单列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get mePlaying;

  /// 首页 - Me，修改昵称弹窗，修改昵称弹窗
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get meEditName;

  /// 首页 - Me，未登录状态下登录引导区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Sign up and get 250 Gems!'**
  String get meSignUpReward;

  /// 登录弹窗顶部以及新用户个性化页登录区的注册奖励提示
  ///
  /// In en, this message translates to:
  /// **'Sign up and get 250 Gems!'**
  String get loginSignUpReward;

  /// 首页 - Me，资料加载失败状态
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get meUnknown;

  /// 首页 - Me，页面标题或顶部区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'OID: {oid}\nLatest Version: {version}'**
  String meOIDLatestVersion({required String oid, required String version});

  /// 首页 - Me，页面标题或顶部区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'WID: {displayWid}\nOwner: {owner}'**
  String meWIDDisplayOwner({required String displayWid, required String owner});

  /// 首页 - Me → 关注/粉丝页，Following 或 Followers 用户列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get meFollows;

  /// 首页 - Me → 关注/粉丝页，Following 或 Followers 用户列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'{followingCount} Following'**
  String meFollowingCount({required String followingCount});

  /// 首页 - Me → 关注/粉丝页，Following 或 Followers 用户列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'{followersCount} Followers'**
  String meFollowersCount({required String followersCount});

  /// 首页 - Me → 关注/粉丝页，Following 或 Followers 用户列表无内容时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No following yet.'**
  String get meNoFollowingYet;

  /// 首页 - Me → 关注/粉丝页，Following 或 Followers 用户列表无内容时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No followers yet.'**
  String get meNoFollowersYet;

  /// Profile and blocked-user settings: block action failure toast, including missing user ID and local fallback when no server err_msg exists.
  ///
  /// In en, this message translates to:
  /// **'Block failed. Please try again.'**
  String get meBlockFailed;

  /// 首页 - Me → 其他用户资料页，Block 或 Unblock 失败
  ///
  /// In en, this message translates to:
  /// **'User blocked. This content has been reported to Worldo team.'**
  String get meUserBlockedContentHasReported;

  /// 首页 - Me → 其他用户资料页，Block 用户的确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Block this user?'**
  String get meBlockUser;

  /// 首页 - Me → 其他用户资料页，Block 用户的确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get meBlock;

  /// Profile and blocked-user settings: unblock action failure toast, including missing user ID and local fallback when no server err_msg exists.
  ///
  /// In en, this message translates to:
  /// **'Unblock failed. Please try again.'**
  String get meUnblockFailed;

  /// 首页 - Me → 其他用户资料页，其他用户资料页的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get meUnblock;

  /// 首页 - Me → 用户资料页，Following/Followers 统计的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get meFollowing;

  /// 首页 - Me → 用户资料页，Follow/Edit 操作按钮
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get meFollow;

  /// 首页 - Me → 用户资料页，Follow/Edit 操作按钮
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get meMessage;

  /// 首页 - Me → 设置页，账号 UID；首页 - Me → Following 或 Followers 列表，用户项的 UID
  ///
  /// In en, this message translates to:
  /// **'UID: {uid}'**
  String meUID({required String uid});

  /// 首页 - Me → 用户资料页，Worldo/World 收藏列表无内容时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No Worldo you created yet.'**
  String get meNoWorldoCreatedYet;

  /// 首页 - Me → 用户资料页，Worldo/World 收藏列表无内容时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No Worldo yet.'**
  String get meNoWorldoYet;

  /// 首页 - Me → 用户资料页，Worldo/World 收藏列表无内容时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No Worlds you created yet.'**
  String get meNoWorldsCreatedYet;

  /// 首页 - Me → 用户资料页，Worldo/World 收藏列表无内容时显示的提示
  ///
  /// In en, this message translates to:
  /// **'No Worlds yet.'**
  String get meNoWorldsYet;

  /// 首页 - Me → 用户资料页，个人资料头部的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'UID'**
  String get profileUID;

  /// 首页 - Me → 用户资料页，Gems 余额入口的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Red gems'**
  String get gemsRed;

  /// 首页 - Me → 用户资料页，Gems 余额入口的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Pink gems'**
  String get gemsPink;

  /// 首页 - Me → 用户资料页，Gems 余额入口中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get gemsTop;

  /// 首页 - Me → Gems 钱包页顶部的页面标题
  ///
  /// In en, this message translates to:
  /// **'Buy Gems'**
  String get gemsBuy;

  /// 首页 - Me → Gems 钱包页右上角 Records 记录入口
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get gemsRecords;

  /// 首页 - Me → Gems 钱包页整体加载失败时的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to load gems.'**
  String get gemsUnableLoad;

  /// 首页 - Me → 设置页，Log Out 确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Log out of your account?'**
  String get settingsLogOutAccount;

  /// 首页 - Me → 设置页，Log Out 确认弹窗
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// 首页 - Me → 设置页，Feedback 反馈弹窗
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get settingsFeedback;

  /// 首页 - Me → 设置页，设置项列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// 首页 - Me → 设置页，设置项列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get settingsAboutUs;

  /// 首页 - Me → 设置页，设置项列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// 首页 - Me → 设置页，设置项列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get settingsBlockedUsers;

  /// 首页 - Me → 设置页，设置项列表中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Join Discord'**
  String get settingsJoinDiscord;

  /// 首页 - Me → 屏蔽用户页，Block/Unblock 操作结果
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get meUserUnblocked;

  /// 首页 - Me → 屏蔽用户页，列表加载/空状态
  ///
  /// In en, this message translates to:
  /// **'No blocked users yet.'**
  String get meNoBlockedUsersYet;

  /// 首页 - Me → 账号设置页，删除账号确认与结果
  ///
  /// In en, this message translates to:
  /// **'Agree to our terms to continue.'**
  String get settingsAgreeTermsContinue;

  /// 首页 - Me → 账号设置页，删除账号确认与结果
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteAccount;

  /// 首页 - Me → 账号设置页，账号信息/删除账号区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Account Deletion Agreement'**
  String get settingsAccountDeletionAgreement;

  /// 首页 - Me → 账号设置页，账号信息/删除账号区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'To ensure the security of your account, please read about the consequences of account deletion.\n\nAccount deletion is not the same as logging out, and once canceled, it cannot be undone. Your private data, including created characters, search history, chat logs with any characters, your favorites, your memories, interaction data, and order records, will be irreversibly deleted and cannot be recovered upon account deletion.'**
  String get settingsEnsureSecurityAccount;

  /// 首页 - Me → 账号设置页，账号信息/删除账号区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'All unused Gems, including purchased and earned Gems, will be permanently lost. By continuing, you voluntarily waive them, and account deletion does not automatically entitle you to a refund.\n\nAll remaining membership benefits will also be permanently lost and cannot be restored. Deleting your account does not cancel your subscription.'**
  String get gemsAllUnusedIncludingPurchased;

  /// 首页 - Me → 账号设置页，账号信息/删除账号区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'I have read the Account Deletion Agreement'**
  String get settingsIHaveReadAccountDeletion;

  /// 首页 - Me → 账号设置页，当前登录账号卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Current login account:'**
  String get settingsCurrentLoginAccount;

  /// 首页 - Me → 新用户个性化页，新用户个性化提交或登录时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Please try again.'**
  String get profileSaveFailed;

  /// 首页 - Me → 新用户个性化页，新用户个性化提交或登录时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get meSignInFailed;

  /// 首页 - Me → 新用户个性化页，新用户个性化选项表单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to continue.'**
  String get meCompleteProfileContinue;

  /// 首页 - Me → 新用户个性化页，新用户个性化选项表单时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Please select your gender and age.'**
  String get meSelectGenderAge;

  /// 首页 - Me → 新用户个性化页，新用户个性化选项表单时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Please select your gender.'**
  String get meSelectGender;

  /// 首页 - Me → 新用户个性化页，新用户个性化选项表单时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Please select your age.'**
  String get meSelectAge;

  /// 首页 - Me → 新用户个性化页，“Required”字段或选项
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get meRequired;

  /// 首页 - Me → 新用户个性化页，新用户个性化页面顶部中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Personalize Your Worldo Experience'**
  String get mePersonalizeWorldoExperience;

  /// 首页 - Me → 新用户个性化页，新用户个性化页面顶部的标题
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get meSignIn;

  /// 首页 - Me → 新用户个性化页，新用户个性化页面顶部的无障碍说明
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get meBack;

  /// 首页 - Me → 新用户个性化页，新用户个性化页面顶部中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get meSkip;

  /// 首页 - Me → 登录/注册页，登录注册页的登录方式按钮
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get meContinueGoogle;

  /// 首页 - Me → 登录/注册页，登录注册页的登录方式按钮
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get meContinueApple;

  /// 首页 - Me → 登录弹窗，登录弹窗
  ///
  /// In en, this message translates to:
  /// **'Sign up to claim Premium'**
  String get meSignUpClaimPremium;

  /// 首页 - Me → 登录弹窗，登录弹窗
  ///
  /// In en, this message translates to:
  /// **'Sign up to continue'**
  String get meSignUpContinue;

  /// 首页 - Me → 登录状态提示，账号在其他设备登录导致当前会话失效中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Your account is logged in on another device.'**
  String get meAccountLoggedAnotherDevice;

  /// 首页 - Me → Premium 订阅，Premium/Gems 页签中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get premiumSubscription;

  /// 首页 - Me → Gems 钱包页 Task 任务执行或签到失败时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Claim failed.'**
  String get gemsClaimFailed;

  /// 首页 - Me → Gems 钱包页 Task 任务执行或签到失败时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Check in failed.'**
  String get gemsCheckFailed;

  /// 首页 - Me → Gems 钱包页 Task 任务执行或签到失败时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Follow failed.'**
  String get gemsFollowFailed;

  /// 首页 - Me → Gems 钱包页 Task 任务执行或签到失败时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Task update failed.'**
  String get gemsTaskUpdateFailed;

  /// 首页 - Me → Gems 钱包页 Task 奖励领取成功弹窗的标题
  ///
  /// In en, this message translates to:
  /// **'Claim successful!'**
  String get gemsClaimSuccessful;

  /// 首页 - Me → Gems 钱包页商品列表加载失败或没有商品时的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to load gem packs.'**
  String get gemsUnableLoadGemPacks;

  /// 首页 - Me → Gems 钱包页商品列表加载失败或没有商品时的提示
  ///
  /// In en, this message translates to:
  /// **'No gem packs available.'**
  String get gemsNoGemPacksAvailable;

  /// 首页 - Me → Gems 钱包页 Task 任务列表加载失败时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to load gem tasks.'**
  String get gemsUnableLoadGemTasks;

  /// 首页 - Me → Gems 钱包页 Task 任务列表中的 Join Us 分组标题
  ///
  /// In en, this message translates to:
  /// **'join us'**
  String get gemsJoinUs;

  /// 首页 - Me → Gems 钱包页 Task 任务列表中，奖励可领取时的按钮
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get gemsClaim;

  /// 首页 - Me → Gems 钱包页 Task 任务列表中，奖励已领取时的按钮
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get gemsClaimed;

  /// 首页 - Me → 每日签到弹窗，Daily Check-in 签到弹窗
  ///
  /// In en, this message translates to:
  /// **'Daily Check-in'**
  String get meDailyCheck;

  /// 首页 - Me → 每日签到弹窗，Daily Check-in 签到弹窗
  ///
  /// In en, this message translates to:
  /// **'Get 100'**
  String get gemsDailyCheckInReward;

  /// 首页 - Me → 每日签到弹窗，Daily Check-in 签到弹窗
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get meCheck;

  /// 首页 - Me → 每日签到弹窗，Daily Check-in 成功弹窗
  ///
  /// In en, this message translates to:
  /// **'Check in successful!'**
  String get meCheckSuccessful;

  /// 首页 - Me → 购买结果弹窗，购买结果
  ///
  /// In en, this message translates to:
  /// **'Google Play is unavailable.'**
  String get meGooglePlayUnavailable;

  /// 首页 - Me → 购买结果弹窗，购买结果
  ///
  /// In en, this message translates to:
  /// **'Purchase failed.'**
  String get mePurchaseFailed;

  /// 首页 - Me → Gems 记录页，Gems 记录页面的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get gemsEarned;

  /// 首页 - Me → Gems 记录页，Gems 记录页面的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get gemsSpent;

  /// 首页 - Me → Gems 记录页，Gems 记录页面的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get gemsPurchase;

  /// 首页 - Me → Gems 记录页，Gems 记录页面中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Gem Records'**
  String get gemsGemRecords;

  /// 首页 - Me → Gems 记录页，Gems 记录加载失败
  ///
  /// In en, this message translates to:
  /// **'Unable to load records.'**
  String get gemsUnableLoadRecords;

  /// 首页 - Me → Gems 记录页，Gems 记录列表为空
  ///
  /// In en, this message translates to:
  /// **'No gem records yet.'**
  String get gemsNoGemRecordsYet;

  /// 首页 - Me → About 页，品牌介绍和版本信息区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get meAbout;

  /// 首页 - Me → About 页，复制联系邮箱完成
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get meEmailCopied;

  /// 首页 - Me → 购买结果弹窗，购买中/成功状态
  ///
  /// In en, this message translates to:
  /// **'Purchasing Premium'**
  String get mePurchasingPremium;

  /// 首页 - Me → 购买结果弹窗，购买中/成功状态
  ///
  /// In en, this message translates to:
  /// **'Purchase successful!'**
  String get mePurchaseSuccessful;

  /// 首页 - Me → 购买结果弹窗，购买中/成功状态
  ///
  /// In en, this message translates to:
  /// **'Your Worldo Premium subscription is now active.'**
  String get meWorldoPremiumSubscription;

  /// 首页 - Me → 购买结果弹窗，My Balance 余额卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'My Balance'**
  String get meMyBalance;

  /// 首页 - Me → 购买结果弹窗，商品卡片的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Sold Out'**
  String get meSoldOut;

  /// 首页 - Me → 购买结果弹窗，商品价格的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'USD'**
  String get meUsd;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Complete user session is required for model list'**
  String get memoryCompleteUserSession;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Model list permission denied for this World'**
  String get memoryModelListPermissionDenied;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get memorySaveFailed;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Save result not confirmed'**
  String get memorySaveResultNotConfirmed;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域的标题
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get memoryChooseModel;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域的标题
  ///
  /// In en, this message translates to:
  /// **'Max memory token limit'**
  String get memoryMaxTokenLimit;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get memoryNoModelsAvailable;

  /// 首页 - Me → Memory & Model 页，Memory 设置区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Retry ranges'**
  String get memoryRetryRanges;

  /// 首页 - Me → Memory & Model 页，当前 Memory 摘要区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Your current memory usage'**
  String get memoryCurrentUsage;

  /// 首页 - Me → Memory & Model 页，AI Model 选择卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'{min} gems'**
  String memoryMinGems({required String min});

  /// 首页 - Me → Memory & Model 页，AI Model 选择卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} gems'**
  String memoryMinMaxGems({required String min, required String max});

  /// 首页 - Me → Memory & Model 页，AI Model 选择卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'memory {memoryStart}'**
  String memoryStart({required String memoryStart});

  /// 首页 - Me → Memory & Model 页，AI Model 选择卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'memory {memoryStart} → {memoryEnd}'**
  String memoryStartEnd({
    required String memoryStart,
    required String memoryEnd,
  });

  /// 首页 - Me → Memory & Model 页，Memory 设置区域出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Memory settings unavailable'**
  String get memorySettingsUnavailable;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play took too long to respond. Please try again.'**
  String get premiumGooglePlayTookTooLong;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are not supported by Google Play on this device.'**
  String get premiumSubscriptionsNotSupported;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The connection to Google Play was lost. Please try again.'**
  String get premiumConnectionGooglePlayLost;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled.'**
  String get premiumPurchaseCanceled;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play is temporarily unavailable. Please try again later.'**
  String get premiumGooglePlayTemporarily;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play billing is unavailable. Please check your Play account and payment settings.'**
  String get premiumGooglePlayBilling;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This Premium subscription is currently unavailable on Google Play.'**
  String get premiumSubscriptionUnavailable;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play could not complete this Premium purchase. Please try again.'**
  String get premiumGooglePlayFailedComplete;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'You already own this subscription on Google Play.'**
  String get premiumAlreadyOwnSubscription;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play could not find the subscription to change. Please check Manage subscriptions.'**
  String get premiumGooglePlayFailedFind;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Google Play. Please check your internet connection and try again.'**
  String get premiumFailedConnectGooglePlay;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Your payment method has insufficient funds. Please update it in Google Play and try again.'**
  String get premiumInsufficientFunds;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Your Google Play account is not eligible for this subscription offer.'**
  String get premiumGoogleAccountIneligible;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store could not complete this Premium purchase. Please try again.'**
  String get premiumAppStoreFailedComplete;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the App Store. Please check your internet connection and try again.'**
  String get premiumFailedConnectAppStore;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store took too long to respond. Please try again.'**
  String get premiumAppStoreTookTooLong;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store encountered a system error. Please try again later.'**
  String get premiumAppStoreEncounteredSystem;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This Premium subscription is not available in your App Store region.'**
  String get premiumRegionUnavailable;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This app cannot make this App Store request. Please contact support.'**
  String get premiumAppCannotMakeStoreRequest;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This purchase is not supported on this device or system version.'**
  String get premiumPurchaseNotSupported;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store purchase window could not open. Please return to the app and try again.'**
  String get premiumAppStorePurchaseWindow;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store could not accept this purchase quantity. Please contact support.'**
  String get premiumAppStoreFailedAccept;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This Premium subscription is currently unavailable on the App Store.'**
  String get premiumAppStoreUnavailable;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Purchases are not allowed on this device. Please check your Apple Account and purchase restrictions.'**
  String get premiumPurchasesNotAllowedDevice;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Your Apple Account is not eligible for this subscription offer.'**
  String get premiumAppleAccountNotEligible;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This subscription offer is unavailable. Please refresh the page and try again.'**
  String get premiumSubscriptionOffer;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store could not accept this offer price. Please refresh the page and try again.'**
  String get premiumAppStoreFailedAcceptOffer;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store could not verify this subscription offer. Please contact support.'**
  String get premiumAppStoreFailedVerify;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This subscription offer could not be prepared. Please refresh the page and try again.'**
  String get premiumSubscriptionOfferFailed;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Please add a payment method to your Apple Account, then try again.'**
  String get premiumAddPaymentMethodApple;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This app cannot make purchases on the App Store. Please contact support.'**
  String get premiumAppCannotMakePurchases;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store could not accept this purchase request. Please try again or contact support.'**
  String get premiumAppStoreRequestRejected;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Apple cloud service access was denied. Please check your Apple Account permissions.'**
  String get premiumAppleCloudServiceAccess;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Apple services. Please check your internet connection and try again.'**
  String get premiumFailedConnectApple;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Apple cloud service access was revoked. Please check your Apple Account settings.'**
  String get premiumAccess2AppleCloudService;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Please accept the latest Apple privacy terms in your Apple Account, then try again.'**
  String get premiumAcceptLatestApplePrivacy;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store window could not be configured. Please contact support.'**
  String get premiumAppStoreWindowFailed;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store window took too long to open. Please try again.'**
  String get premiumAppStoreWindowTookTooLong;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Please return to the app and try your purchase again.'**
  String get premiumReturnAppTryPurchase;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play is unavailable. Please check that it is installed and you are signed in.'**
  String get premiumGooglePlayUnavailable;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This Premium subscription is currently unavailable in the store. Please refresh the page and try again.'**
  String get premiumIs4Subscription;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This Premium subscription could not be prepared. Please refresh the page and try again.'**
  String get premiumSubscriptionFailed;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The store could not open this Premium purchase. Please try again.'**
  String get premiumStoreFailedOpenPurchase;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The original subscription was not found in Google Play. Please check Manage subscriptions.'**
  String get premiumOriginalSubscriptionMissing;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'This subscription uses a different purchase identity. Please refresh the page or contact support.'**
  String get premiumSubscriptionUsesDifferent;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Google Play cannot change this subscription yet. Please check Manage subscriptions.'**
  String get premiumGooglePlayCannotChange;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'An App Store purchase for this plan is still being processed. Please wait for it to finish.'**
  String get premiumPlanChangePending;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Could not load Premium plans from the App Store. Please try again.'**
  String get premiumFailedLoadPlansAppStore;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Purchase preparation expired. Please try again.'**
  String get premiumPurchasePreparation;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'The App Store returned an unknown purchase result. Please check your subscription before trying again.'**
  String get premiumAppStoreReturnedUnknown;

  /// 首页 - Me → Premium 订阅，订阅预检查结果
  ///
  /// In en, this message translates to:
  /// **'Purchases are currently unavailable.'**
  String get premiumPurchasesUnavailable;

  /// 首页 - Me → Premium 订阅，权益介绍区中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Auto-renews. Cancel anytime.'**
  String get premiumAutoRenewsCancelAnytime;

  /// 首页 - Me → Premium 订阅，订阅按钮
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get premiumSubscribed;

  /// 首页 - Me → Premium 订阅，页面内容区域的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Also included'**
  String get premiumAlsoIncluded;

  /// 首页 - Me → Premium 订阅，顶部品牌标题
  ///
  /// In en, this message translates to:
  /// **'Worldo Premium'**
  String get premiumWorldo;

  /// 首页 - Me → Premium 订阅，Gems 权益卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Pink Gems'**
  String get premiumPinkGems;

  /// 首页 - Me → Premium 订阅，Gems 权益卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Red Gems'**
  String get premiumRedGems;

  /// 首页 - Me → Premium 订阅，Gems 权益卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Extra, daily check-in'**
  String get premiumExtraDailyCheck;

  /// 首页 - Me → Premium 订阅，Gems 权益卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Daily check-in'**
  String get premiumDailyCheck;

  /// 首页 - Me → Premium 订阅，Gems 权益卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Claimed monthly'**
  String get premiumClaimedMonthly;

  /// 首页 - Me → Premium 订阅，套餐卡片中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Billed monthly'**
  String get premiumBilledMonthly;

  /// 首页 - Me → Premium 订阅，年付节省标签
  ///
  /// In en, this message translates to:
  /// **'Save {savings}%'**
  String premiumSaveSavings({required String savings});

  /// 首页 - Me → Premium 订阅，订阅按钮
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get premiumSubscribe;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'An active yearly Premium subscription cannot be changed to a monthly plan.'**
  String get premiumActiveYearlySubscription;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'You already have an active Premium subscription.'**
  String get premiumAlreadyHaveActive;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'You’re already subscribed to Premium {label}.'**
  String premiumReAlreadySubscribedLabel({required String label});

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Your previous Premium purchase is still being confirmed.'**
  String get premiumPreviousPurchasePending;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Please use the original store to upgrade your Premium subscription.'**
  String get premiumUseOriginalStoreUpgrade;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Please resolve your current subscription in the store before purchasing.'**
  String get premiumResolveCurrent;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Premium purchase is currently unavailable.'**
  String get premiumPurchaseUnavailable;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to verify purchase eligibility. Please try again.'**
  String get premiumUnableVerifyPurchase;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'The store could not verify this Premium purchase.'**
  String get premiumStoreFailedVerifyPurchase;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'The Premium purchase does not match the selected plan.'**
  String get premiumPurchaseDoesNotMatch;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'This Premium purchase was canceled.'**
  String get premiumMessagePurchaseCanceled;

  /// 首页 - Me → Premium 订阅，用户不满足订阅购买条件出错时显示的提示
  ///
  /// In en, this message translates to:
  /// **'This Premium purchase was revoked.'**
  String get premiumPurchaseRevoked;

  /// 首页 - Me → Premium 订阅，用户无法购买订阅时的提示弹窗
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get premiumNotification;

  /// 首页 - Me → Premium 订阅，用户无法购买订阅时的提示弹窗
  ///
  /// In en, this message translates to:
  /// **'Worldo Premium is active in your subscription and does not support downgrades.'**
  String get premiumWorldoActiveSubscription;

  /// 首页 - Me → Premium 订阅，用户无法购买订阅时的提示弹窗
  ///
  /// In en, this message translates to:
  /// **'Got It'**
  String get premiumGot;

  /// 首页 - Me → Gems 余额提示，Gems 余额不足时的购买提示
  ///
  /// In en, this message translates to:
  /// **'Insufficient Gems'**
  String get gemBalancePromptInsufficientGems;

  /// 首页 - Me → Gems 余额提示，Gems 余额不足时的购买提示
  ///
  /// In en, this message translates to:
  /// **'Low Gems'**
  String get gemBalancePromptLowGems;

  /// App 退出提示，连续返回准备退出 App时显示的提示
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit.'**
  String get appPressBackExit;

  /// 举报弹窗，举报内容时的菜单和原因选择弹窗
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get appReportSubmitted;

  /// 举报弹窗，举报内容时的菜单和原因选择弹窗
  ///
  /// In en, this message translates to:
  /// **'Report failed'**
  String get appReportFailed;

  /// 强制更新弹窗，App 版本过低时的强制更新页面中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get appUpdateRequired;

  /// 强制更新页，服务端未下发更新说明时显示的默认正文
  ///
  /// In en, this message translates to:
  /// **'Please update to the latest version to continue using Worldo.'**
  String get appUpdateContent;

  /// 强制更新页，显示服务端下发的最新版本号
  ///
  /// In en, this message translates to:
  /// **'Version {versionName}'**
  String appUpdateVersion({required String versionName});

  /// 强制更新页，重新检查版本状态失败时的提示
  ///
  /// In en, this message translates to:
  /// **'Unable to refresh update status. Please update to continue.'**
  String get appUpdateCheckFailed;

  /// 强制更新弹窗，App 版本过低时的强制更新页面的按钮或标签
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get appUpdate;

  /// 通用 ID 信息，点击复制 ID 完成
  ///
  /// In en, this message translates to:
  /// **'{normalizedLabel} copied'**
  String commonIdCopied({required String normalizedLabel});

  /// 通用 Sheet，底部面板右上角的关闭按钮
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// 图片裁剪页，图片加载失败时的居中错误提示
  ///
  /// In en, this message translates to:
  /// **'Image load failed'**
  String get commonImageLoadFailed;

  /// 页面不存在页，打开不存在的页面中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Page not found.'**
  String get commonPageNotFound;

  /// 首页 - Home → World 详情页，已进入 World 的角色摘要中的 Tick 编号
  ///
  /// In en, this message translates to:
  /// **'Tick {tickCount}{subTickSuffix}'**
  String worldDetailTickCount({
    required String tickCount,
    required String subTickSuffix,
  });

  /// 首页 - Home → World Tick 事件卡片，聊天样式事件头部的 Tick 编号
  ///
  /// In en, this message translates to:
  /// **'Tick {tickNumber}{subTickSuffix}'**
  String worldDetailItemTickNumber({
    required String tickNumber,
    required String subTickSuffix,
  });

  /// 首页 - Home → World Tick 事件卡片，卡片顶部的 Tick 编号和日期
  ///
  /// In en, this message translates to:
  /// **'Tick {tickNumber}{subTickSuffix}{dateSuffix}'**
  String worldDetailHeaderTickNumber({
    required String tickNumber,
    required String subTickSuffix,
    required String dateSuffix,
  });

  /// 首页 - Home → 首次 Tick 等待弹窗，生成中的提示及动态省略号
  ///
  /// In en, this message translates to:
  /// **'LLM is generating your first tick. This may take a moment{progressDots}'**
  String worldFirstTickGenerating({required String progressDots});

  /// 首页 - Worldo → Worldo 详情面板，最新版本及更新时间
  ///
  /// In en, this message translates to:
  /// **'Latest Version: V{version}{ageSuffix}'**
  String worldoLatestVersion({
    required String version,
    required String ageSuffix,
  });

  /// 首页 - Create → Create Worldo 提交校验，部分模块尚未保存时的提示
  ///
  /// In en, this message translates to:
  /// **'Please save {missingSections} before creating.'**
  String createSaveBeforeCreating({required String missingSections});

  /// 首页 - Create → Worldo 编辑 - Characters，角色字段表单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The character\'\'s role in the worldo.'**
  String get createCharacterRoleHint;

  /// 首页 - Create → Worldo 编辑 - Characters，角色字段表单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The character\'\'s manner of speaking and behaving, which drives their dialogue.'**
  String get createCharacterMannerHint;

  /// 首页 - Create → Worldo 编辑 - Characters，角色字段表单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The character\'\'s goal or behavioral direction, which drives how they act.'**
  String get createCharacterGoalHint;

  /// 首页 - Create → Worldo 编辑 - Characters，角色字段表单中显示的文字
  ///
  /// In en, this message translates to:
  /// **'The character\'\'s background and relationships.'**
  String get createCharacterBackgroundHint;

  /// 首页 - Inbox → 加入 World 的申请通知，审核弹窗标题中的 World 名称及可选 ID
  ///
  /// In en, this message translates to:
  /// **'request to {world}{worldIdSuffix}'**
  String inboxJoinRequestTitle({
    required String world,
    required String worldIdSuffix,
  });

  /// 首页 - Me → Memory & Model 页，Memory 设置区域中显示的文字
  ///
  /// In en, this message translates to:
  /// **'Memory & Model'**
  String get memoryModel;

  /// 首页 - Me → Premium 订阅，App Store 或 Google Play 返回购买错误
  ///
  /// In en, this message translates to:
  /// **'Account identifiers don\'\'t match the previous subscription.'**
  String get premiumAccountMismatch;

  /// World detail bottom sheet tab for the story recap.
  ///
  /// In en, this message translates to:
  /// **'Recap'**
  String get worldRecap;

  /// Inbox approval action cannot proceed because the join request ID is missing.
  ///
  /// In en, this message translates to:
  /// **'Missing join request ID'**
  String get inboxMissingJoinRequestId;

  /// Login error toast after a sign-in request times out.
  ///
  /// In en, this message translates to:
  /// **'Sign-in timed out. Please try again.'**
  String get loginTimedOut;

  /// Login toast for a transport failure with no server message.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your internet connection and try again.'**
  String get loginConnectionFailed;

  /// Login toast for HTTP or gateway failure with no server message.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is temporarily unavailable. Please try again later.'**
  String get loginTemporarilyUnavailable;

  /// Heading suffix following Worldo Premium on the story recap subscription upsell.
  ///
  /// In en, this message translates to:
  /// **'Unlocks Recap'**
  String get recapUnlockHeading;

  /// Story recap subscription upsell description.
  ///
  /// In en, this message translates to:
  /// **'Catch up on your story with a full recap of every twist, choice, and character along the way.'**
  String get recapUpsellDescription;

  /// Button loading previous story recap pages.
  ///
  /// In en, this message translates to:
  /// **'Show earlier recap'**
  String get recapShowEarlier;

  /// Empty story recap section after a successful request with no summaries.
  ///
  /// In en, this message translates to:
  /// **'Story recap will appear here as the story moves forward.'**
  String get recapEmpty;

  /// Location chat input hint when narrator mode is selected.
  ///
  /// In en, this message translates to:
  /// **'Message as the Narrator'**
  String get chatMessageAsNarrator;

  /// Location chat input hint naming the player character.
  ///
  /// In en, this message translates to:
  /// **'Message as {name}'**
  String chatMessageAsCharacter({required String name});

  /// Accessibility speaker name for narrator mode.
  ///
  /// In en, this message translates to:
  /// **'the Narrator'**
  String get chatNarratorSpeaker;

  /// Accessibility speaker fallback while the player character name is unavailable.
  ///
  /// In en, this message translates to:
  /// **'your character'**
  String get chatYourCharacterSpeaker;

  /// Accessibility label for location chat speaker toggle.
  ///
  /// In en, this message translates to:
  /// **'Speaking as {speaker}'**
  String chatSpeakingAs({required String speaker});

  /// Tooltip for switching from narration to character chat.
  ///
  /// In en, this message translates to:
  /// **'Switch to character'**
  String get chatSwitchCharacter;

  /// Tooltip for switching from character chat to narration.
  ///
  /// In en, this message translates to:
  /// **'Switch to narration'**
  String get chatSwitchNarration;

  /// Accessible button label opening a character movement destination.
  ///
  /// In en, this message translates to:
  /// **'Open {locationName}'**
  String chatOpenLocation({required String locationName});

  /// Accessibility label on the narrator message retry control.
  ///
  /// In en, this message translates to:
  /// **'Retry message'**
  String get chatRetryMessage;

  /// Profile and blocked-user settings toast when block succeeded but report submission failed.
  ///
  /// In en, this message translates to:
  /// **'User blocked, but reporting failed.'**
  String get blockedReportFailed;

  /// Billing toast when the store cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the store. Please try again.'**
  String get storeConnectionFailed;

  /// Billing toast when selected store product is unavailable.
  ///
  /// In en, this message translates to:
  /// **'This product is currently unavailable.'**
  String get storeProductUnavailable;

  /// Billing toast when the device does not allow purchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable on this device.'**
  String get storeDevicePurchasesUnavailable;

  /// Developer history query failure toast; World History refers to world chat history.
  ///
  /// In en, this message translates to:
  /// **'World History request failed'**
  String get worldHistoryRequestFailed;

  /// Default API error toast when the server supplies no user-facing error message and caller provides no specific fallback.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get genericError;

  /// Accessibility label on a selectable Premium plan card; price includes currency and the selected period is year or month.
  ///
  /// In en, this message translates to:
  /// **'{period, select, year{{plan} Premium, {price} per year} other{{plan} Premium, {price} per month}}'**
  String subscriptionPlanAccessibility({
    required String period,
    required String plan,
    required String price,
  });

  /// Developer settings toast when clearing cached data or gateway configuration fails.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get developerClearFailed;

  /// Developer gateway signature check failure toast.
  ///
  /// In en, this message translates to:
  /// **'Gateway signature verification failed'**
  String get developerGatewaySignatureFailed;

  /// Developer endpoint settings success toast; new requests use the saved endpoint configuration.
  ///
  /// In en, this message translates to:
  /// **'Saved. New requests use endpoints.'**
  String get developerEndpointsSaved;

  /// Developer settings instruction after changing the Adjust environment; shown as a separate sentence after the save success message.
  ///
  /// In en, this message translates to:
  /// **'Restart app to apply Adjust environment.'**
  String get developerAdjustRestartRequired;

  /// Developer settings row showing the selected story recap preview mode.
  ///
  /// In en, this message translates to:
  /// **'World recap: {mode}'**
  String developerRecapSetting({required String mode});

  /// Title of the developer story recap preview selector dialog.
  ///
  /// In en, this message translates to:
  /// **'World recap preview'**
  String get developerRecapPreview;

  /// Developer recap preview explanation: overrides membership and recap content temporarily; resets on restart.
  ///
  /// In en, this message translates to:
  /// **'Stands in for membership and recap content on the World sheet. Resets when the app restarts.'**
  String get developerRecapPreviewDescription;

  /// Developer version/reset settings failure toast.
  ///
  /// In en, this message translates to:
  /// **'Reset failed'**
  String get developerResetFailed;

  /// Recap debug selector: disable the Recap-specific simulation and follow current membership, including any developer membership override.
  ///
  /// In en, this message translates to:
  /// **'Off (follows membership)'**
  String get developerRecapOff;

  /// Recap debug selector: simulate a user without a subscription.
  ///
  /// In en, this message translates to:
  /// **'Locked · non-member'**
  String get developerRecapLocked;

  /// Recap debug selector: simulate subscription with no recap generated.
  ///
  /// In en, this message translates to:
  /// **'Member · not generated yet'**
  String get developerRecapEmpty;

  /// Recap debug selector: simulate subscription and display sample recap text.
  ///
  /// In en, this message translates to:
  /// **'Member · sample recap'**
  String get developerRecapSample;

  /// Recap debug selector: simulate subscription but load actual server recap content.
  ///
  /// In en, this message translates to:
  /// **'Member · live recap'**
  String get developerRecapLive;

  /// Location chat reply editor: toast when saving edited replies returns server error 2030 because free edit uses are exhausted; a Premium subscription sheet opens and the draft stays intact.
  ///
  /// In en, this message translates to:
  /// **'No free edits remaining.'**
  String get chatEditFreeUsesExhausted;

  /// Developer settings button: displays the selected temporary membership override.
  ///
  /// In en, this message translates to:
  /// **'Membership: {selection}'**
  String developerMembershipSetting({required String selection});

  /// Developer membership override selector: explanation that only client display state is overridden, server permissions stay real, and restart resets the override.
  ///
  /// In en, this message translates to:
  /// **'Temporarily overrides this account’s membership on every screen. The server still uses the real account status. Resets when the app restarts.'**
  String get developerMembershipDescription;

  /// Developer membership override selector: option disabling the override and using real account membership.
  ///
  /// In en, this message translates to:
  /// **'Off (real membership)'**
  String get developerMembershipOff;

  /// Developer membership override selector: simulates annual Premium membership.
  ///
  /// In en, this message translates to:
  /// **'Premium · yearly'**
  String get developerMembershipYearly;

  /// Developer membership override selector: simulates monthly Premium membership.
  ///
  /// In en, this message translates to:
  /// **'Premium · monthly'**
  String get developerMembershipMonthly;

  /// Developer membership override selector: simulates a user without membership.
  ///
  /// In en, this message translates to:
  /// **'Non-member'**
  String get developerMembershipNone;

  /// Worldo location preview: heading above role selector before starting a world.
  ///
  /// In en, this message translates to:
  /// **'Start by selecting your role'**
  String get originStartBySelectingRole;

  /// Worldo location preview: standalone heading above the recommended starting-location card. The destination name is displayed in the card below, not in this heading.
  ///
  /// In en, this message translates to:
  /// **'Recommended start'**
  String get originRecommendedStart;

  /// Worldo location preview: fallback name for the recommended starting point when its location has no name.
  ///
  /// In en, this message translates to:
  /// **'Story Opening'**
  String get originStoryOpening;

  /// Worldo location preview: fallback destination label when the opening location is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Opening location'**
  String get originOpeningLocation;

  /// Worldo location recommendation card: complete sentence naming the characters currently at the opening location. Names and location are styled placeholders; retain the line break.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{names} is now at\n{locationName}} other{{names} are now at\n{locationName}}}'**
  String originCharactersAtLocation({
    required int count,
    required String names,
    required String locationName,
  });

  /// Worldo location recommendation card with no known occupants: title plus dynamic destination on a new line.
  ///
  /// In en, this message translates to:
  /// **'Story Opening\n{locationName}'**
  String originOpeningJump({required String locationName});

  /// Location chat: action on a collapsed contiguous history section from another location; reveals that section's messages for reading.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get chatHistoryExpand;

  /// Location chat: fixed lower-right button that collapses an expanded history section from another location back to its section header; does not leave or change the actual joined location.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatHistoryCollapse;

  /// World detail page: tab label for read-only chat history from all locations in the current world, displayed in chronological order. Refers to past chat messages, not historical lore; opening the tab does not join a location or allow sending messages.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get worldHistory;

  /// World detail History tab: empty-state message after chat history has loaded successfully and no messages exist across any location in the current world. This read-only view displays chat messages in chronological order; this text is not shown for loading or request failures.
  ///
  /// In en, this message translates to:
  /// **'Your World’s chat history will appear here.'**
  String get worldHistoryEmpty;

  /// World detail History tab: heading above the location card at the end of each location's most recent chat segment. Tapping the card opens that location's live chat to continue the story.
  ///
  /// In en, this message translates to:
  /// **'Continue here'**
  String get worldHistoryContinueHere;

  /// Tick message: heading above character destination jump cards.
  ///
  /// In en, this message translates to:
  /// **'Character movement'**
  String get chatCharacterMovement;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'ko',
    'pt',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

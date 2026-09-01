import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ja'),
    Locale('pt'),
    Locale('tr'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get aboutApp;

  /// No description provided for @actionTriggered.
  ///
  /// In en, this message translates to:
  /// **'{action} triggered'**
  String actionTriggered(Object action);

  /// Generic Add button label.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @agentLabelWith.
  ///
  /// In en, this message translates to:
  /// **'Agent: {agent}'**
  String agentLabelWith(Object agent);

  /// No description provided for @agentLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get agentLocal;

  /// No description provided for @agentNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get agentNone;

  /// No description provided for @agentRunsOnServer.
  ///
  /// In en, this message translates to:
  /// **'Agent runs on the server with project-level access'**
  String get agentRunsOnServer;

  /// No description provided for @agentTriggeredFor.
  ///
  /// In en, this message translates to:
  /// **'{agent} AI triggered for \"{title}\"'**
  String agentTriggeredFor(Object agent, Object title);

  /// No description provided for @aiAgent.
  ///
  /// In en, this message translates to:
  /// **'AI Agent'**
  String get aiAgent;

  /// No description provided for @aiAgentUpdated.
  ///
  /// In en, this message translates to:
  /// **'AI agent updated'**
  String get aiAgentUpdated;

  /// No description provided for @aiResponse.
  ///
  /// In en, this message translates to:
  /// **'AI Response'**
  String get aiResponse;

  /// No description provided for @allApps.
  ///
  /// In en, this message translates to:
  /// **'All Apps'**
  String get allApps;

  /// No description provided for @allAppsCompletedOrPostponed.
  ///
  /// In en, this message translates to:
  /// **'All apps are completed or postponed'**
  String get allAppsCompletedOrPostponed;

  /// No description provided for @allAppsHaveAutomations.
  ///
  /// In en, this message translates to:
  /// **'All apps already have automations'**
  String get allAppsHaveAutomations;

  /// No description provided for @allAppsHint.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get allAppsHint;

  /// No description provided for @allPendingBlocked.
  ///
  /// In en, this message translates to:
  /// **'All pending items are blocked by dependencies'**
  String get allPendingBlocked;

  /// No description provided for @apiConnection.
  ///
  /// In en, this message translates to:
  /// **'API Connection'**
  String get apiConnection;

  /// No description provided for @apiUrlSaved.
  ///
  /// In en, this message translates to:
  /// **'API URL saved'**
  String get apiUrlSaved;

  /// No description provided for @appCreated.
  ///
  /// In en, this message translates to:
  /// **'App created!'**
  String get appCreated;

  /// No description provided for @appDetail.
  ///
  /// In en, this message translates to:
  /// **'App Detail'**
  String get appDetail;

  /// No description provided for @appFallback.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get appFallback;

  /// No description provided for @appNameHint.
  ///
  /// In en, this message translates to:
  /// **'App Name (e.g. My Game)'**
  String get appNameHint;

  /// No description provided for @appStatusBuilding.
  ///
  /// In en, this message translates to:
  /// **'building'**
  String get appStatusBuilding;

  /// No description provided for @appStatusDeploying.
  ///
  /// In en, this message translates to:
  /// **'deploying'**
  String get appStatusDeploying;

  /// No description provided for @appStatusError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get appStatusError;

  /// No description provided for @appStatusFixing.
  ///
  /// In en, this message translates to:
  /// **'fixing'**
  String get appStatusFixing;

  /// No description provided for @appStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get appStatusIdle;

  /// No description provided for @appStatusPublished.
  ///
  /// In en, this message translates to:
  /// **'published'**
  String get appStatusPublished;

  /// No description provided for @appStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get appStatusQueued;

  /// No description provided for @appStatusUploading.
  ///
  /// In en, this message translates to:
  /// **'uploading'**
  String get appStatusUploading;

  /// No description provided for @appStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'working'**
  String get appStatusWorking;

  /// The application title displayed in the launcher and as a fallback.
  ///
  /// In en, this message translates to:
  /// **'Auto Game Builder'**
  String get appTitle;

  /// No description provided for @appTypeFlutterDesc.
  ///
  /// In en, this message translates to:
  /// **'Mobile/desktop app with Google Play deploy support'**
  String get appTypeFlutterDesc;

  /// No description provided for @appTypeGodotDesc.
  ///
  /// In en, this message translates to:
  /// **'Game project with export targets (Windows, Android, Web)'**
  String get appTypeGodotDesc;

  /// No description provided for @appTypePhaserDesc.
  ///
  /// In en, this message translates to:
  /// **'Phaser 3 + TypeScript game, wrapped as Android AAB via Capacitor'**
  String get appTypePhaserDesc;

  /// No description provided for @appTypePythonDesc.
  ///
  /// In en, this message translates to:
  /// **'Python project with script runner and pip management'**
  String get appTypePythonDesc;

  /// No description provided for @appTypeWebDesc.
  ///
  /// In en, this message translates to:
  /// **'Web app with static hosting deploy support'**
  String get appTypeWebDesc;

  /// Apps tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get apps;

  /// No description provided for @archivedLabel.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get archivedLabel;

  /// No description provided for @artAndAssets.
  ///
  /// In en, this message translates to:
  /// **'Art & Assets'**
  String get artAndAssets;

  /// No description provided for @artBible.
  ///
  /// In en, this message translates to:
  /// **'Art Bible'**
  String get artBible;

  /// No description provided for @artBibleCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visual identity anchor doc'**
  String get artBibleCardSubtitle;

  /// No description provided for @artBibleHint.
  ///
  /// In en, this message translates to:
  /// **'Identity statement, palette (hex), typography, prohibitions, technical specs...'**
  String get artBibleHint;

  /// No description provided for @artBibleSaved.
  ///
  /// In en, this message translates to:
  /// **'Art bible saved'**
  String get artBibleSaved;

  /// No description provided for @artBibleShort.
  ///
  /// In en, this message translates to:
  /// **'Art bible'**
  String get artBibleShort;

  /// No description provided for @artBibleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visual identity anchor — palette, typography, style prohibitions. Every asset task references this.'**
  String get artBibleSubtitle;

  /// No description provided for @artBibleTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Art bible task created'**
  String get artBibleTaskCreated;

  /// No description provided for @artBibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Art Bible - {app}'**
  String artBibleTitle(Object app);

  /// No description provided for @askAQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question...'**
  String get askAQuestionHint;

  /// No description provided for @askAgent.
  ///
  /// In en, this message translates to:
  /// **'Ask Agent'**
  String get askAgent;

  /// No description provided for @askAnythingAboutYourApps.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your apps'**
  String get askAnythingAboutYourApps;

  /// No description provided for @assetAudit.
  ///
  /// In en, this message translates to:
  /// **'Asset Audit'**
  String get assetAudit;

  /// No description provided for @assetAuditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Broken refs, orphans, placeholders'**
  String get assetAuditSubtitle;

  /// No description provided for @assetAuditTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Asset audit task created'**
  String get assetAuditTaskCreated;

  /// No description provided for @assetSpecTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Asset spec task created'**
  String get assetSpecTaskCreated;

  /// No description provided for @assetSpecs.
  ///
  /// In en, this message translates to:
  /// **'Asset Specs'**
  String get assetSpecs;

  /// No description provided for @assetSpecsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Per-asset prompts from bible'**
  String get assetSpecsSubtitle;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @attachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'Attachments ({count})'**
  String attachmentsCount(Object count);

  /// No description provided for @automationCreated.
  ///
  /// In en, this message translates to:
  /// **'Automation created'**
  String get automationCreated;

  /// No description provided for @automationStateStarted.
  ///
  /// In en, this message translates to:
  /// **'started'**
  String get automationStateStarted;

  /// No description provided for @automationStateStopped.
  ///
  /// In en, this message translates to:
  /// **'stopped'**
  String get automationStateStopped;

  /// No description provided for @automationToggled.
  ///
  /// In en, this message translates to:
  /// **'{app} {state}'**
  String automationToggled(Object app, Object state);

  /// No description provided for @automationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Automation updated'**
  String get automationUpdated;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backend;

  /// No description provided for @balanceCheck.
  ///
  /// In en, this message translates to:
  /// **'Balance Check'**
  String get balanceCheck;

  /// No description provided for @balanceCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Economy, progression, rewards'**
  String get balanceCheckSubtitle;

  /// No description provided for @balanceCheckTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Balance check task created'**
  String get balanceCheckTaskCreated;

  /// No description provided for @batchRunError.
  ///
  /// In en, this message translates to:
  /// **'Error during batch run: {error}'**
  String batchRunError(Object error);

  /// No description provided for @blockedByList.
  ///
  /// In en, this message translates to:
  /// **'blocked by {ids}'**
  String blockedByList(Object ids);

  /// No description provided for @blockedByTask.
  ///
  /// In en, this message translates to:
  /// **'Blocked by #{id}'**
  String blockedByTask(Object id);

  /// No description provided for @blockedCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked'**
  String blockedCountLabel(Object count);

  /// No description provided for @blockerNotInList.
  ///
  /// In en, this message translates to:
  /// **'Task #{id} is not in the current list (archived or deleted)'**
  String blockerNotInList(Object id);

  /// No description provided for @brainstormAndCreate.
  ///
  /// In en, this message translates to:
  /// **'Brainstorm & Create'**
  String get brainstormAndCreate;

  /// No description provided for @brainstormConceptHint.
  ///
  /// In en, this message translates to:
  /// **'Concept seed (e.g. \"ant colony idle game\", \"puzzle with gravity\")'**
  String get brainstormConceptHint;

  /// No description provided for @brainstormCreated.
  ///
  /// In en, this message translates to:
  /// **'Project created with brainstorm task!'**
  String get brainstormCreated;

  /// No description provided for @brainstormDesc.
  ///
  /// In en, this message translates to:
  /// **'Creates a new project with a brainstorm task. When the task runs, AI generates a full GDD and initial tasks.'**
  String get brainstormDesc;

  /// No description provided for @brainstormNameHint.
  ///
  /// In en, this message translates to:
  /// **'Project name (optional — AI can suggest)'**
  String get brainstormNameHint;

  /// No description provided for @brainstormNewGame.
  ///
  /// In en, this message translates to:
  /// **'Brainstorm New Game'**
  String get brainstormNewGame;

  /// No description provided for @build.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get build;

  /// No description provided for @buildAndDeploy.
  ///
  /// In en, this message translates to:
  /// **'Build & Deploy'**
  String get buildAndDeploy;

  /// No description provided for @buildCancelled.
  ///
  /// In en, this message translates to:
  /// **'Build cancelled'**
  String get buildCancelled;

  /// No description provided for @buildFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'build failed'**
  String get buildFailedLabel;

  /// No description provided for @buildListTitle.
  ///
  /// In en, this message translates to:
  /// **'v{version} - {buildType}'**
  String buildListTitle(Object version, Object buildType);

  /// No description provided for @buildPollingTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Build polling timed out after 30 minutes - check server logs'**
  String get buildPollingTimedOut;

  /// No description provided for @buildTarget.
  ///
  /// In en, this message translates to:
  /// **'Build Target'**
  String get buildTarget;

  /// Builds tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Builds'**
  String get builds;

  /// No description provided for @builtCount.
  ///
  /// In en, this message translates to:
  /// **'Built ({count})'**
  String builtCount(Object count);

  /// No description provided for @buyMeACoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get buyMeACoffee;

  /// No description provided for @buyMeACoffeeWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee  {price}'**
  String buyMeACoffeeWithPrice(Object price);

  /// Generic Cancel button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cannotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server'**
  String get cannotReachServer;

  /// No description provided for @cannotReachServerWith.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server: {error}'**
  String cannotReachServerWith(Object error);

  /// No description provided for @cannotSaveEmptyArtBible.
  ///
  /// In en, this message translates to:
  /// **'Cannot save empty art bible'**
  String get cannotSaveEmptyArtBible;

  /// No description provided for @cannotSaveEmptyClaudeMd.
  ///
  /// In en, this message translates to:
  /// **'Cannot save empty CLAUDE.md'**
  String get cannotSaveEmptyClaudeMd;

  /// No description provided for @cannotSaveEmptyDesignDoc.
  ///
  /// In en, this message translates to:
  /// **'Cannot save empty design document'**
  String get cannotSaveEmptyDesignDoc;

  /// No description provided for @catBugsCrashes.
  ///
  /// In en, this message translates to:
  /// **'Bugs & Crashes'**
  String get catBugsCrashes;

  /// No description provided for @catCodeStyle.
  ///
  /// In en, this message translates to:
  /// **'Code Style'**
  String get catCodeStyle;

  /// No description provided for @catDeadCode.
  ///
  /// In en, this message translates to:
  /// **'Dead Code'**
  String get catDeadCode;

  /// No description provided for @catErrorHandling.
  ///
  /// In en, this message translates to:
  /// **'Error Handling'**
  String get catErrorHandling;

  /// No description provided for @catMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get catMemory;

  /// No description provided for @categoryAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get categoryAccessibility;

  /// No description provided for @categoryBug.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get categoryBug;

  /// No description provided for @categoryFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get categoryFeatures;

  /// No description provided for @categoryMonetization.
  ///
  /// In en, this message translates to:
  /// **'Monetization'**
  String get categoryMonetization;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @categoryPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get categoryPerformance;

  /// No description provided for @categorySecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get categorySecurity;

  /// No description provided for @categorySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get categorySuggestion;

  /// No description provided for @categoryUiUx.
  ///
  /// In en, this message translates to:
  /// **'UI/UX'**
  String get categoryUiUx;

  /// No description provided for @charactersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String charactersCount(Object count);

  /// No description provided for @chatHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatHistory;

  /// Reports & Logs tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get chatLogs;

  /// No description provided for @chatSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} messages • {date}'**
  String chatSessionSubtitle(Object count, Object date);

  /// No description provided for @checkBugsCrashes.
  ///
  /// In en, this message translates to:
  /// **'Bugs & crashes'**
  String get checkBugsCrashes;

  /// No description provided for @checkCodeStyle.
  ///
  /// In en, this message translates to:
  /// **'Code style'**
  String get checkCodeStyle;

  /// No description provided for @checkDeadCode.
  ///
  /// In en, this message translates to:
  /// **'Dead code'**
  String get checkDeadCode;

  /// No description provided for @checkErrorHandling.
  ///
  /// In en, this message translates to:
  /// **'Error handling'**
  String get checkErrorHandling;

  /// No description provided for @checkMemoryLeaks.
  ///
  /// In en, this message translates to:
  /// **'Memory leaks'**
  String get checkMemoryLeaks;

  /// No description provided for @checkPerformanceIssues.
  ///
  /// In en, this message translates to:
  /// **'Performance issues'**
  String get checkPerformanceIssues;

  /// No description provided for @checkSecurityVulnerabilities.
  ///
  /// In en, this message translates to:
  /// **'Security vulnerabilities'**
  String get checkSecurityVulnerabilities;

  /// No description provided for @checksToRun.
  ///
  /// In en, this message translates to:
  /// **'Checks to run:'**
  String get checksToRun;

  /// No description provided for @claudeMdHint.
  ///
  /// In en, this message translates to:
  /// **'Project conventions, build commands, rules...'**
  String get claudeMdHint;

  /// No description provided for @claudeMdSaved.
  ///
  /// In en, this message translates to:
  /// **'CLAUDE.md saved'**
  String get claudeMdSaved;

  /// No description provided for @claudeMdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Project instructions for AI agents working on this app.'**
  String get claudeMdSubtitle;

  /// No description provided for @claudeMdTitle.
  ///
  /// In en, this message translates to:
  /// **'CLAUDE.md - {app}'**
  String claudeMdTitle(Object app);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @clearMessages.
  ///
  /// In en, this message translates to:
  /// **'Clear Messages'**
  String get clearMessages;

  /// No description provided for @clearMessagesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all {count} messages in this chat?'**
  String clearMessagesConfirm(Object count);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @codeCheck.
  ///
  /// In en, this message translates to:
  /// **'Code Check'**
  String get codeCheck;

  /// No description provided for @codeCheckBody.
  ///
  /// In en, this message translates to:
  /// **'This will create a task for the AI agent to review your code and report findings as issues.'**
  String get codeCheckBody;

  /// No description provided for @codeCheckRequested.
  ///
  /// In en, this message translates to:
  /// **'Code check requested'**
  String get codeCheckRequested;

  /// No description provided for @codeCheckResults.
  ///
  /// In en, this message translates to:
  /// **'Code Check Results'**
  String get codeCheckResults;

  /// No description provided for @codeReview.
  ///
  /// In en, this message translates to:
  /// **'Code Review'**
  String get codeReview;

  /// No description provided for @codeReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bugs, crashes, code quality'**
  String get codeReviewSubtitle;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @completedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String completedCount(Object count);

  /// No description provided for @connectToYourServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to Your Server'**
  String get connectToYourServer;

  /// No description provided for @connectYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Connect your phone'**
  String get connectYourPhone;

  /// No description provided for @connectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully'**
  String get connectedSuccessfully;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {server}'**
  String connectedTo(Object server);

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful!'**
  String get connectionSuccessful;

  /// No description provided for @connectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get connectionTimedOut;

  /// No description provided for @consistencyCheck.
  ///
  /// In en, this message translates to:
  /// **'Consistency Check'**
  String get consistencyCheck;

  /// No description provided for @consistencyCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GDD ↔ code ↔ data drift'**
  String get consistencyCheckSubtitle;

  /// No description provided for @consistencyCheckTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Consistency check task created'**
  String get consistencyCheckTaskCreated;

  /// No description provided for @console.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get console;

  /// No description provided for @contentAudit.
  ///
  /// In en, this message translates to:
  /// **'Content Audit'**
  String get contentAudit;

  /// No description provided for @contentAuditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Levels, characters, items, text'**
  String get contentAuditSubtitle;

  /// No description provided for @contentAuditTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Content audit task created'**
  String get contentAuditTaskCreated;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Control tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get control;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copiedToClipboardNamed.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboardNamed(Object label);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyAiResponse.
  ///
  /// In en, this message translates to:
  /// **'Copy AI Response'**
  String get copyAiResponse;

  /// No description provided for @copyDescription.
  ///
  /// In en, this message translates to:
  /// **'Copy Description'**
  String get copyDescription;

  /// No description provided for @copyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy Title'**
  String get copyTitle;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @couldNotDownloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Could not download the PDF'**
  String get couldNotDownloadPdf;

  /// No description provided for @couldNotLoadBuildTargets.
  ///
  /// In en, this message translates to:
  /// **'Could not load build targets'**
  String get couldNotLoadBuildTargets;

  /// No description provided for @couldNotLoadDirectives.
  ///
  /// In en, this message translates to:
  /// **'Could not load directives'**
  String get couldNotLoadDirectives;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get couldNotOpenLink;

  /// No description provided for @couldNotOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Could not open the PDF: {error}'**
  String couldNotOpenPdf(Object error);

  /// No description provided for @couldNotOpenPicker.
  ///
  /// In en, this message translates to:
  /// **'Could not open the picker.'**
  String get couldNotOpenPicker;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createApp.
  ///
  /// In en, this message translates to:
  /// **'Create App'**
  String get createApp;

  /// No description provided for @createFirstApp.
  ///
  /// In en, this message translates to:
  /// **'Create your first app to get started'**
  String get createFirstApp;

  /// No description provided for @createIssue.
  ///
  /// In en, this message translates to:
  /// **'Create Issue'**
  String get createIssue;

  /// No description provided for @createdAgo.
  ///
  /// In en, this message translates to:
  /// **'created {time}'**
  String createdAgo(Object time);

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creating;

  /// No description provided for @criticalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} critical'**
  String criticalCount(Object count);

  /// No description provided for @customAutomationPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Custom automation prompt...'**
  String get customAutomationPromptHint;

  /// No description provided for @customPrompt.
  ///
  /// In en, this message translates to:
  /// **'Custom prompt'**
  String get customPrompt;

  /// Dashboard tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAutomation.
  ///
  /// In en, this message translates to:
  /// **'Delete Automation'**
  String get deleteAutomation;

  /// No description provided for @deleteAutomationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove automation for {app}?'**
  String deleteAutomationConfirm(Object app);

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get deleteChat;

  /// No description provided for @deleteChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get deleteChatConfirm;

  /// No description provided for @deleteConfirmTitled.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?\nThis cannot be undone.'**
  String deleteConfirmTitled(Object title);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get deleteFailed;

  /// No description provided for @deleteReportBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes the report and its screenshots.'**
  String get deleteReportBody;

  /// No description provided for @deleteReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete report?'**
  String get deleteReportTitle;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @dependsOn.
  ///
  /// In en, this message translates to:
  /// **'Depends on'**
  String get dependsOn;

  /// No description provided for @deploy.
  ///
  /// In en, this message translates to:
  /// **'Deploy'**
  String get deploy;

  /// No description provided for @deployToProduction.
  ///
  /// In en, this message translates to:
  /// **'Deploy to Production'**
  String get deployToProduction;

  /// No description provided for @deployToProductionBody.
  ///
  /// In en, this message translates to:
  /// **'This will build and publish to ALL users on Google Play.\n\nMake sure you have tested on internal/beta first.'**
  String get deployToProductionBody;

  /// No description provided for @deployToProductionTitle.
  ///
  /// In en, this message translates to:
  /// **'Deploy to Production?'**
  String get deployToProductionTitle;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description...'**
  String get descriptionHint;

  /// No description provided for @designDoc.
  ///
  /// In en, this message translates to:
  /// **'Design Doc'**
  String get designDoc;

  /// No description provided for @designDocHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your app vision, features, goals...'**
  String get designDocHint;

  /// No description provided for @designDocSaved.
  ///
  /// In en, this message translates to:
  /// **'Design doc saved'**
  String get designDocSaved;

  /// No description provided for @designDocShort.
  ///
  /// In en, this message translates to:
  /// **'Design doc'**
  String get designDocShort;

  /// No description provided for @designDocSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The AI will use this as context for all work on this app.'**
  String get designDocSubtitle;

  /// No description provided for @designDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Design Doc - {app}'**
  String designDocTitle(Object app);

  /// No description provided for @designDocument.
  ///
  /// In en, this message translates to:
  /// **'Design Document'**
  String get designDocument;

  /// No description provided for @designReview.
  ///
  /// In en, this message translates to:
  /// **'Design Review'**
  String get designReview;

  /// No description provided for @designReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GDD, mechanics, UX audit'**
  String get designReviewSubtitle;

  /// No description provided for @designReviewTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Design review task created'**
  String get designReviewTaskCreated;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @detectingServer.
  ///
  /// In en, this message translates to:
  /// **'Detecting server...'**
  String get detectingServer;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @directServerUrlLan.
  ///
  /// In en, this message translates to:
  /// **'Direct Server URL (LAN)'**
  String get directServerUrlLan;

  /// No description provided for @directiveHistory.
  ///
  /// In en, this message translates to:
  /// **'Directive history'**
  String get directiveHistory;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @display.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// No description provided for @doIt.
  ///
  /// In en, this message translates to:
  /// **'Do It'**
  String get doIt;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @doneOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} done'**
  String doneOfTotal(Object done, Object total);

  /// No description provided for @durationLabelWith.
  ///
  /// In en, this message translates to:
  /// **'Duration: {seconds}s'**
  String durationLabelWith(Object seconds);

  /// Generic Edit button label.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editNamed.
  ///
  /// In en, this message translates to:
  /// **'Edit {label}'**
  String editNamed(Object label);

  /// No description provided for @editTitleNamed.
  ///
  /// In en, this message translates to:
  /// **'Edit: {app}'**
  String editTitleNamed(Object app);

  /// No description provided for @editWorkerUrl.
  ///
  /// In en, this message translates to:
  /// **'Edit Worker URL'**
  String get editWorkerUrl;

  /// No description provided for @engine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engine;

  /// No description provided for @engineChanged.
  ///
  /// In en, this message translates to:
  /// **'Engine changed: {previous} -> {current}'**
  String engineChanged(Object previous, Object current);

  /// No description provided for @engineConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Engine confirmed: {engine}'**
  String engineConfirmed(Object engine);

  /// No description provided for @engineDetectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Engine detection failed'**
  String get engineDetectionFailed;

  /// No description provided for @enhance.
  ///
  /// In en, this message translates to:
  /// **'Enhance'**
  String get enhance;

  /// No description provided for @enhanceConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'AI will rewrite the document. This cannot be undone.'**
  String get enhanceConfirmBody;

  /// No description provided for @enhanceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Enhance {label}?'**
  String enhanceConfirmTitle(Object label);

  /// No description provided for @enhanceError.
  ///
  /// In en, this message translates to:
  /// **'{label} enhance error: {error}'**
  String enhanceError(Object label, Object error);

  /// No description provided for @enhanceStarted.
  ///
  /// In en, this message translates to:
  /// **'{label} enhancement started on server...'**
  String enhanceStarted(Object label);

  /// No description provided for @enhanceSucceeded.
  ///
  /// In en, this message translates to:
  /// **'{label} enhanced successfully'**
  String enhanceSucceeded(Object label);

  /// No description provided for @enhancementFailed.
  ///
  /// In en, this message translates to:
  /// **'Enhancement failed'**
  String get enhancementFailed;

  /// No description provided for @enterConceptOrName.
  ///
  /// In en, this message translates to:
  /// **'Enter a concept or project name'**
  String get enterConceptOrName;

  /// No description provided for @enterServerUrlDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the URL of your Auto Game Builder server'**
  String get enterServerUrlDesc;

  /// No description provided for @enterUrlInPhoneApp.
  ///
  /// In en, this message translates to:
  /// **'Enter this URL in the phone app to connect remotely'**
  String get enterUrlInPhoneApp;

  /// No description provided for @enterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid URL (e.g. http://192.168.1.100:8000)'**
  String get enterValidUrl;

  /// No description provided for @enterWorkerUrlDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your Worker URL to connect remotely'**
  String get enterWorkerUrlDesc;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(Object error);

  /// No description provided for @everyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes}m'**
  String everyMinutes(Object minutes);

  /// No description provided for @exitLabelWith.
  ///
  /// In en, this message translates to:
  /// **'Exit: {code}'**
  String exitLabelWith(Object code);

  /// No description provided for @expandFoldersOrCreate.
  ///
  /// In en, this message translates to:
  /// **'Expand the folders below or create a new app'**
  String get expandFoldersOrCreate;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @failedCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String failedCountLabel(Object count);

  /// No description provided for @failedToBrainstorm.
  ///
  /// In en, this message translates to:
  /// **'Failed to brainstorm'**
  String get failedToBrainstorm;

  /// No description provided for @failedToCreateApp.
  ///
  /// In en, this message translates to:
  /// **'Failed to create app'**
  String get failedToCreateApp;

  /// No description provided for @failedToCreateItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to create item'**
  String get failedToCreateItem;

  /// No description provided for @failedToCreateTestTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to create test task'**
  String get failedToCreateTestTask;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get failedToDelete;

  /// No description provided for @failedToLoadApp.
  ///
  /// In en, this message translates to:
  /// **'Failed to load app'**
  String get failedToLoadApp;

  /// No description provided for @failedToLoadAutomations.
  ///
  /// In en, this message translates to:
  /// **'Failed to load automations'**
  String get failedToLoadAutomations;

  /// No description provided for @failedToLoadLogs.
  ///
  /// In en, this message translates to:
  /// **'Failed to load logs'**
  String get failedToLoadLogs;

  /// No description provided for @failedToLoadTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tasks'**
  String get failedToLoadTasks;

  /// No description provided for @failedToLoadWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String failedToLoadWithError(Object error);

  /// No description provided for @failedToRefreshApp.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh app'**
  String get failedToRefreshApp;

  /// No description provided for @failedToRequestCodeCheck.
  ///
  /// In en, this message translates to:
  /// **'Failed to request code check'**
  String get failedToRequestCodeCheck;

  /// No description provided for @failedToRequestIdeas.
  ///
  /// In en, this message translates to:
  /// **'Failed to request ideas'**
  String get failedToRequestIdeas;

  /// No description provided for @failedToReset.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset'**
  String get failedToReset;

  /// No description provided for @failedToRunTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to run task'**
  String get failedToRunTask;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSave(Object error);

  /// No description provided for @failedToStartReupload.
  ///
  /// In en, this message translates to:
  /// **'Failed to start re-upload'**
  String get failedToStartReupload;

  /// No description provided for @failedToStartServer.
  ///
  /// In en, this message translates to:
  /// **'Failed to start server: {error}'**
  String failedToStartServer(Object error);

  /// No description provided for @failedToStartWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to start: {error}'**
  String failedToStartWithError(Object error);

  /// No description provided for @failedToTrigger.
  ///
  /// In en, this message translates to:
  /// **'Failed to trigger {action}'**
  String failedToTrigger(Object action);

  /// No description provided for @failedToTriggerRun.
  ///
  /// In en, this message translates to:
  /// **'Failed to trigger run'**
  String get failedToTriggerRun;

  /// No description provided for @failedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update'**
  String get failedToUpdate;

  /// No description provided for @failedToUpdateAiAgent.
  ///
  /// In en, this message translates to:
  /// **'Failed to update AI agent'**
  String get failedToUpdateAiAgent;

  /// No description provided for @failedToUpdateMcp.
  ///
  /// In en, this message translates to:
  /// **'Failed to update MCP'**
  String get failedToUpdateMcp;

  /// No description provided for @favoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get favoritesOnly;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large (max {max} MB): {files}'**
  String fileTooLarge(Object max, Object files);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get filterClosed;

  /// No description provided for @filterOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get filterOpen;

  /// No description provided for @findingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 finding} other{{count} findings}}'**
  String findingsCount(int count);

  /// No description provided for @finishedDoneAgo.
  ///
  /// In en, this message translates to:
  /// **'done {time}'**
  String finishedDoneAgo(Object time);

  /// No description provided for @finishedFailedAgo.
  ///
  /// In en, this message translates to:
  /// **'failed {time}'**
  String finishedFailedAgo(Object time);

  /// No description provided for @forceRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Force refresh failed: {error}'**
  String forceRefreshFailed(Object error);

  /// No description provided for @forceRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Force refresh from server (clears local cache)'**
  String get forceRefreshTooltip;

  /// No description provided for @fullAutoMode.
  ///
  /// In en, this message translates to:
  /// **'Full Auto Mode'**
  String get fullAutoMode;

  /// No description provided for @fullAutoModeOn.
  ///
  /// In en, this message translates to:
  /// **'AI reads tasks, fixes, generates new ideas, repeats'**
  String get fullAutoModeOn;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @generateIdeas.
  ///
  /// In en, this message translates to:
  /// **'Generate Ideas'**
  String get generateIdeas;

  /// No description provided for @generateIdeasHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Ideas for improving the UI\"'**
  String get generateIdeasHint;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @genreAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get genreAction;

  /// No description provided for @genreAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get genreAny;

  /// No description provided for @genreArcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade'**
  String get genreArcade;

  /// No description provided for @genreCardGame.
  ///
  /// In en, this message translates to:
  /// **'Card Game'**
  String get genreCardGame;

  /// No description provided for @genreIdleClicker.
  ///
  /// In en, this message translates to:
  /// **'Idle/Clicker'**
  String get genreIdleClicker;

  /// No description provided for @genrePuzzle.
  ///
  /// In en, this message translates to:
  /// **'Puzzle'**
  String get genrePuzzle;

  /// No description provided for @genreRpg.
  ///
  /// In en, this message translates to:
  /// **'RPG'**
  String get genreRpg;

  /// No description provided for @genreSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get genreSimulation;

  /// No description provided for @genreStrategy.
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get genreStrategy;

  /// No description provided for @genreTowerDefense.
  ///
  /// In en, this message translates to:
  /// **'Tower Defense'**
  String get genreTowerDefense;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @googleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google Account'**
  String get googleAccount;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @highCount.
  ///
  /// In en, this message translates to:
  /// **'{count} high'**
  String highCount(Object count);

  /// No description provided for @ideaGenerationRequested.
  ///
  /// In en, this message translates to:
  /// **'Idea generation requested'**
  String get ideaGenerationRequested;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'installed'**
  String get installed;

  /// No description provided for @intervalMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval (min): '**
  String get intervalMinLabel;

  /// No description provided for @invalidQrData.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code data'**
  String get invalidQrData;

  /// No description provided for @issueCreated.
  ///
  /// In en, this message translates to:
  /// **'Issue created'**
  String get issueCreated;

  /// No description provided for @issueTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Issue title'**
  String get issueTitleHint;

  /// Issues tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issues;

  /// No description provided for @itemCreated.
  ///
  /// In en, this message translates to:
  /// **'Item created'**
  String get itemCreated;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage your game projects from anywhere'**
  String get loginTagline;

  /// Logs tab label in the bottom navigation.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @maintenanceOnly.
  ///
  /// In en, this message translates to:
  /// **'Maintenance only'**
  String get maintenanceOnly;

  /// No description provided for @markAsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get markAsCompleted;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get markComplete;

  /// No description provided for @markCompleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as completed?'**
  String markCompleteConfirm(Object title);

  /// No description provided for @markedAsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Marked as completed'**
  String get markedAsCompleted;

  /// No description provided for @maxMinutes.
  ///
  /// In en, this message translates to:
  /// **'Max {minutes}m'**
  String maxMinutes(Object minutes);

  /// No description provided for @maxSessionMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Max session (min): '**
  String get maxSessionMinLabel;

  /// No description provided for @mcpConfiguredPerApp.
  ///
  /// In en, this message translates to:
  /// **'MCP servers are configured per-app on the app detail page.'**
  String get mcpConfiguredPerApp;

  /// No description provided for @mcpServers.
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get mcpServers;

  /// No description provided for @mcpServersActive.
  ///
  /// In en, this message translates to:
  /// **'MCP Servers ({count} active)'**
  String mcpServersActive(Object count);

  /// No description provided for @mcpServersDesc.
  ///
  /// In en, this message translates to:
  /// **'Tool servers available for all AI runs on this app'**
  String get mcpServersDesc;

  /// No description provided for @mediumCount.
  ///
  /// In en, this message translates to:
  /// **'{count} medium'**
  String mediumCount(Object count);

  /// No description provided for @moveBackToActive.
  ///
  /// In en, this message translates to:
  /// **'Move back to Active'**
  String get moveBackToActive;

  /// No description provided for @moveToCompletedFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to completed folder'**
  String get moveToCompletedFolder;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @needHelpSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Need help setting up?'**
  String get needHelpSettingUp;

  /// No description provided for @newApp.
  ///
  /// In en, this message translates to:
  /// **'New App'**
  String get newApp;

  /// No description provided for @newAutomation.
  ///
  /// In en, this message translates to:
  /// **'New Automation'**
  String get newAutomation;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New Item'**
  String get newItem;

  /// No description provided for @newPrompt.
  ///
  /// In en, this message translates to:
  /// **'New prompt'**
  String get newPrompt;

  /// No description provided for @newReportsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new report(s)'**
  String newReportsCount(Object count);

  /// No description provided for @nextRunIn.
  ///
  /// In en, this message translates to:
  /// **'Next run in'**
  String get nextRunIn;

  /// No description provided for @noApiKeyFound.
  ///
  /// In en, this message translates to:
  /// **'No API key found — restart the server to generate one'**
  String get noApiKeyFound;

  /// No description provided for @noAppsMatch.
  ///
  /// In en, this message translates to:
  /// **'No apps match'**
  String get noAppsMatch;

  /// No description provided for @noAppsYet.
  ///
  /// In en, this message translates to:
  /// **'No apps yet'**
  String get noAppsYet;

  /// No description provided for @noArtBibleYet.
  ///
  /// In en, this message translates to:
  /// **'No art bible yet. Tap Add to define the visual identity — palette, typography, prohibitions.'**
  String get noArtBibleYet;

  /// No description provided for @noAutomationsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No automations match filters'**
  String get noAutomationsMatchFilters;

  /// No description provided for @noAutomationsYet.
  ///
  /// In en, this message translates to:
  /// **'No automations yet'**
  String get noAutomationsYet;

  /// No description provided for @noBuildTargetsFor.
  ///
  /// In en, this message translates to:
  /// **'No build targets for {type} projects.'**
  String noBuildTargetsFor(Object type);

  /// No description provided for @noBuildsYet.
  ///
  /// In en, this message translates to:
  /// **'No builds yet'**
  String get noBuildsYet;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @noClaudeMdYet.
  ///
  /// In en, this message translates to:
  /// **'No CLAUDE.md yet. Tap Add to set project instructions for AI.'**
  String get noClaudeMdYet;

  /// No description provided for @noDesignDocYet.
  ///
  /// In en, this message translates to:
  /// **'No design document yet. Tap Add to describe your app vision.'**
  String get noDesignDocYet;

  /// No description provided for @noDirectivesYet.
  ///
  /// In en, this message translates to:
  /// **'No directives sent yet.'**
  String get noDirectivesYet;

  /// No description provided for @noFavoritePrompts.
  ///
  /// In en, this message translates to:
  /// **'No favorite prompts yet'**
  String get noFavoritePrompts;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @noLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No logs found'**
  String get noLogsFound;

  /// No description provided for @noNewReports.
  ///
  /// In en, this message translates to:
  /// **'No new reports'**
  String get noNewReports;

  /// No description provided for @noOpenReports.
  ///
  /// In en, this message translates to:
  /// **'No open reports'**
  String get noOpenReports;

  /// No description provided for @noOpenTasksToDependOn.
  ///
  /// In en, this message translates to:
  /// **'No open tasks to depend on'**
  String get noOpenTasksToDependOn;

  /// No description provided for @noPendingItems.
  ///
  /// In en, this message translates to:
  /// **'No pending items to work on'**
  String get noPendingItems;

  /// No description provided for @noPromptHistory.
  ///
  /// In en, this message translates to:
  /// **'No prompt history yet.\nGenerate ideas to build history.'**
  String get noPromptHistory;

  /// No description provided for @noReportsHere.
  ///
  /// In en, this message translates to:
  /// **'No reports here'**
  String get noReportsHere;

  /// No description provided for @noWorkerUrlDetected.
  ///
  /// In en, this message translates to:
  /// **'No Worker URL detected in settings.json.\nSet up a Cloudflare Worker to enable remote access.'**
  String get noWorkerUrlDetected;

  /// No description provided for @notAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailableShort;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @notInstalled.
  ///
  /// In en, this message translates to:
  /// **'not installed'**
  String get notInstalled;

  /// No description provided for @notPaired.
  ///
  /// In en, this message translates to:
  /// **'Not paired'**
  String get notPaired;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'(not set)'**
  String get notSet;

  /// No description provided for @notYetUploaded.
  ///
  /// In en, this message translates to:
  /// **'not yet uploaded'**
  String get notYetUploaded;

  /// No description provided for @onHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get onHold;

  /// No description provided for @oneShotRunEndsIn.
  ///
  /// In en, this message translates to:
  /// **'One-shot run ends in'**
  String get oneShotRunEndsIn;

  /// No description provided for @oneTimeRunTriggered.
  ///
  /// In en, this message translates to:
  /// **'{app} one-time run triggered'**
  String oneTimeRunTriggered(Object app);

  /// No description provided for @openCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String openCountLabel(Object count);

  /// No description provided for @openPdf.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get openPdf;

  /// No description provided for @openingPdf.
  ///
  /// In en, this message translates to:
  /// **'Opening PDF…'**
  String get openingPdf;

  /// No description provided for @orSeparator.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orSeparator;

  /// No description provided for @output.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get output;

  /// No description provided for @packageName.
  ///
  /// In en, this message translates to:
  /// **'Package Name'**
  String get packageName;

  /// No description provided for @paired.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get paired;

  /// No description provided for @pairedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Paired successfully!'**
  String get pairedSuccessfully;

  /// No description provided for @perfProfileTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Performance profile task created'**
  String get perfProfileTaskCreated;

  /// No description provided for @performanceProfile.
  ///
  /// In en, this message translates to:
  /// **'Performance Profile'**
  String get performanceProfile;

  /// No description provided for @performanceProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Frame drops, memory, load time'**
  String get performanceProfileSubtitle;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @postpone.
  ///
  /// In en, this message translates to:
  /// **'Postpone'**
  String get postpone;

  /// No description provided for @postponedCount.
  ///
  /// In en, this message translates to:
  /// **'Postponed ({count})'**
  String postponedCount(Object count);

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackAgainToExit;

  /// No description provided for @previousChat.
  ///
  /// In en, this message translates to:
  /// **'Previous Chat'**
  String get previousChat;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @processingTasks.
  ///
  /// In en, this message translates to:
  /// **'Processing {done} of {total} tasks...'**
  String processingTasks(Object done, Object total);

  /// No description provided for @projectPath.
  ///
  /// In en, this message translates to:
  /// **'Project Path'**
  String get projectPath;

  /// No description provided for @promptHistory.
  ///
  /// In en, this message translates to:
  /// **'Prompt History'**
  String get promptHistory;

  /// No description provided for @promptHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Prompt history'**
  String get promptHistoryTooltip;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @pullAndRebuild.
  ///
  /// In en, this message translates to:
  /// **'Pull & Rebuild'**
  String get pullAndRebuild;

  /// No description provided for @pullFailed.
  ///
  /// In en, this message translates to:
  /// **'Pull failed'**
  String get pullFailed;

  /// No description provided for @pullNow.
  ///
  /// In en, this message translates to:
  /// **'Pull now'**
  String get pullNow;

  /// No description provided for @pullOnly.
  ///
  /// In en, this message translates to:
  /// **'Pull Only'**
  String get pullOnly;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed: {error}'**
  String purchaseFailed(Object error);

  /// No description provided for @putOnHoldForLater.
  ///
  /// In en, this message translates to:
  /// **'Put on hold for later'**
  String get putOnHoldForLater;

  /// No description provided for @pythonSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Run scripts and manage the Python project via the server.'**
  String get pythonSectionDesc;

  /// No description provided for @quickIssue.
  ///
  /// In en, this message translates to:
  /// **'Quick Issue'**
  String get quickIssue;

  /// No description provided for @rePairWithQr.
  ///
  /// In en, this message translates to:
  /// **'Re-pair with QR Code'**
  String get rePairWithQr;

  /// No description provided for @rebuild.
  ///
  /// In en, this message translates to:
  /// **'Rebuild'**
  String get rebuild;

  /// No description provided for @rebuildBody.
  ///
  /// In en, this message translates to:
  /// **'Start a new build from scratch?'**
  String get rebuildBody;

  /// No description provided for @rebuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebuild?'**
  String get rebuildTitle;

  /// No description provided for @recentBuilds.
  ///
  /// In en, this message translates to:
  /// **'Recent Builds'**
  String get recentBuilds;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshFailedShowingCached.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed — showing last synced data. {message}'**
  String refreshFailedShowingCached(Object message);

  /// No description provided for @refreshedFromServer.
  ///
  /// In en, this message translates to:
  /// **'Refreshed from server'**
  String get refreshedFromServer;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @reportBugOrSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Report a Bug / Suggestion'**
  String get reportBugOrSuggestion;

  /// No description provided for @reportBugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what to fix or add'**
  String get reportBugSubtitle;

  /// No description provided for @reportConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to send this report with my device info (model, OS and app version) to the developer to help fix issues.'**
  String get reportConsent;

  /// No description provided for @reportHint.
  ///
  /// In en, this message translates to:
  /// **'What happened, or what would you like to see?'**
  String get reportHint;

  /// No description provided for @reportSentThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your report was sent.'**
  String get reportSentThanks;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetServer.
  ///
  /// In en, this message translates to:
  /// **'Reset Server'**
  String get resetServer;

  /// No description provided for @resetServerBody.
  ///
  /// In en, this message translates to:
  /// **'This will restart the backend server.'**
  String get resetServerBody;

  /// No description provided for @resetServerRunningNote.
  ///
  /// In en, this message translates to:
  /// **'{count} running automation(s) will be stopped first to prevent auto-restart.'**
  String resetServerRunningNote(Object count);

  /// No description provided for @resumeActiveDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Resume active development'**
  String get resumeActiveDevelopment;

  /// Retry button label, e.g. after a failed network call.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @retryUpload.
  ///
  /// In en, this message translates to:
  /// **'Retry Upload'**
  String get retryUpload;

  /// No description provided for @reuploadStarted.
  ///
  /// In en, this message translates to:
  /// **'Re-upload started'**
  String get reuploadStarted;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @runAgainBody.
  ///
  /// In en, this message translates to:
  /// **'A one-shot run is already in progress but the AI may have stopped early. Trigger another run?'**
  String get runAgainBody;

  /// No description provided for @runAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Run Again?'**
  String get runAgainTitle;

  /// No description provided for @runAnyway.
  ///
  /// In en, this message translates to:
  /// **'Run Anyway'**
  String get runAnyway;

  /// No description provided for @runCheck.
  ///
  /// In en, this message translates to:
  /// **'Run Check'**
  String get runCheck;

  /// No description provided for @runOnce.
  ///
  /// In en, this message translates to:
  /// **'Run Once'**
  String get runOnce;

  /// No description provided for @runOnceInProgress.
  ///
  /// In en, this message translates to:
  /// **'Run Once (in progress)'**
  String get runOnceInProgress;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// Generic Save button label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @saveEmptyGddBody.
  ///
  /// In en, this message translates to:
  /// **'This will erase the current design document.'**
  String get saveEmptyGddBody;

  /// No description provided for @saveEmptyGddTitle.
  ///
  /// In en, this message translates to:
  /// **'Save empty GDD?'**
  String get saveEmptyGddTitle;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @scanError.
  ///
  /// In en, this message translates to:
  /// **'Scan error: {error}'**
  String scanError(Object error);

  /// No description provided for @scanFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: server returned {status}'**
  String scanFailedStatus(Object status);

  /// No description provided for @scanForProjects.
  ///
  /// In en, this message translates to:
  /// **'Scan for projects'**
  String get scanForProjects;

  /// No description provided for @scanPairingQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Pairing QR Code'**
  String get scanPairingQrTitle;

  /// No description provided for @scanQrToPair.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code to Pair'**
  String get scanQrToPair;

  /// No description provided for @scanResult.
  ///
  /// In en, this message translates to:
  /// **'Scanned {found} folders: {imported} imported, {skipped} skipped'**
  String scanResult(Object found, Object imported, Object skipped);

  /// No description provided for @scanThisQr.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR from your phone'**
  String get scanThisQr;

  /// No description provided for @scanToInstall.
  ///
  /// In en, this message translates to:
  /// **'Scan to install on your phone'**
  String get scanToInstall;

  /// No description provided for @scopeCheck.
  ///
  /// In en, this message translates to:
  /// **'Scope Check'**
  String get scopeCheck;

  /// No description provided for @scopeCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cut list + realism pass'**
  String get scopeCheckSubtitle;

  /// No description provided for @scopeCheckTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Scope check task created'**
  String get scopeCheckTaskCreated;

  /// No description provided for @screenshotsOptional.
  ///
  /// In en, this message translates to:
  /// **'Screenshots (optional)'**
  String get screenshotsOptional;

  /// No description provided for @screenshotsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Screenshots are large — you may need to remove one.'**
  String get screenshotsTooLarge;

  /// No description provided for @searchAppsHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps...'**
  String get searchAppsHint;

  /// No description provided for @searchFilterChip.
  ///
  /// In en, this message translates to:
  /// **'Search: \"{query}\"'**
  String searchFilterChip(Object query);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @sectionAiAgents.
  ///
  /// In en, this message translates to:
  /// **'AI Agents'**
  String get sectionAiAgents;

  /// No description provided for @sectionGameEngines.
  ///
  /// In en, this message translates to:
  /// **'Game Engines'**
  String get sectionGameEngines;

  /// No description provided for @sectionPaths.
  ///
  /// In en, this message translates to:
  /// **'Paths'**
  String get sectionPaths;

  /// No description provided for @sectionServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get sectionServices;

  /// No description provided for @sectionSystemTools.
  ///
  /// In en, this message translates to:
  /// **'System Tools'**
  String get sectionSystemTools;

  /// No description provided for @selectAnApp.
  ///
  /// In en, this message translates to:
  /// **'Select an app'**
  String get selectAnApp;

  /// No description provided for @selectAnAppFirst.
  ///
  /// In en, this message translates to:
  /// **'Select an app first'**
  String get selectAnAppFirst;

  /// No description provided for @selectApp.
  ///
  /// In en, this message translates to:
  /// **'Select app'**
  String get selectApp;

  /// No description provided for @selectAppForContext.
  ///
  /// In en, this message translates to:
  /// **'Select an app for context, or ask general questions'**
  String get selectAppForContext;

  /// No description provided for @selectAppToViewItems.
  ///
  /// In en, this message translates to:
  /// **'Select an app to view items'**
  String get selectAppToViewItems;

  /// No description provided for @selectCategoriesOrPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select categories or type your own prompt.'**
  String get selectCategoriesOrPrompt;

  /// No description provided for @sendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get sendReport;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @serverConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get serverConfiguration;

  /// No description provided for @serverConnection.
  ///
  /// In en, this message translates to:
  /// **'Server Connection'**
  String get serverConnection;

  /// No description provided for @serverReturnedStatus.
  ///
  /// In en, this message translates to:
  /// **'Server returned status {status}'**
  String serverReturnedStatus(Object status);

  /// No description provided for @serverStarted.
  ///
  /// In en, this message translates to:
  /// **'Server started!'**
  String get serverStarted;

  /// No description provided for @serverStartedHealthFailed.
  ///
  /// In en, this message translates to:
  /// **'Server started but health check failed'**
  String get serverStartedHealthFailed;

  /// No description provided for @serverStopped.
  ///
  /// In en, this message translates to:
  /// **'Server stopped'**
  String get serverStopped;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get serverUnreachable;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @sessionEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Session ends in'**
  String get sessionEndsIn;

  /// No description provided for @sessionRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Session refreshed — recent context preserved'**
  String get sessionRefreshed;

  /// Settings tab / screen label.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsJsonNotFound.
  ///
  /// In en, this message translates to:
  /// **'settings.json not found'**
  String get settingsJsonNotFound;

  /// No description provided for @settingsJsonRestartNote.
  ///
  /// In en, this message translates to:
  /// **'settings.json — restart server after changes'**
  String get settingsJsonRestartNote;

  /// No description provided for @settingsSavedRestart.
  ///
  /// In en, this message translates to:
  /// **'Settings saved — restart server to apply'**
  String get settingsSavedRestart;

  /// No description provided for @setupInstructions.
  ///
  /// In en, this message translates to:
  /// **'Setup Instructions'**
  String get setupInstructions;

  /// No description provided for @setupServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Set up the server on your PC first'**
  String get setupServerFirst;

  /// No description provided for @setupStepCloneRepo.
  ///
  /// In en, this message translates to:
  /// **'Clone the repository:'**
  String get setupStepCloneRepo;

  /// No description provided for @setupStepEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter the URL shown in the terminal (e.g. http://192.168.1.100:8000):'**
  String get setupStepEnterUrl;

  /// No description provided for @setupStepInstallDeps.
  ///
  /// In en, this message translates to:
  /// **'Install dependencies:'**
  String get setupStepInstallDeps;

  /// No description provided for @setupStepInstallPython.
  ///
  /// In en, this message translates to:
  /// **'Install Python 3.10+ on your PC'**
  String get setupStepInstallPython;

  /// No description provided for @setupStepRunWizard.
  ///
  /// In en, this message translates to:
  /// **'Run the setup wizard:'**
  String get setupStepRunWizard;

  /// No description provided for @setupStepStartServer.
  ///
  /// In en, this message translates to:
  /// **'Start the server:'**
  String get setupStepStartServer;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @showAppIcons.
  ///
  /// In en, this message translates to:
  /// **'Show app icons'**
  String get showAppIcons;

  /// No description provided for @showAppIconsDesc.
  ///
  /// In en, this message translates to:
  /// **'Display real app icons on the dashboard instead of generic type icons'**
  String get showAppIconsDesc;

  /// No description provided for @showPairingQr.
  ///
  /// In en, this message translates to:
  /// **'Show Pairing QR Code'**
  String get showPairingQr;

  /// No description provided for @signInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled'**
  String get signInCancelled;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String signInFailed(Object error);

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @startBuildFromCardAbove.
  ///
  /// In en, this message translates to:
  /// **'Start a build from the card above'**
  String get startBuildFromCardAbove;

  /// No description provided for @startServer.
  ///
  /// In en, this message translates to:
  /// **'Start Server'**
  String get startServer;

  /// No description provided for @startServerNotFound.
  ///
  /// In en, this message translates to:
  /// **'start_server.py not found'**
  String get startServerNotFound;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @statusBuilt.
  ///
  /// In en, this message translates to:
  /// **'Built'**
  String get statusBuilt;

  /// No description provided for @statusBuiltLower.
  ///
  /// In en, this message translates to:
  /// **'Built'**
  String get statusBuiltLower;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusDivided.
  ///
  /// In en, this message translates to:
  /// **'Divided'**
  String get statusDivided;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusFailedLower.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailedLower;

  /// No description provided for @statusFilterChip.
  ///
  /// In en, this message translates to:
  /// **'Status: {value}'**
  String statusFilterChip(Object value);

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusPendingLower.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPendingLower;

  /// No description provided for @statusPostponed.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get statusPostponed;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopServer.
  ///
  /// In en, this message translates to:
  /// **'Stop Server'**
  String get stopServer;

  /// No description provided for @stoppedLabel.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stoppedLabel;

  /// No description provided for @stuckSuffix.
  ///
  /// In en, this message translates to:
  /// **'{time} STUCK'**
  String stuckSuffix(Object time);

  /// No description provided for @stuckTasksAutoFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} stuck task(s) auto-failed after 30min timeout'**
  String stuckTasksAutoFailed(Object count);

  /// No description provided for @studioReviews.
  ///
  /// In en, this message translates to:
  /// **'Studio Reviews'**
  String get studioReviews;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @suggestApiBackend.
  ///
  /// In en, this message translates to:
  /// **'API & Backend'**
  String get suggestApiBackend;

  /// No description provided for @suggestFeatureIntegration.
  ///
  /// In en, this message translates to:
  /// **'Feature Integration'**
  String get suggestFeatureIntegration;

  /// No description provided for @suggestFixFailures.
  ///
  /// In en, this message translates to:
  /// **'Fix Failures'**
  String get suggestFixFailures;

  /// No description provided for @suggestGddAligned.
  ///
  /// In en, this message translates to:
  /// **'GDD-Aligned'**
  String get suggestGddAligned;

  /// No description provided for @suggestImproveCodebase.
  ///
  /// In en, this message translates to:
  /// **'Improve Codebase'**
  String get suggestImproveCodebase;

  /// No description provided for @suggestNextMilestone.
  ///
  /// In en, this message translates to:
  /// **'Next Milestone'**
  String get suggestNextMilestone;

  /// No description provided for @suggestPerformanceBoost.
  ///
  /// In en, this message translates to:
  /// **'Performance Boost'**
  String get suggestPerformanceBoost;

  /// No description provided for @suggestRevenueIdeas.
  ///
  /// In en, this message translates to:
  /// **'Revenue Ideas'**
  String get suggestRevenueIdeas;

  /// No description provided for @suggestSecurityHardening.
  ///
  /// In en, this message translates to:
  /// **'Security Hardening'**
  String get suggestSecurityHardening;

  /// No description provided for @suggestTaskPrioritization.
  ///
  /// In en, this message translates to:
  /// **'Task Prioritization'**
  String get suggestTaskPrioritization;

  /// No description provided for @suggestTestingQa.
  ///
  /// In en, this message translates to:
  /// **'Testing & QA'**
  String get suggestTestingQa;

  /// No description provided for @suggestUserEngagement.
  ///
  /// In en, this message translates to:
  /// **'User Engagement'**
  String get suggestUserEngagement;

  /// No description provided for @suggestUxPolish.
  ///
  /// In en, this message translates to:
  /// **'UX Polish'**
  String get suggestUxPolish;

  /// No description provided for @suggestedForYou.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get suggestedForYou;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @supportDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Support Development'**
  String get supportDevelopment;

  /// No description provided for @supportDevelopmentDesc.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the app? Consider supporting development!'**
  String get supportDevelopmentDesc;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @syncedAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {time}'**
  String syncedAgo(Object time);

  /// No description provided for @tapPlusToCreateAutomation.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first automation'**
  String get tapPlusToCreateAutomation;

  /// No description provided for @tapPlusToStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Tap + to start a conversation'**
  String get tapPlusToStartConversation;

  /// No description provided for @tapToAddLongPressToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to add, long-press to edit'**
  String get tapToAddLongPressToEdit;

  /// No description provided for @tapToOpenLongPressToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to open, long-press to edit'**
  String get tapToOpenLongPressToEdit;

  /// No description provided for @tapToRedetectEngine.
  ///
  /// In en, this message translates to:
  /// **'Tap to re-detect the engine from disk'**
  String get tapToRedetectEngine;

  /// No description provided for @taskLabelWith.
  ///
  /// In en, this message translates to:
  /// **'Task: {task}'**
  String taskLabelWith(Object task);

  /// No description provided for @taskOverview.
  ///
  /// In en, this message translates to:
  /// **'Task Overview'**
  String get taskOverview;

  /// No description provided for @taskResetToPending.
  ///
  /// In en, this message translates to:
  /// **'Task reset to pending'**
  String get taskResetToPending;

  /// Tasks tab / list label.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @techDebtScan.
  ///
  /// In en, this message translates to:
  /// **'Tech Debt Scan'**
  String get techDebtScan;

  /// No description provided for @techDebtScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'God scripts, duplicates, TODOs'**
  String get techDebtScanSubtitle;

  /// No description provided for @techDebtTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Tech debt scan task created'**
  String get techDebtTaskCreated;

  /// No description provided for @tellUsMore.
  ///
  /// In en, this message translates to:
  /// **'Tell us more'**
  String get tellUsMore;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @testTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Test task created'**
  String get testTaskCreated;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get thinking;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(Object days);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(Object hours);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(Object minutes);

  /// No description provided for @timeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{months}mo ago'**
  String timeMonthsAgo(Object months);

  /// No description provided for @timeSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s ago'**
  String timeSecondsAgo(Object seconds);

  /// No description provided for @timeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks}w ago'**
  String timeWeeksAgo(Object weeks);

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleHint;

  /// No description provided for @titleIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleIsRequired;

  /// No description provided for @trackAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get trackAlpha;

  /// No description provided for @trackBeta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get trackBeta;

  /// No description provided for @trackInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get trackInternal;

  /// No description provided for @trackProd.
  ///
  /// In en, this message translates to:
  /// **'Prod'**
  String get trackProd;

  /// No description provided for @triggeredOfItems.
  ///
  /// In en, this message translates to:
  /// **'Triggered {done} of {total} items'**
  String triggeredOfItems(Object done, Object total);

  /// No description provided for @tryChangingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try changing the category or status filter'**
  String get tryChangingFilters;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @typeBug.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get typeBug;

  /// No description provided for @typeFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get typeFeature;

  /// No description provided for @typeFilterChip.
  ///
  /// In en, this message translates to:
  /// **'Type: {value}'**
  String typeFilterChip(Object value);

  /// No description provided for @typeFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get typeFix;

  /// No description provided for @typeIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get typeIdea;

  /// No description provided for @typeIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get typeIssue;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A new version is available on GitHub.\nPull the latest code and rebuild to update.'**
  String get updateAvailableBody;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'updated {time}'**
  String updatedAgo(Object time);

  /// No description provided for @updatedNamed.
  ///
  /// In en, this message translates to:
  /// **'{label} updated'**
  String updatedNamed(Object label);

  /// No description provided for @uploadToGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Upload to Google Play'**
  String get uploadToGooglePlay;

  /// No description provided for @urgentCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} urgent'**
  String urgentCountLabel(Object count);

  /// No description provided for @urgentLabel.
  ///
  /// In en, this message translates to:
  /// **'urgent'**
  String get urgentLabel;

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionWithNumber.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String versionWithNumber(Object version);

  /// No description provided for @viewFailedTasks.
  ///
  /// In en, this message translates to:
  /// **'View failed tasks'**
  String get viewFailedTasks;

  /// No description provided for @viewIssues.
  ///
  /// In en, this message translates to:
  /// **'View issues'**
  String get viewIssues;

  /// No description provided for @viewOnGitHub.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get viewOnGitHub;

  /// No description provided for @warningPublishesToAll.
  ///
  /// In en, this message translates to:
  /// **'Warning: This publishes to all users!'**
  String get warningPublishesToAll;

  /// No description provided for @webDeploy.
  ///
  /// In en, this message translates to:
  /// **'Web Deploy'**
  String get webDeploy;

  /// No description provided for @webDeploySectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Build and deploy the web app via the server.'**
  String get webDeploySectionDesc;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @whatIsThis.
  ///
  /// In en, this message translates to:
  /// **'What is this?'**
  String get whatIsThis;

  /// No description provided for @workOnAll.
  ///
  /// In en, this message translates to:
  /// **'Work on All'**
  String get workOnAll;

  /// No description provided for @workOnAllBlockedNote.
  ///
  /// In en, this message translates to:
  /// **'\n({count} blocked item(s) will be skipped.)'**
  String workOnAllBlockedNote(Object count);

  /// No description provided for @workOnAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Run AI on all {count} pending item(s)?\nThey will be processed sequentially.'**
  String workOnAllConfirm(Object count);

  /// No description provided for @workOnAllPending.
  ///
  /// In en, this message translates to:
  /// **'Work on All Pending'**
  String get workOnAllPending;

  /// No description provided for @workOnThis.
  ///
  /// In en, this message translates to:
  /// **'Work on This'**
  String get workOnThis;

  /// No description provided for @workOnThisConfirm.
  ///
  /// In en, this message translates to:
  /// **'Run {agent} AI on:\n\"{title}\"'**
  String workOnThisConfirm(Object agent, Object title);

  /// No description provided for @workerUrl.
  ///
  /// In en, this message translates to:
  /// **'Worker URL'**
  String get workerUrl;

  /// No description provided for @workerUrlAutoDetected.
  ///
  /// In en, this message translates to:
  /// **'Auto-detected from settings.json (read-only)'**
  String get workerUrlAutoDetected;

  /// No description provided for @workerUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Worker URL copied'**
  String get workerUrlCopied;

  /// No description provided for @workerUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Get this URL from the desktop app or your server admin'**
  String get workerUrlHelp;

  /// No description provided for @workerUrlSaved.
  ///
  /// In en, this message translates to:
  /// **'Worker URL saved'**
  String get workerUrlSaved;

  /// No description provided for @workerUrlSetHint.
  ///
  /// In en, this message translates to:
  /// **'Set cloudflare.worker_url in server/config/settings.json'**
  String get workerUrlSetHint;

  /// No description provided for @youreAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get youreAllSet;
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
    'ja',
    'pt',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
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
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

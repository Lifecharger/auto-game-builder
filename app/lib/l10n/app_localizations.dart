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

  /// No description provided for @shareUsageStats.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage statistics'**
  String get shareUsageStats;

  /// No description provided for @shareUsageStatsDesc.
  ///
  /// In en, this message translates to:
  /// **'Anonymous counts of sessions and which screens are opened. No project names, no task text, no paths.'**
  String get shareUsageStatsDesc;

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

  /// No description provided for @agentsMdTitle.
  ///
  /// In en, this message translates to:
  /// **'AGENTS.md - {app}'**
  String agentsMdTitle(Object app);

  /// No description provided for @noAgentsMdYet.
  ///
  /// In en, this message translates to:
  /// **'No AGENTS.md yet. Tap Add to set project instructions for AI.'**
  String get noAgentsMdYet;

  /// No description provided for @cannotSaveEmptyAgentsMd.
  ///
  /// In en, this message translates to:
  /// **'Cannot save empty AGENTS.md'**
  String get cannotSaveEmptyAgentsMd;

  /// No description provided for @agentsMdSaved.
  ///
  /// In en, this message translates to:
  /// **'AGENTS.md saved'**
  String get agentsMdSaved;

  /// No description provided for @reportEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'E-mail (optional)'**
  String get reportEmailLabel;

  /// No description provided for @reportEmailHint.
  ///
  /// In en, this message translates to:
  /// **'your e-mail, if you want a reply'**
  String get reportEmailHint;

  /// No description provided for @reportEmailNote.
  ///
  /// In en, this message translates to:
  /// **'Only used to answer this report. Leave it empty to stay anonymous.'**
  String get reportEmailNote;

  /// No description provided for @reportEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'This does not look like an e-mail address.'**
  String get reportEmailInvalid;

  /// No description provided for @reportReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reportReply;

  /// No description provided for @reportReplySubject.
  ///
  /// In en, this message translates to:
  /// **'About your {app} report'**
  String reportReplySubject(String app);

  /// No description provided for @navGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get navGenerate;

  /// No description provided for @navGallery.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get navGallery;

  /// No description provided for @navFlow.
  ///
  /// In en, this message translates to:
  /// **'Pipeline'**
  String get navFlow;

  /// No description provided for @navQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get navQueue;

  /// No description provided for @navDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get navDelivery;

  /// No description provided for @navBuckets.
  ///
  /// In en, this message translates to:
  /// **'Buckets'**
  String get navBuckets;

  /// No description provided for @assetModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Asset mode'**
  String get assetModeTooltip;

  /// No description provided for @deliveryModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delivery mode'**
  String get deliveryModeTooltip;

  /// No description provided for @videoPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'The video could not be played'**
  String get videoPlaybackFailed;

  /// No description provided for @apiKeyRefusedBanner.
  ///
  /// In en, this message translates to:
  /// **'API key refused - tap to fix it in Settings'**
  String get apiKeyRefusedBanner;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server - check your connection'**
  String get errOffline;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to answer - try again'**
  String get errTimeout;

  /// No description provided for @errGatewayTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server did not answer in time (gateway timeout {status})'**
  String errGatewayTimeout(int status);

  /// No description provided for @errGateway.
  ///
  /// In en, this message translates to:
  /// **'The server is unreachable behind its gateway (gateway error {status}) - check that it is running'**
  String errGateway(int status);

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'Server error ({status}) - try again later'**
  String errServer(int status);

  /// No description provided for @errUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorized ({status}) - check the API key in Settings'**
  String errUnauthorized(int status);

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found on the server ({status})'**
  String errNotFound(int status);

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests ({status}) - wait a moment and try again'**
  String errRateLimited(int status);

  /// No description provided for @errTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large for the server ({status})'**
  String errTooLarge(int status);

  /// No description provided for @errRejected.
  ///
  /// In en, this message translates to:
  /// **'The server refused the request ({status})'**
  String errRejected(int status);

  /// No description provided for @errBadResponse.
  ///
  /// In en, this message translates to:
  /// **'The server sent an answer the app could not read'**
  String get errBadResponse;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request failed - try again'**
  String get errUnknown;

  /// No description provided for @bucketsCounting.
  ///
  /// In en, this message translates to:
  /// **'Counting {bucket}...'**
  String bucketsCounting(String bucket);

  /// No description provided for @bucketsTakedownTitle.
  ///
  /// In en, this message translates to:
  /// **'Takedown (new + legacy)'**
  String get bucketsTakedownTitle;

  /// No description provided for @bucketsDeleteForeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get bucketsDeleteForeverTitle;

  /// No description provided for @bucketsDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} objects will be deleted. THIS CANNOT BE UNDONE.'**
  String bucketsDeleteWarning(int count);

  /// No description provided for @bucketsUnmappedNote.
  ///
  /// In en, this message translates to:
  /// **'{count} keys have no match in the legacy twin - they are deleted from this bucket only.'**
  String bucketsUnmappedNote(int count);

  /// No description provided for @bucketsTypeNameToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type the bucket name to confirm: {bucket}'**
  String bucketsTypeNameToConfirm(String bucket);

  /// No description provided for @bucketsTakedown.
  ///
  /// In en, this message translates to:
  /// **'Takedown'**
  String get bucketsTakedown;

  /// No description provided for @bucketsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} objects deleted'**
  String bucketsDeleted(int count);

  /// No description provided for @bucketsDeletedWithTwin.
  ///
  /// In en, this message translates to:
  /// **'{count} objects deleted, {twin} from the legacy twin'**
  String bucketsDeletedWithTwin(int count, int twin);

  /// No description provided for @bucketsCopySource.
  ///
  /// In en, this message translates to:
  /// **'Source: {path}'**
  String bucketsCopySource(String path);

  /// No description provided for @bucketsCopySourceTree.
  ///
  /// In en, this message translates to:
  /// **'Source tree: {path}'**
  String bucketsCopySourceTree(String path);

  /// No description provided for @bucketsWholeBucket.
  ///
  /// In en, this message translates to:
  /// **'(whole bucket)'**
  String get bucketsWholeBucket;

  /// No description provided for @bucketsCopyNote.
  ///
  /// In en, this message translates to:
  /// **'The copy runs inside the storage service - no bytes pass through the phone.'**
  String get bucketsCopyNote;

  /// No description provided for @bucketsTargetKey.
  ///
  /// In en, this message translates to:
  /// **'Target key'**
  String get bucketsTargetKey;

  /// No description provided for @bucketsTargetPrefix.
  ///
  /// In en, this message translates to:
  /// **'Target prefix'**
  String get bucketsTargetPrefix;

  /// No description provided for @bucketsCopyStarted.
  ///
  /// In en, this message translates to:
  /// **'Copy started ({op})'**
  String bucketsCopyStarted(String op);

  /// No description provided for @bucketsFixHeadersTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix headers'**
  String get bucketsFixHeadersTitle;

  /// No description provided for @bucketsFixHeadersBody.
  ///
  /// In en, this message translates to:
  /// **'The Cache-Control header of the objects under {path} is checked; an object that departs from the standard is rewritten in place (Content-Type is kept). No bytes are downloaded.\n\nPrefixes left mutable on purpose are skipped.'**
  String bucketsFixHeadersBody(String path);

  /// No description provided for @bucketsFixStarted.
  ///
  /// In en, this message translates to:
  /// **'Header repair started ({op})'**
  String bucketsFixStarted(String op);

  /// No description provided for @bucketsOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get bucketsOperations;

  /// No description provided for @bucketsNoOperations.
  ///
  /// In en, this message translates to:
  /// **'No operations yet'**
  String get bucketsNoOperations;

  /// No description provided for @bucketsOpStatus.
  ///
  /// In en, this message translates to:
  /// **'{status}  ·  ok {ok}  ·  failed {failed}'**
  String bucketsOpStatus(String status, int ok, int failed);

  /// No description provided for @bucketsTwinDiffRunning.
  ///
  /// In en, this message translates to:
  /// **'Computing the twin diff...'**
  String get bucketsTwinDiffRunning;

  /// No description provided for @bucketsLocalDiffRunning.
  ///
  /// In en, this message translates to:
  /// **'Computing the local diff...'**
  String get bucketsLocalDiffRunning;

  /// No description provided for @bucketsTwinDiffTitle.
  ///
  /// In en, this message translates to:
  /// **'{bucket} <-> {twin} (legacy twin)'**
  String bucketsTwinDiffTitle(String bucket, String twin);

  /// No description provided for @bucketsLocalDiffTitle.
  ///
  /// In en, this message translates to:
  /// **'Local pushed folder <-> {bucket}'**
  String bucketsLocalDiffTitle(String bucket);

  /// No description provided for @bucketsMissingInLegacy.
  ///
  /// In en, this message translates to:
  /// **'Missing in the legacy twin'**
  String get bucketsMissingInLegacy;

  /// No description provided for @bucketsMissingInBucket.
  ///
  /// In en, this message translates to:
  /// **'Missing in the bucket'**
  String get bucketsMissingInBucket;

  /// No description provided for @bucketsOnlyInLegacy.
  ///
  /// In en, this message translates to:
  /// **'Only in the legacy twin'**
  String get bucketsOnlyInLegacy;

  /// No description provided for @bucketsOnlyInBucket.
  ///
  /// In en, this message translates to:
  /// **'Only in the bucket'**
  String get bucketsOnlyInBucket;

  /// No description provided for @bucketsSizeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Size differs'**
  String get bucketsSizeMismatch;

  /// No description provided for @bucketsUnmapped.
  ///
  /// In en, this message translates to:
  /// **'Unmatched (no rule)'**
  String get bucketsUnmapped;

  /// No description provided for @bucketsDerived.
  ///
  /// In en, this message translates to:
  /// **'Generated in the bucket (thumbs)'**
  String get bucketsDerived;

  /// No description provided for @bucketsDiffCount.
  ///
  /// In en, this message translates to:
  /// **'{title}: {count}'**
  String bucketsDiffCount(String title, int count);

  /// No description provided for @bucketsFixFolderHeaders.
  ///
  /// In en, this message translates to:
  /// **'Fix this folder\'s headers'**
  String get bucketsFixFolderHeaders;

  /// No description provided for @bucketsDiffs.
  ///
  /// In en, this message translates to:
  /// **'Differences'**
  String get bucketsDiffs;

  /// No description provided for @bucketsTwinDiff.
  ///
  /// In en, this message translates to:
  /// **'Legacy twin diff'**
  String get bucketsTwinDiff;

  /// No description provided for @bucketsLocalDiff.
  ///
  /// In en, this message translates to:
  /// **'Local pushed folder diff'**
  String get bucketsLocalDiff;

  /// No description provided for @bucketsIntro.
  ///
  /// In en, this message translates to:
  /// **'A bucket is the store named after its content. Counts are computed on request (listing only, no bytes are downloaded).'**
  String get bucketsIntro;

  /// No description provided for @bucketsBadgeLegacy.
  ///
  /// In en, this message translates to:
  /// **'LEGACY'**
  String get bucketsBadgeLegacy;

  /// No description provided for @bucketsBadgePrivate.
  ///
  /// In en, this message translates to:
  /// **'private'**
  String get bucketsBadgePrivate;

  /// No description provided for @bucketsBadgeContent.
  ///
  /// In en, this message translates to:
  /// **'content'**
  String get bucketsBadgeContent;

  /// No description provided for @bucketsNotCounted.
  ///
  /// In en, this message translates to:
  /// **'not counted'**
  String get bucketsNotCounted;

  /// No description provided for @bucketsObjectCount.
  ///
  /// In en, this message translates to:
  /// **'{count} objects'**
  String bucketsObjectCount(int count);

  /// No description provided for @bucketsTwinLabel.
  ///
  /// In en, this message translates to:
  /// **'twin: {twin}'**
  String bucketsTwinLabel(String twin);

  /// No description provided for @bucketsCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get bucketsCount;

  /// No description provided for @bucketsEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get bucketsEmptyFolder;

  /// No description provided for @bucketsTruncated.
  ///
  /// In en, this message translates to:
  /// **'The list was cut short - open a narrower folder'**
  String get bucketsTruncated;

  /// No description provided for @bucketsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String bucketsSelectedCount(int count);

  /// No description provided for @bucketsClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get bucketsClearSelection;

  /// No description provided for @bucketsTakedownTooltip.
  ///
  /// In en, this message translates to:
  /// **'Takedown (also delete from the legacy twin)'**
  String get bucketsTakedownTooltip;

  /// No description provided for @bucketsSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get bucketsSize;

  /// No description provided for @bucketsContentType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bucketsContentType;

  /// No description provided for @bucketsModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get bucketsModified;

  /// No description provided for @bucketsNone.
  ///
  /// In en, this message translates to:
  /// **'(none)'**
  String get bucketsNone;

  /// No description provided for @bucketsMutableOnPurpose.
  ///
  /// In en, this message translates to:
  /// **'Mutable on purpose - no standard applies'**
  String get bucketsMutableOnPurpose;

  /// No description provided for @bucketsHeaderOk.
  ///
  /// In en, this message translates to:
  /// **'Meets the cache standard ({kind})'**
  String bucketsHeaderOk(String kind);

  /// No description provided for @bucketsHeaderExpected.
  ///
  /// In en, this message translates to:
  /// **'Standard: {expected}'**
  String bucketsHeaderExpected(String expected);

  /// No description provided for @bucketsLegacyTwin.
  ///
  /// In en, this message translates to:
  /// **'Legacy twin'**
  String get bucketsLegacyTwin;

  /// No description provided for @bucketsAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get bucketsAddressCopied;

  /// No description provided for @bucketsCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get bucketsCopyAddress;

  /// No description provided for @bucketsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get bucketsOpen;

  /// No description provided for @bucketsPrivateNoAddress.
  ///
  /// In en, this message translates to:
  /// **'This bucket is private - it has no public address'**
  String get bucketsPrivateNoAddress;

  /// No description provided for @kindCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get kindCard;

  /// No description provided for @kindCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get kindCharacter;

  /// No description provided for @assetCodeMode.
  ///
  /// In en, this message translates to:
  /// **'Code mode'**
  String get assetCodeMode;

  /// No description provided for @assetPickFinishedImage.
  ///
  /// In en, this message translates to:
  /// **'Select a finished image'**
  String get assetPickFinishedImage;

  /// No description provided for @assetGenerateVideo.
  ///
  /// In en, this message translates to:
  /// **'Generate video'**
  String get assetGenerateVideo;

  /// No description provided for @assetEnlarge.
  ///
  /// In en, this message translates to:
  /// **'Enlarge'**
  String get assetEnlarge;

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentValue(Object value);

  /// No description provided for @commonCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commonCategory;

  /// No description provided for @durSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durSeconds(Object seconds);

  /// No description provided for @durMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String durMinutesSeconds(Object minutes, Object seconds);

  /// No description provided for @durHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durHoursMinutes(Object hours, Object minutes);

  /// No description provided for @charKindFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get charKindFemale;

  /// No description provided for @charKindMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get charKindMale;

  /// No description provided for @charKindAnimal.
  ///
  /// In en, this message translates to:
  /// **'Animal'**
  String get charKindAnimal;

  /// No description provided for @charKindMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get charKindMachine;

  /// No description provided for @outfitCatSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get outfitCatSet;

  /// No description provided for @outfitCatTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get outfitCatTop;

  /// No description provided for @outfitCatBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get outfitCatBottom;

  /// No description provided for @outfitCatShoes.
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get outfitCatShoes;

  /// No description provided for @outfitCatSocks.
  ///
  /// In en, this message translates to:
  /// **'Socks'**
  String get outfitCatSocks;

  /// No description provided for @outfitCatHat.
  ///
  /// In en, this message translates to:
  /// **'Hat'**
  String get outfitCatHat;

  /// No description provided for @outfitCatHeadgear.
  ///
  /// In en, this message translates to:
  /// **'Headgear'**
  String get outfitCatHeadgear;

  /// No description provided for @outfitCatAccessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory'**
  String get outfitCatAccessory;

  /// No description provided for @outfitCatWeapon.
  ///
  /// In en, this message translates to:
  /// **'Weapon'**
  String get outfitCatWeapon;

  /// No description provided for @audioLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioLabel;

  /// No description provided for @audioDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get audioDownloading;

  /// No description provided for @audioOpen.
  ///
  /// In en, this message translates to:
  /// **'Open audio'**
  String get audioOpen;

  /// No description provided for @outfitExtractTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract outfit'**
  String get outfitExtractTitle;

  /// No description provided for @outfitExtractBody.
  ///
  /// In en, this message translates to:
  /// **'The person in the selected image is removed and the outfit is saved to the wardrobe as a ghost-mannequin product shot on a plain grey background. After that any character can wear it as a skin.'**
  String get outfitExtractBody;

  /// No description provided for @outfitExtractName.
  ///
  /// In en, this message translates to:
  /// **'Outfit name'**
  String get outfitExtractName;

  /// No description provided for @outfitExtractNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Red evening dress'**
  String get outfitExtractNameHint;

  /// No description provided for @outfitExtractNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get outfitExtractNote;

  /// No description provided for @outfitExtractNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. only the dress, not the shoes'**
  String get outfitExtractNoteHint;

  /// No description provided for @outfitExtractHelp.
  ///
  /// In en, this message translates to:
  /// **'Set: everything the person wears, in one shot. Weapon / accessory: only that item, without a mannequin.'**
  String get outfitExtractHelp;

  /// No description provided for @outfitExtractAction.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get outfitExtractAction;

  /// No description provided for @equipSlotTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} slot'**
  String equipSlotTitle(Object category);

  /// No description provided for @equipSlotMultiHint.
  ///
  /// In en, this message translates to:
  /// **'multiple choice - tap to put on / take off'**
  String get equipSlotMultiHint;

  /// No description provided for @equipSlotSingleHint.
  ///
  /// In en, this message translates to:
  /// **'single choice - tap to put on, tap again to take off'**
  String get equipSlotSingleHint;

  /// No description provided for @equipSlotEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get equipSlotEmpty;

  /// No description provided for @equipSlotNoOutfits.
  ///
  /// In en, this message translates to:
  /// **'No ready outfit in this category - use \"+ Generate outfit\" or \"Extract outfit\"'**
  String get equipSlotNoOutfits;

  /// No description provided for @equipBaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Base:'**
  String get equipBaseLabel;

  /// No description provided for @equipUndress.
  ///
  /// In en, this message translates to:
  /// **'Take all off'**
  String get equipUndress;

  /// No description provided for @equipPickSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a source image'**
  String get equipPickSourceTitle;

  /// No description provided for @equipPickSourceHint.
  ///
  /// In en, this message translates to:
  /// **'The latest finished generations (every mode). For incoming / staging / pushed images of the Jigsaw pipeline use the Pipeline > Jigsaw screen.'**
  String get equipPickSourceHint;

  /// No description provided for @equipNoFinishedImage.
  ///
  /// In en, this message translates to:
  /// **'No finished image'**
  String get equipNoFinishedImage;

  /// No description provided for @freeFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Free pipeline'**
  String get freeFlowTitle;

  /// No description provided for @freeFlowEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit - edit engine'**
  String get freeFlowEditTitle;

  /// No description provided for @freeFlowEditLabel.
  ///
  /// In en, this message translates to:
  /// **'What should change'**
  String get freeFlowEditLabel;

  /// No description provided for @freeFlowEditHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. change the dress to red, keep face and pose'**
  String get freeFlowEditHint;

  /// No description provided for @freeFlowEditQueued.
  ///
  /// In en, this message translates to:
  /// **'Edit added to the queue'**
  String get freeFlowEditQueued;

  /// No description provided for @freeFlowNoVideoTask.
  ///
  /// In en, this message translates to:
  /// **'Free mode has no video task'**
  String get freeFlowNoVideoTask;

  /// No description provided for @freeFlowVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate video - {task}'**
  String freeFlowVideoTitle(Object task);

  /// No description provided for @freeFlowMotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get freeFlowMotionLabel;

  /// No description provided for @freeFlowMotionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. she turns her head slowly toward the camera, hair moving in the breeze'**
  String get freeFlowMotionHint;

  /// No description provided for @freeFlowVideoQueued.
  ///
  /// In en, this message translates to:
  /// **'Video added to the queue - a play mark appears on this card when it is done'**
  String get freeFlowVideoQueued;

  /// No description provided for @freeFlowDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this generation?'**
  String get freeFlowDeleteConfirm;

  /// No description provided for @freeFlowDeleteWithVideosConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this generation and its videos?'**
  String get freeFlowDeleteWithVideosConfirm;

  /// No description provided for @freeFlowEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing generated in Free mode yet - start from the Generate tab'**
  String get freeFlowEmpty;

  /// No description provided for @queueKindGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get queueKindGeneration;

  /// No description provided for @queueKindTag.
  ///
  /// In en, this message translates to:
  /// **'Tagging'**
  String get queueKindTag;

  /// No description provided for @queueKindMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get queueKindMusic;

  /// No description provided for @queueKindJob.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get queueKindJob;

  /// No description provided for @queueCancelRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel the running job'**
  String get queueCancelRunningTitle;

  /// No description provided for @queueRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from the queue'**
  String get queueRemoveTitle;

  /// No description provided for @queueCancelIt.
  ///
  /// In en, this message translates to:
  /// **'Cancel it'**
  String get queueCancelIt;

  /// No description provided for @queueClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the queue'**
  String get queueClearTitle;

  /// No description provided for @queueClearBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel the waiting generation jobs? The running job continues.'**
  String get queueClearBody;

  /// No description provided for @queueCancelWaiting.
  ///
  /// In en, this message translates to:
  /// **'Cancel the waiting jobs'**
  String get queueCancelWaiting;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'The queue is empty'**
  String get queueEmpty;

  /// No description provided for @queueEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'You can add jobs from the Generate tab'**
  String get queueEmptyHint;

  /// No description provided for @queueNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get queueNow;

  /// No description provided for @queueWaitingCount.
  ///
  /// In en, this message translates to:
  /// **'Waiting ({count})'**
  String queueWaitingCount(Object count);

  /// No description provided for @queueGenerationJobsCount.
  ///
  /// In en, this message translates to:
  /// **'Generation jobs ({count})'**
  String queueGenerationJobsCount(Object count);

  /// No description provided for @queueOneQueue.
  ///
  /// In en, this message translates to:
  /// **'One queue - every job'**
  String get queueOneQueue;

  /// No description provided for @queueJobCount.
  ///
  /// In en, this message translates to:
  /// **'{count} job(s)'**
  String queueJobCount(Object count);

  /// No description provided for @queueMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get queueMoveUp;

  /// No description provided for @queueMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get queueMoveDown;

  /// No description provided for @queueUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get queueUp;

  /// No description provided for @queueDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get queueDown;

  /// No description provided for @queueElapsed.
  ///
  /// In en, this message translates to:
  /// **'elapsed {time}'**
  String queueElapsed(Object time);

  /// No description provided for @queueWaitingFor.
  ///
  /// In en, this message translates to:
  /// **'waiting {time}'**
  String queueWaitingFor(Object time);

  /// No description provided for @queueWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get queueWaiting;

  /// No description provided for @queueComfyReady.
  ///
  /// In en, this message translates to:
  /// **'ComfyUI ready'**
  String get queueComfyReady;

  /// No description provided for @queueComfyOff.
  ///
  /// In en, this message translates to:
  /// **'ComfyUI is off'**
  String get queueComfyOff;

  /// No description provided for @deliveryPoolNeverRan.
  ///
  /// In en, this message translates to:
  /// **'never ran'**
  String get deliveryPoolNeverRan;

  /// No description provided for @deliveryPoolDryRun.
  ///
  /// In en, this message translates to:
  /// **'{status} (dry run)'**
  String deliveryPoolDryRun(Object status);

  /// No description provided for @deliveryPoolSummary.
  ///
  /// In en, this message translates to:
  /// **'{status} · {total} images, {valid} valid, {tagged} tagged, {failed} failed'**
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  );

  /// No description provided for @reportErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please write a message first.'**
  String get reportErrEmpty;

  /// No description provided for @reportErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachments are too large. Remove one and try again.'**
  String get reportErrTooLarge;

  /// No description provided for @flowOpError.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {message}'**
  String flowOpError(Object message);

  /// No description provided for @flowOpCancelled.
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled'**
  String get flowOpCancelled;

  /// No description provided for @flowOpDone.
  ///
  /// In en, this message translates to:
  /// **'{ok} done'**
  String flowOpDone(Object ok);

  /// No description provided for @flowOpDoneWithFailed.
  ///
  /// In en, this message translates to:
  /// **'{ok} done, {failed} failed'**
  String flowOpDoneWithFailed(Object ok, Object failed);

  /// No description provided for @flowCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get flowCollection;

  /// No description provided for @flowAllParen.
  ///
  /// In en, this message translates to:
  /// **'(all)'**
  String get flowAllParen;

  /// No description provided for @flowAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get flowAll;

  /// No description provided for @flowSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get flowSelectAll;

  /// No description provided for @flowRetag.
  ///
  /// In en, this message translates to:
  /// **'Retag'**
  String get flowRetag;

  /// No description provided for @flowRetagShort.
  ///
  /// In en, this message translates to:
  /// **'Retag'**
  String get flowRetagShort;

  /// No description provided for @flowRetagStarted.
  ///
  /// In en, this message translates to:
  /// **'Tagging started'**
  String get flowRetagStarted;

  /// No description provided for @flowReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get flowReadOnly;

  /// No description provided for @flowPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get flowPush;

  /// No description provided for @flowPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get flowPreview;

  /// No description provided for @flowYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get flowYes;

  /// No description provided for @flowNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get flowNo;

  /// No description provided for @flowMissingUpper.
  ///
  /// In en, this message translates to:
  /// **'MISSING'**
  String get flowMissingUpper;

  /// No description provided for @flowBadgeNoTags.
  ///
  /// In en, this message translates to:
  /// **'no tags'**
  String get flowBadgeNoTags;

  /// No description provided for @flowTabPushed.
  ///
  /// In en, this message translates to:
  /// **'4 Pushed'**
  String get flowTabPushed;

  /// No description provided for @flowSelectAssetFirst.
  ///
  /// In en, this message translates to:
  /// **'Select an asset first'**
  String get flowSelectAssetFirst;

  /// No description provided for @flowAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get flowAccept;

  /// No description provided for @flowReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get flowReject;

  /// No description provided for @flowUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get flowUpload;

  /// No description provided for @flowNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get flowNew;

  /// No description provided for @flowReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The pipeline could not be read'**
  String get flowReadFailed;

  /// No description provided for @flowFilesDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} files deleted'**
  String flowFilesDeleted(Object count);

  /// No description provided for @flowNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get flowNegative;

  /// No description provided for @flowPositive2.
  ///
  /// In en, this message translates to:
  /// **'Positive 2'**
  String get flowPositive2;

  /// No description provided for @flowDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get flowDuration;

  /// No description provided for @flowAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get flowAddToQueue;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @cbnFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'CBN pipeline'**
  String get cbnFlowTitle;

  /// No description provided for @cbnFlowTabIncoming.
  ///
  /// In en, this message translates to:
  /// **'2 Incoming'**
  String get cbnFlowTabIncoming;

  /// No description provided for @cbnFlowTabReady.
  ///
  /// In en, this message translates to:
  /// **'3 Ready'**
  String get cbnFlowTabReady;

  /// No description provided for @cbnFlowBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Build - {count} assets'**
  String cbnFlowBuildTitle(Object count);

  /// No description provided for @cbnFlowBuildBodyHot.
  ///
  /// In en, this message translates to:
  /// **'Regions + palette + numbered template + reveal video (CPU). The SAM step must already be done; outlines come from the SAM boundaries. (Hot: the build makes the line-art page itself with Qwen; step C is an optional preview.)'**
  String get cbnFlowBuildBodyHot;

  /// No description provided for @cbnFlowBuildBodyKid.
  ///
  /// In en, this message translates to:
  /// **'Regions + palette + numbered template + SVG (CPU). The SAM step must already be done.'**
  String get cbnFlowBuildBodyKid;

  /// No description provided for @cbnFlowBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get cbnFlowBuild;

  /// No description provided for @cbnFlowBuildStarted.
  ///
  /// In en, this message translates to:
  /// **'Build started - progress is shown at the top'**
  String get cbnFlowBuildStarted;

  /// No description provided for @cbnFlowStageStarted.
  ///
  /// In en, this message translates to:
  /// **'{stage} started ({count} assets)'**
  String cbnFlowStageStarted(Object stage, Object count);

  /// No description provided for @cbnFlowStageObjects.
  ///
  /// In en, this message translates to:
  /// **'Object list'**
  String get cbnFlowStageObjects;

  /// No description provided for @cbnFlowLineart.
  ///
  /// In en, this message translates to:
  /// **'Line art'**
  String get cbnFlowLineart;

  /// No description provided for @cbnFlowPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push - {count} assets'**
  String cbnFlowPushTitle(Object count);

  /// No description provided for @cbnFlowPushBody.
  ///
  /// In en, this message translates to:
  /// **'The asset folders will be uploaded to R2 and moved to \"Pushed\".\n\nThis is a PUBLISHING action and cannot be undone.'**
  String get cbnFlowPushBody;

  /// No description provided for @cbnFlowDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{count} assets will be deleted.'**
  String cbnFlowDeleteBody(Object count);

  /// No description provided for @cbnFlowDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} deleted'**
  String cbnFlowDeleted(Object count);

  /// No description provided for @cbnFlowEmptyIncoming.
  ///
  /// In en, this message translates to:
  /// **'No assets in this stage.\nSend them here with ACCEPT in CBN mode on the \"Generated\" screen.'**
  String get cbnFlowEmptyIncoming;

  /// No description provided for @cbnFlowEmptyStaging.
  ///
  /// In en, this message translates to:
  /// **'No built asset yet.\nSelect on the \"Incoming\" tab and tap BUILD.'**
  String get cbnFlowEmptyStaging;

  /// No description provided for @cbnFlowEmptyPushed.
  ///
  /// In en, this message translates to:
  /// **'No pushed asset.'**
  String get cbnFlowEmptyPushed;

  /// No description provided for @cbnFlowBadgeTagged.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get cbnFlowBadgeTagged;

  /// No description provided for @cbnFlowBadgeObjects.
  ///
  /// In en, this message translates to:
  /// **'O'**
  String get cbnFlowBadgeObjects;

  /// No description provided for @cbnFlowBadgeBuilt.
  ///
  /// In en, this message translates to:
  /// **'{regions}r {colors}c'**
  String cbnFlowBadgeBuilt(Object regions, Object colors);

  /// No description provided for @cbnFlowLayerNumbered.
  ///
  /// In en, this message translates to:
  /// **'Numbered'**
  String get cbnFlowLayerNumbered;

  /// No description provided for @cbnFlowLayerFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get cbnFlowLayerFinished;

  /// No description provided for @cbnFlowLayerSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get cbnFlowLayerSource;

  /// No description provided for @cbnFlowLayerObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get cbnFlowLayerObjects;

  /// No description provided for @cbnFlowInfo.
  ///
  /// In en, this message translates to:
  /// **'{label}   {regions} regions · {colors} colours · {verdict}'**
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  );

  /// No description provided for @cbnFlowTagLine.
  ///
  /// In en, this message translates to:
  /// **'{label}   tags: {state}'**
  String cbnFlowTagLine(Object label, Object state);

  /// No description provided for @cbnFlowFindObjects.
  ///
  /// In en, this message translates to:
  /// **'A) Find objects'**
  String get cbnFlowFindObjects;

  /// No description provided for @cbnFlowSamMasks.
  ///
  /// In en, this message translates to:
  /// **'B) SAM masks'**
  String get cbnFlowSamMasks;

  /// No description provided for @cbnFlowLineartPage.
  ///
  /// In en, this message translates to:
  /// **'C) Line-art page (optional, Qwen)'**
  String get cbnFlowLineartPage;

  /// No description provided for @cbnFlowBuildStep.
  ///
  /// In en, this message translates to:
  /// **'D) Build'**
  String get cbnFlowBuildStep;

  /// No description provided for @cbnFlowStepMissingA.
  ///
  /// In en, this message translates to:
  /// **'Step A (object list) has not been run'**
  String get cbnFlowStepMissingA;

  /// No description provided for @cbnFlowStepMissingB.
  ///
  /// In en, this message translates to:
  /// **'Step B (SAM masks) has not been run'**
  String get cbnFlowStepMissingB;

  /// No description provided for @cbnFlowStepMissingC.
  ///
  /// In en, this message translates to:
  /// **'Step C (line-art page) has not been run'**
  String get cbnFlowStepMissingC;

  /// No description provided for @cbnFlowImageFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be loaded'**
  String get cbnFlowImageFailed;

  /// No description provided for @jigsawFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Jigsaw pipeline'**
  String get jigsawFlowTitle;

  /// No description provided for @jigsawFlowTabTagged.
  ///
  /// In en, this message translates to:
  /// **'2 Tagged'**
  String get jigsawFlowTabTagged;

  /// No description provided for @jigsawFlowTabToPush.
  ///
  /// In en, this message translates to:
  /// **'3 To push'**
  String get jigsawFlowTabToPush;

  /// No description provided for @jigsawFlowQueueAll.
  ///
  /// In en, this message translates to:
  /// **'QUEUE ALL'**
  String get jigsawFlowQueueAll;

  /// No description provided for @jigsawFlowQueueAllTitle.
  ///
  /// In en, this message translates to:
  /// **'QUEUE ALL - {count} assets'**
  String jigsawFlowQueueAllTitle(Object count);

  /// No description provided for @jigsawFlowVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate video - {count} assets'**
  String jigsawFlowVideoTitle(Object count);

  /// No description provided for @jigsawFlowPositive1.
  ///
  /// In en, this message translates to:
  /// **'Positive 1 - subject'**
  String get jigsawFlowPositive1;

  /// No description provided for @jigsawFlowPositive1Help.
  ///
  /// In en, this message translates to:
  /// **'empty = each asset\'s own prompt'**
  String get jigsawFlowPositive1Help;

  /// No description provided for @jigsawFlowMotionPreset.
  ///
  /// In en, this message translates to:
  /// **'Motion preset'**
  String get jigsawFlowMotionPreset;

  /// No description provided for @jigsawFlowSpreadInTurn.
  ///
  /// In en, this message translates to:
  /// **'(spread in turn)'**
  String get jigsawFlowSpreadInTurn;

  /// No description provided for @jigsawFlowPositive2.
  ///
  /// In en, this message translates to:
  /// **'Positive 2 - motion'**
  String get jigsawFlowPositive2;

  /// No description provided for @jigsawFlowPositive2Help.
  ///
  /// In en, this message translates to:
  /// **'{marker} = where the subject prompt goes. Empty = the presets in turn.'**
  String jigsawFlowPositive2Help(Object marker);

  /// No description provided for @jigsawFlowPresetsSpread.
  ///
  /// In en, this message translates to:
  /// **'The {count} presets will be spread in turn.'**
  String jigsawFlowPresetsSpread(Object count);

  /// No description provided for @jigsawFlowNoAssetWithoutVideo.
  ///
  /// In en, this message translates to:
  /// **'No asset without a video'**
  String get jigsawFlowNoAssetWithoutVideo;

  /// No description provided for @jigsawFlowSelectWithoutVideo.
  ///
  /// In en, this message translates to:
  /// **'Select assets without a video'**
  String get jigsawFlowSelectWithoutVideo;

  /// No description provided for @jigsawFlowVideosQueued.
  ///
  /// In en, this message translates to:
  /// **'{queued} videos added to the queue - they land here when done'**
  String jigsawFlowVideosQueued(Object queued);

  /// No description provided for @jigsawFlowVideosQueuedSkipped.
  ///
  /// In en, this message translates to:
  /// **'{queued} videos added to the queue, {skipped} skipped - they land here when done'**
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped);

  /// No description provided for @jigsawFlowNoVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'No video'**
  String get jigsawFlowNoVideoTitle;

  /// No description provided for @jigsawFlowNoVideoBody.
  ///
  /// In en, this message translates to:
  /// **'{count} assets have no video - only the jpg will be written. Continue?'**
  String jigsawFlowNoVideoBody(Object count);

  /// No description provided for @jigsawFlowMusicNotReady.
  ///
  /// In en, this message translates to:
  /// **'The music model is not ready'**
  String get jigsawFlowMusicNotReady;

  /// No description provided for @jigsawFlowNoMusicMissing.
  ///
  /// In en, this message translates to:
  /// **'No themed collection is missing music'**
  String get jigsawFlowNoMusicMissing;

  /// No description provided for @jigsawFlowHasMusic.
  ///
  /// In en, this message translates to:
  /// **'{collection} already has music or is Generic'**
  String jigsawFlowHasMusic(Object collection);

  /// No description provided for @jigsawFlowMusicBody.
  ///
  /// In en, this message translates to:
  /// **'A 30-second instrumental track will be generated for {count} collections (ACE-Step, local).\n\n{names}\n\nEach one can take a few minutes.'**
  String jigsawFlowMusicBody(Object count, Object names);

  /// No description provided for @jigsawFlowPushBody.
  ///
  /// In en, this message translates to:
  /// **'{count} assets will be UPLOADED to the R2 bucket.\n\nThis is a publishing action that cannot be undone - the uploaded files become visible in the app.'**
  String jigsawFlowPushBody(Object count);

  /// No description provided for @jigsawFlowDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {count} assets (jpg + mp4 + webp + json)?'**
  String jigsawFlowDeleteBody(Object count);

  /// No description provided for @jigsawFlowWebpStarted.
  ///
  /// In en, this message translates to:
  /// **'Generating the missing webp files'**
  String get jigsawFlowWebpStarted;

  /// No description provided for @jigsawFlowCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'{mode} collection'**
  String jigsawFlowCollectionTitle(Object mode);

  /// No description provided for @jigsawFlowCollectionHelp.
  ///
  /// In en, this message translates to:
  /// **'pick from the list or type a NEW name'**
  String get jigsawFlowCollectionHelp;

  /// No description provided for @jigsawFlowCollectionHelpFull.
  ///
  /// In en, this message translates to:
  /// **'pick from the list or type a NEW name  -  {count} full collections are hidden'**
  String jigsawFlowCollectionHelpFull(Object count);

  /// No description provided for @jigsawFlowCollectionRow.
  ///
  /// In en, this message translates to:
  /// **'{total} assets - next is {next}'**
  String jigsawFlowCollectionRow(Object total, Object next);

  /// No description provided for @jigsawFlowEmptyIncoming.
  ///
  /// In en, this message translates to:
  /// **'No assets in this stage.\nSend them here with ACCEPT on the \"Generated\" screen.'**
  String get jigsawFlowEmptyIncoming;

  /// No description provided for @jigsawFlowEmpty.
  ///
  /// In en, this message translates to:
  /// **'No assets in this stage.'**
  String get jigsawFlowEmpty;

  /// No description provided for @jigsawFlowBadgeNoWebp.
  ///
  /// In en, this message translates to:
  /// **'no webp'**
  String get jigsawFlowBadgeNoWebp;

  /// No description provided for @jigsawFlowPreviewInfo.
  ///
  /// In en, this message translates to:
  /// **'{label}\nvideo: {video}   webp: {webp}'**
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp);

  /// No description provided for @jigsawFlowPreviewTags.
  ///
  /// In en, this message translates to:
  /// **'tags: {state}'**
  String jigsawFlowPreviewTags(Object state);

  /// No description provided for @jigsawFlowNoVideoInSelection.
  ///
  /// In en, this message translates to:
  /// **'None of the selected assets has a video'**
  String get jigsawFlowNoVideoInSelection;

  /// No description provided for @jigsawFlowDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete video'**
  String get jigsawFlowDeleteVideo;

  /// No description provided for @jigsawFlowDeleteVideoBody.
  ///
  /// In en, this message translates to:
  /// **'The mp4 + webp of {count} assets will be deleted; the image stays and you can generate a new video.'**
  String jigsawFlowDeleteVideoBody(Object count);

  /// No description provided for @jigsawFlowDeleteVideoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete video (the image stays)'**
  String get jigsawFlowDeleteVideoTooltip;

  /// No description provided for @jigsawFlowExtractNeedsOne.
  ///
  /// In en, this message translates to:
  /// **'An outfit is extracted from a single image - select one'**
  String get jigsawFlowExtractNeedsOne;

  /// No description provided for @outfitExtractStarted.
  ///
  /// In en, this message translates to:
  /// **'{name} is being extracted to the wardrobe - Character > Wardrobe'**
  String outfitExtractStarted(Object name);

  /// No description provided for @jigsawFlowMetaFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get jigsawFlowMetaFile;

  /// No description provided for @jigsawFlowMetaTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get jigsawFlowMetaTags;

  /// No description provided for @jigsawFlowMetaSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get jigsawFlowMetaSubject;

  /// No description provided for @jigsawFlowMetaPolicy.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get jigsawFlowMetaPolicy;

  /// No description provided for @jigsawFlowMetaVideoValue.
  ///
  /// In en, this message translates to:
  /// **'{video}   webp: {webp}'**
  String jigsawFlowMetaVideoValue(Object video, Object webp);

  /// No description provided for @jigsawFlowTagsMetadata.
  ///
  /// In en, this message translates to:
  /// **'Tags / metadata'**
  String get jigsawFlowTagsMetadata;

  /// No description provided for @jigsawFlowMissingWebp.
  ///
  /// In en, this message translates to:
  /// **'Missing webp'**
  String get jigsawFlowMissingWebp;

  /// No description provided for @deliverySavedLive.
  ///
  /// In en, this message translates to:
  /// **'Saved and LIVE ({time}) - refreshing the counts'**
  String deliverySavedLive(Object time);

  /// No description provided for @deliveryReindexTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-read metadata'**
  String get deliveryReindexTitle;

  /// No description provided for @deliveryReindexBody.
  ///
  /// In en, this message translates to:
  /// **'For images whose EXIF changed in the bucket. Type the file names separated by commas (e.g. 12.jpg, 340.jpg); leave it empty to re-read ALL of Generic (~1500 files, a few minutes).'**
  String get deliveryReindexBody;

  /// No description provided for @deliveryReindexNames.
  ///
  /// In en, this message translates to:
  /// **'File names'**
  String get deliveryReindexNames;

  /// No description provided for @deliveryReindexAction.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get deliveryReindexAction;

  /// No description provided for @deliveryReindexed.
  ///
  /// In en, this message translates to:
  /// **'{count} images re-read - manifests refreshed'**
  String deliveryReindexed(Object count);

  /// No description provided for @deliveryReindexedMissing.
  ///
  /// In en, this message translates to:
  /// **'{count} images re-read, {missing} not found - manifests refreshed'**
  String deliveryReindexedMissing(Object count, Object missing);

  /// No description provided for @deliveryDryRunStarted.
  ///
  /// In en, this message translates to:
  /// **'Dry run started - it only produces a report'**
  String get deliveryDryRunStarted;

  /// No description provided for @deliveryNormalizeStarted.
  ///
  /// In en, this message translates to:
  /// **'Normalisation started'**
  String get deliveryNormalizeStarted;

  /// No description provided for @deliveryCancelRequested.
  ///
  /// In en, this message translates to:
  /// **'Cancel requested'**
  String get deliveryCancelRequested;

  /// No description provided for @deliveryNeverSaved.
  ///
  /// In en, this message translates to:
  /// **'never saved'**
  String get deliveryNeverSaved;

  /// No description provided for @deliveryPoolJigsaw.
  ///
  /// In en, this message translates to:
  /// **'Jigsaw pool'**
  String get deliveryPoolJigsaw;

  /// No description provided for @deliveryPoolCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get deliveryPoolCards;

  /// No description provided for @deliveryPoolEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get deliveryPoolEvents;

  /// No description provided for @deliveryEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get deliveryEvent;

  /// No description provided for @deliverySummaryLine.
  ///
  /// In en, this message translates to:
  /// **'{pool} pool: {total} images, {tagged} tagged, {untagged} untagged'**
  String deliverySummaryLine(
    Object pool,
    Object total,
    Object tagged,
    Object untagged,
  );

  /// No description provided for @deliverySaveBeforeSwitch.
  ///
  /// In en, this message translates to:
  /// **'Save your changes before switching pools.'**
  String get deliverySaveBeforeSwitch;

  /// No description provided for @deliveryReindexTooltip.
  ///
  /// In en, this message translates to:
  /// **'Re-read metadata (if the EXIF changed)'**
  String get deliveryReindexTooltip;

  /// No description provided for @deliveryLastRule.
  ///
  /// In en, this message translates to:
  /// **'Last rule: {time}  ·  served by default: {served} / {total}'**
  String deliveryLastRule(Object time, Object served, Object total);

  /// No description provided for @deliveryIntro.
  ///
  /// In en, this message translates to:
  /// **'Switch OFF = images with that value leave the manifest. Saving goes live at once and now filters EVERY collection / deck; a single item the rules miss is closed with the Block list.'**
  String get deliveryIntro;

  /// No description provided for @deliveryNormalizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Normalise - generate the missing tags'**
  String get deliveryNormalizeTitle;

  /// No description provided for @deliveryDryRun.
  ///
  /// In en, this message translates to:
  /// **'Dry run'**
  String get deliveryDryRun;

  /// No description provided for @deliveryNormalizeNoStatus.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable - the server did not answer /api/normalize/status'**
  String get deliveryNormalizeNoStatus;

  /// No description provided for @deliveryIndex.
  ///
  /// In en, this message translates to:
  /// **'Index: {index}'**
  String deliveryIndex(Object index);

  /// No description provided for @deliveryLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run: {summary}'**
  String deliveryLastRun(Object summary);

  /// No description provided for @deliveryBlockScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'every app (global)'**
  String get deliveryBlockScopeGlobal;

  /// No description provided for @deliveryBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block · {scope}'**
  String deliveryBlockTitle(Object scope);

  /// No description provided for @deliveryOpenList.
  ///
  /// In en, this message translates to:
  /// **'Open the list'**
  String get deliveryOpenList;

  /// No description provided for @deliveryBlockIntro.
  ///
  /// In en, this message translates to:
  /// **'A global block applies in EVERY app; select an app to block for that app only. Applied AFTER the rules.'**
  String get deliveryBlockIntro;

  /// No description provided for @deliveryBlockEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to block in this pool (the bucket is empty).'**
  String get deliveryBlockEmpty;

  /// No description provided for @deliveryGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {tagged}/{count} tagged'**
  String deliveryGroupSubtitle(Object count, Object tagged);

  /// No description provided for @deliveryGroupSubtitleBlocked.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {tagged}/{count} tagged · ALL BLOCKED'**
  String deliveryGroupSubtitleBlocked(Object count, Object tagged);

  /// No description provided for @deliveryAppsHint.
  ///
  /// In en, this message translates to:
  /// **'Apps - tap to edit that app\'s rule'**
  String get deliveryAppsHint;

  /// No description provided for @deliveryDefaultChip.
  ///
  /// In en, this message translates to:
  /// **'Default  {served}/{total}'**
  String deliveryDefaultChip(Object served, Object total);

  /// No description provided for @deliveryDefaultRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Default rule - old versions that do not send ?app= and apps without a rule of their own'**
  String get deliveryDefaultRuleTitle;

  /// No description provided for @deliveryCustomRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom rule for {app}'**
  String deliveryCustomRuleTitle(Object app);

  /// No description provided for @deliveryCustomRuleOn.
  ///
  /// In en, this message translates to:
  /// **'Switch it off to return to the default'**
  String get deliveryCustomRuleOn;

  /// No description provided for @deliveryCustomRuleOff.
  ///
  /// In en, this message translates to:
  /// **'Off: the default rule applies. Switching it on starts from a copy of the default.'**
  String get deliveryCustomRuleOff;

  /// No description provided for @deliveryScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Only the selected collections'**
  String get deliveryScopeTitle;

  /// No description provided for @deliveryScopeOn.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} collections - newly published ones do NOT reach this app'**
  String deliveryScopeOn(Object selected, Object total);

  /// No description provided for @deliveryScopeOff.
  ///
  /// In en, this message translates to:
  /// **'Off: every newly published collection also reaches this app'**
  String get deliveryScopeOff;

  /// No description provided for @deliveryScopeNone.
  ///
  /// In en, this message translates to:
  /// **'None selected - an empty list is not saved, the rule falls back to \"all\".'**
  String get deliveryScopeNone;

  /// No description provided for @deliveryRulesEnabled.
  ///
  /// In en, this message translates to:
  /// **'Rules enabled'**
  String get deliveryRulesEnabled;

  /// No description provided for @deliveryRulesEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Off = this rule set filters nothing'**
  String get deliveryRulesEnabledHint;

  /// No description provided for @deliveryServeUntagged.
  ///
  /// In en, this message translates to:
  /// **'Serve untagged images'**
  String get deliveryServeUntagged;

  /// No description provided for @deliveryUntaggedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images have no metadata'**
  String deliveryUntaggedCount(Object count);

  /// No description provided for @deliveryQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick:'**
  String get deliveryQuick;

  /// No description provided for @deliveryOffCount.
  ///
  /// In en, this message translates to:
  /// **'{count} off'**
  String deliveryOffCount(Object count);

  /// No description provided for @deliveryFieldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{field} · {count} values'**
  String deliveryFieldSubtitle(Object field, Object count);

  /// No description provided for @deliveryUnsaved.
  ///
  /// In en, this message translates to:
  /// **'There are unsaved changes'**
  String get deliveryUnsaved;

  /// No description provided for @deliveryInSync.
  ///
  /// In en, this message translates to:
  /// **'Same as the server'**
  String get deliveryInSync;

  /// No description provided for @deliverySavePublish.
  ///
  /// In en, this message translates to:
  /// **'Save and publish'**
  String get deliverySavePublish;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get commonModel;

  /// No description provided for @cardTplShuffled.
  ///
  /// In en, this message translates to:
  /// **'Shuffled - locked axes were left alone'**
  String get cardTplShuffled;

  /// No description provided for @cardTplRankShuffled.
  ///
  /// In en, this message translates to:
  /// **'{rank} shuffled'**
  String cardTplRankShuffled(Object rank);

  /// No description provided for @cardTplAxisAllTitle.
  ///
  /// In en, this message translates to:
  /// **'{axis} - to all'**
  String cardTplAxisAllTitle(Object axis);

  /// No description provided for @cardTplAxisAllBack.
  ///
  /// In en, this message translates to:
  /// **'Written to the card back and LOCKED.'**
  String get cardTplAxisAllBack;

  /// No description provided for @cardTplAxisAllFront.
  ///
  /// In en, this message translates to:
  /// **'Written to all 13 cards + 2 jokers at once and LOCKED - shuffling does not change it.'**
  String get cardTplAxisAllFront;

  /// No description provided for @cardTplValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get cardTplValue;

  /// No description provided for @cardTplAllWritten.
  ///
  /// In en, this message translates to:
  /// **'Written to all and locked'**
  String get cardTplAllWritten;

  /// No description provided for @cardTplRankTitle.
  ///
  /// In en, this message translates to:
  /// **'{rank} template'**
  String cardTplRankTitle(Object rank);

  /// No description provided for @cardTplLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get cardTplLocked;

  /// No description provided for @cardTplLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get cardTplLock;

  /// No description provided for @cardTplManual.
  ///
  /// In en, this message translates to:
  /// **'Manual extra (free text)'**
  String get cardTplManual;

  /// No description provided for @cardTplManualHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. holding a golden card fan'**
  String get cardTplManualHint;

  /// No description provided for @cardTplManualHelp.
  ///
  /// In en, this message translates to:
  /// **'Added to the end of the template - shuffling does not remove it'**
  String get cardTplManualHelp;

  /// No description provided for @cardTplRankSaved.
  ///
  /// In en, this message translates to:
  /// **'{rank} saved'**
  String cardTplRankSaved(Object rank);

  /// No description provided for @cardTplSlotQueued.
  ///
  /// In en, this message translates to:
  /// **'{slot} added to the queue'**
  String cardTplSlotQueued(Object slot);

  /// No description provided for @cardTplTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection card - {title}'**
  String cardTplTitle(Object title);

  /// No description provided for @cardTplShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get cardTplShuffle;

  /// No description provided for @cardTplNoTheme.
  ///
  /// In en, this message translates to:
  /// **'No theme - tap to write one'**
  String get cardTplNoTheme;

  /// No description provided for @cardTplThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme (P1)'**
  String get cardTplThemeTitle;

  /// No description provided for @cardTplPresetCard.
  ///
  /// In en, this message translates to:
  /// **'Preset card'**
  String get cardTplPresetCard;

  /// No description provided for @cardTplTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get cardTplTheme;

  /// No description provided for @cardTplThemeHelp.
  ///
  /// In en, this message translates to:
  /// **'identity + STRICT PALETTE + Signature pieces'**
  String get cardTplThemeHelp;

  /// No description provided for @cardTplThemeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The theme cannot be empty'**
  String get cardTplThemeEmpty;

  /// No description provided for @cardTplThemeSaved.
  ///
  /// In en, this message translates to:
  /// **'Theme saved'**
  String get cardTplThemeSaved;

  /// No description provided for @cardTplModelSet.
  ///
  /// In en, this message translates to:
  /// **'Model: {name}'**
  String cardTplModelSet(Object name);

  /// No description provided for @cardTplFaceDetail.
  ///
  /// In en, this message translates to:
  /// **'Face retouch'**
  String get cardTplFaceDetail;

  /// No description provided for @cardTplFaceDetailHint.
  ///
  /// In en, this message translates to:
  /// **'+15 s per card - runs the face through a separate pass'**
  String get cardTplFaceDetailHint;

  /// No description provided for @cardTplFaceDetailOn.
  ///
  /// In en, this message translates to:
  /// **'Face retouch on'**
  String get cardTplFaceDetailOn;

  /// No description provided for @cardTplFaceDetailOff.
  ///
  /// In en, this message translates to:
  /// **'Face retouch off'**
  String get cardTplFaceDetailOff;

  /// No description provided for @cardTplVideoEngine.
  ///
  /// In en, this message translates to:
  /// **'Video engine (first frame = last frame)'**
  String get cardTplVideoEngine;

  /// No description provided for @cardTplEngineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{engine} (not installed)'**
  String cardTplEngineUnavailable(Object engine);

  /// No description provided for @cardTplVideoEngineSet.
  ///
  /// In en, this message translates to:
  /// **'Video engine: {name}'**
  String cardTplVideoEngineSet(Object name);

  /// No description provided for @cardTplApplyToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to all:'**
  String get cardTplApplyToAll;

  /// No description provided for @cardTplPickAxis.
  ///
  /// In en, this message translates to:
  /// **'pick an axis'**
  String get cardTplPickAxis;

  /// No description provided for @cardTplBackAxis.
  ///
  /// In en, this message translates to:
  /// **'{axis}  (back)'**
  String cardTplBackAxis(Object axis);

  /// No description provided for @cardTplLockedAxes.
  ///
  /// In en, this message translates to:
  /// **'{count} axes locked'**
  String cardTplLockedAxes(Object count);

  /// No description provided for @cardTplShuffleSlot.
  ///
  /// In en, this message translates to:
  /// **'Shuffle this slot'**
  String get cardTplShuffleSlot;

  /// No description provided for @cardTplGenerateSlot.
  ///
  /// In en, this message translates to:
  /// **'Generate this slot'**
  String get cardTplGenerateSlot;

  /// No description provided for @galleryDeleteSelectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} generations and their files?'**
  String galleryDeleteSelectedConfirm(Object count);

  /// No description provided for @galleryDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} generations deleted'**
  String galleryDeleted(Object count);

  /// No description provided for @galleryDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} could not be deleted'**
  String galleryDeleteFailed(Object count);

  /// No description provided for @galleryCharacterNeedsOne.
  ///
  /// In en, this message translates to:
  /// **'A character is created from a single image - select one'**
  String get galleryCharacterNeedsOne;

  /// No description provided for @galleryMakeCharacter.
  ///
  /// In en, this message translates to:
  /// **'Make character'**
  String get galleryMakeCharacter;

  /// No description provided for @galleryMakeCharacterBody.
  ///
  /// In en, this message translates to:
  /// **'The selected image becomes the base directly; the portrait, the story and the 7 directions are generated on their own - no confirmation is asked.'**
  String get galleryMakeCharacterBody;

  /// No description provided for @galleryCharacterQueued.
  ///
  /// In en, this message translates to:
  /// **'{name} added to the queue - follow the pipeline on the Queue tab'**
  String galleryCharacterQueued(Object name);

  /// No description provided for @galleryCreateCharacterFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a character with \"Make character\" first'**
  String get galleryCreateCharacterFirst;

  /// No description provided for @galleryAddToCandidatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to candidates - {count} images'**
  String galleryAddToCandidatesTitle(Object count);

  /// No description provided for @galleryAddedToCandidates.
  ///
  /// In en, this message translates to:
  /// **'{count} images added to the candidates of {name}'**
  String galleryAddedToCandidates(Object count, Object name);

  /// No description provided for @galleryCollectionNeedsOne.
  ///
  /// In en, this message translates to:
  /// **'A single image is added to a collection - select one'**
  String get galleryCollectionNeedsOne;

  /// No description provided for @galleryCreateCollectionFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a collection or a dealer in the Card pipeline first'**
  String get galleryCreateCollectionFirst;

  /// No description provided for @galleryAddToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get galleryAddToCollection;

  /// No description provided for @galleryDealerNoRank.
  ///
  /// In en, this message translates to:
  /// **'dealer (no rank)'**
  String get galleryDealerNoRank;

  /// No description provided for @galleryPickRank.
  ///
  /// In en, this message translates to:
  /// **'{name} - pick a rank'**
  String galleryPickRank(Object name);

  /// No description provided for @galleryQueuedOne.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue (1 job) - follow it on the Queue tab'**
  String get galleryQueuedOne;

  /// No description provided for @galleryAcceptBodyCbn.
  ///
  /// In en, this message translates to:
  /// **'{count} images will move to the \"Incoming\" stage of the CBN pipeline: jpg + EXIF tags. The build (SAM, line art, regions) is started there.\n\nWhich rating?'**
  String galleryAcceptBodyCbn(Object count);

  /// No description provided for @galleryAcceptBodyJigsaw.
  ///
  /// In en, this message translates to:
  /// **'{count} images will move to stage 2: jpg + EXIF tags, with the video next to it if there is one.\n\nWhich rating?'**
  String galleryAcceptBodyJigsaw(Object count);

  /// No description provided for @galleryAcceptStarted.
  ///
  /// In en, this message translates to:
  /// **'Started - follow the progress on the \"Pipeline\" tab'**
  String get galleryAcceptStarted;

  /// No description provided for @galleryExtractTooltip.
  ///
  /// In en, this message translates to:
  /// **'Extract outfit - take the outfit in the image into the wardrobe'**
  String get galleryExtractTooltip;

  /// No description provided for @galleryMakeCharacterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Make character - create a new character'**
  String get galleryMakeCharacterTooltip;

  /// No description provided for @galleryAddToCandidatesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to candidates - copy to an existing character'**
  String get galleryAddToCandidatesTooltip;

  /// No description provided for @galleryAddToCollectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to collection - pick a rank'**
  String get galleryAddToCollectionTooltip;

  /// No description provided for @galleryAcceptTooltip.
  ///
  /// In en, this message translates to:
  /// **'Accept - send to stage 2'**
  String get galleryAcceptTooltip;

  /// No description provided for @galleryDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected'**
  String get galleryDeleteSelected;

  /// No description provided for @galleryFilterImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get galleryFilterImage;

  /// No description provided for @galleryFilterVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get galleryFilterVideo;

  /// No description provided for @galleryFilterFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get galleryFilterFavorite;

  /// No description provided for @galleryQueuedAt.
  ///
  /// In en, this message translates to:
  /// **'queued {position}'**
  String galleryQueuedAt(Object position);

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing generated yet'**
  String get galleryEmpty;

  /// No description provided for @galleryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'You can start from the Generate tab'**
  String get galleryEmptyHint;

  /// No description provided for @galleryDeleteOneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this generation and its file?'**
  String get galleryDeleteOneConfirm;

  /// No description provided for @galleryAcceptOneCbn.
  ///
  /// In en, this message translates to:
  /// **'It will move to the \"Incoming\" stage of the CBN pipeline (jpg + EXIF tags).\n\nWhich rating?'**
  String get galleryAcceptOneCbn;

  /// No description provided for @galleryAcceptOneJigsaw.
  ///
  /// In en, this message translates to:
  /// **'It will move to stage 2 (jpg + EXIF tags).\n\nWhich rating?'**
  String get galleryAcceptOneJigsaw;

  /// No description provided for @galleryAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted - being tagged, follow it on the \"Pipeline\" tab'**
  String get galleryAccepted;

  /// No description provided for @galleryRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get galleryRejected;

  /// No description provided for @galleryEditBody.
  ///
  /// In en, this message translates to:
  /// **'This image becomes the source; the edit engine (Qwen Image Edit, keeps the identity) starts a new generation. What should change?'**
  String get galleryEditBody;

  /// No description provided for @galleryEditPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra prompt'**
  String get galleryEditPromptLabel;

  /// No description provided for @galleryEditPromptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. change the dress to a red pleated miniskirt, keep face and pose'**
  String get galleryEditPromptHint;

  /// No description provided for @galleryEditQueued.
  ///
  /// In en, this message translates to:
  /// **'Edit added to the queue - the result shows up in Generated'**
  String get galleryEditQueued;

  /// No description provided for @galleryEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit - a new generation with the edit engine'**
  String get galleryEditTooltip;

  /// No description provided for @galleryPoolInfo.
  ///
  /// In en, this message translates to:
  /// **'pool {name}'**
  String galleryPoolInfo(Object name);

  /// No description provided for @genPromptUnchanged.
  ///
  /// In en, this message translates to:
  /// **'The prompt did not change (the local LLM did not answer)'**
  String get genPromptUnchanged;

  /// No description provided for @genPromptWritten.
  ///
  /// In en, this message translates to:
  /// **'Prompt written'**
  String get genPromptWritten;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @genVariantFailed.
  ///
  /// In en, this message translates to:
  /// **'No variant could be produced (the local LLM did not answer)'**
  String get genVariantFailed;

  /// No description provided for @genPickVariant.
  ///
  /// In en, this message translates to:
  /// **'Pick a variant'**
  String get genPickVariant;

  /// No description provided for @genEnrich.
  ///
  /// In en, this message translates to:
  /// **'Enrich'**
  String get genEnrich;

  /// No description provided for @genFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get genFix;

  /// No description provided for @genVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get genVariant;

  /// No description provided for @genFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read'**
  String get genFileUnreadable;

  /// No description provided for @genPromptEmpty.
  ///
  /// In en, this message translates to:
  /// **'The prompt cannot be empty'**
  String get genPromptEmpty;

  /// No description provided for @genMissingInputs.
  ///
  /// In en, this message translates to:
  /// **'Missing input: {inputs}'**
  String genMissingInputs(Object inputs);

  /// No description provided for @genNeedsImagePick.
  ///
  /// In en, this message translates to:
  /// **'This task needs an input image - pick one of the generated ones'**
  String get genNeedsImagePick;

  /// No description provided for @genNeedsImage.
  ///
  /// In en, this message translates to:
  /// **'This task needs an input image'**
  String get genNeedsImage;

  /// No description provided for @genQueuedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} jobs added to the queue'**
  String genQueuedCount(Object count);

  /// No description provided for @genQueued.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue'**
  String get genQueued;

  /// No description provided for @genQueueBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} queued'**
  String genQueueBadge(Object count);

  /// No description provided for @genComfyOffBody.
  ///
  /// In en, this message translates to:
  /// **'ComfyUI is off. Jobs enter the queue but do not start - it has to be started on the computer.'**
  String get genComfyOffBody;

  /// No description provided for @genTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get genTask;

  /// No description provided for @genWorkflowInputs.
  ///
  /// In en, this message translates to:
  /// **'Workflow inputs'**
  String get genWorkflowInputs;

  /// No description provided for @genInputImage.
  ///
  /// In en, this message translates to:
  /// **'Input image'**
  String get genInputImage;

  /// No description provided for @genPositive1.
  ///
  /// In en, this message translates to:
  /// **'Positive prompt 1 - subject'**
  String get genPositive1;

  /// No description provided for @genPositive1Hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. police officer'**
  String get genPositive1Hint;

  /// No description provided for @genPositive2.
  ///
  /// In en, this message translates to:
  /// **'Positive prompt 2 - template'**
  String get genPositive2;

  /// No description provided for @genPositive2Help.
  ///
  /// In en, this message translates to:
  /// **'{marker} is replaced by the first prompt. May be left empty.'**
  String genPositive2Help(Object marker);

  /// No description provided for @genFinalPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt to be sent'**
  String get genFinalPrompt;

  /// No description provided for @genNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative prompt'**
  String get genNegative;

  /// No description provided for @genTurboHint.
  ///
  /// In en, this message translates to:
  /// **'fast mode'**
  String get genTurboHint;

  /// No description provided for @genDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'Duration: {seconds} seconds'**
  String genDurationSeconds(Object seconds);

  /// No description provided for @genCount.
  ///
  /// In en, this message translates to:
  /// **'Count: {count}'**
  String genCount(Object count);

  /// No description provided for @genSizeAspect.
  ///
  /// In en, this message translates to:
  /// **'Size: {width} x {height}  ({aspect})'**
  String genSizeAspect(Object width, Object height, Object aspect);

  /// No description provided for @genSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {width} x {height}'**
  String genSize(Object width, Object height);

  /// No description provided for @genAddToQueueUpper.
  ///
  /// In en, this message translates to:
  /// **'ADD TO QUEUE'**
  String get genAddToQueueUpper;

  /// No description provided for @genFootnote.
  ///
  /// In en, this message translates to:
  /// **'Jobs are generated one after another. You can follow them on the Queue tab.'**
  String get genFootnote;

  /// No description provided for @genDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details - may be left empty, locked ones are not shuffled'**
  String get genDetailsTitle;

  /// No description provided for @genRandomGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate random  {count}'**
  String genRandomGenerate(Object count);

  /// No description provided for @genLockedTooltip.
  ///
  /// In en, this message translates to:
  /// **'locked - stays fixed when shuffling'**
  String get genLockedTooltip;

  /// No description provided for @genOptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The option list is empty'**
  String get genOptionsEmpty;

  /// No description provided for @genOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get genOptional;

  /// No description provided for @genUploading.
  ///
  /// In en, this message translates to:
  /// **'uploading...'**
  String get genUploading;

  /// No description provided for @genNotSelected.
  ///
  /// In en, this message translates to:
  /// **'not selected'**
  String get genNotSelected;

  /// No description provided for @genFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get genFromGallery;

  /// No description provided for @genFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get genFromFile;

  /// No description provided for @genNoSource.
  ///
  /// In en, this message translates to:
  /// **'No generation can be used as input. Generate an image first.'**
  String get genNoSource;

  /// No description provided for @genPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'{slot} - pick from Generated'**
  String genPickerTitle(Object slot);

  /// No description provided for @genPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'search in prompts'**
  String get genPickerSearch;

  /// No description provided for @genPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No finished generation of this kind.'**
  String get genPickerEmpty;

  /// No description provided for @optionsFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing in the options file: {items}'**
  String optionsFileMissing(Object items);

  /// No description provided for @optionsFieldsMissing.
  ///
  /// In en, this message translates to:
  /// **'{label} (no field definitions)'**
  String optionsFieldsMissing(Object label);

  /// No description provided for @optionsFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The options file could not be read: {error}'**
  String optionsFileUnreadable(Object error);

  /// No description provided for @optionsFileUnreadableNamed.
  ///
  /// In en, this message translates to:
  /// **'The {name} options file could not be read: {error}'**
  String optionsFileUnreadableNamed(Object name, Object error);

  /// No description provided for @fieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldLocation;

  /// No description provided for @fieldEra.
  ///
  /// In en, this message translates to:
  /// **'Era / aesthetic'**
  String get fieldEra;

  /// No description provided for @fieldWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get fieldWeather;

  /// No description provided for @fieldWeatherLight.
  ///
  /// In en, this message translates to:
  /// **'Weather / light'**
  String get fieldWeatherLight;

  /// No description provided for @fieldJob.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get fieldJob;

  /// No description provided for @fieldFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get fieldFantasy;

  /// No description provided for @fieldOutfitColor.
  ///
  /// In en, this message translates to:
  /// **'Outfit colour'**
  String get fieldOutfitColor;

  /// No description provided for @fieldOutfit.
  ///
  /// In en, this message translates to:
  /// **'Outfit'**
  String get fieldOutfit;

  /// No description provided for @fieldHair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get fieldHair;

  /// No description provided for @fieldHairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair colour'**
  String get fieldHairColor;

  /// No description provided for @fieldHairstyle.
  ///
  /// In en, this message translates to:
  /// **'Hairstyle'**
  String get fieldHairstyle;

  /// No description provided for @fieldEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get fieldEyes;

  /// No description provided for @fieldRace.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get fieldRace;

  /// No description provided for @fieldExpression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get fieldExpression;

  /// No description provided for @fieldPose.
  ///
  /// In en, this message translates to:
  /// **'Pose'**
  String get fieldPose;

  /// No description provided for @fieldAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get fieldAngle;

  /// No description provided for @fieldStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get fieldStyle;

  /// No description provided for @fieldMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get fieldMood;

  /// No description provided for @fieldColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get fieldColor;

  /// No description provided for @fieldCreature.
  ///
  /// In en, this message translates to:
  /// **'Creature'**
  String get fieldCreature;

  /// No description provided for @fieldClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get fieldClass;

  /// No description provided for @fieldAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get fieldAge;

  /// No description provided for @fieldOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get fieldOrigin;

  /// No description provided for @fieldBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get fieldBody;

  /// No description provided for @fieldSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get fieldSkin;

  /// No description provided for @fieldFace.
  ///
  /// In en, this message translates to:
  /// **'Face'**
  String get fieldFace;

  /// No description provided for @fieldGesture.
  ///
  /// In en, this message translates to:
  /// **'Gesture'**
  String get fieldGesture;

  /// No description provided for @cardNotReady.
  ///
  /// In en, this message translates to:
  /// **'The server endpoint is not ready yet'**
  String get cardNotReady;

  /// No description provided for @cardKindNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get cardKindNormal;

  /// No description provided for @cardKindDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get cardKindDealer;

  /// No description provided for @cardStagePushed.
  ///
  /// In en, this message translates to:
  /// **'pushed'**
  String get cardStagePushed;

  /// No description provided for @cardStageWebp.
  ///
  /// In en, this message translates to:
  /// **'webp ready'**
  String get cardStageWebp;

  /// No description provided for @cardStageVideo.
  ///
  /// In en, this message translates to:
  /// **'video ready'**
  String get cardStageVideo;

  /// No description provided for @cardStageStill.
  ///
  /// In en, this message translates to:
  /// **'still ready'**
  String get cardStageStill;

  /// No description provided for @cardStageEmpty.
  ///
  /// In en, this message translates to:
  /// **'empty'**
  String get cardStageEmpty;

  /// No description provided for @cardRankTooltip.
  ///
  /// In en, this message translates to:
  /// **'{rank} - {stage}'**
  String cardRankTooltip(Object rank, Object stage);

  /// No description provided for @cardRankTooltipWarn.
  ///
  /// In en, this message translates to:
  /// **'{rank} - {stage} (check)'**
  String cardRankTooltipWarn(Object rank, Object stage);

  /// No description provided for @cardVideoIntro.
  ///
  /// In en, this message translates to:
  /// **'First frame = last frame (loop). The camera stays locked - framing, scale and background do not change. The output goes to the POOL first; if you pick a tag it is assigned there as well.'**
  String get cardVideoIntro;

  /// No description provided for @cardVideoTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template (fills the text)'**
  String get cardVideoTemplate;

  /// No description provided for @cardVideoMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion sentence (the prompt that is sent)'**
  String get cardVideoMotion;

  /// No description provided for @cardVideoMotionHelp.
  ///
  /// In en, this message translates to:
  /// **'Describe a visible motion; it should return to the starting pose at the end'**
  String get cardVideoMotionHelp;

  /// No description provided for @cardVideoAssignTag.
  ///
  /// In en, this message translates to:
  /// **'Assign to tag'**
  String get cardVideoAssignTag;

  /// No description provided for @cardVideoPoolOnly.
  ///
  /// In en, this message translates to:
  /// **'(pool only - I will assign it later)'**
  String get cardVideoPoolOnly;

  /// No description provided for @cardVideoNewTag.
  ///
  /// In en, this message translates to:
  /// **'New tag...'**
  String get cardVideoNewTag;

  /// No description provided for @cardVideoNewTagName.
  ///
  /// In en, this message translates to:
  /// **'New tag name'**
  String get cardVideoNewTagName;

  /// No description provided for @cardTagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. victory'**
  String get cardTagHint;

  /// No description provided for @cardGestureTitle.
  ///
  /// In en, this message translates to:
  /// **'Animation - pick a gesture'**
  String get cardGestureTitle;

  /// No description provided for @cardGestureIntro.
  ///
  /// In en, this message translates to:
  /// **'MiniMax H3: idle 6 s, victory 2 s. The camera stays locked - framing, scale and background do not change.'**
  String get cardGestureIntro;

  /// No description provided for @cardGestureCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom motion'**
  String get cardGestureCustom;

  /// No description provided for @cardGestureCustomHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. a slight hip sway, feet fixed'**
  String get cardGestureCustomHint;

  /// No description provided for @cardGestureCustomHelp.
  ///
  /// In en, this message translates to:
  /// **'A short motion sentence - the camera stays locked'**
  String get cardGestureCustomHelp;

  /// No description provided for @cardCutTitle.
  ///
  /// In en, this message translates to:
  /// **'3 WebP - cut mode'**
  String get cardCutTitle;

  /// No description provided for @cardCutHybrid.
  ///
  /// In en, this message translates to:
  /// **'Old green Grok masters - chroma + SAM together'**
  String get cardCutHybrid;

  /// No description provided for @cardCutSam.
  ///
  /// In en, this message translates to:
  /// **'Default - SAM3 only, plain light grey background'**
  String get cardCutSam;

  /// No description provided for @cardCutAction.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cardCutAction;

  /// No description provided for @cardEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit - {name}'**
  String cardEditTitle(Object name);

  /// No description provided for @cardEditSentence.
  ///
  /// In en, this message translates to:
  /// **'Correction sentence'**
  String get cardEditSentence;

  /// No description provided for @cardEditSentenceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. shorten her hair / remove the gloves'**
  String get cardEditSentenceHint;

  /// No description provided for @cardEditBody.
  ///
  /// In en, this message translates to:
  /// **'The accepted still is edited with this sentence; identity, pose and background are kept. The new image is accepted automatically.'**
  String get cardEditBody;

  /// No description provided for @cardEditUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted edit (NSFW LoRA)'**
  String get cardEditUnrestricted;

  /// No description provided for @cardEditUnrestrictedHint.
  ///
  /// In en, this message translates to:
  /// **'Switch on if Qwen refuses - MCNL LoRA, 20 steps, a little slower'**
  String get cardEditUnrestrictedHint;

  /// No description provided for @cardQueuedJobs.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue ({count} jobs) - follow it on the Queue tab'**
  String cardQueuedJobs(Object count);

  /// No description provided for @cardQueued.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue - follow it on the Queue tab'**
  String get cardQueued;

  /// No description provided for @cardQueuedOp.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue (op {op}) - follow it on the Queue tab'**
  String cardQueuedOp(Object op);

  /// No description provided for @cardSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'{what} - coming soon'**
  String cardSoonTitle(Object what);

  /// No description provided for @cardSoonBody.
  ///
  /// In en, this message translates to:
  /// **'The card endpoints on the server are not open yet. This screen starts working on its own once they are.'**
  String get cardSoonBody;

  /// No description provided for @cardNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get cardNewCollection;

  /// No description provided for @cardIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Identifier (id)'**
  String get cardIdLabel;

  /// No description provided for @cardIdHintCollection.
  ///
  /// In en, this message translates to:
  /// **'e.g. police_royale'**
  String get cardIdHintCollection;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @cardNameHintCollection.
  ///
  /// In en, this message translates to:
  /// **'e.g. Police Royale'**
  String get cardNameHintCollection;

  /// No description provided for @cardPickPreset.
  ///
  /// In en, this message translates to:
  /// **'Pick a preset card (optional)'**
  String get cardPickPreset;

  /// No description provided for @cardThemeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. sexy police costume with badge and duty belt'**
  String get cardThemeHint;

  /// No description provided for @cardThemeFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula: identity + STRICT PALETTE + Signature pieces'**
  String get cardThemeFormula;

  /// No description provided for @cardJokers.
  ///
  /// In en, this message translates to:
  /// **'Jokers (2)'**
  String get cardJokers;

  /// No description provided for @cardJokersHint.
  ///
  /// In en, this message translates to:
  /// **'15 ranks instead of 13'**
  String get cardJokersHint;

  /// No description provided for @cardNewCollectionNote.
  ///
  /// In en, this message translates to:
  /// **'One still per rank enters the queue (skin / hair / outfit / pose rotation). No confirmation is asked - fine-tune with ✎ / ↻.'**
  String get cardNewCollectionNote;

  /// No description provided for @cardIdNameRequired.
  ///
  /// In en, this message translates to:
  /// **'The identifier and the name cannot be empty'**
  String get cardIdNameRequired;

  /// No description provided for @cardNewDealer.
  ///
  /// In en, this message translates to:
  /// **'New dealer'**
  String get cardNewDealer;

  /// No description provided for @cardIdHintDealer.
  ///
  /// In en, this message translates to:
  /// **'e.g. scarlett'**
  String get cardIdHintDealer;

  /// No description provided for @cardNameHintDealer.
  ///
  /// In en, this message translates to:
  /// **'e.g. Scarlett'**
  String get cardNameHintDealer;

  /// No description provided for @cardDealerTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme / outfit'**
  String get cardDealerTheme;

  /// No description provided for @cardDealerThemeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. casino vest and bow tie, noir red dress'**
  String get cardDealerThemeHint;

  /// No description provided for @cardDealerNote.
  ///
  /// In en, this message translates to:
  /// **'The dealer is generated in a waist-up frame (hands on the table, looking at the camera). There is no rank - the single item goes through the four stages.'**
  String get cardDealerNote;

  /// No description provided for @cardNightPickGesture.
  ///
  /// In en, this message translates to:
  /// **'Night mode - pick a gesture'**
  String get cardNightPickGesture;

  /// No description provided for @cardNightMode.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get cardNightMode;

  /// No description provided for @cardNightBody.
  ///
  /// In en, this message translates to:
  /// **'All cards AND dealers are re-animated: current still -> LTX-2.5 i2v ({gesture}) -> SAM cut -> sheet.\n\nIt takes long and everything enters the queue. NO push is done.'**
  String cardNightBody(Object gesture);

  /// No description provided for @cardRestillTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn backgrounds grey'**
  String get cardRestillTitle;

  /// No description provided for @cardRestillBody.
  ///
  /// In en, this message translates to:
  /// **'The still background of all cards AND dealers is turned plain light grey (the woman stays as she is). The original is kept as still_green.png; ones that are already grey are skipped.\n\nNo video is generated.'**
  String get cardRestillBody;

  /// No description provided for @cardManifestPreview.
  ///
  /// In en, this message translates to:
  /// **'Manifest preview'**
  String get cardManifestPreview;

  /// No description provided for @cardManifestCounts.
  ///
  /// In en, this message translates to:
  /// **'{collections} collections, {dealers} dealers'**
  String cardManifestCounts(Object collections, Object dealers);

  /// No description provided for @cardManifestNote.
  ///
  /// In en, this message translates to:
  /// **'The manifest file is written during PUSH (files first, then the manifest). This is only a preview.'**
  String get cardManifestNote;

  /// No description provided for @cardCollectionCardSettings.
  ///
  /// In en, this message translates to:
  /// **'Collection card (settings)'**
  String get cardCollectionCardSettings;

  /// No description provided for @cardCollectionCardSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'theme, 16 slots, model, face retouch'**
  String get cardCollectionCardSettingsHint;

  /// No description provided for @cardReanimate.
  ///
  /// In en, this message translates to:
  /// **'Re-animate'**
  String get cardReanimate;

  /// No description provided for @cardReanimateHint.
  ///
  /// In en, this message translates to:
  /// **'still -> i2v -> cut (this collection)'**
  String get cardReanimateHint;

  /// No description provided for @cardRealify.
  ///
  /// In en, this message translates to:
  /// **'Anime -> realistic (collection)'**
  String get cardRealify;

  /// No description provided for @cardRealifyHint.
  ///
  /// In en, this message translates to:
  /// **'every still becomes a realistic photo with edit_qwen'**
  String get cardRealifyHint;

  /// No description provided for @cardDeleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get cardDeleteCollection;

  /// No description provided for @cardDeleteCollectionHint.
  ///
  /// In en, this message translates to:
  /// **'the folder is deleted with all its cards - cannot be undone'**
  String get cardDeleteCollectionHint;

  /// No description provided for @cardDeleteCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection - {name}'**
  String cardDeleteCollectionTitle(Object name);

  /// No description provided for @cardDeleteDealerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete dealer - {name}'**
  String cardDeleteDealerTitle(Object name);

  /// No description provided for @cardDeleteCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'The collection folder is deleted with all its files.\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.'**
  String get cardDeleteCollectionBody;

  /// No description provided for @cardDeleteDealerBody.
  ///
  /// In en, this message translates to:
  /// **'The dealer folder is deleted with all its files.\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.'**
  String get cardDeleteDealerBody;

  /// No description provided for @cardDeletedNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String cardDeletedNamed(Object name);

  /// No description provided for @cardDealerCardSettings.
  ///
  /// In en, this message translates to:
  /// **'Dealer card (settings)'**
  String get cardDealerCardSettings;

  /// No description provided for @cardDealerCardSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'theme, template, model, face retouch'**
  String get cardDealerCardSettingsHint;

  /// No description provided for @cardDeleteDealer.
  ///
  /// In en, this message translates to:
  /// **'Delete dealer'**
  String get cardDeleteDealer;

  /// No description provided for @cardDeleteDealerHint.
  ///
  /// In en, this message translates to:
  /// **'the folder is deleted with all its files - cannot be undone'**
  String get cardDeleteDealerHint;

  /// No description provided for @cardFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Card pipeline'**
  String get cardFlowTitle;

  /// No description provided for @cardBulkActions.
  ///
  /// In en, this message translates to:
  /// **'Bulk actions'**
  String get cardBulkActions;

  /// No description provided for @cardNightMenu.
  ///
  /// In en, this message translates to:
  /// **'Night mode: re-animate everything'**
  String get cardNightMenu;

  /// No description provided for @cardRestillMenu.
  ///
  /// In en, this message translates to:
  /// **'Turn backgrounds grey (all)'**
  String get cardRestillMenu;

  /// No description provided for @cardManifestMenu.
  ///
  /// In en, this message translates to:
  /// **'Preview manifest'**
  String get cardManifestMenu;

  /// No description provided for @cardDealers.
  ///
  /// In en, this message translates to:
  /// **'Dealers'**
  String get cardDealers;

  /// No description provided for @cardEmptyCollections.
  ///
  /// In en, this message translates to:
  /// **'No collection yet.\n\nGive an identifier, a name and a theme with \"+ New collection\" - one still per rank enters the queue for 13 (or 15) ranks, then come the 2 Video and 3 WebP stages.'**
  String get cardEmptyCollections;

  /// No description provided for @cardEmptyDealers.
  ///
  /// In en, this message translates to:
  /// **'No dealer yet.\n\nGive a name, a theme and a gesture with \"+ New dealer\" - a single item is generated in a waist-up frame and goes through the four stages.'**
  String get cardEmptyDealers;

  /// No description provided for @cardGestureLine.
  ///
  /// In en, this message translates to:
  /// **'gesture: {gesture}'**
  String cardGestureLine(Object gesture);

  /// No description provided for @cardAnimateTitle.
  ///
  /// In en, this message translates to:
  /// **'2 Video ({count} cards)'**
  String cardAnimateTitle(Object count);

  /// No description provided for @cardAnimateBody.
  ///
  /// In en, this message translates to:
  /// **'Two animations are generated for each card and assigned to their tags:\n• idle - 6 s, one controlled gesture\n• victory - 2 s, a short cheer inside the frame\n{total} videos in total; the old ones stay in the pool.'**
  String cardAnimateBody(Object total);

  /// No description provided for @cardEditNeedsOne.
  ///
  /// In en, this message translates to:
  /// **'Editing is for a single rank - select one card'**
  String get cardEditNeedsOne;

  /// No description provided for @cardPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push - {name}'**
  String cardPushTitle(Object name);

  /// No description provided for @cardPushBody.
  ///
  /// In en, this message translates to:
  /// **'The sheet and thumb files are uploaded to R2 (cards), then the manifest is written. Right now the webp of {ready}/{total} ranks is ready.\n\nThis is a PUBLISHING action and CANNOT BE UNDONE.'**
  String cardPushBody(Object ready, Object total);

  /// No description provided for @cardPushQueued.
  ///
  /// In en, this message translates to:
  /// **'Push added to the queue - follow it on the Queue tab'**
  String get cardPushQueued;

  /// No description provided for @cardCollectionCardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collection card - theme, 16 slots, model, face retouch'**
  String get cardCollectionCardTooltip;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @cardNoThemeTap.
  ///
  /// In en, this message translates to:
  /// **'No theme - tap: Collection card'**
  String get cardNoThemeTap;

  /// No description provided for @cardThemeTap.
  ///
  /// In en, this message translates to:
  /// **'{theme}\nCollection card: tap (theme, 16 slots, model, face retouch)'**
  String cardThemeTap(Object theme);

  /// No description provided for @cardDeleteCollectionStills.
  ///
  /// In en, this message translates to:
  /// **'The collection folder is deleted with all its cards ({stills} stills).\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.'**
  String cardDeleteCollectionStills(Object stills);

  /// No description provided for @cardDeleteCollectionStillsPushed.
  ///
  /// In en, this message translates to:
  /// **'The collection folder is deleted with all its cards ({stills} stills, {pushed} pushed).\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.'**
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed);

  /// No description provided for @cardClearCards.
  ///
  /// In en, this message translates to:
  /// **'Clear cards'**
  String get cardClearCards;

  /// No description provided for @cardClearCardsBody.
  ///
  /// In en, this message translates to:
  /// **'{ranks} - still, candidates, video and webp are deleted; the rank stays empty (generate it again with \"1 Still\").'**
  String cardClearCardsBody(Object ranks);

  /// No description provided for @cardsCleared.
  ///
  /// In en, this message translates to:
  /// **'{count} cards cleared'**
  String cardsCleared(Object count);

  /// No description provided for @cardsClearFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} cards could not be cleared'**
  String cardsClearFailed(Object count);

  /// No description provided for @cardGenerateStill.
  ///
  /// In en, this message translates to:
  /// **'Generate 1 Still'**
  String get cardGenerateStill;

  /// No description provided for @cardGenerateVideo.
  ///
  /// In en, this message translates to:
  /// **'Generate 2 Video'**
  String get cardGenerateVideo;

  /// No description provided for @cardGenerateWebp.
  ///
  /// In en, this message translates to:
  /// **'Generate 3 WebP'**
  String get cardGenerateWebp;

  /// No description provided for @cardBackUpper.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get cardBackUpper;

  /// No description provided for @cardAssetVideo.
  ///
  /// In en, this message translates to:
  /// **'Video ({tag})'**
  String cardAssetVideo(Object tag);

  /// No description provided for @cardAssetSheet.
  ///
  /// In en, this message translates to:
  /// **'WebP / cut ({tag})'**
  String cardAssetSheet(Object tag);

  /// No description provided for @cardAssetMissing.
  ///
  /// In en, this message translates to:
  /// **'No {asset}'**
  String cardAssetMissing(Object asset);

  /// No description provided for @cardAssetDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {asset}?'**
  String cardAssetDeleteConfirm(Object asset);

  /// No description provided for @cardAssetDeleteVideoBody.
  ///
  /// In en, this message translates to:
  /// **'Only the video of this tag is deleted; the copy in the pool, the still and the webp stay.'**
  String get cardAssetDeleteVideoBody;

  /// No description provided for @cardAssetDeleteSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Only sheet.webp, the thumb and the cut frames are deleted; the video and the still stay.'**
  String get cardAssetDeleteSheetBody;

  /// No description provided for @cardAssetDeleteStillBody.
  ///
  /// In en, this message translates to:
  /// **'Only the selected still is deleted; the candidates, the video and the webp stay.'**
  String get cardAssetDeleteStillBody;

  /// No description provided for @cardPoolDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete from the pool'**
  String get cardPoolDelete;

  /// No description provided for @cardPoolDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{id} is deleted from the pool. Copies assigned to tags ({tags}) stay.'**
  String cardPoolDeleteBody(Object id, Object tags);

  /// No description provided for @cardNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get cardNone;

  /// No description provided for @cardNewAnimTag.
  ///
  /// In en, this message translates to:
  /// **'New animation tag'**
  String get cardNewAnimTag;

  /// No description provided for @cardNewAnimTagHelp.
  ///
  /// In en, this message translates to:
  /// **'The game reads it by this name (idle, wink, victory ...)'**
  String get cardNewAnimTagHelp;

  /// No description provided for @cardUnassigned.
  ///
  /// In en, this message translates to:
  /// **'not assigned'**
  String get cardUnassigned;

  /// No description provided for @cardAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'assigned: {tags}'**
  String cardAssignedTo(Object tags);

  /// No description provided for @cardAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign: {name}'**
  String cardAssignTo(Object name);

  /// No description provided for @cardAssignNewTag.
  ///
  /// In en, this message translates to:
  /// **'Assign to a new tag...'**
  String get cardAssignNewTag;

  /// No description provided for @cardAnimReady.
  ///
  /// In en, this message translates to:
  /// **'video + webp ready'**
  String get cardAnimReady;

  /// No description provided for @cardAnimVideoOnly.
  ///
  /// In en, this message translates to:
  /// **'has video, no webp'**
  String get cardAnimVideoOnly;

  /// No description provided for @cardPoolEmpty.
  ///
  /// In en, this message translates to:
  /// **'No video in the pool - run \"2 Video\" first'**
  String get cardPoolEmpty;

  /// No description provided for @cardDeleteVideoKeepTag.
  ///
  /// In en, this message translates to:
  /// **'Delete the video (the tag stays)'**
  String get cardDeleteVideoKeepTag;

  /// No description provided for @cardDeleteSheet.
  ///
  /// In en, this message translates to:
  /// **'Delete WebP / cut'**
  String get cardDeleteSheet;

  /// No description provided for @cardDeleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete the tag (with its video + webp)'**
  String get cardDeleteTag;

  /// No description provided for @cardVideosHeader.
  ///
  /// In en, this message translates to:
  /// **'Videos ({count}) - tap = assign / preview / delete'**
  String cardVideosHeader(Object count);

  /// No description provided for @cardDeleteThisDealerBody.
  ///
  /// In en, this message translates to:
  /// **'The folder of {name} is deleted with all its files. CANNOT BE UNDONE.'**
  String cardDeleteThisDealerBody(Object name);

  /// No description provided for @cardClearCard.
  ///
  /// In en, this message translates to:
  /// **'Clear card'**
  String get cardClearCard;

  /// No description provided for @cardClearCardBody.
  ///
  /// In en, this message translates to:
  /// **'{name}: still, candidates, video, webp and animations are deleted; the rank stays empty (generate it again with \"1 Still\").'**
  String cardClearCardBody(Object name);

  /// No description provided for @cardClearCardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear card (the rank becomes empty)'**
  String get cardClearCardTooltip;

  /// No description provided for @cardViewCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cardViewCut;

  /// No description provided for @cardDeleteThisVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete this video ({tag})'**
  String cardDeleteThisVideo(Object tag);

  /// No description provided for @cardDeleteSheetTag.
  ///
  /// In en, this message translates to:
  /// **'Delete WebP / cut ({tag})'**
  String cardDeleteSheetTag(Object tag);

  /// No description provided for @cardDeleteStill.
  ///
  /// In en, this message translates to:
  /// **'Delete the still'**
  String get cardDeleteStill;

  /// No description provided for @cardNoVideo.
  ///
  /// In en, this message translates to:
  /// **'No video - generate it with \"2 Video\"'**
  String get cardNoVideo;

  /// No description provided for @cardNoCut.
  ///
  /// In en, this message translates to:
  /// **'No cut - generate it with \"3 WebP\"'**
  String get cardNoCut;

  /// No description provided for @cardCutFrameFailed.
  ///
  /// In en, this message translates to:
  /// **'The cut frame could not be read'**
  String get cardCutFrameFailed;

  /// No description provided for @cardNoStill.
  ///
  /// In en, this message translates to:
  /// **'No still - generate it with \"1 Still\"'**
  String get cardNoStill;

  /// No description provided for @cardStillFailed.
  ///
  /// In en, this message translates to:
  /// **'The still could not be read'**
  String get cardStillFailed;

  /// No description provided for @cardPromptTitleAge.
  ///
  /// In en, this message translates to:
  /// **'Prompt  ·  age {age}'**
  String cardPromptTitleAge(Object age);

  /// No description provided for @cardGuardFail.
  ///
  /// In en, this message translates to:
  /// **'Guard FAIL - frame drift / zoom / broken mask. Generate the video or the cut again.'**
  String get cardGuardFail;

  /// No description provided for @cardAnimsHeader.
  ///
  /// In en, this message translates to:
  /// **'Animations - tap = select, long press = assign / delete'**
  String get cardAnimsHeader;

  /// No description provided for @cardAnimOpened.
  ///
  /// In en, this message translates to:
  /// **'\"{tag}\" opened - generate it with 2 Video or assign from the pool'**
  String cardAnimOpened(Object tag);

  /// No description provided for @cardPickPoolVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick a video from the pool for \"{tag}\"'**
  String cardPickPoolVideo(Object tag);

  /// No description provided for @cardCandidatesHeader.
  ///
  /// In en, this message translates to:
  /// **'Candidates ({count}) - tap = select'**
  String cardCandidatesHeader(Object count);

  /// No description provided for @cardCandidatePicked.
  ///
  /// In en, this message translates to:
  /// **'The candidate is now the selected still'**
  String get cardCandidatePicked;

  /// No description provided for @cardRunFailed.
  ///
  /// In en, this message translates to:
  /// **'{step}: {error}'**
  String cardRunFailed(Object step, Object error);
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

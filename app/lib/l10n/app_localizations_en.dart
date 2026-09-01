// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get aboutApp => 'App';

  @override
  String actionTriggered(Object action) {
    return '$action triggered';
  }

  @override
  String get add => 'Add';

  @override
  String agentLabelWith(Object agent) {
    return 'Agent: $agent';
  }

  @override
  String get agentLocal => 'Local';

  @override
  String get agentNone => 'None';

  @override
  String get agentRunsOnServer =>
      'Agent runs on the server with project-level access';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return '$agent AI triggered for \"$title\"';
  }

  @override
  String get aiAgent => 'AI Agent';

  @override
  String get aiAgentUpdated => 'AI agent updated';

  @override
  String get aiResponse => 'AI Response';

  @override
  String get allApps => 'All Apps';

  @override
  String get allAppsCompletedOrPostponed =>
      'All apps are completed or postponed';

  @override
  String get allAppsHaveAutomations => 'All apps already have automations';

  @override
  String get allAppsHint => 'All apps';

  @override
  String get allPendingBlocked =>
      'All pending items are blocked by dependencies';

  @override
  String get apiConnection => 'API Connection';

  @override
  String get apiUrlSaved => 'API URL saved';

  @override
  String get appCreated => 'App created!';

  @override
  String get appDetail => 'App Detail';

  @override
  String get appFallback => 'App';

  @override
  String get appNameHint => 'App Name (e.g. My Game)';

  @override
  String get appStatusBuilding => 'building';

  @override
  String get appStatusDeploying => 'deploying';

  @override
  String get appStatusError => 'error';

  @override
  String get appStatusFixing => 'fixing';

  @override
  String get appStatusIdle => 'idle';

  @override
  String get appStatusPublished => 'published';

  @override
  String get appStatusQueued => 'queued';

  @override
  String get appStatusUploading => 'uploading';

  @override
  String get appStatusWorking => 'working';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc =>
      'Mobile/desktop app with Google Play deploy support';

  @override
  String get appTypeGodotDesc =>
      'Game project with export targets (Windows, Android, Web)';

  @override
  String get appTypePhaserDesc =>
      'Phaser 3 + TypeScript game, wrapped as Android AAB via Capacitor';

  @override
  String get appTypePythonDesc =>
      'Python project with script runner and pip management';

  @override
  String get appTypeWebDesc => 'Web app with static hosting deploy support';

  @override
  String get apps => 'Apps';

  @override
  String get archivedLabel => 'archived';

  @override
  String get artAndAssets => 'Art & Assets';

  @override
  String get artBible => 'Art Bible';

  @override
  String get artBibleCardSubtitle => 'Visual identity anchor doc';

  @override
  String get artBibleHint =>
      'Identity statement, palette (hex), typography, prohibitions, technical specs...';

  @override
  String get artBibleSaved => 'Art bible saved';

  @override
  String get artBibleShort => 'Art bible';

  @override
  String get artBibleSubtitle =>
      'Visual identity anchor — palette, typography, style prohibitions. Every asset task references this.';

  @override
  String get artBibleTaskCreated => 'Art bible task created';

  @override
  String artBibleTitle(Object app) {
    return 'Art Bible - $app';
  }

  @override
  String get askAQuestionHint => 'Ask a question...';

  @override
  String get askAgent => 'Ask Agent';

  @override
  String get askAnythingAboutYourApps => 'Ask anything about your apps';

  @override
  String get assetAudit => 'Asset Audit';

  @override
  String get assetAuditSubtitle => 'Broken refs, orphans, placeholders';

  @override
  String get assetAuditTaskCreated => 'Asset audit task created';

  @override
  String get assetSpecTaskCreated => 'Asset spec task created';

  @override
  String get assetSpecs => 'Asset Specs';

  @override
  String get assetSpecsSubtitle => 'Per-asset prompts from bible';

  @override
  String get attachments => 'Attachments';

  @override
  String attachmentsCount(Object count) {
    return 'Attachments ($count)';
  }

  @override
  String get automationCreated => 'Automation created';

  @override
  String get automationStateStarted => 'started';

  @override
  String get automationStateStopped => 'stopped';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => 'Automation updated';

  @override
  String get back => 'Back';

  @override
  String get backend => 'Backend';

  @override
  String get balanceCheck => 'Balance Check';

  @override
  String get balanceCheckSubtitle => 'Economy, progression, rewards';

  @override
  String get balanceCheckTaskCreated => 'Balance check task created';

  @override
  String batchRunError(Object error) {
    return 'Error during batch run: $error';
  }

  @override
  String blockedByList(Object ids) {
    return 'blocked by $ids';
  }

  @override
  String blockedByTask(Object id) {
    return 'Blocked by #$id';
  }

  @override
  String blockedCountLabel(Object count) {
    return '$count blocked';
  }

  @override
  String blockerNotInList(Object id) {
    return 'Task #$id is not in the current list (archived or deleted)';
  }

  @override
  String get brainstormAndCreate => 'Brainstorm & Create';

  @override
  String get brainstormConceptHint =>
      'Concept seed (e.g. \"ant colony idle game\", \"puzzle with gravity\")';

  @override
  String get brainstormCreated => 'Project created with brainstorm task!';

  @override
  String get brainstormDesc =>
      'Creates a new project with a brainstorm task. When the task runs, AI generates a full GDD and initial tasks.';

  @override
  String get brainstormNameHint => 'Project name (optional — AI can suggest)';

  @override
  String get brainstormNewGame => 'Brainstorm New Game';

  @override
  String get build => 'Build';

  @override
  String get buildAndDeploy => 'Build & Deploy';

  @override
  String get buildCancelled => 'Build cancelled';

  @override
  String get buildFailedLabel => 'build failed';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'Build polling timed out after 30 minutes - check server logs';

  @override
  String get buildTarget => 'Build Target';

  @override
  String get builds => 'Builds';

  @override
  String builtCount(Object count) {
    return 'Built ($count)';
  }

  @override
  String get buyMeACoffee => 'Buy me a coffee';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'Buy me a coffee  $price';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get cannotReachServer => 'Cannot reach server';

  @override
  String cannotReachServerWith(Object error) {
    return 'Cannot reach server: $error';
  }

  @override
  String get cannotSaveEmptyArtBible => 'Cannot save empty art bible';

  @override
  String get cannotSaveEmptyClaudeMd => 'Cannot save empty CLAUDE.md';

  @override
  String get cannotSaveEmptyDesignDoc => 'Cannot save empty design document';

  @override
  String get catBugsCrashes => 'Bugs & Crashes';

  @override
  String get catCodeStyle => 'Code Style';

  @override
  String get catDeadCode => 'Dead Code';

  @override
  String get catErrorHandling => 'Error Handling';

  @override
  String get catMemory => 'Memory';

  @override
  String get categoryAccessibility => 'Accessibility';

  @override
  String get categoryBug => 'Bug';

  @override
  String get categoryFeatures => 'Features';

  @override
  String get categoryMonetization => 'Monetization';

  @override
  String get categoryOther => 'Other';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categorySecurity => 'Security';

  @override
  String get categorySuggestion => 'Suggestion';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count characters';
  }

  @override
  String get chatHistory => 'Chat History';

  @override
  String get chatLogs => 'Reports';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count messages • $date';
  }

  @override
  String get checkBugsCrashes => 'Bugs & crashes';

  @override
  String get checkCodeStyle => 'Code style';

  @override
  String get checkDeadCode => 'Dead code';

  @override
  String get checkErrorHandling => 'Error handling';

  @override
  String get checkMemoryLeaks => 'Memory leaks';

  @override
  String get checkPerformanceIssues => 'Performance issues';

  @override
  String get checkSecurityVulnerabilities => 'Security vulnerabilities';

  @override
  String get checksToRun => 'Checks to run:';

  @override
  String get claudeMdHint => 'Project conventions, build commands, rules...';

  @override
  String get claudeMdSaved => 'CLAUDE.md saved';

  @override
  String get claudeMdSubtitle =>
      'Project instructions for AI agents working on this app.';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'Clear';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get clearMessages => 'Clear Messages';

  @override
  String clearMessagesConfirm(Object count) {
    return 'Delete all $count messages in this chat?';
  }

  @override
  String get close => 'Close';

  @override
  String get codeCheck => 'Code Check';

  @override
  String get codeCheckBody =>
      'This will create a task for the AI agent to review your code and report findings as issues.';

  @override
  String get codeCheckRequested => 'Code check requested';

  @override
  String get codeCheckResults => 'Code Check Results';

  @override
  String get codeReview => 'Code Review';

  @override
  String get codeReviewSubtitle => 'Bugs, crashes, code quality';

  @override
  String get complete => 'Complete';

  @override
  String completedCount(Object count) {
    return 'Completed ($count)';
  }

  @override
  String get connectToYourServer => 'Connect to Your Server';

  @override
  String get connectYourPhone => 'Connect your phone';

  @override
  String get connectedSuccessfully => 'Connected successfully';

  @override
  String connectedTo(Object server) {
    return 'Connected to $server';
  }

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get connectionSuccessful => 'Connection successful!';

  @override
  String get connectionTimedOut => 'Connection timed out';

  @override
  String get consistencyCheck => 'Consistency Check';

  @override
  String get consistencyCheckSubtitle => 'GDD ↔ code ↔ data drift';

  @override
  String get consistencyCheckTaskCreated => 'Consistency check task created';

  @override
  String get console => 'Console';

  @override
  String get contentAudit => 'Content Audit';

  @override
  String get contentAuditSubtitle => 'Levels, characters, items, text';

  @override
  String get contentAuditTaskCreated => 'Content audit task created';

  @override
  String get continueLabel => 'Continue';

  @override
  String get control => 'Control';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label copied to clipboard';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copyAiResponse => 'Copy AI Response';

  @override
  String get copyDescription => 'Copy Description';

  @override
  String get copyTitle => 'Copy Title';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get couldNotDownloadPdf => 'Could not download the PDF';

  @override
  String get couldNotLoadBuildTargets => 'Could not load build targets';

  @override
  String get couldNotLoadDirectives => 'Could not load directives';

  @override
  String get couldNotOpenLink => 'Could not open link';

  @override
  String couldNotOpenPdf(Object error) {
    return 'Could not open the PDF: $error';
  }

  @override
  String get couldNotOpenPicker => 'Could not open the picker.';

  @override
  String get create => 'Create';

  @override
  String get createApp => 'Create App';

  @override
  String get createFirstApp => 'Create your first app to get started';

  @override
  String get createIssue => 'Create Issue';

  @override
  String createdAgo(Object time) {
    return 'created $time';
  }

  @override
  String get creating => 'Creating...';

  @override
  String criticalCount(Object count) {
    return '$count critical';
  }

  @override
  String get customAutomationPromptHint => 'Custom automation prompt...';

  @override
  String get customPrompt => 'Custom prompt';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAutomation => 'Delete Automation';

  @override
  String deleteAutomationConfirm(Object app) {
    return 'Remove automation for $app?';
  }

  @override
  String get deleteChat => 'Delete Chat';

  @override
  String get deleteChatConfirm => 'Delete this conversation?';

  @override
  String deleteConfirmTitled(Object title) {
    return 'Delete \"$title\"?\nThis cannot be undone.';
  }

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get deleteReportBody =>
      'This permanently removes the report and its screenshots.';

  @override
  String get deleteReportTitle => 'Delete report?';

  @override
  String get deleted => 'Deleted';

  @override
  String get dependsOn => 'Depends on';

  @override
  String get deploy => 'Deploy';

  @override
  String get deployToProduction => 'Deploy to Production';

  @override
  String get deployToProductionBody =>
      'This will build and publish to ALL users on Google Play.\n\nMake sure you have tested on internal/beta first.';

  @override
  String get deployToProductionTitle => 'Deploy to Production?';

  @override
  String get descriptionHint => 'Description...';

  @override
  String get designDoc => 'Design Doc';

  @override
  String get designDocHint => 'Describe your app vision, features, goals...';

  @override
  String get designDocSaved => 'Design doc saved';

  @override
  String get designDocShort => 'Design doc';

  @override
  String get designDocSubtitle =>
      'The AI will use this as context for all work on this app.';

  @override
  String designDocTitle(Object app) {
    return 'Design Doc - $app';
  }

  @override
  String get designDocument => 'Design Document';

  @override
  String get designReview => 'Design Review';

  @override
  String get designReviewSubtitle => 'GDD, mechanics, UX audit';

  @override
  String get designReviewTaskCreated => 'Design review task created';

  @override
  String get details => 'Details';

  @override
  String get detectingServer => 'Detecting server...';

  @override
  String get developer => 'Developer';

  @override
  String get directServerUrlLan => 'Direct Server URL (LAN)';

  @override
  String get directiveHistory => 'Directive history';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get display => 'Display';

  @override
  String get doIt => 'Do It';

  @override
  String get done => 'Done';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total done';
  }

  @override
  String durationLabelWith(Object seconds) {
    return 'Duration: ${seconds}s';
  }

  @override
  String get edit => 'Edit';

  @override
  String editNamed(Object label) {
    return 'Edit $label';
  }

  @override
  String editTitleNamed(Object app) {
    return 'Edit: $app';
  }

  @override
  String get editWorkerUrl => 'Edit Worker URL';

  @override
  String get engine => 'Engine';

  @override
  String engineChanged(Object previous, Object current) {
    return 'Engine changed: $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'Engine confirmed: $engine';
  }

  @override
  String get engineDetectionFailed => 'Engine detection failed';

  @override
  String get enhance => 'Enhance';

  @override
  String get enhanceConfirmBody =>
      'AI will rewrite the document. This cannot be undone.';

  @override
  String enhanceConfirmTitle(Object label) {
    return 'Enhance $label?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return '$label enhance error: $error';
  }

  @override
  String enhanceStarted(Object label) {
    return '$label enhancement started on server...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label enhanced successfully';
  }

  @override
  String get enhancementFailed => 'Enhancement failed';

  @override
  String get enterConceptOrName => 'Enter a concept or project name';

  @override
  String get enterServerUrlDesc =>
      'Enter the URL of your Auto Game Builder server';

  @override
  String get enterUrlInPhoneApp =>
      'Enter this URL in the phone app to connect remotely';

  @override
  String get enterValidUrl =>
      'Enter a valid URL (e.g. http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc => 'Enter your Worker URL to connect remotely';

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return 'Every ${minutes}m';
  }

  @override
  String exitLabelWith(Object code) {
    return 'Exit: $code';
  }

  @override
  String get expandFoldersOrCreate =>
      'Expand the folders below or create a new app';

  @override
  String get failed => 'Failed';

  @override
  String failedCountLabel(Object count) {
    return '$count failed';
  }

  @override
  String get failedToBrainstorm => 'Failed to brainstorm';

  @override
  String get failedToCreateApp => 'Failed to create app';

  @override
  String get failedToCreateItem => 'Failed to create item';

  @override
  String get failedToCreateTestTask => 'Failed to create test task';

  @override
  String get failedToDelete => 'Failed to delete';

  @override
  String get failedToLoadApp => 'Failed to load app';

  @override
  String get failedToLoadAutomations => 'Failed to load automations';

  @override
  String get failedToLoadLogs => 'Failed to load logs';

  @override
  String get failedToLoadTasks => 'Failed to load tasks';

  @override
  String failedToLoadWithError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String get failedToRefreshApp => 'Failed to refresh app';

  @override
  String get failedToRequestCodeCheck => 'Failed to request code check';

  @override
  String get failedToRequestIdeas => 'Failed to request ideas';

  @override
  String get failedToReset => 'Failed to reset';

  @override
  String get failedToRunTask => 'Failed to run task';

  @override
  String failedToSave(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get failedToStartReupload => 'Failed to start re-upload';

  @override
  String failedToStartServer(Object error) {
    return 'Failed to start server: $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return 'Failed to start: $error';
  }

  @override
  String failedToTrigger(Object action) {
    return 'Failed to trigger $action';
  }

  @override
  String get failedToTriggerRun => 'Failed to trigger run';

  @override
  String get failedToUpdate => 'Failed to update';

  @override
  String get failedToUpdateAiAgent => 'Failed to update AI agent';

  @override
  String get failedToUpdateMcp => 'Failed to update MCP';

  @override
  String get favoritesOnly => 'Favorites only';

  @override
  String get feedback => 'Feedback';

  @override
  String fileTooLarge(Object max, Object files) {
    return 'Too large (max $max MB): $files';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterClosed => 'Closed';

  @override
  String get filterOpen => 'Open';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count findings',
      one: '1 finding',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return 'done $time';
  }

  @override
  String finishedFailedAgo(Object time) {
    return 'failed $time';
  }

  @override
  String forceRefreshFailed(Object error) {
    return 'Force refresh failed: $error';
  }

  @override
  String get forceRefreshTooltip =>
      'Force refresh from server (clears local cache)';

  @override
  String get fullAutoMode => 'Full Auto Mode';

  @override
  String get fullAutoModeOn =>
      'AI reads tasks, fixes, generates new ideas, repeats';

  @override
  String get generate => 'Generate';

  @override
  String get generateIdeas => 'Generate Ideas';

  @override
  String get generateIdeasHint => 'e.g. \"Ideas for improving the UI\"';

  @override
  String get genre => 'Genre';

  @override
  String get genreAction => 'Action';

  @override
  String get genreAny => 'Any';

  @override
  String get genreArcade => 'Arcade';

  @override
  String get genreCardGame => 'Card Game';

  @override
  String get genreIdleClicker => 'Idle/Clicker';

  @override
  String get genrePuzzle => 'Puzzle';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'Simulation';

  @override
  String get genreStrategy => 'Strategy';

  @override
  String get genreTowerDefense => 'Tower Defense';

  @override
  String get getStarted => 'Get Started';

  @override
  String get googleAccount => 'Google Account';

  @override
  String get hide => 'Hide';

  @override
  String highCount(Object count) {
    return '$count high';
  }

  @override
  String get ideaGenerationRequested => 'Idea generation requested';

  @override
  String get installed => 'installed';

  @override
  String get intervalMinLabel => 'Interval (min): ';

  @override
  String get invalidQrData => 'Invalid QR code data';

  @override
  String get issueCreated => 'Issue created';

  @override
  String get issueTitleHint => 'Issue title';

  @override
  String get issues => 'Issues';

  @override
  String get itemCreated => 'Item created';

  @override
  String get justNow => 'Just now';

  @override
  String get language => 'Language';

  @override
  String get later => 'Later';

  @override
  String get links => 'Links';

  @override
  String get loginTagline => 'Manage your game projects from anywhere';

  @override
  String get logs => 'Logs';

  @override
  String get maintenanceOnly => 'Maintenance only';

  @override
  String get markAsCompleted => 'Mark as Completed';

  @override
  String get markComplete => 'Mark Complete';

  @override
  String markCompleteConfirm(Object title) {
    return 'Mark \"$title\" as completed?';
  }

  @override
  String get markedAsCompleted => 'Marked as completed';

  @override
  String maxMinutes(Object minutes) {
    return 'Max ${minutes}m';
  }

  @override
  String get maxSessionMinLabel => 'Max session (min): ';

  @override
  String get mcpConfiguredPerApp =>
      'MCP servers are configured per-app on the app detail page.';

  @override
  String get mcpServers => 'MCP Servers';

  @override
  String mcpServersActive(Object count) {
    return 'MCP Servers ($count active)';
  }

  @override
  String get mcpServersDesc =>
      'Tool servers available for all AI runs on this app';

  @override
  String mediumCount(Object count) {
    return '$count medium';
  }

  @override
  String get moveBackToActive => 'Move back to Active';

  @override
  String get moveToCompletedFolder => 'Move to completed folder';

  @override
  String get nameIsRequired => 'Name is required';

  @override
  String get needHelpSettingUp => 'Need help setting up?';

  @override
  String get newApp => 'New App';

  @override
  String get newAutomation => 'New Automation';

  @override
  String get newChat => 'New Chat';

  @override
  String get newItem => 'New Item';

  @override
  String get newPrompt => 'New prompt';

  @override
  String newReportsCount(Object count) {
    return '$count new report(s)';
  }

  @override
  String get nextRunIn => 'Next run in';

  @override
  String get noApiKeyFound =>
      'No API key found — restart the server to generate one';

  @override
  String get noAppsMatch => 'No apps match';

  @override
  String get noAppsYet => 'No apps yet';

  @override
  String get noArtBibleYet =>
      'No art bible yet. Tap Add to define the visual identity — palette, typography, prohibitions.';

  @override
  String get noAutomationsMatchFilters => 'No automations match filters';

  @override
  String get noAutomationsYet => 'No automations yet';

  @override
  String noBuildTargetsFor(Object type) {
    return 'No build targets for $type projects.';
  }

  @override
  String get noBuildsYet => 'No builds yet';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get noClaudeMdYet =>
      'No CLAUDE.md yet. Tap Add to set project instructions for AI.';

  @override
  String get noDesignDocYet =>
      'No design document yet. Tap Add to describe your app vision.';

  @override
  String get noDirectivesYet => 'No directives sent yet.';

  @override
  String get noFavoritePrompts => 'No favorite prompts yet';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get noLogsFound => 'No logs found';

  @override
  String get noNewReports => 'No new reports';

  @override
  String get noOpenReports => 'No open reports';

  @override
  String get noOpenTasksToDependOn => 'No open tasks to depend on';

  @override
  String get noPendingItems => 'No pending items to work on';

  @override
  String get noPromptHistory =>
      'No prompt history yet.\nGenerate ideas to build history.';

  @override
  String get noReportsHere => 'No reports here';

  @override
  String get noWorkerUrlDetected =>
      'No Worker URL detected in settings.json.\nSet up a Cloudflare Worker to enable remote access.';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get notConnected => 'Not connected';

  @override
  String get notInstalled => 'not installed';

  @override
  String get notPaired => 'Not paired';

  @override
  String get notSet => '(not set)';

  @override
  String get notYetUploaded => 'not yet uploaded';

  @override
  String get onHold => 'On hold';

  @override
  String get oneShotRunEndsIn => 'One-shot run ends in';

  @override
  String oneTimeRunTriggered(Object app) {
    return '$app one-time run triggered';
  }

  @override
  String openCountLabel(Object count) {
    return '$count open';
  }

  @override
  String get openPdf => 'Open PDF';

  @override
  String get openingPdf => 'Opening PDF…';

  @override
  String get orSeparator => 'OR';

  @override
  String get output => 'Output';

  @override
  String get packageName => 'Package Name';

  @override
  String get paired => 'Paired';

  @override
  String get pairedSuccessfully => 'Paired successfully!';

  @override
  String get perfProfileTaskCreated => 'Performance profile task created';

  @override
  String get performanceProfile => 'Performance Profile';

  @override
  String get performanceProfileSubtitle => 'Frame drops, memory, load time';

  @override
  String get photo => 'Photo';

  @override
  String get postpone => 'Postpone';

  @override
  String postponedCount(Object count) {
    return 'Postponed ($count)';
  }

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get previousChat => 'Previous Chat';

  @override
  String get priority => 'Priority';

  @override
  String processingTasks(Object done, Object total) {
    return 'Processing $done of $total tasks...';
  }

  @override
  String get projectPath => 'Project Path';

  @override
  String get promptHistory => 'Prompt History';

  @override
  String get promptHistoryTooltip => 'Prompt history';

  @override
  String get publish => 'Publish';

  @override
  String get pullAndRebuild => 'Pull & Rebuild';

  @override
  String get pullFailed => 'Pull failed';

  @override
  String get pullNow => 'Pull now';

  @override
  String get pullOnly => 'Pull Only';

  @override
  String purchaseFailed(Object error) {
    return 'Purchase failed: $error';
  }

  @override
  String get putOnHoldForLater => 'Put on hold for later';

  @override
  String get pythonSectionDesc =>
      'Run scripts and manage the Python project via the server.';

  @override
  String get quickIssue => 'Quick Issue';

  @override
  String get rePairWithQr => 'Re-pair with QR Code';

  @override
  String get rebuild => 'Rebuild';

  @override
  String get rebuildBody => 'Start a new build from scratch?';

  @override
  String get rebuildTitle => 'Rebuild?';

  @override
  String get recentBuilds => 'Recent Builds';

  @override
  String get refresh => 'Refresh';

  @override
  String refreshFailedShowingCached(Object message) {
    return 'Refresh failed — showing last synced data. $message';
  }

  @override
  String get refreshedFromServer => 'Refreshed from server';

  @override
  String get reload => 'Reload';

  @override
  String get reopen => 'Reopen';

  @override
  String get reportBugOrSuggestion => 'Report a Bug / Suggestion';

  @override
  String get reportBugSubtitle => 'Tell us what to fix or add';

  @override
  String get reportConsent =>
      'I agree to send this report with my device info (model, OS and app version) to the developer to help fix issues.';

  @override
  String get reportHint => 'What happened, or what would you like to see?';

  @override
  String get reportSentThanks => 'Thanks! Your report was sent.';

  @override
  String get reset => 'Reset';

  @override
  String get resetServer => 'Reset Server';

  @override
  String get resetServerBody => 'This will restart the backend server.';

  @override
  String resetServerRunningNote(Object count) {
    return '$count running automation(s) will be stopped first to prevent auto-restart.';
  }

  @override
  String get resumeActiveDevelopment => 'Resume active development';

  @override
  String get retry => 'Retry';

  @override
  String get retryUpload => 'Retry Upload';

  @override
  String get reuploadStarted => 'Re-upload started';

  @override
  String get run => 'Run';

  @override
  String get runAgainBody =>
      'A one-shot run is already in progress but the AI may have stopped early. Trigger another run?';

  @override
  String get runAgainTitle => 'Run Again?';

  @override
  String get runAnyway => 'Run Anyway';

  @override
  String get runCheck => 'Run Check';

  @override
  String get runOnce => 'Run Once';

  @override
  String get runOnceInProgress => 'Run Once (in progress)';

  @override
  String get running => 'Running';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get saveEmptyGddBody => 'This will erase the current design document.';

  @override
  String get saveEmptyGddTitle => 'Save empty GDD?';

  @override
  String get saving => 'Saving...';

  @override
  String scanError(Object error) {
    return 'Scan error: $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'Scan failed: server returned $status';
  }

  @override
  String get scanForProjects => 'Scan for projects';

  @override
  String get scanPairingQrTitle => 'Scan Pairing QR Code';

  @override
  String get scanQrToPair => 'Scan QR Code to Pair';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return 'Scanned $found folders: $imported imported, $skipped skipped';
  }

  @override
  String get scanThisQr => 'Scan this QR from your phone';

  @override
  String get scanToInstall => 'Scan to install on your phone';

  @override
  String get scopeCheck => 'Scope Check';

  @override
  String get scopeCheckSubtitle => 'Cut list + realism pass';

  @override
  String get scopeCheckTaskCreated => 'Scope check task created';

  @override
  String get screenshotsOptional => 'Screenshots (optional)';

  @override
  String get screenshotsTooLarge =>
      'Screenshots are large — you may need to remove one.';

  @override
  String get searchAppsHint => 'Search apps...';

  @override
  String searchFilterChip(Object query) {
    return 'Search: \"$query\"';
  }

  @override
  String get searchHint => 'Search...';

  @override
  String get sectionAiAgents => 'AI Agents';

  @override
  String get sectionGameEngines => 'Game Engines';

  @override
  String get sectionPaths => 'Paths';

  @override
  String get sectionServices => 'Services';

  @override
  String get sectionSystemTools => 'System Tools';

  @override
  String get selectAnApp => 'Select an app';

  @override
  String get selectAnAppFirst => 'Select an app first';

  @override
  String get selectApp => 'Select app';

  @override
  String get selectAppForContext =>
      'Select an app for context, or ask general questions';

  @override
  String get selectAppToViewItems => 'Select an app to view items';

  @override
  String get selectCategoriesOrPrompt =>
      'Select categories or type your own prompt.';

  @override
  String get sendReport => 'Send report';

  @override
  String get sending => 'Sending…';

  @override
  String get server => 'Server';

  @override
  String get serverConfiguration => 'Server Configuration';

  @override
  String get serverConnection => 'Server Connection';

  @override
  String serverReturnedStatus(Object status) {
    return 'Server returned status $status';
  }

  @override
  String get serverStarted => 'Server started!';

  @override
  String get serverStartedHealthFailed =>
      'Server started but health check failed';

  @override
  String get serverStopped => 'Server stopped';

  @override
  String get serverUnreachable => 'Server unreachable';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get sessionEndsIn => 'Session ends in';

  @override
  String get sessionRefreshed => 'Session refreshed — recent context preserved';

  @override
  String get settings => 'Settings';

  @override
  String get settingsJsonNotFound => 'settings.json not found';

  @override
  String get settingsJsonRestartNote =>
      'settings.json — restart server after changes';

  @override
  String get settingsSavedRestart => 'Settings saved — restart server to apply';

  @override
  String get setupInstructions => 'Setup Instructions';

  @override
  String get setupServerFirst => 'Set up the server on your PC first';

  @override
  String get setupStepCloneRepo => 'Clone the repository:';

  @override
  String get setupStepEnterUrl =>
      'Enter the URL shown in the terminal (e.g. http://192.168.1.100:8000):';

  @override
  String get setupStepInstallDeps => 'Install dependencies:';

  @override
  String get setupStepInstallPython => 'Install Python 3.10+ on your PC';

  @override
  String get setupStepRunWizard => 'Run the setup wizard:';

  @override
  String get setupStepStartServer => 'Start the server:';

  @override
  String get show => 'Show';

  @override
  String get showAll => 'Show all';

  @override
  String get showAppIcons => 'Show app icons';

  @override
  String get showAppIconsDesc =>
      'Display real app icons on the dashboard instead of generic type icons';

  @override
  String get showPairingQr => 'Show Pairing QR Code';

  @override
  String get signInCancelled => 'Sign-in was cancelled';

  @override
  String signInFailed(Object error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get start => 'Start';

  @override
  String get startBuildFromCardAbove => 'Start a build from the card above';

  @override
  String get startServer => 'Start Server';

  @override
  String get startServerNotFound => 'start_server.py not found';

  @override
  String get status => 'Status';

  @override
  String get statusActive => 'Active';

  @override
  String get statusAll => 'All';

  @override
  String get statusBuilt => 'Built';

  @override
  String get statusBuiltLower => 'Built';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusDivided => 'Divided';

  @override
  String get statusDone => 'Done';

  @override
  String get statusFailedLower => 'Failed';

  @override
  String statusFilterChip(Object value) {
    return 'Status: $value';
  }

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusPendingLower => 'Pending';

  @override
  String get statusPostponed => 'Postponed';

  @override
  String get stop => 'Stop';

  @override
  String get stopServer => 'Stop Server';

  @override
  String get stoppedLabel => 'Stopped';

  @override
  String stuckSuffix(Object time) {
    return '$time STUCK';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return '$count stuck task(s) auto-failed after 30min timeout';
  }

  @override
  String get studioReviews => 'Studio Reviews';

  @override
  String get submit => 'Submit';

  @override
  String get submitting => 'Submitting...';

  @override
  String get suggestApiBackend => 'API & Backend';

  @override
  String get suggestFeatureIntegration => 'Feature Integration';

  @override
  String get suggestFixFailures => 'Fix Failures';

  @override
  String get suggestGddAligned => 'GDD-Aligned';

  @override
  String get suggestImproveCodebase => 'Improve Codebase';

  @override
  String get suggestNextMilestone => 'Next Milestone';

  @override
  String get suggestPerformanceBoost => 'Performance Boost';

  @override
  String get suggestRevenueIdeas => 'Revenue Ideas';

  @override
  String get suggestSecurityHardening => 'Security Hardening';

  @override
  String get suggestTaskPrioritization => 'Task Prioritization';

  @override
  String get suggestTestingQa => 'Testing & QA';

  @override
  String get suggestUserEngagement => 'User Engagement';

  @override
  String get suggestUxPolish => 'UX Polish';

  @override
  String get suggestedForYou => 'Suggested for you';

  @override
  String get summary => 'Summary';

  @override
  String get supportDevelopment => 'Support Development';

  @override
  String get supportDevelopmentDesc =>
      'Enjoying the app? Consider supporting development!';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String syncedAgo(Object time) {
    return 'Synced $time';
  }

  @override
  String get tapPlusToCreateAutomation =>
      'Tap + to create your first automation';

  @override
  String get tapPlusToStartConversation => 'Tap + to start a conversation';

  @override
  String get tapToAddLongPressToEdit => 'Tap to add, long-press to edit';

  @override
  String get tapToOpenLongPressToEdit => 'Tap to open, long-press to edit';

  @override
  String get tapToRedetectEngine => 'Tap to re-detect the engine from disk';

  @override
  String taskLabelWith(Object task) {
    return 'Task: $task';
  }

  @override
  String get taskOverview => 'Task Overview';

  @override
  String get taskResetToPending => 'Task reset to pending';

  @override
  String get tasks => 'Tasks';

  @override
  String get techDebtScan => 'Tech Debt Scan';

  @override
  String get techDebtScanSubtitle => 'God scripts, duplicates, TODOs';

  @override
  String get techDebtTaskCreated => 'Tech debt scan task created';

  @override
  String get tellUsMore => 'Tell us more';

  @override
  String get test => 'Test';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get testTaskCreated => 'Test task created';

  @override
  String get testing => 'Testing...';

  @override
  String get theme => 'Theme';

  @override
  String get thinking => 'Thinking...';

  @override
  String timeDaysAgo(Object days) {
    return '${days}d ago';
  }

  @override
  String timeHoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeMonthsAgo(Object months) {
    return '${months}mo ago';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return '${seconds}s ago';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return '${weeks}w ago';
  }

  @override
  String get titleHint => 'Title';

  @override
  String get titleIsRequired => 'Title is required';

  @override
  String get trackAlpha => 'Alpha';

  @override
  String get trackBeta => 'Beta';

  @override
  String get trackInternal => 'Internal';

  @override
  String get trackProd => 'Prod';

  @override
  String triggeredOfItems(Object done, Object total) {
    return 'Triggered $done of $total items';
  }

  @override
  String get tryChangingFilters => 'Try changing the category or status filter';

  @override
  String get type => 'Type';

  @override
  String get typeBug => 'Bug';

  @override
  String get typeFeature => 'Feature';

  @override
  String typeFilterChip(Object value) {
    return 'Type: $value';
  }

  @override
  String get typeFix => 'Fix';

  @override
  String get typeIdea => 'Idea';

  @override
  String get typeIssue => 'Issue';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get updateAvailableBody =>
      'A new version is available on GitHub.\nPull the latest code and rebuild to update.';

  @override
  String get updateFailed => 'Update failed';

  @override
  String updatedAgo(Object time) {
    return 'updated $time';
  }

  @override
  String updatedNamed(Object label) {
    return '$label updated';
  }

  @override
  String get uploadToGooglePlay => 'Upload to Google Play';

  @override
  String urgentCountLabel(Object count) {
    return '$count urgent';
  }

  @override
  String get urgentLabel => 'urgent';

  @override
  String get userFallback => 'User';

  @override
  String get version => 'Version';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => 'View failed tasks';

  @override
  String get viewIssues => 'View issues';

  @override
  String get viewOnGitHub => 'View on GitHub';

  @override
  String get warningPublishesToAll => 'Warning: This publishes to all users!';

  @override
  String get webDeploy => 'Web Deploy';

  @override
  String get webDeploySectionDesc =>
      'Build and deploy the web app via the server.';

  @override
  String get website => 'Website';

  @override
  String get whatIsThis => 'What is this?';

  @override
  String get workOnAll => 'Work on All';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n($count blocked item(s) will be skipped.)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return 'Run AI on all $count pending item(s)?\nThey will be processed sequentially.';
  }

  @override
  String get workOnAllPending => 'Work on All Pending';

  @override
  String get workOnThis => 'Work on This';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return 'Run $agent AI on:\n\"$title\"';
  }

  @override
  String get workerUrl => 'Worker URL';

  @override
  String get workerUrlAutoDetected =>
      'Auto-detected from settings.json (read-only)';

  @override
  String get workerUrlCopied => 'Worker URL copied';

  @override
  String get workerUrlHelp =>
      'Get this URL from the desktop app or your server admin';

  @override
  String get workerUrlSaved => 'Worker URL saved';

  @override
  String get workerUrlSetHint =>
      'Set cloudflare.worker_url in server/config/settings.json';

  @override
  String get youreAllSet => 'You\'re All Set!';
}

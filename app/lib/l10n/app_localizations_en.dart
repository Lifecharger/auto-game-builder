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
  String get shareUsageStats => 'Share anonymous usage statistics';

  @override
  String get shareUsageStatsDesc =>
      'Anonymous counts of sessions and which screens are opened. No project names, no task text, no paths.';

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

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'No AGENTS.md yet. Tap Add to set project instructions for AI.';

  @override
  String get cannotSaveEmptyAgentsMd => 'Cannot save empty AGENTS.md';

  @override
  String get agentsMdSaved => 'AGENTS.md saved';

  @override
  String get reportEmailLabel => 'E-mail (optional)';

  @override
  String get reportEmailHint => 'your e-mail, if you want a reply';

  @override
  String get reportEmailNote =>
      'Only used to answer this report. Leave it empty to stay anonymous.';

  @override
  String get reportEmailInvalid => 'This does not look like an e-mail address.';

  @override
  String get reportReply => 'Reply';

  @override
  String reportReplySubject(String app) {
    return 'About your $app report';
  }

  @override
  String get navGenerate => 'Generate';

  @override
  String get navGallery => 'Generated';

  @override
  String get navFlow => 'Pipeline';

  @override
  String get navQueue => 'Queue';

  @override
  String get navDelivery => 'Delivery';

  @override
  String get navBuckets => 'Buckets';

  @override
  String get assetModeTooltip => 'Asset mode';

  @override
  String get deliveryModeTooltip => 'Delivery mode';

  @override
  String get videoPlaybackFailed => 'The video could not be played';

  @override
  String get apiKeyRefusedBanner =>
      'API key refused - tap to fix it in Settings';

  @override
  String get errOffline => 'Cannot reach the server - check your connection';

  @override
  String get errTimeout => 'The server took too long to answer - try again';

  @override
  String errGatewayTimeout(int status) {
    return 'The server did not answer in time (gateway timeout $status)';
  }

  @override
  String errGateway(int status) {
    return 'The server is unreachable behind its gateway (gateway error $status) - check that it is running';
  }

  @override
  String errServer(int status) {
    return 'Server error ($status) - try again later';
  }

  @override
  String errUnauthorized(int status) {
    return 'Not authorized ($status) - check the API key in Settings';
  }

  @override
  String errNotFound(int status) {
    return 'Not found on the server ($status)';
  }

  @override
  String errRateLimited(int status) {
    return 'Too many requests ($status) - wait a moment and try again';
  }

  @override
  String errTooLarge(int status) {
    return 'Too large for the server ($status)';
  }

  @override
  String errRejected(int status) {
    return 'The server refused the request ($status)';
  }

  @override
  String get errBadResponse =>
      'The server sent an answer the app could not read';

  @override
  String get errUnknown => 'The request failed - try again';

  @override
  String bucketsCounting(String bucket) {
    return 'Counting $bucket...';
  }

  @override
  String get bucketsTakedownTitle => 'Takedown (new + legacy)';

  @override
  String get bucketsDeleteForeverTitle => 'Delete permanently';

  @override
  String bucketsDeleteWarning(int count) {
    return '$count objects will be deleted. THIS CANNOT BE UNDONE.';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count keys have no match in the legacy twin - they are deleted from this bucket only.';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return 'Type the bucket name to confirm: $bucket';
  }

  @override
  String get bucketsTakedown => 'Takedown';

  @override
  String bucketsDeleted(int count) {
    return '$count objects deleted';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count objects deleted, $twin from the legacy twin';
  }

  @override
  String bucketsCopySource(String path) {
    return 'Source: $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'Source tree: $path';
  }

  @override
  String get bucketsWholeBucket => '(whole bucket)';

  @override
  String get bucketsCopyNote =>
      'The copy runs inside the storage service - no bytes pass through the phone.';

  @override
  String get bucketsTargetKey => 'Target key';

  @override
  String get bucketsTargetPrefix => 'Target prefix';

  @override
  String bucketsCopyStarted(String op) {
    return 'Copy started ($op)';
  }

  @override
  String get bucketsFixHeadersTitle => 'Fix headers';

  @override
  String bucketsFixHeadersBody(String path) {
    return 'The Cache-Control header of the objects under $path is checked; an object that departs from the standard is rewritten in place (Content-Type is kept). No bytes are downloaded.\n\nPrefixes left mutable on purpose are skipped.';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'Header repair started ($op)';
  }

  @override
  String get bucketsOperations => 'Operations';

  @override
  String get bucketsNoOperations => 'No operations yet';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  ok $ok  ·  failed $failed';
  }

  @override
  String get bucketsTwinDiffRunning => 'Computing the twin diff...';

  @override
  String get bucketsLocalDiffRunning => 'Computing the local diff...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin (legacy twin)';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'Local pushed folder <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => 'Missing in the legacy twin';

  @override
  String get bucketsMissingInBucket => 'Missing in the bucket';

  @override
  String get bucketsOnlyInLegacy => 'Only in the legacy twin';

  @override
  String get bucketsOnlyInBucket => 'Only in the bucket';

  @override
  String get bucketsSizeMismatch => 'Size differs';

  @override
  String get bucketsUnmapped => 'Unmatched (no rule)';

  @override
  String get bucketsDerived => 'Generated in the bucket (thumbs)';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title: $count';
  }

  @override
  String get bucketsFixFolderHeaders => 'Fix this folder\'s headers';

  @override
  String get bucketsDiffs => 'Differences';

  @override
  String get bucketsTwinDiff => 'Legacy twin diff';

  @override
  String get bucketsLocalDiff => 'Local pushed folder diff';

  @override
  String get bucketsIntro =>
      'A bucket is the store named after its content. Counts are computed on request (listing only, no bytes are downloaded).';

  @override
  String get bucketsBadgeLegacy => 'LEGACY';

  @override
  String get bucketsBadgePrivate => 'private';

  @override
  String get bucketsBadgeContent => 'content';

  @override
  String get bucketsNotCounted => 'not counted';

  @override
  String bucketsObjectCount(int count) {
    return '$count objects';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'twin: $twin';
  }

  @override
  String get bucketsCount => 'Count';

  @override
  String get bucketsEmptyFolder => 'This folder is empty';

  @override
  String get bucketsTruncated =>
      'The list was cut short - open a narrower folder';

  @override
  String bucketsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bucketsClearSelection => 'Clear selection';

  @override
  String get bucketsTakedownTooltip =>
      'Takedown (also delete from the legacy twin)';

  @override
  String get bucketsSize => 'Size';

  @override
  String get bucketsContentType => 'Type';

  @override
  String get bucketsModified => 'Modified';

  @override
  String get bucketsNone => '(none)';

  @override
  String get bucketsMutableOnPurpose =>
      'Mutable on purpose - no standard applies';

  @override
  String bucketsHeaderOk(String kind) {
    return 'Meets the cache standard ($kind)';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return 'Standard: $expected';
  }

  @override
  String get bucketsLegacyTwin => 'Legacy twin';

  @override
  String get bucketsAddressCopied => 'Address copied';

  @override
  String get bucketsCopyAddress => 'Copy address';

  @override
  String get bucketsOpen => 'Open';

  @override
  String get bucketsPrivateNoAddress =>
      'This bucket is private - it has no public address';

  @override
  String get kindCard => 'Card';

  @override
  String get kindCharacter => 'Character';

  @override
  String get assetCodeMode => 'Code mode';

  @override
  String get assetPickFinishedImage => 'Select a finished image';

  @override
  String get assetGenerateVideo => 'Generate video';

  @override
  String get assetEnlarge => 'Enlarge';

  @override
  String percentValue(Object value) {
    return '$value%';
  }

  @override
  String get commonCategory => 'Category';

  @override
  String durSeconds(Object seconds) {
    return '$seconds s';
  }

  @override
  String durMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get charKindFemale => 'Female';

  @override
  String get charKindMale => 'Male';

  @override
  String get charKindAnimal => 'Animal';

  @override
  String get charKindMachine => 'Machine';

  @override
  String get outfitCatSet => 'Set';

  @override
  String get outfitCatTop => 'Top';

  @override
  String get outfitCatBottom => 'Bottom';

  @override
  String get outfitCatShoes => 'Shoes';

  @override
  String get outfitCatSocks => 'Socks';

  @override
  String get outfitCatHat => 'Hat';

  @override
  String get outfitCatHeadgear => 'Headgear';

  @override
  String get outfitCatAccessory => 'Accessory';

  @override
  String get outfitCatWeapon => 'Weapon';

  @override
  String get audioLabel => 'Audio';

  @override
  String get audioDownloading => 'Downloading...';

  @override
  String get audioOpen => 'Open audio';

  @override
  String get outfitExtractTitle => 'Extract outfit';

  @override
  String get outfitExtractBody =>
      'The person in the selected image is removed and the outfit is saved to the wardrobe as a ghost-mannequin product shot on a plain grey background. After that any character can wear it as a skin.';

  @override
  String get outfitExtractName => 'Outfit name';

  @override
  String get outfitExtractNameHint => 'e.g. Red evening dress';

  @override
  String get outfitExtractNote => 'Note (optional)';

  @override
  String get outfitExtractNoteHint => 'e.g. only the dress, not the shoes';

  @override
  String get outfitExtractHelp =>
      'Set: everything the person wears, in one shot. Weapon / accessory: only that item, without a mannequin.';

  @override
  String get outfitExtractAction => 'Extract';

  @override
  String equipSlotTitle(Object category) {
    return '$category slot';
  }

  @override
  String get equipSlotMultiHint => 'multiple choice - tap to put on / take off';

  @override
  String get equipSlotSingleHint =>
      'single choice - tap to put on, tap again to take off';

  @override
  String get equipSlotEmpty => '(empty)';

  @override
  String get equipSlotNoOutfits =>
      'No ready outfit in this category - use \"+ Generate outfit\" or \"Extract outfit\"';

  @override
  String get equipBaseLabel => 'Base:';

  @override
  String get equipUndress => 'Take all off';

  @override
  String get equipPickSourceTitle => 'Pick a source image';

  @override
  String get equipPickSourceHint =>
      'The latest finished generations (every mode). For incoming / staging / pushed images of the Jigsaw pipeline use the Pipeline > Jigsaw screen.';

  @override
  String get equipNoFinishedImage => 'No finished image';

  @override
  String get freeFlowTitle => 'Free pipeline';

  @override
  String get freeFlowEditTitle => 'Edit - edit engine';

  @override
  String get freeFlowEditLabel => 'What should change';

  @override
  String get freeFlowEditHint =>
      'e.g. change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => 'Edit added to the queue';

  @override
  String get freeFlowNoVideoTask => 'Free mode has no video task';

  @override
  String freeFlowVideoTitle(Object task) {
    return 'Generate video - $task';
  }

  @override
  String get freeFlowMotionLabel => 'Motion';

  @override
  String get freeFlowMotionHint =>
      'e.g. she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued =>
      'Video added to the queue - a play mark appears on this card when it is done';

  @override
  String get freeFlowDeleteConfirm => 'Delete this generation?';

  @override
  String get freeFlowDeleteWithVideosConfirm =>
      'Delete this generation and its videos?';

  @override
  String get freeFlowEmpty =>
      'Nothing generated in Free mode yet - start from the Generate tab';

  @override
  String get queueKindGeneration => 'Generation';

  @override
  String get queueKindTag => 'Tagging';

  @override
  String get queueKindMusic => 'Music';

  @override
  String get queueKindJob => 'Job';

  @override
  String get queueCancelRunningTitle => 'Cancel the running job';

  @override
  String get queueRemoveTitle => 'Remove from the queue';

  @override
  String get queueCancelIt => 'Cancel it';

  @override
  String get queueClearTitle => 'Clear the queue';

  @override
  String get queueClearBody =>
      'Cancel the waiting generation jobs? The running job continues.';

  @override
  String get queueCancelWaiting => 'Cancel the waiting jobs';

  @override
  String get queueEmpty => 'The queue is empty';

  @override
  String get queueEmptyHint => 'You can add jobs from the Generate tab';

  @override
  String get queueNow => 'Now';

  @override
  String queueWaitingCount(Object count) {
    return 'Waiting ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return 'Generation jobs ($count)';
  }

  @override
  String get queueOneQueue => 'One queue - every job';

  @override
  String queueJobCount(Object count) {
    return '$count job(s)';
  }

  @override
  String get queueMoveUp => 'Move up';

  @override
  String get queueMoveDown => 'Move down';

  @override
  String get queueUp => 'Up';

  @override
  String get queueDown => 'Down';

  @override
  String queueElapsed(Object time) {
    return 'elapsed $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return 'waiting $time';
  }

  @override
  String get queueWaiting => 'waiting';

  @override
  String get queueComfyReady => 'ComfyUI ready';

  @override
  String get queueComfyOff => 'ComfyUI is off';

  @override
  String get deliveryPoolNeverRan => 'never ran';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (dry run)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · $total images, $valid valid, $tagged tagged, $failed failed';
  }

  @override
  String get reportErrEmpty => 'Please write a message first.';

  @override
  String get reportErrTooLarge =>
      'Attachments are too large. Remove one and try again.';

  @override
  String flowOpError(Object message) {
    return 'Operation failed: $message';
  }

  @override
  String get flowOpCancelled => 'Operation cancelled';

  @override
  String flowOpDone(Object ok) {
    return '$ok done';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok done, $failed failed';
  }

  @override
  String get flowCollection => 'Collection';

  @override
  String get flowAllParen => '(all)';

  @override
  String get flowAll => 'all';

  @override
  String get flowSelectAll => 'Select all';

  @override
  String get flowRetag => 'Retag';

  @override
  String get flowRetagShort => 'Retag';

  @override
  String get flowRetagStarted => 'Tagging started';

  @override
  String get flowReadOnly => 'Read-only';

  @override
  String get flowPush => 'Push';

  @override
  String get flowPreview => 'Preview';

  @override
  String get flowYes => 'yes';

  @override
  String get flowNo => 'no';

  @override
  String get flowMissingUpper => 'MISSING';

  @override
  String get flowBadgeNoTags => 'no tags';

  @override
  String get flowTabPushed => '4 Pushed';

  @override
  String get flowSelectAssetFirst => 'Select an asset first';

  @override
  String get flowAccept => 'Accept';

  @override
  String get flowReject => 'Reject';

  @override
  String get flowUpload => 'Upload';

  @override
  String get flowNew => 'New';

  @override
  String get flowReadFailed => 'The pipeline could not be read';

  @override
  String flowFilesDeleted(Object count) {
    return '$count files deleted';
  }

  @override
  String get flowNegative => 'Negative';

  @override
  String get flowPositive2 => 'Positive 2';

  @override
  String get flowDuration => 'Duration';

  @override
  String get flowAddToQueue => 'Add to queue';

  @override
  String get commonDescription => 'Description';

  @override
  String get cbnFlowTitle => 'CBN pipeline';

  @override
  String get cbnFlowTabIncoming => '2 Incoming';

  @override
  String get cbnFlowTabReady => '3 Ready';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'Build - $count assets';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      'Regions + palette + numbered template + reveal video (CPU). The SAM step must already be done; outlines come from the SAM boundaries. (Hot: the build makes the line-art page itself with Qwen; step C is an optional preview.)';

  @override
  String get cbnFlowBuildBodyKid =>
      'Regions + palette + numbered template + SVG (CPU). The SAM step must already be done.';

  @override
  String get cbnFlowBuild => 'Build';

  @override
  String get cbnFlowBuildStarted =>
      'Build started - progress is shown at the top';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stage started ($count assets)';
  }

  @override
  String get cbnFlowStageObjects => 'Object list';

  @override
  String get cbnFlowLineart => 'Line art';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'Push - $count assets';
  }

  @override
  String get cbnFlowPushBody =>
      'The asset folders will be uploaded to R2 and moved to \"Pushed\".\n\nThis is a PUBLISHING action and cannot be undone.';

  @override
  String cbnFlowDeleteBody(Object count) {
    return '$count assets will be deleted.';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count deleted';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'No assets in this stage.\nSend them here with ACCEPT in CBN mode on the \"Generated\" screen.';

  @override
  String get cbnFlowEmptyStaging =>
      'No built asset yet.\nSelect on the \"Incoming\" tab and tap BUILD.';

  @override
  String get cbnFlowEmptyPushed => 'No pushed asset.';

  @override
  String get cbnFlowBadgeTagged => 'T';

  @override
  String get cbnFlowBadgeObjects => 'O';

  @override
  String cbnFlowBadgeBuilt(Object regions, Object colors) {
    return '${regions}r ${colors}c';
  }

  @override
  String get cbnFlowLayerNumbered => 'Numbered';

  @override
  String get cbnFlowLayerFinished => 'Finished';

  @override
  String get cbnFlowLayerSource => 'Source';

  @override
  String get cbnFlowLayerObjects => 'Objects';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions regions · $colors colours · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   tags: $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) Find objects';

  @override
  String get cbnFlowSamMasks => 'B) SAM masks';

  @override
  String get cbnFlowLineartPage => 'C) Line-art page (optional, Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) Build';

  @override
  String get cbnFlowStepMissingA => 'Step A (object list) has not been run';

  @override
  String get cbnFlowStepMissingB => 'Step B (SAM masks) has not been run';

  @override
  String get cbnFlowStepMissingC => 'Step C (line-art page) has not been run';

  @override
  String get cbnFlowImageFailed => 'The image could not be loaded';

  @override
  String get jigsawFlowTitle => 'Jigsaw pipeline';

  @override
  String get jigsawFlowTabTagged => '2 Tagged';

  @override
  String get jigsawFlowTabToPush => '3 To push';

  @override
  String get jigsawFlowQueueAll => 'QUEUE ALL';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'QUEUE ALL - $count assets';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return 'Generate video - $count assets';
  }

  @override
  String get jigsawFlowPositive1 => 'Positive 1 - subject';

  @override
  String get jigsawFlowPositive1Help => 'empty = each asset\'s own prompt';

  @override
  String get jigsawFlowMotionPreset => 'Motion preset';

  @override
  String get jigsawFlowSpreadInTurn => '(spread in turn)';

  @override
  String get jigsawFlowPositive2 => 'Positive 2 - motion';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = where the subject prompt goes. Empty = the presets in turn.';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return 'The $count presets will be spread in turn.';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => 'No asset without a video';

  @override
  String get jigsawFlowSelectWithoutVideo => 'Select assets without a video';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued videos added to the queue - they land here when done';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued videos added to the queue, $skipped skipped - they land here when done';
  }

  @override
  String get jigsawFlowNoVideoTitle => 'No video';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count assets have no video - only the jpg will be written. Continue?';
  }

  @override
  String get jigsawFlowMusicNotReady => 'The music model is not ready';

  @override
  String get jigsawFlowNoMusicMissing =>
      'No themed collection is missing music';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection already has music or is Generic';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return 'A 30-second instrumental track will be generated for $count collections (ACE-Step, local).\n\n$names\n\nEach one can take a few minutes.';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count assets will be UPLOADED to the R2 bucket.\n\nThis is a publishing action that cannot be undone - the uploaded files become visible in the app.';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return 'Permanently delete $count assets (jpg + mp4 + webp + json)?';
  }

  @override
  String get jigsawFlowWebpStarted => 'Generating the missing webp files';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return '$mode collection';
  }

  @override
  String get jigsawFlowCollectionHelp =>
      'pick from the list or type a NEW name';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return 'pick from the list or type a NEW name  -  $count full collections are hidden';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total assets - next is $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'No assets in this stage.\nSend them here with ACCEPT on the \"Generated\" screen.';

  @override
  String get jigsawFlowEmpty => 'No assets in this stage.';

  @override
  String get jigsawFlowBadgeNoWebp => 'no webp';

  @override
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp) {
    return '$label\nvideo: $video   webp: $webp';
  }

  @override
  String jigsawFlowPreviewTags(Object state) {
    return 'tags: $state';
  }

  @override
  String get jigsawFlowNoVideoInSelection =>
      'None of the selected assets has a video';

  @override
  String get jigsawFlowDeleteVideo => 'Delete video';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return 'The mp4 + webp of $count assets will be deleted; the image stays and you can generate a new video.';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip => 'Delete video (the image stays)';

  @override
  String get jigsawFlowExtractNeedsOne =>
      'An outfit is extracted from a single image - select one';

  @override
  String outfitExtractStarted(Object name) {
    return '$name is being extracted to the wardrobe - Character > Wardrobe';
  }

  @override
  String get jigsawFlowMetaFile => 'File';

  @override
  String get jigsawFlowMetaTags => 'Tags';

  @override
  String get jigsawFlowMetaSubject => 'Subject';

  @override
  String get jigsawFlowMetaPolicy => 'Policy';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   webp: $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'Tags / metadata';

  @override
  String get jigsawFlowMissingWebp => 'Missing webp';

  @override
  String deliverySavedLive(Object time) {
    return 'Saved and LIVE ($time) - refreshing the counts';
  }

  @override
  String get deliveryReindexTitle => 'Re-read metadata';

  @override
  String get deliveryReindexBody =>
      'For images whose EXIF changed in the bucket. Type the file names separated by commas (e.g. 12.jpg, 340.jpg); leave it empty to re-read ALL of Generic (~1500 files, a few minutes).';

  @override
  String get deliveryReindexNames => 'File names';

  @override
  String get deliveryReindexAction => 'Read';

  @override
  String deliveryReindexed(Object count) {
    return '$count images re-read - manifests refreshed';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count images re-read, $missing not found - manifests refreshed';
  }

  @override
  String get deliveryDryRunStarted =>
      'Dry run started - it only produces a report';

  @override
  String get deliveryNormalizeStarted => 'Normalisation started';

  @override
  String get deliveryCancelRequested => 'Cancel requested';

  @override
  String get deliveryNeverSaved => 'never saved';

  @override
  String get deliveryPoolJigsaw => 'Jigsaw pool';

  @override
  String get deliveryPoolCards => 'Cards';

  @override
  String get deliveryPoolEvents => 'Events';

  @override
  String get deliveryEvent => 'Event';

  @override
  String deliverySummaryLine(
    Object pool,
    Object total,
    Object tagged,
    Object untagged,
  ) {
    return '$pool pool: $total images, $tagged tagged, $untagged untagged';
  }

  @override
  String get deliverySaveBeforeSwitch =>
      'Save your changes before switching pools.';

  @override
  String get deliveryReindexTooltip => 'Re-read metadata (if the EXIF changed)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return 'Last rule: $time  ·  served by default: $served / $total';
  }

  @override
  String get deliveryIntro =>
      'Switch OFF = images with that value leave the manifest. Saving goes live at once and now filters EVERY collection / deck; a single item the rules miss is closed with the Block list.';

  @override
  String get deliveryNormalizeTitle => 'Normalise - generate the missing tags';

  @override
  String get deliveryDryRun => 'Dry run';

  @override
  String get deliveryNormalizeNoStatus =>
      'Status unavailable - the server did not answer /api/normalize/status';

  @override
  String deliveryIndex(Object index) {
    return 'Index: $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return 'Last run: $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => 'every app (global)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'Block · $scope';
  }

  @override
  String get deliveryOpenList => 'Open the list';

  @override
  String get deliveryBlockIntro =>
      'A global block applies in EVERY app; select an app to block for that app only. Applied AFTER the rules.';

  @override
  String get deliveryBlockEmpty =>
      'Nothing to block in this pool (the bucket is empty).';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count items · $tagged/$count tagged';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count items · $tagged/$count tagged · ALL BLOCKED';
  }

  @override
  String get deliveryAppsHint => 'Apps - tap to edit that app\'s rule';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return 'Default  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      'Default rule - old versions that do not send ?app= and apps without a rule of their own';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return 'Custom rule for $app';
  }

  @override
  String get deliveryCustomRuleOn => 'Switch it off to return to the default';

  @override
  String get deliveryCustomRuleOff =>
      'Off: the default rule applies. Switching it on starts from a copy of the default.';

  @override
  String get deliveryScopeTitle => 'Only the selected collections';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total collections - newly published ones do NOT reach this app';
  }

  @override
  String get deliveryScopeOff =>
      'Off: every newly published collection also reaches this app';

  @override
  String get deliveryScopeNone =>
      'None selected - an empty list is not saved, the rule falls back to \"all\".';

  @override
  String get deliveryRulesEnabled => 'Rules enabled';

  @override
  String get deliveryRulesEnabledHint => 'Off = this rule set filters nothing';

  @override
  String get deliveryServeUntagged => 'Serve untagged images';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count images have no metadata';
  }

  @override
  String get deliveryQuick => 'Quick:';

  @override
  String deliveryOffCount(Object count) {
    return '$count off';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count values';
  }

  @override
  String get deliveryUnsaved => 'There are unsaved changes';

  @override
  String get deliveryInSync => 'Same as the server';

  @override
  String get deliverySavePublish => 'Save and publish';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonModel => 'Model';

  @override
  String get cardTplShuffled => 'Shuffled - locked axes were left alone';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank shuffled';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - to all';
  }

  @override
  String get cardTplAxisAllBack => 'Written to the card back and LOCKED.';

  @override
  String get cardTplAxisAllFront =>
      'Written to all 13 cards + 2 jokers at once and LOCKED - shuffling does not change it.';

  @override
  String get cardTplValue => 'Value';

  @override
  String get cardTplAllWritten => 'Written to all and locked';

  @override
  String cardTplRankTitle(Object rank) {
    return '$rank template';
  }

  @override
  String get cardTplLocked => 'Locked';

  @override
  String get cardTplLock => 'Lock';

  @override
  String get cardTplManual => 'Manual extra (free text)';

  @override
  String get cardTplManualHint => 'e.g. holding a golden card fan';

  @override
  String get cardTplManualHelp =>
      'Added to the end of the template - shuffling does not remove it';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank saved';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot added to the queue';
  }

  @override
  String cardTplTitle(Object title) {
    return 'Collection card - $title';
  }

  @override
  String get cardTplShuffle => 'Shuffle';

  @override
  String get cardTplNoTheme => 'No theme - tap to write one';

  @override
  String get cardTplThemeTitle => 'Theme (P1)';

  @override
  String get cardTplPresetCard => 'Preset card';

  @override
  String get cardTplTheme => 'Theme';

  @override
  String get cardTplThemeHelp => 'identity + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'The theme cannot be empty';

  @override
  String get cardTplThemeSaved => 'Theme saved';

  @override
  String cardTplModelSet(Object name) {
    return 'Model: $name';
  }

  @override
  String get cardTplFaceDetail => 'Face retouch';

  @override
  String get cardTplFaceDetailHint =>
      '+15 s per card - runs the face through a separate pass';

  @override
  String get cardTplFaceDetailOn => 'Face retouch on';

  @override
  String get cardTplFaceDetailOff => 'Face retouch off';

  @override
  String get cardTplVideoEngine => 'Video engine (first frame = last frame)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (not installed)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return 'Video engine: $name';
  }

  @override
  String get cardTplApplyToAll => 'Apply to all:';

  @override
  String get cardTplPickAxis => 'pick an axis';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (back)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count axes locked';
  }

  @override
  String get cardTplShuffleSlot => 'Shuffle this slot';

  @override
  String get cardTplGenerateSlot => 'Generate this slot';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return 'Delete $count generations and their files?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count generations deleted';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count could not be deleted';
  }

  @override
  String get galleryCharacterNeedsOne =>
      'A character is created from a single image - select one';

  @override
  String get galleryMakeCharacter => 'Make character';

  @override
  String get galleryMakeCharacterBody =>
      'The selected image becomes the base directly; the portrait, the story and the 7 directions are generated on their own - no confirmation is asked.';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name added to the queue - follow the pipeline on the Queue tab';
  }

  @override
  String get galleryCreateCharacterFirst =>
      'Create a character with \"Make character\" first';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return 'Add to candidates - $count images';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$count images added to the candidates of $name';
  }

  @override
  String get galleryCollectionNeedsOne =>
      'A single image is added to a collection - select one';

  @override
  String get galleryCreateCollectionFirst =>
      'Create a collection or a dealer in the Card pipeline first';

  @override
  String get galleryAddToCollection => 'Add to collection';

  @override
  String get galleryDealerNoRank => 'dealer (no rank)';

  @override
  String galleryPickRank(Object name) {
    return '$name - pick a rank';
  }

  @override
  String get galleryQueuedOne =>
      'Added to the queue (1 job) - follow it on the Queue tab';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count images will move to the \"Incoming\" stage of the CBN pipeline: jpg + EXIF tags. The build (SAM, line art, regions) is started there.\n\nWhich rating?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count images will move to stage 2: jpg + EXIF tags, with the video next to it if there is one.\n\nWhich rating?';
  }

  @override
  String get galleryAcceptStarted =>
      'Started - follow the progress on the \"Pipeline\" tab';

  @override
  String get galleryExtractTooltip =>
      'Extract outfit - take the outfit in the image into the wardrobe';

  @override
  String get galleryMakeCharacterTooltip =>
      'Make character - create a new character';

  @override
  String get galleryAddToCandidatesTooltip =>
      'Add to candidates - copy to an existing character';

  @override
  String get galleryAddToCollectionTooltip => 'Add to collection - pick a rank';

  @override
  String get galleryAcceptTooltip => 'Accept - send to stage 2';

  @override
  String get galleryDeleteSelected => 'Delete the selected';

  @override
  String get galleryFilterImage => 'Image';

  @override
  String get galleryFilterVideo => 'Video';

  @override
  String get galleryFilterFavorite => 'Favorite';

  @override
  String galleryQueuedAt(Object position) {
    return 'queued $position';
  }

  @override
  String get galleryEmpty => 'Nothing generated yet';

  @override
  String get galleryEmptyHint => 'You can start from the Generate tab';

  @override
  String get galleryDeleteOneConfirm => 'Delete this generation and its file?';

  @override
  String get galleryAcceptOneCbn =>
      'It will move to the \"Incoming\" stage of the CBN pipeline (jpg + EXIF tags).\n\nWhich rating?';

  @override
  String get galleryAcceptOneJigsaw =>
      'It will move to stage 2 (jpg + EXIF tags).\n\nWhich rating?';

  @override
  String get galleryAccepted =>
      'Accepted - being tagged, follow it on the \"Pipeline\" tab';

  @override
  String get galleryRejected => 'Rejected';

  @override
  String get galleryEditBody =>
      'This image becomes the source; the edit engine (Qwen Image Edit, keeps the identity) starts a new generation. What should change?';

  @override
  String get galleryEditPromptLabel => 'Extra prompt';

  @override
  String get galleryEditPromptHint =>
      'e.g. change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued =>
      'Edit added to the queue - the result shows up in Generated';

  @override
  String get galleryEditTooltip =>
      'Edit - a new generation with the edit engine';

  @override
  String galleryPoolInfo(Object name) {
    return 'pool $name';
  }

  @override
  String get genPromptUnchanged =>
      'The prompt did not change (the local LLM did not answer)';

  @override
  String get genPromptWritten => 'Prompt written';

  @override
  String get commonUndo => 'Undo';

  @override
  String get genVariantFailed =>
      'No variant could be produced (the local LLM did not answer)';

  @override
  String get genPickVariant => 'Pick a variant';

  @override
  String get genEnrich => 'Enrich';

  @override
  String get genFix => 'Fix';

  @override
  String get genVariant => 'Variant';

  @override
  String get genFileUnreadable => 'The file could not be read';

  @override
  String get genPromptEmpty => 'The prompt cannot be empty';

  @override
  String genMissingInputs(Object inputs) {
    return 'Missing input: $inputs';
  }

  @override
  String get genNeedsImagePick =>
      'This task needs an input image - pick one of the generated ones';

  @override
  String get genNeedsImage => 'This task needs an input image';

  @override
  String genQueuedCount(Object count) {
    return '$count jobs added to the queue';
  }

  @override
  String get genQueued => 'Added to the queue';

  @override
  String genQueueBadge(Object count) {
    return '$count queued';
  }

  @override
  String get genComfyOffBody =>
      'ComfyUI is off. Jobs enter the queue but do not start - it has to be started on the computer.';

  @override
  String get genTask => 'Task';

  @override
  String get genWorkflowInputs => 'Workflow inputs';

  @override
  String get genInputImage => 'Input image';

  @override
  String get genPositive1 => 'Positive prompt 1 - subject';

  @override
  String get genPositive1Hint => 'e.g. police officer';

  @override
  String get genPositive2 => 'Positive prompt 2 - template';

  @override
  String genPositive2Help(Object marker) {
    return '$marker is replaced by the first prompt. May be left empty.';
  }

  @override
  String get genFinalPrompt => 'Prompt to be sent';

  @override
  String get genNegative => 'Negative prompt';

  @override
  String get genTurboHint => 'fast mode';

  @override
  String genDurationSeconds(Object seconds) {
    return 'Duration: $seconds seconds';
  }

  @override
  String genCount(Object count) {
    return 'Count: $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'Size: $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'Size: $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'ADD TO QUEUE';

  @override
  String get genFootnote =>
      'Jobs are generated one after another. You can follow them on the Queue tab.';

  @override
  String get genDetailsTitle =>
      'Details - may be left empty, locked ones are not shuffled';

  @override
  String genRandomGenerate(Object count) {
    return 'Generate random  $count';
  }

  @override
  String get genLockedTooltip => 'locked - stays fixed when shuffling';

  @override
  String get genOptionsEmpty => 'The option list is empty';

  @override
  String get genOptional => 'optional';

  @override
  String get genUploading => 'uploading...';

  @override
  String get genNotSelected => 'not selected';

  @override
  String get genFromGallery => 'From gallery';

  @override
  String get genFromFile => 'From file';

  @override
  String get genNoSource =>
      'No generation can be used as input. Generate an image first.';

  @override
  String genPickerTitle(Object slot) {
    return '$slot - pick from Generated';
  }

  @override
  String get genPickerSearch => 'search in prompts';

  @override
  String get genPickerEmpty => 'No finished generation of this kind.';

  @override
  String optionsFileMissing(Object items) {
    return 'Missing in the options file: $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (no field definitions)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'The options file could not be read: $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return 'The $name options file could not be read: $error';
  }

  @override
  String get fieldLocation => 'Location';

  @override
  String get fieldEra => 'Era / aesthetic';

  @override
  String get fieldWeather => 'Weather';

  @override
  String get fieldWeatherLight => 'Weather / light';

  @override
  String get fieldJob => 'Job';

  @override
  String get fieldFantasy => 'Fantasy';

  @override
  String get fieldOutfitColor => 'Outfit colour';

  @override
  String get fieldOutfit => 'Outfit';

  @override
  String get fieldHair => 'Hair';

  @override
  String get fieldHairColor => 'Hair colour';

  @override
  String get fieldHairstyle => 'Hairstyle';

  @override
  String get fieldEyes => 'Eyes';

  @override
  String get fieldRace => 'Race';

  @override
  String get fieldExpression => 'Expression';

  @override
  String get fieldPose => 'Pose';

  @override
  String get fieldAngle => 'Angle';

  @override
  String get fieldStyle => 'Style';

  @override
  String get fieldMood => 'Mood';

  @override
  String get fieldColor => 'Colour';

  @override
  String get fieldCreature => 'Creature';

  @override
  String get fieldClass => 'Class';

  @override
  String get fieldAge => 'Age';

  @override
  String get fieldOrigin => 'Origin';

  @override
  String get fieldBody => 'Body';

  @override
  String get fieldSkin => 'Skin';

  @override
  String get fieldFace => 'Face';

  @override
  String get fieldGesture => 'Gesture';

  @override
  String get cardNotReady => 'The server endpoint is not ready yet';

  @override
  String get cardKindNormal => 'Normal';

  @override
  String get cardKindDealer => 'Dealer';

  @override
  String get cardStagePushed => 'pushed';

  @override
  String get cardStageWebp => 'webp ready';

  @override
  String get cardStageVideo => 'video ready';

  @override
  String get cardStageStill => 'still ready';

  @override
  String get cardStageEmpty => 'empty';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (check)';
  }

  @override
  String get cardVideoIntro =>
      'First frame = last frame (loop). The camera stays locked - framing, scale and background do not change. The output goes to the POOL first; if you pick a tag it is assigned there as well.';

  @override
  String get cardVideoTemplate => 'Template (fills the text)';

  @override
  String get cardVideoMotion => 'Motion sentence (the prompt that is sent)';

  @override
  String get cardVideoMotionHelp =>
      'Describe a visible motion; it should return to the starting pose at the end';

  @override
  String get cardVideoAssignTag => 'Assign to tag';

  @override
  String get cardVideoPoolOnly => '(pool only - I will assign it later)';

  @override
  String get cardVideoNewTag => 'New tag...';

  @override
  String get cardVideoNewTagName => 'New tag name';

  @override
  String get cardTagHint => 'e.g. victory';

  @override
  String get cardGestureTitle => 'Animation - pick a gesture';

  @override
  String get cardGestureIntro =>
      'MiniMax H3: idle 6 s, victory 2 s. The camera stays locked - framing, scale and background do not change.';

  @override
  String get cardGestureCustom => 'Custom motion';

  @override
  String get cardGestureCustomHint => 'e.g. a slight hip sway, feet fixed';

  @override
  String get cardGestureCustomHelp =>
      'A short motion sentence - the camera stays locked';

  @override
  String get cardCutTitle => '3 WebP - cut mode';

  @override
  String get cardCutHybrid => 'Old green Grok masters - chroma + SAM together';

  @override
  String get cardCutSam => 'Default - SAM3 only, plain light grey background';

  @override
  String get cardCutAction => 'Cut';

  @override
  String cardEditTitle(Object name) {
    return 'Edit - $name';
  }

  @override
  String get cardEditSentence => 'Correction sentence';

  @override
  String get cardEditSentenceHint =>
      'e.g. shorten her hair / remove the gloves';

  @override
  String get cardEditBody =>
      'The accepted still is edited with this sentence; identity, pose and background are kept. The new image is accepted automatically.';

  @override
  String get cardEditUnrestricted => 'Unrestricted edit (NSFW LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Switch on if Qwen refuses - MCNL LoRA, 20 steps, a little slower';

  @override
  String cardQueuedJobs(Object count) {
    return 'Added to the queue ($count jobs) - follow it on the Queue tab';
  }

  @override
  String get cardQueued => 'Added to the queue - follow it on the Queue tab';

  @override
  String cardQueuedOp(Object op) {
    return 'Added to the queue (op $op) - follow it on the Queue tab';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - coming soon';
  }

  @override
  String get cardSoonBody =>
      'The card endpoints on the server are not open yet. This screen starts working on its own once they are.';

  @override
  String get cardNewCollection => 'New collection';

  @override
  String get cardIdLabel => 'Identifier (id)';

  @override
  String get cardIdHintCollection => 'e.g. police_royale';

  @override
  String get commonName => 'Name';

  @override
  String get cardNameHintCollection => 'e.g. Police Royale';

  @override
  String get cardPickPreset => 'Pick a preset card (optional)';

  @override
  String get cardThemeHint =>
      'e.g. sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      'Formula: identity + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'Jokers (2)';

  @override
  String get cardJokersHint => '15 ranks instead of 13';

  @override
  String get cardNewCollectionNote =>
      'One still per rank enters the queue (skin / hair / outfit / pose rotation). No confirmation is asked - fine-tune with ✎ / ↻.';

  @override
  String get cardIdNameRequired =>
      'The identifier and the name cannot be empty';

  @override
  String get cardNewDealer => 'New dealer';

  @override
  String get cardIdHintDealer => 'e.g. scarlett';

  @override
  String get cardNameHintDealer => 'e.g. Scarlett';

  @override
  String get cardDealerTheme => 'Theme / outfit';

  @override
  String get cardDealerThemeHint =>
      'e.g. casino vest and bow tie, noir red dress';

  @override
  String get cardDealerNote =>
      'The dealer is generated in a waist-up frame (hands on the table, looking at the camera). There is no rank - the single item goes through the four stages.';

  @override
  String get cardNightPickGesture => 'Night mode - pick a gesture';

  @override
  String get cardNightMode => 'Night mode';

  @override
  String cardNightBody(Object gesture) {
    return 'All cards AND dealers are re-animated: current still -> LTX-2.5 i2v ($gesture) -> SAM cut -> sheet.\n\nIt takes long and everything enters the queue. NO push is done.';
  }

  @override
  String get cardRestillTitle => 'Turn backgrounds grey';

  @override
  String get cardRestillBody =>
      'The still background of all cards AND dealers is turned plain light grey (the woman stays as she is). The original is kept as still_green.png; ones that are already grey are skipped.\n\nNo video is generated.';

  @override
  String get cardManifestPreview => 'Manifest preview';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return '$collections collections, $dealers dealers';
  }

  @override
  String get cardManifestNote =>
      'The manifest file is written during PUSH (files first, then the manifest). This is only a preview.';

  @override
  String get cardCollectionCardSettings => 'Collection card (settings)';

  @override
  String get cardCollectionCardSettingsHint =>
      'theme, 16 slots, model, face retouch';

  @override
  String get cardReanimate => 'Re-animate';

  @override
  String get cardReanimateHint => 'still -> i2v -> cut (this collection)';

  @override
  String get cardRealify => 'Anime -> realistic (collection)';

  @override
  String get cardRealifyHint =>
      'every still becomes a realistic photo with edit_qwen';

  @override
  String get cardDeleteCollection => 'Delete collection';

  @override
  String get cardDeleteCollectionHint =>
      'the folder is deleted with all its cards - cannot be undone';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'Delete collection - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'Delete dealer - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'The collection folder is deleted with all its files.\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.';

  @override
  String get cardDeleteDealerBody =>
      'The dealer folder is deleted with all its files.\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.';

  @override
  String cardDeletedNamed(Object name) {
    return '$name deleted';
  }

  @override
  String get cardDealerCardSettings => 'Dealer card (settings)';

  @override
  String get cardDealerCardSettingsHint =>
      'theme, template, model, face retouch';

  @override
  String get cardDeleteDealer => 'Delete dealer';

  @override
  String get cardDeleteDealerHint =>
      'the folder is deleted with all its files - cannot be undone';

  @override
  String get cardFlowTitle => 'Card pipeline';

  @override
  String get cardBulkActions => 'Bulk actions';

  @override
  String get cardNightMenu => 'Night mode: re-animate everything';

  @override
  String get cardRestillMenu => 'Turn backgrounds grey (all)';

  @override
  String get cardManifestMenu => 'Preview manifest';

  @override
  String get cardDealers => 'Dealers';

  @override
  String get cardEmptyCollections =>
      'No collection yet.\n\nGive an identifier, a name and a theme with \"+ New collection\" - one still per rank enters the queue for 13 (or 15) ranks, then come the 2 Video and 3 WebP stages.';

  @override
  String get cardEmptyDealers =>
      'No dealer yet.\n\nGive a name, a theme and a gesture with \"+ New dealer\" - a single item is generated in a waist-up frame and goes through the four stages.';

  @override
  String cardGestureLine(Object gesture) {
    return 'gesture: $gesture';
  }

  @override
  String cardAnimateTitle(Object count) {
    return '2 Video ($count cards)';
  }

  @override
  String cardAnimateBody(Object total) {
    return 'Two animations are generated for each card and assigned to their tags:\n• idle - 6 s, one controlled gesture\n• victory - 2 s, a short cheer inside the frame\n$total videos in total; the old ones stay in the pool.';
  }

  @override
  String get cardEditNeedsOne =>
      'Editing is for a single rank - select one card';

  @override
  String cardPushTitle(Object name) {
    return 'Push - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'The sheet and thumb files are uploaded to R2 (cards), then the manifest is written. Right now the webp of $ready/$total ranks is ready.\n\nThis is a PUBLISHING action and CANNOT BE UNDONE.';
  }

  @override
  String get cardPushQueued =>
      'Push added to the queue - follow it on the Queue tab';

  @override
  String get cardCollectionCardTooltip =>
      'Collection card - theme, 16 slots, model, face retouch';

  @override
  String get commonMore => 'More';

  @override
  String get cardNoThemeTap => 'No theme - tap: Collection card';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nCollection card: tap (theme, 16 slots, model, face retouch)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'The collection folder is deleted with all its cards ($stills stills).\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'The collection folder is deleted with all its cards ($stills stills, $pushed pushed).\n\nCANNOT BE UNDONE. Files already pushed to R2 stay in the bucket.';
  }

  @override
  String get cardClearCards => 'Clear cards';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - still, candidates, video and webp are deleted; the rank stays empty (generate it again with \"1 Still\").';
  }

  @override
  String cardsCleared(Object count) {
    return '$count cards cleared';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count cards could not be cleared';
  }

  @override
  String get cardGenerateStill => 'Generate 1 Still';

  @override
  String get cardGenerateVideo => 'Generate 2 Video';

  @override
  String get cardGenerateWebp => 'Generate 3 WebP';

  @override
  String get cardBackUpper => 'BACK';

  @override
  String cardAssetVideo(Object tag) {
    return 'Video ($tag)';
  }

  @override
  String cardAssetSheet(Object tag) {
    return 'WebP / cut ($tag)';
  }

  @override
  String cardAssetMissing(Object asset) {
    return 'No $asset';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return 'Delete $asset?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'Only the video of this tag is deleted; the copy in the pool, the still and the webp stay.';

  @override
  String get cardAssetDeleteSheetBody =>
      'Only sheet.webp, the thumb and the cut frames are deleted; the video and the still stay.';

  @override
  String get cardAssetDeleteStillBody =>
      'Only the selected still is deleted; the candidates, the video and the webp stay.';

  @override
  String get cardPoolDelete => 'Delete from the pool';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id is deleted from the pool. Copies assigned to tags ($tags) stay.';
  }

  @override
  String get cardNone => 'none';

  @override
  String get cardNewAnimTag => 'New animation tag';

  @override
  String get cardNewAnimTagHelp =>
      'The game reads it by this name (idle, wink, victory ...)';

  @override
  String get cardUnassigned => 'not assigned';

  @override
  String cardAssignedTo(Object tags) {
    return 'assigned: $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return 'Assign: $name';
  }

  @override
  String get cardAssignNewTag => 'Assign to a new tag...';

  @override
  String get cardAnimReady => 'video + webp ready';

  @override
  String get cardAnimVideoOnly => 'has video, no webp';

  @override
  String get cardPoolEmpty => 'No video in the pool - run \"2 Video\" first';

  @override
  String get cardDeleteVideoKeepTag => 'Delete the video (the tag stays)';

  @override
  String get cardDeleteSheet => 'Delete WebP / cut';

  @override
  String get cardDeleteTag => 'Delete the tag (with its video + webp)';

  @override
  String cardVideosHeader(Object count) {
    return 'Videos ($count) - tap = assign / preview / delete';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return 'The folder of $name is deleted with all its files. CANNOT BE UNDONE.';
  }

  @override
  String get cardClearCard => 'Clear card';

  @override
  String cardClearCardBody(Object name) {
    return '$name: still, candidates, video, webp and animations are deleted; the rank stays empty (generate it again with \"1 Still\").';
  }

  @override
  String get cardClearCardTooltip => 'Clear card (the rank becomes empty)';

  @override
  String get cardViewCut => 'Cut';

  @override
  String cardDeleteThisVideo(Object tag) {
    return 'Delete this video ($tag)';
  }

  @override
  String cardDeleteSheetTag(Object tag) {
    return 'Delete WebP / cut ($tag)';
  }

  @override
  String get cardDeleteStill => 'Delete the still';

  @override
  String get cardNoVideo => 'No video - generate it with \"2 Video\"';

  @override
  String get cardNoCut => 'No cut - generate it with \"3 WebP\"';

  @override
  String get cardCutFrameFailed => 'The cut frame could not be read';

  @override
  String get cardNoStill => 'No still - generate it with \"1 Still\"';

  @override
  String get cardStillFailed => 'The still could not be read';

  @override
  String cardPromptTitleAge(Object age) {
    return 'Prompt  ·  age $age';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - frame drift / zoom / broken mask. Generate the video or the cut again.';

  @override
  String get cardAnimsHeader =>
      'Animations - tap = select, long press = assign / delete';

  @override
  String cardAnimOpened(Object tag) {
    return '\"$tag\" opened - generate it with 2 Video or assign from the pool';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return 'Pick a video from the pool for \"$tag\"';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return 'Candidates ($count) - tap = select';
  }

  @override
  String get cardCandidatePicked => 'The candidate is now the selected still';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step: $error';
  }
}

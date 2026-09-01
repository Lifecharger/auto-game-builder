import '../l10n/app_localizations.dart';

/// Localized display labels for values that travel over the wire as stable
/// English identifiers (app status, brainstorm genre, code-check option).
/// The identifier stays English everywhere it is sent to the server; only the
/// label the user reads is translated.

String appStatusLabel(AppLocalizations l10n, String status) {
  switch (status.toLowerCase()) {
    case 'idle':
      return l10n.appStatusIdle;
    case 'queued':
      return l10n.appStatusQueued;
    case 'building':
      return l10n.appStatusBuilding;
    case 'uploading':
      return l10n.appStatusUploading;
    case 'working':
      return l10n.appStatusWorking;
    case 'fixing':
      return l10n.appStatusFixing;
    case 'deploying':
      return l10n.appStatusDeploying;
    case 'error':
      return l10n.appStatusError;
    case 'published':
      return l10n.appStatusPublished;
    default:
      return status;
  }
}

String genreLabel(AppLocalizations l10n, String genre) {
  switch (genre) {
    case '':
      return l10n.genreAny;
    case 'Puzzle':
      return l10n.genrePuzzle;
    case 'Idle/Clicker':
      return l10n.genreIdleClicker;
    case 'RPG':
      return l10n.genreRpg;
    case 'Action':
      return l10n.genreAction;
    case 'Strategy':
      return l10n.genreStrategy;
    case 'Simulation':
      return l10n.genreSimulation;
    case 'Arcade':
      return l10n.genreArcade;
    case 'Card Game':
      return l10n.genreCardGame;
    case 'Tower Defense':
      return l10n.genreTowerDefense;
    default:
      return genre;
  }
}

String codeCheckLabel(AppLocalizations l10n, String check) {
  switch (check) {
    case 'Bugs & crashes':
      return l10n.checkBugsCrashes;
    case 'Security vulnerabilities':
      return l10n.checkSecurityVulnerabilities;
    case 'Performance issues':
      return l10n.checkPerformanceIssues;
    case 'Code style':
      return l10n.checkCodeStyle;
    case 'Dead code':
      return l10n.checkDeadCode;
    case 'Error handling':
      return l10n.checkErrorHandling;
    case 'Memory leaks':
      return l10n.checkMemoryLeaks;
    default:
      return check;
  }
}

String ideaCategoryLabel(AppLocalizations l10n, String category) {
  switch (category) {
    case 'UI/UX':
      return l10n.categoryUiUx;
    case 'Performance':
      return l10n.categoryPerformance;
    case 'Features':
      return l10n.categoryFeatures;
    case 'Security':
      return l10n.categorySecurity;
    case 'Monetization':
      return l10n.categoryMonetization;
    case 'Accessibility':
      return l10n.categoryAccessibility;
    default:
      return category;
  }
}

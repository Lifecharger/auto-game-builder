// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get about => 'Über';

  @override
  String get aboutApp => 'App';

  @override
  String actionTriggered(Object action) {
    return '$action ausgelöst';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String agentLabelWith(Object agent) {
    return 'Agent: $agent';
  }

  @override
  String get agentLocal => 'Lokal';

  @override
  String get agentNone => 'Keiner';

  @override
  String get agentRunsOnServer =>
      'Agent läuft auf dem Server mit projektweitem Zugriff';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return '$agent-KI ausgelöst für \"$title\"';
  }

  @override
  String get aiAgent => 'KI-Agent';

  @override
  String get aiAgentUpdated => 'KI-Agent aktualisiert';

  @override
  String get aiResponse => 'KI-Antwort';

  @override
  String get allApps => 'Alle Apps';

  @override
  String get allAppsCompletedOrPostponed =>
      'Alle Apps sind abgeschlossen oder zurückgestellt';

  @override
  String get allAppsHaveAutomations =>
      'Alle Apps haben bereits Automatisierungen';

  @override
  String get allAppsHint => 'Alle Apps';

  @override
  String get allPendingBlocked =>
      'Alle ausstehenden Einträge sind durch Abhängigkeiten blockiert';

  @override
  String get apiConnection => 'API-Verbindung';

  @override
  String get apiUrlSaved => 'API-URL gespeichert';

  @override
  String get appCreated => 'App erstellt!';

  @override
  String get appDetail => 'App-Details';

  @override
  String get appFallback => 'App';

  @override
  String get appNameHint => 'App-Name (z. B. Mein Spiel)';

  @override
  String get appStatusBuilding => 'baut';

  @override
  String get appStatusDeploying => 'verteilt';

  @override
  String get appStatusError => 'fehler';

  @override
  String get appStatusFixing => 'behebt';

  @override
  String get appStatusIdle => 'inaktiv';

  @override
  String get appStatusPublished => 'veröffentlicht';

  @override
  String get appStatusQueued => 'wartend';

  @override
  String get appStatusUploading => 'lädt hoch';

  @override
  String get appStatusWorking => 'arbeitet';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc =>
      'Mobile/Desktop-App mit Google-Play-Deploy-Unterstützung';

  @override
  String get appTypeGodotDesc =>
      'Spielprojekt mit Export-Zielen (Windows, Android, Web)';

  @override
  String get appTypePhaserDesc =>
      'Phaser-3 + TypeScript-Spiel, verpackt als Android-AAB via Capacitor';

  @override
  String get appTypePythonDesc =>
      'Python-Projekt mit Skript-Runner und pip-Verwaltung';

  @override
  String get appTypeWebDesc =>
      'Web-App mit Unterstützung für statisches Hosting-Deploy';

  @override
  String get apps => 'Apps';

  @override
  String get archivedLabel => 'archiviert';

  @override
  String get artAndAssets => 'Grafik & Assets';

  @override
  String get artBible => 'Grafik-Bibel';

  @override
  String get artBibleCardSubtitle => 'Ankerdokument für visuelle Identität';

  @override
  String get artBibleHint =>
      'Identitätsaussage, Palette (Hex), Typografie, Verbote, technische Vorgaben...';

  @override
  String get artBibleSaved => 'Grafik-Bibel gespeichert';

  @override
  String get artBibleShort => 'Grafik-Bibel';

  @override
  String get artBibleSubtitle =>
      'Anker der visuellen Identität – Palette, Typografie, Stilverbote. Jede Asset-Aufgabe bezieht sich darauf.';

  @override
  String get artBibleTaskCreated => 'Aufgabe für Grafik-Bibel erstellt';

  @override
  String artBibleTitle(Object app) {
    return 'Grafik-Bibel - $app';
  }

  @override
  String get askAQuestionHint => 'Stelle eine Frage...';

  @override
  String get askAgent => 'Agent fragen';

  @override
  String get askAnythingAboutYourApps => 'Frag alles zu deinen Apps';

  @override
  String get assetAudit => 'Asset-Audit';

  @override
  String get assetAuditSubtitle => 'Defekte Referenzen, Waisen, Platzhalter';

  @override
  String get assetAuditTaskCreated => 'Asset-Audit-Aufgabe erstellt';

  @override
  String get assetSpecTaskCreated => 'Asset-Spezifikations-Aufgabe erstellt';

  @override
  String get assetSpecs => 'Asset-Spezifikationen';

  @override
  String get assetSpecsSubtitle => 'Prompts pro Asset aus der Bibel';

  @override
  String get attachments => 'Anhänge';

  @override
  String attachmentsCount(Object count) {
    return 'Anhänge ($count)';
  }

  @override
  String get automationCreated => 'Automatisierung erstellt';

  @override
  String get automationStateStarted => 'gestartet';

  @override
  String get automationStateStopped => 'gestoppt';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => 'Automatisierung aktualisiert';

  @override
  String get back => 'Zurück';

  @override
  String get backend => 'Backend';

  @override
  String get balanceCheck => 'Balance-Check';

  @override
  String get balanceCheckSubtitle => 'Wirtschaft, Progression, Belohnungen';

  @override
  String get balanceCheckTaskCreated => 'Balance-Check-Aufgabe erstellt';

  @override
  String batchRunError(Object error) {
    return 'Fehler beim Stapellauf: $error';
  }

  @override
  String blockedByList(Object ids) {
    return 'blockiert durch $ids';
  }

  @override
  String blockedByTask(Object id) {
    return 'Blockiert durch #$id';
  }

  @override
  String blockedCountLabel(Object count) {
    return '$count blockiert';
  }

  @override
  String blockerNotInList(Object id) {
    return 'Aufgabe #$id ist nicht in der aktuellen Liste (archiviert oder gelöscht)';
  }

  @override
  String get brainstormAndCreate => 'Brainstorming & Erstellen';

  @override
  String get brainstormConceptHint =>
      'Konzeptidee (z. B. \"Idle-Spiel mit Ameisenkolonie\", \"Puzzle mit Schwerkraft\")';

  @override
  String get brainstormCreated => 'Projekt mit Brainstorming-Aufgabe erstellt!';

  @override
  String get brainstormDesc =>
      'Erstellt ein neues Projekt mit einer Brainstorming-Aufgabe. Beim Ausführen generiert die KI ein vollständiges GDD und erste Aufgaben.';

  @override
  String get brainstormNameHint =>
      'Projektname (optional – KI kann vorschlagen)';

  @override
  String get brainstormNewGame => 'Neues Spiel brainstormen';

  @override
  String get build => 'Build';

  @override
  String get buildAndDeploy => 'Build & Deploy';

  @override
  String get buildCancelled => 'Build abgebrochen';

  @override
  String get buildFailedLabel => 'build fehlgeschlagen';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'Build-Abfrage nach 30 Minuten abgelaufen - Server-Logs prüfen';

  @override
  String get buildTarget => 'Build-Ziel';

  @override
  String get builds => 'Builds';

  @override
  String builtCount(Object count) {
    return 'Gebaut ($count)';
  }

  @override
  String get buyMeACoffee => 'Spendier mir einen Kaffee';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'Spendier mir einen Kaffee  $price';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get cannotReachServer => 'Server nicht erreichbar';

  @override
  String cannotReachServerWith(Object error) {
    return 'Server nicht erreichbar: $error';
  }

  @override
  String get cannotSaveEmptyArtBible =>
      'Leere Grafik-Bibel kann nicht gespeichert werden';

  @override
  String get cannotSaveEmptyClaudeMd =>
      'Leere CLAUDE.md kann nicht gespeichert werden';

  @override
  String get cannotSaveEmptyDesignDoc =>
      'Leeres Design-Dokument kann nicht gespeichert werden';

  @override
  String get catBugsCrashes => 'Bugs & Abstürze';

  @override
  String get catCodeStyle => 'Codestil';

  @override
  String get catDeadCode => 'Toter Code';

  @override
  String get catErrorHandling => 'Fehlerbehandlung';

  @override
  String get catMemory => 'Speicher';

  @override
  String get categoryAccessibility => 'Barrierefreiheit';

  @override
  String get categoryBug => 'Bug';

  @override
  String get categoryFeatures => 'Features';

  @override
  String get categoryMonetization => 'Monetarisierung';

  @override
  String get categoryOther => 'Sonstiges';

  @override
  String get categoryPerformance => 'Leistung';

  @override
  String get categorySecurity => 'Sicherheit';

  @override
  String get categorySuggestion => 'Vorschlag';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count Zeichen';
  }

  @override
  String get chatHistory => 'Chatverlauf';

  @override
  String get chatLogs => 'Berichte';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count Nachrichten • $date';
  }

  @override
  String get checkBugsCrashes => 'Bugs & Abstürze';

  @override
  String get checkCodeStyle => 'Codestil';

  @override
  String get checkDeadCode => 'Toter Code';

  @override
  String get checkErrorHandling => 'Fehlerbehandlung';

  @override
  String get checkMemoryLeaks => 'Speicherlecks';

  @override
  String get checkPerformanceIssues => 'Leistungsprobleme';

  @override
  String get checkSecurityVulnerabilities => 'Sicherheitslücken';

  @override
  String get checksToRun => 'Auszuführende Checks:';

  @override
  String get claudeMdHint => 'Projektkonventionen, Build-Befehle, Regeln...';

  @override
  String get claudeMdSaved => 'CLAUDE.md gespeichert';

  @override
  String get claudeMdSubtitle =>
      'Projektanweisungen für KI-Agenten, die an dieser App arbeiten.';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'Leeren';

  @override
  String get clearFilters => 'Filter zurücksetzen';

  @override
  String get clearMessages => 'Nachrichten löschen';

  @override
  String clearMessagesConfirm(Object count) {
    return 'Alle $count Nachrichten in diesem Chat löschen?';
  }

  @override
  String get close => 'Schließen';

  @override
  String get codeCheck => 'Code-Check';

  @override
  String get codeCheckBody =>
      'Dies erstellt eine Aufgabe für den KI-Agenten, deinen Code zu prüfen und Befunde als Issues zu melden.';

  @override
  String get codeCheckRequested => 'Code-Check angefordert';

  @override
  String get codeCheckResults => 'Ergebnisse des Code-Checks';

  @override
  String get codeReview => 'Code-Review';

  @override
  String get codeReviewSubtitle => 'Bugs, Abstürze, Codequalität';

  @override
  String get complete => 'Abschließen';

  @override
  String completedCount(Object count) {
    return 'Abgeschlossen ($count)';
  }

  @override
  String get connectToYourServer => 'Mit deinem Server verbinden';

  @override
  String get connectYourPhone => 'Verbinde dein Telefon';

  @override
  String get connectedSuccessfully => 'Erfolgreich verbunden';

  @override
  String connectedTo(Object server) {
    return 'Verbunden mit $server';
  }

  @override
  String get connecting => 'Verbinde...';

  @override
  String get connectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get connectionSuccessful => 'Verbindung erfolgreich!';

  @override
  String get connectionTimedOut => 'Verbindung zeitüberschritten';

  @override
  String get consistencyCheck => 'Konsistenzprüfung';

  @override
  String get consistencyCheckSubtitle => 'GDD ↔ Code ↔ Daten-Drift';

  @override
  String get consistencyCheckTaskCreated =>
      'Aufgabe für Konsistenzprüfung erstellt';

  @override
  String get console => 'Konsole';

  @override
  String get contentAudit => 'Content-Audit';

  @override
  String get contentAuditSubtitle => 'Level, Charaktere, Items, Texte';

  @override
  String get contentAuditTaskCreated => 'Content-Audit-Aufgabe erstellt';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get control => 'Steuerung';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label in die Zwischenablage kopiert';
  }

  @override
  String get copy => 'Kopieren';

  @override
  String get copyAiResponse => 'KI-Antwort kopieren';

  @override
  String get copyDescription => 'Beschreibung kopieren';

  @override
  String get copyTitle => 'Titel kopieren';

  @override
  String get copyUrl => 'URL kopieren';

  @override
  String get couldNotDownloadPdf => 'PDF konnte nicht heruntergeladen werden';

  @override
  String get couldNotLoadBuildTargets =>
      'Build-Ziele konnten nicht geladen werden';

  @override
  String get couldNotLoadDirectives =>
      'Direktiven konnten nicht geladen werden';

  @override
  String get couldNotOpenLink => 'Link konnte nicht geöffnet werden';

  @override
  String couldNotOpenPdf(Object error) {
    return 'PDF konnte nicht geöffnet werden: $error';
  }

  @override
  String get couldNotOpenPicker => 'Auswahl konnte nicht geöffnet werden.';

  @override
  String get create => 'Erstellen';

  @override
  String get createApp => 'App erstellen';

  @override
  String get createFirstApp => 'Erstelle deine erste App, um loszulegen';

  @override
  String get createIssue => 'Issue erstellen';

  @override
  String createdAgo(Object time) {
    return 'erstellt $time';
  }

  @override
  String get creating => 'Wird erstellt...';

  @override
  String criticalCount(Object count) {
    return '$count kritisch';
  }

  @override
  String get customAutomationPromptHint => 'Eigener Automatisierungs-Prompt...';

  @override
  String get customPrompt => 'Eigener Prompt';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteAutomation => 'Automatisierung löschen';

  @override
  String deleteAutomationConfirm(Object app) {
    return 'Automatisierung für $app entfernen?';
  }

  @override
  String get deleteChat => 'Chat löschen';

  @override
  String get deleteChatConfirm => 'Diese Unterhaltung löschen?';

  @override
  String deleteConfirmTitled(Object title) {
    return '\"$title\" löschen?\nDies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteFailed => 'Löschen fehlgeschlagen';

  @override
  String get deleteReportBody =>
      'Dies entfernt den Bericht und seine Screenshots dauerhaft.';

  @override
  String get deleteReportTitle => 'Bericht löschen?';

  @override
  String get deleted => 'Gelöscht';

  @override
  String get dependsOn => 'Abhängig von';

  @override
  String get deploy => 'Deploy';

  @override
  String get deployToProduction => 'In Produktion bereitstellen';

  @override
  String get deployToProductionBody =>
      'Dies baut die App und veröffentlicht sie für ALLE Nutzer auf Google Play.\n\nStelle sicher, dass du zuvor auf Internal/Beta getestet hast.';

  @override
  String get deployToProductionTitle => 'In Produktion bereitstellen?';

  @override
  String get descriptionHint => 'Beschreibung...';

  @override
  String get designDoc => 'Design-Dokument';

  @override
  String get designDocHint => 'Beschreibe deine App-Vision, Features, Ziele...';

  @override
  String get designDocSaved => 'Design-Dokument gespeichert';

  @override
  String get designDocShort => 'Design-Dokument';

  @override
  String get designDocSubtitle =>
      'Die KI nutzt dies als Kontext für alle Arbeiten an dieser App.';

  @override
  String designDocTitle(Object app) {
    return 'Design-Dokument - $app';
  }

  @override
  String get designDocument => 'Design-Dokument';

  @override
  String get designReview => 'Design-Review';

  @override
  String get designReviewSubtitle => 'GDD, Mechaniken, UX-Audit';

  @override
  String get designReviewTaskCreated => 'Design-Review-Aufgabe erstellt';

  @override
  String get details => 'Details';

  @override
  String get detectingServer => 'Server wird erkannt...';

  @override
  String get developer => 'Entwickler';

  @override
  String get directServerUrlLan => 'Direkte Server-URL (LAN)';

  @override
  String get directiveHistory => 'Direktiven-Verlauf';

  @override
  String get dismiss => 'Verwerfen';

  @override
  String get display => 'Anzeige';

  @override
  String get doIt => 'Los geht\'s';

  @override
  String get done => 'Fertig';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total erledigt';
  }

  @override
  String durationLabelWith(Object seconds) {
    return 'Dauer: ${seconds}s';
  }

  @override
  String get edit => 'Bearbeiten';

  @override
  String editNamed(Object label) {
    return '$label bearbeiten';
  }

  @override
  String editTitleNamed(Object app) {
    return 'Bearbeiten: $app';
  }

  @override
  String get editWorkerUrl => 'Worker-URL bearbeiten';

  @override
  String get engine => 'Engine';

  @override
  String engineChanged(Object previous, Object current) {
    return 'Engine geändert: $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'Engine bestätigt: $engine';
  }

  @override
  String get engineDetectionFailed => 'Engine-Erkennung fehlgeschlagen';

  @override
  String get enhance => 'Verbessern';

  @override
  String get enhanceConfirmBody =>
      'Die KI schreibt das Dokument neu. Dies kann nicht rückgängig gemacht werden.';

  @override
  String enhanceConfirmTitle(Object label) {
    return '$label verbessern?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return 'Fehler beim Verbessern von $label: $error';
  }

  @override
  String enhanceStarted(Object label) {
    return 'Verbesserung von $label auf dem Server gestartet...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label erfolgreich verbessert';
  }

  @override
  String get enhancementFailed => 'Verbesserung fehlgeschlagen';

  @override
  String get enterConceptOrName =>
      'Gib ein Konzept oder einen Projektnamen ein';

  @override
  String get enterServerUrlDesc =>
      'Gib die URL deines Auto-Game-Builder-Servers ein';

  @override
  String get enterUrlInPhoneApp =>
      'Gib diese URL in der Telefon-App ein, um dich remote zu verbinden';

  @override
  String get enterValidUrl =>
      'Gib eine gültige URL ein (z. B. http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc =>
      'Gib deine Worker-URL ein, um dich remote zu verbinden';

  @override
  String errorWithMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return 'Alle $minutes Min.';
  }

  @override
  String exitLabelWith(Object code) {
    return 'Exit: $code';
  }

  @override
  String get expandFoldersOrCreate =>
      'Klappe die Ordner unten auf oder erstelle eine neue App';

  @override
  String get failed => 'Fehlgeschlagen';

  @override
  String failedCountLabel(Object count) {
    return '$count fehlgeschlagen';
  }

  @override
  String get failedToBrainstorm => 'Brainstorming fehlgeschlagen';

  @override
  String get failedToCreateApp => 'App konnte nicht erstellt werden';

  @override
  String get failedToCreateItem => 'Eintrag konnte nicht erstellt werden';

  @override
  String get failedToCreateTestTask =>
      'Testaufgabe konnte nicht erstellt werden';

  @override
  String get failedToDelete => 'Löschen fehlgeschlagen';

  @override
  String get failedToLoadApp => 'App konnte nicht geladen werden';

  @override
  String get failedToLoadAutomations =>
      'Automatisierungen konnten nicht geladen werden';

  @override
  String get failedToLoadLogs => 'Logs konnten nicht geladen werden';

  @override
  String get failedToLoadTasks => 'Aufgaben konnten nicht geladen werden';

  @override
  String failedToLoadWithError(Object error) {
    return 'Laden fehlgeschlagen: $error';
  }

  @override
  String get failedToRefreshApp => 'App konnte nicht aktualisiert werden';

  @override
  String get failedToRequestCodeCheck =>
      'Code-Check konnte nicht angefordert werden';

  @override
  String get failedToRequestIdeas => 'Ideen konnten nicht angefordert werden';

  @override
  String get failedToReset => 'Zurücksetzen fehlgeschlagen';

  @override
  String get failedToRunTask => 'Aufgabe konnte nicht ausgeführt werden';

  @override
  String failedToSave(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get failedToStartReupload =>
      'Erneuter Upload konnte nicht gestartet werden';

  @override
  String failedToStartServer(Object error) {
    return 'Server konnte nicht gestartet werden: $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return 'Start fehlgeschlagen: $error';
  }

  @override
  String failedToTrigger(Object action) {
    return '$action konnte nicht ausgelöst werden';
  }

  @override
  String get failedToTriggerRun => 'Lauf konnte nicht ausgelöst werden';

  @override
  String get failedToUpdate => 'Aktualisierung fehlgeschlagen';

  @override
  String get failedToUpdateAiAgent =>
      'KI-Agent konnte nicht aktualisiert werden';

  @override
  String get failedToUpdateMcp => 'MCP konnte nicht aktualisiert werden';

  @override
  String get favoritesOnly => 'Nur Favoriten';

  @override
  String get feedback => 'Feedback';

  @override
  String fileTooLarge(Object max, Object files) {
    return 'Zu groß (max. $max MB): $files';
  }

  @override
  String get filterAll => 'Alle';

  @override
  String get filterClosed => 'Geschlossen';

  @override
  String get filterOpen => 'Offen';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Befunde',
      one: '1 Befund',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return 'erledigt $time';
  }

  @override
  String finishedFailedAgo(Object time) {
    return 'fehlgeschlagen $time';
  }

  @override
  String forceRefreshFailed(Object error) {
    return 'Erzwungene Aktualisierung fehlgeschlagen: $error';
  }

  @override
  String get forceRefreshTooltip =>
      'Aktualisierung vom Server erzwingen (leert lokalen Cache)';

  @override
  String get fullAutoMode => 'Vollautomatik-Modus';

  @override
  String get fullAutoModeOn =>
      'KI liest Aufgaben, behebt Fehler, generiert neue Ideen, wiederholt';

  @override
  String get generate => 'Generieren';

  @override
  String get generateIdeas => 'Ideen generieren';

  @override
  String get generateIdeasHint => 'z. B. \"Ideen zur Verbesserung der UI\"';

  @override
  String get genre => 'Genre';

  @override
  String get genreAction => 'Action';

  @override
  String get genreAny => 'Beliebig';

  @override
  String get genreArcade => 'Arcade';

  @override
  String get genreCardGame => 'Kartenspiel';

  @override
  String get genreIdleClicker => 'Idle/Clicker';

  @override
  String get genrePuzzle => 'Puzzle';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'Simulation';

  @override
  String get genreStrategy => 'Strategie';

  @override
  String get genreTowerDefense => 'Tower Defense';

  @override
  String get getStarted => 'Loslegen';

  @override
  String get googleAccount => 'Google-Konto';

  @override
  String get hide => 'Ausblenden';

  @override
  String highCount(Object count) {
    return '$count hoch';
  }

  @override
  String get ideaGenerationRequested => 'Ideengenerierung angefordert';

  @override
  String get installed => 'installiert';

  @override
  String get intervalMinLabel => 'Intervall (Min.): ';

  @override
  String get invalidQrData => 'Ungültige QR-Code-Daten';

  @override
  String get issueCreated => 'Issue erstellt';

  @override
  String get issueTitleHint => 'Issue-Titel';

  @override
  String get issues => 'Issues';

  @override
  String get itemCreated => 'Eintrag erstellt';

  @override
  String get justNow => 'Gerade eben';

  @override
  String get language => 'Sprache';

  @override
  String get later => 'Später';

  @override
  String get links => 'Links';

  @override
  String get loginTagline => 'Verwalte deine Spieleprojekte von überall';

  @override
  String get logs => 'Logs';

  @override
  String get maintenanceOnly => 'Nur Wartung';

  @override
  String get markAsCompleted => 'Als abgeschlossen markieren';

  @override
  String get markComplete => 'Als erledigt markieren';

  @override
  String markCompleteConfirm(Object title) {
    return '\"$title\" als abgeschlossen markieren?';
  }

  @override
  String get markedAsCompleted => 'Als abgeschlossen markiert';

  @override
  String maxMinutes(Object minutes) {
    return 'Max. $minutes Min.';
  }

  @override
  String get maxSessionMinLabel => 'Max. Sitzung (Min.): ';

  @override
  String get mcpConfiguredPerApp =>
      'MCP-Server werden pro App auf der App-Detailseite konfiguriert.';

  @override
  String get mcpServers => 'MCP-Server';

  @override
  String mcpServersActive(Object count) {
    return 'MCP-Server ($count aktiv)';
  }

  @override
  String get mcpServersDesc =>
      'Tool-Server, die für alle KI-Läufe dieser App verfügbar sind';

  @override
  String mediumCount(Object count) {
    return '$count mittel';
  }

  @override
  String get moveBackToActive => 'Zurück zu Aktiv verschieben';

  @override
  String get moveToCompletedFolder => 'In Ordner \"Abgeschlossen\" verschieben';

  @override
  String get nameIsRequired => 'Name ist erforderlich';

  @override
  String get needHelpSettingUp => 'Hilfe bei der Einrichtung benötigt?';

  @override
  String get newApp => 'Neue App';

  @override
  String get newAutomation => 'Neue Automatisierung';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get newItem => 'Neuer Eintrag';

  @override
  String get newPrompt => 'Neuer Prompt';

  @override
  String newReportsCount(Object count) {
    return '$count neue(r) Bericht(e)';
  }

  @override
  String get nextRunIn => 'Nächster Lauf in';

  @override
  String get noApiKeyFound =>
      'Kein API-Schlüssel gefunden – Server neu starten, um einen zu erzeugen';

  @override
  String get noAppsMatch => 'Keine passenden Apps';

  @override
  String get noAppsYet => 'Noch keine Apps';

  @override
  String get noArtBibleYet =>
      'Noch keine Grafik-Bibel. Tippe auf Hinzufügen, um die visuelle Identität festzulegen – Palette, Typografie, Verbote.';

  @override
  String get noAutomationsMatchFilters =>
      'Keine Automatisierungen entsprechen den Filtern';

  @override
  String get noAutomationsYet => 'Noch keine Automatisierungen';

  @override
  String noBuildTargetsFor(Object type) {
    return 'Keine Build-Ziele für $type-Projekte.';
  }

  @override
  String get noBuildsYet => 'Noch keine Builds';

  @override
  String get noChatsYet => 'Noch keine Chats';

  @override
  String get noClaudeMdYet =>
      'Noch keine CLAUDE.md. Tippe auf Hinzufügen, um Projektanweisungen für die KI festzulegen.';

  @override
  String get noDesignDocYet =>
      'Noch kein Design-Dokument. Tippe auf Hinzufügen, um deine App-Vision zu beschreiben.';

  @override
  String get noDirectivesYet => 'Noch keine Direktiven gesendet.';

  @override
  String get noFavoritePrompts => 'Noch keine Favoriten-Prompts';

  @override
  String get noItemsFound => 'Keine Einträge gefunden';

  @override
  String get noLogsFound => 'Keine Logs gefunden';

  @override
  String get noNewReports => 'Keine neuen Berichte';

  @override
  String get noOpenReports => 'Keine offenen Berichte';

  @override
  String get noOpenTasksToDependOn =>
      'Keine offenen Aufgaben zum Abhängigmachen';

  @override
  String get noPendingItems => 'Keine ausstehenden Einträge zum Bearbeiten';

  @override
  String get noPromptHistory =>
      'Noch kein Prompt-Verlauf.\nGeneriere Ideen, um einen Verlauf aufzubauen.';

  @override
  String get noReportsHere => 'Keine Berichte hier';

  @override
  String get noWorkerUrlDetected =>
      'Keine Worker-URL in settings.json erkannt.\nRichte einen Cloudflare Worker ein, um Fernzugriff zu ermöglichen.';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get notConfigured => 'Nicht konfiguriert';

  @override
  String get notConnected => 'Nicht verbunden';

  @override
  String get notInstalled => 'nicht installiert';

  @override
  String get notPaired => 'Nicht gekoppelt';

  @override
  String get notSet => '(nicht gesetzt)';

  @override
  String get notYetUploaded => 'noch nicht hochgeladen';

  @override
  String get onHold => 'Pausiert';

  @override
  String get oneShotRunEndsIn => 'Einmaliger Lauf endet in';

  @override
  String oneTimeRunTriggered(Object app) {
    return 'Einmaliger Lauf für $app ausgelöst';
  }

  @override
  String openCountLabel(Object count) {
    return '$count offen';
  }

  @override
  String get openPdf => 'PDF öffnen';

  @override
  String get openingPdf => 'PDF wird geöffnet…';

  @override
  String get orSeparator => 'ODER';

  @override
  String get output => 'Ausgabe';

  @override
  String get packageName => 'Paketname';

  @override
  String get paired => 'Gekoppelt';

  @override
  String get pairedSuccessfully => 'Erfolgreich gekoppelt!';

  @override
  String get perfProfileTaskCreated => 'Performance-Profil-Aufgabe erstellt';

  @override
  String get performanceProfile => 'Performance-Profil';

  @override
  String get performanceProfileSubtitle =>
      'Frame-Einbrüche, Speicher, Ladezeit';

  @override
  String get photo => 'Foto';

  @override
  String get postpone => 'Zurückstellen';

  @override
  String postponedCount(Object count) {
    return 'Zurückgestellt ($count)';
  }

  @override
  String get pressBackAgainToExit => 'Zurück erneut drücken zum Beenden';

  @override
  String get previousChat => 'Vorheriger Chat';

  @override
  String get priority => 'Priorität';

  @override
  String processingTasks(Object done, Object total) {
    return 'Verarbeite $done von $total Aufgaben...';
  }

  @override
  String get projectPath => 'Projektpfad';

  @override
  String get promptHistory => 'Prompt-Verlauf';

  @override
  String get promptHistoryTooltip => 'Prompt-Verlauf';

  @override
  String get publish => 'Veröffentlichen';

  @override
  String get pullAndRebuild => 'Pull & Neu bauen';

  @override
  String get pullFailed => 'Pull fehlgeschlagen';

  @override
  String get pullNow => 'Jetzt pullen';

  @override
  String get pullOnly => 'Nur Pull';

  @override
  String purchaseFailed(Object error) {
    return 'Kauf fehlgeschlagen: $error';
  }

  @override
  String get putOnHoldForLater => 'Für später pausieren';

  @override
  String get pythonSectionDesc =>
      'Skripte ausführen und das Python-Projekt über den Server verwalten.';

  @override
  String get quickIssue => 'Schnelles Issue';

  @override
  String get rePairWithQr => 'Mit QR-Code neu koppeln';

  @override
  String get rebuild => 'Neu bauen';

  @override
  String get rebuildBody => 'Einen neuen Build von Grund auf starten?';

  @override
  String get rebuildTitle => 'Neu bauen?';

  @override
  String get recentBuilds => 'Letzte Builds';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String refreshFailedShowingCached(Object message) {
    return 'Aktualisierung fehlgeschlagen – zeige zuletzt synchronisierte Daten. $message';
  }

  @override
  String get refreshedFromServer => 'Vom Server aktualisiert';

  @override
  String get reload => 'Neu laden';

  @override
  String get reopen => 'Wieder öffnen';

  @override
  String get reportBugOrSuggestion => 'Bug / Vorschlag melden';

  @override
  String get reportBugSubtitle =>
      'Sag uns, was behoben oder hinzugefügt werden soll';

  @override
  String get reportConsent =>
      'Ich stimme zu, diesen Bericht mit meinen Geräteinfos (Modell, Betriebssystem und App-Version) an den Entwickler zu senden, um bei der Fehlerbehebung zu helfen.';

  @override
  String get reportHint => 'Was ist passiert, oder was möchtest du sehen?';

  @override
  String get reportSentThanks => 'Danke! Dein Bericht wurde gesendet.';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get resetServer => 'Server zurücksetzen';

  @override
  String get resetServerBody => 'Dies startet den Backend-Server neu.';

  @override
  String resetServerRunningNote(Object count) {
    return '$count laufende Automatisierung(en) werden zuerst gestoppt, um einen automatischen Neustart zu verhindern.';
  }

  @override
  String get resumeActiveDevelopment => 'Aktive Entwicklung fortsetzen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get retryUpload => 'Upload erneut versuchen';

  @override
  String get reuploadStarted => 'Erneuter Upload gestartet';

  @override
  String get run => 'Ausführen';

  @override
  String get runAgainBody =>
      'Ein einmaliger Lauf ist bereits im Gange, aber die KI hat möglicherweise vorzeitig gestoppt. Einen weiteren Lauf auslösen?';

  @override
  String get runAgainTitle => 'Erneut ausführen?';

  @override
  String get runAnyway => 'Trotzdem ausführen';

  @override
  String get runCheck => 'Check ausführen';

  @override
  String get runOnce => 'Einmal ausführen';

  @override
  String get runOnceInProgress => 'Einmal ausführen (läuft)';

  @override
  String get running => 'Läuft';

  @override
  String get save => 'Speichern';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get saveEmptyGddBody => 'Dies löscht das aktuelle Design-Dokument.';

  @override
  String get saveEmptyGddTitle => 'Leeres GDD speichern?';

  @override
  String get saving => 'Wird gespeichert...';

  @override
  String scanError(Object error) {
    return 'Scanfehler: $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'Scan fehlgeschlagen: Server antwortete mit $status';
  }

  @override
  String get scanForProjects => 'Nach Projekten scannen';

  @override
  String get scanPairingQrTitle => 'Kopplungs-QR-Code scannen';

  @override
  String get scanQrToPair => 'QR-Code zum Koppeln scannen';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return '$found Ordner gescannt: $imported importiert, $skipped übersprungen';
  }

  @override
  String get scanThisQr => 'Scanne diesen QR-Code mit deinem Telefon';

  @override
  String get scanToInstall => 'Scannen, um auf deinem Telefon zu installieren';

  @override
  String get scopeCheck => 'Scope-Check';

  @override
  String get scopeCheckSubtitle => 'Streichliste + Realismus-Durchgang';

  @override
  String get scopeCheckTaskCreated => 'Scope-Check-Aufgabe erstellt';

  @override
  String get screenshotsOptional => 'Screenshots (optional)';

  @override
  String get screenshotsTooLarge =>
      'Screenshots sind groß – eventuell musst du einen entfernen.';

  @override
  String get searchAppsHint => 'Apps suchen...';

  @override
  String searchFilterChip(Object query) {
    return 'Suche: \"$query\"';
  }

  @override
  String get searchHint => 'Suchen...';

  @override
  String get sectionAiAgents => 'KI-Agenten';

  @override
  String get sectionGameEngines => 'Spiel-Engines';

  @override
  String get sectionPaths => 'Pfade';

  @override
  String get sectionServices => 'Dienste';

  @override
  String get sectionSystemTools => 'Systemtools';

  @override
  String get selectAnApp => 'App auswählen';

  @override
  String get selectAnAppFirst => 'Zuerst eine App auswählen';

  @override
  String get selectApp => 'App auswählen';

  @override
  String get selectAppForContext =>
      'Wähle eine App für Kontext, oder stelle allgemeine Fragen';

  @override
  String get selectAppToViewItems => 'Wähle eine App, um Einträge anzuzeigen';

  @override
  String get selectCategoriesOrPrompt =>
      'Wähle Kategorien oder gib einen eigenen Prompt ein.';

  @override
  String get sendReport => 'Bericht senden';

  @override
  String get sending => 'Wird gesendet…';

  @override
  String get server => 'Server';

  @override
  String get serverConfiguration => 'Serverkonfiguration';

  @override
  String get serverConnection => 'Serververbindung';

  @override
  String serverReturnedStatus(Object status) {
    return 'Server antwortete mit Status $status';
  }

  @override
  String get serverStarted => 'Server gestartet!';

  @override
  String get serverStartedHealthFailed =>
      'Server gestartet, aber Statusprüfung fehlgeschlagen';

  @override
  String get serverStopped => 'Server gestoppt';

  @override
  String get serverUnreachable => 'Server nicht erreichbar';

  @override
  String get serverUrl => 'Server-URL';

  @override
  String get sessionEndsIn => 'Sitzung endet in';

  @override
  String get sessionRefreshed =>
      'Sitzung aktualisiert – aktueller Kontext bleibt erhalten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsJsonNotFound => 'settings.json nicht gefunden';

  @override
  String get settingsJsonRestartNote =>
      'settings.json – Server nach Änderungen neu starten';

  @override
  String get settingsSavedRestart =>
      'Einstellungen gespeichert – Server neu starten, um sie anzuwenden';

  @override
  String get setupInstructions => 'Einrichtungsanleitung';

  @override
  String get setupServerFirst => 'Richte zuerst den Server auf deinem PC ein';

  @override
  String get setupStepCloneRepo => 'Repository klonen:';

  @override
  String get setupStepEnterUrl =>
      'Gib die im Terminal angezeigte URL ein (z. B. http://192.168.1.100:8000):';

  @override
  String get setupStepInstallDeps => 'Abhängigkeiten installieren:';

  @override
  String get setupStepInstallPython => 'Installiere Python 3.10+ auf deinem PC';

  @override
  String get setupStepRunWizard => 'Einrichtungsassistenten ausführen:';

  @override
  String get setupStepStartServer => 'Server starten:';

  @override
  String get show => 'Anzeigen';

  @override
  String get showAll => 'Alle anzeigen';

  @override
  String get showAppIcons => 'App-Icons anzeigen';

  @override
  String get showAppIconsDesc =>
      'Zeigt echte App-Icons im Dashboard statt generischer Typ-Icons';

  @override
  String get showPairingQr => 'Kopplungs-QR-Code anzeigen';

  @override
  String get signInCancelled => 'Anmeldung wurde abgebrochen';

  @override
  String signInFailed(Object error) {
    return 'Anmeldung fehlgeschlagen: $error';
  }

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signingIn => 'Wird angemeldet...';

  @override
  String get skipForNow => 'Vorerst überspringen';

  @override
  String get start => 'Start';

  @override
  String get startBuildFromCardAbove =>
      'Starte einen Build über die Karte oben';

  @override
  String get startServer => 'Server starten';

  @override
  String get startServerNotFound => 'start_server.py nicht gefunden';

  @override
  String get status => 'Status';

  @override
  String get statusActive => 'Aktiv';

  @override
  String get statusAll => 'Alle';

  @override
  String get statusBuilt => 'Gebaut';

  @override
  String get statusBuiltLower => 'Gebaut';

  @override
  String get statusCompleted => 'Abgeschlossen';

  @override
  String get statusDivided => 'Aufgeteilt';

  @override
  String get statusDone => 'Fertig';

  @override
  String get statusFailedLower => 'Fehlgeschlagen';

  @override
  String statusFilterChip(Object value) {
    return 'Status: $value';
  }

  @override
  String get statusInProgress => 'In Bearbeitung';

  @override
  String get statusPending => 'Ausstehend';

  @override
  String get statusPendingLower => 'Ausstehend';

  @override
  String get statusPostponed => 'Zurückgestellt';

  @override
  String get stop => 'Stopp';

  @override
  String get stopServer => 'Server stoppen';

  @override
  String get stoppedLabel => 'Gestoppt';

  @override
  String stuckSuffix(Object time) {
    return '$time HÄNGT';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return '$count hängende Aufgabe(n) nach 30-Minuten-Timeout automatisch als fehlgeschlagen markiert';
  }

  @override
  String get studioReviews => 'Studio-Reviews';

  @override
  String get submit => 'Absenden';

  @override
  String get submitting => 'Wird gesendet...';

  @override
  String get suggestApiBackend => 'API & Backend';

  @override
  String get suggestFeatureIntegration => 'Feature-Integration';

  @override
  String get suggestFixFailures => 'Fehler beheben';

  @override
  String get suggestGddAligned => 'GDD-konform';

  @override
  String get suggestImproveCodebase => 'Codebasis verbessern';

  @override
  String get suggestNextMilestone => 'Nächster Meilenstein';

  @override
  String get suggestPerformanceBoost => 'Performance-Boost';

  @override
  String get suggestRevenueIdeas => 'Umsatzideen';

  @override
  String get suggestSecurityHardening => 'Sicherheitshärtung';

  @override
  String get suggestTaskPrioritization => 'Aufgabenpriorisierung';

  @override
  String get suggestTestingQa => 'Testing & QA';

  @override
  String get suggestUserEngagement => 'Nutzerbindung';

  @override
  String get suggestUxPolish => 'UX-Feinschliff';

  @override
  String get suggestedForYou => 'Für dich vorgeschlagen';

  @override
  String get summary => 'Zusammenfassung';

  @override
  String get supportDevelopment => 'Entwicklung unterstützen';

  @override
  String get supportDevelopmentDesc =>
      'Gefällt dir die App? Unterstütze doch die Entwicklung!';

  @override
  String get syncFailed => 'Synchronisierung fehlgeschlagen';

  @override
  String syncedAgo(Object time) {
    return 'Synchronisiert $time';
  }

  @override
  String get tapPlusToCreateAutomation =>
      'Tippe auf +, um deine erste Automatisierung zu erstellen';

  @override
  String get tapPlusToStartConversation =>
      'Tippe auf +, um eine Unterhaltung zu starten';

  @override
  String get tapToAddLongPressToEdit =>
      'Tippen zum Hinzufügen, lange drücken zum Bearbeiten';

  @override
  String get tapToOpenLongPressToEdit =>
      'Tippen zum Öffnen, lange drücken zum Bearbeiten';

  @override
  String get tapToRedetectEngine =>
      'Tippen, um die Engine erneut von der Festplatte zu erkennen';

  @override
  String taskLabelWith(Object task) {
    return 'Aufgabe: $task';
  }

  @override
  String get taskOverview => 'Aufgabenübersicht';

  @override
  String get taskResetToPending => 'Aufgabe auf ausstehend zurückgesetzt';

  @override
  String get tasks => 'Aufgaben';

  @override
  String get techDebtScan => 'Tech-Debt-Scan';

  @override
  String get techDebtScanSubtitle => 'God-Scripts, Duplikate, TODOs';

  @override
  String get techDebtTaskCreated => 'Tech-Debt-Scan-Aufgabe erstellt';

  @override
  String get tellUsMore => 'Erzähl uns mehr';

  @override
  String get test => 'Test';

  @override
  String get testConnection => 'Verbindung testen';

  @override
  String get testTaskCreated => 'Testaufgabe erstellt';

  @override
  String get testing => 'Wird getestet...';

  @override
  String get theme => 'Design';

  @override
  String get thinking => 'Denkt nach...';

  @override
  String timeDaysAgo(Object days) {
    return 'vor $days T.';
  }

  @override
  String timeHoursAgo(Object hours) {
    return 'vor $hours Std.';
  }

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinutesAgo(Object minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String timeMonthsAgo(Object months) {
    return 'vor $months Mon.';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return 'vor $seconds Sek.';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return 'vor $weeks Wo.';
  }

  @override
  String get titleHint => 'Titel';

  @override
  String get titleIsRequired => 'Titel ist erforderlich';

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
    return '$done von $total Einträgen ausgelöst';
  }

  @override
  String get tryChangingFilters =>
      'Versuche, den Kategorie- oder Statusfilter zu ändern';

  @override
  String get type => 'Typ';

  @override
  String get typeBug => 'Bug';

  @override
  String get typeFeature => 'Feature';

  @override
  String typeFilterChip(Object value) {
    return 'Typ: $value';
  }

  @override
  String get typeFix => 'Fix';

  @override
  String get typeIdea => 'Idee';

  @override
  String get typeIssue => 'Issue';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String get updateAvailableBody =>
      'Eine neue Version ist auf GitHub verfügbar.\nHole den neuesten Code und baue neu, um zu aktualisieren.';

  @override
  String get updateFailed => 'Update fehlgeschlagen';

  @override
  String updatedAgo(Object time) {
    return 'aktualisiert $time';
  }

  @override
  String updatedNamed(Object label) {
    return '$label aktualisiert';
  }

  @override
  String get uploadToGooglePlay => 'Zu Google Play hochladen';

  @override
  String urgentCountLabel(Object count) {
    return '$count dringend';
  }

  @override
  String get urgentLabel => 'dringend';

  @override
  String get userFallback => 'Nutzer';

  @override
  String get version => 'Version';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => 'Fehlgeschlagene Aufgaben anzeigen';

  @override
  String get viewIssues => 'Issues anzeigen';

  @override
  String get viewOnGitHub => 'Auf GitHub ansehen';

  @override
  String get warningPublishesToAll =>
      'Warnung: Dies veröffentlicht für alle Nutzer!';

  @override
  String get webDeploy => 'Web-Deploy';

  @override
  String get webDeploySectionDesc =>
      'Web-App über den Server bauen und bereitstellen.';

  @override
  String get website => 'Website';

  @override
  String get whatIsThis => 'Was ist das?';

  @override
  String get workOnAll => 'Alle bearbeiten';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n($count blockierte(r) Eintrag/Einträge werden übersprungen.)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return 'KI auf alle $count ausstehenden Eintrag/Einträge anwenden?\nSie werden nacheinander verarbeitet.';
  }

  @override
  String get workOnAllPending => 'Alle Ausstehenden bearbeiten';

  @override
  String get workOnThis => 'Dies bearbeiten';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return '$agent-KI anwenden auf:\n\"$title\"';
  }

  @override
  String get workerUrl => 'Worker-URL';

  @override
  String get workerUrlAutoDetected =>
      'Automatisch aus settings.json erkannt (schreibgeschützt)';

  @override
  String get workerUrlCopied => 'Worker-URL kopiert';

  @override
  String get workerUrlHelp =>
      'Diese URL erhältst du von der Desktop-App oder deinem Server-Administrator';

  @override
  String get workerUrlSaved => 'Worker-URL gespeichert';

  @override
  String get workerUrlSetHint =>
      'Setze cloudflare.worker_url in server/config/settings.json';

  @override
  String get youreAllSet => 'Alles bereit!';
}

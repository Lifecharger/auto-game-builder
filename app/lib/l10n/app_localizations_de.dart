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
  String get shareUsageStats => 'Anonyme Nutzungsstatistik teilen';

  @override
  String get shareUsageStatsDesc =>
      'Anonyme Zähler für Sitzungen und geöffnete Bildschirme. Keine Projektnamen, keine Aufgabentexte, keine Pfade.';

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

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'Noch keine AGENTS.md. Tippe auf Hinzufügen, um Projektanweisungen für die KI festzulegen.';

  @override
  String get cannotSaveEmptyAgentsMd =>
      'Leere AGENTS.md kann nicht gespeichert werden';

  @override
  String get agentsMdSaved => 'AGENTS.md gespeichert';

  @override
  String get reportEmailLabel => 'E-Mail (optional)';

  @override
  String get reportEmailHint => 'deine E-Mail, falls du eine Antwort möchtest';

  @override
  String get reportEmailNote =>
      'Wird nur genutzt, um auf diese Meldung zu antworten. Leer lassen, um anonym zu bleiben.';

  @override
  String get reportEmailInvalid =>
      'Das sieht nicht nach einer E-Mail-Adresse aus.';

  @override
  String get reportReply => 'Antworten';

  @override
  String reportReplySubject(String app) {
    return 'Zu deiner Meldung zu $app';
  }

  @override
  String get navGenerate => 'Erzeugen';

  @override
  String get navGallery => 'Erzeugtes';

  @override
  String get navFlow => 'Pipeline';

  @override
  String get navQueue => 'Warteschlange';

  @override
  String get navDelivery => 'Auslieferung';

  @override
  String get navBuckets => 'Buckets';

  @override
  String get assetModeTooltip => 'Asset-Modus';

  @override
  String get deliveryModeTooltip => 'Auslieferungsmodus';

  @override
  String get videoPlaybackFailed => 'Das Video konnte nicht abgespielt werden';

  @override
  String get apiKeyRefusedBanner =>
      'API-Schlüssel abgelehnt - zum Korrigieren in den Einstellungen tippen';

  @override
  String get errOffline => 'Server nicht erreichbar - Verbindung prüfen';

  @override
  String get errTimeout =>
      'Der Server hat zu lange nicht geantwortet - erneut versuchen';

  @override
  String errGatewayTimeout(int status) {
    return 'Der Server hat nicht rechtzeitig geantwortet (Gateway-Zeitüberschreitung $status)';
  }

  @override
  String errGateway(int status) {
    return 'Der Server ist hinter seinem Gateway nicht erreichbar (Gateway-Fehler $status) - prüfen, ob er läuft';
  }

  @override
  String errServer(int status) {
    return 'Serverfehler ($status) - später erneut versuchen';
  }

  @override
  String errUnauthorized(int status) {
    return 'Nicht autorisiert ($status) - API-Schlüssel in den Einstellungen prüfen';
  }

  @override
  String errNotFound(int status) {
    return 'Auf dem Server nicht gefunden ($status)';
  }

  @override
  String errRateLimited(int status) {
    return 'Zu viele Anfragen ($status) - kurz warten und erneut versuchen';
  }

  @override
  String errTooLarge(int status) {
    return 'Zu groß für den Server ($status)';
  }

  @override
  String errRejected(int status) {
    return 'Der Server hat die Anfrage abgelehnt ($status)';
  }

  @override
  String get errBadResponse =>
      'Der Server hat eine Antwort gesendet, die die App nicht lesen konnte';

  @override
  String get errUnknown => 'Die Anfrage ist fehlgeschlagen - erneut versuchen';

  @override
  String bucketsCounting(String bucket) {
    return '$bucket wird gezählt...';
  }

  @override
  String get bucketsTakedownTitle => 'Takedown (neu + alt)';

  @override
  String get bucketsDeleteForeverTitle => 'Endgültig löschen';

  @override
  String bucketsDeleteWarning(int count) {
    return '$count Objekte werden gelöscht. DAS KANN NICHT RÜCKGÄNGIG GEMACHT WERDEN.';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count Schlüssel haben keine Entsprechung im alten Zwilling - sie werden nur aus diesem Bucket gelöscht.';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return 'Zum Bestätigen den Bucket-Namen eingeben: $bucket';
  }

  @override
  String get bucketsTakedown => 'Takedown';

  @override
  String bucketsDeleted(int count) {
    return '$count Objekte gelöscht';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count Objekte gelöscht, $twin aus dem alten Zwilling';
  }

  @override
  String bucketsCopySource(String path) {
    return 'Quelle: $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'Quellbaum: $path';
  }

  @override
  String get bucketsWholeBucket => '(gesamter Bucket)';

  @override
  String get bucketsCopyNote =>
      'Die Kopie läuft im Speicherdienst - es fließen keine Bytes über das Telefon.';

  @override
  String get bucketsTargetKey => 'Zielschlüssel';

  @override
  String get bucketsTargetPrefix => 'Zielpräfix';

  @override
  String bucketsCopyStarted(String op) {
    return 'Kopie gestartet ($op)';
  }

  @override
  String get bucketsFixHeadersTitle => 'Header korrigieren';

  @override
  String bucketsFixHeadersBody(String path) {
    return 'Der Cache-Control-Header der Objekte unter $path wird geprüft; ein Objekt, das vom Standard abweicht, wird an Ort und Stelle neu geschrieben (Content-Type bleibt erhalten). Es werden keine Bytes heruntergeladen.\n\nAbsichtlich veränderlich gelassene Präfixe werden übersprungen.';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'Header-Reparatur gestartet ($op)';
  }

  @override
  String get bucketsOperations => 'Vorgänge';

  @override
  String get bucketsNoOperations => 'Noch keine Vorgänge';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  ok $ok  ·  Fehler $failed';
  }

  @override
  String get bucketsTwinDiffRunning => 'Zwillingsdifferenz wird berechnet...';

  @override
  String get bucketsLocalDiffRunning => 'Lokale Differenz wird berechnet...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin (alter Zwilling)';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'Lokaler Pushed-Ordner <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => 'Fehlt im alten Zwilling';

  @override
  String get bucketsMissingInBucket => 'Fehlt im Bucket';

  @override
  String get bucketsOnlyInLegacy => 'Nur im alten Zwilling';

  @override
  String get bucketsOnlyInBucket => 'Nur im Bucket';

  @override
  String get bucketsSizeMismatch => 'Größe weicht ab';

  @override
  String get bucketsUnmapped => 'Nicht zugeordnet (keine Regel)';

  @override
  String get bucketsDerived => 'Im Bucket erzeugt (Thumbs)';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title: $count';
  }

  @override
  String get bucketsFixFolderHeaders => 'Header dieses Ordners korrigieren';

  @override
  String get bucketsDiffs => 'Unterschiede';

  @override
  String get bucketsTwinDiff => 'Differenz zum alten Zwilling';

  @override
  String get bucketsLocalDiff => 'Differenz zum lokalen Pushed-Ordner';

  @override
  String get bucketsIntro =>
      'Ein Bucket ist der nach seinem Inhalt benannte Speicher. Zahlen werden auf Anfrage berechnet (nur Auflistung, es werden keine Bytes heruntergeladen).';

  @override
  String get bucketsBadgeLegacy => 'ALT';

  @override
  String get bucketsBadgePrivate => 'privat';

  @override
  String get bucketsBadgeContent => 'Inhalt';

  @override
  String get bucketsNotCounted => 'nicht gezählt';

  @override
  String bucketsObjectCount(int count) {
    return '$count Objekte';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'Zwilling: $twin';
  }

  @override
  String get bucketsCount => 'Zählen';

  @override
  String get bucketsEmptyFolder => 'Dieser Ordner ist leer';

  @override
  String get bucketsTruncated =>
      'Die Liste wurde gekürzt - einen engeren Ordner öffnen';

  @override
  String bucketsSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get bucketsClearSelection => 'Auswahl aufheben';

  @override
  String get bucketsTakedownTooltip =>
      'Takedown (auch aus dem alten Zwilling löschen)';

  @override
  String get bucketsSize => 'Größe';

  @override
  String get bucketsContentType => 'Typ';

  @override
  String get bucketsModified => 'Geändert';

  @override
  String get bucketsNone => '(keiner)';

  @override
  String get bucketsMutableOnPurpose =>
      'Absichtlich veränderlich - kein Standard gilt';

  @override
  String bucketsHeaderOk(String kind) {
    return 'Entspricht dem Cache-Standard ($kind)';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return 'Standard: $expected';
  }

  @override
  String get bucketsLegacyTwin => 'Alter Zwilling';

  @override
  String get bucketsAddressCopied => 'Adresse kopiert';

  @override
  String get bucketsCopyAddress => 'Adresse kopieren';

  @override
  String get bucketsOpen => 'Öffnen';

  @override
  String get bucketsPrivateNoAddress =>
      'Dieser Bucket ist privat - er hat keine öffentliche Adresse';

  @override
  String get kindCard => 'Karte';

  @override
  String get kindCharacter => 'Charakter';

  @override
  String get assetCodeMode => 'Code-Modus';

  @override
  String get assetPickFinishedImage => 'Wähle ein fertiges Bild';

  @override
  String get assetGenerateVideo => 'Video erzeugen';

  @override
  String get assetEnlarge => 'Vergrößern';

  @override
  String percentValue(Object value) {
    return '$value %';
  }

  @override
  String get commonCategory => 'Kategorie';

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
  String get charKindFemale => 'Weiblich';

  @override
  String get charKindMale => 'Männlich';

  @override
  String get charKindAnimal => 'Tier';

  @override
  String get charKindMachine => 'Maschine';

  @override
  String get outfitCatSet => 'Set';

  @override
  String get outfitCatTop => 'Oberteil';

  @override
  String get outfitCatBottom => 'Unterteil';

  @override
  String get outfitCatShoes => 'Schuhe';

  @override
  String get outfitCatSocks => 'Socken';

  @override
  String get outfitCatHat => 'Hut';

  @override
  String get outfitCatHeadgear => 'Kopfschmuck';

  @override
  String get outfitCatAccessory => 'Accessoire';

  @override
  String get outfitCatWeapon => 'Waffe';

  @override
  String get audioLabel => 'Audio';

  @override
  String get audioDownloading => 'Wird heruntergeladen...';

  @override
  String get audioOpen => 'Audio öffnen';

  @override
  String get outfitExtractTitle => 'Outfit extrahieren';

  @override
  String get outfitExtractBody =>
      'Die Person im gewählten Bild wird entfernt und das Outfit als Produktbild auf unsichtbarer Puppe vor schlichtem grauem Hintergrund in der Garderobe gespeichert. Danach kann es jeder Charakter als Skin tragen.';

  @override
  String get outfitExtractName => 'Name des Outfits';

  @override
  String get outfitExtractNameHint => 'z. B. Rotes Abendkleid';

  @override
  String get outfitExtractNote => 'Notiz (optional)';

  @override
  String get outfitExtractNoteHint => 'z. B. nur das Kleid, ohne die Schuhe';

  @override
  String get outfitExtractHelp =>
      'Set: alles, was die Person trägt, in einem Bild. Waffe / Accessoire: nur dieser Gegenstand, ohne Puppe.';

  @override
  String get outfitExtractAction => 'Extrahieren';

  @override
  String equipSlotTitle(Object category) {
    return 'Slot: $category';
  }

  @override
  String get equipSlotMultiHint =>
      'Mehrfachauswahl - tippen: anziehen / ablegen';

  @override
  String get equipSlotSingleHint =>
      'Einzelauswahl - tippen: anziehen, erneut tippen: ablegen';

  @override
  String get equipSlotEmpty => '(leer)';

  @override
  String get equipSlotNoOutfits =>
      'Kein fertiges Outfit in dieser Kategorie - nutze „+ Outfit erzeugen“ oder „Outfit extrahieren“';

  @override
  String get equipBaseLabel => 'Basis:';

  @override
  String get equipUndress => 'Alles ablegen';

  @override
  String get equipPickSourceTitle => 'Quellbild wählen';

  @override
  String get equipPickSourceHint =>
      'Die neuesten fertigen Erzeugungen (jeder Modus). Für Incoming- / Staging- / Pushed-Bilder der Jigsaw-Pipeline nutze den Bildschirm Pipeline > Jigsaw.';

  @override
  String get equipNoFinishedImage => 'Kein fertiges Bild';

  @override
  String get freeFlowTitle => 'Free-Pipeline';

  @override
  String get freeFlowEditTitle => 'Bearbeiten - Edit-Engine';

  @override
  String get freeFlowEditLabel => 'Was soll sich ändern';

  @override
  String get freeFlowEditHint =>
      'z. B. change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => 'Bearbeitung zur Warteschlange hinzugefügt';

  @override
  String get freeFlowNoVideoTask => 'Im Free-Modus gibt es keine Video-Aufgabe';

  @override
  String freeFlowVideoTitle(Object task) {
    return 'Video erzeugen - $task';
  }

  @override
  String get freeFlowMotionLabel => 'Bewegung';

  @override
  String get freeFlowMotionHint =>
      'z. B. she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued =>
      'Video zur Warteschlange hinzugefügt - wenn es fertig ist, erscheint auf dieser Karte ein Wiedergabesymbol';

  @override
  String get freeFlowDeleteConfirm => 'Diese Erzeugung löschen?';

  @override
  String get freeFlowDeleteWithVideosConfirm =>
      'Diese Erzeugung und ihre Videos löschen?';

  @override
  String get freeFlowEmpty =>
      'Im Free-Modus wurde noch nichts erzeugt - starte im Tab Erzeugen';

  @override
  String get queueKindGeneration => 'Erzeugung';

  @override
  String get queueKindTag => 'Tagging';

  @override
  String get queueKindMusic => 'Musik';

  @override
  String get queueKindJob => 'Auftrag';

  @override
  String get queueCancelRunningTitle => 'Laufenden Auftrag abbrechen';

  @override
  String get queueRemoveTitle => 'Aus der Warteschlange entfernen';

  @override
  String get queueCancelIt => 'Abbrechen';

  @override
  String get queueClearTitle => 'Warteschlange leeren';

  @override
  String get queueClearBody =>
      'Wartende Erzeugungsaufträge abbrechen? Der laufende Auftrag läuft weiter.';

  @override
  String get queueCancelWaiting => 'Wartende Aufträge abbrechen';

  @override
  String get queueEmpty => 'Die Warteschlange ist leer';

  @override
  String get queueEmptyHint => 'Aufträge kannst du im Tab Erzeugen hinzufügen';

  @override
  String get queueNow => 'Jetzt';

  @override
  String queueWaitingCount(Object count) {
    return 'Wartend ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return 'Erzeugungsaufträge ($count)';
  }

  @override
  String get queueOneQueue => 'Eine Warteschlange - alle Aufträge';

  @override
  String queueJobCount(Object count) {
    return '$count Aufträge';
  }

  @override
  String get queueMoveUp => 'Nach oben';

  @override
  String get queueMoveDown => 'Nach unten';

  @override
  String get queueUp => 'Hoch';

  @override
  String get queueDown => 'Runter';

  @override
  String queueElapsed(Object time) {
    return 'läuft seit $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return 'wartet seit $time';
  }

  @override
  String get queueWaiting => 'wartet';

  @override
  String get queueComfyReady => 'ComfyUI bereit';

  @override
  String get queueComfyOff => 'ComfyUI ist aus';

  @override
  String get deliveryPoolNeverRan => 'noch nie gelaufen';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (Probelauf)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · $total Bilder, $valid gültig, $tagged getaggt, $failed fehlgeschlagen';
  }

  @override
  String get reportErrEmpty => 'Bitte schreibe zuerst eine Nachricht.';

  @override
  String get reportErrTooLarge =>
      'Die Anhänge sind zu groß. Entferne einen und versuche es erneut.';

  @override
  String flowOpError(Object message) {
    return 'Vorgang fehlgeschlagen: $message';
  }

  @override
  String get flowOpCancelled => 'Vorgang abgebrochen';

  @override
  String flowOpDone(Object ok) {
    return '$ok fertig';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok fertig, $failed fehlgeschlagen';
  }

  @override
  String get flowCollection => 'Sammlung';

  @override
  String get flowAllParen => '(alle)';

  @override
  String get flowAll => 'alle';

  @override
  String get flowSelectAll => 'Alle auswählen';

  @override
  String get flowRetag => 'Neu taggen';

  @override
  String get flowRetagShort => 'Taggen';

  @override
  String get flowRetagStarted => 'Tagging gestartet';

  @override
  String get flowReadOnly => 'Nur Ansicht';

  @override
  String get flowPush => 'Push';

  @override
  String get flowPreview => 'Vorschau';

  @override
  String get flowYes => 'ja';

  @override
  String get flowNo => 'nein';

  @override
  String get flowMissingUpper => 'FEHLT';

  @override
  String get flowBadgeNoTags => 'keine Tags';

  @override
  String get flowTabPushed => '4 Gepusht';

  @override
  String get flowSelectAssetFirst => 'Wähle zuerst ein Asset';

  @override
  String get flowAccept => 'Annehmen';

  @override
  String get flowReject => 'Ablehnen';

  @override
  String get flowUpload => 'Hochladen';

  @override
  String get flowNew => 'Neu';

  @override
  String get flowReadFailed => 'Die Pipeline konnte nicht gelesen werden';

  @override
  String flowFilesDeleted(Object count) {
    return '$count Dateien gelöscht';
  }

  @override
  String get flowNegative => 'Negativ';

  @override
  String get flowPositive2 => 'Positiv 2';

  @override
  String get flowDuration => 'Dauer';

  @override
  String get flowAddToQueue => 'Einreihen';

  @override
  String get commonDescription => 'Beschreibung';

  @override
  String get cbnFlowTitle => 'CBN-Pipeline';

  @override
  String get cbnFlowTabIncoming => '2 Eingang';

  @override
  String get cbnFlowTabReady => '3 Fertig';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'Bauen - $count Assets';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      'Bereiche + Palette + nummerierte Vorlage + Reveal-Video (CPU). Der SAM-Schritt muss bereits erledigt sein; die Konturen kommen von den SAM-Grenzen. (Hot: Der Build erzeugt die Linienseite selbst mit Qwen; Schritt C ist eine optionale Vorschau.)';

  @override
  String get cbnFlowBuildBodyKid =>
      'Bereiche + Palette + nummerierte Vorlage + SVG (CPU). Der SAM-Schritt muss bereits erledigt sein.';

  @override
  String get cbnFlowBuild => 'Bauen';

  @override
  String get cbnFlowBuildStarted =>
      'Build gestartet - der Fortschritt steht oben';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stage gestartet ($count Assets)';
  }

  @override
  String get cbnFlowStageObjects => 'Objektliste';

  @override
  String get cbnFlowLineart => 'Linien';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'Push - $count Assets';
  }

  @override
  String get cbnFlowPushBody =>
      'Die Asset-Ordner werden zu R2 hochgeladen und nach „Gepusht“ verschoben.\n\nDas ist eine VERÖFFENTLICHUNG und kann nicht rückgängig gemacht werden.';

  @override
  String cbnFlowDeleteBody(Object count) {
    return '$count Assets werden gelöscht.';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count gelöscht';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'Keine Assets in dieser Stufe.\nSchicke sie im Bildschirm „Erzeugtes“ im CBN-Modus mit ANNEHMEN hierher.';

  @override
  String get cbnFlowEmptyStaging =>
      'Noch kein gebautes Asset.\nWähle im Tab „Eingang“ aus und tippe auf BAUEN.';

  @override
  String get cbnFlowEmptyPushed => 'Kein gepushtes Asset.';

  @override
  String get cbnFlowBadgeTagged => 'T';

  @override
  String get cbnFlowBadgeObjects => 'O';

  @override
  String cbnFlowBadgeBuilt(Object regions, Object colors) {
    return '${regions}B ${colors}F';
  }

  @override
  String get cbnFlowLayerNumbered => 'Nummeriert';

  @override
  String get cbnFlowLayerFinished => 'Fertig';

  @override
  String get cbnFlowLayerSource => 'Quelle';

  @override
  String get cbnFlowLayerObjects => 'Objekte';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions Bereiche · $colors Farben · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   Tags: $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) Objekte finden';

  @override
  String get cbnFlowSamMasks => 'B) SAM-Masken';

  @override
  String get cbnFlowLineartPage => 'C) Linienseite (optional, Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) Bauen';

  @override
  String get cbnFlowStepMissingA =>
      'Schritt A (Objektliste) wurde nicht ausgeführt';

  @override
  String get cbnFlowStepMissingB =>
      'Schritt B (SAM-Masken) wurde nicht ausgeführt';

  @override
  String get cbnFlowStepMissingC =>
      'Schritt C (Linienseite) wurde nicht ausgeführt';

  @override
  String get cbnFlowImageFailed => 'Das Bild konnte nicht geladen werden';

  @override
  String get jigsawFlowTitle => 'Jigsaw-Pipeline';

  @override
  String get jigsawFlowTabTagged => '2 Getaggt';

  @override
  String get jigsawFlowTabToPush => '3 Zu pushen';

  @override
  String get jigsawFlowQueueAll => 'ALLE EINREIHEN';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'ALLE EINREIHEN - $count Assets';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return 'Video erzeugen - $count Assets';
  }

  @override
  String get jigsawFlowPositive1 => 'Positiv 1 - Motiv';

  @override
  String get jigsawFlowPositive1Help => 'leer = der eigene Prompt jedes Assets';

  @override
  String get jigsawFlowMotionPreset => 'Bewegungsvorlage';

  @override
  String get jigsawFlowSpreadInTurn => '(reihum verteilen)';

  @override
  String get jigsawFlowPositive2 => 'Positiv 2 - Bewegung';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = Platz des Motiv-Prompts. Leer = die Vorlagen reihum.';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return 'Die $count Vorlagen werden reihum verteilt.';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => 'Kein Asset ohne Video';

  @override
  String get jigsawFlowSelectWithoutVideo => 'Wähle Assets ohne Video';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued Videos eingereiht - sie erscheinen hier, wenn sie fertig sind';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued Videos eingereiht, $skipped übersprungen - sie erscheinen hier, wenn sie fertig sind';
  }

  @override
  String get jigsawFlowNoVideoTitle => 'Kein Video';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count Assets haben kein Video - es wird nur das JPG geschrieben. Fortfahren?';
  }

  @override
  String get jigsawFlowMusicNotReady => 'Das Musikmodell ist nicht bereit';

  @override
  String get jigsawFlowNoMusicMissing => 'Keiner Themensammlung fehlt Musik';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection hat bereits Musik oder ist Generic';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return 'Für $count Sammlungen wird je ein 30-sekündiges Instrumentalstück erzeugt (ACE-Step, lokal).\n\n$names\n\nJedes kann einige Minuten dauern.';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count Assets werden in den R2-Bucket HOCHGELADEN.\n\nDas ist eine Veröffentlichung, die nicht rückgängig gemacht werden kann - die hochgeladenen Dateien werden in der App sichtbar.';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return '$count Assets (jpg + mp4 + webp + json) endgültig löschen?';
  }

  @override
  String get jigsawFlowWebpStarted => 'Fehlende WebP-Dateien werden erzeugt';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return '$mode-Sammlung';
  }

  @override
  String get jigsawFlowCollectionHelp =>
      'aus der Liste wählen oder einen NEUEN Namen eingeben';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return 'aus der Liste wählen oder einen NEUEN Namen eingeben  -  $count volle Sammlungen sind ausgeblendet';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total Assets - als Nächstes $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'Keine Assets in dieser Stufe.\nSchicke sie im Bildschirm „Erzeugtes“ mit ANNEHMEN hierher.';

  @override
  String get jigsawFlowEmpty => 'Keine Assets in dieser Stufe.';

  @override
  String get jigsawFlowBadgeNoWebp => 'kein WebP';

  @override
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp) {
    return '$label\nVideo: $video   WebP: $webp';
  }

  @override
  String jigsawFlowPreviewTags(Object state) {
    return 'Tags: $state';
  }

  @override
  String get jigsawFlowNoVideoInSelection =>
      'Keines der gewählten Assets hat ein Video';

  @override
  String get jigsawFlowDeleteVideo => 'Video löschen';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return 'MP4 + WebP von $count Assets werden gelöscht; das Bild bleibt und du kannst ein neues Video erzeugen.';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip => 'Video löschen (das Bild bleibt)';

  @override
  String get jigsawFlowExtractNeedsOne =>
      'Ein Outfit wird aus einem einzelnen Bild extrahiert - wähle eines';

  @override
  String outfitExtractStarted(Object name) {
    return '$name wird in die Garderobe extrahiert - Charakter > Garderobe';
  }

  @override
  String get jigsawFlowMetaFile => 'Datei';

  @override
  String get jigsawFlowMetaTags => 'Tags';

  @override
  String get jigsawFlowMetaSubject => 'Motiv';

  @override
  String get jigsawFlowMetaPolicy => 'Richtlinie';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   WebP: $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'Tags / Metadaten';

  @override
  String get jigsawFlowMissingWebp => 'Fehlende WebP';

  @override
  String deliverySavedLive(Object time) {
    return 'Gespeichert und LIVE ($time) - die Zahlen werden aktualisiert';
  }

  @override
  String get deliveryReindexTitle => 'Metadaten neu einlesen';

  @override
  String get deliveryReindexBody =>
      'Für Bilder, deren EXIF im Bucket geändert wurde. Gib die Dateinamen durch Kommas getrennt ein (z. B. 12.jpg, 340.jpg); leer lassen, um GANZ Generic neu einzulesen (~1500 Dateien, einige Minuten).';

  @override
  String get deliveryReindexNames => 'Dateinamen';

  @override
  String get deliveryReindexAction => 'Einlesen';

  @override
  String deliveryReindexed(Object count) {
    return '$count Bilder neu eingelesen - Manifeste aktualisiert';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count Bilder neu eingelesen, $missing nicht gefunden - Manifeste aktualisiert';
  }

  @override
  String get deliveryDryRunStarted =>
      'Probelauf gestartet - er erzeugt nur einen Bericht';

  @override
  String get deliveryNormalizeStarted => 'Normalisierung gestartet';

  @override
  String get deliveryCancelRequested => 'Abbruch angefordert';

  @override
  String get deliveryNeverSaved => 'nie gespeichert';

  @override
  String get deliveryPoolJigsaw => 'Jigsaw-Pool';

  @override
  String get deliveryPoolCards => 'Karten';

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
    return '$pool-Pool: $total Bilder, $tagged getaggt, $untagged ohne Tags';
  }

  @override
  String get deliverySaveBeforeSwitch =>
      'Speichere deine Änderungen, bevor du den Pool wechselst.';

  @override
  String get deliveryReindexTooltip =>
      'Metadaten neu einlesen (wenn sich das EXIF geändert hat)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return 'Letzte Regel: $time  ·  standardmäßig ausgeliefert: $served / $total';
  }

  @override
  String get deliveryIntro =>
      'Schalter AUS = Bilder mit diesem Wert verschwinden aus dem Manifest. Speichern ist sofort live und filtert jetzt JEDE Sammlung / jedes Deck; ein einzelnes Element, das die Regeln durchlassen, sperrst du mit der Sperrliste.';

  @override
  String get deliveryNormalizeTitle => 'Normalisieren - fehlende Tags erzeugen';

  @override
  String get deliveryDryRun => 'Probelauf';

  @override
  String get deliveryNormalizeNoStatus =>
      'Status nicht verfügbar - der Server hat auf /api/normalize/status nicht geantwortet';

  @override
  String deliveryIndex(Object index) {
    return 'Index: $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return 'Letzter Lauf: $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => 'jede App (global)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'Sperren · $scope';
  }

  @override
  String get deliveryOpenList => 'Liste öffnen';

  @override
  String get deliveryBlockIntro =>
      'Eine globale Sperre gilt in JEDER App; wähle eine App, um nur für diese App zu sperren. Wird NACH den Regeln angewendet.';

  @override
  String get deliveryBlockEmpty =>
      'In diesem Pool gibt es nichts zu sperren (der Bucket ist leer).';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count Elemente · $tagged/$count getaggt';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count Elemente · $tagged/$count getaggt · ALLES GESPERRT';
  }

  @override
  String get deliveryAppsHint =>
      'Apps - tippen, um die Regel dieser App zu bearbeiten';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return 'Standard  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      'Standardregel - alte Versionen, die kein ?app= senden, und Apps ohne eigene Regel';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return 'Eigene Regel für $app';
  }

  @override
  String get deliveryCustomRuleOn =>
      'Ausschalten, um zum Standard zurückzukehren';

  @override
  String get deliveryCustomRuleOff =>
      'Aus: Es gilt die Standardregel. Beim Einschalten startet sie mit einer Kopie des Standards.';

  @override
  String get deliveryScopeTitle => 'Nur die ausgewählten Sammlungen';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total Sammlungen - neu veröffentlichte erreichen diese App NICHT';
  }

  @override
  String get deliveryScopeOff =>
      'Aus: Jede neu veröffentlichte Sammlung erreicht auch diese App';

  @override
  String get deliveryScopeNone =>
      'Nichts ausgewählt - eine leere Liste wird nicht gespeichert, die Regel fällt auf „alle“ zurück.';

  @override
  String get deliveryRulesEnabled => 'Regeln aktiv';

  @override
  String get deliveryRulesEnabledHint =>
      'Aus = dieser Regelsatz filtert nichts';

  @override
  String get deliveryServeUntagged => 'Bilder ohne Tags ausliefern';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count Bilder haben keine Metadaten';
  }

  @override
  String get deliveryQuick => 'Schnell:';

  @override
  String deliveryOffCount(Object count) {
    return '$count aus';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count Werte';
  }

  @override
  String get deliveryUnsaved => 'Es gibt ungespeicherte Änderungen';

  @override
  String get deliveryInSync => 'Identisch mit dem Server';

  @override
  String get deliverySavePublish => 'Speichern und veröffentlichen';

  @override
  String get commonApply => 'Anwenden';

  @override
  String get commonModel => 'Modell';

  @override
  String get cardTplShuffled =>
      'Gemischt - gesperrte Achsen blieben unverändert';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank gemischt';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - für alle';
  }

  @override
  String get cardTplAxisAllBack =>
      'Wird auf die Kartenrückseite geschrieben und GESPERRT.';

  @override
  String get cardTplAxisAllFront =>
      'Wird auf alle 13 Karten + 2 Joker zugleich geschrieben und GESPERRT - Mischen ändert es nicht.';

  @override
  String get cardTplValue => 'Wert';

  @override
  String get cardTplAllWritten => 'Für alle geschrieben und gesperrt';

  @override
  String cardTplRankTitle(Object rank) {
    return 'Vorlage $rank';
  }

  @override
  String get cardTplLocked => 'Gesperrt';

  @override
  String get cardTplLock => 'Sperren';

  @override
  String get cardTplManual => 'Manueller Zusatz (Freitext)';

  @override
  String get cardTplManualHint => 'z. B. holding a golden card fan';

  @override
  String get cardTplManualHelp =>
      'Wird ans Ende der Vorlage angehängt - Mischen entfernt es nicht';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank gespeichert';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot eingereiht';
  }

  @override
  String cardTplTitle(Object title) {
    return 'Sammlungskarte - $title';
  }

  @override
  String get cardTplShuffle => 'Mischen';

  @override
  String get cardTplNoTheme => 'Kein Thema - tippen und eingeben';

  @override
  String get cardTplThemeTitle => 'Thema (P1)';

  @override
  String get cardTplPresetCard => 'Fertige Karte';

  @override
  String get cardTplTheme => 'Thema';

  @override
  String get cardTplThemeHelp =>
      'Identität + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'Das Thema darf nicht leer sein';

  @override
  String get cardTplThemeSaved => 'Thema gespeichert';

  @override
  String cardTplModelSet(Object name) {
    return 'Modell: $name';
  }

  @override
  String get cardTplFaceDetail => 'Gesichtsretusche';

  @override
  String get cardTplFaceDetailHint =>
      '+15 s pro Karte - das Gesicht durchläuft einen eigenen Durchgang';

  @override
  String get cardTplFaceDetailOn => 'Gesichtsretusche an';

  @override
  String get cardTplFaceDetailOff => 'Gesichtsretusche aus';

  @override
  String get cardTplVideoEngine => 'Video-Engine (erstes Bild = letztes Bild)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (nicht installiert)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return 'Video-Engine: $name';
  }

  @override
  String get cardTplApplyToAll => 'Auf alle anwenden:';

  @override
  String get cardTplPickAxis => 'Achse wählen';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (Rückseite)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count Achsen gesperrt';
  }

  @override
  String get cardTplShuffleSlot => 'Diesen Slot mischen';

  @override
  String get cardTplGenerateSlot => 'Diesen Slot erzeugen';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return '$count Erzeugungen und ihre Dateien löschen?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count Erzeugungen gelöscht';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count konnten nicht gelöscht werden';
  }

  @override
  String get galleryCharacterNeedsOne =>
      'Ein Charakter wird aus einem einzelnen Bild erstellt - wähle eines';

  @override
  String get galleryMakeCharacter => 'Charakter erstellen';

  @override
  String get galleryMakeCharacterBody =>
      'Das gewählte Bild wird direkt zur Basis; Porträt, Geschichte und die 7 Richtungen werden von selbst erzeugt - ohne Rückfrage.';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name eingereiht - verfolge die Pipeline im Tab Warteschlange';
  }

  @override
  String get galleryCreateCharacterFirst =>
      'Erstelle zuerst mit „Charakter erstellen“ einen Charakter';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return 'Zu den Kandidaten hinzufügen - $count Bilder';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$count Bilder zu den Kandidaten von $name hinzugefügt';
  }

  @override
  String get galleryCollectionNeedsOne =>
      'Einer Sammlung wird ein einzelnes Bild hinzugefügt - wähle eines';

  @override
  String get galleryCreateCollectionFirst =>
      'Erstelle zuerst in der Karten-Pipeline eine Sammlung oder einen Dealer';

  @override
  String get galleryAddToCollection => 'Zur Sammlung hinzufügen';

  @override
  String get galleryDealerNoRank => 'Dealer (kein Rang)';

  @override
  String galleryPickRank(Object name) {
    return '$name - Rang wählen';
  }

  @override
  String get galleryQueuedOne =>
      'Eingereiht (1 Auftrag) - verfolge ihn im Tab Warteschlange';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count Bilder wandern in die Stufe „Eingang“ der CBN-Pipeline: JPG + EXIF-Tags. Der Build (SAM, Linien, Bereiche) wird dort gestartet.\n\nWelche Einstufung?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count Bilder wandern in Stufe 2: JPG + EXIF-Tags, das Video kommt mit, falls vorhanden.\n\nWelche Einstufung?';
  }

  @override
  String get galleryAcceptStarted =>
      'Gestartet - verfolge den Fortschritt im Tab „Pipeline“';

  @override
  String get galleryExtractTooltip =>
      'Outfit extrahieren - das Outfit aus dem Bild in die Garderobe übernehmen';

  @override
  String get galleryMakeCharacterTooltip =>
      'Charakter erstellen - einen neuen Charakter anlegen';

  @override
  String get galleryAddToCandidatesTooltip =>
      'Zu den Kandidaten hinzufügen - zu einem vorhandenen Charakter kopieren';

  @override
  String get galleryAddToCollectionTooltip =>
      'Zur Sammlung hinzufügen - Rang wählen';

  @override
  String get galleryAcceptTooltip => 'Annehmen - an Stufe 2 senden';

  @override
  String get galleryDeleteSelected => 'Auswahl löschen';

  @override
  String get galleryFilterImage => 'Bild';

  @override
  String get galleryFilterVideo => 'Video';

  @override
  String get galleryFilterFavorite => 'Favorit';

  @override
  String galleryQueuedAt(Object position) {
    return 'wartend $position';
  }

  @override
  String get galleryEmpty => 'Noch nichts erzeugt';

  @override
  String get galleryEmptyHint => 'Du kannst im Tab Erzeugen starten';

  @override
  String get galleryDeleteOneConfirm =>
      'Diese Erzeugung und ihre Datei löschen?';

  @override
  String get galleryAcceptOneCbn =>
      'Es wandert in die Stufe „Eingang“ der CBN-Pipeline (JPG + EXIF-Tags).\n\nWelche Einstufung?';

  @override
  String get galleryAcceptOneJigsaw =>
      'Es wandert in Stufe 2 (JPG + EXIF-Tags).\n\nWelche Einstufung?';

  @override
  String get galleryAccepted =>
      'Angenommen - wird getaggt, verfolge es im Tab „Pipeline“';

  @override
  String get galleryRejected => 'Abgelehnt';

  @override
  String get galleryEditBody =>
      'Dieses Bild wird zur Quelle; die Edit-Engine (Qwen Image Edit, bewahrt die Identität) startet eine neue Erzeugung. Was soll sich ändern?';

  @override
  String get galleryEditPromptLabel => 'Zusatz-Prompt';

  @override
  String get galleryEditPromptHint =>
      'z. B. change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued =>
      'Bearbeitung eingereiht - das Ergebnis erscheint unter Erzeugtes';

  @override
  String get galleryEditTooltip =>
      'Bearbeiten - neue Erzeugung mit der Edit-Engine';

  @override
  String galleryPoolInfo(Object name) {
    return 'Pool $name';
  }

  @override
  String get genPromptUnchanged =>
      'Der Prompt blieb unverändert (das lokale LLM hat nicht geantwortet)';

  @override
  String get genPromptWritten => 'Prompt geschrieben';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get genVariantFailed =>
      'Es konnte keine Variante erzeugt werden (das lokale LLM hat nicht geantwortet)';

  @override
  String get genPickVariant => 'Variante wählen';

  @override
  String get genEnrich => 'Anreichern';

  @override
  String get genFix => 'Korrigieren';

  @override
  String get genVariant => 'Variante';

  @override
  String get genFileUnreadable => 'Die Datei konnte nicht gelesen werden';

  @override
  String get genPromptEmpty => 'Der Prompt darf nicht leer sein';

  @override
  String genMissingInputs(Object inputs) {
    return 'Fehlende Eingabe: $inputs';
  }

  @override
  String get genNeedsImagePick =>
      'Diese Aufgabe braucht ein Eingabebild - wähle eines der erzeugten';

  @override
  String get genNeedsImage => 'Diese Aufgabe braucht ein Eingabebild';

  @override
  String genQueuedCount(Object count) {
    return '$count Aufträge eingereiht';
  }

  @override
  String get genQueued => 'Eingereiht';

  @override
  String genQueueBadge(Object count) {
    return '$count wartend';
  }

  @override
  String get genComfyOffBody =>
      'ComfyUI ist aus. Aufträge kommen in die Warteschlange, starten aber nicht - es muss am Computer gestartet werden.';

  @override
  String get genTask => 'Aufgabe';

  @override
  String get genWorkflowInputs => 'Eingaben des Workflows';

  @override
  String get genInputImage => 'Eingabebild';

  @override
  String get genPositive1 => 'Positiver Prompt 1 - Motiv';

  @override
  String get genPositive1Hint => 'z. B. police officer';

  @override
  String get genPositive2 => 'Positiver Prompt 2 - Vorlage';

  @override
  String genPositive2Help(Object marker) {
    return '$marker wird durch den ersten Prompt ersetzt. Kann leer bleiben.';
  }

  @override
  String get genFinalPrompt => 'Prompt, der gesendet wird';

  @override
  String get genNegative => 'Negativer Prompt';

  @override
  String get genTurboHint => 'schneller Modus';

  @override
  String genDurationSeconds(Object seconds) {
    return 'Dauer: $seconds Sekunden';
  }

  @override
  String genCount(Object count) {
    return 'Anzahl: $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'Größe: $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'Größe: $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'EINREIHEN';

  @override
  String get genFootnote =>
      'Aufträge werden nacheinander erzeugt. Du kannst sie im Tab Warteschlange verfolgen.';

  @override
  String get genDetailsTitle =>
      'Details - können leer bleiben, gesperrte werden nicht gemischt';

  @override
  String genRandomGenerate(Object count) {
    return 'Zufällig erzeugen  $count';
  }

  @override
  String get genLockedTooltip => 'gesperrt - bleibt beim Mischen fest';

  @override
  String get genOptionsEmpty => 'Die Optionsliste ist leer';

  @override
  String get genOptional => 'optional';

  @override
  String get genUploading => 'wird hochgeladen...';

  @override
  String get genNotSelected => 'nicht ausgewählt';

  @override
  String get genFromGallery => 'Aus Galerie';

  @override
  String get genFromFile => 'Aus Datei';

  @override
  String get genNoSource =>
      'Keine Erzeugung kann als Eingabe dienen. Erzeuge zuerst ein Bild.';

  @override
  String genPickerTitle(Object slot) {
    return '$slot - aus Erzeugtes wählen';
  }

  @override
  String get genPickerSearch => 'in Prompts suchen';

  @override
  String get genPickerEmpty => 'Keine fertige Erzeugung dieser Art.';

  @override
  String optionsFileMissing(Object items) {
    return 'Fehlt in der Optionsdatei: $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (keine Felddefinitionen)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'Die Optionsdatei konnte nicht gelesen werden: $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return 'Die Optionsdatei für $name konnte nicht gelesen werden: $error';
  }

  @override
  String get fieldLocation => 'Ort';

  @override
  String get fieldEra => 'Epoche / Ästhetik';

  @override
  String get fieldWeather => 'Wetter';

  @override
  String get fieldWeatherLight => 'Wetter / Licht';

  @override
  String get fieldJob => 'Beruf';

  @override
  String get fieldFantasy => 'Fantasy';

  @override
  String get fieldOutfitColor => 'Outfit-Farbe';

  @override
  String get fieldOutfit => 'Outfit';

  @override
  String get fieldHair => 'Haare';

  @override
  String get fieldHairColor => 'Haarfarbe';

  @override
  String get fieldHairstyle => 'Frisur';

  @override
  String get fieldEyes => 'Augen';

  @override
  String get fieldRace => 'Herkunft';

  @override
  String get fieldExpression => 'Ausdruck';

  @override
  String get fieldPose => 'Pose';

  @override
  String get fieldAngle => 'Winkel';

  @override
  String get fieldStyle => 'Stil';

  @override
  String get fieldMood => 'Stimmung';

  @override
  String get fieldColor => 'Farbe';

  @override
  String get fieldCreature => 'Kreatur';

  @override
  String get fieldClass => 'Klasse';

  @override
  String get fieldAge => 'Alter';

  @override
  String get fieldOrigin => 'Herkunft';

  @override
  String get fieldBody => 'Körper';

  @override
  String get fieldSkin => 'Haut';

  @override
  String get fieldFace => 'Gesicht';

  @override
  String get fieldGesture => 'Geste';

  @override
  String get cardNotReady => 'Der Server-Endpunkt ist noch nicht bereit';

  @override
  String get cardKindNormal => 'Normal';

  @override
  String get cardKindDealer => 'Dealer';

  @override
  String get cardStagePushed => 'gepusht';

  @override
  String get cardStageWebp => 'WebP fertig';

  @override
  String get cardStageVideo => 'Video fertig';

  @override
  String get cardStageStill => 'Still fertig';

  @override
  String get cardStageEmpty => 'leer';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (prüfen)';
  }

  @override
  String get cardVideoIntro =>
      'Erstes Bild = letztes Bild (Schleife). Die Kamera bleibt fixiert - Bildausschnitt, Maßstab und Hintergrund ändern sich nicht. Die Ausgabe landet zuerst im POOL; wählst du ein Tag, wird sie auch dort zugewiesen.';

  @override
  String get cardVideoTemplate => 'Vorlage (füllt den Text)';

  @override
  String get cardVideoMotion => 'Bewegungssatz (der gesendete Prompt)';

  @override
  String get cardVideoMotionHelp =>
      'Beschreibe eine sichtbare Bewegung; am Ende soll sie zur Ausgangspose zurückkehren';

  @override
  String get cardVideoAssignTag => 'Tag zuweisen';

  @override
  String get cardVideoPoolOnly => '(nur Pool - ich weise später zu)';

  @override
  String get cardVideoNewTag => 'Neues Tag...';

  @override
  String get cardVideoNewTagName => 'Name des neuen Tags';

  @override
  String get cardTagHint => 'z. B. victory';

  @override
  String get cardGestureTitle => 'Animation - Geste wählen';

  @override
  String get cardGestureIntro =>
      'MiniMax H3: idle 6 s, victory 2 s. Die Kamera bleibt fixiert - Bildausschnitt, Maßstab und Hintergrund ändern sich nicht.';

  @override
  String get cardGestureCustom => 'Eigene Bewegung';

  @override
  String get cardGestureCustomHint => 'z. B. leichtes Hüftwiegen, Füße fest';

  @override
  String get cardGestureCustomHelp =>
      'Ein kurzer Bewegungssatz - die Kamera bleibt fixiert';

  @override
  String get cardCutTitle => '3 WebP - Freistellmodus';

  @override
  String get cardCutHybrid => 'Alte grüne Grok-Master - Chroma + SAM zusammen';

  @override
  String get cardCutSam =>
      'Standard - nur SAM3, schlichter hellgrauer Hintergrund';

  @override
  String get cardCutAction => 'Freistellen';

  @override
  String cardEditTitle(Object name) {
    return 'Bearbeiten - $name';
  }

  @override
  String get cardEditSentence => 'Korrektursatz';

  @override
  String get cardEditSentenceHint =>
      'z. B. Haare kürzen / Handschuhe entfernen';

  @override
  String get cardEditBody =>
      'Das angenommene Still wird mit diesem Satz bearbeitet; Identität, Pose und Hintergrund bleiben erhalten. Das neue Bild wird automatisch angenommen.';

  @override
  String get cardEditUnrestricted => 'Uneingeschränkte Bearbeitung (NSFW-LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Einschalten, wenn Qwen ablehnt - MCNL-LoRA, 20 Schritte, etwas langsamer';

  @override
  String cardQueuedJobs(Object count) {
    return 'Eingereiht ($count Aufträge) - verfolge sie im Tab Warteschlange';
  }

  @override
  String get cardQueued => 'Eingereiht - verfolge es im Tab Warteschlange';

  @override
  String cardQueuedOp(Object op) {
    return 'Eingereiht (Op $op) - verfolge es im Tab Warteschlange';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - demnächst';
  }

  @override
  String get cardSoonBody =>
      'Die Karten-Endpunkte auf dem Server sind noch nicht offen. Sobald sie es sind, funktioniert dieser Bildschirm von selbst.';

  @override
  String get cardNewCollection => 'Neue Sammlung';

  @override
  String get cardIdLabel => 'Kennung (id)';

  @override
  String get cardIdHintCollection => 'z. B. police_royale';

  @override
  String get commonName => 'Name';

  @override
  String get cardNameHintCollection => 'z. B. Police Royale';

  @override
  String get cardPickPreset => 'Fertige Karte wählen (optional)';

  @override
  String get cardThemeHint =>
      'z. B. sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      'Formel: Identität + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'Joker (2 Stück)';

  @override
  String get cardJokersHint => '15 Ränge statt 13';

  @override
  String get cardNewCollectionNote =>
      'Pro Rang kommt 1 Still in die Warteschlange (Rotation von Haut / Haaren / Outfit / Pose). Es gibt keine Rückfrage - Feinschliff mit ✎ / ↻.';

  @override
  String get cardIdNameRequired => 'Kennung und Name dürfen nicht leer sein';

  @override
  String get cardNewDealer => 'Neuer Dealer';

  @override
  String get cardIdHintDealer => 'z. B. scarlett';

  @override
  String get cardNameHintDealer => 'z. B. Scarlett';

  @override
  String get cardDealerTheme => 'Thema / Outfit';

  @override
  String get cardDealerThemeHint =>
      'z. B. Casino-Weste und Fliege, rotes Noir-Kleid';

  @override
  String get cardDealerNote =>
      'Der Dealer wird im Hüftbild erzeugt (Hände auf dem Tisch, Blick in die Kamera). Es gibt keinen Rang - das eine Element durchläuft die vier Stufen.';

  @override
  String get cardNightPickGesture => 'Nachtmodus - Geste wählen';

  @override
  String get cardNightMode => 'Nachtmodus';

  @override
  String cardNightBody(Object gesture) {
    return 'Alle Karten UND Dealer werden neu animiert: aktuelles Still -> LTX-2.5 i2v ($gesture) -> SAM-Freistellung -> Sheet.\n\nDas dauert lange, alles kommt in die Warteschlange. Es wird NICHT gepusht.';
  }

  @override
  String get cardRestillTitle => 'Hintergründe grau machen';

  @override
  String get cardRestillBody =>
      'Der Still-Hintergrund aller Karten UND Dealer wird schlicht hellgrau (die Frau bleibt unverändert). Das Original bleibt als still_green.png erhalten; bereits graue werden übersprungen.\n\nEs wird kein Video erzeugt.';

  @override
  String get cardManifestPreview => 'Manifest-Vorschau';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return '$collections Sammlungen, $dealers Dealer';
  }

  @override
  String get cardManifestNote =>
      'Die Manifest-Datei wird beim PUSH geschrieben (erst die Dateien, dann das Manifest). Dies ist nur eine Vorschau.';

  @override
  String get cardCollectionCardSettings => 'Sammlungskarte (Einstellungen)';

  @override
  String get cardCollectionCardSettingsHint =>
      'Thema, 16 Slots, Modell, Gesichtsretusche';

  @override
  String get cardReanimate => 'Neu animieren';

  @override
  String get cardReanimateHint =>
      'Still -> i2v -> Freistellung (diese Sammlung)';

  @override
  String get cardRealify => 'Anime -> realistisch (Sammlung)';

  @override
  String get cardRealifyHint =>
      'jedes Still wird mit edit_qwen zum realistischen Foto';

  @override
  String get cardDeleteCollection => 'Sammlung löschen';

  @override
  String get cardDeleteCollectionHint =>
      'der Ordner wird mit allen Karten gelöscht - nicht rückgängig zu machen';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'Sammlung löschen - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'Dealer löschen - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'Der Sammlungsordner wird mit allen Dateien gelöscht.\n\nNICHT RÜCKGÄNGIG ZU MACHEN. Bereits zu R2 gepushte Dateien bleiben im Bucket.';

  @override
  String get cardDeleteDealerBody =>
      'Der Dealer-Ordner wird mit allen Dateien gelöscht.\n\nNICHT RÜCKGÄNGIG ZU MACHEN. Bereits zu R2 gepushte Dateien bleiben im Bucket.';

  @override
  String cardDeletedNamed(Object name) {
    return '$name gelöscht';
  }

  @override
  String get cardDealerCardSettings => 'Dealer-Karte (Einstellungen)';

  @override
  String get cardDealerCardSettingsHint =>
      'Thema, Vorlage, Modell, Gesichtsretusche';

  @override
  String get cardDeleteDealer => 'Dealer löschen';

  @override
  String get cardDeleteDealerHint =>
      'der Ordner wird mit allen Dateien gelöscht - nicht rückgängig zu machen';

  @override
  String get cardFlowTitle => 'Karten-Pipeline';

  @override
  String get cardBulkActions => 'Sammelaktionen';

  @override
  String get cardNightMenu => 'Nachtmodus: alles neu animieren';

  @override
  String get cardRestillMenu => 'Hintergründe grau machen (alle)';

  @override
  String get cardManifestMenu => 'Manifest-Vorschau';

  @override
  String get cardDealers => 'Dealer';

  @override
  String get cardEmptyCollections =>
      'Noch keine Sammlung.\n\nGib mit „+ Neue Sammlung“ Kennung, Namen und Thema an - für 13 (oder 15) Ränge kommt je 1 Still in die Warteschlange, danach folgen die Stufen 2 Video und 3 WebP.';

  @override
  String get cardEmptyDealers =>
      'Noch kein Dealer.\n\nGib mit „+ Neuer Dealer“ Namen, Thema und Geste an - ein einzelnes Element wird im Hüftbild erzeugt und durchläuft die vier Stufen.';

  @override
  String cardGestureLine(Object gesture) {
    return 'Geste: $gesture';
  }

  @override
  String cardAnimateTitle(Object count) {
    return '2 Video ($count Karten)';
  }

  @override
  String cardAnimateBody(Object total) {
    return 'Für jede Karte werden 2 Animationen erzeugt und ihren Tags zugewiesen:\n• idle - 6 s, eine kontrollierte Geste\n• victory - 2 s, kurzer Jubel im Bildausschnitt\nInsgesamt $total Videos; die alten bleiben im Pool.';
  }

  @override
  String get cardEditNeedsOne =>
      'Bearbeiten geht nur für einen Rang - wähle eine Karte';

  @override
  String cardPushTitle(Object name) {
    return 'Push - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'Sheet- und Thumb-Dateien werden zu R2 (cards) hochgeladen, dann wird das Manifest geschrieben. Derzeit ist das WebP von $ready/$total Rängen fertig.\n\nDas ist eine VERÖFFENTLICHUNG und NICHT RÜCKGÄNGIG ZU MACHEN.';
  }

  @override
  String get cardPushQueued =>
      'Push eingereiht - verfolge ihn im Tab Warteschlange';

  @override
  String get cardCollectionCardTooltip =>
      'Sammlungskarte - Thema, 16 Slots, Modell, Gesichtsretusche';

  @override
  String get commonMore => 'Mehr';

  @override
  String get cardNoThemeTap => 'Kein Thema - tippen: Sammlungskarte';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nSammlungskarte: tippen (Thema, 16 Slots, Modell, Gesichtsretusche)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'Der Sammlungsordner wird mit allen Karten gelöscht ($stills Stills).\n\nNICHT RÜCKGÄNGIG ZU MACHEN. Bereits zu R2 gepushte Dateien bleiben im Bucket.';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'Der Sammlungsordner wird mit allen Karten gelöscht ($stills Stills, $pushed gepusht).\n\nNICHT RÜCKGÄNGIG ZU MACHEN. Bereits zu R2 gepushte Dateien bleiben im Bucket.';
  }

  @override
  String get cardClearCards => 'Karten leeren';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - Still, Kandidaten, Video und WebP werden gelöscht; der Rang bleibt leer (mit „1 Still“ neu erzeugen).';
  }

  @override
  String cardsCleared(Object count) {
    return '$count Karten geleert';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count Karten konnten nicht geleert werden';
  }

  @override
  String get cardGenerateStill => '1 Still erzeugen';

  @override
  String get cardGenerateVideo => '2 Video erzeugen';

  @override
  String get cardGenerateWebp => '3 WebP erzeugen';

  @override
  String get cardBackUpper => 'RÜCKSEITE';

  @override
  String cardAssetVideo(Object tag) {
    return 'Video ($tag)';
  }

  @override
  String cardAssetSheet(Object tag) {
    return 'WebP / Freistellung ($tag)';
  }

  @override
  String cardAssetMissing(Object asset) {
    return '$asset fehlt';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return '$asset löschen?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'Nur das Video dieses Tags wird gelöscht; die Kopie im Pool, das Still und das WebP bleiben.';

  @override
  String get cardAssetDeleteSheetBody =>
      'Nur sheet.webp, Thumb und die freigestellten Frames werden gelöscht; Video und Still bleiben.';

  @override
  String get cardAssetDeleteStillBody =>
      'Nur das gewählte Still wird gelöscht; Kandidaten, Video und WebP bleiben.';

  @override
  String get cardPoolDelete => 'Aus dem Pool löschen';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id wird aus dem Pool gelöscht. Tags zugewiesene Kopien ($tags) bleiben.';
  }

  @override
  String get cardNone => 'keine';

  @override
  String get cardNewAnimTag => 'Neues Animations-Tag';

  @override
  String get cardNewAnimTagHelp =>
      'Das Spiel liest es unter diesem Namen (idle, wink, victory ...)';

  @override
  String get cardUnassigned => 'nicht zugewiesen';

  @override
  String cardAssignedTo(Object tags) {
    return 'zugewiesen: $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return 'Zuweisen: $name';
  }

  @override
  String get cardAssignNewTag => 'Neuem Tag zuweisen...';

  @override
  String get cardAnimReady => 'Video + WebP fertig';

  @override
  String get cardAnimVideoOnly => 'Video vorhanden, kein WebP';

  @override
  String get cardPoolEmpty => 'Kein Video im Pool - zuerst „2 Video“';

  @override
  String get cardDeleteVideoKeepTag => 'Video löschen (das Tag bleibt)';

  @override
  String get cardDeleteSheet => 'WebP / Freistellung löschen';

  @override
  String get cardDeleteTag => 'Tag löschen (mit Video + WebP)';

  @override
  String cardVideosHeader(Object count) {
    return 'Videos ($count) - tippen = zuweisen / Vorschau / löschen';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return 'Der Ordner von $name wird mit allen Dateien gelöscht. NICHT RÜCKGÄNGIG ZU MACHEN.';
  }

  @override
  String get cardClearCard => 'Karte leeren';

  @override
  String cardClearCardBody(Object name) {
    return '$name: Still, Kandidaten, Video, WebP und Animationen werden gelöscht; der Rang bleibt leer (mit „1 Still“ neu erzeugen).';
  }

  @override
  String get cardClearCardTooltip => 'Karte leeren (der Rang wird leer)';

  @override
  String get cardViewCut => 'Freistellung';

  @override
  String cardDeleteThisVideo(Object tag) {
    return 'Dieses Video löschen ($tag)';
  }

  @override
  String cardDeleteSheetTag(Object tag) {
    return 'WebP / Freistellung löschen ($tag)';
  }

  @override
  String get cardDeleteStill => 'Still löschen';

  @override
  String get cardNoVideo => 'Kein Video - mit „2 Video“ erzeugen';

  @override
  String get cardNoCut => 'Keine Freistellung - mit „3 WebP“ erzeugen';

  @override
  String get cardCutFrameFailed =>
      'Das freigestellte Bild konnte nicht gelesen werden';

  @override
  String get cardNoStill => 'Kein Still - mit „1 Still“ erzeugen';

  @override
  String get cardStillFailed => 'Das Still konnte nicht gelesen werden';

  @override
  String cardPromptTitleAge(Object age) {
    return 'Prompt  ·  Alter $age';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - Bildausschnitt verrutscht / Zoom / Maske gerissen. Erzeuge das Video oder die Freistellung neu.';

  @override
  String get cardAnimsHeader =>
      'Animationen - tippen = wählen, lange drücken = zuweisen / löschen';

  @override
  String cardAnimOpened(Object tag) {
    return '„$tag“ angelegt - mit 2 Video erzeugen oder aus dem Pool zuweisen';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return 'Wähle für „$tag“ ein Video aus dem Pool';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return 'Kandidaten ($count) - tippen = wählen';
  }

  @override
  String get cardCandidatePicked => 'Der Kandidat ist jetzt das gewählte Still';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step: $error';
  }
}

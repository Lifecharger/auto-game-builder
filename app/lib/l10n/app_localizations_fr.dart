// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get about => 'À propos';

  @override
  String get aboutApp => 'Application';

  @override
  String actionTriggered(Object action) {
    return '$action déclenché';
  }

  @override
  String get add => 'Ajouter';

  @override
  String agentLabelWith(Object agent) {
    return 'Agent : $agent';
  }

  @override
  String get agentLocal => 'Local';

  @override
  String get agentNone => 'Aucun';

  @override
  String get agentRunsOnServer =>
      'L’agent s’exécute sur le serveur avec un accès au niveau du projet';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return 'IA $agent déclenchée pour « $title »';
  }

  @override
  String get aiAgent => 'Agent IA';

  @override
  String get aiAgentUpdated => 'Agent IA mis à jour';

  @override
  String get aiResponse => 'Réponse de l’IA';

  @override
  String get allApps => 'Toutes les apps';

  @override
  String get allAppsCompletedOrPostponed =>
      'Toutes les apps sont terminées ou reportées';

  @override
  String get allAppsHaveAutomations =>
      'Toutes les apps ont déjà des automatisations';

  @override
  String get allAppsHint => 'Toutes les apps';

  @override
  String get allPendingBlocked =>
      'Tous les éléments en attente sont bloqués par des dépendances';

  @override
  String get apiConnection => 'Connexion API';

  @override
  String get apiUrlSaved => 'URL de l’API enregistrée';

  @override
  String get appCreated => 'App créée !';

  @override
  String get appDetail => 'Détail de l’app';

  @override
  String get appFallback => 'App';

  @override
  String get appNameHint => 'Nom de l’app (ex. Mon Jeu)';

  @override
  String get appStatusBuilding => 'compilation';

  @override
  String get appStatusDeploying => 'déploiement';

  @override
  String get appStatusError => 'erreur';

  @override
  String get appStatusFixing => 'correction';

  @override
  String get appStatusIdle => 'inactif';

  @override
  String get appStatusPublished => 'publié';

  @override
  String get appStatusQueued => 'en file d’attente';

  @override
  String get appStatusUploading => 'envoi';

  @override
  String get appStatusWorking => 'en cours';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc =>
      'App mobile/bureau avec prise en charge du déploiement Google Play';

  @override
  String get appTypeGodotDesc =>
      'Projet de jeu avec cibles d’export (Windows, Android, Web)';

  @override
  String get appTypePhaserDesc =>
      'Jeu Phaser 3 + TypeScript, packagé en AAB Android via Capacitor';

  @override
  String get appTypePythonDesc =>
      'Projet Python avec exécuteur de scripts et gestion pip';

  @override
  String get appTypeWebDesc =>
      'App web avec prise en charge du déploiement en hébergement statique';

  @override
  String get apps => 'Apps';

  @override
  String get archivedLabel => 'archivé';

  @override
  String get artAndAssets => 'Art & Assets';

  @override
  String get artBible => 'Bible artistique';

  @override
  String get artBibleCardSubtitle =>
      'Document d’ancrage de l’identité visuelle';

  @override
  String get artBibleHint =>
      'Déclaration d’identité, palette (hex), typographie, interdits, spécifications techniques...';

  @override
  String get artBibleSaved => 'Bible artistique enregistrée';

  @override
  String get artBibleShort => 'Bible artistique';

  @override
  String get artBibleSubtitle =>
      'Ancrage de l’identité visuelle — palette, typographie, interdits de style. Chaque tâche d’asset s’y réfère.';

  @override
  String get artBibleTaskCreated => 'Tâche de bible artistique créée';

  @override
  String artBibleTitle(Object app) {
    return 'Bible artistique - $app';
  }

  @override
  String get askAQuestionHint => 'Posez une question...';

  @override
  String get askAgent => 'Demander à l’agent';

  @override
  String get askAnythingAboutYourApps =>
      'Posez n’importe quelle question sur vos apps';

  @override
  String get assetAudit => 'Audit des assets';

  @override
  String get assetAuditSubtitle =>
      'Références cassées, orphelins, espaces réservés';

  @override
  String get assetAuditTaskCreated => 'Tâche d’audit des assets créée';

  @override
  String get assetSpecTaskCreated => 'Tâche de spécification d’assets créée';

  @override
  String get assetSpecs => 'Spécifications d’assets';

  @override
  String get assetSpecsSubtitle => 'Prompts par asset issus de la bible';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String attachmentsCount(Object count) {
    return 'Pièces jointes ($count)';
  }

  @override
  String get automationCreated => 'Automatisation créée';

  @override
  String get automationStateStarted => 'démarrée';

  @override
  String get automationStateStopped => 'arrêtée';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => 'Automatisation mise à jour';

  @override
  String get back => 'Retour';

  @override
  String get backend => 'Backend';

  @override
  String get balanceCheck => 'Vérification de l’équilibrage';

  @override
  String get balanceCheckSubtitle => 'Économie, progression, récompenses';

  @override
  String get balanceCheckTaskCreated =>
      'Tâche de vérification de l’équilibrage créée';

  @override
  String batchRunError(Object error) {
    return 'Erreur pendant l’exécution du lot : $error';
  }

  @override
  String blockedByList(Object ids) {
    return 'bloqué par $ids';
  }

  @override
  String blockedByTask(Object id) {
    return 'Bloqué par #$id';
  }

  @override
  String blockedCountLabel(Object count) {
    return '$count bloqué(s)';
  }

  @override
  String blockerNotInList(Object id) {
    return 'La tâche #$id n’est pas dans la liste actuelle (archivée ou supprimée)';
  }

  @override
  String get brainstormAndCreate => 'Brainstorming et création';

  @override
  String get brainstormConceptHint =>
      'Idée de concept (ex. « jeu idle de colonie de fourmis », « puzzle avec gravité »)';

  @override
  String get brainstormCreated =>
      'Projet créé avec une tâche de brainstorming !';

  @override
  String get brainstormDesc =>
      'Crée un nouveau projet avec une tâche de brainstorming. Quand la tâche s’exécute, l’IA génère un GDD complet et les tâches initiales.';

  @override
  String get brainstormNameHint =>
      'Nom du projet (facultatif — l’IA peut en suggérer un)';

  @override
  String get brainstormNewGame => 'Brainstormer un nouveau jeu';

  @override
  String get build => 'Compiler';

  @override
  String get buildAndDeploy => 'Compiler et déployer';

  @override
  String get buildCancelled => 'Build annulé';

  @override
  String get buildFailedLabel => 'build échoué';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'Le suivi du build a expiré après 30 minutes - vérifiez les journaux du serveur';

  @override
  String get buildTarget => 'Cible de build';

  @override
  String get builds => 'Builds';

  @override
  String builtCount(Object count) {
    return 'Compilés ($count)';
  }

  @override
  String get buyMeACoffee => 'Offrez-moi un café';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'Offrez-moi un café  $price';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get cannotReachServer => 'Impossible de joindre le serveur';

  @override
  String cannotReachServerWith(Object error) {
    return 'Impossible de joindre le serveur : $error';
  }

  @override
  String get cannotSaveEmptyArtBible =>
      'Impossible d’enregistrer une bible artistique vide';

  @override
  String get cannotSaveEmptyClaudeMd =>
      'Impossible d’enregistrer un CLAUDE.md vide';

  @override
  String get cannotSaveEmptyDesignDoc =>
      'Impossible d’enregistrer un document de conception vide';

  @override
  String get catBugsCrashes => 'Bugs & Crashs';

  @override
  String get catCodeStyle => 'Style de code';

  @override
  String get catDeadCode => 'Code mort';

  @override
  String get catErrorHandling => 'Gestion des erreurs';

  @override
  String get catMemory => 'Mémoire';

  @override
  String get categoryAccessibility => 'Accessibilité';

  @override
  String get categoryBug => 'Bug';

  @override
  String get categoryFeatures => 'Fonctionnalités';

  @override
  String get categoryMonetization => 'Monétisation';

  @override
  String get categoryOther => 'Autre';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categorySecurity => 'Sécurité';

  @override
  String get categorySuggestion => 'Suggestion';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count caractères';
  }

  @override
  String get chatHistory => 'Historique des discussions';

  @override
  String get chatLogs => 'Rapports';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count messages • $date';
  }

  @override
  String get checkBugsCrashes => 'Bugs et crashs';

  @override
  String get checkCodeStyle => 'Style de code';

  @override
  String get checkDeadCode => 'Code mort';

  @override
  String get checkErrorHandling => 'Gestion des erreurs';

  @override
  String get checkMemoryLeaks => 'Fuites de mémoire';

  @override
  String get checkPerformanceIssues => 'Problèmes de performance';

  @override
  String get checkSecurityVulnerabilities => 'Vulnérabilités de sécurité';

  @override
  String get checksToRun => 'Vérifications à exécuter :';

  @override
  String get claudeMdHint =>
      'Conventions du projet, commandes de build, règles...';

  @override
  String get claudeMdSaved => 'CLAUDE.md enregistré';

  @override
  String get claudeMdSubtitle =>
      'Instructions de projet pour les agents IA travaillant sur cette app.';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'Effacer';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get clearMessages => 'Effacer les messages';

  @override
  String clearMessagesConfirm(Object count) {
    return 'Supprimer les $count messages de cette discussion ?';
  }

  @override
  String get close => 'Fermer';

  @override
  String get codeCheck => 'Vérification du code';

  @override
  String get codeCheckBody =>
      'Ceci créera une tâche pour que l’agent IA examine votre code et signale les problèmes trouvés.';

  @override
  String get codeCheckRequested => 'Vérification du code demandée';

  @override
  String get codeCheckResults => 'Résultats de la vérification du code';

  @override
  String get codeReview => 'Revue de code';

  @override
  String get codeReviewSubtitle => 'Bugs, crashs, qualité du code';

  @override
  String get complete => 'Terminer';

  @override
  String completedCount(Object count) {
    return 'Terminés ($count)';
  }

  @override
  String get connectToYourServer => 'Se connecter à votre serveur';

  @override
  String get connectYourPhone => 'Connectez votre téléphone';

  @override
  String get connectedSuccessfully => 'Connecté avec succès';

  @override
  String connectedTo(Object server) {
    return 'Connecté à $server';
  }

  @override
  String get connecting => 'Connexion en cours...';

  @override
  String get connectionFailed => 'Échec de la connexion';

  @override
  String get connectionSuccessful => 'Connexion réussie !';

  @override
  String get connectionTimedOut => 'Délai de connexion dépassé';

  @override
  String get consistencyCheck => 'Vérification de cohérence';

  @override
  String get consistencyCheckSubtitle => 'Écarts GDD ↔ code ↔ données';

  @override
  String get consistencyCheckTaskCreated =>
      'Tâche de vérification de cohérence créée';

  @override
  String get console => 'Console';

  @override
  String get contentAudit => 'Audit de contenu';

  @override
  String get contentAuditSubtitle => 'Niveaux, personnages, objets, textes';

  @override
  String get contentAuditTaskCreated => 'Tâche d’audit de contenu créée';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get control => 'Contrôle';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label copié dans le presse-papiers';
  }

  @override
  String get copy => 'Copier';

  @override
  String get copyAiResponse => 'Copier la réponse de l’IA';

  @override
  String get copyDescription => 'Copier la description';

  @override
  String get copyTitle => 'Copier le titre';

  @override
  String get copyUrl => 'Copier l’URL';

  @override
  String get couldNotDownloadPdf => 'Impossible de télécharger le PDF';

  @override
  String get couldNotLoadBuildTargets =>
      'Impossible de charger les cibles de build';

  @override
  String get couldNotLoadDirectives => 'Impossible de charger les directives';

  @override
  String get couldNotOpenLink => 'Impossible d’ouvrir le lien';

  @override
  String couldNotOpenPdf(Object error) {
    return 'Impossible d’ouvrir le PDF : $error';
  }

  @override
  String get couldNotOpenPicker => 'Impossible d’ouvrir le sélecteur.';

  @override
  String get create => 'Créer';

  @override
  String get createApp => 'Créer une app';

  @override
  String get createFirstApp => 'Créez votre première app pour commencer';

  @override
  String get createIssue => 'Créer un signalement';

  @override
  String createdAgo(Object time) {
    return 'créé $time';
  }

  @override
  String get creating => 'Création en cours...';

  @override
  String criticalCount(Object count) {
    return '$count critique(s)';
  }

  @override
  String get customAutomationPromptHint =>
      'Prompt d’automatisation personnalisé...';

  @override
  String get customPrompt => 'Prompt personnalisé';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAutomation => 'Supprimer l’automatisation';

  @override
  String deleteAutomationConfirm(Object app) {
    return 'Supprimer l’automatisation pour $app ?';
  }

  @override
  String get deleteChat => 'Supprimer la discussion';

  @override
  String get deleteChatConfirm => 'Supprimer cette conversation ?';

  @override
  String deleteConfirmTitled(Object title) {
    return 'Supprimer « $title » ?\nCette action est irréversible.';
  }

  @override
  String get deleteFailed => 'Échec de la suppression';

  @override
  String get deleteReportBody =>
      'Cette action supprime définitivement le rapport et ses captures d’écran.';

  @override
  String get deleteReportTitle => 'Supprimer le rapport ?';

  @override
  String get deleted => 'Supprimé';

  @override
  String get dependsOn => 'Dépend de';

  @override
  String get deploy => 'Déployer';

  @override
  String get deployToProduction => 'Déployer en production';

  @override
  String get deployToProductionBody =>
      'Ceci va compiler et publier pour TOUS les utilisateurs sur Google Play.\n\nAssurez-vous d’avoir testé en interne/bêta au préalable.';

  @override
  String get deployToProductionTitle => 'Déployer en production ?';

  @override
  String get descriptionHint => 'Description...';

  @override
  String get designDoc => 'Document de conception';

  @override
  String get designDocHint =>
      'Décrivez la vision de votre app, ses fonctionnalités, ses objectifs...';

  @override
  String get designDocSaved => 'Document de conception enregistré';

  @override
  String get designDocShort => 'Doc de conception';

  @override
  String get designDocSubtitle =>
      'L’IA utilisera ceci comme contexte pour tout le travail sur cette app.';

  @override
  String designDocTitle(Object app) {
    return 'Document de conception - $app';
  }

  @override
  String get designDocument => 'Document de conception';

  @override
  String get designReview => 'Revue de conception';

  @override
  String get designReviewSubtitle => 'GDD, mécaniques, audit UX';

  @override
  String get designReviewTaskCreated => 'Tâche de revue de conception créée';

  @override
  String get details => 'Détails';

  @override
  String get detectingServer => 'Détection du serveur...';

  @override
  String get developer => 'Développeur';

  @override
  String get directServerUrlLan => 'URL directe du serveur (LAN)';

  @override
  String get directiveHistory => 'Historique des directives';

  @override
  String get dismiss => 'Ignorer';

  @override
  String get display => 'Affichage';

  @override
  String get doIt => 'Faire';

  @override
  String get done => 'Terminé';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total terminé(s)';
  }

  @override
  String durationLabelWith(Object seconds) {
    return 'Durée : ${seconds}s';
  }

  @override
  String get edit => 'Modifier';

  @override
  String editNamed(Object label) {
    return 'Modifier $label';
  }

  @override
  String editTitleNamed(Object app) {
    return 'Modifier : $app';
  }

  @override
  String get editWorkerUrl => 'Modifier l’URL du Worker';

  @override
  String get engine => 'Moteur';

  @override
  String engineChanged(Object previous, Object current) {
    return 'Moteur changé : $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'Moteur confirmé : $engine';
  }

  @override
  String get engineDetectionFailed => 'Échec de la détection du moteur';

  @override
  String get enhance => 'Améliorer';

  @override
  String get enhanceConfirmBody =>
      'L’IA va réécrire le document. Cette action est irréversible.';

  @override
  String enhanceConfirmTitle(Object label) {
    return 'Améliorer $label ?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return 'Erreur d’amélioration de $label : $error';
  }

  @override
  String enhanceStarted(Object label) {
    return 'Amélioration de $label démarrée sur le serveur...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label amélioré avec succès';
  }

  @override
  String get enhancementFailed => 'Échec de l’amélioration';

  @override
  String get enterConceptOrName => 'Entrez un concept ou un nom de projet';

  @override
  String get enterServerUrlDesc =>
      'Entrez l’URL de votre serveur Auto Game Builder';

  @override
  String get enterUrlInPhoneApp =>
      'Entrez cette URL dans l’app du téléphone pour vous connecter à distance';

  @override
  String get enterValidUrl =>
      'Entrez une URL valide (ex. http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc =>
      'Entrez l’URL de votre Worker pour vous connecter à distance';

  @override
  String errorWithMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return 'Toutes les $minutes min';
  }

  @override
  String exitLabelWith(Object code) {
    return 'Sortie : $code';
  }

  @override
  String get expandFoldersOrCreate =>
      'Déployez les dossiers ci-dessous ou créez une nouvelle app';

  @override
  String get failed => 'Échoué';

  @override
  String failedCountLabel(Object count) {
    return '$count échoué(s)';
  }

  @override
  String get failedToBrainstorm => 'Échec du brainstorming';

  @override
  String get failedToCreateApp => 'Échec de la création de l’app';

  @override
  String get failedToCreateItem => 'Échec de la création de l’élément';

  @override
  String get failedToCreateTestTask =>
      'Échec de la création de la tâche de test';

  @override
  String get failedToDelete => 'Échec de la suppression';

  @override
  String get failedToLoadApp => 'Échec du chargement de l’app';

  @override
  String get failedToLoadAutomations =>
      'Échec du chargement des automatisations';

  @override
  String get failedToLoadLogs => 'Échec du chargement des journaux';

  @override
  String get failedToLoadTasks => 'Échec du chargement des tâches';

  @override
  String failedToLoadWithError(Object error) {
    return 'Échec du chargement : $error';
  }

  @override
  String get failedToRefreshApp => 'Échec de l’actualisation de l’app';

  @override
  String get failedToRequestCodeCheck =>
      'Échec de la demande de vérification du code';

  @override
  String get failedToRequestIdeas => 'Échec de la demande d’idées';

  @override
  String get failedToReset => 'Échec de la réinitialisation';

  @override
  String get failedToRunTask => 'Échec de l’exécution de la tâche';

  @override
  String failedToSave(Object error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String get failedToStartReupload => 'Échec du démarrage du nouvel envoi';

  @override
  String failedToStartServer(Object error) {
    return 'Échec du démarrage du serveur : $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return 'Échec du démarrage : $error';
  }

  @override
  String failedToTrigger(Object action) {
    return 'Échec du déclenchement de $action';
  }

  @override
  String get failedToTriggerRun => 'Échec du déclenchement de l’exécution';

  @override
  String get failedToUpdate => 'Échec de la mise à jour';

  @override
  String get failedToUpdateAiAgent => 'Échec de la mise à jour de l’agent IA';

  @override
  String get failedToUpdateMcp => 'Échec de la mise à jour du MCP';

  @override
  String get favoritesOnly => 'Favoris uniquement';

  @override
  String get feedback => 'Commentaires';

  @override
  String fileTooLarge(Object max, Object files) {
    return 'Trop volumineux (max $max Mo) : $files';
  }

  @override
  String get filterAll => 'Tout';

  @override
  String get filterClosed => 'Fermés';

  @override
  String get filterOpen => 'Ouverts';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return 'terminé $time';
  }

  @override
  String finishedFailedAgo(Object time) {
    return 'échoué $time';
  }

  @override
  String forceRefreshFailed(Object error) {
    return 'Échec de l’actualisation forcée : $error';
  }

  @override
  String get forceRefreshTooltip =>
      'Forcer l’actualisation depuis le serveur (efface le cache local)';

  @override
  String get fullAutoMode => 'Mode entièrement automatique';

  @override
  String get fullAutoModeOn =>
      'L’IA lit les tâches, corrige, génère de nouvelles idées, et recommence';

  @override
  String get generate => 'Générer';

  @override
  String get generateIdeas => 'Générer des idées';

  @override
  String get generateIdeasHint => 'ex. « Idées pour améliorer l’UI »';

  @override
  String get genre => 'Genre';

  @override
  String get genreAction => 'Action';

  @override
  String get genreAny => 'Tous';

  @override
  String get genreArcade => 'Arcade';

  @override
  String get genreCardGame => 'Jeu de cartes';

  @override
  String get genreIdleClicker => 'Idle/Clicker';

  @override
  String get genrePuzzle => 'Puzzle';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'Simulation';

  @override
  String get genreStrategy => 'Stratégie';

  @override
  String get genreTowerDefense => 'Tower Defense';

  @override
  String get getStarted => 'Commencer';

  @override
  String get googleAccount => 'Compte Google';

  @override
  String get hide => 'Masquer';

  @override
  String highCount(Object count) {
    return '$count élevé(s)';
  }

  @override
  String get ideaGenerationRequested => 'Génération d’idées demandée';

  @override
  String get installed => 'installé';

  @override
  String get intervalMinLabel => 'Intervalle (min) : ';

  @override
  String get invalidQrData => 'Données du QR code invalides';

  @override
  String get issueCreated => 'Signalement créé';

  @override
  String get issueTitleHint => 'Titre du signalement';

  @override
  String get issues => 'Signalements';

  @override
  String get itemCreated => 'Élément créé';

  @override
  String get justNow => 'À l’instant';

  @override
  String get language => 'Langue';

  @override
  String get later => 'Plus tard';

  @override
  String get links => 'Liens';

  @override
  String get loginTagline => 'Gérez vos projets de jeu depuis n’importe où';

  @override
  String get logs => 'Journaux';

  @override
  String get maintenanceOnly => 'Maintenance uniquement';

  @override
  String get markAsCompleted => 'Marquer comme terminé';

  @override
  String get markComplete => 'Marquer terminé';

  @override
  String markCompleteConfirm(Object title) {
    return 'Marquer « $title » comme terminé ?';
  }

  @override
  String get markedAsCompleted => 'Marqué comme terminé';

  @override
  String maxMinutes(Object minutes) {
    return 'Max $minutes min';
  }

  @override
  String get maxSessionMinLabel => 'Session max (min) : ';

  @override
  String get mcpConfiguredPerApp =>
      'Les serveurs MCP sont configurés par app sur la page de détail de l’app.';

  @override
  String get mcpServers => 'Serveurs MCP';

  @override
  String mcpServersActive(Object count) {
    return 'Serveurs MCP ($count actifs)';
  }

  @override
  String get mcpServersDesc =>
      'Serveurs d’outils disponibles pour toutes les exécutions IA sur cette app';

  @override
  String mediumCount(Object count) {
    return '$count moyen(s)';
  }

  @override
  String get moveBackToActive => 'Remettre en actif';

  @override
  String get moveToCompletedFolder => 'Déplacer vers le dossier terminé';

  @override
  String get nameIsRequired => 'Le nom est requis';

  @override
  String get needHelpSettingUp => 'Besoin d’aide pour la configuration ?';

  @override
  String get newApp => 'Nouvelle app';

  @override
  String get newAutomation => 'Nouvelle automatisation';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get newItem => 'Nouvel élément';

  @override
  String get newPrompt => 'Nouveau prompt';

  @override
  String newReportsCount(Object count) {
    return '$count nouveau(x) rapport(s)';
  }

  @override
  String get nextRunIn => 'Prochaine exécution dans';

  @override
  String get noApiKeyFound =>
      'Aucune clé API trouvée — redémarrez le serveur pour en générer une';

  @override
  String get noAppsMatch => 'Aucune app ne correspond';

  @override
  String get noAppsYet => 'Aucune app pour le moment';

  @override
  String get noArtBibleYet =>
      'Aucune bible artistique pour le moment. Appuyez sur Ajouter pour définir l’identité visuelle — palette, typographie, interdits.';

  @override
  String get noAutomationsMatchFilters =>
      'Aucune automatisation ne correspond aux filtres';

  @override
  String get noAutomationsYet => 'Aucune automatisation pour le moment';

  @override
  String noBuildTargetsFor(Object type) {
    return 'Aucune cible de build pour les projets $type.';
  }

  @override
  String get noBuildsYet => 'Aucun build pour le moment';

  @override
  String get noChatsYet => 'Aucune discussion pour le moment';

  @override
  String get noClaudeMdYet =>
      'Aucun CLAUDE.md pour le moment. Appuyez sur Ajouter pour définir les instructions du projet pour l’IA.';

  @override
  String get noDesignDocYet =>
      'Aucun document de conception pour le moment. Appuyez sur Ajouter pour décrire la vision de votre app.';

  @override
  String get noDirectivesYet => 'Aucune directive envoyée pour le moment.';

  @override
  String get noFavoritePrompts => 'Aucun prompt favori pour le moment';

  @override
  String get noItemsFound => 'Aucun élément trouvé';

  @override
  String get noLogsFound => 'Aucun journal trouvé';

  @override
  String get noNewReports => 'Aucun nouveau rapport';

  @override
  String get noOpenReports => 'Aucun rapport ouvert';

  @override
  String get noOpenTasksToDependOn => 'Aucune tâche ouverte dont dépendre';

  @override
  String get noPendingItems => 'Aucun élément en attente à traiter';

  @override
  String get noPromptHistory =>
      'Aucun historique de prompts pour le moment.\nGénérez des idées pour créer l’historique.';

  @override
  String get noReportsHere => 'Aucun rapport ici';

  @override
  String get noWorkerUrlDetected =>
      'Aucune URL de Worker détectée dans settings.json.\nConfigurez un Cloudflare Worker pour activer l’accès à distance.';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get notConfigured => 'Non configuré';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get notInstalled => 'non installé';

  @override
  String get notPaired => 'Non jumelé';

  @override
  String get notSet => '(non défini)';

  @override
  String get notYetUploaded => 'pas encore envoyé';

  @override
  String get onHold => 'En pause';

  @override
  String get oneShotRunEndsIn => 'L’exécution unique se termine dans';

  @override
  String oneTimeRunTriggered(Object app) {
    return 'Exécution unique déclenchée pour $app';
  }

  @override
  String openCountLabel(Object count) {
    return '$count ouvert(s)';
  }

  @override
  String get openPdf => 'Ouvrir le PDF';

  @override
  String get openingPdf => 'Ouverture du PDF…';

  @override
  String get orSeparator => 'OU';

  @override
  String get output => 'Sortie';

  @override
  String get packageName => 'Nom du package';

  @override
  String get paired => 'Jumelé';

  @override
  String get pairedSuccessfully => 'Jumelage réussi !';

  @override
  String get perfProfileTaskCreated =>
      'Tâche de profilage de performance créée';

  @override
  String get performanceProfile => 'Profil de performance';

  @override
  String get performanceProfileSubtitle =>
      'Baisses de fps, mémoire, temps de chargement';

  @override
  String get photo => 'Photo';

  @override
  String get postpone => 'Reporter';

  @override
  String postponedCount(Object count) {
    return 'Reportés ($count)';
  }

  @override
  String get pressBackAgainToExit =>
      'Appuyez à nouveau sur retour pour quitter';

  @override
  String get previousChat => 'Discussion précédente';

  @override
  String get priority => 'Priorité';

  @override
  String processingTasks(Object done, Object total) {
    return 'Traitement de $done sur $total tâches...';
  }

  @override
  String get projectPath => 'Chemin du projet';

  @override
  String get promptHistory => 'Historique des prompts';

  @override
  String get promptHistoryTooltip => 'Historique des prompts';

  @override
  String get publish => 'Publier';

  @override
  String get pullAndRebuild => 'Récupérer et recompiler';

  @override
  String get pullFailed => 'Échec de la récupération';

  @override
  String get pullNow => 'Récupérer maintenant';

  @override
  String get pullOnly => 'Récupérer seulement';

  @override
  String purchaseFailed(Object error) {
    return 'Échec de l’achat : $error';
  }

  @override
  String get putOnHoldForLater => 'Mettre en pause pour plus tard';

  @override
  String get pythonSectionDesc =>
      'Exécutez des scripts et gérez le projet Python via le serveur.';

  @override
  String get quickIssue => 'Signalement rapide';

  @override
  String get rePairWithQr => 'Re-jumeler avec un QR Code';

  @override
  String get rebuild => 'Recompiler';

  @override
  String get rebuildBody => 'Démarrer un nouveau build à partir de zéro ?';

  @override
  String get rebuildTitle => 'Recompiler ?';

  @override
  String get recentBuilds => 'Builds récents';

  @override
  String get refresh => 'Actualiser';

  @override
  String refreshFailedShowingCached(Object message) {
    return 'Échec de l’actualisation — affichage des dernières données synchronisées. $message';
  }

  @override
  String get refreshedFromServer => 'Actualisé depuis le serveur';

  @override
  String get reload => 'Recharger';

  @override
  String get reopen => 'Rouvrir';

  @override
  String get reportBugOrSuggestion => 'Signaler un bug / une suggestion';

  @override
  String get reportBugSubtitle => 'Dites-nous quoi corriger ou ajouter';

  @override
  String get reportConsent =>
      'J’accepte d’envoyer ce rapport avec les infos de mon appareil (modèle, OS et version de l’app) au développeur pour aider à résoudre les problèmes.';

  @override
  String get reportHint =>
      'Que s’est-il passé, ou que souhaiteriez-vous voir ?';

  @override
  String get reportSentThanks => 'Merci ! Votre rapport a été envoyé.';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get resetServer => 'Réinitialiser le serveur';

  @override
  String get resetServerBody => 'Ceci redémarrera le serveur backend.';

  @override
  String resetServerRunningNote(Object count) {
    return '$count automatisation(s) en cours seront d’abord arrêtées pour éviter un redémarrage automatique.';
  }

  @override
  String get resumeActiveDevelopment => 'Reprendre le développement actif';

  @override
  String get retry => 'Réessayer';

  @override
  String get retryUpload => 'Réessayer l’envoi';

  @override
  String get reuploadStarted => 'Nouvel envoi démarré';

  @override
  String get run => 'Exécuter';

  @override
  String get runAgainBody =>
      'Une exécution unique est déjà en cours mais l’IA a peut-être arrêté prématurément. Déclencher une nouvelle exécution ?';

  @override
  String get runAgainTitle => 'Relancer ?';

  @override
  String get runAnyway => 'Exécuter quand même';

  @override
  String get runCheck => 'Lancer la vérification';

  @override
  String get runOnce => 'Exécuter une fois';

  @override
  String get runOnceInProgress => 'Exécution unique (en cours)';

  @override
  String get running => 'En cours';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get saveEmptyGddBody =>
      'Ceci effacera le document de conception actuel.';

  @override
  String get saveEmptyGddTitle => 'Enregistrer un GDD vide ?';

  @override
  String get saving => 'Enregistrement...';

  @override
  String scanError(Object error) {
    return 'Erreur de scan : $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'Échec du scan : le serveur a renvoyé $status';
  }

  @override
  String get scanForProjects => 'Rechercher des projets';

  @override
  String get scanPairingQrTitle => 'Scanner le QR code de jumelage';

  @override
  String get scanQrToPair => 'Scanner le QR code pour jumeler';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return '$found dossiers scannés : $imported importés, $skipped ignorés';
  }

  @override
  String get scanThisQr => 'Scannez ce QR code depuis votre téléphone';

  @override
  String get scanToInstall => 'Scannez pour installer sur votre téléphone';

  @override
  String get scopeCheck => 'Vérification du périmètre';

  @override
  String get scopeCheckSubtitle =>
      'Liste des éléments à couper + passage de réalisme';

  @override
  String get scopeCheckTaskCreated =>
      'Tâche de vérification du périmètre créée';

  @override
  String get screenshotsOptional => 'Captures d’écran (facultatif)';

  @override
  String get screenshotsTooLarge =>
      'Les captures d’écran sont volumineuses — vous devrez peut-être en retirer une.';

  @override
  String get searchAppsHint => 'Rechercher des apps...';

  @override
  String searchFilterChip(Object query) {
    return 'Recherche : « $query »';
  }

  @override
  String get searchHint => 'Rechercher...';

  @override
  String get sectionAiAgents => 'Agents IA';

  @override
  String get sectionGameEngines => 'Moteurs de jeu';

  @override
  String get sectionPaths => 'Chemins';

  @override
  String get sectionServices => 'Services';

  @override
  String get sectionSystemTools => 'Outils système';

  @override
  String get selectAnApp => 'Sélectionnez une app';

  @override
  String get selectAnAppFirst => 'Sélectionnez d’abord une app';

  @override
  String get selectApp => 'Sélectionner une app';

  @override
  String get selectAppForContext =>
      'Sélectionnez une app pour le contexte, ou posez des questions générales';

  @override
  String get selectAppToViewItems =>
      'Sélectionnez une app pour voir les éléments';

  @override
  String get selectCategoriesOrPrompt =>
      'Sélectionnez des catégories ou saisissez votre propre prompt.';

  @override
  String get sendReport => 'Envoyer le rapport';

  @override
  String get sending => 'Envoi en cours…';

  @override
  String get server => 'Serveur';

  @override
  String get serverConfiguration => 'Configuration du serveur';

  @override
  String get serverConnection => 'Connexion au serveur';

  @override
  String serverReturnedStatus(Object status) {
    return 'Le serveur a renvoyé le statut $status';
  }

  @override
  String get serverStarted => 'Serveur démarré !';

  @override
  String get serverStartedHealthFailed =>
      'Serveur démarré mais le contrôle de santé a échoué';

  @override
  String get serverStopped => 'Serveur arrêté';

  @override
  String get serverUnreachable => 'Serveur injoignable';

  @override
  String get serverUrl => 'URL du serveur';

  @override
  String get sessionEndsIn => 'La session se termine dans';

  @override
  String get sessionRefreshed =>
      'Session actualisée — contexte récent conservé';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsJsonNotFound => 'settings.json introuvable';

  @override
  String get settingsJsonRestartNote =>
      'settings.json — redémarrez le serveur après modification';

  @override
  String get settingsSavedRestart =>
      'Paramètres enregistrés — redémarrez le serveur pour appliquer';

  @override
  String get setupInstructions => 'Instructions de configuration';

  @override
  String get setupServerFirst => 'Configurez d’abord le serveur sur votre PC';

  @override
  String get setupStepCloneRepo => 'Clonez le dépôt :';

  @override
  String get setupStepEnterUrl =>
      'Entrez l’URL affichée dans le terminal (ex. http://192.168.1.100:8000) :';

  @override
  String get setupStepInstallDeps => 'Installez les dépendances :';

  @override
  String get setupStepInstallPython => 'Installez Python 3.10+ sur votre PC';

  @override
  String get setupStepRunWizard => 'Exécutez l’assistant de configuration :';

  @override
  String get setupStepStartServer => 'Démarrez le serveur :';

  @override
  String get show => 'Afficher';

  @override
  String get showAll => 'Tout afficher';

  @override
  String get showAppIcons => 'Afficher les icônes des apps';

  @override
  String get showAppIconsDesc =>
      'Afficher les vraies icônes des apps sur le tableau de bord au lieu d’icônes génériques par type';

  @override
  String get showPairingQr => 'Afficher le QR code de jumelage';

  @override
  String get signInCancelled => 'Connexion annulée';

  @override
  String signInFailed(Object error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signingIn => 'Connexion en cours...';

  @override
  String get skipForNow => 'Passer pour l’instant';

  @override
  String get start => 'Démarrer';

  @override
  String get startBuildFromCardAbove =>
      'Démarrez un build depuis la carte ci-dessus';

  @override
  String get startServer => 'Démarrer le serveur';

  @override
  String get startServerNotFound => 'start_server.py introuvable';

  @override
  String get status => 'Statut';

  @override
  String get statusActive => 'Actif';

  @override
  String get statusAll => 'Tous';

  @override
  String get statusBuilt => 'Compilé';

  @override
  String get statusBuiltLower => 'Compilé';

  @override
  String get statusCompleted => 'Terminé';

  @override
  String get statusDivided => 'Divisé';

  @override
  String get statusDone => 'Fait';

  @override
  String get statusFailedLower => 'Échoué';

  @override
  String statusFilterChip(Object value) {
    return 'Statut : $value';
  }

  @override
  String get statusInProgress => 'En cours';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusPendingLower => 'En attente';

  @override
  String get statusPostponed => 'Reporté';

  @override
  String get stop => 'Arrêter';

  @override
  String get stopServer => 'Arrêter le serveur';

  @override
  String get stoppedLabel => 'Arrêté';

  @override
  String stuckSuffix(Object time) {
    return '$time BLOQUÉ';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return '$count tâche(s) bloquée(s) automatiquement échouée(s) après un délai de 30 min';
  }

  @override
  String get studioReviews => 'Revues du studio';

  @override
  String get submit => 'Envoyer';

  @override
  String get submitting => 'Envoi en cours...';

  @override
  String get suggestApiBackend => 'API & Backend';

  @override
  String get suggestFeatureIntegration => 'Intégration de fonctionnalités';

  @override
  String get suggestFixFailures => 'Corriger les échecs';

  @override
  String get suggestGddAligned => 'Aligné sur le GDD';

  @override
  String get suggestImproveCodebase => 'Améliorer le code';

  @override
  String get suggestNextMilestone => 'Prochain jalon';

  @override
  String get suggestPerformanceBoost => 'Amélioration des performances';

  @override
  String get suggestRevenueIdeas => 'Idées de revenus';

  @override
  String get suggestSecurityHardening => 'Renforcement de la sécurité';

  @override
  String get suggestTaskPrioritization => 'Priorisation des tâches';

  @override
  String get suggestTestingQa => 'Tests & QA';

  @override
  String get suggestUserEngagement => 'Engagement utilisateur';

  @override
  String get suggestUxPolish => 'Finitions UX';

  @override
  String get suggestedForYou => 'Suggéré pour vous';

  @override
  String get summary => 'Résumé';

  @override
  String get supportDevelopment => 'Soutenir le développement';

  @override
  String get supportDevelopmentDesc =>
      'Vous appréciez l’app ? Pensez à soutenir son développement !';

  @override
  String get syncFailed => 'Échec de la synchronisation';

  @override
  String syncedAgo(Object time) {
    return 'Synchronisé $time';
  }

  @override
  String get tapPlusToCreateAutomation =>
      'Appuyez sur + pour créer votre première automatisation';

  @override
  String get tapPlusToStartConversation =>
      'Appuyez sur + pour démarrer une conversation';

  @override
  String get tapToAddLongPressToEdit =>
      'Appuyez pour ajouter, appui long pour modifier';

  @override
  String get tapToOpenLongPressToEdit =>
      'Appuyez pour ouvrir, appui long pour modifier';

  @override
  String get tapToRedetectEngine =>
      'Appuyez pour redétecter le moteur depuis le disque';

  @override
  String taskLabelWith(Object task) {
    return 'Tâche : $task';
  }

  @override
  String get taskOverview => 'Aperçu des tâches';

  @override
  String get taskResetToPending => 'Tâche réinitialisée en attente';

  @override
  String get tasks => 'Tâches';

  @override
  String get techDebtScan => 'Analyse de la dette technique';

  @override
  String get techDebtScanSubtitle => 'Scripts monolithiques, doublons, TODO';

  @override
  String get techDebtTaskCreated =>
      'Tâche d’analyse de la dette technique créée';

  @override
  String get tellUsMore => 'Dites-nous en plus';

  @override
  String get test => 'Test';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get testTaskCreated => 'Tâche de test créée';

  @override
  String get testing => 'Test en cours...';

  @override
  String get theme => 'Thème';

  @override
  String get thinking => 'Réflexion en cours...';

  @override
  String timeDaysAgo(Object days) {
    return 'il y a $days j';
  }

  @override
  String timeHoursAgo(Object hours) {
    return 'il y a $hours h';
  }

  @override
  String get timeJustNow => 'à l’instant';

  @override
  String timeMinutesAgo(Object minutes) {
    return 'il y a $minutes min';
  }

  @override
  String timeMonthsAgo(Object months) {
    return 'il y a $months mois';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return 'il y a $seconds s';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return 'il y a $weeks sem';
  }

  @override
  String get titleHint => 'Titre';

  @override
  String get titleIsRequired => 'Le titre est requis';

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
    return '$done éléments déclenchés sur $total';
  }

  @override
  String get tryChangingFilters =>
      'Essayez de changer le filtre de catégorie ou de statut';

  @override
  String get type => 'Type';

  @override
  String get typeBug => 'Bug';

  @override
  String get typeFeature => 'Fonctionnalité';

  @override
  String typeFilterChip(Object value) {
    return 'Type : $value';
  }

  @override
  String get typeFix => 'Correction';

  @override
  String get typeIdea => 'Idée';

  @override
  String get typeIssue => 'Signalement';

  @override
  String get updateAvailable => 'Mise à jour disponible';

  @override
  String get updateAvailableBody =>
      'Une nouvelle version est disponible sur GitHub.\nRécupérez le dernier code et recompilez pour mettre à jour.';

  @override
  String get updateFailed => 'Échec de la mise à jour';

  @override
  String updatedAgo(Object time) {
    return 'mis à jour $time';
  }

  @override
  String updatedNamed(Object label) {
    return '$label mis à jour';
  }

  @override
  String get uploadToGooglePlay => 'Envoyer vers Google Play';

  @override
  String urgentCountLabel(Object count) {
    return '$count urgent(s)';
  }

  @override
  String get urgentLabel => 'urgent';

  @override
  String get userFallback => 'Utilisateur';

  @override
  String get version => 'Version';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => 'Voir les tâches échouées';

  @override
  String get viewIssues => 'Voir les signalements';

  @override
  String get viewOnGitHub => 'Voir sur GitHub';

  @override
  String get warningPublishesToAll =>
      'Attention : ceci publie pour tous les utilisateurs !';

  @override
  String get webDeploy => 'Déploiement web';

  @override
  String get webDeploySectionDesc =>
      'Compilez et déployez l’app web via le serveur.';

  @override
  String get website => 'Site web';

  @override
  String get whatIsThis => 'Qu’est-ce que c’est ?';

  @override
  String get workOnAll => 'Travailler sur tout';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n($count élément(s) bloqué(s) seront ignorés.)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return 'Exécuter l’IA sur les $count élément(s) en attente ?\nIls seront traités séquentiellement.';
  }

  @override
  String get workOnAllPending => 'Travailler sur tout ce qui est en attente';

  @override
  String get workOnThis => 'Travailler sur ceci';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return 'Exécuter l’IA $agent sur :\n« $title »';
  }

  @override
  String get workerUrl => 'URL du Worker';

  @override
  String get workerUrlAutoDetected =>
      'Détecté automatiquement depuis settings.json (lecture seule)';

  @override
  String get workerUrlCopied => 'URL du Worker copiée';

  @override
  String get workerUrlHelp =>
      'Obtenez cette URL depuis l’app de bureau ou l’administrateur de votre serveur';

  @override
  String get workerUrlSaved => 'URL du Worker enregistrée';

  @override
  String get workerUrlSetHint =>
      'Définissez cloudflare.worker_url dans server/config/settings.json';

  @override
  String get youreAllSet => 'Tout est prêt !';
}

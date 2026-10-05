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
  String get shareUsageStats => 'Partager des statistiques d\'usage anonymes';

  @override
  String get shareUsageStatsDesc =>
      'Comptages anonymes des sessions et des écrans ouverts. Aucun nom de projet, aucun texte de tâche, aucun chemin.';

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

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'Aucun AGENTS.md pour le moment. Appuyez sur Ajouter pour définir les instructions du projet pour l’IA.';

  @override
  String get cannotSaveEmptyAgentsMd =>
      'Impossible d’enregistrer un AGENTS.md vide';

  @override
  String get agentsMdSaved => 'AGENTS.md enregistré';

  @override
  String get reportEmailLabel => 'E-mail (facultatif)';

  @override
  String get reportEmailHint => 'votre e-mail, si vous voulez une réponse';

  @override
  String get reportEmailNote =>
      'Utilisé uniquement pour répondre à ce signalement. Laissez vide pour rester anonyme.';

  @override
  String get reportEmailInvalid =>
      'Cela ne ressemble pas à une adresse e-mail.';

  @override
  String get reportReply => 'Répondre';

  @override
  String reportReplySubject(String app) {
    return 'À propos de votre signalement sur $app';
  }

  @override
  String get navGenerate => 'Générer';

  @override
  String get navGallery => 'Générés';

  @override
  String get navFlow => 'Chaîne';

  @override
  String get navQueue => 'File';

  @override
  String get navDelivery => 'Diffusion';

  @override
  String get navBuckets => 'Buckets';

  @override
  String get assetModeTooltip => 'Mode ressources';

  @override
  String get deliveryModeTooltip => 'Mode diffusion';

  @override
  String get videoPlaybackFailed => 'Impossible de lire la vidéo';

  @override
  String get apiKeyRefusedBanner =>
      'Clé API refusée - touchez pour la corriger dans les Réglages';

  @override
  String get errOffline => 'Serveur injoignable - vérifiez votre connexion';

  @override
  String get errTimeout =>
      'Le serveur a mis trop de temps à répondre - réessayez';

  @override
  String errGatewayTimeout(int status) {
    return 'Le serveur n\'a pas répondu à temps (délai de passerelle dépassé $status)';
  }

  @override
  String errGateway(int status) {
    return 'Le serveur est injoignable derrière sa passerelle (erreur de passerelle $status) - vérifiez qu\'il tourne';
  }

  @override
  String errServer(int status) {
    return 'Erreur du serveur ($status) - réessayez plus tard';
  }

  @override
  String errUnauthorized(int status) {
    return 'Non autorisé ($status) - vérifiez la clé API dans les Réglages';
  }

  @override
  String errNotFound(int status) {
    return 'Introuvable sur le serveur ($status)';
  }

  @override
  String errRateLimited(int status) {
    return 'Trop de requêtes ($status) - patientez un instant puis réessayez';
  }

  @override
  String errTooLarge(int status) {
    return 'Trop volumineux pour le serveur ($status)';
  }

  @override
  String errRejected(int status) {
    return 'Le serveur a refusé la requête ($status)';
  }

  @override
  String get errBadResponse =>
      'Le serveur a envoyé une réponse que l\'application n\'a pas pu lire';

  @override
  String get errUnknown => 'La requête a échoué - réessayez';

  @override
  String bucketsCounting(String bucket) {
    return 'Comptage de $bucket...';
  }

  @override
  String get bucketsTakedownTitle => 'Retrait (nouveau + ancien)';

  @override
  String get bucketsDeleteForeverTitle => 'Supprimer définitivement';

  @override
  String bucketsDeleteWarning(int count) {
    return '$count objets seront supprimés. CETTE ACTION EST IRRÉVERSIBLE.';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count clés n\'ont pas d\'équivalent dans l\'ancien jumeau - elles ne sont supprimées que de ce bucket.';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return 'Saisissez le nom du bucket pour confirmer : $bucket';
  }

  @override
  String get bucketsTakedown => 'Retirer';

  @override
  String bucketsDeleted(int count) {
    return '$count objets supprimés';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count objets supprimés, dont $twin dans l\'ancien jumeau';
  }

  @override
  String bucketsCopySource(String path) {
    return 'Source : $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'Arborescence source : $path';
  }

  @override
  String get bucketsWholeBucket => '(tout le bucket)';

  @override
  String get bucketsCopyNote =>
      'La copie s\'exécute dans le service de stockage - aucun octet ne transite par le téléphone.';

  @override
  String get bucketsTargetKey => 'Clé de destination';

  @override
  String get bucketsTargetPrefix => 'Préfixe de destination';

  @override
  String bucketsCopyStarted(String op) {
    return 'Copie lancée ($op)';
  }

  @override
  String get bucketsFixHeadersTitle => 'Corriger les en-têtes';

  @override
  String bucketsFixHeadersBody(String path) {
    return 'L\'en-tête Cache-Control des objets sous $path est vérifié ; un objet qui s\'écarte du standard est réécrit sur place (Content-Type est conservé). Aucun octet n\'est téléchargé.\n\nLes préfixes laissés modifiables volontairement sont ignorés.';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'Réparation des en-têtes lancée ($op)';
  }

  @override
  String get bucketsOperations => 'Opérations';

  @override
  String get bucketsNoOperations => 'Aucune opération pour l\'instant';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  ok $ok  ·  échecs $failed';
  }

  @override
  String get bucketsTwinDiffRunning => 'Calcul de l\'écart avec le jumeau...';

  @override
  String get bucketsLocalDiffRunning => 'Calcul de l\'écart local...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin (ancien jumeau)';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'Dossier local envoyé <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => 'Absent de l\'ancien jumeau';

  @override
  String get bucketsMissingInBucket => 'Absent du bucket';

  @override
  String get bucketsOnlyInLegacy => 'Uniquement dans l\'ancien jumeau';

  @override
  String get bucketsOnlyInBucket => 'Uniquement dans le bucket';

  @override
  String get bucketsSizeMismatch => 'Taille différente';

  @override
  String get bucketsUnmapped => 'Sans correspondance (aucune règle)';

  @override
  String get bucketsDerived => 'Généré dans le bucket (vignettes)';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title : $count';
  }

  @override
  String get bucketsFixFolderHeaders => 'Corriger les en-têtes de ce dossier';

  @override
  String get bucketsDiffs => 'Écarts';

  @override
  String get bucketsTwinDiff => 'Écart avec l\'ancien jumeau';

  @override
  String get bucketsLocalDiff => 'Écart avec le dossier local envoyé';

  @override
  String get bucketsIntro =>
      'Un bucket est le dépôt qui porte le nom de son contenu. Les décomptes sont calculés à la demande (simple listage, aucun octet téléchargé).';

  @override
  String get bucketsBadgeLegacy => 'ANCIEN';

  @override
  String get bucketsBadgePrivate => 'privé';

  @override
  String get bucketsBadgeContent => 'contenu';

  @override
  String get bucketsNotCounted => 'non compté';

  @override
  String bucketsObjectCount(int count) {
    return '$count objets';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'jumeau : $twin';
  }

  @override
  String get bucketsCount => 'Compter';

  @override
  String get bucketsEmptyFolder => 'Ce dossier est vide';

  @override
  String get bucketsTruncated =>
      'La liste a été tronquée - ouvrez un dossier plus précis';

  @override
  String bucketsSelectedCount(int count) {
    return '$count sélectionnés';
  }

  @override
  String get bucketsClearSelection => 'Effacer la sélection';

  @override
  String get bucketsTakedownTooltip =>
      'Retrait (supprimer aussi de l\'ancien jumeau)';

  @override
  String get bucketsSize => 'Taille';

  @override
  String get bucketsContentType => 'Type';

  @override
  String get bucketsModified => 'Modifié';

  @override
  String get bucketsNone => '(aucun)';

  @override
  String get bucketsMutableOnPurpose =>
      'Modifiable volontairement - aucun standard ne s\'applique';

  @override
  String bucketsHeaderOk(String kind) {
    return 'Conforme au standard de cache ($kind)';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return 'Standard : $expected';
  }

  @override
  String get bucketsLegacyTwin => 'Ancien jumeau';

  @override
  String get bucketsAddressCopied => 'Adresse copiée';

  @override
  String get bucketsCopyAddress => 'Copier l\'adresse';

  @override
  String get bucketsOpen => 'Ouvrir';

  @override
  String get bucketsPrivateNoAddress =>
      'Ce bucket est privé - il n\'a pas d\'adresse publique';

  @override
  String get kindCard => 'Carte';

  @override
  String get kindCharacter => 'Personnage';

  @override
  String get assetCodeMode => 'Mode code';

  @override
  String get assetPickFinishedImage => 'Sélectionnez une image terminée';

  @override
  String get assetGenerateVideo => 'Générer une vidéo';

  @override
  String get assetEnlarge => 'Agrandir';

  @override
  String percentValue(Object value) {
    return '$value %';
  }

  @override
  String get commonCategory => 'Catégorie';

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
  String get charKindFemale => 'Femme';

  @override
  String get charKindMale => 'Homme';

  @override
  String get charKindAnimal => 'Animal';

  @override
  String get charKindMachine => 'Machine';

  @override
  String get outfitCatSet => 'Ensemble';

  @override
  String get outfitCatTop => 'Haut';

  @override
  String get outfitCatBottom => 'Bas';

  @override
  String get outfitCatShoes => 'Chaussures';

  @override
  String get outfitCatSocks => 'Chaussettes';

  @override
  String get outfitCatHat => 'Chapeau';

  @override
  String get outfitCatHeadgear => 'Coiffe';

  @override
  String get outfitCatAccessory => 'Accessoire';

  @override
  String get outfitCatWeapon => 'Arme';

  @override
  String get audioLabel => 'Audio';

  @override
  String get audioDownloading => 'Téléchargement...';

  @override
  String get audioOpen => 'Ouvrir l’audio';

  @override
  String get outfitExtractTitle => 'Extraire la tenue';

  @override
  String get outfitExtractBody =>
      'La personne de l’image sélectionnée est retirée et la tenue est enregistrée dans la garde-robe comme photo produit sur mannequin invisible, sur fond gris uni. Ensuite, n’importe quel personnage peut la porter comme skin.';

  @override
  String get outfitExtractName => 'Nom de la tenue';

  @override
  String get outfitExtractNameHint => 'p. ex. Robe de soirée rouge';

  @override
  String get outfitExtractNote => 'Note (facultatif)';

  @override
  String get outfitExtractNoteHint =>
      'p. ex. seulement la robe, sans les chaussures';

  @override
  String get outfitExtractHelp =>
      'Ensemble : tout ce que porte la personne, en une seule image. Arme / accessoire : uniquement cet objet, sans mannequin.';

  @override
  String get outfitExtractAction => 'Extraire';

  @override
  String equipSlotTitle(Object category) {
    return 'Emplacement : $category';
  }

  @override
  String get equipSlotMultiHint =>
      'choix multiple - touchez pour mettre / retirer';

  @override
  String get equipSlotSingleHint =>
      'choix unique - touchez pour mettre, touchez à nouveau pour retirer';

  @override
  String get equipSlotEmpty => '(vide)';

  @override
  String get equipSlotNoOutfits =>
      'Aucune tenue prête dans cette catégorie - utilisez « + Générer une tenue » ou « Extraire la tenue »';

  @override
  String get equipBaseLabel => 'Base :';

  @override
  String get equipUndress => 'Tout retirer';

  @override
  String get equipPickSourceTitle => 'Choisir une image source';

  @override
  String get equipPickSourceHint =>
      'Les dernières générations terminées (tous les modes). Pour les images incoming / staging / pushed de la chaîne Jigsaw, utilisez l’écran Chaîne > Jigsaw.';

  @override
  String get equipNoFinishedImage => 'Aucune image terminée';

  @override
  String get freeFlowTitle => 'Chaîne Free';

  @override
  String get freeFlowEditTitle => 'Modifier - moteur d’édition';

  @override
  String get freeFlowEditLabel => 'Que faut-il changer';

  @override
  String get freeFlowEditHint =>
      'p. ex. change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => 'Modification ajoutée à la file';

  @override
  String get freeFlowNoVideoTask => 'Le mode Free n’a pas de tâche vidéo';

  @override
  String freeFlowVideoTitle(Object task) {
    return 'Générer une vidéo - $task';
  }

  @override
  String get freeFlowMotionLabel => 'Mouvement';

  @override
  String get freeFlowMotionHint =>
      'p. ex. she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued =>
      'Vidéo ajoutée à la file - une icône de lecture apparaîtra sur cette carte une fois terminée';

  @override
  String get freeFlowDeleteConfirm => 'Supprimer cette génération ?';

  @override
  String get freeFlowDeleteWithVideosConfirm =>
      'Supprimer cette génération et ses vidéos ?';

  @override
  String get freeFlowEmpty =>
      'Rien n’a encore été généré en mode Free - commencez depuis l’onglet Générer';

  @override
  String get queueKindGeneration => 'Génération';

  @override
  String get queueKindTag => 'Étiquetage';

  @override
  String get queueKindMusic => 'Musique';

  @override
  String get queueKindJob => 'Tâche';

  @override
  String get queueCancelRunningTitle => 'Annuler la tâche en cours';

  @override
  String get queueRemoveTitle => 'Retirer de la file';

  @override
  String get queueCancelIt => 'Annuler';

  @override
  String get queueClearTitle => 'Vider la file';

  @override
  String get queueClearBody =>
      'Annuler les tâches de génération en attente ? La tâche en cours continue.';

  @override
  String get queueCancelWaiting => 'Annuler les tâches en attente';

  @override
  String get queueEmpty => 'La file est vide';

  @override
  String get queueEmptyHint =>
      'Vous pouvez ajouter des tâches depuis l’onglet Générer';

  @override
  String get queueNow => 'En cours';

  @override
  String queueWaitingCount(Object count) {
    return 'En attente ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return 'Tâches de génération ($count)';
  }

  @override
  String get queueOneQueue => 'Une seule file - toutes les tâches';

  @override
  String queueJobCount(Object count) {
    return '$count tâches';
  }

  @override
  String get queueMoveUp => 'Monter';

  @override
  String get queueMoveDown => 'Descendre';

  @override
  String get queueUp => 'Haut';

  @override
  String get queueDown => 'Bas';

  @override
  String queueElapsed(Object time) {
    return 'écoulé $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return 'en attente $time';
  }

  @override
  String get queueWaiting => 'en attente';

  @override
  String get queueComfyReady => 'ComfyUI prêt';

  @override
  String get queueComfyOff => 'ComfyUI est arrêté';

  @override
  String get deliveryPoolNeverRan => 'jamais exécuté';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (essai à blanc)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · $total images, $valid valides, $tagged étiquetées, $failed échouées';
  }

  @override
  String get reportErrEmpty => 'Veuillez d’abord écrire un message.';

  @override
  String get reportErrTooLarge =>
      'Les pièces jointes sont trop volumineuses. Retirez-en une et réessayez.';

  @override
  String flowOpError(Object message) {
    return 'Échec de l’opération : $message';
  }

  @override
  String get flowOpCancelled => 'Opération annulée';

  @override
  String flowOpDone(Object ok) {
    return '$ok terminés';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok terminés, $failed échoués';
  }

  @override
  String get flowCollection => 'Collection';

  @override
  String get flowAllParen => '(toutes)';

  @override
  String get flowAll => 'toutes';

  @override
  String get flowSelectAll => 'Tout sélectionner';

  @override
  String get flowRetag => 'Réétiqueter';

  @override
  String get flowRetagShort => 'Étiqueter';

  @override
  String get flowRetagStarted => 'Étiquetage lancé';

  @override
  String get flowReadOnly => 'Lecture seule';

  @override
  String get flowPush => 'Push';

  @override
  String get flowPreview => 'Aperçu';

  @override
  String get flowYes => 'oui';

  @override
  String get flowNo => 'non';

  @override
  String get flowMissingUpper => 'ABSENT';

  @override
  String get flowBadgeNoTags => 'sans étiquettes';

  @override
  String get flowTabPushed => '4 Publiés';

  @override
  String get flowSelectAssetFirst => 'Sélectionnez d’abord une ressource';

  @override
  String get flowAccept => 'Accepter';

  @override
  String get flowReject => 'Rejeter';

  @override
  String get flowUpload => 'Envoyer';

  @override
  String get flowNew => 'Nouvelle';

  @override
  String get flowReadFailed => 'Impossible de lire la chaîne';

  @override
  String flowFilesDeleted(Object count) {
    return '$count fichiers supprimés';
  }

  @override
  String get flowNegative => 'Négatif';

  @override
  String get flowPositive2 => 'Positif 2';

  @override
  String get flowDuration => 'Durée';

  @override
  String get flowAddToQueue => 'Ajouter à la file';

  @override
  String get commonDescription => 'Description';

  @override
  String get cbnFlowTitle => 'Chaîne CBN';

  @override
  String get cbnFlowTabIncoming => '2 Entrants';

  @override
  String get cbnFlowTabReady => '3 Prêts';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'Construire - $count ressources';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      'Régions + palette + modèle numéroté + vidéo reveal (CPU). L’étape SAM doit déjà être faite ; les contours viennent des limites SAM. (Hot : la construction génère elle-même la page de traits avec Qwen ; l’étape C est un aperçu facultatif.)';

  @override
  String get cbnFlowBuildBodyKid =>
      'Régions + palette + modèle numéroté + SVG (CPU). L’étape SAM doit déjà être faite.';

  @override
  String get cbnFlowBuild => 'Construire';

  @override
  String get cbnFlowBuildStarted =>
      'Construction lancée - la progression s’affiche en haut';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stage lancé ($count ressources)';
  }

  @override
  String get cbnFlowStageObjects => 'Liste d’objets';

  @override
  String get cbnFlowLineart => 'Traits';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'Push - $count ressources';
  }

  @override
  String get cbnFlowPushBody =>
      'Les dossiers de ressources seront envoyés vers R2 et déplacés dans « Publiés ».\n\nC’est une PUBLICATION, irréversible.';

  @override
  String cbnFlowDeleteBody(Object count) {
    return '$count ressources seront supprimées.';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count supprimés';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'Aucune ressource à cette étape.\nEnvoyez-les ici avec ACCEPTER en mode CBN depuis l’écran « Générés ».';

  @override
  String get cbnFlowEmptyStaging =>
      'Aucune ressource construite pour l’instant.\nSélectionnez dans l’onglet « Entrants » puis touchez CONSTRUIRE.';

  @override
  String get cbnFlowEmptyPushed => 'Aucune ressource publiée.';

  @override
  String get cbnFlowBadgeTagged => 'É';

  @override
  String get cbnFlowBadgeObjects => 'O';

  @override
  String cbnFlowBadgeBuilt(Object regions, Object colors) {
    return '${regions}r ${colors}c';
  }

  @override
  String get cbnFlowLayerNumbered => 'Numéroté';

  @override
  String get cbnFlowLayerFinished => 'Terminé';

  @override
  String get cbnFlowLayerSource => 'Source';

  @override
  String get cbnFlowLayerObjects => 'Objets';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions régions · $colors couleurs · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   étiquettes : $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) Trouver les objets';

  @override
  String get cbnFlowSamMasks => 'B) Masques SAM';

  @override
  String get cbnFlowLineartPage => 'C) Page de traits (facultatif, Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) Construire';

  @override
  String get cbnFlowStepMissingA =>
      'L’étape A (liste d’objets) n’a pas été exécutée';

  @override
  String get cbnFlowStepMissingB =>
      'L’étape B (masques SAM) n’a pas été exécutée';

  @override
  String get cbnFlowStepMissingC =>
      'L’étape C (page de traits) n’a pas été exécutée';

  @override
  String get cbnFlowImageFailed => 'Impossible de charger l’image';

  @override
  String get jigsawFlowTitle => 'Chaîne Jigsaw';

  @override
  String get jigsawFlowTabTagged => '2 Étiquetés';

  @override
  String get jigsawFlowTabToPush => '3 À publier';

  @override
  String get jigsawFlowQueueAll => 'TOUT EN FILE';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'TOUT EN FILE - $count ressources';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return 'Générer une vidéo - $count ressources';
  }

  @override
  String get jigsawFlowPositive1 => 'Positif 1 - sujet';

  @override
  String get jigsawFlowPositive1Help =>
      'vide = le prompt propre à chaque ressource';

  @override
  String get jigsawFlowMotionPreset => 'Modèle de mouvement';

  @override
  String get jigsawFlowSpreadInTurn => '(répartir à tour de rôle)';

  @override
  String get jigsawFlowPositive2 => 'Positif 2 - mouvement';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = emplacement du prompt du sujet. Vide = les modèles à tour de rôle.';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return 'Les $count modèles seront répartis à tour de rôle.';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => 'Aucune ressource sans vidéo';

  @override
  String get jigsawFlowSelectWithoutVideo =>
      'Sélectionnez des ressources sans vidéo';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued vidéos ajoutées à la file - elles arriveront ici une fois terminées';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued vidéos ajoutées à la file, $skipped ignorées - elles arriveront ici une fois terminées';
  }

  @override
  String get jigsawFlowNoVideoTitle => 'Pas de vidéo';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count ressources n’ont pas de vidéo - seul le jpg sera écrit. Continuer ?';
  }

  @override
  String get jigsawFlowMusicNotReady => 'Le modèle de musique n’est pas prêt';

  @override
  String get jigsawFlowNoMusicMissing =>
      'Aucune collection thématique sans musique';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection a déjà de la musique ou est Generic';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return 'Un morceau instrumental de 30 secondes sera généré pour $count collections (ACE-Step, local).\n\n$names\n\nChacun peut prendre quelques minutes.';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count ressources seront ENVOYÉES vers le bucket R2.\n\nC’est une publication irréversible - les fichiers envoyés deviennent visibles dans l’app.';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return 'Supprimer définitivement $count ressources (jpg + mp4 + webp + json) ?';
  }

  @override
  String get jigsawFlowWebpStarted => 'Génération des webp manquants lancée';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return 'Collection $mode';
  }

  @override
  String get jigsawFlowCollectionHelp =>
      'choisissez dans la liste ou saisissez un NOUVEAU nom';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return 'choisissez dans la liste ou saisissez un NOUVEAU nom  -  $count collections pleines sont masquées';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total ressources - suivant $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'Aucune ressource à cette étape.\nEnvoyez-les ici avec ACCEPTER depuis l’écran « Générés ».';

  @override
  String get jigsawFlowEmpty => 'Aucune ressource à cette étape.';

  @override
  String get jigsawFlowBadgeNoWebp => 'sans webp';

  @override
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp) {
    return '$label\nvidéo : $video   webp : $webp';
  }

  @override
  String jigsawFlowPreviewTags(Object state) {
    return 'étiquettes : $state';
  }

  @override
  String get jigsawFlowNoVideoInSelection =>
      'Aucune des ressources sélectionnées n’a de vidéo';

  @override
  String get jigsawFlowDeleteVideo => 'Supprimer la vidéo';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return 'Les mp4 + webp de $count ressources seront supprimés ; l’image reste et vous pourrez générer une nouvelle vidéo.';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip =>
      'Supprimer la vidéo (l’image reste)';

  @override
  String get jigsawFlowExtractNeedsOne =>
      'Une tenue s’extrait d’une seule image - sélectionnez-en une';

  @override
  String outfitExtractStarted(Object name) {
    return '$name est en cours d’extraction vers la garde-robe - Personnage > Garde-robe';
  }

  @override
  String get jigsawFlowMetaFile => 'Fichier';

  @override
  String get jigsawFlowMetaTags => 'Étiquettes';

  @override
  String get jigsawFlowMetaSubject => 'Sujet';

  @override
  String get jigsawFlowMetaPolicy => 'Politique';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   webp : $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'Étiquettes / métadonnées';

  @override
  String get jigsawFlowMissingWebp => 'Webp manquants';

  @override
  String deliverySavedLive(Object time) {
    return 'Enregistré et EN LIGNE ($time) - actualisation des compteurs';
  }

  @override
  String get deliveryReindexTitle => 'Relire les métadonnées';

  @override
  String get deliveryReindexBody =>
      'Pour les images dont l’EXIF a changé dans le bucket. Saisissez les noms de fichiers séparés par des virgules (p. ex. 12.jpg, 340.jpg) ; laissez vide pour relire TOUT Generic (~1500 fichiers, quelques minutes).';

  @override
  String get deliveryReindexNames => 'Noms de fichiers';

  @override
  String get deliveryReindexAction => 'Lire';

  @override
  String deliveryReindexed(Object count) {
    return '$count images relues - manifestes actualisés';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count images relues, $missing introuvables - manifestes actualisés';
  }

  @override
  String get deliveryDryRunStarted =>
      'Essai à blanc lancé - il ne produit qu’un rapport';

  @override
  String get deliveryNormalizeStarted => 'Normalisation lancée';

  @override
  String get deliveryCancelRequested => 'Annulation demandée';

  @override
  String get deliveryNeverSaved => 'jamais enregistré';

  @override
  String get deliveryPoolJigsaw => 'Pool Jigsaw';

  @override
  String get deliveryPoolCards => 'Cartes';

  @override
  String get deliveryPoolEvents => 'Événements';

  @override
  String get deliveryEvent => 'Événement';

  @override
  String deliverySummaryLine(
    Object pool,
    Object total,
    Object tagged,
    Object untagged,
  ) {
    return 'Pool $pool : $total images, $tagged étiquetées, $untagged sans étiquette';
  }

  @override
  String get deliverySaveBeforeSwitch =>
      'Enregistrez vos modifications avant de changer de pool.';

  @override
  String get deliveryReindexTooltip =>
      'Relire les métadonnées (si l’EXIF a changé)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return 'Dernière règle : $time  ·  diffusées par défaut : $served / $total';
  }

  @override
  String get deliveryIntro =>
      'Interrupteur DÉSACTIVÉ = les images ayant cette valeur sortent du manifeste. L’enregistrement est en ligne immédiatement et filtre désormais CHAQUE collection / paquet ; un élément isolé qui échappe aux règles se ferme avec la liste de blocage.';

  @override
  String get deliveryNormalizeTitle =>
      'Normaliser - générer les étiquettes manquantes';

  @override
  String get deliveryDryRun => 'Essai';

  @override
  String get deliveryNormalizeNoStatus =>
      'État indisponible - le serveur n’a pas répondu à /api/normalize/status';

  @override
  String deliveryIndex(Object index) {
    return 'Index : $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return 'Dernière exécution : $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => 'toutes les apps (global)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'Bloquer · $scope';
  }

  @override
  String get deliveryOpenList => 'Ouvrir la liste';

  @override
  String get deliveryBlockIntro =>
      'Un blocage global s’applique dans TOUTES les apps ; sélectionnez une app pour ne bloquer que pour elle. Appliqué APRÈS les règles.';

  @override
  String get deliveryBlockEmpty =>
      'Rien à bloquer dans ce pool (le bucket est vide).';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count éléments · $tagged/$count étiquetés';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count éléments · $tagged/$count étiquetés · TOUT BLOQUÉ';
  }

  @override
  String get deliveryAppsHint =>
      'Apps - touchez pour modifier la règle de cette app';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return 'Par défaut  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      'Règle par défaut - anciennes versions qui n’envoient pas ?app= et apps sans règle propre';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return 'Règle propre à $app';
  }

  @override
  String get deliveryCustomRuleOn =>
      'Désactivez pour revenir à la règle par défaut';

  @override
  String get deliveryCustomRuleOff =>
      'Désactivé : la règle par défaut s’applique. L’activer démarre avec une copie de celle-ci.';

  @override
  String get deliveryScopeTitle => 'Uniquement les collections sélectionnées';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total collections - les nouvelles publications n’atteignent PAS cette app';
  }

  @override
  String get deliveryScopeOff =>
      'Désactivé : chaque nouvelle collection publiée atteint aussi cette app';

  @override
  String get deliveryScopeNone =>
      'Aucune sélection - une liste vide n’est pas enregistrée, la règle revient à « toutes ».';

  @override
  String get deliveryRulesEnabled => 'Règles actives';

  @override
  String get deliveryRulesEnabledHint =>
      'Désactivé = cet ensemble de règles ne filtre rien';

  @override
  String get deliveryServeUntagged => 'Diffuser les images sans étiquette';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count images n’ont pas de métadonnées';
  }

  @override
  String get deliveryQuick => 'Rapide :';

  @override
  String deliveryOffCount(Object count) {
    return '$count désactivés';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count valeurs';
  }

  @override
  String get deliveryUnsaved => 'Des modifications ne sont pas enregistrées';

  @override
  String get deliveryInSync => 'Identique au serveur';

  @override
  String get deliverySavePublish => 'Enregistrer et publier';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonModel => 'Modèle';

  @override
  String get cardTplShuffled =>
      'Mélangé - les axes verrouillés n’ont pas été modifiés';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank mélangé';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - pour tous';
  }

  @override
  String get cardTplAxisAllBack => 'Écrit au dos de la carte et VERROUILLÉ.';

  @override
  String get cardTplAxisAllFront =>
      'Écrit sur les 13 cartes + 2 jokers en une fois et VERROUILLÉ - le mélange ne le change pas.';

  @override
  String get cardTplValue => 'Valeur';

  @override
  String get cardTplAllWritten => 'Écrit pour tous et verrouillé';

  @override
  String cardTplRankTitle(Object rank) {
    return 'Modèle $rank';
  }

  @override
  String get cardTplLocked => 'Verrouillé';

  @override
  String get cardTplLock => 'Verrouiller';

  @override
  String get cardTplManual => 'Ajout manuel (texte libre)';

  @override
  String get cardTplManualHint => 'p. ex. holding a golden card fan';

  @override
  String get cardTplManualHelp =>
      'Ajouté à la fin du modèle - le mélange ne le supprime pas';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank enregistré';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot ajouté à la file';
  }

  @override
  String cardTplTitle(Object title) {
    return 'Carte de collection - $title';
  }

  @override
  String get cardTplShuffle => 'Mélanger';

  @override
  String get cardTplNoTheme => 'Pas de thème - touchez pour en écrire un';

  @override
  String get cardTplThemeTitle => 'Thème (P1)';

  @override
  String get cardTplPresetCard => 'Carte prédéfinie';

  @override
  String get cardTplTheme => 'Thème';

  @override
  String get cardTplThemeHelp => 'identité + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'Le thème ne peut pas être vide';

  @override
  String get cardTplThemeSaved => 'Thème enregistré';

  @override
  String cardTplModelSet(Object name) {
    return 'Modèle : $name';
  }

  @override
  String get cardTplFaceDetail => 'Retouche du visage';

  @override
  String get cardTplFaceDetailHint =>
      '+15 s par carte - le visage passe par une passe séparée';

  @override
  String get cardTplFaceDetailOn => 'Retouche du visage activée';

  @override
  String get cardTplFaceDetailOff => 'Retouche du visage désactivée';

  @override
  String get cardTplVideoEngine =>
      'Moteur vidéo (première image = dernière image)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (non installé)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return 'Moteur vidéo : $name';
  }

  @override
  String get cardTplApplyToAll => 'Appliquer à tous :';

  @override
  String get cardTplPickAxis => 'choisir un axe';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (dos)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count axes verrouillés';
  }

  @override
  String get cardTplShuffleSlot => 'Mélanger cet emplacement';

  @override
  String get cardTplGenerateSlot => 'Générer cet emplacement';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return 'Supprimer $count générations et leurs fichiers ?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count générations supprimées';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count n’ont pas pu être supprimées';
  }

  @override
  String get galleryCharacterNeedsOne =>
      'Un personnage se crée à partir d’une seule image - sélectionnez-en une';

  @override
  String get galleryMakeCharacter => 'Créer un personnage';

  @override
  String get galleryMakeCharacterBody =>
      'L’image sélectionnée devient directement la base ; le portrait, l’histoire et les 7 directions sont générés automatiquement - sans confirmation.';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name ajouté à la file - suivez le traitement dans l’onglet File';
  }

  @override
  String get galleryCreateCharacterFirst =>
      'Créez d’abord un personnage avec « Créer un personnage »';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return 'Ajouter aux candidats - $count images';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$count images ajoutées aux candidats de $name';
  }

  @override
  String get galleryCollectionNeedsOne =>
      'Une seule image s’ajoute à une collection - sélectionnez-en une';

  @override
  String get galleryCreateCollectionFirst =>
      'Créez d’abord une collection ou un croupier dans la chaîne Carte';

  @override
  String get galleryAddToCollection => 'Ajouter à la collection';

  @override
  String get galleryDealerNoRank => 'croupier (sans rang)';

  @override
  String galleryPickRank(Object name) {
    return '$name - choisir un rang';
  }

  @override
  String get galleryQueuedOne =>
      'Ajouté à la file (1 tâche) - suivez-la dans l’onglet File';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count images passeront à l’étape « Entrants » de la chaîne CBN : jpg + étiquettes EXIF. La construction (SAM, traits, régions) se lance là-bas.\n\nQuelle classification ?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count images passeront à l’étape 2 : jpg + étiquettes EXIF, avec la vidéo s’il y en a une.\n\nQuelle classification ?';
  }

  @override
  String get galleryAcceptStarted =>
      'Lancé - suivez la progression dans l’onglet « Chaîne »';

  @override
  String get galleryExtractTooltip =>
      'Extraire la tenue - mettre la tenue de l’image dans la garde-robe';

  @override
  String get galleryMakeCharacterTooltip =>
      'Créer un personnage - nouveau personnage';

  @override
  String get galleryAddToCandidatesTooltip =>
      'Ajouter aux candidats - copier vers un personnage existant';

  @override
  String get galleryAddToCollectionTooltip =>
      'Ajouter à la collection - choisir un rang';

  @override
  String get galleryAcceptTooltip => 'Accepter - envoyer à l’étape 2';

  @override
  String get galleryDeleteSelected => 'Supprimer la sélection';

  @override
  String get galleryFilterImage => 'Image';

  @override
  String get galleryFilterVideo => 'Vidéo';

  @override
  String get galleryFilterFavorite => 'Favori';

  @override
  String galleryQueuedAt(Object position) {
    return 'en file $position';
  }

  @override
  String get galleryEmpty => 'Rien n’a encore été généré';

  @override
  String get galleryEmptyHint =>
      'Vous pouvez commencer depuis l’onglet Générer';

  @override
  String get galleryDeleteOneConfirm =>
      'Supprimer cette génération et son fichier ?';

  @override
  String get galleryAcceptOneCbn =>
      'Elle passera à l’étape « Entrants » de la chaîne CBN (jpg + étiquettes EXIF).\n\nQuelle classification ?';

  @override
  String get galleryAcceptOneJigsaw =>
      'Elle passera à l’étape 2 (jpg + étiquettes EXIF).\n\nQuelle classification ?';

  @override
  String get galleryAccepted =>
      'Accepté - étiquetage en cours, suivez-le dans l’onglet « Chaîne »';

  @override
  String get galleryRejected => 'Rejeté';

  @override
  String get galleryEditBody =>
      'Cette image devient la source ; le moteur d’édition (Qwen Image Edit, conserve l’identité) lance une nouvelle génération. Que faut-il changer ?';

  @override
  String get galleryEditPromptLabel => 'Prompt supplémentaire';

  @override
  String get galleryEditPromptHint =>
      'p. ex. change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued =>
      'Modification ajoutée à la file - le résultat apparaîtra dans Générés';

  @override
  String get galleryEditTooltip =>
      'Modifier - nouvelle génération avec le moteur d’édition';

  @override
  String galleryPoolInfo(Object name) {
    return 'pool $name';
  }

  @override
  String get genPromptUnchanged =>
      'Le prompt n’a pas changé (le LLM local n’a pas répondu)';

  @override
  String get genPromptWritten => 'Prompt rédigé';

  @override
  String get commonUndo => 'Annuler l’action';

  @override
  String get genVariantFailed =>
      'Aucune variante n’a pu être produite (le LLM local n’a pas répondu)';

  @override
  String get genPickVariant => 'Choisir une variante';

  @override
  String get genEnrich => 'Enrichir';

  @override
  String get genFix => 'Corriger';

  @override
  String get genVariant => 'Variante';

  @override
  String get genFileUnreadable => 'Impossible de lire le fichier';

  @override
  String get genPromptEmpty => 'Le prompt ne peut pas être vide';

  @override
  String genMissingInputs(Object inputs) {
    return 'Entrée manquante : $inputs';
  }

  @override
  String get genNeedsImagePick =>
      'Cette tâche nécessite une image d’entrée - choisissez-en une parmi les générées';

  @override
  String get genNeedsImage => 'Cette tâche nécessite une image d’entrée';

  @override
  String genQueuedCount(Object count) {
    return '$count tâches ajoutées à la file';
  }

  @override
  String get genQueued => 'Ajouté à la file';

  @override
  String genQueueBadge(Object count) {
    return '$count en file';
  }

  @override
  String get genComfyOffBody =>
      'ComfyUI est arrêté. Les tâches entrent dans la file mais ne démarrent pas - il faut le lancer sur l’ordinateur.';

  @override
  String get genTask => 'Tâche';

  @override
  String get genWorkflowInputs => 'Entrées du workflow';

  @override
  String get genInputImage => 'Image d’entrée';

  @override
  String get genPositive1 => 'Prompt positif 1 - sujet';

  @override
  String get genPositive1Hint => 'p. ex. police officer';

  @override
  String get genPositive2 => 'Prompt positif 2 - modèle';

  @override
  String genPositive2Help(Object marker) {
    return '$marker est remplacé par le premier prompt. Peut rester vide.';
  }

  @override
  String get genFinalPrompt => 'Prompt qui sera envoyé';

  @override
  String get genNegative => 'Prompt négatif';

  @override
  String get genTurboHint => 'mode rapide';

  @override
  String genDurationSeconds(Object seconds) {
    return 'Durée : $seconds secondes';
  }

  @override
  String genCount(Object count) {
    return 'Nombre : $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'Taille : $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'Taille : $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'AJOUTER À LA FILE';

  @override
  String get genFootnote =>
      'Les tâches sont générées l’une après l’autre. Vous pouvez les suivre dans l’onglet File.';

  @override
  String get genDetailsTitle =>
      'Détails - peuvent rester vides, les verrouillés ne sont pas mélangés';

  @override
  String genRandomGenerate(Object count) {
    return 'Générer au hasard  $count';
  }

  @override
  String get genLockedTooltip => 'verrouillé - reste fixe lors du mélange';

  @override
  String get genOptionsEmpty => 'La liste d’options est vide';

  @override
  String get genOptional => 'facultatif';

  @override
  String get genUploading => 'envoi...';

  @override
  String get genNotSelected => 'non sélectionné';

  @override
  String get genFromGallery => 'Depuis la galerie';

  @override
  String get genFromFile => 'Depuis un fichier';

  @override
  String get genNoSource =>
      'Aucune génération utilisable comme entrée. Générez d’abord une image.';

  @override
  String genPickerTitle(Object slot) {
    return '$slot - choisir dans Générés';
  }

  @override
  String get genPickerSearch => 'rechercher dans les prompts';

  @override
  String get genPickerEmpty => 'Aucune génération terminée de ce type.';

  @override
  String optionsFileMissing(Object items) {
    return 'Manquant dans le fichier d’options : $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (aucune définition de champ)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'Impossible de lire le fichier d’options : $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return 'Impossible de lire le fichier d’options $name : $error';
  }

  @override
  String get fieldLocation => 'Lieu';

  @override
  String get fieldEra => 'Époque / esthétique';

  @override
  String get fieldWeather => 'Météo';

  @override
  String get fieldWeatherLight => 'Météo / lumière';

  @override
  String get fieldJob => 'Métier';

  @override
  String get fieldFantasy => 'Fantaisie';

  @override
  String get fieldOutfitColor => 'Couleur de la tenue';

  @override
  String get fieldOutfit => 'Tenue';

  @override
  String get fieldHair => 'Cheveux';

  @override
  String get fieldHairColor => 'Couleur des cheveux';

  @override
  String get fieldHairstyle => 'Coiffure';

  @override
  String get fieldEyes => 'Yeux';

  @override
  String get fieldRace => 'Origine ethnique';

  @override
  String get fieldExpression => 'Expression';

  @override
  String get fieldPose => 'Pose';

  @override
  String get fieldAngle => 'Angle';

  @override
  String get fieldStyle => 'Style';

  @override
  String get fieldMood => 'Ambiance';

  @override
  String get fieldColor => 'Couleur';

  @override
  String get fieldCreature => 'Créature';

  @override
  String get fieldClass => 'Classe';

  @override
  String get fieldAge => 'Âge';

  @override
  String get fieldOrigin => 'Origine';

  @override
  String get fieldBody => 'Corps';

  @override
  String get fieldSkin => 'Peau';

  @override
  String get fieldFace => 'Visage';

  @override
  String get fieldGesture => 'Geste';

  @override
  String get cardNotReady =>
      'Le point d’accès du serveur n’est pas encore prêt';

  @override
  String get cardKindNormal => 'Normal';

  @override
  String get cardKindDealer => 'Croupier';

  @override
  String get cardStagePushed => 'publié';

  @override
  String get cardStageWebp => 'webp prêt';

  @override
  String get cardStageVideo => 'vidéo prête';

  @override
  String get cardStageStill => 'still prêt';

  @override
  String get cardStageEmpty => 'vide';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (à vérifier)';
  }

  @override
  String get cardVideoIntro =>
      'Première image = dernière image (boucle). La caméra reste verrouillée - cadrage, échelle et fond ne changent pas. Le résultat va d’abord dans le POOL ; si vous choisissez une étiquette, il y est aussi affecté.';

  @override
  String get cardVideoTemplate => 'Modèle (remplit le texte)';

  @override
  String get cardVideoMotion => 'Phrase de mouvement (le prompt envoyé)';

  @override
  String get cardVideoMotionHelp =>
      'Décrivez un mouvement visible ; il doit revenir à la pose de départ à la fin';

  @override
  String get cardVideoAssignTag => 'Affecter à l’étiquette';

  @override
  String get cardVideoPoolOnly => '(pool uniquement - j’affecterai plus tard)';

  @override
  String get cardVideoNewTag => 'Nouvelle étiquette...';

  @override
  String get cardVideoNewTagName => 'Nom de la nouvelle étiquette';

  @override
  String get cardTagHint => 'p. ex. victory';

  @override
  String get cardGestureTitle => 'Animation - choisir un geste';

  @override
  String get cardGestureIntro =>
      'MiniMax H3 : idle 6 s, victory 2 s. La caméra reste verrouillée - cadrage, échelle et fond ne changent pas.';

  @override
  String get cardGestureCustom => 'Mouvement personnalisé';

  @override
  String get cardGestureCustomHint =>
      'p. ex. léger balancement des hanches, pieds fixes';

  @override
  String get cardGestureCustomHelp =>
      'Une courte phrase de mouvement - la caméra reste verrouillée';

  @override
  String get cardCutTitle => '3 WebP - mode de détourage';

  @override
  String get cardCutHybrid =>
      'Anciens masters verts Grok - chroma + SAM ensemble';

  @override
  String get cardCutSam => 'Par défaut - SAM3 seul, fond gris clair uni';

  @override
  String get cardCutAction => 'Détourer';

  @override
  String cardEditTitle(Object name) {
    return 'Modifier - $name';
  }

  @override
  String get cardEditSentence => 'Phrase de correction';

  @override
  String get cardEditSentenceHint =>
      'p. ex. raccourcir les cheveux / retirer les gants';

  @override
  String get cardEditBody =>
      'Le still accepté est modifié avec cette phrase ; l’identité, la pose et le fond sont conservés. La nouvelle image est acceptée automatiquement.';

  @override
  String get cardEditUnrestricted =>
      'Modification sans restriction (NSFW LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Activez si Qwen refuse - MCNL LoRA, 20 étapes, un peu plus lent';

  @override
  String cardQueuedJobs(Object count) {
    return 'Ajouté à la file ($count tâches) - suivez-les dans l’onglet File';
  }

  @override
  String get cardQueued => 'Ajouté à la file - suivez-le dans l’onglet File';

  @override
  String cardQueuedOp(Object op) {
    return 'Ajouté à la file (op $op) - suivez-le dans l’onglet File';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - bientôt';
  }

  @override
  String get cardSoonBody =>
      'Les points d’accès des cartes sur le serveur ne sont pas encore ouverts. Cet écran fonctionnera de lui-même dès qu’ils le seront.';

  @override
  String get cardNewCollection => 'Nouvelle collection';

  @override
  String get cardIdLabel => 'Identifiant (id)';

  @override
  String get cardIdHintCollection => 'p. ex. police_royale';

  @override
  String get commonName => 'Nom';

  @override
  String get cardNameHintCollection => 'p. ex. Police Royale';

  @override
  String get cardPickPreset => 'Choisir une carte prédéfinie (facultatif)';

  @override
  String get cardThemeHint =>
      'p. ex. sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      'Formule : identité + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'Jokers (2)';

  @override
  String get cardJokersHint => '15 rangs au lieu de 13';

  @override
  String get cardNewCollectionNote =>
      'Un still par rang entre dans la file (rotation peau / cheveux / tenue / pose). Aucune confirmation - affinez avec ✎ / ↻.';

  @override
  String get cardIdNameRequired =>
      'L’identifiant et le nom ne peuvent pas être vides';

  @override
  String get cardNewDealer => 'Nouveau croupier';

  @override
  String get cardIdHintDealer => 'p. ex. scarlett';

  @override
  String get cardNameHintDealer => 'p. ex. Scarlett';

  @override
  String get cardDealerTheme => 'Thème / tenue';

  @override
  String get cardDealerThemeHint =>
      'p. ex. gilet de casino et nœud papillon, robe rouge noir';

  @override
  String get cardDealerNote =>
      'Le croupier est généré en plan taille (mains sur la table, regard caméra). Pas de rang - l’élément unique passe par les quatre étapes.';

  @override
  String get cardNightPickGesture => 'Mode nuit - choisir un geste';

  @override
  String get cardNightMode => 'Mode nuit';

  @override
  String cardNightBody(Object gesture) {
    return 'Toutes les cartes ET les croupiers sont réanimés : still actuel -> LTX-2.5 i2v ($gesture) -> détourage SAM -> sheet.\n\nC’est long et tout entre dans la file. AUCUN push n’est fait.';
  }

  @override
  String get cardRestillTitle => 'Passer les fonds en gris';

  @override
  String get cardRestillBody =>
      'Le fond du still de toutes les cartes ET des croupiers devient gris clair uni (la femme reste telle quelle). L’original est conservé sous still_green.png ; ceux déjà gris sont ignorés.\n\nAucune vidéo n’est générée.';

  @override
  String get cardManifestPreview => 'Aperçu du manifeste';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return '$collections collections, $dealers croupiers';
  }

  @override
  String get cardManifestNote =>
      'Le fichier manifeste est écrit pendant le PUSH (les fichiers d’abord, puis le manifeste). Ceci n’est qu’un aperçu.';

  @override
  String get cardCollectionCardSettings => 'Carte de collection (réglages)';

  @override
  String get cardCollectionCardSettingsHint =>
      'thème, 16 emplacements, modèle, retouche du visage';

  @override
  String get cardReanimate => 'Réanimer';

  @override
  String get cardReanimateHint =>
      'still -> i2v -> détourage (cette collection)';

  @override
  String get cardRealify => 'Anime -> réaliste (collection)';

  @override
  String get cardRealifyHint =>
      'chaque still devient une photo réaliste avec edit_qwen';

  @override
  String get cardDeleteCollection => 'Supprimer la collection';

  @override
  String get cardDeleteCollectionHint =>
      'le dossier est supprimé avec toutes ses cartes - irréversible';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'Supprimer la collection - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'Supprimer le croupier - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'Le dossier de la collection est supprimé avec tous ses fichiers.\n\nIRRÉVERSIBLE. Les fichiers déjà publiés sur R2 restent dans le bucket.';

  @override
  String get cardDeleteDealerBody =>
      'Le dossier du croupier est supprimé avec tous ses fichiers.\n\nIRRÉVERSIBLE. Les fichiers déjà publiés sur R2 restent dans le bucket.';

  @override
  String cardDeletedNamed(Object name) {
    return '$name supprimé';
  }

  @override
  String get cardDealerCardSettings => 'Carte du croupier (réglages)';

  @override
  String get cardDealerCardSettingsHint =>
      'thème, modèle de prompt, modèle, retouche du visage';

  @override
  String get cardDeleteDealer => 'Supprimer le croupier';

  @override
  String get cardDeleteDealerHint =>
      'le dossier est supprimé avec tous ses fichiers - irréversible';

  @override
  String get cardFlowTitle => 'Chaîne Carte';

  @override
  String get cardBulkActions => 'Actions groupées';

  @override
  String get cardNightMenu => 'Mode nuit : tout réanimer';

  @override
  String get cardRestillMenu => 'Passer les fonds en gris (tous)';

  @override
  String get cardManifestMenu => 'Aperçu du manifeste';

  @override
  String get cardDealers => 'Croupiers';

  @override
  String get cardEmptyCollections =>
      'Aucune collection pour l’instant.\n\nAvec « + Nouvelle collection », indiquez un identifiant, un nom et un thème - un still par rang entre dans la file pour 13 (ou 15) rangs, puis viennent les étapes 2 Video et 3 WebP.';

  @override
  String get cardEmptyDealers =>
      'Aucun croupier pour l’instant.\n\nAvec « + Nouveau croupier », indiquez un nom, un thème et un geste - un élément unique est généré en plan taille et passe par les quatre étapes.';

  @override
  String cardGestureLine(Object gesture) {
    return 'geste : $gesture';
  }

  @override
  String cardAnimateTitle(Object count) {
    return '2 Video ($count cartes)';
  }

  @override
  String cardAnimateBody(Object total) {
    return 'Deux animations sont générées pour chaque carte et affectées à leurs étiquettes :\n• idle - 6 s, un geste contrôlé\n• victory - 2 s, une courte joie dans le cadre\n$total vidéos au total ; les anciennes restent dans le pool.';
  }

  @override
  String get cardEditNeedsOne =>
      'La modification concerne un seul rang - sélectionnez une carte';

  @override
  String cardPushTitle(Object name) {
    return 'Push - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'Les fichiers sheet et thumb sont envoyés vers R2 (cards), puis le manifeste est écrit. Pour l’instant, le webp de $ready/$total rangs est prêt.\n\nC’est une PUBLICATION, IRRÉVERSIBLE.';
  }

  @override
  String get cardPushQueued =>
      'Push ajouté à la file - suivez-le dans l’onglet File';

  @override
  String get cardCollectionCardTooltip =>
      'Carte de collection - thème, 16 emplacements, modèle, retouche du visage';

  @override
  String get commonMore => 'Plus';

  @override
  String get cardNoThemeTap => 'Pas de thème - touchez : Carte de collection';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nCarte de collection : touchez (thème, 16 emplacements, modèle, retouche du visage)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'Le dossier de la collection est supprimé avec toutes ses cartes ($stills stills).\n\nIRRÉVERSIBLE. Les fichiers déjà publiés sur R2 restent dans le bucket.';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'Le dossier de la collection est supprimé avec toutes ses cartes ($stills stills, $pushed publiées).\n\nIRRÉVERSIBLE. Les fichiers déjà publiés sur R2 restent dans le bucket.';
  }

  @override
  String get cardClearCards => 'Vider les cartes';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - still, candidats, vidéo et webp sont supprimés ; le rang reste vide (à régénérer avec « 1 Still »).';
  }

  @override
  String cardsCleared(Object count) {
    return '$count cartes vidées';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count cartes n’ont pas pu être vidées';
  }

  @override
  String get cardGenerateStill => 'Générer 1 Still';

  @override
  String get cardGenerateVideo => 'Générer 2 Video';

  @override
  String get cardGenerateWebp => 'Générer 3 WebP';

  @override
  String get cardBackUpper => 'DOS';

  @override
  String cardAssetVideo(Object tag) {
    return 'Vidéo ($tag)';
  }

  @override
  String cardAssetSheet(Object tag) {
    return 'WebP / détourage ($tag)';
  }

  @override
  String cardAssetMissing(Object asset) {
    return 'Pas de $asset';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return 'Supprimer $asset ?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'Seule la vidéo de cette étiquette est supprimée ; la copie du pool, le still et le webp restent.';

  @override
  String get cardAssetDeleteSheetBody =>
      'Seuls sheet.webp, le thumb et les images détourées sont supprimés ; la vidéo et le still restent.';

  @override
  String get cardAssetDeleteStillBody =>
      'Seul le still sélectionné est supprimé ; les candidats, la vidéo et le webp restent.';

  @override
  String get cardPoolDelete => 'Supprimer du pool';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id est supprimé du pool. Les copies affectées aux étiquettes ($tags) restent.';
  }

  @override
  String get cardNone => 'aucune';

  @override
  String get cardNewAnimTag => 'Nouvelle étiquette d’animation';

  @override
  String get cardNewAnimTagHelp =>
      'Le jeu la lit sous ce nom (idle, wink, victory ...)';

  @override
  String get cardUnassigned => 'non affectée';

  @override
  String cardAssignedTo(Object tags) {
    return 'affectée : $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return 'Affecter : $name';
  }

  @override
  String get cardAssignNewTag => 'Affecter à une nouvelle étiquette...';

  @override
  String get cardAnimReady => 'vidéo + webp prêts';

  @override
  String get cardAnimVideoOnly => 'vidéo présente, pas de webp';

  @override
  String get cardPoolEmpty =>
      'Aucune vidéo dans le pool - lancez d’abord « 2 Video »';

  @override
  String get cardDeleteVideoKeepTag => 'Supprimer la vidéo (l’étiquette reste)';

  @override
  String get cardDeleteSheet => 'Supprimer WebP / détourage';

  @override
  String get cardDeleteTag => 'Supprimer l’étiquette (avec vidéo + webp)';

  @override
  String cardVideosHeader(Object count) {
    return 'Vidéos ($count) - touchez = affecter / aperçu / supprimer';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return 'Le dossier de $name est supprimé avec tous ses fichiers. IRRÉVERSIBLE.';
  }

  @override
  String get cardClearCard => 'Vider la carte';

  @override
  String cardClearCardBody(Object name) {
    return '$name : still, candidats, vidéo, webp et animations sont supprimés ; le rang reste vide (à régénérer avec « 1 Still »).';
  }

  @override
  String get cardClearCardTooltip => 'Vider la carte (le rang redevient vide)';

  @override
  String get cardViewCut => 'Détourage';

  @override
  String cardDeleteThisVideo(Object tag) {
    return 'Supprimer cette vidéo ($tag)';
  }

  @override
  String cardDeleteSheetTag(Object tag) {
    return 'Supprimer WebP / détourage ($tag)';
  }

  @override
  String get cardDeleteStill => 'Supprimer le still';

  @override
  String get cardNoVideo => 'Pas de vidéo - générez-la avec « 2 Video »';

  @override
  String get cardNoCut => 'Pas de détourage - générez-le avec « 3 WebP »';

  @override
  String get cardCutFrameFailed => 'Impossible de lire l’image détourée';

  @override
  String get cardNoStill => 'Pas de still - générez-le avec « 1 Still »';

  @override
  String get cardStillFailed => 'Impossible de lire le still';

  @override
  String cardPromptTitleAge(Object age) {
    return 'Prompt  ·  $age ans';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - cadrage décalé / zoom / masque rompu. Régénérez la vidéo ou le détourage.';

  @override
  String get cardAnimsHeader =>
      'Animations - touchez = sélectionner, appui long = affecter / supprimer';

  @override
  String cardAnimOpened(Object tag) {
    return '« $tag » créée - générez-la avec 2 Video ou affectez depuis le pool';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return 'Choisissez une vidéo du pool pour « $tag »';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return 'Candidats ($count) - touchez = sélectionner';
  }

  @override
  String get cardCandidatePicked =>
      'Le candidat est maintenant le still sélectionné';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step : $error';
  }
}

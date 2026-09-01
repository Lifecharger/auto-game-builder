// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get about => 'Acerca de';

  @override
  String get aboutApp => 'Aplicación';

  @override
  String actionTriggered(Object action) {
    return '$action activado';
  }

  @override
  String get add => 'Añadir';

  @override
  String agentLabelWith(Object agent) {
    return 'Agente: $agent';
  }

  @override
  String get agentLocal => 'Local';

  @override
  String get agentNone => 'Ninguno';

  @override
  String get agentRunsOnServer =>
      'El agente se ejecuta en el servidor con acceso a nivel de proyecto';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return 'IA $agent activada para \"$title\"';
  }

  @override
  String get aiAgent => 'Agente IA';

  @override
  String get aiAgentUpdated => 'Agente IA actualizado';

  @override
  String get aiResponse => 'Respuesta de la IA';

  @override
  String get allApps => 'Todas las apps';

  @override
  String get allAppsCompletedOrPostponed =>
      'Todas las apps están completadas o pospuestas';

  @override
  String get allAppsHaveAutomations =>
      'Todas las apps ya tienen automatizaciones';

  @override
  String get allAppsHint => 'Todas las apps';

  @override
  String get allPendingBlocked =>
      'Todos los elementos pendientes están bloqueados por dependencias';

  @override
  String get apiConnection => 'Conexión API';

  @override
  String get apiUrlSaved => 'URL de la API guardada';

  @override
  String get appCreated => '¡App creada!';

  @override
  String get appDetail => 'Detalle de la app';

  @override
  String get appFallback => 'App';

  @override
  String get appNameHint => 'Nombre de la app (p. ej. Mi Juego)';

  @override
  String get appStatusBuilding => 'compilando';

  @override
  String get appStatusDeploying => 'desplegando';

  @override
  String get appStatusError => 'error';

  @override
  String get appStatusFixing => 'corrigiendo';

  @override
  String get appStatusIdle => 'inactivo';

  @override
  String get appStatusPublished => 'publicado';

  @override
  String get appStatusQueued => 'en cola';

  @override
  String get appStatusUploading => 'subiendo';

  @override
  String get appStatusWorking => 'trabajando';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc =>
      'App móvil/escritorio con soporte de despliegue a Google Play';

  @override
  String get appTypeGodotDesc =>
      'Proyecto de juego con destinos de exportación (Windows, Android, Web)';

  @override
  String get appTypePhaserDesc =>
      'Juego Phaser 3 + TypeScript, empaquetado como AAB de Android mediante Capacitor';

  @override
  String get appTypePythonDesc =>
      'Proyecto Python con ejecutor de scripts y gestión de pip';

  @override
  String get appTypeWebDesc =>
      'App web con soporte de despliegue a hosting estático';

  @override
  String get apps => 'Apps';

  @override
  String get archivedLabel => 'archivado';

  @override
  String get artAndAssets => 'Arte y recursos';

  @override
  String get artBible => 'Biblia de arte';

  @override
  String get artBibleCardSubtitle => 'Documento ancla de identidad visual';

  @override
  String get artBibleHint =>
      'Declaración de identidad, paleta (hex), tipografía, prohibiciones, especificaciones técnicas...';

  @override
  String get artBibleSaved => 'Biblia de arte guardada';

  @override
  String get artBibleShort => 'Biblia de arte';

  @override
  String get artBibleSubtitle =>
      'Ancla de identidad visual: paleta, tipografía, prohibiciones de estilo. Todas las tareas de recursos hacen referencia a esto.';

  @override
  String get artBibleTaskCreated => 'Tarea de biblia de arte creada';

  @override
  String artBibleTitle(Object app) {
    return 'Biblia de arte - $app';
  }

  @override
  String get askAQuestionHint => 'Haz una pregunta...';

  @override
  String get askAgent => 'Preguntar al agente';

  @override
  String get askAnythingAboutYourApps =>
      'Pregunta lo que quieras sobre tus apps';

  @override
  String get assetAudit => 'Auditoría de recursos';

  @override
  String get assetAuditSubtitle =>
      'Referencias rotas, huérfanos, marcadores de posición';

  @override
  String get assetAuditTaskCreated => 'Tarea de auditoría de recursos creada';

  @override
  String get assetSpecTaskCreated =>
      'Tarea de especificación de recursos creada';

  @override
  String get assetSpecs => 'Especificaciones de recursos';

  @override
  String get assetSpecsSubtitle => 'Prompts por recurso a partir de la biblia';

  @override
  String get attachments => 'Adjuntos';

  @override
  String attachmentsCount(Object count) {
    return 'Adjuntos ($count)';
  }

  @override
  String get automationCreated => 'Automatización creada';

  @override
  String get automationStateStarted => 'iniciada';

  @override
  String get automationStateStopped => 'detenida';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => 'Automatización actualizada';

  @override
  String get back => 'Atrás';

  @override
  String get backend => 'Backend';

  @override
  String get balanceCheck => 'Revisión de balance';

  @override
  String get balanceCheckSubtitle => 'Economía, progresión, recompensas';

  @override
  String get balanceCheckTaskCreated => 'Tarea de revisión de balance creada';

  @override
  String batchRunError(Object error) {
    return 'Error durante la ejecución por lotes: $error';
  }

  @override
  String blockedByList(Object ids) {
    return 'bloqueado por $ids';
  }

  @override
  String blockedByTask(Object id) {
    return 'Bloqueado por #$id';
  }

  @override
  String blockedCountLabel(Object count) {
    return '$count bloqueados';
  }

  @override
  String blockerNotInList(Object id) {
    return 'La tarea #$id no está en la lista actual (archivada o eliminada)';
  }

  @override
  String get brainstormAndCreate => 'Idear y crear';

  @override
  String get brainstormConceptHint =>
      'Idea inicial (p. ej. \"juego idle de colonia de hormigas\", \"puzle con gravedad\")';

  @override
  String get brainstormCreated =>
      '¡Proyecto creado con tarea de lluvia de ideas!';

  @override
  String get brainstormDesc =>
      'Crea un nuevo proyecto con una tarea de lluvia de ideas. Al ejecutarse, la IA genera un GDD completo y las tareas iniciales.';

  @override
  String get brainstormNameHint =>
      'Nombre del proyecto (opcional; la IA puede sugerirlo)';

  @override
  String get brainstormNewGame => 'Idear nuevo juego';

  @override
  String get build => 'Compilar';

  @override
  String get buildAndDeploy => 'Compilar y desplegar';

  @override
  String get buildCancelled => 'Compilación cancelada';

  @override
  String get buildFailedLabel => 'compilación fallida';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'Se agotó el tiempo de consulta de la compilación tras 30 minutos; revisa los registros del servidor';

  @override
  String get buildTarget => 'Destino de compilación';

  @override
  String get builds => 'Compilaciones';

  @override
  String builtCount(Object count) {
    return 'Compilado ($count)';
  }

  @override
  String get buyMeACoffee => 'Invítame a un café';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'Invítame a un café  $price';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get cannotReachServer => 'No se puede contactar con el servidor';

  @override
  String cannotReachServerWith(Object error) {
    return 'No se puede contactar con el servidor: $error';
  }

  @override
  String get cannotSaveEmptyArtBible =>
      'No se puede guardar una biblia de arte vacía';

  @override
  String get cannotSaveEmptyClaudeMd =>
      'No se puede guardar un CLAUDE.md vacío';

  @override
  String get cannotSaveEmptyDesignDoc =>
      'No se puede guardar un documento de diseño vacío';

  @override
  String get catBugsCrashes => 'Errores y bloqueos';

  @override
  String get catCodeStyle => 'Estilo de código';

  @override
  String get catDeadCode => 'Código muerto';

  @override
  String get catErrorHandling => 'Gestión de errores';

  @override
  String get catMemory => 'Memoria';

  @override
  String get categoryAccessibility => 'Accesibilidad';

  @override
  String get categoryBug => 'Error';

  @override
  String get categoryFeatures => 'Funciones';

  @override
  String get categoryMonetization => 'Monetización';

  @override
  String get categoryOther => 'Otro';

  @override
  String get categoryPerformance => 'Rendimiento';

  @override
  String get categorySecurity => 'Seguridad';

  @override
  String get categorySuggestion => 'Sugerencia';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count caracteres';
  }

  @override
  String get chatHistory => 'Historial de chat';

  @override
  String get chatLogs => 'Informes';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count mensajes • $date';
  }

  @override
  String get checkBugsCrashes => 'Errores y bloqueos';

  @override
  String get checkCodeStyle => 'Estilo de código';

  @override
  String get checkDeadCode => 'Código muerto';

  @override
  String get checkErrorHandling => 'Gestión de errores';

  @override
  String get checkMemoryLeaks => 'Fugas de memoria';

  @override
  String get checkPerformanceIssues => 'Problemas de rendimiento';

  @override
  String get checkSecurityVulnerabilities => 'Vulnerabilidades de seguridad';

  @override
  String get checksToRun => 'Comprobaciones a ejecutar:';

  @override
  String get claudeMdHint =>
      'Convenciones del proyecto, comandos de compilación, reglas...';

  @override
  String get claudeMdSaved => 'CLAUDE.md guardado';

  @override
  String get claudeMdSubtitle =>
      'Instrucciones del proyecto para los agentes de IA que trabajan en esta app.';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'Borrar';

  @override
  String get clearFilters => 'Borrar filtros';

  @override
  String get clearMessages => 'Borrar mensajes';

  @override
  String clearMessagesConfirm(Object count) {
    return '¿Eliminar los $count mensajes de este chat?';
  }

  @override
  String get close => 'Cerrar';

  @override
  String get codeCheck => 'Revisión de código';

  @override
  String get codeCheckBody =>
      'Esto creará una tarea para que el agente de IA revise tu código e informe de los hallazgos como incidencias.';

  @override
  String get codeCheckRequested => 'Revisión de código solicitada';

  @override
  String get codeCheckResults => 'Resultados de la revisión de código';

  @override
  String get codeReview => 'Revisión de código';

  @override
  String get codeReviewSubtitle => 'Errores, bloqueos, calidad del código';

  @override
  String get complete => 'Completar';

  @override
  String completedCount(Object count) {
    return 'Completadas ($count)';
  }

  @override
  String get connectToYourServer => 'Conecta con tu servidor';

  @override
  String get connectYourPhone => 'Conecta tu teléfono';

  @override
  String get connectedSuccessfully => 'Conectado correctamente';

  @override
  String connectedTo(Object server) {
    return 'Conectado a $server';
  }

  @override
  String get connecting => 'Conectando...';

  @override
  String get connectionFailed => 'Error de conexión';

  @override
  String get connectionSuccessful => '¡Conexión correcta!';

  @override
  String get connectionTimedOut => 'Se agotó el tiempo de conexión';

  @override
  String get consistencyCheck => 'Revisión de consistencia';

  @override
  String get consistencyCheckSubtitle => 'Desviación GDD ↔ código ↔ datos';

  @override
  String get consistencyCheckTaskCreated =>
      'Tarea de revisión de consistencia creada';

  @override
  String get console => 'Consola';

  @override
  String get contentAudit => 'Auditoría de contenido';

  @override
  String get contentAuditSubtitle => 'Niveles, personajes, objetos, texto';

  @override
  String get contentAuditTaskCreated =>
      'Tarea de auditoría de contenido creada';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get control => 'Control';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label copiado al portapapeles';
  }

  @override
  String get copy => 'Copiar';

  @override
  String get copyAiResponse => 'Copiar respuesta de la IA';

  @override
  String get copyDescription => 'Copiar descripción';

  @override
  String get copyTitle => 'Copiar título';

  @override
  String get copyUrl => 'Copiar URL';

  @override
  String get couldNotDownloadPdf => 'No se pudo descargar el PDF';

  @override
  String get couldNotLoadBuildTargets =>
      'No se pudieron cargar los destinos de compilación';

  @override
  String get couldNotLoadDirectives => 'No se pudieron cargar las directivas';

  @override
  String get couldNotOpenLink => 'No se pudo abrir el enlace';

  @override
  String couldNotOpenPdf(Object error) {
    return 'No se pudo abrir el PDF: $error';
  }

  @override
  String get couldNotOpenPicker => 'No se pudo abrir el selector.';

  @override
  String get create => 'Crear';

  @override
  String get createApp => 'Crear app';

  @override
  String get createFirstApp => 'Crea tu primera app para empezar';

  @override
  String get createIssue => 'Crear incidencia';

  @override
  String createdAgo(Object time) {
    return 'creado $time';
  }

  @override
  String get creating => 'Creando...';

  @override
  String criticalCount(Object count) {
    return '$count críticos';
  }

  @override
  String get customAutomationPromptHint =>
      'Prompt de automatización personalizado...';

  @override
  String get customPrompt => 'Prompt personalizado';

  @override
  String get dashboard => 'Panel';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteAutomation => 'Eliminar automatización';

  @override
  String deleteAutomationConfirm(Object app) {
    return '¿Eliminar la automatización de $app?';
  }

  @override
  String get deleteChat => 'Eliminar chat';

  @override
  String get deleteChatConfirm => '¿Eliminar esta conversación?';

  @override
  String deleteConfirmTitled(Object title) {
    return '¿Eliminar \"$title\"?\nEsta acción no se puede deshacer.';
  }

  @override
  String get deleteFailed => 'Error al eliminar';

  @override
  String get deleteReportBody =>
      'Esto elimina permanentemente el informe y sus capturas de pantalla.';

  @override
  String get deleteReportTitle => '¿Eliminar informe?';

  @override
  String get deleted => 'Eliminado';

  @override
  String get dependsOn => 'Depende de';

  @override
  String get deploy => 'Desplegar';

  @override
  String get deployToProduction => 'Desplegar a producción';

  @override
  String get deployToProductionBody =>
      'Esto compilará y publicará para TODOS los usuarios en Google Play.\n\nAsegúrate de haberlo probado antes en interno/beta.';

  @override
  String get deployToProductionTitle => '¿Desplegar a producción?';

  @override
  String get descriptionHint => 'Descripción...';

  @override
  String get designDoc => 'Documento de diseño';

  @override
  String get designDocHint =>
      'Describe la visión, funciones y objetivos de tu app...';

  @override
  String get designDocSaved => 'Documento de diseño guardado';

  @override
  String get designDocShort => 'Documento de diseño';

  @override
  String get designDocSubtitle =>
      'La IA usará esto como contexto para todo el trabajo en esta app.';

  @override
  String designDocTitle(Object app) {
    return 'Documento de diseño - $app';
  }

  @override
  String get designDocument => 'Documento de diseño';

  @override
  String get designReview => 'Revisión de diseño';

  @override
  String get designReviewSubtitle => 'GDD, mecánicas, auditoría de UX';

  @override
  String get designReviewTaskCreated => 'Tarea de revisión de diseño creada';

  @override
  String get details => 'Detalles';

  @override
  String get detectingServer => 'Detectando servidor...';

  @override
  String get developer => 'Desarrollador';

  @override
  String get directServerUrlLan => 'URL directa del servidor (LAN)';

  @override
  String get directiveHistory => 'Historial de directivas';

  @override
  String get dismiss => 'Descartar';

  @override
  String get display => 'Pantalla';

  @override
  String get doIt => 'Hacerlo';

  @override
  String get done => 'Hecho';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total hechas';
  }

  @override
  String durationLabelWith(Object seconds) {
    return 'Duración: ${seconds}s';
  }

  @override
  String get edit => 'Editar';

  @override
  String editNamed(Object label) {
    return 'Editar $label';
  }

  @override
  String editTitleNamed(Object app) {
    return 'Editar: $app';
  }

  @override
  String get editWorkerUrl => 'Editar URL del Worker';

  @override
  String get engine => 'Motor';

  @override
  String engineChanged(Object previous, Object current) {
    return 'Motor cambiado: $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'Motor confirmado: $engine';
  }

  @override
  String get engineDetectionFailed => 'Fallo en la detección del motor';

  @override
  String get enhance => 'Mejorar';

  @override
  String get enhanceConfirmBody =>
      'La IA reescribirá el documento. Esta acción no se puede deshacer.';

  @override
  String enhanceConfirmTitle(Object label) {
    return '¿Mejorar $label?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return 'Error al mejorar $label: $error';
  }

  @override
  String enhanceStarted(Object label) {
    return 'Mejora de $label iniciada en el servidor...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label mejorado correctamente';
  }

  @override
  String get enhancementFailed => 'Error al mejorar';

  @override
  String get enterConceptOrName => 'Introduce un concepto o nombre de proyecto';

  @override
  String get enterServerUrlDesc =>
      'Introduce la URL de tu servidor de Auto Game Builder';

  @override
  String get enterUrlInPhoneApp =>
      'Introduce esta URL en la app del teléfono para conectar de forma remota';

  @override
  String get enterValidUrl =>
      'Introduce una URL válida (p. ej. http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc =>
      'Introduce la URL de tu Worker para conectar de forma remota';

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return 'Cada $minutes min';
  }

  @override
  String exitLabelWith(Object code) {
    return 'Salida: $code';
  }

  @override
  String get expandFoldersOrCreate =>
      'Despliega las carpetas de abajo o crea una nueva app';

  @override
  String get failed => 'Fallido';

  @override
  String failedCountLabel(Object count) {
    return '$count fallidos';
  }

  @override
  String get failedToBrainstorm => 'Error al generar ideas';

  @override
  String get failedToCreateApp => 'Error al crear la app';

  @override
  String get failedToCreateItem => 'Error al crear el elemento';

  @override
  String get failedToCreateTestTask => 'Error al crear la tarea de prueba';

  @override
  String get failedToDelete => 'Error al eliminar';

  @override
  String get failedToLoadApp => 'Error al cargar la app';

  @override
  String get failedToLoadAutomations => 'Error al cargar las automatizaciones';

  @override
  String get failedToLoadLogs => 'Error al cargar los registros';

  @override
  String get failedToLoadTasks => 'Error al cargar las tareas';

  @override
  String failedToLoadWithError(Object error) {
    return 'Error al cargar: $error';
  }

  @override
  String get failedToRefreshApp => 'Error al actualizar la app';

  @override
  String get failedToRequestCodeCheck =>
      'Error al solicitar la revisión de código';

  @override
  String get failedToRequestIdeas => 'Error al solicitar ideas';

  @override
  String get failedToReset => 'Error al restablecer';

  @override
  String get failedToRunTask => 'Error al ejecutar la tarea';

  @override
  String failedToSave(Object error) {
    return 'Error al guardar: $error';
  }

  @override
  String get failedToStartReupload => 'Error al iniciar la nueva subida';

  @override
  String failedToStartServer(Object error) {
    return 'Error al iniciar el servidor: $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return 'Error al iniciar: $error';
  }

  @override
  String failedToTrigger(Object action) {
    return 'Error al activar $action';
  }

  @override
  String get failedToTriggerRun => 'Error al activar la ejecución';

  @override
  String get failedToUpdate => 'Error al actualizar';

  @override
  String get failedToUpdateAiAgent => 'Error al actualizar el agente IA';

  @override
  String get failedToUpdateMcp => 'Error al actualizar MCP';

  @override
  String get favoritesOnly => 'Solo favoritos';

  @override
  String get feedback => 'Comentarios';

  @override
  String fileTooLarge(Object max, Object files) {
    return 'Demasiado grande (máx. $max MB): $files';
  }

  @override
  String get filterAll => 'Todos';

  @override
  String get filterClosed => 'Cerrados';

  @override
  String get filterOpen => 'Abiertos';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hallazgos',
      one: '1 hallazgo',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return 'hecho $time';
  }

  @override
  String finishedFailedAgo(Object time) {
    return 'fallido $time';
  }

  @override
  String forceRefreshFailed(Object error) {
    return 'Error al forzar la actualización: $error';
  }

  @override
  String get forceRefreshTooltip =>
      'Forzar actualización desde el servidor (borra la caché local)';

  @override
  String get fullAutoMode => 'Modo automático completo';

  @override
  String get fullAutoModeOn =>
      'La IA lee tareas, corrige, genera nuevas ideas y repite';

  @override
  String get generate => 'Generar';

  @override
  String get generateIdeas => 'Generar ideas';

  @override
  String get generateIdeasHint => 'p. ej. \"Ideas para mejorar la UI\"';

  @override
  String get genre => 'Género';

  @override
  String get genreAction => 'Acción';

  @override
  String get genreAny => 'Cualquiera';

  @override
  String get genreArcade => 'Arcade';

  @override
  String get genreCardGame => 'Juego de cartas';

  @override
  String get genreIdleClicker => 'Idle/Clicker';

  @override
  String get genrePuzzle => 'Puzle';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'Simulación';

  @override
  String get genreStrategy => 'Estrategia';

  @override
  String get genreTowerDefense => 'Tower defense';

  @override
  String get getStarted => 'Empezar';

  @override
  String get googleAccount => 'Cuenta de Google';

  @override
  String get hide => 'Ocultar';

  @override
  String highCount(Object count) {
    return '$count altos';
  }

  @override
  String get ideaGenerationRequested => 'Generación de ideas solicitada';

  @override
  String get installed => 'instalado';

  @override
  String get intervalMinLabel => 'Intervalo (min): ';

  @override
  String get invalidQrData => 'Datos de código QR no válidos';

  @override
  String get issueCreated => 'Incidencia creada';

  @override
  String get issueTitleHint => 'Título de la incidencia';

  @override
  String get issues => 'Incidencias';

  @override
  String get itemCreated => 'Elemento creado';

  @override
  String get justNow => 'Ahora mismo';

  @override
  String get language => 'Idioma';

  @override
  String get later => 'Más tarde';

  @override
  String get links => 'Enlaces';

  @override
  String get loginTagline =>
      'Gestiona tus proyectos de juegos desde cualquier lugar';

  @override
  String get logs => 'Registros';

  @override
  String get maintenanceOnly => 'Solo mantenimiento';

  @override
  String get markAsCompleted => 'Marcar como completada';

  @override
  String get markComplete => 'Marcar como completada';

  @override
  String markCompleteConfirm(Object title) {
    return '¿Marcar \"$title\" como completada?';
  }

  @override
  String get markedAsCompleted => 'Marcada como completada';

  @override
  String maxMinutes(Object minutes) {
    return 'Máx. ${minutes}m';
  }

  @override
  String get maxSessionMinLabel => 'Sesión máx. (min): ';

  @override
  String get mcpConfiguredPerApp =>
      'Los servidores MCP se configuran por app en la página de detalle de la app.';

  @override
  String get mcpServers => 'Servidores MCP';

  @override
  String mcpServersActive(Object count) {
    return 'Servidores MCP ($count activos)';
  }

  @override
  String get mcpServersDesc =>
      'Servidores de herramientas disponibles para todas las ejecuciones de IA en esta app';

  @override
  String mediumCount(Object count) {
    return '$count medios';
  }

  @override
  String get moveBackToActive => 'Volver a Activas';

  @override
  String get moveToCompletedFolder => 'Mover a la carpeta de completadas';

  @override
  String get nameIsRequired => 'El nombre es obligatorio';

  @override
  String get needHelpSettingUp => '¿Necesitas ayuda con la configuración?';

  @override
  String get newApp => 'Nueva app';

  @override
  String get newAutomation => 'Nueva automatización';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get newItem => 'Nuevo elemento';

  @override
  String get newPrompt => 'Nuevo prompt';

  @override
  String newReportsCount(Object count) {
    return '$count informe(s) nuevo(s)';
  }

  @override
  String get nextRunIn => 'Próxima ejecución en';

  @override
  String get noApiKeyFound =>
      'No se encontró clave de API; reinicia el servidor para generar una';

  @override
  String get noAppsMatch => 'Ninguna app coincide';

  @override
  String get noAppsYet => 'Aún no hay apps';

  @override
  String get noArtBibleYet =>
      'Aún no hay biblia de arte. Toca Añadir para definir la identidad visual: paleta, tipografía, prohibiciones.';

  @override
  String get noAutomationsMatchFilters =>
      'Ninguna automatización coincide con los filtros';

  @override
  String get noAutomationsYet => 'Aún no hay automatizaciones';

  @override
  String noBuildTargetsFor(Object type) {
    return 'No hay destinos de compilación para proyectos $type.';
  }

  @override
  String get noBuildsYet => 'Aún no hay compilaciones';

  @override
  String get noChatsYet => 'Aún no hay chats';

  @override
  String get noClaudeMdYet =>
      'Aún no hay CLAUDE.md. Toca Añadir para definir las instrucciones del proyecto para la IA.';

  @override
  String get noDesignDocYet =>
      'Aún no hay documento de diseño. Toca Añadir para describir la visión de tu app.';

  @override
  String get noDirectivesYet => 'Aún no se han enviado directivas.';

  @override
  String get noFavoritePrompts => 'Aún no hay prompts favoritos';

  @override
  String get noItemsFound => 'No se encontraron elementos';

  @override
  String get noLogsFound => 'No se encontraron registros';

  @override
  String get noNewReports => 'No hay informes nuevos';

  @override
  String get noOpenReports => 'No hay informes abiertos';

  @override
  String get noOpenTasksToDependOn =>
      'No hay tareas abiertas de las que depender';

  @override
  String get noPendingItems =>
      'No hay elementos pendientes en los que trabajar';

  @override
  String get noPromptHistory =>
      'Aún no hay historial de prompts.\nGenera ideas para crear historial.';

  @override
  String get noReportsHere => 'No hay informes aquí';

  @override
  String get noWorkerUrlDetected =>
      'No se detectó URL de Worker en settings.json.\nConfigura un Cloudflare Worker para habilitar el acceso remoto.';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get notConfigured => 'No configurado';

  @override
  String get notConnected => 'No conectado';

  @override
  String get notInstalled => 'no instalado';

  @override
  String get notPaired => 'No emparejado';

  @override
  String get notSet => '(no definido)';

  @override
  String get notYetUploaded => 'aún no subido';

  @override
  String get onHold => 'En espera';

  @override
  String get oneShotRunEndsIn => 'La ejecución única termina en';

  @override
  String oneTimeRunTriggered(Object app) {
    return 'Ejecución única de $app activada';
  }

  @override
  String openCountLabel(Object count) {
    return '$count abiertos';
  }

  @override
  String get openPdf => 'Abrir PDF';

  @override
  String get openingPdf => 'Abriendo PDF…';

  @override
  String get orSeparator => 'O';

  @override
  String get output => 'Salida';

  @override
  String get packageName => 'Nombre del paquete';

  @override
  String get paired => 'Emparejado';

  @override
  String get pairedSuccessfully => '¡Emparejado correctamente!';

  @override
  String get perfProfileTaskCreated => 'Tarea de perfil de rendimiento creada';

  @override
  String get performanceProfile => 'Perfil de rendimiento';

  @override
  String get performanceProfileSubtitle =>
      'Caídas de fotogramas, memoria, tiempo de carga';

  @override
  String get photo => 'Foto';

  @override
  String get postpone => 'Posponer';

  @override
  String postponedCount(Object count) {
    return 'Pospuestas ($count)';
  }

  @override
  String get pressBackAgainToExit => 'Pulsa atrás de nuevo para salir';

  @override
  String get previousChat => 'Chat anterior';

  @override
  String get priority => 'Prioridad';

  @override
  String processingTasks(Object done, Object total) {
    return 'Procesando $done de $total tareas...';
  }

  @override
  String get projectPath => 'Ruta del proyecto';

  @override
  String get promptHistory => 'Historial de prompts';

  @override
  String get promptHistoryTooltip => 'Historial de prompts';

  @override
  String get publish => 'Publicar';

  @override
  String get pullAndRebuild => 'Pull y recompilar';

  @override
  String get pullFailed => 'Error al hacer pull';

  @override
  String get pullNow => 'Hacer pull ahora';

  @override
  String get pullOnly => 'Solo pull';

  @override
  String purchaseFailed(Object error) {
    return 'Error en la compra: $error';
  }

  @override
  String get putOnHoldForLater => 'Poner en espera para más tarde';

  @override
  String get pythonSectionDesc =>
      'Ejecuta scripts y gestiona el proyecto Python a través del servidor.';

  @override
  String get quickIssue => 'Incidencia rápida';

  @override
  String get rePairWithQr => 'Volver a emparejar con código QR';

  @override
  String get rebuild => 'Recompilar';

  @override
  String get rebuildBody => '¿Iniciar una nueva compilación desde cero?';

  @override
  String get rebuildTitle => '¿Recompilar?';

  @override
  String get recentBuilds => 'Compilaciones recientes';

  @override
  String get refresh => 'Actualizar';

  @override
  String refreshFailedShowingCached(Object message) {
    return 'Error al actualizar; mostrando los últimos datos sincronizados. $message';
  }

  @override
  String get refreshedFromServer => 'Actualizado desde el servidor';

  @override
  String get reload => 'Recargar';

  @override
  String get reopen => 'Reabrir';

  @override
  String get reportBugOrSuggestion => 'Reportar un error o sugerencia';

  @override
  String get reportBugSubtitle => 'Cuéntanos qué corregir o añadir';

  @override
  String get reportConsent =>
      'Acepto enviar este informe junto con la información de mi dispositivo (modelo, SO y versión de la app) al desarrollador para ayudar a solucionar problemas.';

  @override
  String get reportHint => '¿Qué ha pasado o qué te gustaría ver?';

  @override
  String get reportSentThanks => '¡Gracias! Tu informe se ha enviado.';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetServer => 'Restablecer servidor';

  @override
  String get resetServerBody => 'Esto reiniciará el servidor backend.';

  @override
  String resetServerRunningNote(Object count) {
    return 'Primero se detendrán $count automatización(es) en ejecución para evitar el reinicio automático.';
  }

  @override
  String get resumeActiveDevelopment => 'Reanudar desarrollo activo';

  @override
  String get retry => 'Reintentar';

  @override
  String get retryUpload => 'Reintentar subida';

  @override
  String get reuploadStarted => 'Nueva subida iniciada';

  @override
  String get run => 'Ejecutar';

  @override
  String get runAgainBody =>
      'Ya hay una ejecución única en curso, pero es posible que la IA se haya detenido antes de tiempo. ¿Activar otra ejecución?';

  @override
  String get runAgainTitle => '¿Ejecutar de nuevo?';

  @override
  String get runAnyway => 'Ejecutar de todos modos';

  @override
  String get runCheck => 'Ejecutar comprobación';

  @override
  String get runOnce => 'Ejecutar una vez';

  @override
  String get runOnceInProgress => 'Ejecutar una vez (en curso)';

  @override
  String get running => 'Ejecutándose';

  @override
  String get save => 'Guardar';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get saveEmptyGddBody => 'Esto borrará el documento de diseño actual.';

  @override
  String get saveEmptyGddTitle => '¿Guardar GDD vacío?';

  @override
  String get saving => 'Guardando...';

  @override
  String scanError(Object error) {
    return 'Error de escaneo: $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'Error de escaneo: el servidor devolvió $status';
  }

  @override
  String get scanForProjects => 'Buscar proyectos';

  @override
  String get scanPairingQrTitle => 'Escanear código QR de emparejamiento';

  @override
  String get scanQrToPair => 'Escanear código QR para emparejar';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return 'Se escanearon $found carpetas: $imported importadas, $skipped omitidas';
  }

  @override
  String get scanThisQr => 'Escanea este QR desde tu teléfono';

  @override
  String get scanToInstall => 'Escanea para instalar en tu teléfono';

  @override
  String get scopeCheck => 'Revisión de alcance';

  @override
  String get scopeCheckSubtitle => 'Lista de recortes + pase de realismo';

  @override
  String get scopeCheckTaskCreated => 'Tarea de revisión de alcance creada';

  @override
  String get screenshotsOptional => 'Capturas de pantalla (opcional)';

  @override
  String get screenshotsTooLarge =>
      'Las capturas son grandes; puede que tengas que quitar alguna.';

  @override
  String get searchAppsHint => 'Buscar apps...';

  @override
  String searchFilterChip(Object query) {
    return 'Búsqueda: \"$query\"';
  }

  @override
  String get searchHint => 'Buscar...';

  @override
  String get sectionAiAgents => 'Agentes IA';

  @override
  String get sectionGameEngines => 'Motores de juego';

  @override
  String get sectionPaths => 'Rutas';

  @override
  String get sectionServices => 'Servicios';

  @override
  String get sectionSystemTools => 'Herramientas del sistema';

  @override
  String get selectAnApp => 'Selecciona una app';

  @override
  String get selectAnAppFirst => 'Selecciona primero una app';

  @override
  String get selectApp => 'Selecciona app';

  @override
  String get selectAppForContext =>
      'Selecciona una app para dar contexto, o haz preguntas generales';

  @override
  String get selectAppToViewItems =>
      'Selecciona una app para ver los elementos';

  @override
  String get selectCategoriesOrPrompt =>
      'Selecciona categorías o escribe tu propio prompt.';

  @override
  String get sendReport => 'Enviar informe';

  @override
  String get sending => 'Enviando…';

  @override
  String get server => 'Servidor';

  @override
  String get serverConfiguration => 'Configuración del servidor';

  @override
  String get serverConnection => 'Conexión con el servidor';

  @override
  String serverReturnedStatus(Object status) {
    return 'El servidor devolvió el estado $status';
  }

  @override
  String get serverStarted => '¡Servidor iniciado!';

  @override
  String get serverStartedHealthFailed =>
      'El servidor se inició, pero falló la comprobación de estado';

  @override
  String get serverStopped => 'Servidor detenido';

  @override
  String get serverUnreachable => 'Servidor inaccesible';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get sessionEndsIn => 'La sesión termina en';

  @override
  String get sessionRefreshed =>
      'Sesión actualizada; se ha conservado el contexto reciente';

  @override
  String get settings => 'Ajustes';

  @override
  String get settingsJsonNotFound => 'No se encontró settings.json';

  @override
  String get settingsJsonRestartNote =>
      'settings.json: reinicia el servidor tras los cambios';

  @override
  String get settingsSavedRestart =>
      'Ajustes guardados; reinicia el servidor para aplicarlos';

  @override
  String get setupInstructions => 'Instrucciones de configuración';

  @override
  String get setupServerFirst => 'Configura primero el servidor en tu PC';

  @override
  String get setupStepCloneRepo => 'Clona el repositorio:';

  @override
  String get setupStepEnterUrl =>
      'Introduce la URL que aparece en la terminal (p. ej. http://192.168.1.100:8000):';

  @override
  String get setupStepInstallDeps => 'Instala las dependencias:';

  @override
  String get setupStepInstallPython => 'Instala Python 3.10+ en tu PC';

  @override
  String get setupStepRunWizard => 'Ejecuta el asistente de configuración:';

  @override
  String get setupStepStartServer => 'Inicia el servidor:';

  @override
  String get show => 'Mostrar';

  @override
  String get showAll => 'Mostrar todo';

  @override
  String get showAppIcons => 'Mostrar iconos de las apps';

  @override
  String get showAppIconsDesc =>
      'Muestra los iconos reales de las apps en el panel en lugar de iconos genéricos por tipo';

  @override
  String get showPairingQr => 'Mostrar código QR de emparejamiento';

  @override
  String get signInCancelled => 'Se canceló el inicio de sesión';

  @override
  String signInFailed(Object error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signingIn => 'Iniciando sesión...';

  @override
  String get skipForNow => 'Omitir por ahora';

  @override
  String get start => 'Iniciar';

  @override
  String get startBuildFromCardAbove =>
      'Inicia una compilación desde la tarjeta de arriba';

  @override
  String get startServer => 'Iniciar servidor';

  @override
  String get startServerNotFound => 'No se encontró start_server.py';

  @override
  String get status => 'Estado';

  @override
  String get statusActive => 'Activa';

  @override
  String get statusAll => 'Todas';

  @override
  String get statusBuilt => 'Compilada';

  @override
  String get statusBuiltLower => 'Compilada';

  @override
  String get statusCompleted => 'Completada';

  @override
  String get statusDivided => 'Dividida';

  @override
  String get statusDone => 'Hecha';

  @override
  String get statusFailedLower => 'Fallida';

  @override
  String statusFilterChip(Object value) {
    return 'Estado: $value';
  }

  @override
  String get statusInProgress => 'En curso';

  @override
  String get statusPending => 'Pendiente';

  @override
  String get statusPendingLower => 'Pendiente';

  @override
  String get statusPostponed => 'Pospuesta';

  @override
  String get stop => 'Detener';

  @override
  String get stopServer => 'Detener servidor';

  @override
  String get stoppedLabel => 'Detenido';

  @override
  String stuckSuffix(Object time) {
    return '$time BLOQUEADA';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return '$count tarea(s) bloqueada(s) marcada(s) como fallida(s) automáticamente tras 30 min de espera';
  }

  @override
  String get studioReviews => 'Reseñas del estudio';

  @override
  String get submit => 'Enviar';

  @override
  String get submitting => 'Enviando...';

  @override
  String get suggestApiBackend => 'API y backend';

  @override
  String get suggestFeatureIntegration => 'Integración de funciones';

  @override
  String get suggestFixFailures => 'Corregir fallos';

  @override
  String get suggestGddAligned => 'Alineado con el GDD';

  @override
  String get suggestImproveCodebase => 'Mejorar el código base';

  @override
  String get suggestNextMilestone => 'Próximo hito';

  @override
  String get suggestPerformanceBoost => 'Mejora de rendimiento';

  @override
  String get suggestRevenueIdeas => 'Ideas de ingresos';

  @override
  String get suggestSecurityHardening => 'Refuerzo de seguridad';

  @override
  String get suggestTaskPrioritization => 'Priorización de tareas';

  @override
  String get suggestTestingQa => 'Pruebas y QA';

  @override
  String get suggestUserEngagement => 'Interacción de usuarios';

  @override
  String get suggestUxPolish => 'Pulido de UX';

  @override
  String get suggestedForYou => 'Sugerido para ti';

  @override
  String get summary => 'Resumen';

  @override
  String get supportDevelopment => 'Apoya el desarrollo';

  @override
  String get supportDevelopmentDesc =>
      '¿Te gusta la app? ¡Considera apoyar su desarrollo!';

  @override
  String get syncFailed => 'Error de sincronización';

  @override
  String syncedAgo(Object time) {
    return 'Sincronizado $time';
  }

  @override
  String get tapPlusToCreateAutomation =>
      'Toca + para crear tu primera automatización';

  @override
  String get tapPlusToStartConversation =>
      'Toca + para iniciar una conversación';

  @override
  String get tapToAddLongPressToEdit =>
      'Toca para añadir, mantén pulsado para editar';

  @override
  String get tapToOpenLongPressToEdit =>
      'Toca para abrir, mantén pulsado para editar';

  @override
  String get tapToRedetectEngine =>
      'Toca para volver a detectar el motor desde el disco';

  @override
  String taskLabelWith(Object task) {
    return 'Tarea: $task';
  }

  @override
  String get taskOverview => 'Resumen de tareas';

  @override
  String get taskResetToPending => 'Tarea restablecida a pendiente';

  @override
  String get tasks => 'Tareas';

  @override
  String get techDebtScan => 'Análisis de deuda técnica';

  @override
  String get techDebtScanSubtitle => 'Scripts monolíticos, duplicados, TODOs';

  @override
  String get techDebtTaskCreated => 'Tarea de análisis de deuda técnica creada';

  @override
  String get tellUsMore => 'Cuéntanos más';

  @override
  String get test => 'Probar';

  @override
  String get testConnection => 'Probar conexión';

  @override
  String get testTaskCreated => 'Tarea de prueba creada';

  @override
  String get testing => 'Probando...';

  @override
  String get theme => 'Tema';

  @override
  String get thinking => 'Pensando...';

  @override
  String timeDaysAgo(Object days) {
    return 'hace ${days}d';
  }

  @override
  String timeHoursAgo(Object hours) {
    return 'hace ${hours}h';
  }

  @override
  String get timeJustNow => 'ahora mismo';

  @override
  String timeMinutesAgo(Object minutes) {
    return 'hace ${minutes}min';
  }

  @override
  String timeMonthsAgo(Object months) {
    return 'hace ${months}mes';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return 'hace ${seconds}s';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return 'hace ${weeks}sem';
  }

  @override
  String get titleHint => 'Título';

  @override
  String get titleIsRequired => 'El título es obligatorio';

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
    return 'Activados $done de $total elementos';
  }

  @override
  String get tryChangingFilters =>
      'Prueba a cambiar el filtro de categoría o estado';

  @override
  String get type => 'Tipo';

  @override
  String get typeBug => 'Error';

  @override
  String get typeFeature => 'Función';

  @override
  String typeFilterChip(Object value) {
    return 'Tipo: $value';
  }

  @override
  String get typeFix => 'Corrección';

  @override
  String get typeIdea => 'Idea';

  @override
  String get typeIssue => 'Incidencia';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String get updateAvailableBody =>
      'Hay una nueva versión disponible en GitHub.\nHaz pull del código más reciente y recompila para actualizar.';

  @override
  String get updateFailed => 'Error al actualizar';

  @override
  String updatedAgo(Object time) {
    return 'actualizado $time';
  }

  @override
  String updatedNamed(Object label) {
    return '$label actualizado';
  }

  @override
  String get uploadToGooglePlay => 'Subir a Google Play';

  @override
  String urgentCountLabel(Object count) {
    return '$count urgentes';
  }

  @override
  String get urgentLabel => 'urgente';

  @override
  String get userFallback => 'Usuario';

  @override
  String get version => 'Versión';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => 'Ver tareas fallidas';

  @override
  String get viewIssues => 'Ver incidencias';

  @override
  String get viewOnGitHub => 'Ver en GitHub';

  @override
  String get warningPublishesToAll =>
      'Aviso: ¡esto publica para todos los usuarios!';

  @override
  String get webDeploy => 'Despliegue web';

  @override
  String get webDeploySectionDesc =>
      'Compila y despliega la app web a través del servidor.';

  @override
  String get website => 'Sitio web';

  @override
  String get whatIsThis => '¿Qué es esto?';

  @override
  String get workOnAll => 'Trabajar en todas';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n($count elemento(s) bloqueado(s) se omitirán.)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return '¿Ejecutar la IA en los $count elemento(s) pendiente(s)?\nSe procesarán secuencialmente.';
  }

  @override
  String get workOnAllPending => 'Trabajar en todas las pendientes';

  @override
  String get workOnThis => 'Trabajar en esto';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return 'Ejecutar IA $agent en:\n\"$title\"';
  }

  @override
  String get workerUrl => 'URL del Worker';

  @override
  String get workerUrlAutoDetected =>
      'Detectada automáticamente en settings.json (solo lectura)';

  @override
  String get workerUrlCopied => 'URL del Worker copiada';

  @override
  String get workerUrlHelp =>
      'Obtén esta URL desde la app de escritorio o tu administrador del servidor';

  @override
  String get workerUrlSaved => 'URL del Worker guardada';

  @override
  String get workerUrlSetHint =>
      'Define cloudflare.worker_url en server/config/settings.json';

  @override
  String get youreAllSet => '¡Ya está todo listo!';
}

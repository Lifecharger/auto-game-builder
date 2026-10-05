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
  String get shareUsageStats => 'Compartir estadísticas de uso anónimas';

  @override
  String get shareUsageStatsDesc =>
      'Recuentos anónimos de sesiones y pantallas abiertas. Sin nombres de proyecto, sin texto de tareas, sin rutas.';

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

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'Aún no hay AGENTS.md. Toca Añadir para definir las instrucciones del proyecto para la IA.';

  @override
  String get cannotSaveEmptyAgentsMd =>
      'No se puede guardar un AGENTS.md vacío';

  @override
  String get agentsMdSaved => 'AGENTS.md guardado';

  @override
  String get reportEmailLabel => 'Correo (opcional)';

  @override
  String get reportEmailHint => 'tu correo, si quieres respuesta';

  @override
  String get reportEmailNote =>
      'Solo se usa para responder a este reporte. Déjalo vacío para seguir siendo anónimo.';

  @override
  String get reportEmailInvalid => 'Esto no parece una dirección de correo.';

  @override
  String get reportReply => 'Responder';

  @override
  String reportReplySubject(String app) {
    return 'Sobre tu reporte de $app';
  }

  @override
  String get navGenerate => 'Generar';

  @override
  String get navGallery => 'Generados';

  @override
  String get navFlow => 'Línea';

  @override
  String get navQueue => 'Cola';

  @override
  String get navDelivery => 'Entrega';

  @override
  String get navBuckets => 'Buckets';

  @override
  String get assetModeTooltip => 'Modo de recursos';

  @override
  String get deliveryModeTooltip => 'Modo de entrega';

  @override
  String get videoPlaybackFailed => 'No se pudo reproducir el vídeo';

  @override
  String get apiKeyRefusedBanner =>
      'Clave de API rechazada - toca para corregirla en Ajustes';

  @override
  String get errOffline =>
      'No se puede contactar con el servidor - comprueba tu conexión';

  @override
  String get errTimeout =>
      'El servidor tardó demasiado en responder - inténtalo de nuevo';

  @override
  String errGatewayTimeout(int status) {
    return 'El servidor no respondió a tiempo (tiempo de espera de la pasarela $status)';
  }

  @override
  String errGateway(int status) {
    return 'El servidor no responde tras su pasarela (error de pasarela $status) - comprueba que esté en marcha';
  }

  @override
  String errServer(int status) {
    return 'Error del servidor ($status) - inténtalo más tarde';
  }

  @override
  String errUnauthorized(int status) {
    return 'No autorizado ($status) - revisa la clave de API en Ajustes';
  }

  @override
  String errNotFound(int status) {
    return 'No encontrado en el servidor ($status)';
  }

  @override
  String errRateLimited(int status) {
    return 'Demasiadas solicitudes ($status) - espera un momento e inténtalo de nuevo';
  }

  @override
  String errTooLarge(int status) {
    return 'Demasiado grande para el servidor ($status)';
  }

  @override
  String errRejected(int status) {
    return 'El servidor rechazó la solicitud ($status)';
  }

  @override
  String get errBadResponse =>
      'El servidor envió una respuesta que la app no pudo leer';

  @override
  String get errUnknown => 'La solicitud falló - inténtalo de nuevo';

  @override
  String bucketsCounting(String bucket) {
    return 'Contando $bucket...';
  }

  @override
  String get bucketsTakedownTitle => 'Retirada (nuevo + antiguo)';

  @override
  String get bucketsDeleteForeverTitle => 'Eliminar definitivamente';

  @override
  String bucketsDeleteWarning(int count) {
    return 'Se eliminarán $count objetos. NO SE PUEDE DESHACER.';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count claves no tienen equivalente en el gemelo antiguo - solo se eliminan de este bucket.';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return 'Escribe el nombre del bucket para confirmar: $bucket';
  }

  @override
  String get bucketsTakedown => 'Retirar';

  @override
  String bucketsDeleted(int count) {
    return '$count objetos eliminados';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count objetos eliminados, $twin del gemelo antiguo';
  }

  @override
  String bucketsCopySource(String path) {
    return 'Origen: $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'Árbol de origen: $path';
  }

  @override
  String get bucketsWholeBucket => '(todo el bucket)';

  @override
  String get bucketsCopyNote =>
      'La copia se ejecuta dentro del servicio de almacenamiento - ningún byte pasa por el teléfono.';

  @override
  String get bucketsTargetKey => 'Clave de destino';

  @override
  String get bucketsTargetPrefix => 'Prefijo de destino';

  @override
  String bucketsCopyStarted(String op) {
    return 'Copia iniciada ($op)';
  }

  @override
  String get bucketsFixHeadersTitle => 'Corregir cabeceras';

  @override
  String bucketsFixHeadersBody(String path) {
    return 'Se comprueba la cabecera Cache-Control de los objetos bajo $path; un objeto que se aparta del estándar se reescribe en su sitio (se conserva Content-Type). No se descargan bytes.\n\nLos prefijos que se dejan mutables a propósito se omiten.';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'Reparación de cabeceras iniciada ($op)';
  }

  @override
  String get bucketsOperations => 'Operaciones';

  @override
  String get bucketsNoOperations => 'Aún no hay operaciones';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  ok $ok  ·  fallos $failed';
  }

  @override
  String get bucketsTwinDiffRunning =>
      'Calculando la diferencia con el gemelo...';

  @override
  String get bucketsLocalDiffRunning => 'Calculando la diferencia local...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin (gemelo antiguo)';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'Carpeta local enviada <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => 'Falta en el gemelo antiguo';

  @override
  String get bucketsMissingInBucket => 'Falta en el bucket';

  @override
  String get bucketsOnlyInLegacy => 'Solo en el gemelo antiguo';

  @override
  String get bucketsOnlyInBucket => 'Solo en el bucket';

  @override
  String get bucketsSizeMismatch => 'Tamaño distinto';

  @override
  String get bucketsUnmapped => 'Sin correspondencia (sin regla)';

  @override
  String get bucketsDerived => 'Generado en el bucket (miniaturas)';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title: $count';
  }

  @override
  String get bucketsFixFolderHeaders =>
      'Corregir las cabeceras de esta carpeta';

  @override
  String get bucketsDiffs => 'Diferencias';

  @override
  String get bucketsTwinDiff => 'Diferencia con el gemelo antiguo';

  @override
  String get bucketsLocalDiff => 'Diferencia con la carpeta local enviada';

  @override
  String get bucketsIntro =>
      'Un bucket es el almacén que lleva el nombre de su contenido. Los recuentos se calculan a petición (solo listado, no se descargan bytes).';

  @override
  String get bucketsBadgeLegacy => 'ANTIGUO';

  @override
  String get bucketsBadgePrivate => 'privado';

  @override
  String get bucketsBadgeContent => 'contenido';

  @override
  String get bucketsNotCounted => 'sin contar';

  @override
  String bucketsObjectCount(int count) {
    return '$count objetos';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'gemelo: $twin';
  }

  @override
  String get bucketsCount => 'Contar';

  @override
  String get bucketsEmptyFolder => 'Esta carpeta está vacía';

  @override
  String get bucketsTruncated =>
      'La lista se ha recortado - abre una carpeta más concreta';

  @override
  String bucketsSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get bucketsClearSelection => 'Quitar selección';

  @override
  String get bucketsTakedownTooltip =>
      'Retirada (eliminar también del gemelo antiguo)';

  @override
  String get bucketsSize => 'Tamaño';

  @override
  String get bucketsContentType => 'Tipo';

  @override
  String get bucketsModified => 'Modificado';

  @override
  String get bucketsNone => '(ninguno)';

  @override
  String get bucketsMutableOnPurpose =>
      'Mutable a propósito - no se aplica el estándar';

  @override
  String bucketsHeaderOk(String kind) {
    return 'Cumple el estándar de caché ($kind)';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return 'Estándar: $expected';
  }

  @override
  String get bucketsLegacyTwin => 'Gemelo antiguo';

  @override
  String get bucketsAddressCopied => 'Dirección copiada';

  @override
  String get bucketsCopyAddress => 'Copiar dirección';

  @override
  String get bucketsOpen => 'Abrir';

  @override
  String get bucketsPrivateNoAddress =>
      'Este bucket es privado - no tiene dirección pública';

  @override
  String get kindCard => 'Carta';

  @override
  String get kindCharacter => 'Personaje';

  @override
  String get assetCodeMode => 'Modo de código';

  @override
  String get assetPickFinishedImage => 'Selecciona una imagen terminada';

  @override
  String get assetGenerateVideo => 'Generar vídeo';

  @override
  String get assetEnlarge => 'Ampliar';

  @override
  String percentValue(Object value) {
    return '$value %';
  }

  @override
  String get commonCategory => 'Categoría';

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
  String get charKindFemale => 'Mujer';

  @override
  String get charKindMale => 'Hombre';

  @override
  String get charKindAnimal => 'Animal';

  @override
  String get charKindMachine => 'Máquina';

  @override
  String get outfitCatSet => 'Conjunto';

  @override
  String get outfitCatTop => 'Superior';

  @override
  String get outfitCatBottom => 'Inferior';

  @override
  String get outfitCatShoes => 'Zapatos';

  @override
  String get outfitCatSocks => 'Calcetines';

  @override
  String get outfitCatHat => 'Sombrero';

  @override
  String get outfitCatHeadgear => 'Tocado';

  @override
  String get outfitCatAccessory => 'Accesorio';

  @override
  String get outfitCatWeapon => 'Arma';

  @override
  String get audioLabel => 'Audio';

  @override
  String get audioDownloading => 'Descargando...';

  @override
  String get audioOpen => 'Abrir audio';

  @override
  String get outfitExtractTitle => 'Extraer atuendo';

  @override
  String get outfitExtractBody =>
      'Se elimina a la persona de la imagen seleccionada y el atuendo se guarda en el armario como foto de producto en maniquí invisible sobre fondo gris liso. Después cualquier personaje puede llevarlo como skin.';

  @override
  String get outfitExtractName => 'Nombre del atuendo';

  @override
  String get outfitExtractNameHint => 'p. ej. Vestido de noche rojo';

  @override
  String get outfitExtractNote => 'Nota (opcional)';

  @override
  String get outfitExtractNoteHint => 'p. ej. solo el vestido, sin los zapatos';

  @override
  String get outfitExtractHelp =>
      'Conjunto: todo lo que lleva la persona en una sola imagen. Arma / accesorio: solo ese objeto, sin maniquí.';

  @override
  String get outfitExtractAction => 'Extraer';

  @override
  String equipSlotTitle(Object category) {
    return 'Ranura: $category';
  }

  @override
  String get equipSlotMultiHint =>
      'selección múltiple - toca para poner / quitar';

  @override
  String get equipSlotSingleHint =>
      'selección única - toca para poner, toca otra vez para quitar';

  @override
  String get equipSlotEmpty => '(vacío)';

  @override
  String get equipSlotNoOutfits =>
      'No hay atuendos listos en esta categoría - usa «+ Generar atuendo» o «Extraer atuendo»';

  @override
  String get equipBaseLabel => 'Base:';

  @override
  String get equipUndress => 'Quitar todo';

  @override
  String get equipPickSourceTitle => 'Elige una imagen de origen';

  @override
  String get equipPickSourceHint =>
      'Las últimas generaciones terminadas (todos los modos). Para las imágenes incoming / staging / pushed de la línea Jigsaw usa la pantalla Línea > Jigsaw.';

  @override
  String get equipNoFinishedImage => 'No hay imágenes terminadas';

  @override
  String get freeFlowTitle => 'Línea Free';

  @override
  String get freeFlowEditTitle => 'Editar - motor de edición';

  @override
  String get freeFlowEditLabel => 'Qué debe cambiar';

  @override
  String get freeFlowEditHint =>
      'p. ej. change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => 'Edición añadida a la cola';

  @override
  String get freeFlowNoVideoTask => 'El modo Free no tiene tarea de vídeo';

  @override
  String freeFlowVideoTitle(Object task) {
    return 'Generar vídeo - $task';
  }

  @override
  String get freeFlowMotionLabel => 'Movimiento';

  @override
  String get freeFlowMotionHint =>
      'p. ej. she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued =>
      'Vídeo añadido a la cola - cuando termine aparecerá una marca de reproducción en esta tarjeta';

  @override
  String get freeFlowDeleteConfirm => '¿Eliminar esta generación?';

  @override
  String get freeFlowDeleteWithVideosConfirm =>
      '¿Eliminar esta generación y sus vídeos?';

  @override
  String get freeFlowEmpty =>
      'Aún no se ha generado nada en modo Free - empieza desde la pestaña Generar';

  @override
  String get queueKindGeneration => 'Generación';

  @override
  String get queueKindTag => 'Etiquetado';

  @override
  String get queueKindMusic => 'Música';

  @override
  String get queueKindJob => 'Trabajo';

  @override
  String get queueCancelRunningTitle => 'Cancelar el trabajo en curso';

  @override
  String get queueRemoveTitle => 'Quitar de la cola';

  @override
  String get queueCancelIt => 'Cancelar';

  @override
  String get queueClearTitle => 'Vaciar la cola';

  @override
  String get queueClearBody =>
      '¿Cancelar los trabajos de generación en espera? El trabajo en curso continúa.';

  @override
  String get queueCancelWaiting => 'Cancelar los trabajos en espera';

  @override
  String get queueEmpty => 'La cola está vacía';

  @override
  String get queueEmptyHint =>
      'Puedes añadir trabajos desde la pestaña Generar';

  @override
  String get queueNow => 'Ahora';

  @override
  String queueWaitingCount(Object count) {
    return 'En espera ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return 'Trabajos de generación ($count)';
  }

  @override
  String get queueOneQueue => 'Una sola cola - todos los trabajos';

  @override
  String queueJobCount(Object count) {
    return '$count trabajos';
  }

  @override
  String get queueMoveUp => 'Subir';

  @override
  String get queueMoveDown => 'Bajar';

  @override
  String get queueUp => 'Arriba';

  @override
  String get queueDown => 'Abajo';

  @override
  String queueElapsed(Object time) {
    return 'transcurrido $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return 'en espera $time';
  }

  @override
  String get queueWaiting => 'en espera';

  @override
  String get queueComfyReady => 'ComfyUI listo';

  @override
  String get queueComfyOff => 'ComfyUI está apagado';

  @override
  String get deliveryPoolNeverRan => 'nunca se ejecutó';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (simulacro)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · $total imágenes, $valid válidas, $tagged etiquetadas, $failed fallidas';
  }

  @override
  String get reportErrEmpty => 'Escribe primero un mensaje.';

  @override
  String get reportErrTooLarge =>
      'Los adjuntos son demasiado grandes. Quita uno e inténtalo de nuevo.';

  @override
  String flowOpError(Object message) {
    return 'La operación falló: $message';
  }

  @override
  String get flowOpCancelled => 'Operación cancelada';

  @override
  String flowOpDone(Object ok) {
    return '$ok hechos';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok hechos, $failed fallidos';
  }

  @override
  String get flowCollection => 'Colección';

  @override
  String get flowAllParen => '(todas)';

  @override
  String get flowAll => 'todas';

  @override
  String get flowSelectAll => 'Seleccionar todo';

  @override
  String get flowRetag => 'Volver a etiquetar';

  @override
  String get flowRetagShort => 'Etiquetar';

  @override
  String get flowRetagStarted => 'Etiquetado iniciado';

  @override
  String get flowReadOnly => 'Solo lectura';

  @override
  String get flowPush => 'Push';

  @override
  String get flowPreview => 'Vista previa';

  @override
  String get flowYes => 'sí';

  @override
  String get flowNo => 'no';

  @override
  String get flowMissingUpper => 'FALTA';

  @override
  String get flowBadgeNoTags => 'sin etiquetas';

  @override
  String get flowTabPushed => '4 Publicados';

  @override
  String get flowSelectAssetFirst => 'Selecciona primero un recurso';

  @override
  String get flowAccept => 'Aceptar';

  @override
  String get flowReject => 'Rechazar';

  @override
  String get flowUpload => 'Subir';

  @override
  String get flowNew => 'Nueva';

  @override
  String get flowReadFailed => 'No se pudo leer la línea';

  @override
  String flowFilesDeleted(Object count) {
    return '$count archivos eliminados';
  }

  @override
  String get flowNegative => 'Negativo';

  @override
  String get flowPositive2 => 'Positivo 2';

  @override
  String get flowDuration => 'Duración';

  @override
  String get flowAddToQueue => 'Añadir a la cola';

  @override
  String get commonDescription => 'Descripción';

  @override
  String get cbnFlowTitle => 'Línea CBN';

  @override
  String get cbnFlowTabIncoming => '2 Entrantes';

  @override
  String get cbnFlowTabReady => '3 Listos';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'Construir - $count recursos';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      'Regiones + paleta + plantilla numerada + vídeo reveal (CPU). El paso SAM debe estar hecho; los contornos salen de los límites de SAM. (Hot: la construcción genera la página de líneas con Qwen; el paso C es una vista previa opcional.)';

  @override
  String get cbnFlowBuildBodyKid =>
      'Regiones + paleta + plantilla numerada + SVG (CPU). El paso SAM debe estar hecho.';

  @override
  String get cbnFlowBuild => 'Construir';

  @override
  String get cbnFlowBuildStarted =>
      'Construcción iniciada - el progreso se muestra arriba';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stage iniciado ($count recursos)';
  }

  @override
  String get cbnFlowStageObjects => 'Lista de objetos';

  @override
  String get cbnFlowLineart => 'Líneas';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'Push - $count recursos';
  }

  @override
  String get cbnFlowPushBody =>
      'Las carpetas de recursos se subirán a R2 y pasarán a «Publicados».\n\nEs una PUBLICACIÓN y no se puede deshacer.';

  @override
  String cbnFlowDeleteBody(Object count) {
    return 'Se eliminarán $count recursos.';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count eliminados';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'No hay recursos en esta etapa.\nEnvíalos aquí con ACEPTAR en modo CBN desde la pantalla «Generados».';

  @override
  String get cbnFlowEmptyStaging =>
      'Aún no hay recursos construidos.\nSelecciona en la pestaña «Entrantes» y toca CONSTRUIR.';

  @override
  String get cbnFlowEmptyPushed => 'No hay recursos publicados.';

  @override
  String get cbnFlowBadgeTagged => 'E';

  @override
  String get cbnFlowBadgeObjects => 'O';

  @override
  String cbnFlowBadgeBuilt(Object regions, Object colors) {
    return '${regions}r ${colors}c';
  }

  @override
  String get cbnFlowLayerNumbered => 'Numerada';

  @override
  String get cbnFlowLayerFinished => 'Terminada';

  @override
  String get cbnFlowLayerSource => 'Origen';

  @override
  String get cbnFlowLayerObjects => 'Objetos';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions regiones · $colors colores · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   etiquetas: $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) Buscar objetos';

  @override
  String get cbnFlowSamMasks => 'B) Máscaras SAM';

  @override
  String get cbnFlowLineartPage => 'C) Página de líneas (opcional, Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) Construir';

  @override
  String get cbnFlowStepMissingA =>
      'El paso A (lista de objetos) no se ha ejecutado';

  @override
  String get cbnFlowStepMissingB =>
      'El paso B (máscaras SAM) no se ha ejecutado';

  @override
  String get cbnFlowStepMissingC =>
      'El paso C (página de líneas) no se ha ejecutado';

  @override
  String get cbnFlowImageFailed => 'No se pudo cargar la imagen';

  @override
  String get jigsawFlowTitle => 'Línea Jigsaw';

  @override
  String get jigsawFlowTabTagged => '2 Etiquetados';

  @override
  String get jigsawFlowTabToPush => '3 Por publicar';

  @override
  String get jigsawFlowQueueAll => 'ENCOLAR TODO';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'ENCOLAR TODO - $count recursos';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return 'Generar vídeo - $count recursos';
  }

  @override
  String get jigsawFlowPositive1 => 'Positivo 1 - sujeto';

  @override
  String get jigsawFlowPositive1Help =>
      'vacío = el prompt propio de cada recurso';

  @override
  String get jigsawFlowMotionPreset => 'Plantilla de movimiento';

  @override
  String get jigsawFlowSpreadInTurn => '(repartir por turno)';

  @override
  String get jigsawFlowPositive2 => 'Positivo 2 - movimiento';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = lugar del prompt del sujeto. Vacío = las plantillas por turno.';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return 'Las $count plantillas se repartirán por turno.';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => 'No hay recursos sin vídeo';

  @override
  String get jigsawFlowSelectWithoutVideo => 'Selecciona recursos sin vídeo';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued vídeos añadidos a la cola - llegarán aquí al terminar';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued vídeos añadidos a la cola, $skipped omitidos - llegarán aquí al terminar';
  }

  @override
  String get jigsawFlowNoVideoTitle => 'Sin vídeo';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count recursos no tienen vídeo - solo se escribirá el jpg. ¿Continuar?';
  }

  @override
  String get jigsawFlowMusicNotReady => 'El modelo de música no está listo';

  @override
  String get jigsawFlowNoMusicMissing =>
      'A ninguna colección temática le falta música';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection ya tiene música o es Generic';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return 'Se generará una pista instrumental de 30 segundos para $count colecciones (ACE-Step, local).\n\n$names\n\nCada una puede tardar unos minutos.';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count recursos se SUBIRÁN al bucket R2.\n\nEs una publicación que no se puede deshacer - los archivos subidos serán visibles en la app.';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return '¿Eliminar definitivamente $count recursos (jpg + mp4 + webp + json)?';
  }

  @override
  String get jigsawFlowWebpStarted => 'Generando los webp que faltan';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return 'Colección de $mode';
  }

  @override
  String get jigsawFlowCollectionHelp =>
      'elige de la lista o escribe un nombre NUEVO';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return 'elige de la lista o escribe un nombre NUEVO  -  $count colecciones llenas están ocultas';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total recursos - siguiente $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'No hay recursos en esta etapa.\nEnvíalos aquí con ACEPTAR desde la pantalla «Generados».';

  @override
  String get jigsawFlowEmpty => 'No hay recursos en esta etapa.';

  @override
  String get jigsawFlowBadgeNoWebp => 'sin webp';

  @override
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp) {
    return '$label\nvídeo: $video   webp: $webp';
  }

  @override
  String jigsawFlowPreviewTags(Object state) {
    return 'etiquetas: $state';
  }

  @override
  String get jigsawFlowNoVideoInSelection =>
      'Ninguno de los recursos seleccionados tiene vídeo';

  @override
  String get jigsawFlowDeleteVideo => 'Eliminar vídeo';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return 'Se eliminarán el mp4 + webp de $count recursos; la imagen se conserva y puedes generar otro vídeo.';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip =>
      'Eliminar vídeo (la imagen se conserva)';

  @override
  String get jigsawFlowExtractNeedsOne =>
      'El atuendo se extrae de una sola imagen - selecciona una';

  @override
  String outfitExtractStarted(Object name) {
    return '$name se está extrayendo al armario - Personaje > Armario';
  }

  @override
  String get jigsawFlowMetaFile => 'Archivo';

  @override
  String get jigsawFlowMetaTags => 'Etiquetas';

  @override
  String get jigsawFlowMetaSubject => 'Sujeto';

  @override
  String get jigsawFlowMetaPolicy => 'Política';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   webp: $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'Etiquetas / metadatos';

  @override
  String get jigsawFlowMissingWebp => 'Webp que faltan';

  @override
  String deliverySavedLive(Object time) {
    return 'Guardado y EN VIVO ($time) - actualizando los recuentos';
  }

  @override
  String get deliveryReindexTitle => 'Volver a leer los metadatos';

  @override
  String get deliveryReindexBody =>
      'Para imágenes cuyo EXIF cambió en el bucket. Escribe los nombres de archivo separados por comas (p. ej. 12.jpg, 340.jpg); déjalo vacío para volver a leer TODO Generic (~1500 archivos, unos minutos).';

  @override
  String get deliveryReindexNames => 'Nombres de archivo';

  @override
  String get deliveryReindexAction => 'Leer';

  @override
  String deliveryReindexed(Object count) {
    return '$count imágenes leídas de nuevo - manifiestos actualizados';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count imágenes leídas de nuevo, $missing no encontradas - manifiestos actualizados';
  }

  @override
  String get deliveryDryRunStarted =>
      'Simulacro iniciado - solo genera un informe';

  @override
  String get deliveryNormalizeStarted => 'Normalización iniciada';

  @override
  String get deliveryCancelRequested => 'Cancelación solicitada';

  @override
  String get deliveryNeverSaved => 'nunca guardado';

  @override
  String get deliveryPoolJigsaw => 'Grupo Jigsaw';

  @override
  String get deliveryPoolCards => 'Cartas';

  @override
  String get deliveryPoolEvents => 'Eventos';

  @override
  String get deliveryEvent => 'Evento';

  @override
  String deliverySummaryLine(
    Object pool,
    Object total,
    Object tagged,
    Object untagged,
  ) {
    return 'Grupo $pool: $total imágenes, $tagged etiquetadas, $untagged sin etiquetar';
  }

  @override
  String get deliverySaveBeforeSwitch =>
      'Guarda los cambios antes de cambiar de grupo.';

  @override
  String get deliveryReindexTooltip =>
      'Volver a leer los metadatos (si cambió el EXIF)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return 'Última regla: $time  ·  servidas por defecto: $served / $total';
  }

  @override
  String get deliveryIntro =>
      'Interruptor APAGADO = las imágenes con ese valor salen del manifiesto. Guardar se publica al instante y ahora filtra TODAS las colecciones / mazos; un elemento suelto que se les escape a las reglas se cierra con la lista de bloqueo.';

  @override
  String get deliveryNormalizeTitle =>
      'Normalizar - generar las etiquetas que faltan';

  @override
  String get deliveryDryRun => 'Simulacro';

  @override
  String get deliveryNormalizeNoStatus =>
      'Estado no disponible - el servidor no respondió a /api/normalize/status';

  @override
  String deliveryIndex(Object index) {
    return 'Índice: $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return 'Última ejecución: $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => 'todas las apps (global)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'Bloquear · $scope';
  }

  @override
  String get deliveryOpenList => 'Abrir la lista';

  @override
  String get deliveryBlockIntro =>
      'Un bloqueo global vale en TODAS las apps; selecciona una app para bloquear solo en ella. Se aplica DESPUÉS de las reglas.';

  @override
  String get deliveryBlockEmpty =>
      'No hay nada que bloquear en este grupo (el bucket está vacío).';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count elementos · $tagged/$count etiquetados';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count elementos · $tagged/$count etiquetados · TODO BLOQUEADO';
  }

  @override
  String get deliveryAppsHint => 'Apps - toca para editar la regla de esa app';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return 'Por defecto  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      'Regla por defecto - versiones antiguas que no envían ?app= y apps sin regla propia';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return 'Regla propia para $app';
  }

  @override
  String get deliveryCustomRuleOn =>
      'Apágalo para volver a la regla por defecto';

  @override
  String get deliveryCustomRuleOff =>
      'Apagado: se aplica la regla por defecto. Al encenderlo empieza con una copia de ella.';

  @override
  String get deliveryScopeTitle => 'Solo las colecciones seleccionadas';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total colecciones - las recién publicadas NO llegan a esta app';
  }

  @override
  String get deliveryScopeOff =>
      'Apagado: cada colección recién publicada también llega a esta app';

  @override
  String get deliveryScopeNone =>
      'Ninguna seleccionada - una lista vacía no se guarda, la regla vuelve a «todas».';

  @override
  String get deliveryRulesEnabled => 'Reglas activas';

  @override
  String get deliveryRulesEnabledHint =>
      'Apagado = este conjunto de reglas no filtra nada';

  @override
  String get deliveryServeUntagged => 'Servir imágenes sin etiquetar';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count imágenes no tienen metadatos';
  }

  @override
  String get deliveryQuick => 'Rápido:';

  @override
  String deliveryOffCount(Object count) {
    return '$count apagados';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count valores';
  }

  @override
  String get deliveryUnsaved => 'Hay cambios sin guardar';

  @override
  String get deliveryInSync => 'Igual que el servidor';

  @override
  String get deliverySavePublish => 'Guardar y publicar';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonModel => 'Modelo';

  @override
  String get cardTplShuffled => 'Mezclado - los ejes bloqueados no se tocaron';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank mezclado';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - a todos';
  }

  @override
  String get cardTplAxisAllBack =>
      'Se escribe en el reverso de la carta y se BLOQUEA.';

  @override
  String get cardTplAxisAllFront =>
      'Se escribe en las 13 cartas + 2 comodines a la vez y se BLOQUEA - mezclar no lo cambia.';

  @override
  String get cardTplValue => 'Valor';

  @override
  String get cardTplAllWritten => 'Escrito en todos y bloqueado';

  @override
  String cardTplRankTitle(Object rank) {
    return 'Plantilla de $rank';
  }

  @override
  String get cardTplLocked => 'Bloqueado';

  @override
  String get cardTplLock => 'Bloquear';

  @override
  String get cardTplManual => 'Añadido manual (texto libre)';

  @override
  String get cardTplManualHint => 'p. ej. holding a golden card fan';

  @override
  String get cardTplManualHelp =>
      'Se añade al final de la plantilla - mezclar no lo borra';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank guardado';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot añadido a la cola';
  }

  @override
  String cardTplTitle(Object title) {
    return 'Carta de colección - $title';
  }

  @override
  String get cardTplShuffle => 'Mezclar';

  @override
  String get cardTplNoTheme => 'Sin tema - toca y escribe uno';

  @override
  String get cardTplThemeTitle => 'Tema (P1)';

  @override
  String get cardTplPresetCard => 'Carta predefinida';

  @override
  String get cardTplTheme => 'Tema';

  @override
  String get cardTplThemeHelp =>
      'identidad + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'El tema no puede estar vacío';

  @override
  String get cardTplThemeSaved => 'Tema guardado';

  @override
  String cardTplModelSet(Object name) {
    return 'Modelo: $name';
  }

  @override
  String get cardTplFaceDetail => 'Retoque facial';

  @override
  String get cardTplFaceDetailHint =>
      '+15 s por carta - pasa el rostro por una pasada aparte';

  @override
  String get cardTplFaceDetailOn => 'Retoque facial activado';

  @override
  String get cardTplFaceDetailOff => 'Retoque facial desactivado';

  @override
  String get cardTplVideoEngine => 'Motor de vídeo (primer fotograma = último)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (no instalado)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return 'Motor de vídeo: $name';
  }

  @override
  String get cardTplApplyToAll => 'Aplicar a todos:';

  @override
  String get cardTplPickAxis => 'elige un eje';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (reverso)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count ejes bloqueados';
  }

  @override
  String get cardTplShuffleSlot => 'Mezclar esta ranura';

  @override
  String get cardTplGenerateSlot => 'Generar esta ranura';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return '¿Eliminar $count generaciones y sus archivos?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count generaciones eliminadas';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count no se pudieron eliminar';
  }

  @override
  String get galleryCharacterNeedsOne =>
      'Un personaje se crea a partir de una sola imagen - selecciona una';

  @override
  String get galleryMakeCharacter => 'Crear personaje';

  @override
  String get galleryMakeCharacterBody =>
      'La imagen seleccionada pasa a ser la base directamente; el retrato, la historia y las 7 direcciones se generan solos - sin pedir confirmación.';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name añadido a la cola - sigue el proceso en la pestaña Cola';
  }

  @override
  String get galleryCreateCharacterFirst =>
      'Primero crea un personaje con «Crear personaje»';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return 'Añadir a candidatos - $count imágenes';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$count imágenes añadidas a los candidatos de $name';
  }

  @override
  String get galleryCollectionNeedsOne =>
      'A una colección se añade una sola imagen - selecciona una';

  @override
  String get galleryCreateCollectionFirst =>
      'Primero crea una colección o un crupier en la línea de Cartas';

  @override
  String get galleryAddToCollection => 'Añadir a la colección';

  @override
  String get galleryDealerNoRank => 'crupier (sin rango)';

  @override
  String galleryPickRank(Object name) {
    return '$name - elige un rango';
  }

  @override
  String get galleryQueuedOne =>
      'Añadido a la cola (1 trabajo) - síguelo en la pestaña Cola';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count imágenes pasarán a la etapa «Entrantes» de la línea CBN: jpg + etiquetas EXIF. La construcción (SAM, líneas, regiones) se inicia allí.\n\n¿Qué clasificación?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count imágenes pasarán a la etapa 2: jpg + etiquetas EXIF, junto con su vídeo si lo hay.\n\n¿Qué clasificación?';
  }

  @override
  String get galleryAcceptStarted =>
      'Iniciado - sigue el progreso en la pestaña «Línea»';

  @override
  String get galleryExtractTooltip =>
      'Extraer atuendo - lleva el atuendo de la imagen al armario';

  @override
  String get galleryMakeCharacterTooltip =>
      'Crear personaje - crea un personaje nuevo';

  @override
  String get galleryAddToCandidatesTooltip =>
      'Añadir a candidatos - copia a un personaje existente';

  @override
  String get galleryAddToCollectionTooltip =>
      'Añadir a la colección - elige un rango';

  @override
  String get galleryAcceptTooltip => 'Aceptar - enviar a la etapa 2';

  @override
  String get galleryDeleteSelected => 'Eliminar los seleccionados';

  @override
  String get galleryFilterImage => 'Imagen';

  @override
  String get galleryFilterVideo => 'Vídeo';

  @override
  String get galleryFilterFavorite => 'Favorito';

  @override
  String galleryQueuedAt(Object position) {
    return 'en cola $position';
  }

  @override
  String get galleryEmpty => 'Aún no se ha generado nada';

  @override
  String get galleryEmptyHint => 'Puedes empezar desde la pestaña Generar';

  @override
  String get galleryDeleteOneConfirm =>
      '¿Eliminar esta generación y su archivo?';

  @override
  String get galleryAcceptOneCbn =>
      'Pasará a la etapa «Entrantes» de la línea CBN (jpg + etiquetas EXIF).\n\n¿Qué clasificación?';

  @override
  String get galleryAcceptOneJigsaw =>
      'Pasará a la etapa 2 (jpg + etiquetas EXIF).\n\n¿Qué clasificación?';

  @override
  String get galleryAccepted =>
      'Aceptado - se está etiquetando, síguelo en la pestaña «Línea»';

  @override
  String get galleryRejected => 'Rechazado';

  @override
  String get galleryEditBody =>
      'Esta imagen pasa a ser el origen; el motor de edición (Qwen Image Edit, conserva la identidad) inicia una nueva generación. ¿Qué debe cambiar?';

  @override
  String get galleryEditPromptLabel => 'Prompt adicional';

  @override
  String get galleryEditPromptHint =>
      'p. ej. change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued =>
      'Edición añadida a la cola - el resultado aparecerá en Generados';

  @override
  String get galleryEditTooltip =>
      'Editar - nueva generación con el motor de edición';

  @override
  String galleryPoolInfo(Object name) {
    return 'grupo $name';
  }

  @override
  String get genPromptUnchanged =>
      'El prompt no cambió (el LLM local no respondió)';

  @override
  String get genPromptWritten => 'Prompt escrito';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get genVariantFailed =>
      'No se pudo generar ninguna variante (el LLM local no respondió)';

  @override
  String get genPickVariant => 'Elige una variante';

  @override
  String get genEnrich => 'Enriquecer';

  @override
  String get genFix => 'Corregir';

  @override
  String get genVariant => 'Variante';

  @override
  String get genFileUnreadable => 'No se pudo leer el archivo';

  @override
  String get genPromptEmpty => 'El prompt no puede estar vacío';

  @override
  String genMissingInputs(Object inputs) {
    return 'Falta la entrada: $inputs';
  }

  @override
  String get genNeedsImagePick =>
      'Esta tarea necesita una imagen de entrada - elige una de las generadas';

  @override
  String get genNeedsImage => 'Esta tarea necesita una imagen de entrada';

  @override
  String genQueuedCount(Object count) {
    return '$count trabajos añadidos a la cola';
  }

  @override
  String get genQueued => 'Añadido a la cola';

  @override
  String genQueueBadge(Object count) {
    return '$count en cola';
  }

  @override
  String get genComfyOffBody =>
      'ComfyUI está apagado. Los trabajos entran en la cola pero no empiezan - hay que iniciarlo en el ordenador.';

  @override
  String get genTask => 'Tarea';

  @override
  String get genWorkflowInputs => 'Entradas del flujo de trabajo';

  @override
  String get genInputImage => 'Imagen de entrada';

  @override
  String get genPositive1 => 'Prompt positivo 1 - sujeto';

  @override
  String get genPositive1Hint => 'p. ej. police officer';

  @override
  String get genPositive2 => 'Prompt positivo 2 - plantilla';

  @override
  String genPositive2Help(Object marker) {
    return '$marker se sustituye por el primer prompt. Puede dejarse vacío.';
  }

  @override
  String get genFinalPrompt => 'Prompt que se enviará';

  @override
  String get genNegative => 'Prompt negativo';

  @override
  String get genTurboHint => 'modo rápido';

  @override
  String genDurationSeconds(Object seconds) {
    return 'Duración: $seconds segundos';
  }

  @override
  String genCount(Object count) {
    return 'Cantidad: $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'Tamaño: $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'Tamaño: $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'AÑADIR A LA COLA';

  @override
  String get genFootnote =>
      'Los trabajos se generan uno tras otro. Puedes seguirlos en la pestaña Cola.';

  @override
  String get genDetailsTitle =>
      'Detalles - pueden dejarse vacíos, los bloqueados no se mezclan';

  @override
  String genRandomGenerate(Object count) {
    return 'Generar al azar  $count';
  }

  @override
  String get genLockedTooltip => 'bloqueado - no cambia al mezclar';

  @override
  String get genOptionsEmpty => 'La lista de opciones está vacía';

  @override
  String get genOptional => 'opcional';

  @override
  String get genUploading => 'subiendo...';

  @override
  String get genNotSelected => 'sin seleccionar';

  @override
  String get genFromGallery => 'De la galería';

  @override
  String get genFromFile => 'De archivo';

  @override
  String get genNoSource =>
      'No hay ninguna generación que sirva de entrada. Genera primero una imagen.';

  @override
  String genPickerTitle(Object slot) {
    return '$slot - elige de Generados';
  }

  @override
  String get genPickerSearch => 'buscar en los prompts';

  @override
  String get genPickerEmpty => 'No hay generaciones terminadas de este tipo.';

  @override
  String optionsFileMissing(Object items) {
    return 'Falta en el archivo de opciones: $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (sin definiciones de campo)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'No se pudo leer el archivo de opciones: $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return 'No se pudo leer el archivo de opciones de $name: $error';
  }

  @override
  String get fieldLocation => 'Lugar';

  @override
  String get fieldEra => 'Época / estética';

  @override
  String get fieldWeather => 'Clima';

  @override
  String get fieldWeatherLight => 'Clima / luz';

  @override
  String get fieldJob => 'Profesión';

  @override
  String get fieldFantasy => 'Fantasía';

  @override
  String get fieldOutfitColor => 'Color del atuendo';

  @override
  String get fieldOutfit => 'Atuendo';

  @override
  String get fieldHair => 'Pelo';

  @override
  String get fieldHairColor => 'Color de pelo';

  @override
  String get fieldHairstyle => 'Peinado';

  @override
  String get fieldEyes => 'Ojos';

  @override
  String get fieldRace => 'Raza';

  @override
  String get fieldExpression => 'Expresión';

  @override
  String get fieldPose => 'Pose';

  @override
  String get fieldAngle => 'Ángulo';

  @override
  String get fieldStyle => 'Estilo';

  @override
  String get fieldMood => 'Ambiente';

  @override
  String get fieldColor => 'Color';

  @override
  String get fieldCreature => 'Criatura';

  @override
  String get fieldClass => 'Clase';

  @override
  String get fieldAge => 'Edad';

  @override
  String get fieldOrigin => 'Origen';

  @override
  String get fieldBody => 'Cuerpo';

  @override
  String get fieldSkin => 'Piel';

  @override
  String get fieldFace => 'Rostro';

  @override
  String get fieldGesture => 'Gesto';

  @override
  String get cardNotReady => 'El endpoint del servidor aún no está listo';

  @override
  String get cardKindNormal => 'Normal';

  @override
  String get cardKindDealer => 'Crupier';

  @override
  String get cardStagePushed => 'publicado';

  @override
  String get cardStageWebp => 'webp listo';

  @override
  String get cardStageVideo => 'vídeo listo';

  @override
  String get cardStageStill => 'still listo';

  @override
  String get cardStageEmpty => 'vacío';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (revisar)';
  }

  @override
  String get cardVideoIntro =>
      'Primer fotograma = último (bucle). La cámara queda fija - el encuadre, la escala y el fondo no cambian. El resultado va primero al GRUPO; si eliges una etiqueta, también se asigna a ella.';

  @override
  String get cardVideoTemplate => 'Plantilla (rellena el texto)';

  @override
  String get cardVideoMotion => 'Frase de movimiento (el prompt que se envía)';

  @override
  String get cardVideoMotionHelp =>
      'Describe un movimiento visible; al final debe volver a la pose inicial';

  @override
  String get cardVideoAssignTag => 'Asignar a etiqueta';

  @override
  String get cardVideoPoolOnly => '(solo al grupo - lo asignaré después)';

  @override
  String get cardVideoNewTag => 'Nueva etiqueta...';

  @override
  String get cardVideoNewTagName => 'Nombre de la nueva etiqueta';

  @override
  String get cardTagHint => 'p. ej. victory';

  @override
  String get cardGestureTitle => 'Animación - elige un gesto';

  @override
  String get cardGestureIntro =>
      'MiniMax H3: idle 6 s, victory 2 s. La cámara queda fija - el encuadre, la escala y el fondo no cambian.';

  @override
  String get cardGestureCustom => 'Movimiento personalizado';

  @override
  String get cardGestureCustomHint =>
      'p. ej. leve balanceo de cadera, pies fijos';

  @override
  String get cardGestureCustomHelp =>
      'Una frase corta de movimiento - la cámara sigue fija';

  @override
  String get cardCutTitle => '3 WebP - modo de recorte';

  @override
  String get cardCutHybrid =>
      'Masters verdes antiguos de Grok - croma + SAM juntos';

  @override
  String get cardCutSam => 'Por defecto - solo SAM3, fondo gris claro liso';

  @override
  String get cardCutAction => 'Recortar';

  @override
  String cardEditTitle(Object name) {
    return 'Editar - $name';
  }

  @override
  String get cardEditSentence => 'Frase de corrección';

  @override
  String get cardEditSentenceHint =>
      'p. ej. acorta el pelo / quita los guantes';

  @override
  String get cardEditBody =>
      'El still aceptado se edita con esta frase; se conservan la identidad, la pose y el fondo. La nueva imagen se acepta automáticamente.';

  @override
  String get cardEditUnrestricted => 'Edición sin restricciones (NSFW LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Actívalo si Qwen se niega - MCNL LoRA, 20 pasos, algo más lento';

  @override
  String cardQueuedJobs(Object count) {
    return 'Añadido a la cola ($count trabajos) - síguelo en la pestaña Cola';
  }

  @override
  String get cardQueued => 'Añadido a la cola - síguelo en la pestaña Cola';

  @override
  String cardQueuedOp(Object op) {
    return 'Añadido a la cola (op $op) - síguelo en la pestaña Cola';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - próximamente';
  }

  @override
  String get cardSoonBody =>
      'Los endpoints de cartas del servidor aún no están abiertos. Esta pantalla empezará a funcionar sola cuando lo estén.';

  @override
  String get cardNewCollection => 'Nueva colección';

  @override
  String get cardIdLabel => 'Identificador (id)';

  @override
  String get cardIdHintCollection => 'p. ej. police_royale';

  @override
  String get commonName => 'Nombre';

  @override
  String get cardNameHintCollection => 'p. ej. Police Royale';

  @override
  String get cardPickPreset => 'Elige una carta predefinida (opcional)';

  @override
  String get cardThemeHint =>
      'p. ej. sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      'Fórmula: identidad + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'Comodines (2)';

  @override
  String get cardJokersHint => '15 rangos en lugar de 13';

  @override
  String get cardNewCollectionNote =>
      'Entra en la cola 1 still por rango (rotación de piel / pelo / atuendo / pose). No se pide confirmación - afina con ✎ / ↻.';

  @override
  String get cardIdNameRequired =>
      'El identificador y el nombre no pueden estar vacíos';

  @override
  String get cardNewDealer => 'Nuevo crupier';

  @override
  String get cardIdHintDealer => 'p. ej. scarlett';

  @override
  String get cardNameHintDealer => 'p. ej. Scarlett';

  @override
  String get cardDealerTheme => 'Tema / atuendo';

  @override
  String get cardDealerThemeHint =>
      'p. ej. chaleco de casino y pajarita, vestido rojo noir';

  @override
  String get cardDealerNote =>
      'El crupier se genera en plano medio (manos sobre la mesa, mirando a cámara). No hay rango - el único elemento pasa por las cuatro etapas.';

  @override
  String get cardNightPickGesture => 'Modo nocturno - elige un gesto';

  @override
  String get cardNightMode => 'Modo nocturno';

  @override
  String cardNightBody(Object gesture) {
    return 'Se reaniman todas las cartas Y los crupieres: still actual -> LTX-2.5 i2v ($gesture) -> recorte SAM -> sheet.\n\nTarda mucho y todo entra en la cola. NO se hace push.';
  }

  @override
  String get cardRestillTitle => 'Poner los fondos en gris';

  @override
  String get cardRestillBody =>
      'El fondo del still de todas las cartas Y crupieres pasa a gris claro liso (la mujer queda igual). El original se guarda como still_green.png; los que ya son grises se omiten.\n\nNo se genera vídeo.';

  @override
  String get cardManifestPreview => 'Vista previa del manifiesto';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return '$collections colecciones, $dealers crupieres';
  }

  @override
  String get cardManifestNote =>
      'El archivo de manifiesto se escribe durante el PUSH (primero los archivos, después el manifiesto). Esto es solo una vista previa.';

  @override
  String get cardCollectionCardSettings => 'Carta de colección (ajustes)';

  @override
  String get cardCollectionCardSettingsHint =>
      'tema, 16 ranuras, modelo, retoque facial';

  @override
  String get cardReanimate => 'Reanimar';

  @override
  String get cardReanimateHint => 'still -> i2v -> recorte (esta colección)';

  @override
  String get cardRealify => 'Anime -> realista (colección)';

  @override
  String get cardRealifyHint => 'cada still pasa a foto realista con edit_qwen';

  @override
  String get cardDeleteCollection => 'Eliminar colección';

  @override
  String get cardDeleteCollectionHint =>
      'la carpeta se elimina con todas sus cartas - no se puede deshacer';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'Eliminar colección - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'Eliminar crupier - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'La carpeta de la colección se elimina con todos sus archivos.\n\nNO SE PUEDE DESHACER. Los archivos ya publicados en R2 se quedan en el bucket.';

  @override
  String get cardDeleteDealerBody =>
      'La carpeta del crupier se elimina con todos sus archivos.\n\nNO SE PUEDE DESHACER. Los archivos ya publicados en R2 se quedan en el bucket.';

  @override
  String cardDeletedNamed(Object name) {
    return '$name eliminado';
  }

  @override
  String get cardDealerCardSettings => 'Carta de crupier (ajustes)';

  @override
  String get cardDealerCardSettingsHint =>
      'tema, plantilla, modelo, retoque facial';

  @override
  String get cardDeleteDealer => 'Eliminar crupier';

  @override
  String get cardDeleteDealerHint =>
      'la carpeta se elimina con todos sus archivos - no se puede deshacer';

  @override
  String get cardFlowTitle => 'Línea de Cartas';

  @override
  String get cardBulkActions => 'Acciones en lote';

  @override
  String get cardNightMenu => 'Modo nocturno: reanimar todo';

  @override
  String get cardRestillMenu => 'Poner los fondos en gris (todos)';

  @override
  String get cardManifestMenu => 'Ver manifiesto';

  @override
  String get cardDealers => 'Crupieres';

  @override
  String get cardEmptyCollections =>
      'Aún no hay colecciones.\n\nCon «+ Nueva colección» indica identificador, nombre y tema - entra en la cola 1 still por rango para 13 (o 15) rangos, y después vienen las etapas 2 Video y 3 WebP.';

  @override
  String get cardEmptyDealers =>
      'Aún no hay crupieres.\n\nCon «+ Nuevo crupier» indica nombre, tema y gesto - se genera un único elemento en plano medio que pasa por las cuatro etapas.';

  @override
  String cardGestureLine(Object gesture) {
    return 'gesto: $gesture';
  }

  @override
  String cardAnimateTitle(Object count) {
    return '2 Video ($count cartas)';
  }

  @override
  String cardAnimateBody(Object total) {
    return 'Para cada carta se generan 2 animaciones y se asignan a sus etiquetas:\n• idle - 6 s, un gesto controlado\n• victory - 2 s, una breve celebración dentro del encuadre\n$total vídeos en total; los antiguos se quedan en el grupo.';
  }

  @override
  String get cardEditNeedsOne =>
      'La edición es para un solo rango - selecciona una carta';

  @override
  String cardPushTitle(Object name) {
    return 'Push - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'Los archivos sheet y thumb se suben a R2 (cards) y después se escribe el manifiesto. Ahora mismo está listo el webp de $ready/$total rangos.\n\nEs una PUBLICACIÓN y NO SE PUEDE DESHACER.';
  }

  @override
  String get cardPushQueued =>
      'Push añadido a la cola - síguelo en la pestaña Cola';

  @override
  String get cardCollectionCardTooltip =>
      'Carta de colección - tema, 16 ranuras, modelo, retoque facial';

  @override
  String get commonMore => 'Más';

  @override
  String get cardNoThemeTap => 'Sin tema - toca: Carta de colección';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nCarta de colección: toca (tema, 16 ranuras, modelo, retoque facial)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'La carpeta de la colección se elimina con todas sus cartas ($stills stills).\n\nNO SE PUEDE DESHACER. Los archivos ya publicados en R2 se quedan en el bucket.';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'La carpeta de la colección se elimina con todas sus cartas ($stills stills, $pushed publicadas).\n\nNO SE PUEDE DESHACER. Los archivos ya publicados en R2 se quedan en el bucket.';
  }

  @override
  String get cardClearCards => 'Vaciar cartas';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - se eliminan still, candidatos, vídeo y webp; el rango queda vacío (se vuelve a generar con «1 Still»).';
  }

  @override
  String cardsCleared(Object count) {
    return '$count cartas vaciadas';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count cartas no se pudieron vaciar';
  }

  @override
  String get cardGenerateStill => 'Generar 1 Still';

  @override
  String get cardGenerateVideo => 'Generar 2 Video';

  @override
  String get cardGenerateWebp => 'Generar 3 WebP';

  @override
  String get cardBackUpper => 'REVERSO';

  @override
  String cardAssetVideo(Object tag) {
    return 'Vídeo ($tag)';
  }

  @override
  String cardAssetSheet(Object tag) {
    return 'WebP / recorte ($tag)';
  }

  @override
  String cardAssetMissing(Object asset) {
    return 'No hay $asset';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return '¿Eliminar $asset?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'Solo se elimina el vídeo de esta etiqueta; la copia del grupo, el still y el webp se conservan.';

  @override
  String get cardAssetDeleteSheetBody =>
      'Solo se eliminan sheet.webp, el thumb y los fotogramas recortados; el vídeo y el still se conservan.';

  @override
  String get cardAssetDeleteStillBody =>
      'Solo se elimina el still seleccionado; los candidatos, el vídeo y el webp se conservan.';

  @override
  String get cardPoolDelete => 'Eliminar del grupo';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id se elimina del grupo. Las copias asignadas a etiquetas ($tags) se conservan.';
  }

  @override
  String get cardNone => 'ninguna';

  @override
  String get cardNewAnimTag => 'Nueva etiqueta de animación';

  @override
  String get cardNewAnimTagHelp =>
      'El juego la lee con este nombre (idle, wink, victory ...)';

  @override
  String get cardUnassigned => 'sin asignar';

  @override
  String cardAssignedTo(Object tags) {
    return 'asignado: $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return 'Asignar: $name';
  }

  @override
  String get cardAssignNewTag => 'Asignar a una etiqueta nueva...';

  @override
  String get cardAnimReady => 'vídeo + webp listos';

  @override
  String get cardAnimVideoOnly => 'hay vídeo, falta el webp';

  @override
  String get cardPoolEmpty => 'No hay vídeos en el grupo - primero «2 Video»';

  @override
  String get cardDeleteVideoKeepTag =>
      'Eliminar el vídeo (la etiqueta se conserva)';

  @override
  String get cardDeleteSheet => 'Eliminar WebP / recorte';

  @override
  String get cardDeleteTag => 'Eliminar la etiqueta (con su vídeo + webp)';

  @override
  String cardVideosHeader(Object count) {
    return 'Vídeos ($count) - toca = asignar / ver / eliminar';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return 'La carpeta de $name se elimina con todos sus archivos. NO SE PUEDE DESHACER.';
  }

  @override
  String get cardClearCard => 'Vaciar carta';

  @override
  String cardClearCardBody(Object name) {
    return '$name: se eliminan still, candidatos, vídeo, webp y animaciones; el rango queda vacío (se vuelve a generar con «1 Still»).';
  }

  @override
  String get cardClearCardTooltip => 'Vaciar carta (el rango queda vacío)';

  @override
  String get cardViewCut => 'Recorte';

  @override
  String cardDeleteThisVideo(Object tag) {
    return 'Eliminar este vídeo ($tag)';
  }

  @override
  String cardDeleteSheetTag(Object tag) {
    return 'Eliminar WebP / recorte ($tag)';
  }

  @override
  String get cardDeleteStill => 'Eliminar el still';

  @override
  String get cardNoVideo => 'No hay vídeo - genéralo con «2 Video»';

  @override
  String get cardNoCut => 'No hay recorte - genéralo con «3 WebP»';

  @override
  String get cardCutFrameFailed => 'No se pudo leer el fotograma recortado';

  @override
  String get cardNoStill => 'No hay still - genéralo con «1 Still»';

  @override
  String get cardStillFailed => 'No se pudo leer el still';

  @override
  String cardPromptTitleAge(Object age) {
    return 'Prompt  ·  $age años';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - encuadre desplazado / zoom / máscara rota. Vuelve a generar el vídeo o el recorte.';

  @override
  String get cardAnimsHeader =>
      'Animaciones - toca = seleccionar, mantén pulsado = asignar / eliminar';

  @override
  String cardAnimOpened(Object tag) {
    return '«$tag» creada - genérala con 2 Video o asígnala desde el grupo';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return 'Elige un vídeo del grupo para «$tag»';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return 'Candidatos ($count) - toca = seleccionar';
  }

  @override
  String get cardCandidatePicked =>
      'El candidato es ahora el still seleccionado';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step: $error';
  }
}

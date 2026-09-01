// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get about => 'Sobre';

  @override
  String get aboutApp => 'Aplicação';

  @override
  String actionTriggered(Object action) {
    return '$action acionado';
  }

  @override
  String get add => 'Adicionar';

  @override
  String agentLabelWith(Object agent) {
    return 'Agente: $agent';
  }

  @override
  String get agentLocal => 'Local';

  @override
  String get agentNone => 'Nenhum';

  @override
  String get agentRunsOnServer =>
      'O agente é executado no servidor com acesso ao nível do projeto';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return 'IA $agent acionada para \"$title\"';
  }

  @override
  String get aiAgent => 'Agente de IA';

  @override
  String get aiAgentUpdated => 'Agente de IA atualizado';

  @override
  String get aiResponse => 'Resposta da IA';

  @override
  String get allApps => 'Todas as Apps';

  @override
  String get allAppsCompletedOrPostponed =>
      'Todas as apps estão concluídas ou adiadas';

  @override
  String get allAppsHaveAutomations => 'Todas as apps já têm automações';

  @override
  String get allAppsHint => 'Todas as apps';

  @override
  String get allPendingBlocked =>
      'Todos os itens pendentes estão bloqueados por dependências';

  @override
  String get apiConnection => 'Ligação à API';

  @override
  String get apiUrlSaved => 'URL da API guardado';

  @override
  String get appCreated => 'App criada!';

  @override
  String get appDetail => 'Detalhe da App';

  @override
  String get appFallback => 'App';

  @override
  String get appNameHint => 'Nome da App (ex.: My Game)';

  @override
  String get appStatusBuilding => 'a compilar';

  @override
  String get appStatusDeploying => 'a implementar';

  @override
  String get appStatusError => 'erro';

  @override
  String get appStatusFixing => 'a corrigir';

  @override
  String get appStatusIdle => 'inativo';

  @override
  String get appStatusPublished => 'publicado';

  @override
  String get appStatusQueued => 'em fila';

  @override
  String get appStatusUploading => 'a carregar';

  @override
  String get appStatusWorking => 'a trabalhar';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc =>
      'App móvel/desktop com suporte de implementação no Google Play';

  @override
  String get appTypeGodotDesc =>
      'Projeto de jogo com destinos de exportação (Windows, Android, Web)';

  @override
  String get appTypePhaserDesc =>
      'Jogo Phaser 3 + TypeScript, empacotado como AAB Android via Capacitor';

  @override
  String get appTypePythonDesc =>
      'Projeto Python com executor de scripts e gestão de pip';

  @override
  String get appTypeWebDesc =>
      'App web com suporte de implementação em alojamento estático';

  @override
  String get apps => 'Apps';

  @override
  String get archivedLabel => 'arquivado';

  @override
  String get artAndAssets => 'Arte e Recursos';

  @override
  String get artBible => 'Art Bible';

  @override
  String get artBibleCardSubtitle => 'Documento âncora da identidade visual';

  @override
  String get artBibleHint =>
      'Declaração de identidade, paleta (hex), tipografia, proibições, especificações técnicas...';

  @override
  String get artBibleSaved => 'Art bible guardada';

  @override
  String get artBibleShort => 'Art bible';

  @override
  String get artBibleSubtitle =>
      'Âncora da identidade visual — paleta, tipografia, proibições de estilo. Todas as tarefas de recursos referenciam este documento.';

  @override
  String get artBibleTaskCreated => 'Tarefa de art bible criada';

  @override
  String artBibleTitle(Object app) {
    return 'Art Bible - $app';
  }

  @override
  String get askAQuestionHint => 'Faça uma pergunta...';

  @override
  String get askAgent => 'Perguntar ao Agente';

  @override
  String get askAnythingAboutYourApps =>
      'Pergunte o que quiser sobre as suas apps';

  @override
  String get assetAudit => 'Auditoria de Recursos';

  @override
  String get assetAuditSubtitle =>
      'Referências quebradas, órfãos, placeholders';

  @override
  String get assetAuditTaskCreated => 'Tarefa de auditoria de recursos criada';

  @override
  String get assetSpecTaskCreated =>
      'Tarefa de especificação de recursos criada';

  @override
  String get assetSpecs => 'Especificações de Recursos';

  @override
  String get assetSpecsSubtitle => 'Prompts por recurso a partir da bible';

  @override
  String get attachments => 'Anexos';

  @override
  String attachmentsCount(Object count) {
    return 'Anexos ($count)';
  }

  @override
  String get automationCreated => 'Automação criada';

  @override
  String get automationStateStarted => 'iniciada';

  @override
  String get automationStateStopped => 'parada';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => 'Automação atualizada';

  @override
  String get back => 'Voltar';

  @override
  String get backend => 'Backend';

  @override
  String get balanceCheck => 'Verificação de Equilíbrio';

  @override
  String get balanceCheckSubtitle => 'Economia, progressão, recompensas';

  @override
  String get balanceCheckTaskCreated =>
      'Tarefa de verificação de equilíbrio criada';

  @override
  String batchRunError(Object error) {
    return 'Erro durante a execução em lote: $error';
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
    return '$count bloqueado(s)';
  }

  @override
  String blockerNotInList(Object id) {
    return 'A tarefa #$id não está na lista atual (arquivada ou eliminada)';
  }

  @override
  String get brainstormAndCreate => 'Brainstorm e Criar';

  @override
  String get brainstormConceptHint =>
      'Ideia inicial (ex.: \"jogo idle de colónia de formigas\", \"puzzle com gravidade\")';

  @override
  String get brainstormCreated => 'Projeto criado com tarefa de brainstorm!';

  @override
  String get brainstormDesc =>
      'Cria um novo projeto com uma tarefa de brainstorm. Quando a tarefa é executada, a IA gera um GDD completo e as tarefas iniciais.';

  @override
  String get brainstormNameHint =>
      'Nome do projeto (opcional — a IA pode sugerir)';

  @override
  String get brainstormNewGame => 'Brainstorm de Novo Jogo';

  @override
  String get build => 'Compilar';

  @override
  String get buildAndDeploy => 'Compilar e Implementar';

  @override
  String get buildCancelled => 'Compilação cancelada';

  @override
  String get buildFailedLabel => 'compilação falhada';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'A verificação da compilação expirou após 30 minutos - verifique os registos do servidor';

  @override
  String get buildTarget => 'Destino de Compilação';

  @override
  String get builds => 'Compilações';

  @override
  String builtCount(Object count) {
    return 'Compilado(s) ($count)';
  }

  @override
  String get buyMeACoffee => 'Ofereça-me um café';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'Ofereça-me um café  $price';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get cannotReachServer => 'Não é possível alcançar o servidor';

  @override
  String cannotReachServerWith(Object error) {
    return 'Não é possível alcançar o servidor: $error';
  }

  @override
  String get cannotSaveEmptyArtBible =>
      'Não é possível guardar uma art bible vazia';

  @override
  String get cannotSaveEmptyClaudeMd =>
      'Não é possível guardar um CLAUDE.md vazio';

  @override
  String get cannotSaveEmptyDesignDoc =>
      'Não é possível guardar um documento de design vazio';

  @override
  String get catBugsCrashes => 'Bugs e Falhas';

  @override
  String get catCodeStyle => 'Estilo de Código';

  @override
  String get catDeadCode => 'Código Morto';

  @override
  String get catErrorHandling => 'Tratamento de Erros';

  @override
  String get catMemory => 'Memória';

  @override
  String get categoryAccessibility => 'Acessibilidade';

  @override
  String get categoryBug => 'Bug';

  @override
  String get categoryFeatures => 'Funcionalidades';

  @override
  String get categoryMonetization => 'Monetização';

  @override
  String get categoryOther => 'Outro';

  @override
  String get categoryPerformance => 'Desempenho';

  @override
  String get categorySecurity => 'Segurança';

  @override
  String get categorySuggestion => 'Sugestão';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count caracteres';
  }

  @override
  String get chatHistory => 'Histórico de Conversas';

  @override
  String get chatLogs => 'Relatórios';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count mensagens • $date';
  }

  @override
  String get checkBugsCrashes => 'Bugs e falhas';

  @override
  String get checkCodeStyle => 'Estilo de código';

  @override
  String get checkDeadCode => 'Código morto';

  @override
  String get checkErrorHandling => 'Tratamento de erros';

  @override
  String get checkMemoryLeaks => 'Fugas de memória';

  @override
  String get checkPerformanceIssues => 'Problemas de desempenho';

  @override
  String get checkSecurityVulnerabilities => 'Vulnerabilidades de segurança';

  @override
  String get checksToRun => 'Verificações a executar:';

  @override
  String get claudeMdHint =>
      'Convenções do projeto, comandos de compilação, regras...';

  @override
  String get claudeMdSaved => 'CLAUDE.md guardado';

  @override
  String get claudeMdSubtitle =>
      'Instruções do projeto para os agentes de IA que trabalham nesta app.';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'Limpar';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get clearMessages => 'Limpar Mensagens';

  @override
  String clearMessagesConfirm(Object count) {
    return 'Eliminar todas as $count mensagens nesta conversa?';
  }

  @override
  String get close => 'Fechar';

  @override
  String get codeCheck => 'Verificação de Código';

  @override
  String get codeCheckBody =>
      'Isto cria uma tarefa para o agente de IA rever o seu código e reportar os resultados como problemas.';

  @override
  String get codeCheckRequested => 'Verificação de código solicitada';

  @override
  String get codeCheckResults => 'Resultados da Verificação de Código';

  @override
  String get codeReview => 'Revisão de Código';

  @override
  String get codeReviewSubtitle => 'Bugs, falhas, qualidade de código';

  @override
  String get complete => 'Concluir';

  @override
  String completedCount(Object count) {
    return 'Concluído(s) ($count)';
  }

  @override
  String get connectToYourServer => 'Ligar ao Seu Servidor';

  @override
  String get connectYourPhone => 'Ligue o seu telemóvel';

  @override
  String get connectedSuccessfully => 'Ligado com sucesso';

  @override
  String connectedTo(Object server) {
    return 'Ligado a $server';
  }

  @override
  String get connecting => 'A ligar...';

  @override
  String get connectionFailed => 'Falha na ligação';

  @override
  String get connectionSuccessful => 'Ligação bem-sucedida!';

  @override
  String get connectionTimedOut => 'A ligação expirou';

  @override
  String get consistencyCheck => 'Verificação de Consistência';

  @override
  String get consistencyCheckSubtitle => 'Divergência GDD ↔ código ↔ dados';

  @override
  String get consistencyCheckTaskCreated =>
      'Tarefa de verificação de consistência criada';

  @override
  String get console => 'Consola';

  @override
  String get contentAudit => 'Auditoria de Conteúdo';

  @override
  String get contentAuditSubtitle => 'Níveis, personagens, itens, texto';

  @override
  String get contentAuditTaskCreated =>
      'Tarefa de auditoria de conteúdo criada';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get control => 'Controlo';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label copiado para a área de transferência';
  }

  @override
  String get copy => 'Copiar';

  @override
  String get copyAiResponse => 'Copiar Resposta da IA';

  @override
  String get copyDescription => 'Copiar Descrição';

  @override
  String get copyTitle => 'Copiar Título';

  @override
  String get copyUrl => 'Copiar URL';

  @override
  String get couldNotDownloadPdf => 'Não foi possível transferir o PDF';

  @override
  String get couldNotLoadBuildTargets =>
      'Não foi possível carregar os destinos de compilação';

  @override
  String get couldNotLoadDirectives => 'Não foi possível carregar as diretivas';

  @override
  String get couldNotOpenLink => 'Não foi possível abrir o link';

  @override
  String couldNotOpenPdf(Object error) {
    return 'Não foi possível abrir o PDF: $error';
  }

  @override
  String get couldNotOpenPicker => 'Não foi possível abrir o seletor.';

  @override
  String get create => 'Criar';

  @override
  String get createApp => 'Criar App';

  @override
  String get createFirstApp => 'Crie a sua primeira app para começar';

  @override
  String get createIssue => 'Criar Problema';

  @override
  String createdAgo(Object time) {
    return 'criado $time';
  }

  @override
  String get creating => 'A criar...';

  @override
  String criticalCount(Object count) {
    return '$count crítico(s)';
  }

  @override
  String get customAutomationPromptHint =>
      'Prompt de automação personalizado...';

  @override
  String get customPrompt => 'Prompt personalizado';

  @override
  String get dashboard => 'Painel';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteAutomation => 'Eliminar Automação';

  @override
  String deleteAutomationConfirm(Object app) {
    return 'Remover automação de $app?';
  }

  @override
  String get deleteChat => 'Eliminar Conversa';

  @override
  String get deleteChatConfirm => 'Eliminar esta conversa?';

  @override
  String deleteConfirmTitled(Object title) {
    return 'Eliminar \"$title\"?\nEsta ação não pode ser anulada.';
  }

  @override
  String get deleteFailed => 'Falha ao eliminar';

  @override
  String get deleteReportBody =>
      'Isto remove permanentemente o relatório e as suas capturas de ecrã.';

  @override
  String get deleteReportTitle => 'Eliminar relatório?';

  @override
  String get deleted => 'Eliminado';

  @override
  String get dependsOn => 'Depende de';

  @override
  String get deploy => 'Implementar';

  @override
  String get deployToProduction => 'Implementar em Produção';

  @override
  String get deployToProductionBody =>
      'Isto irá compilar e publicar para TODOS os utilizadores no Google Play.\n\nCertifique-se de que testou primeiro em interno/beta.';

  @override
  String get deployToProductionTitle => 'Implementar em Produção?';

  @override
  String get descriptionHint => 'Descrição...';

  @override
  String get designDoc => 'Documento de Design';

  @override
  String get designDocHint =>
      'Descreva a visão, funcionalidades e objetivos da sua app...';

  @override
  String get designDocSaved => 'Documento de design guardado';

  @override
  String get designDocShort => 'Documento de design';

  @override
  String get designDocSubtitle =>
      'A IA usará isto como contexto para todo o trabalho nesta app.';

  @override
  String designDocTitle(Object app) {
    return 'Documento de Design - $app';
  }

  @override
  String get designDocument => 'Documento de Design';

  @override
  String get designReview => 'Revisão de Design';

  @override
  String get designReviewSubtitle => 'GDD, mecânicas, auditoria de UX';

  @override
  String get designReviewTaskCreated => 'Tarefa de revisão de design criada';

  @override
  String get details => 'Detalhes';

  @override
  String get detectingServer => 'A detetar servidor...';

  @override
  String get developer => 'Programador';

  @override
  String get directServerUrlLan => 'URL Direto do Servidor (LAN)';

  @override
  String get directiveHistory => 'Histórico de diretivas';

  @override
  String get dismiss => 'Dispensar';

  @override
  String get display => 'Ecrã';

  @override
  String get doIt => 'Fazer';

  @override
  String get done => 'Concluído';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total concluído(s)';
  }

  @override
  String durationLabelWith(Object seconds) {
    return 'Duração: ${seconds}s';
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
  String get editWorkerUrl => 'Editar URL do Worker';

  @override
  String get engine => 'Motor';

  @override
  String engineChanged(Object previous, Object current) {
    return 'Motor alterado: $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'Motor confirmado: $engine';
  }

  @override
  String get engineDetectionFailed => 'Falha na deteção do motor';

  @override
  String get enhance => 'Melhorar';

  @override
  String get enhanceConfirmBody =>
      'A IA irá reescrever o documento. Esta ação não pode ser anulada.';

  @override
  String enhanceConfirmTitle(Object label) {
    return 'Melhorar $label?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return 'Erro ao melhorar $label: $error';
  }

  @override
  String enhanceStarted(Object label) {
    return 'Melhoria de $label iniciada no servidor...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label melhorado com sucesso';
  }

  @override
  String get enhancementFailed => 'Falha na melhoria';

  @override
  String get enterConceptOrName => 'Introduza um conceito ou nome de projeto';

  @override
  String get enterServerUrlDesc =>
      'Introduza o URL do seu servidor Auto Game Builder';

  @override
  String get enterUrlInPhoneApp =>
      'Introduza este URL na app do telemóvel para ligar remotamente';

  @override
  String get enterValidUrl =>
      'Introduza um URL válido (ex.: http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc =>
      'Introduza o URL do seu Worker para ligar remotamente';

  @override
  String errorWithMessage(Object error) {
    return 'Erro: $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return 'A cada ${minutes}m';
  }

  @override
  String exitLabelWith(Object code) {
    return 'Saída: $code';
  }

  @override
  String get expandFoldersOrCreate =>
      'Expanda as pastas abaixo ou crie uma nova app';

  @override
  String get failed => 'Falhou';

  @override
  String failedCountLabel(Object count) {
    return '$count falhado(s)';
  }

  @override
  String get failedToBrainstorm => 'Falha no brainstorm';

  @override
  String get failedToCreateApp => 'Falha ao criar a app';

  @override
  String get failedToCreateItem => 'Falha ao criar o item';

  @override
  String get failedToCreateTestTask => 'Falha ao criar a tarefa de teste';

  @override
  String get failedToDelete => 'Falha ao eliminar';

  @override
  String get failedToLoadApp => 'Falha ao carregar a app';

  @override
  String get failedToLoadAutomations => 'Falha ao carregar as automações';

  @override
  String get failedToLoadLogs => 'Falha ao carregar os registos';

  @override
  String get failedToLoadTasks => 'Falha ao carregar as tarefas';

  @override
  String failedToLoadWithError(Object error) {
    return 'Falha ao carregar: $error';
  }

  @override
  String get failedToRefreshApp => 'Falha ao atualizar a app';

  @override
  String get failedToRequestCodeCheck =>
      'Falha ao solicitar a verificação de código';

  @override
  String get failedToRequestIdeas => 'Falha ao solicitar ideias';

  @override
  String get failedToReset => 'Falha ao repor';

  @override
  String get failedToRunTask => 'Falha ao executar a tarefa';

  @override
  String failedToSave(Object error) {
    return 'Falha ao guardar: $error';
  }

  @override
  String get failedToStartReupload => 'Falha ao iniciar o reenvio';

  @override
  String failedToStartServer(Object error) {
    return 'Falha ao iniciar o servidor: $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return 'Falha ao iniciar: $error';
  }

  @override
  String failedToTrigger(Object action) {
    return 'Falha ao acionar $action';
  }

  @override
  String get failedToTriggerRun => 'Falha ao acionar a execução';

  @override
  String get failedToUpdate => 'Falha ao atualizar';

  @override
  String get failedToUpdateAiAgent => 'Falha ao atualizar o agente de IA';

  @override
  String get failedToUpdateMcp => 'Falha ao atualizar o MCP';

  @override
  String get favoritesOnly => 'Apenas favoritos';

  @override
  String get feedback => 'Feedback';

  @override
  String fileTooLarge(Object max, Object files) {
    return 'Demasiado grande (máx $max MB): $files';
  }

  @override
  String get filterAll => 'Todos';

  @override
  String get filterClosed => 'Fechados';

  @override
  String get filterOpen => 'Abertos';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count achados',
      one: '1 achado',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return 'concluído $time';
  }

  @override
  String finishedFailedAgo(Object time) {
    return 'falhou $time';
  }

  @override
  String forceRefreshFailed(Object error) {
    return 'Falha ao forçar atualização: $error';
  }

  @override
  String get forceRefreshTooltip =>
      'Forçar atualização a partir do servidor (limpa a cache local)';

  @override
  String get fullAutoMode => 'Modo Totalmente Automático';

  @override
  String get fullAutoModeOn =>
      'A IA lê tarefas, corrige, gera novas ideias, repete';

  @override
  String get generate => 'Gerar';

  @override
  String get generateIdeas => 'Gerar Ideias';

  @override
  String get generateIdeasHint => 'ex.: \"Ideias para melhorar a UI\"';

  @override
  String get genre => 'Género';

  @override
  String get genreAction => 'Ação';

  @override
  String get genreAny => 'Qualquer';

  @override
  String get genreArcade => 'Arcade';

  @override
  String get genreCardGame => 'Jogo de Cartas';

  @override
  String get genreIdleClicker => 'Idle/Clicker';

  @override
  String get genrePuzzle => 'Puzzle';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'Simulação';

  @override
  String get genreStrategy => 'Estratégia';

  @override
  String get genreTowerDefense => 'Tower Defense';

  @override
  String get getStarted => 'Começar';

  @override
  String get googleAccount => 'Conta Google';

  @override
  String get hide => 'Ocultar';

  @override
  String highCount(Object count) {
    return '$count alto(s)';
  }

  @override
  String get ideaGenerationRequested => 'Geração de ideias solicitada';

  @override
  String get installed => 'instalado';

  @override
  String get intervalMinLabel => 'Intervalo (min): ';

  @override
  String get invalidQrData => 'Dados do código QR inválidos';

  @override
  String get issueCreated => 'Problema criado';

  @override
  String get issueTitleHint => 'Título do problema';

  @override
  String get issues => 'Problemas';

  @override
  String get itemCreated => 'Item criado';

  @override
  String get justNow => 'Agora mesmo';

  @override
  String get language => 'Idioma';

  @override
  String get later => 'Mais tarde';

  @override
  String get links => 'Links';

  @override
  String get loginTagline =>
      'Gira os seus projetos de jogos a partir de qualquer lugar';

  @override
  String get logs => 'Registos';

  @override
  String get maintenanceOnly => 'Apenas manutenção';

  @override
  String get markAsCompleted => 'Marcar como Concluído';

  @override
  String get markComplete => 'Marcar como Concluído';

  @override
  String markCompleteConfirm(Object title) {
    return 'Marcar \"$title\" como concluído?';
  }

  @override
  String get markedAsCompleted => 'Marcado como concluído';

  @override
  String maxMinutes(Object minutes) {
    return 'Máx ${minutes}m';
  }

  @override
  String get maxSessionMinLabel => 'Sessão máx (min): ';

  @override
  String get mcpConfiguredPerApp =>
      'Os servidores MCP são configurados por app na página de detalhe da app.';

  @override
  String get mcpServers => 'Servidores MCP';

  @override
  String mcpServersActive(Object count) {
    return 'Servidores MCP ($count ativos)';
  }

  @override
  String get mcpServersDesc =>
      'Servidores de ferramentas disponíveis para todas as execuções de IA nesta app';

  @override
  String mediumCount(Object count) {
    return '$count médio(s)';
  }

  @override
  String get moveBackToActive => 'Mover de volta para Ativo';

  @override
  String get moveToCompletedFolder => 'Mover para a pasta de concluídos';

  @override
  String get nameIsRequired => 'O nome é obrigatório';

  @override
  String get needHelpSettingUp => 'Precisa de ajuda com a configuração?';

  @override
  String get newApp => 'Nova App';

  @override
  String get newAutomation => 'Nova Automação';

  @override
  String get newChat => 'Nova Conversa';

  @override
  String get newItem => 'Novo Item';

  @override
  String get newPrompt => 'Novo prompt';

  @override
  String newReportsCount(Object count) {
    return '$count novo(s) relatório(s)';
  }

  @override
  String get nextRunIn => 'Próxima execução em';

  @override
  String get noApiKeyFound =>
      'Nenhuma chave de API encontrada — reinicie o servidor para gerar uma';

  @override
  String get noAppsMatch => 'Nenhuma app corresponde';

  @override
  String get noAppsYet => 'Ainda não há apps';

  @override
  String get noArtBibleYet =>
      'Ainda não há art bible. Toque em Adicionar para definir a identidade visual — paleta, tipografia, proibições.';

  @override
  String get noAutomationsMatchFilters =>
      'Nenhuma automação corresponde aos filtros';

  @override
  String get noAutomationsYet => 'Ainda não há automações';

  @override
  String noBuildTargetsFor(Object type) {
    return 'Sem destinos de compilação para projetos $type.';
  }

  @override
  String get noBuildsYet => 'Ainda não há compilações';

  @override
  String get noChatsYet => 'Ainda não há conversas';

  @override
  String get noClaudeMdYet =>
      'Ainda não há CLAUDE.md. Toque em Adicionar para definir as instruções do projeto para a IA.';

  @override
  String get noDesignDocYet =>
      'Ainda não há documento de design. Toque em Adicionar para descrever a visão da sua app.';

  @override
  String get noDirectivesYet => 'Ainda não foram enviadas diretivas.';

  @override
  String get noFavoritePrompts => 'Ainda não há prompts favoritos';

  @override
  String get noItemsFound => 'Nenhum item encontrado';

  @override
  String get noLogsFound => 'Nenhum registo encontrado';

  @override
  String get noNewReports => 'Sem novos relatórios';

  @override
  String get noOpenReports => 'Sem relatórios em aberto';

  @override
  String get noOpenTasksToDependOn => 'Não há tarefas abertas para depender';

  @override
  String get noPendingItems => 'Sem itens pendentes para trabalhar';

  @override
  String get noPromptHistory =>
      'Ainda não há histórico de prompts.\nGere ideias para criar histórico.';

  @override
  String get noReportsHere => 'Sem relatórios aqui';

  @override
  String get noWorkerUrlDetected =>
      'Nenhum URL de Worker detetado em settings.json.\nConfigure um Cloudflare Worker para ativar o acesso remoto.';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get notConfigured => 'Não configurado';

  @override
  String get notConnected => 'Não ligado';

  @override
  String get notInstalled => 'não instalado';

  @override
  String get notPaired => 'Não emparelhado';

  @override
  String get notSet => '(não definido)';

  @override
  String get notYetUploaded => 'ainda não carregado';

  @override
  String get onHold => 'Em espera';

  @override
  String get oneShotRunEndsIn => 'A execução única termina em';

  @override
  String oneTimeRunTriggered(Object app) {
    return 'Execução única de $app acionada';
  }

  @override
  String openCountLabel(Object count) {
    return '$count aberto(s)';
  }

  @override
  String get openPdf => 'Abrir PDF';

  @override
  String get openingPdf => 'A abrir PDF…';

  @override
  String get orSeparator => 'OU';

  @override
  String get output => 'Saída';

  @override
  String get packageName => 'Nome do Pacote';

  @override
  String get paired => 'Emparelhado';

  @override
  String get pairedSuccessfully => 'Emparelhado com sucesso!';

  @override
  String get perfProfileTaskCreated => 'Tarefa de perfil de desempenho criada';

  @override
  String get performanceProfile => 'Perfil de Desempenho';

  @override
  String get performanceProfileSubtitle =>
      'Quebras de frames, memória, tempo de carregamento';

  @override
  String get photo => 'Foto';

  @override
  String get postpone => 'Adiar';

  @override
  String postponedCount(Object count) {
    return 'Adiado(s) ($count)';
  }

  @override
  String get pressBackAgainToExit => 'Prima voltar novamente para sair';

  @override
  String get previousChat => 'Conversa Anterior';

  @override
  String get priority => 'Prioridade';

  @override
  String processingTasks(Object done, Object total) {
    return 'A processar $done de $total tarefas...';
  }

  @override
  String get projectPath => 'Caminho do Projeto';

  @override
  String get promptHistory => 'Histórico de Prompts';

  @override
  String get promptHistoryTooltip => 'Histórico de prompts';

  @override
  String get publish => 'Publicar';

  @override
  String get pullAndRebuild => 'Pull e Recompilar';

  @override
  String get pullFailed => 'Falha no pull';

  @override
  String get pullNow => 'Pull agora';

  @override
  String get pullOnly => 'Apenas Pull';

  @override
  String purchaseFailed(Object error) {
    return 'Falha na compra: $error';
  }

  @override
  String get putOnHoldForLater => 'Colocar em espera para mais tarde';

  @override
  String get pythonSectionDesc =>
      'Execute scripts e gira o projeto Python através do servidor.';

  @override
  String get quickIssue => 'Problema Rápido';

  @override
  String get rePairWithQr => 'Reemparelhar com Código QR';

  @override
  String get rebuild => 'Recompilar';

  @override
  String get rebuildBody => 'Iniciar uma nova compilação do zero?';

  @override
  String get rebuildTitle => 'Recompilar?';

  @override
  String get recentBuilds => 'Compilações Recentes';

  @override
  String get refresh => 'Atualizar';

  @override
  String refreshFailedShowingCached(Object message) {
    return 'Falha na atualização — a mostrar os últimos dados sincronizados. $message';
  }

  @override
  String get refreshedFromServer => 'Atualizado a partir do servidor';

  @override
  String get reload => 'Recarregar';

  @override
  String get reopen => 'Reabrir';

  @override
  String get reportBugOrSuggestion => 'Reportar um Bug / Sugestão';

  @override
  String get reportBugSubtitle => 'Diga-nos o que corrigir ou adicionar';

  @override
  String get reportConsent =>
      'Concordo em enviar este relatório com as informações do meu dispositivo (modelo, SO e versão da app) ao programador para ajudar a resolver problemas.';

  @override
  String get reportHint => 'O que aconteceu, ou o que gostaria de ver?';

  @override
  String get reportSentThanks => 'Obrigado! O seu relatório foi enviado.';

  @override
  String get reset => 'Repor';

  @override
  String get resetServer => 'Repor Servidor';

  @override
  String get resetServerBody => 'Isto irá reiniciar o servidor backend.';

  @override
  String resetServerRunningNote(Object count) {
    return '$count automação(ões) em execução será(ão) parada(s) primeiro para evitar o reinício automático.';
  }

  @override
  String get resumeActiveDevelopment => 'Retomar desenvolvimento ativo';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get retryUpload => 'Tentar Carregamento Novamente';

  @override
  String get reuploadStarted => 'Reenvio iniciado';

  @override
  String get run => 'Executar';

  @override
  String get runAgainBody =>
      'Já está em curso uma execução única, mas a IA pode ter parado prematuramente. Acionar outra execução?';

  @override
  String get runAgainTitle => 'Executar Novamente?';

  @override
  String get runAnyway => 'Executar Mesmo Assim';

  @override
  String get runCheck => 'Executar Verificação';

  @override
  String get runOnce => 'Executar Uma Vez';

  @override
  String get runOnceInProgress => 'Executar Uma Vez (em curso)';

  @override
  String get running => 'Em execução';

  @override
  String get save => 'Guardar';

  @override
  String get saveChanges => 'Guardar Alterações';

  @override
  String get saveEmptyGddBody => 'Isto irá apagar o documento de design atual.';

  @override
  String get saveEmptyGddTitle => 'Guardar GDD vazio?';

  @override
  String get saving => 'A guardar...';

  @override
  String scanError(Object error) {
    return 'Erro de digitalização: $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'Falha na digitalização: o servidor devolveu $status';
  }

  @override
  String get scanForProjects => 'Procurar projetos';

  @override
  String get scanPairingQrTitle => 'Digitalizar Código QR de Emparelhamento';

  @override
  String get scanQrToPair => 'Digitalizar Código QR para Emparelhar';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return '$found pastas digitalizadas: $imported importadas, $skipped ignoradas';
  }

  @override
  String get scanThisQr =>
      'Digitalize este código QR a partir do seu telemóvel';

  @override
  String get scanToInstall => 'Digitalize para instalar no seu telemóvel';

  @override
  String get scopeCheck => 'Verificação de Âmbito';

  @override
  String get scopeCheckSubtitle => 'Lista de cortes + análise de realismo';

  @override
  String get scopeCheckTaskCreated => 'Tarefa de verificação de âmbito criada';

  @override
  String get screenshotsOptional => 'Capturas de ecrã (opcional)';

  @override
  String get screenshotsTooLarge =>
      'As capturas de ecrã são grandes — pode ser necessário remover uma.';

  @override
  String get searchAppsHint => 'Pesquisar apps...';

  @override
  String searchFilterChip(Object query) {
    return 'Pesquisa: \"$query\"';
  }

  @override
  String get searchHint => 'Pesquisar...';

  @override
  String get sectionAiAgents => 'Agentes de IA';

  @override
  String get sectionGameEngines => 'Motores de Jogo';

  @override
  String get sectionPaths => 'Caminhos';

  @override
  String get sectionServices => 'Serviços';

  @override
  String get sectionSystemTools => 'Ferramentas do Sistema';

  @override
  String get selectAnApp => 'Selecione uma app';

  @override
  String get selectAnAppFirst => 'Selecione primeiro uma app';

  @override
  String get selectApp => 'Selecionar app';

  @override
  String get selectAppForContext =>
      'Selecione uma app para contexto, ou faça perguntas gerais';

  @override
  String get selectAppToViewItems => 'Selecione uma app para ver os itens';

  @override
  String get selectCategoriesOrPrompt =>
      'Selecione categorias ou escreva o seu próprio prompt.';

  @override
  String get sendReport => 'Enviar relatório';

  @override
  String get sending => 'A enviar…';

  @override
  String get server => 'Servidor';

  @override
  String get serverConfiguration => 'Configuração do Servidor';

  @override
  String get serverConnection => 'Ligação do Servidor';

  @override
  String serverReturnedStatus(Object status) {
    return 'O servidor devolveu o estado $status';
  }

  @override
  String get serverStarted => 'Servidor iniciado!';

  @override
  String get serverStartedHealthFailed =>
      'O servidor foi iniciado, mas a verificação de estado falhou';

  @override
  String get serverStopped => 'Servidor parado';

  @override
  String get serverUnreachable => 'Servidor inacessível';

  @override
  String get serverUrl => 'URL do Servidor';

  @override
  String get sessionEndsIn => 'A sessão termina em';

  @override
  String get sessionRefreshed =>
      'Sessão atualizada — contexto recente preservado';

  @override
  String get settings => 'Definições';

  @override
  String get settingsJsonNotFound => 'settings.json não encontrado';

  @override
  String get settingsJsonRestartNote =>
      'settings.json — reinicie o servidor após alterações';

  @override
  String get settingsSavedRestart =>
      'Definições guardadas — reinicie o servidor para aplicar';

  @override
  String get setupInstructions => 'Instruções de Configuração';

  @override
  String get setupServerFirst => 'Configure primeiro o servidor no seu PC';

  @override
  String get setupStepCloneRepo => 'Clone o repositório:';

  @override
  String get setupStepEnterUrl =>
      'Introduza o URL mostrado no terminal (ex.: http://192.168.1.100:8000):';

  @override
  String get setupStepInstallDeps => 'Instale as dependências:';

  @override
  String get setupStepInstallPython => 'Instale o Python 3.10+ no seu PC';

  @override
  String get setupStepRunWizard => 'Execute o assistente de configuração:';

  @override
  String get setupStepStartServer => 'Inicie o servidor:';

  @override
  String get show => 'Mostrar';

  @override
  String get showAll => 'Mostrar tudo';

  @override
  String get showAppIcons => 'Mostrar ícones das apps';

  @override
  String get showAppIconsDesc =>
      'Mostrar os ícones reais das apps no painel em vez de ícones de tipo genéricos';

  @override
  String get showPairingQr => 'Mostrar Código QR de Emparelhamento';

  @override
  String get signInCancelled => 'O início de sessão foi cancelado';

  @override
  String signInFailed(Object error) {
    return 'Falha no início de sessão: $error';
  }

  @override
  String get signInWithGoogle => 'Iniciar sessão com o Google';

  @override
  String get signOut => 'Terminar Sessão';

  @override
  String get signingIn => 'A iniciar sessão...';

  @override
  String get skipForNow => 'Ignorar por agora';

  @override
  String get start => 'Iniciar';

  @override
  String get startBuildFromCardAbove =>
      'Inicie uma compilação a partir do cartão acima';

  @override
  String get startServer => 'Iniciar Servidor';

  @override
  String get startServerNotFound => 'start_server.py não encontrado';

  @override
  String get status => 'Estado';

  @override
  String get statusActive => 'Ativo';

  @override
  String get statusAll => 'Todos';

  @override
  String get statusBuilt => 'Compilado';

  @override
  String get statusBuiltLower => 'Compilado';

  @override
  String get statusCompleted => 'Concluído';

  @override
  String get statusDivided => 'Dividido';

  @override
  String get statusDone => 'Concluído';

  @override
  String get statusFailedLower => 'Falhado';

  @override
  String statusFilterChip(Object value) {
    return 'Estado: $value';
  }

  @override
  String get statusInProgress => 'Em Curso';

  @override
  String get statusPending => 'Pendente';

  @override
  String get statusPendingLower => 'Pendente';

  @override
  String get statusPostponed => 'Adiado';

  @override
  String get stop => 'Parar';

  @override
  String get stopServer => 'Parar Servidor';

  @override
  String get stoppedLabel => 'Parado';

  @override
  String stuckSuffix(Object time) {
    return '$time BLOQUEADO';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return '$count tarefa(s) bloqueada(s) marcada(s) como falhada(s) automaticamente após 30 min de limite';
  }

  @override
  String get studioReviews => 'Avaliações do Estúdio';

  @override
  String get submit => 'Submeter';

  @override
  String get submitting => 'A submeter...';

  @override
  String get suggestApiBackend => 'API e Backend';

  @override
  String get suggestFeatureIntegration => 'Integração de Funcionalidades';

  @override
  String get suggestFixFailures => 'Corrigir Falhas';

  @override
  String get suggestGddAligned => 'Alinhado com o GDD';

  @override
  String get suggestImproveCodebase => 'Melhorar o Código';

  @override
  String get suggestNextMilestone => 'Próximo Marco';

  @override
  String get suggestPerformanceBoost => 'Aumento de Desempenho';

  @override
  String get suggestRevenueIdeas => 'Ideias de Receita';

  @override
  String get suggestSecurityHardening => 'Reforço de Segurança';

  @override
  String get suggestTaskPrioritization => 'Priorização de Tarefas';

  @override
  String get suggestTestingQa => 'Testes e QA';

  @override
  String get suggestUserEngagement => 'Envolvimento do Utilizador';

  @override
  String get suggestUxPolish => 'Refinamento de UX';

  @override
  String get suggestedForYou => 'Sugerido para si';

  @override
  String get summary => 'Resumo';

  @override
  String get supportDevelopment => 'Apoiar o Desenvolvimento';

  @override
  String get supportDevelopmentDesc =>
      'Está a gostar da app? Considere apoiar o desenvolvimento!';

  @override
  String get syncFailed => 'Falha na sincronização';

  @override
  String syncedAgo(Object time) {
    return 'Sincronizado $time';
  }

  @override
  String get tapPlusToCreateAutomation =>
      'Toque em + para criar a sua primeira automação';

  @override
  String get tapPlusToStartConversation =>
      'Toque em + para iniciar uma conversa';

  @override
  String get tapToAddLongPressToEdit =>
      'Toque para adicionar, prima longamente para editar';

  @override
  String get tapToOpenLongPressToEdit =>
      'Toque para abrir, prima longamente para editar';

  @override
  String get tapToRedetectEngine =>
      'Toque para redetetar o motor a partir do disco';

  @override
  String taskLabelWith(Object task) {
    return 'Tarefa: $task';
  }

  @override
  String get taskOverview => 'Visão Geral das Tarefas';

  @override
  String get taskResetToPending => 'Tarefa reposta para pendente';

  @override
  String get tasks => 'Tarefas';

  @override
  String get techDebtScan => 'Análise de Dívida Técnica';

  @override
  String get techDebtScanSubtitle => 'Scripts monolíticos, duplicados, TODOs';

  @override
  String get techDebtTaskCreated =>
      'Tarefa de análise de dívida técnica criada';

  @override
  String get tellUsMore => 'Conte-nos mais';

  @override
  String get test => 'Testar';

  @override
  String get testConnection => 'Testar Ligação';

  @override
  String get testTaskCreated => 'Tarefa de teste criada';

  @override
  String get testing => 'A testar...';

  @override
  String get theme => 'Tema';

  @override
  String get thinking => 'A pensar...';

  @override
  String timeDaysAgo(Object days) {
    return 'há ${days}d';
  }

  @override
  String timeHoursAgo(Object hours) {
    return 'há ${hours}h';
  }

  @override
  String get timeJustNow => 'agora';

  @override
  String timeMinutesAgo(Object minutes) {
    return 'há ${minutes}m';
  }

  @override
  String timeMonthsAgo(Object months) {
    return 'há ${months}mês';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return 'há ${seconds}s';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return 'há ${weeks}sem';
  }

  @override
  String get titleHint => 'Título';

  @override
  String get titleIsRequired => 'O título é obrigatório';

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
    return 'Acionado(s) $done de $total itens';
  }

  @override
  String get tryChangingFilters =>
      'Tente alterar o filtro de categoria ou estado';

  @override
  String get type => 'Tipo';

  @override
  String get typeBug => 'Bug';

  @override
  String get typeFeature => 'Funcionalidade';

  @override
  String typeFilterChip(Object value) {
    return 'Tipo: $value';
  }

  @override
  String get typeFix => 'Correção';

  @override
  String get typeIdea => 'Ideia';

  @override
  String get typeIssue => 'Problema';

  @override
  String get updateAvailable => 'Atualização Disponível';

  @override
  String get updateAvailableBody =>
      'Está disponível uma nova versão no GitHub.\nFaça pull do código mais recente e recompile para atualizar.';

  @override
  String get updateFailed => 'Falha na atualização';

  @override
  String updatedAgo(Object time) {
    return 'atualizado $time';
  }

  @override
  String updatedNamed(Object label) {
    return '$label atualizado';
  }

  @override
  String get uploadToGooglePlay => 'Carregar para o Google Play';

  @override
  String urgentCountLabel(Object count) {
    return '$count urgente(s)';
  }

  @override
  String get urgentLabel => 'urgente';

  @override
  String get userFallback => 'Utilizador';

  @override
  String get version => 'Versão';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => 'Ver tarefas falhadas';

  @override
  String get viewIssues => 'Ver problemas';

  @override
  String get viewOnGitHub => 'Ver no GitHub';

  @override
  String get warningPublishesToAll =>
      'Aviso: Isto publica para todos os utilizadores!';

  @override
  String get webDeploy => 'Implementação Web';

  @override
  String get webDeploySectionDesc =>
      'Compile e implemente a app web através do servidor.';

  @override
  String get website => 'Website';

  @override
  String get whatIsThis => 'O que é isto?';

  @override
  String get workOnAll => 'Trabalhar em Tudo';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n($count item(ns) bloqueado(s) será(ão) ignorado(s).)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return 'Executar a IA em todos os $count item(ns) pendente(s)?\nSerão processados sequencialmente.';
  }

  @override
  String get workOnAllPending => 'Trabalhar em Todos os Pendentes';

  @override
  String get workOnThis => 'Trabalhar Nisto';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return 'Executar a IA $agent em:\n\"$title\"';
  }

  @override
  String get workerUrl => 'URL do Worker';

  @override
  String get workerUrlAutoDetected =>
      'Detetado automaticamente a partir de settings.json (só leitura)';

  @override
  String get workerUrlCopied => 'URL do Worker copiado';

  @override
  String get workerUrlHelp =>
      'Obtenha este URL na app de desktop ou junto do administrador do seu servidor';

  @override
  String get workerUrlSaved => 'URL do Worker guardado';

  @override
  String get workerUrlSetHint =>
      'Defina cloudflare.worker_url em server/config/settings.json';

  @override
  String get youreAllSet => 'Está Tudo Pronto!';
}

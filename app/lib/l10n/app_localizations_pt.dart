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
  String get shareUsageStats => 'Partilhar estatísticas de uso anónimas';

  @override
  String get shareUsageStatsDesc =>
      'Contagens anónimas de sessões e de ecrãs abertos. Sem nomes de projeto, sem texto de tarefas, sem caminhos.';

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

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'Ainda não há AGENTS.md. Toque em Adicionar para definir as instruções do projeto para a IA.';

  @override
  String get cannotSaveEmptyAgentsMd =>
      'Não é possível guardar um AGENTS.md vazio';

  @override
  String get agentsMdSaved => 'AGENTS.md guardado';

  @override
  String get reportEmailLabel => 'E-mail (opcional)';

  @override
  String get reportEmailHint => 'seu e-mail, se quiser resposta';

  @override
  String get reportEmailNote =>
      'Usado apenas para responder a este relato. Deixe vazio para continuar anônimo.';

  @override
  String get reportEmailInvalid => 'Isso não parece um endereço de e-mail.';

  @override
  String get reportReply => 'Responder';

  @override
  String reportReplySubject(String app) {
    return 'Sobre o seu relato do $app';
  }

  @override
  String get navGenerate => 'Gerar';

  @override
  String get navGallery => 'Gerados';

  @override
  String get navFlow => 'Linha';

  @override
  String get navQueue => 'Fila';

  @override
  String get navDelivery => 'Entrega';

  @override
  String get navBuckets => 'Buckets';

  @override
  String get assetModeTooltip => 'Modo de recursos';

  @override
  String get deliveryModeTooltip => 'Modo de entrega';

  @override
  String get videoPlaybackFailed => 'Não foi possível reproduzir o vídeo';

  @override
  String get apiKeyRefusedBanner =>
      'Chave de API recusada - toque para corrigir nas Configurações';

  @override
  String get errOffline =>
      'Não foi possível contatar o servidor - verifique sua conexão';

  @override
  String get errTimeout =>
      'O servidor demorou demais para responder - tente novamente';

  @override
  String errGatewayTimeout(int status) {
    return 'O servidor não respondeu a tempo (tempo limite do gateway $status)';
  }

  @override
  String errGateway(int status) {
    return 'O servidor está inacessível atrás do gateway (erro de gateway $status) - verifique se ele está em execução';
  }

  @override
  String errServer(int status) {
    return 'Erro do servidor ($status) - tente mais tarde';
  }

  @override
  String errUnauthorized(int status) {
    return 'Não autorizado ($status) - verifique a chave de API nas Configurações';
  }

  @override
  String errNotFound(int status) {
    return 'Não encontrado no servidor ($status)';
  }

  @override
  String errRateLimited(int status) {
    return 'Muitas solicitações ($status) - aguarde um momento e tente novamente';
  }

  @override
  String errTooLarge(int status) {
    return 'Grande demais para o servidor ($status)';
  }

  @override
  String errRejected(int status) {
    return 'O servidor recusou a solicitação ($status)';
  }

  @override
  String get errBadResponse =>
      'O servidor enviou uma resposta que o app não conseguiu ler';

  @override
  String get errUnknown => 'A solicitação falhou - tente novamente';

  @override
  String bucketsCounting(String bucket) {
    return 'Contando $bucket...';
  }

  @override
  String get bucketsTakedownTitle => 'Remoção (novo + antigo)';

  @override
  String get bucketsDeleteForeverTitle => 'Excluir definitivamente';

  @override
  String bucketsDeleteWarning(int count) {
    return '$count objetos serão excluídos. ISSO NÃO PODE SER DESFEITO.';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count chaves não têm correspondência no gêmeo antigo - são excluídas apenas deste bucket.';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return 'Digite o nome do bucket para confirmar: $bucket';
  }

  @override
  String get bucketsTakedown => 'Remover';

  @override
  String bucketsDeleted(int count) {
    return '$count objetos excluídos';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count objetos excluídos, $twin do gêmeo antigo';
  }

  @override
  String bucketsCopySource(String path) {
    return 'Origem: $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'Árvore de origem: $path';
  }

  @override
  String get bucketsWholeBucket => '(bucket inteiro)';

  @override
  String get bucketsCopyNote =>
      'A cópia é feita dentro do serviço de armazenamento - nenhum byte passa pelo telefone.';

  @override
  String get bucketsTargetKey => 'Chave de destino';

  @override
  String get bucketsTargetPrefix => 'Prefixo de destino';

  @override
  String bucketsCopyStarted(String op) {
    return 'Cópia iniciada ($op)';
  }

  @override
  String get bucketsFixHeadersTitle => 'Corrigir cabeçalhos';

  @override
  String bucketsFixHeadersBody(String path) {
    return 'O cabeçalho Cache-Control dos objetos em $path é verificado; um objeto fora do padrão é regravado no lugar (Content-Type é mantido). Nenhum byte é baixado.\n\nPrefixos deixados mutáveis de propósito são ignorados.';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'Reparo de cabeçalhos iniciado ($op)';
  }

  @override
  String get bucketsOperations => 'Operações';

  @override
  String get bucketsNoOperations => 'Nenhuma operação ainda';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  ok $ok  ·  falhas $failed';
  }

  @override
  String get bucketsTwinDiffRunning => 'Calculando a diferença com o gêmeo...';

  @override
  String get bucketsLocalDiffRunning => 'Calculando a diferença local...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin (gêmeo antigo)';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'Pasta local enviada <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => 'Ausente no gêmeo antigo';

  @override
  String get bucketsMissingInBucket => 'Ausente no bucket';

  @override
  String get bucketsOnlyInLegacy => 'Somente no gêmeo antigo';

  @override
  String get bucketsOnlyInBucket => 'Somente no bucket';

  @override
  String get bucketsSizeMismatch => 'Tamanho diferente';

  @override
  String get bucketsUnmapped => 'Sem correspondência (sem regra)';

  @override
  String get bucketsDerived => 'Gerado no bucket (miniaturas)';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title: $count';
  }

  @override
  String get bucketsFixFolderHeaders => 'Corrigir os cabeçalhos desta pasta';

  @override
  String get bucketsDiffs => 'Diferenças';

  @override
  String get bucketsTwinDiff => 'Diferença com o gêmeo antigo';

  @override
  String get bucketsLocalDiff => 'Diferença com a pasta local enviada';

  @override
  String get bucketsIntro =>
      'Um bucket é o depósito que leva o nome do seu conteúdo. As contagens são calculadas sob demanda (apenas listagem, nenhum byte é baixado).';

  @override
  String get bucketsBadgeLegacy => 'ANTIGO';

  @override
  String get bucketsBadgePrivate => 'privado';

  @override
  String get bucketsBadgeContent => 'conteúdo';

  @override
  String get bucketsNotCounted => 'não contado';

  @override
  String bucketsObjectCount(int count) {
    return '$count objetos';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'gêmeo: $twin';
  }

  @override
  String get bucketsCount => 'Contar';

  @override
  String get bucketsEmptyFolder => 'Esta pasta está vazia';

  @override
  String get bucketsTruncated =>
      'A lista foi cortada - abra uma pasta mais específica';

  @override
  String bucketsSelectedCount(int count) {
    return '$count selecionados';
  }

  @override
  String get bucketsClearSelection => 'Limpar seleção';

  @override
  String get bucketsTakedownTooltip =>
      'Remoção (excluir também do gêmeo antigo)';

  @override
  String get bucketsSize => 'Tamanho';

  @override
  String get bucketsContentType => 'Tipo';

  @override
  String get bucketsModified => 'Modificado';

  @override
  String get bucketsNone => '(nenhum)';

  @override
  String get bucketsMutableOnPurpose =>
      'Mutável de propósito - nenhum padrão se aplica';

  @override
  String bucketsHeaderOk(String kind) {
    return 'Atende ao padrão de cache ($kind)';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return 'Padrão: $expected';
  }

  @override
  String get bucketsLegacyTwin => 'Gêmeo antigo';

  @override
  String get bucketsAddressCopied => 'Endereço copiado';

  @override
  String get bucketsCopyAddress => 'Copiar endereço';

  @override
  String get bucketsOpen => 'Abrir';

  @override
  String get bucketsPrivateNoAddress =>
      'Este bucket é privado - não tem endereço público';

  @override
  String get kindCard => 'Carta';

  @override
  String get kindCharacter => 'Personagem';

  @override
  String get assetCodeMode => 'Modo de código';

  @override
  String get assetPickFinishedImage => 'Selecione uma imagem concluída';

  @override
  String get assetGenerateVideo => 'Gerar vídeo';

  @override
  String get assetEnlarge => 'Ampliar';

  @override
  String percentValue(Object value) {
    return '$value%';
  }

  @override
  String get commonCategory => 'Categoria';

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
  String get charKindFemale => 'Mulher';

  @override
  String get charKindMale => 'Homem';

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
  String get outfitCatShoes => 'Sapatos';

  @override
  String get outfitCatSocks => 'Meias';

  @override
  String get outfitCatHat => 'Chapéu';

  @override
  String get outfitCatHeadgear => 'Adereço de cabeça';

  @override
  String get outfitCatAccessory => 'Acessório';

  @override
  String get outfitCatWeapon => 'Arma';

  @override
  String get audioLabel => 'Áudio';

  @override
  String get audioDownloading => 'A transferir...';

  @override
  String get audioOpen => 'Abrir áudio';

  @override
  String get outfitExtractTitle => 'Extrair traje';

  @override
  String get outfitExtractBody =>
      'A pessoa da imagem selecionada é removida e o traje é guardado no guarda-roupa como foto de produto em manequim invisível, sobre fundo cinzento liso. Depois, qualquer personagem pode usá-lo como skin.';

  @override
  String get outfitExtractName => 'Nome do traje';

  @override
  String get outfitExtractNameHint => 'ex.: Vestido de noite vermelho';

  @override
  String get outfitExtractNote => 'Nota (opcional)';

  @override
  String get outfitExtractNoteHint => 'ex.: só o vestido, sem os sapatos';

  @override
  String get outfitExtractHelp =>
      'Conjunto: tudo o que a pessoa veste, numa só imagem. Arma / acessório: apenas esse objeto, sem manequim.';

  @override
  String get outfitExtractAction => 'Extrair';

  @override
  String equipSlotTitle(Object category) {
    return 'Espaço: $category';
  }

  @override
  String get equipSlotMultiHint =>
      'seleção múltipla - toque para vestir / tirar';

  @override
  String get equipSlotSingleHint =>
      'seleção única - toque para vestir, toque de novo para tirar';

  @override
  String get equipSlotEmpty => '(vazio)';

  @override
  String get equipSlotNoOutfits =>
      'Não há trajes prontos nesta categoria - use \"+ Gerar traje\" ou \"Extrair traje\"';

  @override
  String get equipBaseLabel => 'Base:';

  @override
  String get equipUndress => 'Tirar tudo';

  @override
  String get equipPickSourceTitle => 'Escolher imagem de origem';

  @override
  String get equipPickSourceHint =>
      'As últimas gerações concluídas (todos os modos). Para as imagens incoming / staging / pushed da linha Jigsaw use o ecrã Linha > Jigsaw.';

  @override
  String get equipNoFinishedImage => 'Nenhuma imagem concluída';

  @override
  String get freeFlowTitle => 'Linha Free';

  @override
  String get freeFlowEditTitle => 'Editar - motor de edição';

  @override
  String get freeFlowEditLabel => 'O que deve mudar';

  @override
  String get freeFlowEditHint =>
      'ex.: change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => 'Edição adicionada à fila';

  @override
  String get freeFlowNoVideoTask => 'O modo Free não tem tarefa de vídeo';

  @override
  String freeFlowVideoTitle(Object task) {
    return 'Gerar vídeo - $task';
  }

  @override
  String get freeFlowMotionLabel => 'Movimento';

  @override
  String get freeFlowMotionHint =>
      'ex.: she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued =>
      'Vídeo adicionado à fila - quando terminar, aparece uma marca de reprodução neste cartão';

  @override
  String get freeFlowDeleteConfirm => 'Eliminar esta geração?';

  @override
  String get freeFlowDeleteWithVideosConfirm =>
      'Eliminar esta geração e os seus vídeos?';

  @override
  String get freeFlowEmpty =>
      'Ainda nada foi gerado no modo Free - comece no separador Gerar';

  @override
  String get queueKindGeneration => 'Geração';

  @override
  String get queueKindTag => 'Etiquetagem';

  @override
  String get queueKindMusic => 'Música';

  @override
  String get queueKindJob => 'Trabalho';

  @override
  String get queueCancelRunningTitle => 'Cancelar o trabalho em curso';

  @override
  String get queueRemoveTitle => 'Remover da fila';

  @override
  String get queueCancelIt => 'Cancelar';

  @override
  String get queueClearTitle => 'Limpar a fila';

  @override
  String get queueClearBody =>
      'Cancelar os trabalhos de geração em espera? O trabalho em curso continua.';

  @override
  String get queueCancelWaiting => 'Cancelar os trabalhos em espera';

  @override
  String get queueEmpty => 'A fila está vazia';

  @override
  String get queueEmptyHint => 'Pode adicionar trabalhos no separador Gerar';

  @override
  String get queueNow => 'Agora';

  @override
  String queueWaitingCount(Object count) {
    return 'Em espera ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return 'Trabalhos de geração ($count)';
  }

  @override
  String get queueOneQueue => 'Uma só fila - todos os trabalhos';

  @override
  String queueJobCount(Object count) {
    return '$count trabalhos';
  }

  @override
  String get queueMoveUp => 'Mover para cima';

  @override
  String get queueMoveDown => 'Mover para baixo';

  @override
  String get queueUp => 'Cima';

  @override
  String get queueDown => 'Baixo';

  @override
  String queueElapsed(Object time) {
    return 'decorrido $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return 'em espera $time';
  }

  @override
  String get queueWaiting => 'em espera';

  @override
  String get queueComfyReady => 'ComfyUI pronto';

  @override
  String get queueComfyOff => 'ComfyUI está desligado';

  @override
  String get deliveryPoolNeverRan => 'nunca executado';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (simulação)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · $total imagens, $valid válidas, $tagged etiquetadas, $failed falhadas';
  }

  @override
  String get reportErrEmpty => 'Escreva primeiro uma mensagem.';

  @override
  String get reportErrTooLarge =>
      'Os anexos são demasiado grandes. Remova um e tente novamente.';

  @override
  String flowOpError(Object message) {
    return 'A operação falhou: $message';
  }

  @override
  String get flowOpCancelled => 'Operação cancelada';

  @override
  String flowOpDone(Object ok) {
    return '$ok concluídos';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok concluídos, $failed falhados';
  }

  @override
  String get flowCollection => 'Coleção';

  @override
  String get flowAllParen => '(todas)';

  @override
  String get flowAll => 'todas';

  @override
  String get flowSelectAll => 'Selecionar tudo';

  @override
  String get flowRetag => 'Etiquetar de novo';

  @override
  String get flowRetagShort => 'Etiquetar';

  @override
  String get flowRetagStarted => 'Etiquetagem iniciada';

  @override
  String get flowReadOnly => 'Só leitura';

  @override
  String get flowPush => 'Push';

  @override
  String get flowPreview => 'Pré-visualização';

  @override
  String get flowYes => 'sim';

  @override
  String get flowNo => 'não';

  @override
  String get flowMissingUpper => 'FALTA';

  @override
  String get flowBadgeNoTags => 'sem etiquetas';

  @override
  String get flowTabPushed => '4 Publicados';

  @override
  String get flowSelectAssetFirst => 'Selecione primeiro um recurso';

  @override
  String get flowAccept => 'Aceitar';

  @override
  String get flowReject => 'Rejeitar';

  @override
  String get flowUpload => 'Enviar';

  @override
  String get flowNew => 'Nova';

  @override
  String get flowReadFailed => 'Não foi possível ler a linha';

  @override
  String flowFilesDeleted(Object count) {
    return '$count ficheiros eliminados';
  }

  @override
  String get flowNegative => 'Negativo';

  @override
  String get flowPositive2 => 'Positivo 2';

  @override
  String get flowDuration => 'Duração';

  @override
  String get flowAddToQueue => 'Adicionar à fila';

  @override
  String get commonDescription => 'Descrição';

  @override
  String get cbnFlowTitle => 'Linha CBN';

  @override
  String get cbnFlowTabIncoming => '2 Recebidos';

  @override
  String get cbnFlowTabReady => '3 Prontos';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'Construir - $count recursos';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      'Regiões + paleta + modelo numerado + vídeo reveal (CPU). O passo SAM tem de estar feito; os contornos vêm dos limites do SAM. (Hot: a construção gera a página de traços com o Qwen; o passo C é uma pré-visualização opcional.)';

  @override
  String get cbnFlowBuildBodyKid =>
      'Regiões + paleta + modelo numerado + SVG (CPU). O passo SAM tem de estar feito.';

  @override
  String get cbnFlowBuild => 'Construir';

  @override
  String get cbnFlowBuildStarted =>
      'Construção iniciada - o progresso aparece em cima';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stage iniciado ($count recursos)';
  }

  @override
  String get cbnFlowStageObjects => 'Lista de objetos';

  @override
  String get cbnFlowLineart => 'Traços';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'Push - $count recursos';
  }

  @override
  String get cbnFlowPushBody =>
      'As pastas de recursos serão enviadas para o R2 e movidas para \"Publicados\".\n\nÉ uma PUBLICAÇÃO e não pode ser desfeita.';

  @override
  String cbnFlowDeleteBody(Object count) {
    return '$count recursos serão eliminados.';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count eliminados';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'Não há recursos nesta etapa.\nEnvie-os para aqui com ACEITAR no modo CBN, no ecrã \"Gerados\".';

  @override
  String get cbnFlowEmptyStaging =>
      'Ainda não há recursos construídos.\nSelecione no separador \"Recebidos\" e toque em CONSTRUIR.';

  @override
  String get cbnFlowEmptyPushed => 'Não há recursos publicados.';

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
  String get cbnFlowLayerSource => 'Origem';

  @override
  String get cbnFlowLayerObjects => 'Objetos';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions regiões · $colors cores · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   etiquetas: $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) Encontrar objetos';

  @override
  String get cbnFlowSamMasks => 'B) Máscaras SAM';

  @override
  String get cbnFlowLineartPage => 'C) Página de traços (opcional, Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) Construir';

  @override
  String get cbnFlowStepMissingA =>
      'O passo A (lista de objetos) não foi executado';

  @override
  String get cbnFlowStepMissingB =>
      'O passo B (máscaras SAM) não foi executado';

  @override
  String get cbnFlowStepMissingC =>
      'O passo C (página de traços) não foi executado';

  @override
  String get cbnFlowImageFailed => 'Não foi possível carregar a imagem';

  @override
  String get jigsawFlowTitle => 'Linha Jigsaw';

  @override
  String get jigsawFlowTabTagged => '2 Etiquetados';

  @override
  String get jigsawFlowTabToPush => '3 Por publicar';

  @override
  String get jigsawFlowQueueAll => 'TUDO NA FILA';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'TUDO NA FILA - $count recursos';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return 'Gerar vídeo - $count recursos';
  }

  @override
  String get jigsawFlowPositive1 => 'Positivo 1 - assunto';

  @override
  String get jigsawFlowPositive1Help =>
      'vazio = o prompt próprio de cada recurso';

  @override
  String get jigsawFlowMotionPreset => 'Modelo de movimento';

  @override
  String get jigsawFlowSpreadInTurn => '(distribuir à vez)';

  @override
  String get jigsawFlowPositive2 => 'Positivo 2 - movimento';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = lugar do prompt do assunto. Vazio = os modelos à vez.';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return 'Os $count modelos serão distribuídos à vez.';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => 'Não há recursos sem vídeo';

  @override
  String get jigsawFlowSelectWithoutVideo => 'Selecione recursos sem vídeo';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued vídeos adicionados à fila - chegam aqui quando terminarem';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued vídeos adicionados à fila, $skipped ignorados - chegam aqui quando terminarem';
  }

  @override
  String get jigsawFlowNoVideoTitle => 'Sem vídeo';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count recursos não têm vídeo - só o jpg será escrito. Continuar?';
  }

  @override
  String get jigsawFlowMusicNotReady => 'O modelo de música não está pronto';

  @override
  String get jigsawFlowNoMusicMissing =>
      'Nenhuma coleção temática está sem música';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection já tem música ou é Generic';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return 'Será gerada uma faixa instrumental de 30 segundos para $count coleções (ACE-Step, local).\n\n$names\n\nCada uma pode demorar alguns minutos.';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count recursos serão ENVIADOS para o bucket R2.\n\nÉ uma publicação que não pode ser desfeita - os ficheiros enviados ficam visíveis na app.';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return 'Eliminar definitivamente $count recursos (jpg + mp4 + webp + json)?';
  }

  @override
  String get jigsawFlowWebpStarted => 'A gerar os webp em falta';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return 'Coleção de $mode';
  }

  @override
  String get jigsawFlowCollectionHelp =>
      'escolha da lista ou escreva um nome NOVO';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return 'escolha da lista ou escreva um nome NOVO  -  $count coleções cheias estão ocultas';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total recursos - seguinte $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'Não há recursos nesta etapa.\nEnvie-os para aqui com ACEITAR no ecrã \"Gerados\".';

  @override
  String get jigsawFlowEmpty => 'Não há recursos nesta etapa.';

  @override
  String get jigsawFlowBadgeNoWebp => 'sem webp';

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
      'Nenhum dos recursos selecionados tem vídeo';

  @override
  String get jigsawFlowDeleteVideo => 'Eliminar vídeo';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return 'O mp4 + webp de $count recursos serão eliminados; a imagem fica e pode gerar um novo vídeo.';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip => 'Eliminar vídeo (a imagem fica)';

  @override
  String get jigsawFlowExtractNeedsOne =>
      'O traje é extraído de uma só imagem - selecione uma';

  @override
  String outfitExtractStarted(Object name) {
    return '$name está a ser extraído para o guarda-roupa - Personagem > Guarda-roupa';
  }

  @override
  String get jigsawFlowMetaFile => 'Ficheiro';

  @override
  String get jigsawFlowMetaTags => 'Etiquetas';

  @override
  String get jigsawFlowMetaSubject => 'Assunto';

  @override
  String get jigsawFlowMetaPolicy => 'Política';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   webp: $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'Etiquetas / metadados';

  @override
  String get jigsawFlowMissingWebp => 'Webp em falta';

  @override
  String deliverySavedLive(Object time) {
    return 'Guardado e ATIVO ($time) - a atualizar as contagens';
  }

  @override
  String get deliveryReindexTitle => 'Reler os metadados';

  @override
  String get deliveryReindexBody =>
      'Para imagens cujo EXIF mudou no bucket. Escreva os nomes dos ficheiros separados por vírgulas (ex.: 12.jpg, 340.jpg); deixe vazio para reler TODO o Generic (~1500 ficheiros, alguns minutos).';

  @override
  String get deliveryReindexNames => 'Nomes dos ficheiros';

  @override
  String get deliveryReindexAction => 'Ler';

  @override
  String deliveryReindexed(Object count) {
    return '$count imagens relidas - manifestos atualizados';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count imagens relidas, $missing não encontradas - manifestos atualizados';
  }

  @override
  String get deliveryDryRunStarted =>
      'Simulação iniciada - só produz um relatório';

  @override
  String get deliveryNormalizeStarted => 'Normalização iniciada';

  @override
  String get deliveryCancelRequested => 'Cancelamento pedido';

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
    return 'Grupo $pool: $total imagens, $tagged etiquetadas, $untagged sem etiqueta';
  }

  @override
  String get deliverySaveBeforeSwitch =>
      'Guarde as alterações antes de mudar de grupo.';

  @override
  String get deliveryReindexTooltip => 'Reler os metadados (se o EXIF mudou)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return 'Última regra: $time  ·  servidas por omissão: $served / $total';
  }

  @override
  String get deliveryIntro =>
      'Interruptor DESLIGADO = as imagens com esse valor saem do manifesto. Guardar fica ativo de imediato e agora filtra TODAS as coleções / baralhos; um item isolado que escape às regras fecha-se com a lista de bloqueio.';

  @override
  String get deliveryNormalizeTitle =>
      'Normalizar - gerar as etiquetas em falta';

  @override
  String get deliveryDryRun => 'Simulação';

  @override
  String get deliveryNormalizeNoStatus =>
      'Estado indisponível - o servidor não respondeu a /api/normalize/status';

  @override
  String deliveryIndex(Object index) {
    return 'Índice: $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return 'Última execução: $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => 'todas as apps (global)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'Bloquear · $scope';
  }

  @override
  String get deliveryOpenList => 'Abrir a lista';

  @override
  String get deliveryBlockIntro =>
      'Um bloqueio global vale em TODAS as apps; selecione uma app para bloquear só nessa app. É aplicado DEPOIS das regras.';

  @override
  String get deliveryBlockEmpty =>
      'Não há nada para bloquear neste grupo (o bucket está vazio).';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count itens · $tagged/$count etiquetados';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count itens · $tagged/$count etiquetados · TUDO BLOQUEADO';
  }

  @override
  String get deliveryAppsHint => 'Apps - toque para editar a regra dessa app';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return 'Predefinição  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      'Regra predefinida - versões antigas que não enviam ?app= e apps sem regra própria';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return 'Regra própria para $app';
  }

  @override
  String get deliveryCustomRuleOn => 'Desligue para voltar à predefinição';

  @override
  String get deliveryCustomRuleOff =>
      'Desligado: aplica-se a regra predefinida. Ao ligar, começa com uma cópia dela.';

  @override
  String get deliveryScopeTitle => 'Só as coleções selecionadas';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total coleções - as recém-publicadas NÃO chegam a esta app';
  }

  @override
  String get deliveryScopeOff =>
      'Desligado: cada coleção recém-publicada também chega a esta app';

  @override
  String get deliveryScopeNone =>
      'Nenhuma selecionada - uma lista vazia não é guardada, a regra volta a \"todas\".';

  @override
  String get deliveryRulesEnabled => 'Regras ativas';

  @override
  String get deliveryRulesEnabledHint =>
      'Desligado = este conjunto de regras não filtra nada';

  @override
  String get deliveryServeUntagged => 'Servir imagens sem etiqueta';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count imagens não têm metadados';
  }

  @override
  String get deliveryQuick => 'Rápido:';

  @override
  String deliveryOffCount(Object count) {
    return '$count desligados';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count valores';
  }

  @override
  String get deliveryUnsaved => 'Há alterações por guardar';

  @override
  String get deliveryInSync => 'Igual ao servidor';

  @override
  String get deliverySavePublish => 'Guardar e publicar';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonModel => 'Modelo';

  @override
  String get cardTplShuffled =>
      'Baralhado - os eixos bloqueados não foram alterados';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank baralhado';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - para todos';
  }

  @override
  String get cardTplAxisAllBack => 'É escrito no verso da carta e BLOQUEADO.';

  @override
  String get cardTplAxisAllFront =>
      'É escrito nas 13 cartas + 2 jokers de uma vez e BLOQUEADO - baralhar não o altera.';

  @override
  String get cardTplValue => 'Valor';

  @override
  String get cardTplAllWritten => 'Escrito em todos e bloqueado';

  @override
  String cardTplRankTitle(Object rank) {
    return 'Modelo de $rank';
  }

  @override
  String get cardTplLocked => 'Bloqueado';

  @override
  String get cardTplLock => 'Bloquear';

  @override
  String get cardTplManual => 'Extra manual (texto livre)';

  @override
  String get cardTplManualHint => 'ex.: holding a golden card fan';

  @override
  String get cardTplManualHelp =>
      'É acrescentado ao fim do modelo - baralhar não o apaga';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank guardado';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot adicionado à fila';
  }

  @override
  String cardTplTitle(Object title) {
    return 'Carta de coleção - $title';
  }

  @override
  String get cardTplShuffle => 'Baralhar';

  @override
  String get cardTplNoTheme => 'Sem tema - toque para escrever';

  @override
  String get cardTplThemeTitle => 'Tema (P1)';

  @override
  String get cardTplPresetCard => 'Carta predefinida';

  @override
  String get cardTplTheme => 'Tema';

  @override
  String get cardTplThemeHelp =>
      'identidade + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'O tema não pode ficar vazio';

  @override
  String get cardTplThemeSaved => 'Tema guardado';

  @override
  String cardTplModelSet(Object name) {
    return 'Modelo: $name';
  }

  @override
  String get cardTplFaceDetail => 'Retoque do rosto';

  @override
  String get cardTplFaceDetailHint =>
      '+15 s por carta - passa o rosto por uma passagem à parte';

  @override
  String get cardTplFaceDetailOn => 'Retoque do rosto ligado';

  @override
  String get cardTplFaceDetailOff => 'Retoque do rosto desligado';

  @override
  String get cardTplVideoEngine =>
      'Motor de vídeo (primeiro fotograma = último)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (não instalado)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return 'Motor de vídeo: $name';
  }

  @override
  String get cardTplApplyToAll => 'Aplicar a todos:';

  @override
  String get cardTplPickAxis => 'escolher um eixo';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (verso)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count eixos bloqueados';
  }

  @override
  String get cardTplShuffleSlot => 'Baralhar este espaço';

  @override
  String get cardTplGenerateSlot => 'Gerar este espaço';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return 'Eliminar $count gerações e os seus ficheiros?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count gerações eliminadas';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count não puderam ser eliminadas';
  }

  @override
  String get galleryCharacterNeedsOne =>
      'Uma personagem é criada a partir de uma só imagem - selecione uma';

  @override
  String get galleryMakeCharacter => 'Criar personagem';

  @override
  String get galleryMakeCharacterBody =>
      'A imagem selecionada passa diretamente a ser a base; o retrato, a história e as 7 direções são gerados sozinhos - sem pedir confirmação.';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name adicionado à fila - acompanhe o processo no separador Fila';
  }

  @override
  String get galleryCreateCharacterFirst =>
      'Crie primeiro uma personagem com \"Criar personagem\"';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return 'Adicionar aos candidatos - $count imagens';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$count imagens adicionadas aos candidatos de $name';
  }

  @override
  String get galleryCollectionNeedsOne =>
      'Só se adiciona uma imagem a uma coleção - selecione uma';

  @override
  String get galleryCreateCollectionFirst =>
      'Crie primeiro uma coleção ou um croupier na linha de Cartas';

  @override
  String get galleryAddToCollection => 'Adicionar à coleção';

  @override
  String get galleryDealerNoRank => 'croupier (sem valor)';

  @override
  String galleryPickRank(Object name) {
    return '$name - escolher um valor';
  }

  @override
  String get galleryQueuedOne =>
      'Adicionado à fila (1 trabalho) - acompanhe no separador Fila';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count imagens passam para a etapa \"Recebidos\" da linha CBN: jpg + etiquetas EXIF. A construção (SAM, traços, regiões) é iniciada lá.\n\nQue classificação?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count imagens passam para a etapa 2: jpg + etiquetas EXIF, com o vídeo ao lado se existir.\n\nQue classificação?';
  }

  @override
  String get galleryAcceptStarted =>
      'Iniciado - acompanhe o progresso no separador \"Linha\"';

  @override
  String get galleryExtractTooltip =>
      'Extrair traje - levar o traje da imagem para o guarda-roupa';

  @override
  String get galleryMakeCharacterTooltip =>
      'Criar personagem - cria uma nova personagem';

  @override
  String get galleryAddToCandidatesTooltip =>
      'Adicionar aos candidatos - copiar para uma personagem existente';

  @override
  String get galleryAddToCollectionTooltip =>
      'Adicionar à coleção - escolher um valor';

  @override
  String get galleryAcceptTooltip => 'Aceitar - enviar para a etapa 2';

  @override
  String get galleryDeleteSelected => 'Eliminar os selecionados';

  @override
  String get galleryFilterImage => 'Imagem';

  @override
  String get galleryFilterVideo => 'Vídeo';

  @override
  String get galleryFilterFavorite => 'Favorito';

  @override
  String galleryQueuedAt(Object position) {
    return 'em fila $position';
  }

  @override
  String get galleryEmpty => 'Ainda nada foi gerado';

  @override
  String get galleryEmptyHint => 'Pode começar no separador Gerar';

  @override
  String get galleryDeleteOneConfirm =>
      'Eliminar esta geração e o seu ficheiro?';

  @override
  String get galleryAcceptOneCbn =>
      'Passa para a etapa \"Recebidos\" da linha CBN (jpg + etiquetas EXIF).\n\nQue classificação?';

  @override
  String get galleryAcceptOneJigsaw =>
      'Passa para a etapa 2 (jpg + etiquetas EXIF).\n\nQue classificação?';

  @override
  String get galleryAccepted =>
      'Aceite - a etiquetar, acompanhe no separador \"Linha\"';

  @override
  String get galleryRejected => 'Rejeitado';

  @override
  String get galleryEditBody =>
      'Esta imagem passa a ser a origem; o motor de edição (Qwen Image Edit, mantém a identidade) inicia uma nova geração. O que deve mudar?';

  @override
  String get galleryEditPromptLabel => 'Prompt adicional';

  @override
  String get galleryEditPromptHint =>
      'ex.: change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued =>
      'Edição adicionada à fila - o resultado aparece em Gerados';

  @override
  String get galleryEditTooltip =>
      'Editar - nova geração com o motor de edição';

  @override
  String galleryPoolInfo(Object name) {
    return 'grupo $name';
  }

  @override
  String get genPromptUnchanged =>
      'O prompt não mudou (o LLM local não respondeu)';

  @override
  String get genPromptWritten => 'Prompt escrito';

  @override
  String get commonUndo => 'Anular';

  @override
  String get genVariantFailed =>
      'Não foi possível gerar variantes (o LLM local não respondeu)';

  @override
  String get genPickVariant => 'Escolher uma variante';

  @override
  String get genEnrich => 'Enriquecer';

  @override
  String get genFix => 'Corrigir';

  @override
  String get genVariant => 'Variante';

  @override
  String get genFileUnreadable => 'Não foi possível ler o ficheiro';

  @override
  String get genPromptEmpty => 'O prompt não pode ficar vazio';

  @override
  String genMissingInputs(Object inputs) {
    return 'Entrada em falta: $inputs';
  }

  @override
  String get genNeedsImagePick =>
      'Esta tarefa precisa de uma imagem de entrada - escolha uma das geradas';

  @override
  String get genNeedsImage => 'Esta tarefa precisa de uma imagem de entrada';

  @override
  String genQueuedCount(Object count) {
    return '$count trabalhos adicionados à fila';
  }

  @override
  String get genQueued => 'Adicionado à fila';

  @override
  String genQueueBadge(Object count) {
    return '$count em fila';
  }

  @override
  String get genComfyOffBody =>
      'O ComfyUI está desligado. Os trabalhos entram na fila mas não arrancam - é preciso iniciá-lo no computador.';

  @override
  String get genTask => 'Tarefa';

  @override
  String get genWorkflowInputs => 'Entradas do fluxo de trabalho';

  @override
  String get genInputImage => 'Imagem de entrada';

  @override
  String get genPositive1 => 'Prompt positivo 1 - assunto';

  @override
  String get genPositive1Hint => 'ex.: police officer';

  @override
  String get genPositive2 => 'Prompt positivo 2 - modelo';

  @override
  String genPositive2Help(Object marker) {
    return '$marker é substituído pelo primeiro prompt. Pode ficar vazio.';
  }

  @override
  String get genFinalPrompt => 'Prompt a enviar';

  @override
  String get genNegative => 'Prompt negativo';

  @override
  String get genTurboHint => 'modo rápido';

  @override
  String genDurationSeconds(Object seconds) {
    return 'Duração: $seconds segundos';
  }

  @override
  String genCount(Object count) {
    return 'Quantidade: $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'Tamanho: $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'Tamanho: $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'ADICIONAR À FILA';

  @override
  String get genFootnote =>
      'Os trabalhos são gerados um a seguir ao outro. Pode acompanhá-los no separador Fila.';

  @override
  String get genDetailsTitle =>
      'Detalhes - podem ficar vazios, os bloqueados não são baralhados';

  @override
  String genRandomGenerate(Object count) {
    return 'Gerar ao acaso  $count';
  }

  @override
  String get genLockedTooltip => 'bloqueado - fica fixo ao baralhar';

  @override
  String get genOptionsEmpty => 'A lista de opções está vazia';

  @override
  String get genOptional => 'opcional';

  @override
  String get genUploading => 'a enviar...';

  @override
  String get genNotSelected => 'não selecionado';

  @override
  String get genFromGallery => 'Da galeria';

  @override
  String get genFromFile => 'De ficheiro';

  @override
  String get genNoSource =>
      'Não há nenhuma geração que sirva de entrada. Gere primeiro uma imagem.';

  @override
  String genPickerTitle(Object slot) {
    return '$slot - escolher em Gerados';
  }

  @override
  String get genPickerSearch => 'procurar nos prompts';

  @override
  String get genPickerEmpty => 'Não há gerações concluídas deste tipo.';

  @override
  String optionsFileMissing(Object items) {
    return 'Em falta no ficheiro de opções: $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (sem definições de campo)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'Não foi possível ler o ficheiro de opções: $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return 'Não foi possível ler o ficheiro de opções de $name: $error';
  }

  @override
  String get fieldLocation => 'Local';

  @override
  String get fieldEra => 'Época / estética';

  @override
  String get fieldWeather => 'Tempo';

  @override
  String get fieldWeatherLight => 'Tempo / luz';

  @override
  String get fieldJob => 'Profissão';

  @override
  String get fieldFantasy => 'Fantasia';

  @override
  String get fieldOutfitColor => 'Cor do traje';

  @override
  String get fieldOutfit => 'Traje';

  @override
  String get fieldHair => 'Cabelo';

  @override
  String get fieldHairColor => 'Cor do cabelo';

  @override
  String get fieldHairstyle => 'Penteado';

  @override
  String get fieldEyes => 'Olhos';

  @override
  String get fieldRace => 'Raça';

  @override
  String get fieldExpression => 'Expressão';

  @override
  String get fieldPose => 'Pose';

  @override
  String get fieldAngle => 'Ângulo';

  @override
  String get fieldStyle => 'Estilo';

  @override
  String get fieldMood => 'Ambiente';

  @override
  String get fieldColor => 'Cor';

  @override
  String get fieldCreature => 'Criatura';

  @override
  String get fieldClass => 'Classe';

  @override
  String get fieldAge => 'Idade';

  @override
  String get fieldOrigin => 'Origem';

  @override
  String get fieldBody => 'Corpo';

  @override
  String get fieldSkin => 'Pele';

  @override
  String get fieldFace => 'Rosto';

  @override
  String get fieldGesture => 'Gesto';

  @override
  String get cardNotReady => 'O endpoint do servidor ainda não está pronto';

  @override
  String get cardKindNormal => 'Normal';

  @override
  String get cardKindDealer => 'Croupier';

  @override
  String get cardStagePushed => 'publicado';

  @override
  String get cardStageWebp => 'webp pronto';

  @override
  String get cardStageVideo => 'vídeo pronto';

  @override
  String get cardStageStill => 'still pronto';

  @override
  String get cardStageEmpty => 'vazio';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (verificar)';
  }

  @override
  String get cardVideoIntro =>
      'Primeiro fotograma = último (ciclo). A câmara fica bloqueada - o enquadramento, a escala e o fundo não mudam. O resultado vai primeiro para o GRUPO; se escolher uma etiqueta, também é atribuído a ela.';

  @override
  String get cardVideoTemplate => 'Modelo (preenche o texto)';

  @override
  String get cardVideoMotion => 'Frase de movimento (o prompt enviado)';

  @override
  String get cardVideoMotionHelp =>
      'Descreva um movimento visível; no fim deve voltar à pose inicial';

  @override
  String get cardVideoAssignTag => 'Atribuir a etiqueta';

  @override
  String get cardVideoPoolOnly => '(só para o grupo - atribuo depois)';

  @override
  String get cardVideoNewTag => 'Nova etiqueta...';

  @override
  String get cardVideoNewTagName => 'Nome da nova etiqueta';

  @override
  String get cardTagHint => 'ex.: victory';

  @override
  String get cardGestureTitle => 'Animação - escolher um gesto';

  @override
  String get cardGestureIntro =>
      'MiniMax H3: idle 6 s, victory 2 s. A câmara fica bloqueada - o enquadramento, a escala e o fundo não mudam.';

  @override
  String get cardGestureCustom => 'Movimento personalizado';

  @override
  String get cardGestureCustomHint => 'ex.: leve balanço de ancas, pés fixos';

  @override
  String get cardGestureCustomHelp =>
      'Uma frase curta de movimento - a câmara continua bloqueada';

  @override
  String get cardCutTitle => '3 WebP - modo de recorte';

  @override
  String get cardCutHybrid =>
      'Masters verdes antigos do Grok - chroma + SAM juntos';

  @override
  String get cardCutSam => 'Predefinição - só SAM3, fundo cinzento-claro liso';

  @override
  String get cardCutAction => 'Recortar';

  @override
  String cardEditTitle(Object name) {
    return 'Editar - $name';
  }

  @override
  String get cardEditSentence => 'Frase de correção';

  @override
  String get cardEditSentenceHint => 'ex.: encurtar o cabelo / tirar as luvas';

  @override
  String get cardEditBody =>
      'O still aceite é editado com esta frase; a identidade, a pose e o fundo são mantidos. A nova imagem é aceite automaticamente.';

  @override
  String get cardEditUnrestricted => 'Edição sem restrições (NSFW LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Ligue se o Qwen recusar - MCNL LoRA, 20 passos, um pouco mais lento';

  @override
  String cardQueuedJobs(Object count) {
    return 'Adicionado à fila ($count trabalhos) - acompanhe no separador Fila';
  }

  @override
  String get cardQueued => 'Adicionado à fila - acompanhe no separador Fila';

  @override
  String cardQueuedOp(Object op) {
    return 'Adicionado à fila (op $op) - acompanhe no separador Fila';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - em breve';
  }

  @override
  String get cardSoonBody =>
      'Os endpoints de cartas no servidor ainda não estão abertos. Este ecrã começa a funcionar sozinho quando estiverem.';

  @override
  String get cardNewCollection => 'Nova coleção';

  @override
  String get cardIdLabel => 'Identificador (id)';

  @override
  String get cardIdHintCollection => 'ex.: police_royale';

  @override
  String get commonName => 'Nome';

  @override
  String get cardNameHintCollection => 'ex.: Police Royale';

  @override
  String get cardPickPreset => 'Escolher uma carta predefinida (opcional)';

  @override
  String get cardThemeHint =>
      'ex.: sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      'Fórmula: identidade + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'Jokers (2)';

  @override
  String get cardJokersHint => '15 valores em vez de 13';

  @override
  String get cardNewCollectionNote =>
      'Entra na fila 1 still por valor (rotação de pele / cabelo / traje / pose). Não se pede confirmação - afine com ✎ / ↻.';

  @override
  String get cardIdNameRequired =>
      'O identificador e o nome não podem ficar vazios';

  @override
  String get cardNewDealer => 'Novo croupier';

  @override
  String get cardIdHintDealer => 'ex.: scarlett';

  @override
  String get cardNameHintDealer => 'ex.: Scarlett';

  @override
  String get cardDealerTheme => 'Tema / traje';

  @override
  String get cardDealerThemeHint =>
      'ex.: colete de casino e laço, vestido vermelho noir';

  @override
  String get cardDealerNote =>
      'O croupier é gerado em plano médio (mãos na mesa, a olhar para a câmara). Não há valor - o item único passa pelas quatro etapas.';

  @override
  String get cardNightPickGesture => 'Modo noturno - escolher um gesto';

  @override
  String get cardNightMode => 'Modo noturno';

  @override
  String cardNightBody(Object gesture) {
    return 'Todas as cartas E os croupiers são reanimados: still atual -> LTX-2.5 i2v ($gesture) -> recorte SAM -> sheet.\n\nDemora muito e tudo entra na fila. NÃO é feito push.';
  }

  @override
  String get cardRestillTitle => 'Pôr os fundos a cinzento';

  @override
  String get cardRestillBody =>
      'O fundo do still de todas as cartas E croupiers passa a cinzento-claro liso (a mulher fica igual). O original é guardado como still_green.png; os que já são cinzentos são ignorados.\n\nNão é gerado vídeo.';

  @override
  String get cardManifestPreview => 'Pré-visualização do manifesto';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return '$collections coleções, $dealers croupiers';
  }

  @override
  String get cardManifestNote =>
      'O ficheiro de manifesto é escrito durante o PUSH (primeiro os ficheiros, depois o manifesto). Isto é só uma pré-visualização.';

  @override
  String get cardCollectionCardSettings => 'Carta de coleção (definições)';

  @override
  String get cardCollectionCardSettingsHint =>
      'tema, 16 espaços, modelo, retoque do rosto';

  @override
  String get cardReanimate => 'Reanimar';

  @override
  String get cardReanimateHint => 'still -> i2v -> recorte (esta coleção)';

  @override
  String get cardRealify => 'Anime -> realista (coleção)';

  @override
  String get cardRealifyHint =>
      'cada still passa a foto realista com o edit_qwen';

  @override
  String get cardDeleteCollection => 'Eliminar coleção';

  @override
  String get cardDeleteCollectionHint =>
      'a pasta é eliminada com todas as cartas - não pode ser desfeito';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'Eliminar coleção - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'Eliminar croupier - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'A pasta da coleção é eliminada com todos os ficheiros.\n\nNÃO PODE SER DESFEITO. Os ficheiros já publicados no R2 ficam no bucket.';

  @override
  String get cardDeleteDealerBody =>
      'A pasta do croupier é eliminada com todos os ficheiros.\n\nNÃO PODE SER DESFEITO. Os ficheiros já publicados no R2 ficam no bucket.';

  @override
  String cardDeletedNamed(Object name) {
    return '$name eliminado';
  }

  @override
  String get cardDealerCardSettings => 'Carta de croupier (definições)';

  @override
  String get cardDealerCardSettingsHint =>
      'tema, modelo de prompt, modelo, retoque do rosto';

  @override
  String get cardDeleteDealer => 'Eliminar croupier';

  @override
  String get cardDeleteDealerHint =>
      'a pasta é eliminada com todos os ficheiros - não pode ser desfeito';

  @override
  String get cardFlowTitle => 'Linha de Cartas';

  @override
  String get cardBulkActions => 'Ações em lote';

  @override
  String get cardNightMenu => 'Modo noturno: reanimar tudo';

  @override
  String get cardRestillMenu => 'Pôr os fundos a cinzento (todos)';

  @override
  String get cardManifestMenu => 'Ver manifesto';

  @override
  String get cardDealers => 'Croupiers';

  @override
  String get cardEmptyCollections =>
      'Ainda não há coleções.\n\nCom \"+ Nova coleção\" indique identificador, nome e tema - entra na fila 1 still por valor para 13 (ou 15) valores, e depois vêm as etapas 2 Video e 3 WebP.';

  @override
  String get cardEmptyDealers =>
      'Ainda não há croupiers.\n\nCom \"+ Novo croupier\" indique nome, tema e gesto - é gerado um único item em plano médio que passa pelas quatro etapas.';

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
    return 'Para cada carta são geradas 2 animações, atribuídas às suas etiquetas:\n• idle - 6 s, um gesto controlado\n• victory - 2 s, uma breve celebração dentro do enquadramento\n$total vídeos no total; os antigos ficam no grupo.';
  }

  @override
  String get cardEditNeedsOne =>
      'A edição é para um só valor - selecione uma carta';

  @override
  String cardPushTitle(Object name) {
    return 'Push - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'Os ficheiros sheet e thumb são enviados para o R2 (cards) e depois o manifesto é escrito. Neste momento está pronto o webp de $ready/$total valores.\n\nÉ uma PUBLICAÇÃO e NÃO PODE SER DESFEITA.';
  }

  @override
  String get cardPushQueued =>
      'Push adicionado à fila - acompanhe no separador Fila';

  @override
  String get cardCollectionCardTooltip =>
      'Carta de coleção - tema, 16 espaços, modelo, retoque do rosto';

  @override
  String get commonMore => 'Mais';

  @override
  String get cardNoThemeTap => 'Sem tema - toque: Carta de coleção';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nCarta de coleção: toque (tema, 16 espaços, modelo, retoque do rosto)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'A pasta da coleção é eliminada com todas as cartas ($stills stills).\n\nNÃO PODE SER DESFEITO. Os ficheiros já publicados no R2 ficam no bucket.';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'A pasta da coleção é eliminada com todas as cartas ($stills stills, $pushed publicadas).\n\nNÃO PODE SER DESFEITO. Os ficheiros já publicados no R2 ficam no bucket.';
  }

  @override
  String get cardClearCards => 'Limpar cartas';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - still, candidatos, vídeo e webp são eliminados; o valor fica vazio (gera-se de novo com \"1 Still\").';
  }

  @override
  String cardsCleared(Object count) {
    return '$count cartas limpas';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count cartas não puderam ser limpas';
  }

  @override
  String get cardGenerateStill => 'Gerar 1 Still';

  @override
  String get cardGenerateVideo => 'Gerar 2 Video';

  @override
  String get cardGenerateWebp => 'Gerar 3 WebP';

  @override
  String get cardBackUpper => 'VERSO';

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
    return 'Não há $asset';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return 'Eliminar $asset?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'Só o vídeo desta etiqueta é eliminado; a cópia no grupo, o still e o webp ficam.';

  @override
  String get cardAssetDeleteSheetBody =>
      'Só o sheet.webp, o thumb e os fotogramas recortados são eliminados; o vídeo e o still ficam.';

  @override
  String get cardAssetDeleteStillBody =>
      'Só o still selecionado é eliminado; os candidatos, o vídeo e o webp ficam.';

  @override
  String get cardPoolDelete => 'Eliminar do grupo';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id é eliminado do grupo. As cópias atribuídas a etiquetas ($tags) ficam.';
  }

  @override
  String get cardNone => 'nenhuma';

  @override
  String get cardNewAnimTag => 'Nova etiqueta de animação';

  @override
  String get cardNewAnimTagHelp =>
      'O jogo lê-a por este nome (idle, wink, victory ...)';

  @override
  String get cardUnassigned => 'não atribuído';

  @override
  String cardAssignedTo(Object tags) {
    return 'atribuído: $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return 'Atribuir: $name';
  }

  @override
  String get cardAssignNewTag => 'Atribuir a uma etiqueta nova...';

  @override
  String get cardAnimReady => 'vídeo + webp prontos';

  @override
  String get cardAnimVideoOnly => 'tem vídeo, falta o webp';

  @override
  String get cardPoolEmpty => 'Não há vídeos no grupo - primeiro \"2 Video\"';

  @override
  String get cardDeleteVideoKeepTag => 'Eliminar o vídeo (a etiqueta fica)';

  @override
  String get cardDeleteSheet => 'Eliminar WebP / recorte';

  @override
  String get cardDeleteTag => 'Eliminar a etiqueta (com vídeo + webp)';

  @override
  String cardVideosHeader(Object count) {
    return 'Vídeos ($count) - toque = atribuir / ver / eliminar';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return 'A pasta de $name é eliminada com todos os ficheiros. NÃO PODE SER DESFEITO.';
  }

  @override
  String get cardClearCard => 'Limpar carta';

  @override
  String cardClearCardBody(Object name) {
    return '$name: still, candidatos, vídeo, webp e animações são eliminados; o valor fica vazio (gera-se de novo com \"1 Still\").';
  }

  @override
  String get cardClearCardTooltip => 'Limpar carta (o valor fica vazio)';

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
  String get cardDeleteStill => 'Eliminar o still';

  @override
  String get cardNoVideo => 'Não há vídeo - gere-o com \"2 Video\"';

  @override
  String get cardNoCut => 'Não há recorte - gere-o com \"3 WebP\"';

  @override
  String get cardCutFrameFailed => 'Não foi possível ler o fotograma recortado';

  @override
  String get cardNoStill => 'Não há still - gere-o com \"1 Still\"';

  @override
  String get cardStillFailed => 'Não foi possível ler o still';

  @override
  String cardPromptTitleAge(Object age) {
    return 'Prompt  ·  $age anos';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - enquadramento desviado / zoom / máscara partida. Gere de novo o vídeo ou o recorte.';

  @override
  String get cardAnimsHeader =>
      'Animações - toque = selecionar, toque longo = atribuir / eliminar';

  @override
  String cardAnimOpened(Object tag) {
    return '\"$tag\" criada - gere-a com 2 Video ou atribua a partir do grupo';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return 'Escolha um vídeo do grupo para \"$tag\"';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return 'Candidatos ($count) - toque = selecionar';
  }

  @override
  String get cardCandidatePicked =>
      'O candidato passou a ser o still selecionado';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step: $error';
  }
}

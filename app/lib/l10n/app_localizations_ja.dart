// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get about => 'アプリについて';

  @override
  String get aboutApp => 'アプリ';

  @override
  String actionTriggered(Object action) {
    return '$action をトリガーしました';
  }

  @override
  String get add => '追加';

  @override
  String agentLabelWith(Object agent) {
    return 'エージェント: $agent';
  }

  @override
  String get agentLocal => 'ローカル';

  @override
  String get agentNone => 'なし';

  @override
  String get agentRunsOnServer => 'エージェントはプロジェクトレベルのアクセス権でサーバー上で実行されます';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return '$agent AI を \"$title\" に対してトリガーしました';
  }

  @override
  String get aiAgent => 'AIエージェント';

  @override
  String get aiAgentUpdated => 'AIエージェントを更新しました';

  @override
  String get aiResponse => 'AIの応答';

  @override
  String get allApps => 'すべてのアプリ';

  @override
  String get allAppsCompletedOrPostponed => 'すべてのアプリが完了または保留になっています';

  @override
  String get allAppsHaveAutomations => 'すべてのアプリに自動化が設定済みです';

  @override
  String get allAppsHint => 'すべてのアプリ';

  @override
  String get allPendingBlocked => '保留中の項目はすべて依存関係でブロックされています';

  @override
  String get apiConnection => 'API接続';

  @override
  String get apiUrlSaved => 'API URLを保存しました';

  @override
  String get appCreated => 'アプリを作成しました!';

  @override
  String get appDetail => 'アプリ詳細';

  @override
  String get appFallback => 'アプリ';

  @override
  String get appNameHint => 'アプリ名 (例: My Game)';

  @override
  String get appStatusBuilding => 'ビルド中';

  @override
  String get appStatusDeploying => 'デプロイ中';

  @override
  String get appStatusError => 'エラー';

  @override
  String get appStatusFixing => '修正中';

  @override
  String get appStatusIdle => 'アイドル';

  @override
  String get appStatusPublished => '公開済み';

  @override
  String get appStatusQueued => 'キュー待ち';

  @override
  String get appStatusUploading => 'アップロード中';

  @override
  String get appStatusWorking => '作業中';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc => 'Google Playへのデプロイに対応したモバイル/デスクトップアプリ';

  @override
  String get appTypeGodotDesc => '書き出しターゲット (Windows、Android、Web) を持つゲームプロジェクト';

  @override
  String get appTypePhaserDesc =>
      'Phaser 3 + TypeScript製ゲームをCapacitorでAndroid AABにラップ';

  @override
  String get appTypePythonDesc => 'スクリプトランナーとpip管理を備えたPythonプロジェクト';

  @override
  String get appTypeWebDesc => '静的ホスティングへのデプロイに対応したWebアプリ';

  @override
  String get apps => 'アプリ';

  @override
  String get archivedLabel => 'アーカイブ済み';

  @override
  String get artAndAssets => 'アート＆アセット';

  @override
  String get artBible => 'アートバイブル';

  @override
  String get artBibleCardSubtitle => 'ビジュアルアイデンティティの基準ドキュメント';

  @override
  String get artBibleHint => 'アイデンティティステートメント、パレット (hex)、タイポグラフィ、禁止事項、技術仕様...';

  @override
  String get artBibleSaved => 'アートバイブルを保存しました';

  @override
  String get artBibleShort => 'アートバイブル';

  @override
  String get artBibleSubtitle =>
      'ビジュアルアイデンティティの基準 — パレット、タイポグラフィ、スタイルの禁止事項。すべてのアセットタスクがこれを参照します。';

  @override
  String get artBibleTaskCreated => 'アートバイブルタスクを作成しました';

  @override
  String artBibleTitle(Object app) {
    return 'アートバイブル - $app';
  }

  @override
  String get askAQuestionHint => '質問を入力...';

  @override
  String get askAgent => 'エージェントに質問';

  @override
  String get askAnythingAboutYourApps => 'アプリについて何でも質問してください';

  @override
  String get assetAudit => 'アセット監査';

  @override
  String get assetAuditSubtitle => '壊れた参照、孤立ファイル、プレースホルダー';

  @override
  String get assetAuditTaskCreated => 'アセット監査タスクを作成しました';

  @override
  String get assetSpecTaskCreated => 'アセット仕様タスクを作成しました';

  @override
  String get assetSpecs => 'アセット仕様';

  @override
  String get assetSpecsSubtitle => 'バイブルに基づくアセットごとのプロンプト';

  @override
  String get attachments => '添付ファイル';

  @override
  String attachmentsCount(Object count) {
    return '添付ファイル ($count)';
  }

  @override
  String get automationCreated => '自動化を作成しました';

  @override
  String get automationStateStarted => '開始';

  @override
  String get automationStateStopped => '停止';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => '自動化を更新しました';

  @override
  String get back => '戻る';

  @override
  String get backend => 'バックエンド';

  @override
  String get balanceCheck => 'バランスチェック';

  @override
  String get balanceCheckSubtitle => '経済、進行、報酬';

  @override
  String get balanceCheckTaskCreated => 'バランスチェックタスクを作成しました';

  @override
  String batchRunError(Object error) {
    return 'バッチ実行中のエラー: $error';
  }

  @override
  String blockedByList(Object ids) {
    return '$ids によってブロック中';
  }

  @override
  String blockedByTask(Object id) {
    return '#$id によってブロック中';
  }

  @override
  String blockedCountLabel(Object count) {
    return '$count 件ブロック中';
  }

  @override
  String blockerNotInList(Object id) {
    return 'タスク #$id は現在のリストにありません (アーカイブ済みまたは削除済み)';
  }

  @override
  String get brainstormAndCreate => 'ブレインストーム＆作成';

  @override
  String get brainstormConceptHint =>
      'コンセプトの種 (例: \"ant colony idle game\"、\"puzzle with gravity\")';

  @override
  String get brainstormCreated => 'ブレインストームタスク付きでプロジェクトを作成しました!';

  @override
  String get brainstormDesc =>
      'ブレインストームタスク付きで新しいプロジェクトを作成します。タスクが実行されると、AIが完全なGDDと初期タスクを生成します。';

  @override
  String get brainstormNameHint => 'プロジェクト名 (任意 — AIが提案可能)';

  @override
  String get brainstormNewGame => '新しいゲームをブレインストーム';

  @override
  String get build => 'ビルド';

  @override
  String get buildAndDeploy => 'ビルド＆デプロイ';

  @override
  String get buildCancelled => 'ビルドをキャンセルしました';

  @override
  String get buildFailedLabel => 'ビルド失敗';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'ビルドのポーリングが30分でタイムアウトしました - サーバーログを確認してください';

  @override
  String get buildTarget => 'ビルドターゲット';

  @override
  String get builds => 'ビルド';

  @override
  String builtCount(Object count) {
    return 'ビルド済み ($count)';
  }

  @override
  String get buyMeACoffee => 'コーヒーをおごる';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'コーヒーをおごる  $price';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get cannotReachServer => 'サーバーに接続できません';

  @override
  String cannotReachServerWith(Object error) {
    return 'サーバーに接続できません: $error';
  }

  @override
  String get cannotSaveEmptyArtBible => '空のアートバイブルは保存できません';

  @override
  String get cannotSaveEmptyClaudeMd => '空のCLAUDE.mdは保存できません';

  @override
  String get cannotSaveEmptyDesignDoc => '空の設計ドキュメントは保存できません';

  @override
  String get catBugsCrashes => 'バグ＆クラッシュ';

  @override
  String get catCodeStyle => 'コードスタイル';

  @override
  String get catDeadCode => 'デッドコード';

  @override
  String get catErrorHandling => 'エラー処理';

  @override
  String get catMemory => 'メモリ';

  @override
  String get categoryAccessibility => 'アクセシビリティ';

  @override
  String get categoryBug => 'バグ';

  @override
  String get categoryFeatures => '機能';

  @override
  String get categoryMonetization => 'マネタイズ';

  @override
  String get categoryOther => 'その他';

  @override
  String get categoryPerformance => 'パフォーマンス';

  @override
  String get categorySecurity => 'セキュリティ';

  @override
  String get categorySuggestion => '提案';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count 文字';
  }

  @override
  String get chatHistory => 'チャット履歴';

  @override
  String get chatLogs => 'レポート';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count 件のメッセージ • $date';
  }

  @override
  String get checkBugsCrashes => 'バグ＆クラッシュ';

  @override
  String get checkCodeStyle => 'コードスタイル';

  @override
  String get checkDeadCode => 'デッドコード';

  @override
  String get checkErrorHandling => 'エラー処理';

  @override
  String get checkMemoryLeaks => 'メモリリーク';

  @override
  String get checkPerformanceIssues => 'パフォーマンスの問題';

  @override
  String get checkSecurityVulnerabilities => 'セキュリティの脆弱性';

  @override
  String get checksToRun => '実行するチェック:';

  @override
  String get claudeMdHint => 'プロジェクトの規約、ビルドコマンド、ルール...';

  @override
  String get claudeMdSaved => 'CLAUDE.mdを保存しました';

  @override
  String get claudeMdSubtitle => 'このアプリで作業するAIエージェント向けのプロジェクト指示。';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'クリア';

  @override
  String get clearFilters => 'フィルターをクリア';

  @override
  String get clearMessages => 'メッセージをクリア';

  @override
  String clearMessagesConfirm(Object count) {
    return 'このチャットの$count件のメッセージをすべて削除しますか?';
  }

  @override
  String get close => '閉じる';

  @override
  String get codeCheck => 'コードチェック';

  @override
  String get codeCheckBody => 'AIエージェントがコードをレビューし、指摘事項をIssueとして報告するタスクを作成します。';

  @override
  String get codeCheckRequested => 'コードチェックをリクエストしました';

  @override
  String get codeCheckResults => 'コードチェックの結果';

  @override
  String get codeReview => 'コードレビュー';

  @override
  String get codeReviewSubtitle => 'バグ、クラッシュ、コード品質';

  @override
  String get complete => '完了';

  @override
  String completedCount(Object count) {
    return '完了済み ($count)';
  }

  @override
  String get connectToYourServer => 'サーバーに接続';

  @override
  String get connectYourPhone => 'スマートフォンを接続';

  @override
  String get connectedSuccessfully => '接続に成功しました';

  @override
  String connectedTo(Object server) {
    return '$server に接続しました';
  }

  @override
  String get connecting => '接続中...';

  @override
  String get connectionFailed => '接続に失敗しました';

  @override
  String get connectionSuccessful => '接続に成功しました!';

  @override
  String get connectionTimedOut => '接続がタイムアウトしました';

  @override
  String get consistencyCheck => '整合性チェック';

  @override
  String get consistencyCheckSubtitle => 'GDD ↔ コード ↔ データのずれ';

  @override
  String get consistencyCheckTaskCreated => '整合性チェックタスクを作成しました';

  @override
  String get console => 'コンソール';

  @override
  String get contentAudit => 'コンテンツ監査';

  @override
  String get contentAuditSubtitle => 'レベル、キャラクター、アイテム、テキスト';

  @override
  String get contentAuditTaskCreated => 'コンテンツ監査タスクを作成しました';

  @override
  String get continueLabel => '続ける';

  @override
  String get control => 'コントロール';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label をクリップボードにコピーしました';
  }

  @override
  String get copy => 'コピー';

  @override
  String get copyAiResponse => 'AIの応答をコピー';

  @override
  String get copyDescription => '説明をコピー';

  @override
  String get copyTitle => 'タイトルをコピー';

  @override
  String get copyUrl => 'URLをコピー';

  @override
  String get couldNotDownloadPdf => 'PDFをダウンロードできませんでした';

  @override
  String get couldNotLoadBuildTargets => 'ビルドターゲットを読み込めませんでした';

  @override
  String get couldNotLoadDirectives => '指示を読み込めませんでした';

  @override
  String get couldNotOpenLink => 'リンクを開けませんでした';

  @override
  String couldNotOpenPdf(Object error) {
    return 'PDFを開けませんでした: $error';
  }

  @override
  String get couldNotOpenPicker => 'ピッカーを開けませんでした。';

  @override
  String get create => '作成';

  @override
  String get createApp => 'アプリを作成';

  @override
  String get createFirstApp => '最初のアプリを作成して始めましょう';

  @override
  String get createIssue => 'Issueを作成';

  @override
  String createdAgo(Object time) {
    return '$timeに作成';
  }

  @override
  String get creating => '作成中...';

  @override
  String criticalCount(Object count) {
    return '重大 $count件';
  }

  @override
  String get customAutomationPromptHint => 'カスタム自動化プロンプト...';

  @override
  String get customPrompt => 'カスタムプロンプト';

  @override
  String get dashboard => 'ダッシュボード';

  @override
  String get delete => '削除';

  @override
  String get deleteAutomation => '自動化を削除';

  @override
  String deleteAutomationConfirm(Object app) {
    return '$app の自動化を削除しますか?';
  }

  @override
  String get deleteChat => 'チャットを削除';

  @override
  String get deleteChatConfirm => 'この会話を削除しますか?';

  @override
  String deleteConfirmTitled(Object title) {
    return '\"$title\" を削除しますか?\nこの操作は元に戻せません。';
  }

  @override
  String get deleteFailed => '削除に失敗しました';

  @override
  String get deleteReportBody => 'このレポートとそのスクリーンショットを完全に削除します。';

  @override
  String get deleteReportTitle => 'レポートを削除しますか?';

  @override
  String get deleted => '削除しました';

  @override
  String get dependsOn => '依存先';

  @override
  String get deploy => 'デプロイ';

  @override
  String get deployToProduction => '本番環境にデプロイ';

  @override
  String get deployToProductionBody =>
      'Google Playの全ユーザーに向けてビルド・公開します。\n\n事前にInternal/Betaでテスト済みであることを確認してください。';

  @override
  String get deployToProductionTitle => '本番環境にデプロイしますか?';

  @override
  String get descriptionHint => '説明...';

  @override
  String get designDoc => '設計ドキュメント';

  @override
  String get designDocHint => 'アプリのビジョン、機能、目標を記述してください...';

  @override
  String get designDocSaved => '設計ドキュメントを保存しました';

  @override
  String get designDocShort => '設計ドキュメント';

  @override
  String get designDocSubtitle => 'AIはこのアプリでのすべての作業においてこれをコンテキストとして使用します。';

  @override
  String designDocTitle(Object app) {
    return '設計ドキュメント - $app';
  }

  @override
  String get designDocument => '設計ドキュメント';

  @override
  String get designReview => 'デザインレビュー';

  @override
  String get designReviewSubtitle => 'GDD、ゲームメカニクス、UX監査';

  @override
  String get designReviewTaskCreated => 'デザインレビュータスクを作成しました';

  @override
  String get details => '詳細';

  @override
  String get detectingServer => 'サーバーを検出中...';

  @override
  String get developer => '開発者';

  @override
  String get directServerUrlLan => 'サーバーURL直接指定 (LAN)';

  @override
  String get directiveHistory => '指示履歴';

  @override
  String get dismiss => '閉じる';

  @override
  String get display => '表示';

  @override
  String get doIt => '実行する';

  @override
  String get done => '完了';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total 完了';
  }

  @override
  String durationLabelWith(Object seconds) {
    return '所要時間: $seconds秒';
  }

  @override
  String get edit => '編集';

  @override
  String editNamed(Object label) {
    return '$label を編集';
  }

  @override
  String editTitleNamed(Object app) {
    return '編集: $app';
  }

  @override
  String get editWorkerUrl => 'Worker URLを編集';

  @override
  String get engine => 'エンジン';

  @override
  String engineChanged(Object previous, Object current) {
    return 'エンジンを変更しました: $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'エンジンを確認しました: $engine';
  }

  @override
  String get engineDetectionFailed => 'エンジンの検出に失敗しました';

  @override
  String get enhance => '強化';

  @override
  String get enhanceConfirmBody => 'AIがドキュメントを書き直します。この操作は元に戻せません。';

  @override
  String enhanceConfirmTitle(Object label) {
    return '$label を強化しますか?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return '$label の強化エラー: $error';
  }

  @override
  String enhanceStarted(Object label) {
    return 'サーバーで$labelの強化を開始しました...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label の強化に成功しました';
  }

  @override
  String get enhancementFailed => '強化に失敗しました';

  @override
  String get enterConceptOrName => 'コンセプトまたはプロジェクト名を入力してください';

  @override
  String get enterServerUrlDesc => 'Auto Game BuilderサーバーのURLを入力してください';

  @override
  String get enterUrlInPhoneApp => 'リモート接続するには、このURLをスマートフォンアプリに入力してください';

  @override
  String get enterValidUrl => '有効なURLを入力してください (例: http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc => 'リモート接続するにはWorker URLを入力してください';

  @override
  String errorWithMessage(Object error) {
    return 'エラー: $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return '$minutes分ごと';
  }

  @override
  String exitLabelWith(Object code) {
    return '終了コード: $code';
  }

  @override
  String get expandFoldersOrCreate => '下のフォルダを展開するか、新しいアプリを作成してください';

  @override
  String get failed => '失敗';

  @override
  String failedCountLabel(Object count) {
    return '$count 件失敗';
  }

  @override
  String get failedToBrainstorm => 'ブレインストームに失敗しました';

  @override
  String get failedToCreateApp => 'アプリの作成に失敗しました';

  @override
  String get failedToCreateItem => '項目の作成に失敗しました';

  @override
  String get failedToCreateTestTask => 'テストタスクの作成に失敗しました';

  @override
  String get failedToDelete => '削除に失敗しました';

  @override
  String get failedToLoadApp => 'アプリの読み込みに失敗しました';

  @override
  String get failedToLoadAutomations => '自動化の読み込みに失敗しました';

  @override
  String get failedToLoadLogs => 'ログの読み込みに失敗しました';

  @override
  String get failedToLoadTasks => 'タスクの読み込みに失敗しました';

  @override
  String failedToLoadWithError(Object error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String get failedToRefreshApp => 'アプリの更新に失敗しました';

  @override
  String get failedToRequestCodeCheck => 'コードチェックのリクエストに失敗しました';

  @override
  String get failedToRequestIdeas => 'アイデアのリクエストに失敗しました';

  @override
  String get failedToReset => 'リセットに失敗しました';

  @override
  String get failedToRunTask => 'タスクの実行に失敗しました';

  @override
  String failedToSave(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get failedToStartReupload => '再アップロードの開始に失敗しました';

  @override
  String failedToStartServer(Object error) {
    return 'サーバーの起動に失敗しました: $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return '開始に失敗しました: $error';
  }

  @override
  String failedToTrigger(Object action) {
    return '$action のトリガーに失敗しました';
  }

  @override
  String get failedToTriggerRun => '実行のトリガーに失敗しました';

  @override
  String get failedToUpdate => '更新に失敗しました';

  @override
  String get failedToUpdateAiAgent => 'AIエージェントの更新に失敗しました';

  @override
  String get failedToUpdateMcp => 'MCPの更新に失敗しました';

  @override
  String get favoritesOnly => 'お気に入りのみ';

  @override
  String get feedback => 'フィードバック';

  @override
  String fileTooLarge(Object max, Object files) {
    return '大きすぎます (最大${max}MB): $files';
  }

  @override
  String get filterAll => 'すべて';

  @override
  String get filterClosed => 'クローズ';

  @override
  String get filterOpen => 'オープン';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の指摘',
      one: '1 件の指摘',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return '$timeに完了';
  }

  @override
  String finishedFailedAgo(Object time) {
    return '$timeに失敗';
  }

  @override
  String forceRefreshFailed(Object error) {
    return '強制更新に失敗しました: $error';
  }

  @override
  String get forceRefreshTooltip => 'サーバーから強制的に更新 (ローカルキャッシュをクリア)';

  @override
  String get fullAutoMode => 'フルオートモード';

  @override
  String get fullAutoModeOn => 'AIがタスクを読み取り、修正し、新しいアイデアを生成することを繰り返します';

  @override
  String get generate => '生成';

  @override
  String get generateIdeas => 'アイデアを生成';

  @override
  String get generateIdeasHint => '例: \"UIを改善するアイデア\"';

  @override
  String get genre => 'ジャンル';

  @override
  String get genreAction => 'アクション';

  @override
  String get genreAny => '指定なし';

  @override
  String get genreArcade => 'アーケード';

  @override
  String get genreCardGame => 'カードゲーム';

  @override
  String get genreIdleClicker => '放置/クリッカー';

  @override
  String get genrePuzzle => 'パズル';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'シミュレーション';

  @override
  String get genreStrategy => 'ストラテジー';

  @override
  String get genreTowerDefense => 'タワーディフェンス';

  @override
  String get getStarted => 'はじめる';

  @override
  String get googleAccount => 'Googleアカウント';

  @override
  String get hide => '非表示';

  @override
  String highCount(Object count) {
    return '高 $count件';
  }

  @override
  String get ideaGenerationRequested => 'アイデア生成をリクエストしました';

  @override
  String get installed => 'インストール済み';

  @override
  String get intervalMinLabel => '間隔 (分): ';

  @override
  String get invalidQrData => '無効なQRコードデータです';

  @override
  String get issueCreated => 'Issueを作成しました';

  @override
  String get issueTitleHint => 'Issueのタイトル';

  @override
  String get issues => 'Issue';

  @override
  String get itemCreated => '項目を作成しました';

  @override
  String get justNow => 'たった今';

  @override
  String get language => '言語';

  @override
  String get later => '後で';

  @override
  String get links => 'リンク';

  @override
  String get loginTagline => 'どこからでもゲームプロジェクトを管理';

  @override
  String get logs => 'ログ';

  @override
  String get maintenanceOnly => 'メンテナンスのみ';

  @override
  String get markAsCompleted => '完了にする';

  @override
  String get markComplete => '完了にする';

  @override
  String markCompleteConfirm(Object title) {
    return '\"$title\" を完了にしますか?';
  }

  @override
  String get markedAsCompleted => '完了にしました';

  @override
  String maxMinutes(Object minutes) {
    return '最大$minutes分';
  }

  @override
  String get maxSessionMinLabel => '最大セッション (分): ';

  @override
  String get mcpConfiguredPerApp => 'MCPサーバーはアプリ詳細ページでアプリごとに設定します。';

  @override
  String get mcpServers => 'MCPサーバー';

  @override
  String mcpServersActive(Object count) {
    return 'MCPサーバー ($count件有効)';
  }

  @override
  String get mcpServersDesc => 'このアプリのすべてのAI実行で利用可能なツールサーバー';

  @override
  String mediumCount(Object count) {
    return '中 $count件';
  }

  @override
  String get moveBackToActive => 'アクティブに戻す';

  @override
  String get moveToCompletedFolder => '完了フォルダに移動';

  @override
  String get nameIsRequired => '名前は必須です';

  @override
  String get needHelpSettingUp => 'セットアップにお困りですか?';

  @override
  String get newApp => '新規アプリ';

  @override
  String get newAutomation => '新規自動化';

  @override
  String get newChat => '新規チャット';

  @override
  String get newItem => '新規項目';

  @override
  String get newPrompt => '新規プロンプト';

  @override
  String newReportsCount(Object count) {
    return '新しいレポート $count件';
  }

  @override
  String get nextRunIn => '次回実行まで';

  @override
  String get noApiKeyFound => 'APIキーが見つかりません — サーバーを再起動して生成してください';

  @override
  String get noAppsMatch => '一致するアプリがありません';

  @override
  String get noAppsYet => 'アプリはまだありません';

  @override
  String get noArtBibleYet =>
      'アートバイブルはまだありません。「追加」をタップしてビジュアルアイデンティティ (パレット、タイポグラフィ、禁止事項) を定義してください。';

  @override
  String get noAutomationsMatchFilters => 'フィルターに一致する自動化がありません';

  @override
  String get noAutomationsYet => '自動化はまだありません';

  @override
  String noBuildTargetsFor(Object type) {
    return '$type プロジェクトのビルドターゲットがありません。';
  }

  @override
  String get noBuildsYet => 'ビルドはまだありません';

  @override
  String get noChatsYet => 'チャットはまだありません';

  @override
  String get noClaudeMdYet =>
      'CLAUDE.mdはまだありません。「追加」をタップしてAI向けのプロジェクト指示を設定してください。';

  @override
  String get noDesignDocYet => '設計ドキュメントはまだありません。「追加」をタップしてアプリのビジョンを記述してください。';

  @override
  String get noDirectivesYet => '指示はまだ送信されていません。';

  @override
  String get noFavoritePrompts => 'お気に入りのプロンプトはまだありません';

  @override
  String get noItemsFound => '項目が見つかりません';

  @override
  String get noLogsFound => 'ログが見つかりません';

  @override
  String get noNewReports => '新しいレポートはありません';

  @override
  String get noOpenReports => '未対応のレポートはありません';

  @override
  String get noOpenTasksToDependOn => '依存できる未完了のタスクがありません';

  @override
  String get noPendingItems => '作業する保留中の項目がありません';

  @override
  String get noPromptHistory => 'プロンプト履歴はまだありません。\nアイデアを生成すると履歴が作成されます。';

  @override
  String get noReportsHere => 'ここにはレポートがありません';

  @override
  String get noWorkerUrlDetected =>
      'settings.jsonにWorker URLが見つかりません。\nリモートアクセスを有効にするにはCloudflare Workerを設定してください。';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get notConfigured => '未設定';

  @override
  String get notConnected => '未接続';

  @override
  String get notInstalled => '未インストール';

  @override
  String get notPaired => '未ペアリング';

  @override
  String get notSet => '(未設定)';

  @override
  String get notYetUploaded => '未アップロード';

  @override
  String get onHold => '保留中';

  @override
  String get oneShotRunEndsIn => '単発実行終了まで';

  @override
  String oneTimeRunTriggered(Object app) {
    return '$app の単発実行をトリガーしました';
  }

  @override
  String openCountLabel(Object count) {
    return '未対応 $count件';
  }

  @override
  String get openPdf => 'PDFを開く';

  @override
  String get openingPdf => 'PDFを開いています…';

  @override
  String get orSeparator => 'または';

  @override
  String get output => '出力';

  @override
  String get packageName => 'パッケージ名';

  @override
  String get paired => 'ペアリング済み';

  @override
  String get pairedSuccessfully => 'ペアリングに成功しました!';

  @override
  String get perfProfileTaskCreated => 'パフォーマンスプロファイルタスクを作成しました';

  @override
  String get performanceProfile => 'パフォーマンスプロファイル';

  @override
  String get performanceProfileSubtitle => 'フレーム落ち、メモリ、読み込み時間';

  @override
  String get photo => '写真';

  @override
  String get postpone => '延期';

  @override
  String postponedCount(Object count) {
    return '延期済み ($count)';
  }

  @override
  String get pressBackAgainToExit => 'もう一度戻るを押すと終了します';

  @override
  String get previousChat => '前のチャット';

  @override
  String get priority => '優先度';

  @override
  String processingTasks(Object done, Object total) {
    return '$total件中$done件のタスクを処理中...';
  }

  @override
  String get projectPath => 'プロジェクトパス';

  @override
  String get promptHistory => 'プロンプト履歴';

  @override
  String get promptHistoryTooltip => 'プロンプト履歴';

  @override
  String get publish => '公開';

  @override
  String get pullAndRebuild => 'Pull＆再ビルド';

  @override
  String get pullFailed => 'Pullに失敗しました';

  @override
  String get pullNow => '今すぐPull';

  @override
  String get pullOnly => 'Pullのみ';

  @override
  String purchaseFailed(Object error) {
    return '購入に失敗しました: $error';
  }

  @override
  String get putOnHoldForLater => '後で対応するため保留にする';

  @override
  String get pythonSectionDesc => 'サーバー経由でスクリプトを実行し、Pythonプロジェクトを管理します。';

  @override
  String get quickIssue => 'クイックIssue';

  @override
  String get rePairWithQr => 'QRコードで再ペアリング';

  @override
  String get rebuild => '再ビルド';

  @override
  String get rebuildBody => '最初から新しいビルドを開始しますか?';

  @override
  String get rebuildTitle => '再ビルドしますか?';

  @override
  String get recentBuilds => '最近のビルド';

  @override
  String get refresh => '更新';

  @override
  String refreshFailedShowingCached(Object message) {
    return '更新に失敗しました — 最後に同期したデータを表示しています。$message';
  }

  @override
  String get refreshedFromServer => 'サーバーから更新しました';

  @override
  String get reload => '再読み込み';

  @override
  String get reopen => '再オープン';

  @override
  String get reportBugOrSuggestion => 'バグ/提案を報告';

  @override
  String get reportBugSubtitle => '修正・追加してほしいことを教えてください';

  @override
  String get shareUsageStats => '匿名の利用統計を共有';

  @override
  String get shareUsageStatsDesc =>
      'セッション数と開いた画面の匿名な集計のみ。プロジェクト名やタスクの文面、パスは送信しません。';

  @override
  String get reportConsent =>
      '問題解決のため、このレポートを端末情報 (機種、OS、アプリバージョン) とともに開発者に送信することに同意します。';

  @override
  String get reportHint => '何が起きましたか、またはどんな機能が欲しいですか?';

  @override
  String get reportSentThanks => 'ありがとうございます! レポートを送信しました。';

  @override
  String get reset => 'リセット';

  @override
  String get resetServer => 'サーバーをリセット';

  @override
  String get resetServerBody => 'バックエンドサーバーを再起動します。';

  @override
  String resetServerRunningNote(Object count) {
    return '自動再起動を防ぐため、実行中の自動化 $count件を先に停止します。';
  }

  @override
  String get resumeActiveDevelopment => 'アクティブな開発を再開';

  @override
  String get retry => '再試行';

  @override
  String get retryUpload => 'アップロードを再試行';

  @override
  String get reuploadStarted => '再アップロードを開始しました';

  @override
  String get run => '実行';

  @override
  String get runAgainBody => '単発実行がすでに進行中ですが、AIが早期に停止した可能性があります。もう一度実行しますか?';

  @override
  String get runAgainTitle => '再実行しますか?';

  @override
  String get runAnyway => 'とにかく実行';

  @override
  String get runCheck => 'チェックを実行';

  @override
  String get runOnce => '1回実行';

  @override
  String get runOnceInProgress => '1回実行 (進行中)';

  @override
  String get running => '実行中';

  @override
  String get save => '保存';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get saveEmptyGddBody => '現在の設計ドキュメントが消去されます。';

  @override
  String get saveEmptyGddTitle => '空のGDDを保存しますか?';

  @override
  String get saving => '保存中...';

  @override
  String scanError(Object error) {
    return 'スキャンエラー: $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'スキャンに失敗しました: サーバーが$statusを返しました';
  }

  @override
  String get scanForProjects => 'プロジェクトをスキャン';

  @override
  String get scanPairingQrTitle => 'ペアリング用QRコードをスキャン';

  @override
  String get scanQrToPair => 'QRコードをスキャンしてペアリング';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return '$found件のフォルダをスキャンしました: $imported件インポート、$skipped件スキップ';
  }

  @override
  String get scanThisQr => 'スマートフォンでこのQRコードをスキャンしてください';

  @override
  String get scanToInstall => 'スキャンしてスマートフォンにインストール';

  @override
  String get scopeCheck => 'スコープチェック';

  @override
  String get scopeCheckSubtitle => 'カットリスト＋実現可能性チェック';

  @override
  String get scopeCheckTaskCreated => 'スコープチェックタスクを作成しました';

  @override
  String get screenshotsOptional => 'スクリーンショット (任意)';

  @override
  String get screenshotsTooLarge => 'スクリーンショットが大きすぎます — 1枚削除する必要があるかもしれません。';

  @override
  String get searchAppsHint => 'アプリを検索...';

  @override
  String searchFilterChip(Object query) {
    return '検索: \"$query\"';
  }

  @override
  String get searchHint => '検索...';

  @override
  String get sectionAiAgents => 'AIエージェント';

  @override
  String get sectionGameEngines => 'ゲームエンジン';

  @override
  String get sectionPaths => 'パス';

  @override
  String get sectionServices => 'サービス';

  @override
  String get sectionSystemTools => 'システムツール';

  @override
  String get selectAnApp => 'アプリを選択';

  @override
  String get selectAnAppFirst => '先にアプリを選択してください';

  @override
  String get selectApp => 'アプリを選択';

  @override
  String get selectAppForContext => 'コンテキスト用にアプリを選択するか、一般的な質問をしてください';

  @override
  String get selectAppToViewItems => '項目を表示するアプリを選択してください';

  @override
  String get selectCategoriesOrPrompt => 'カテゴリを選択するか、独自のプロンプトを入力してください。';

  @override
  String get sendReport => 'レポートを送信';

  @override
  String get sending => '送信中…';

  @override
  String get server => 'サーバー';

  @override
  String get serverConfiguration => 'サーバー設定';

  @override
  String get serverConnection => 'サーバー接続';

  @override
  String serverReturnedStatus(Object status) {
    return 'サーバーがステータス$statusを返しました';
  }

  @override
  String get serverStarted => 'サーバーを起動しました!';

  @override
  String get serverStartedHealthFailed => 'サーバーは起動しましたがヘルスチェックに失敗しました';

  @override
  String get serverStopped => 'サーバーを停止しました';

  @override
  String get serverUnreachable => 'サーバーに到達できません';

  @override
  String get serverUrl => 'サーバーURL';

  @override
  String get sessionEndsIn => 'セッション終了まで';

  @override
  String get sessionRefreshed => 'セッションを更新しました — 最近のコンテキストは保持されます';

  @override
  String get settings => '設定';

  @override
  String get settingsJsonNotFound => 'settings.jsonが見つかりません';

  @override
  String get settingsJsonRestartNote => 'settings.json — 変更後はサーバーを再起動してください';

  @override
  String get settingsSavedRestart => '設定を保存しました — 適用するにはサーバーを再起動してください';

  @override
  String get setupInstructions => 'セットアップ手順';

  @override
  String get setupServerFirst => 'まずPCでサーバーをセットアップしてください';

  @override
  String get setupStepCloneRepo => 'リポジトリをクローンします:';

  @override
  String get setupStepEnterUrl =>
      'ターミナルに表示されたURLを入力します (例: http://192.168.1.100:8000):';

  @override
  String get setupStepInstallDeps => '依存関係をインストールします:';

  @override
  String get setupStepInstallPython => 'PCにPython 3.10以上をインストールしてください';

  @override
  String get setupStepRunWizard => 'セットアップウィザードを実行します:';

  @override
  String get setupStepStartServer => 'サーバーを起動します:';

  @override
  String get show => '表示';

  @override
  String get showAll => 'すべて表示';

  @override
  String get showAppIcons => 'アプリアイコンを表示';

  @override
  String get showAppIconsDesc => 'ダッシュボードに汎用のタイプアイコンではなく実際のアプリアイコンを表示します';

  @override
  String get showPairingQr => 'ペアリング用QRコードを表示';

  @override
  String get signInCancelled => 'サインインがキャンセルされました';

  @override
  String signInFailed(Object error) {
    return 'サインインに失敗しました: $error';
  }

  @override
  String get signInWithGoogle => 'Googleでサインイン';

  @override
  String get signOut => 'サインアウト';

  @override
  String get signingIn => 'サインイン中...';

  @override
  String get skipForNow => '今はスキップ';

  @override
  String get start => '開始';

  @override
  String get startBuildFromCardAbove => '上のカードからビルドを開始してください';

  @override
  String get startServer => 'サーバーを起動';

  @override
  String get startServerNotFound => 'start_server.pyが見つかりません';

  @override
  String get status => 'ステータス';

  @override
  String get statusActive => 'アクティブ';

  @override
  String get statusAll => 'すべて';

  @override
  String get statusBuilt => 'ビルド済み';

  @override
  String get statusBuiltLower => 'ビルド済み';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusDivided => '分割済み';

  @override
  String get statusDone => '完了';

  @override
  String get statusFailedLower => '失敗';

  @override
  String statusFilterChip(Object value) {
    return 'ステータス: $value';
  }

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusPending => '保留中';

  @override
  String get statusPendingLower => '保留中';

  @override
  String get statusPostponed => '延期済み';

  @override
  String get stop => '停止';

  @override
  String get stopServer => 'サーバーを停止';

  @override
  String get stoppedLabel => '停止済み';

  @override
  String stuckSuffix(Object time) {
    return '$time スタック中';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return 'スタックしたタスク$count件が30分のタイムアウトで自動的に失敗になりました';
  }

  @override
  String get studioReviews => 'スタジオレビュー';

  @override
  String get submit => '送信';

  @override
  String get submitting => '送信中...';

  @override
  String get suggestApiBackend => 'API＆バックエンド';

  @override
  String get suggestFeatureIntegration => '機能統合';

  @override
  String get suggestFixFailures => '失敗を修正';

  @override
  String get suggestGddAligned => 'GDD準拠';

  @override
  String get suggestImproveCodebase => 'コードベースを改善';

  @override
  String get suggestNextMilestone => '次のマイルストーン';

  @override
  String get suggestPerformanceBoost => 'パフォーマンス向上';

  @override
  String get suggestRevenueIdeas => '収益アイデア';

  @override
  String get suggestSecurityHardening => 'セキュリティ強化';

  @override
  String get suggestTaskPrioritization => 'タスクの優先順位付け';

  @override
  String get suggestTestingQa => 'テスト＆QA';

  @override
  String get suggestUserEngagement => 'ユーザーエンゲージメント';

  @override
  String get suggestUxPolish => 'UXの磨き上げ';

  @override
  String get suggestedForYou => 'あなたへのおすすめ';

  @override
  String get summary => 'サマリー';

  @override
  String get supportDevelopment => '開発を支援';

  @override
  String get supportDevelopmentDesc => 'アプリを楽しんでいますか? ぜひ開発の支援をご検討ください!';

  @override
  String get syncFailed => '同期に失敗しました';

  @override
  String syncedAgo(Object time) {
    return '$timeに同期';
  }

  @override
  String get tapPlusToCreateAutomation => '+をタップして最初の自動化を作成してください';

  @override
  String get tapPlusToStartConversation => '+をタップして会話を開始してください';

  @override
  String get tapToAddLongPressToEdit => 'タップして追加、長押しして編集';

  @override
  String get tapToOpenLongPressToEdit => 'タップして開く、長押しして編集';

  @override
  String get tapToRedetectEngine => 'タップしてディスクからエンジンを再検出';

  @override
  String taskLabelWith(Object task) {
    return 'タスク: $task';
  }

  @override
  String get taskOverview => 'タスク概要';

  @override
  String get taskResetToPending => 'タスクを保留中にリセットしました';

  @override
  String get tasks => 'タスク';

  @override
  String get techDebtScan => '技術的負債スキャン';

  @override
  String get techDebtScanSubtitle => '肥大化したスクリプト、重複、TODO';

  @override
  String get techDebtTaskCreated => '技術的負債スキャンタスクを作成しました';

  @override
  String get tellUsMore => '詳しく教えてください';

  @override
  String get test => 'テスト';

  @override
  String get testConnection => '接続をテスト';

  @override
  String get testTaskCreated => 'テストタスクを作成しました';

  @override
  String get testing => 'テスト中...';

  @override
  String get theme => 'テーマ';

  @override
  String get thinking => '考え中...';

  @override
  String timeDaysAgo(Object days) {
    return '$days日前';
  }

  @override
  String timeHoursAgo(Object hours) {
    return '$hours時間前';
  }

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(Object minutes) {
    return '$minutes分前';
  }

  @override
  String timeMonthsAgo(Object months) {
    return '$monthsか月前';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return '$seconds秒前';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return '$weeks週間前';
  }

  @override
  String get titleHint => 'タイトル';

  @override
  String get titleIsRequired => 'タイトルは必須です';

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
    return '$total件中$done件をトリガーしました';
  }

  @override
  String get tryChangingFilters => 'カテゴリまたはステータスのフィルターを変更してみてください';

  @override
  String get type => '種類';

  @override
  String get typeBug => 'バグ';

  @override
  String get typeFeature => '機能';

  @override
  String typeFilterChip(Object value) {
    return '種類: $value';
  }

  @override
  String get typeFix => '修正';

  @override
  String get typeIdea => 'アイデア';

  @override
  String get typeIssue => 'Issue';

  @override
  String get updateAvailable => 'アップデートあり';

  @override
  String get updateAvailableBody =>
      'GitHubに新しいバージョンがあります。\n最新のコードをPullして再ビルドすると更新されます。';

  @override
  String get updateFailed => '更新に失敗しました';

  @override
  String updatedAgo(Object time) {
    return '$timeに更新';
  }

  @override
  String updatedNamed(Object label) {
    return '$label を更新しました';
  }

  @override
  String get uploadToGooglePlay => 'Google Playにアップロード';

  @override
  String urgentCountLabel(Object count) {
    return '緊急 $count件';
  }

  @override
  String get urgentLabel => '緊急';

  @override
  String get userFallback => 'ユーザー';

  @override
  String get version => 'バージョン';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => '失敗したタスクを表示';

  @override
  String get viewIssues => 'Issueを表示';

  @override
  String get viewOnGitHub => 'GitHubで表示';

  @override
  String get warningPublishesToAll => '警告: これは全ユーザーに公開されます!';

  @override
  String get webDeploy => 'Webデプロイ';

  @override
  String get webDeploySectionDesc => 'サーバー経由でWebアプリをビルド・デプロイします。';

  @override
  String get website => 'ウェブサイト';

  @override
  String get whatIsThis => 'これは何ですか?';

  @override
  String get workOnAll => 'すべてに取り組む';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n($count件のブロック中の項目はスキップされます。)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return '保留中の$count件すべてにAIを実行しますか?\n順番に処理されます。';
  }

  @override
  String get workOnAllPending => '保留中のすべてに取り組む';

  @override
  String get workOnThis => 'これに取り組む';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return '$agent AIを実行:\n\"$title\"';
  }

  @override
  String get workerUrl => 'Worker URL';

  @override
  String get workerUrlAutoDetected => 'settings.jsonから自動検出 (読み取り専用)';

  @override
  String get workerUrlCopied => 'Worker URLをコピーしました';

  @override
  String get workerUrlHelp => 'このURLはデスクトップアプリまたはサーバー管理者から取得してください';

  @override
  String get workerUrlSaved => 'Worker URLを保存しました';

  @override
  String get workerUrlSetHint =>
      'server/config/settings.jsonでcloudflare.worker_urlを設定してください';

  @override
  String get youreAllSet => '準備完了です!';

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'AGENTS.mdはまだありません。「追加」をタップしてAI向けのプロジェクト指示を設定してください。';

  @override
  String get cannotSaveEmptyAgentsMd => '空のAGENTS.mdは保存できません';

  @override
  String get agentsMdSaved => 'AGENTS.mdを保存しました';

  @override
  String get reportEmailLabel => 'メール (任意)';

  @override
  String get reportEmailHint => '返信が必要な場合のメールアドレス';

  @override
  String get reportEmailNote => 'このレポートへの返信にのみ使用します。空欄なら匿名のままです。';

  @override
  String get reportEmailInvalid => 'メールアドレスの形式ではありません。';

  @override
  String get reportReply => '返信';

  @override
  String reportReplySubject(String app) {
    return '$app のレポートについて';
  }

  @override
  String get navGenerate => '生成';

  @override
  String get navGallery => '生成済み';

  @override
  String get navFlow => 'ライン';

  @override
  String get navQueue => 'キュー';

  @override
  String get navDelivery => '配信';

  @override
  String get navBuckets => 'バケット';

  @override
  String get assetModeTooltip => 'アセットモード';

  @override
  String get deliveryModeTooltip => '配信モード';

  @override
  String get videoPlaybackFailed => '動画を再生できませんでした';

  @override
  String get apiKeyRefusedBanner => 'APIキーが拒否されました - タップして設定で修正';

  @override
  String get errOffline => 'サーバーに接続できません - 接続を確認してください';

  @override
  String get errTimeout => 'サーバーの応答がタイムアウトしました - もう一度お試しください';

  @override
  String errGatewayTimeout(int status) {
    return 'サーバーが時間内に応答しませんでした（ゲートウェイタイムアウト $status）';
  }

  @override
  String errGateway(int status) {
    return 'ゲートウェイの先のサーバーに接続できません（ゲートウェイエラー $status）- サーバーが起動しているか確認してください';
  }

  @override
  String errServer(int status) {
    return 'サーバーエラー（$status）- 後でもう一度お試しください';
  }

  @override
  String errUnauthorized(int status) {
    return '認証されていません（$status）- 設定のAPIキーを確認してください';
  }

  @override
  String errNotFound(int status) {
    return 'サーバーに見つかりません（$status）';
  }

  @override
  String errRateLimited(int status) {
    return 'リクエストが多すぎます（$status）- 少し待ってからもう一度お試しください';
  }

  @override
  String errTooLarge(int status) {
    return 'サーバーには大きすぎます（$status）';
  }

  @override
  String errRejected(int status) {
    return 'サーバーがリクエストを拒否しました（$status）';
  }

  @override
  String get errBadResponse => 'サーバーからアプリが読み取れない応答が返されました';

  @override
  String get errUnknown => 'リクエストに失敗しました - もう一度お試しください';

  @override
  String bucketsCounting(String bucket) {
    return '$bucket を集計中...';
  }

  @override
  String get bucketsTakedownTitle => 'テイクダウン（新 + 旧）';

  @override
  String get bucketsDeleteForeverTitle => '完全に削除';

  @override
  String bucketsDeleteWarning(int count) {
    return '$count 個のオブジェクトが削除されます。元に戻せません。';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count 個のキーは旧ツインに対応がありません - このバケットからのみ削除されます。';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return '確認のためバケット名を入力してください: $bucket';
  }

  @override
  String get bucketsTakedown => 'テイクダウン';

  @override
  String bucketsDeleted(int count) {
    return '$count 個のオブジェクトを削除しました';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count 個のオブジェクトを削除、旧ツインから $twin 個';
  }

  @override
  String bucketsCopySource(String path) {
    return 'コピー元: $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'コピー元ツリー: $path';
  }

  @override
  String get bucketsWholeBucket => '（バケット全体）';

  @override
  String get bucketsCopyNote => 'コピーはストレージサービス内で実行されます - 端末をデータが通ることはありません。';

  @override
  String get bucketsTargetKey => 'コピー先キー';

  @override
  String get bucketsTargetPrefix => 'コピー先プレフィックス';

  @override
  String bucketsCopyStarted(String op) {
    return 'コピーを開始しました（$op）';
  }

  @override
  String get bucketsFixHeadersTitle => 'ヘッダーを修正';

  @override
  String bucketsFixHeadersBody(String path) {
    return '$path 配下のオブジェクトの Cache-Control ヘッダーを確認し、標準から外れているものはその場で書き直します（Content-Type は保持）。データはダウンロードされません。\n\n意図的に可変のままにしているプレフィックスはスキップされます。';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'ヘッダーの修復を開始しました（$op）';
  }

  @override
  String get bucketsOperations => '操作';

  @override
  String get bucketsNoOperations => '操作はまだありません';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  成功 $ok  ·  失敗 $failed';
  }

  @override
  String get bucketsTwinDiffRunning => 'ツインとの差分を計算中...';

  @override
  String get bucketsLocalDiffRunning => 'ローカルとの差分を計算中...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin（旧ツイン）';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'ローカルの送信済みフォルダー <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => '旧ツインにないもの';

  @override
  String get bucketsMissingInBucket => 'バケットにないもの';

  @override
  String get bucketsOnlyInLegacy => '旧ツインのみ';

  @override
  String get bucketsOnlyInBucket => 'バケットのみ';

  @override
  String get bucketsSizeMismatch => 'サイズが異なる';

  @override
  String get bucketsUnmapped => '対応なし（ルールなし）';

  @override
  String get bucketsDerived => 'バケット内で生成（サムネイル）';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title: $count';
  }

  @override
  String get bucketsFixFolderHeaders => 'このフォルダーのヘッダーを修正';

  @override
  String get bucketsDiffs => '差分';

  @override
  String get bucketsTwinDiff => '旧ツインとの差分';

  @override
  String get bucketsLocalDiff => 'ローカルの送信済みフォルダーとの差分';

  @override
  String get bucketsIntro =>
      'バケットは内容の名前が付いた保管場所です。件数は要求時に計算されます（一覧取得のみで、データはダウンロードされません）。';

  @override
  String get bucketsBadgeLegacy => '旧';

  @override
  String get bucketsBadgePrivate => '非公開';

  @override
  String get bucketsBadgeContent => 'コンテンツ';

  @override
  String get bucketsNotCounted => '未集計';

  @override
  String bucketsObjectCount(int count) {
    return '$count 個のオブジェクト';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'ツイン: $twin';
  }

  @override
  String get bucketsCount => '集計';

  @override
  String get bucketsEmptyFolder => 'このフォルダーは空です';

  @override
  String get bucketsTruncated => '一覧が途中で切れました - より絞ったフォルダーを開いてください';

  @override
  String bucketsSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get bucketsClearSelection => '選択を解除';

  @override
  String get bucketsTakedownTooltip => 'テイクダウン（旧ツインからも削除）';

  @override
  String get bucketsSize => 'サイズ';

  @override
  String get bucketsContentType => '種類';

  @override
  String get bucketsModified => '更新日時';

  @override
  String get bucketsNone => '（なし）';

  @override
  String get bucketsMutableOnPurpose => '意図的に可変 - 標準の対象外';

  @override
  String bucketsHeaderOk(String kind) {
    return 'キャッシュ標準に適合（$kind）';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return '標準: $expected';
  }

  @override
  String get bucketsLegacyTwin => '旧ツイン';

  @override
  String get bucketsAddressCopied => 'アドレスをコピーしました';

  @override
  String get bucketsCopyAddress => 'アドレスをコピー';

  @override
  String get bucketsOpen => '開く';

  @override
  String get bucketsPrivateNoAddress => 'このバケットは非公開です - 公開アドレスはありません';

  @override
  String get kindCard => 'カード';

  @override
  String get kindCharacter => 'キャラクター';

  @override
  String get assetCodeMode => 'コードモード';

  @override
  String get assetPickFinishedImage => '完成した画像を選択してください';

  @override
  String get assetGenerateVideo => '動画を生成';

  @override
  String get assetEnlarge => '拡大';

  @override
  String percentValue(Object value) {
    return '$value%';
  }

  @override
  String get commonCategory => 'カテゴリ';

  @override
  String durSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String durMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String get charKindFemale => '女性';

  @override
  String get charKindMale => '男性';

  @override
  String get charKindAnimal => '動物';

  @override
  String get charKindMachine => '機械';

  @override
  String get outfitCatSet => 'セット';

  @override
  String get outfitCatTop => 'トップス';

  @override
  String get outfitCatBottom => 'ボトムス';

  @override
  String get outfitCatShoes => '靴';

  @override
  String get outfitCatSocks => '靴下';

  @override
  String get outfitCatHat => '帽子';

  @override
  String get outfitCatHeadgear => 'ヘッドギア';

  @override
  String get outfitCatAccessory => 'アクセサリー';

  @override
  String get outfitCatWeapon => '武器';

  @override
  String get audioLabel => 'オーディオ';

  @override
  String get audioDownloading => 'ダウンロード中...';

  @override
  String get audioOpen => 'オーディオを開く';

  @override
  String get outfitExtractTitle => '衣装を抽出';

  @override
  String get outfitExtractBody =>
      '選択した画像から人物を消し、衣装を無地グレー背景のゴーストマネキン商品カットとしてワードローブに保存します。その後、どのキャラクターにもスキンとして着せられます。';

  @override
  String get outfitExtractName => '衣装名';

  @override
  String get outfitExtractNameHint => '例: 赤いイブニングドレス';

  @override
  String get outfitExtractNote => 'メモ (任意)';

  @override
  String get outfitExtractNoteHint => '例: ドレスのみ、靴は除く';

  @override
  String get outfitExtractHelp =>
      'セット: 人物が身に着けているものすべてを1枚に。武器 / アクセサリー: その品だけ、マネキンなし。';

  @override
  String get outfitExtractAction => '抽出';

  @override
  String equipSlotTitle(Object category) {
    return '$categoryスロット';
  }

  @override
  String get equipSlotMultiHint => '複数選択 - タップで着ける / 外す';

  @override
  String get equipSlotSingleHint => '単一選択 - タップで着ける、もう一度タップで外す';

  @override
  String get equipSlotEmpty => '(なし)';

  @override
  String get equipSlotNoOutfits =>
      'このカテゴリに使用できる衣装がありません -「+ 衣装を生成」または「衣装を抽出」を使ってください';

  @override
  String get equipBaseLabel => 'ベース:';

  @override
  String get equipUndress => 'すべて外す';

  @override
  String get equipPickSourceTitle => '元画像を選択';

  @override
  String get equipPickSourceHint =>
      '最新の完了済み生成 (全モード)。Jigsawラインの incoming / staging / pushed の画像は「ライン > Jigsaw」画面を使ってください。';

  @override
  String get equipNoFinishedImage => '完成した画像がありません';

  @override
  String get freeFlowTitle => 'Freeライン';

  @override
  String get freeFlowEditTitle => '編集 - 編集エンジン';

  @override
  String get freeFlowEditLabel => '変更したい内容';

  @override
  String get freeFlowEditHint =>
      '例: change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => '編集をキューに追加しました';

  @override
  String get freeFlowNoVideoTask => 'Freeモードには動画タスクがありません';

  @override
  String freeFlowVideoTitle(Object task) {
    return '動画を生成 - $task';
  }

  @override
  String get freeFlowMotionLabel => '動き';

  @override
  String get freeFlowMotionHint =>
      '例: she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued => '動画をキューに追加しました - 完了するとこのカードに再生マークが表示されます';

  @override
  String get freeFlowDeleteConfirm => 'この生成を削除しますか?';

  @override
  String get freeFlowDeleteWithVideosConfirm => 'この生成とその動画を削除しますか?';

  @override
  String get freeFlowEmpty => 'Freeモードの生成はまだありません -「生成」タブから始めてください';

  @override
  String get queueKindGeneration => '生成';

  @override
  String get queueKindTag => 'タグ付け';

  @override
  String get queueKindMusic => '音楽';

  @override
  String get queueKindJob => 'ジョブ';

  @override
  String get queueCancelRunningTitle => '実行中のジョブをキャンセル';

  @override
  String get queueRemoveTitle => 'キューから外す';

  @override
  String get queueCancelIt => 'キャンセルする';

  @override
  String get queueClearTitle => 'キューを空にする';

  @override
  String get queueClearBody => '待機中の生成ジョブをキャンセルしますか? 実行中のジョブは続行されます。';

  @override
  String get queueCancelWaiting => '待機中のジョブをキャンセル';

  @override
  String get queueEmpty => 'キューは空です';

  @override
  String get queueEmptyHint => '「生成」タブからジョブを追加できます';

  @override
  String get queueNow => '実行中';

  @override
  String queueWaitingCount(Object count) {
    return '待機中 ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return '生成ジョブ ($count)';
  }

  @override
  String get queueOneQueue => '単一キュー - すべてのジョブ';

  @override
  String queueJobCount(Object count) {
    return '$count 件';
  }

  @override
  String get queueMoveUp => '上へ移動';

  @override
  String get queueMoveDown => '下へ移動';

  @override
  String get queueUp => '上へ';

  @override
  String get queueDown => '下へ';

  @override
  String queueElapsed(Object time) {
    return '経過 $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return '待機 $time';
  }

  @override
  String get queueWaiting => '待機中';

  @override
  String get queueComfyReady => 'ComfyUI 準備完了';

  @override
  String get queueComfyOff => 'ComfyUI は停止中';

  @override
  String get deliveryPoolNeverRan => '未実行';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (試行)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · 画像 $total、有効 $valid、タグ付け $tagged、失敗 $failed';
  }

  @override
  String get reportErrEmpty => '先にメッセージを入力してください。';

  @override
  String get reportErrTooLarge => '添付ファイルが大きすぎます。1つ削除してもう一度お試しください。';

  @override
  String flowOpError(Object message) {
    return '処理に失敗しました: $message';
  }

  @override
  String get flowOpCancelled => '処理をキャンセルしました';

  @override
  String flowOpDone(Object ok) {
    return '$ok 件完了';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok 件完了、$failed 件失敗';
  }

  @override
  String get flowCollection => 'コレクション';

  @override
  String get flowAllParen => '(すべて)';

  @override
  String get flowAll => 'すべて';

  @override
  String get flowSelectAll => 'すべて選択';

  @override
  String get flowRetag => 'タグを付け直す';

  @override
  String get flowRetagShort => 'タグ';

  @override
  String get flowRetagStarted => 'タグ付けを開始しました';

  @override
  String get flowReadOnly => '閲覧のみ';

  @override
  String get flowPush => 'プッシュ';

  @override
  String get flowPreview => 'プレビュー';

  @override
  String get flowYes => 'あり';

  @override
  String get flowNo => 'なし';

  @override
  String get flowMissingUpper => 'なし';

  @override
  String get flowBadgeNoTags => 'タグなし';

  @override
  String get flowTabPushed => '4 プッシュ済み';

  @override
  String get flowSelectAssetFirst => '先にアセットを選択してください';

  @override
  String get flowAccept => '承認';

  @override
  String get flowReject => '却下';

  @override
  String get flowUpload => 'アップロード';

  @override
  String get flowNew => '新規';

  @override
  String get flowReadFailed => 'ラインを読み込めませんでした';

  @override
  String flowFilesDeleted(Object count) {
    return '$count 個のファイルを削除しました';
  }

  @override
  String get flowNegative => 'ネガティブ';

  @override
  String get flowPositive2 => 'ポジティブ 2';

  @override
  String get flowDuration => '長さ';

  @override
  String get flowAddToQueue => 'キューに追加';

  @override
  String get commonDescription => '説明';

  @override
  String get cbnFlowTitle => 'CBNライン';

  @override
  String get cbnFlowTabIncoming => '2 受信';

  @override
  String get cbnFlowTabReady => '3 準備完了';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'ビルド - $count 件';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      '領域分割 + パレット + 番号付きテンプレート + リビール動画 (CPU)。SAM工程は事前に完了している必要があります。輪郭はSAMの境界から作られます。(Hot: ビルドが線画ページをQwenで自動生成します。C工程は任意のプレビューです。)';

  @override
  String get cbnFlowBuildBodyKid =>
      '領域分割 + パレット + 番号付きテンプレート + SVG (CPU)。SAM工程は事前に完了している必要があります。';

  @override
  String get cbnFlowBuild => 'ビルド';

  @override
  String get cbnFlowBuildStarted => 'ビルドを開始しました - 進行状況は上部に表示されます';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stageを開始しました ($count 件)';
  }

  @override
  String get cbnFlowStageObjects => 'オブジェクト一覧';

  @override
  String get cbnFlowLineart => '線画';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'プッシュ - $count 件';
  }

  @override
  String get cbnFlowPushBody =>
      'アセットフォルダーをR2にアップロードし、「プッシュ済み」へ移動します。\n\nこれは公開操作で、元に戻せません。';

  @override
  String cbnFlowDeleteBody(Object count) {
    return '$count 件のアセットを削除します。';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count 件削除しました';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'このステージにアセットはありません。\n「生成済み」画面のCBNモードで「承認」するとここに届きます。';

  @override
  String get cbnFlowEmptyStaging =>
      'ビルド済みのアセットはまだありません。\n「受信」タブで選択して「ビルド」をタップしてください。';

  @override
  String get cbnFlowEmptyPushed => 'プッシュ済みのアセットはありません。';

  @override
  String get cbnFlowBadgeTagged => 'タ';

  @override
  String get cbnFlowBadgeObjects => '物';

  @override
  String cbnFlowBadgeBuilt(Object regions, Object colors) {
    return '$regions域 $colors色';
  }

  @override
  String get cbnFlowLayerNumbered => '番号付き';

  @override
  String get cbnFlowLayerFinished => '完成';

  @override
  String get cbnFlowLayerSource => '元画像';

  @override
  String get cbnFlowLayerObjects => 'オブジェクト';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions 領域 · $colors 色 · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   タグ: $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) オブジェクトを検出';

  @override
  String get cbnFlowSamMasks => 'B) SAMマスク';

  @override
  String get cbnFlowLineartPage => 'C) 線画ページ (任意、Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) ビルド';

  @override
  String get cbnFlowStepMissingA => 'A工程 (オブジェクト一覧) は未実行です';

  @override
  String get cbnFlowStepMissingB => 'B工程 (SAMマスク) は未実行です';

  @override
  String get cbnFlowStepMissingC => 'C工程 (線画ページ) は未実行です';

  @override
  String get cbnFlowImageFailed => '画像を読み込めませんでした';

  @override
  String get jigsawFlowTitle => 'Jigsawライン';

  @override
  String get jigsawFlowTabTagged => '2 タグ済み';

  @override
  String get jigsawFlowTabToPush => '3 プッシュ待ち';

  @override
  String get jigsawFlowQueueAll => 'すべてキューへ';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'すべてキューへ - $count 件';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return '動画を生成 - $count 件';
  }

  @override
  String get jigsawFlowPositive1 => 'ポジティブ 1 - 被写体';

  @override
  String get jigsawFlowPositive1Help => '空欄 = 各アセット自身のプロンプト';

  @override
  String get jigsawFlowMotionPreset => '動きのプリセット';

  @override
  String get jigsawFlowSpreadInTurn => '(順番に割り当て)';

  @override
  String get jigsawFlowPositive2 => 'ポジティブ 2 - 動き';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = 被写体プロンプトの位置。空欄 = プリセットを順番に使用。';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return '$count 個のプリセットを順番に割り当てます。';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => '動画のないアセットはありません';

  @override
  String get jigsawFlowSelectWithoutVideo => '動画のないアセットを選択してください';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued 本の動画をキューに追加しました - 完了するとここに届きます';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued 本の動画をキューに追加、$skipped 本をスキップしました - 完了するとここに届きます';
  }

  @override
  String get jigsawFlowNoVideoTitle => '動画なし';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count 件のアセットに動画がありません - jpgのみ書き出されます。続行しますか?';
  }

  @override
  String get jigsawFlowMusicNotReady => '音楽モデルの準備ができていません';

  @override
  String get jigsawFlowNoMusicMissing => '音楽が未設定のテーマコレクションはありません';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection には既に音楽があるか、Generic です';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return '$count 個のコレクション用に30秒のインストゥルメンタル曲を生成します (ACE-Step、ローカル)。\n\n$names\n\n1曲あたり数分かかることがあります。';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count 件のアセットをR2バケットにアップロードします。\n\nこれは元に戻せない公開操作です - アップロードしたファイルはアプリに表示されます。';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return '$count 件のアセット (jpg + mp4 + webp + json) を完全に削除しますか?';
  }

  @override
  String get jigsawFlowWebpStarted => '不足しているwebpの生成を開始しました';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return '$mode コレクション';
  }

  @override
  String get jigsawFlowCollectionHelp => '一覧から選ぶか、新しい名前を入力';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return '一覧から選ぶか、新しい名前を入力  -  満杯のコレクション $count 個は非表示';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total 件 - 次は $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'このステージにアセットはありません。\n「生成済み」画面で「承認」するとここに届きます。';

  @override
  String get jigsawFlowEmpty => 'このステージにアセットはありません。';

  @override
  String get jigsawFlowBadgeNoWebp => 'webpなし';

  @override
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp) {
    return '$label\n動画: $video   webp: $webp';
  }

  @override
  String jigsawFlowPreviewTags(Object state) {
    return 'タグ: $state';
  }

  @override
  String get jigsawFlowNoVideoInSelection => '選択したアセットに動画はありません';

  @override
  String get jigsawFlowDeleteVideo => '動画を削除';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return '$count 件のアセットの mp4 + webp を削除します。画像は残り、動画を再生成できます。';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip => '動画を削除 (画像は残ります)';

  @override
  String get jigsawFlowExtractNeedsOne => '衣装は1枚の画像から抽出します - 1枚選択してください';

  @override
  String outfitExtractStarted(Object name) {
    return '$name をワードローブへ抽出しています - キャラクター > ワードローブ';
  }

  @override
  String get jigsawFlowMetaFile => 'ファイル';

  @override
  String get jigsawFlowMetaTags => 'タグ';

  @override
  String get jigsawFlowMetaSubject => '被写体';

  @override
  String get jigsawFlowMetaPolicy => 'ポリシー';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   webp: $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'タグ / メタデータ';

  @override
  String get jigsawFlowMissingWebp => '不足しているwebp';

  @override
  String deliverySavedLive(Object time) {
    return '保存して公開しました ($time) - 件数を更新しています';
  }

  @override
  String get deliveryReindexTitle => 'メタデータを再読み込み';

  @override
  String get deliveryReindexBody =>
      'バケット内でEXIFが変わった画像用です。ファイル名をカンマ区切りで入力してください (例: 12.jpg, 340.jpg)。空欄にすると Generic 全体を再読み込みします (約1500ファイル、数分)。';

  @override
  String get deliveryReindexNames => 'ファイル名';

  @override
  String get deliveryReindexAction => '読み込む';

  @override
  String deliveryReindexed(Object count) {
    return '$count 枚の画像を再読み込みしました - マニフェストを更新しました';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count 枚の画像を再読み込み、$missing 枚は見つかりませんでした - マニフェストを更新しました';
  }

  @override
  String get deliveryDryRunStarted => '試行を開始しました - レポートのみ作成します';

  @override
  String get deliveryNormalizeStarted => '正規化を開始しました';

  @override
  String get deliveryCancelRequested => 'キャンセルを要求しました';

  @override
  String get deliveryNeverSaved => '未保存';

  @override
  String get deliveryPoolJigsaw => 'Jigsawプール';

  @override
  String get deliveryPoolCards => 'カード';

  @override
  String get deliveryPoolEvents => 'イベント';

  @override
  String get deliveryEvent => 'イベント';

  @override
  String deliverySummaryLine(
    Object pool,
    Object total,
    Object tagged,
    Object untagged,
  ) {
    return '$poolプール: 画像 $total、タグ済み $tagged、タグなし $untagged';
  }

  @override
  String get deliverySaveBeforeSwitch => 'プールを切り替える前に変更を保存してください。';

  @override
  String get deliveryReindexTooltip => 'メタデータを再読み込み (EXIFが変わった場合)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return '最終ルール: $time  ·  既定で配信: $served / $total';
  }

  @override
  String get deliveryIntro =>
      'スイッチOFF = その値の画像はマニフェストから外れます。保存は即時に反映され、すべてのコレクション / デッキが対象になります。ルールで漏れた個別の項目はブロックリストで止められます。';

  @override
  String get deliveryNormalizeTitle => '正規化 - 不足しているタグを生成';

  @override
  String get deliveryDryRun => '試行';

  @override
  String get deliveryNormalizeNoStatus =>
      '状態を取得できません - サーバーが /api/normalize/status に応答しませんでした';

  @override
  String deliveryIndex(Object index) {
    return 'インデックス: $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return '前回の実行: $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => '全アプリ (グローバル)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'ブロック · $scope';
  }

  @override
  String get deliveryOpenList => 'リストを開く';

  @override
  String get deliveryBlockIntro =>
      'グローバルブロックはすべてのアプリに適用されます。アプリを選ぶと、そのアプリだけをブロックします。ルールの後に適用されます。';

  @override
  String get deliveryBlockEmpty => 'このプールにブロックできる項目はありません (バケットは空です)。';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count 件 · タグ済み $tagged/$count';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count 件 · タグ済み $tagged/$count · すべてブロック中';
  }

  @override
  String get deliveryAppsHint => 'アプリ - タップしてそのアプリのルールを編集';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return '既定  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      '既定ルール - ?app= を送らない旧バージョンと、独自ルールのないアプリ';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return '$app 用の独自ルール';
  }

  @override
  String get deliveryCustomRuleOn => 'オフにすると既定に戻ります';

  @override
  String get deliveryCustomRuleOff => 'オフ: 既定ルールが適用されます。オンにすると既定のコピーから始まります。';

  @override
  String get deliveryScopeTitle => '選択したコレクションのみ';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total コレクション - 新しく公開されたものはこのアプリに届きません';
  }

  @override
  String get deliveryScopeOff => 'オフ: 新しく公開されたコレクションはすべてこのアプリにも届きます';

  @override
  String get deliveryScopeNone => '何も選択されていません - 空のリストは保存されず、ルールは「すべて」に戻ります。';

  @override
  String get deliveryRulesEnabled => 'ルール有効';

  @override
  String get deliveryRulesEnabledHint => 'オフ = このルールセットは何もフィルターしません';

  @override
  String get deliveryServeUntagged => 'タグなし画像を配信';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count 枚の画像にメタデータがありません';
  }

  @override
  String get deliveryQuick => 'クイック:';

  @override
  String deliveryOffCount(Object count) {
    return '$count 件オフ';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count 個の値';
  }

  @override
  String get deliveryUnsaved => '未保存の変更があります';

  @override
  String get deliveryInSync => 'サーバーと同じ';

  @override
  String get deliverySavePublish => '保存して公開';

  @override
  String get commonApply => '適用';

  @override
  String get commonModel => 'モデル';

  @override
  String get cardTplShuffled => 'シャッフルしました - ロックした軸は変更していません';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank をシャッフルしました';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - すべてに適用';
  }

  @override
  String get cardTplAxisAllBack => 'カード裏面に書き込み、ロックします。';

  @override
  String get cardTplAxisAllFront =>
      '13枚のカード + ジョーカー2枚にまとめて書き込み、ロックします - シャッフルでは変わりません。';

  @override
  String get cardTplValue => '値';

  @override
  String get cardTplAllWritten => 'すべてに書き込み、ロックしました';

  @override
  String cardTplRankTitle(Object rank) {
    return '$rank のテンプレート';
  }

  @override
  String get cardTplLocked => 'ロック中';

  @override
  String get cardTplLock => 'ロック';

  @override
  String get cardTplManual => '手動の追加 (自由入力)';

  @override
  String get cardTplManualHint => '例: holding a golden card fan';

  @override
  String get cardTplManualHelp => 'テンプレートの末尾に追加されます - シャッフルしても消えません';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank を保存しました';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot をキューに追加しました';
  }

  @override
  String cardTplTitle(Object title) {
    return 'コレクションカード - $title';
  }

  @override
  String get cardTplShuffle => 'シャッフル';

  @override
  String get cardTplNoTheme => 'テーマなし - タップして入力';

  @override
  String get cardTplThemeTitle => 'テーマ (P1)';

  @override
  String get cardTplPresetCard => 'プリセットカード';

  @override
  String get cardTplTheme => 'テーマ';

  @override
  String get cardTplThemeHelp => 'アイデンティティ + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'テーマは空にできません';

  @override
  String get cardTplThemeSaved => 'テーマを保存しました';

  @override
  String cardTplModelSet(Object name) {
    return 'モデル: $name';
  }

  @override
  String get cardTplFaceDetail => '顔のレタッチ';

  @override
  String get cardTplFaceDetailHint => '+15秒/枚 - 顔を別パスで処理します';

  @override
  String get cardTplFaceDetailOn => '顔のレタッチ: オン';

  @override
  String get cardTplFaceDetailOff => '顔のレタッチ: オフ';

  @override
  String get cardTplVideoEngine => '動画エンジン (最初のフレーム = 最後のフレーム)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (未インストール)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return '動画エンジン: $name';
  }

  @override
  String get cardTplApplyToAll => 'すべてに適用:';

  @override
  String get cardTplPickAxis => '軸を選択';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (裏面)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count 個の軸をロック中';
  }

  @override
  String get cardTplShuffleSlot => 'このスロットをシャッフル';

  @override
  String get cardTplGenerateSlot => 'このスロットを生成';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return '$count 件の生成とそのファイルを削除しますか?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count 件の生成を削除しました';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count 件を削除できませんでした';
  }

  @override
  String get galleryCharacterNeedsOne => 'キャラクターは1枚の画像から作成します - 1枚選択してください';

  @override
  String get galleryMakeCharacter => 'キャラクターを作成';

  @override
  String get galleryMakeCharacterBody =>
      '選択した画像がそのままベースになります。ポートレート、ストーリー、7方向は自動で生成されます - 確認はありません。';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name をキューに追加しました - 進行状況は「キュー」タブで確認できます';
  }

  @override
  String get galleryCreateCharacterFirst => '先に「キャラクターを作成」でキャラクターを作成してください';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return '候補に追加 - $count 枚';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$name の候補に $count 枚の画像を追加しました';
  }

  @override
  String get galleryCollectionNeedsOne => 'コレクションに追加できる画像は1枚です - 1枚選択してください';

  @override
  String get galleryCreateCollectionFirst => '先にカードラインでコレクションまたはディーラーを作成してください';

  @override
  String get galleryAddToCollection => 'コレクションに追加';

  @override
  String get galleryDealerNoRank => 'ディーラー (ランクなし)';

  @override
  String galleryPickRank(Object name) {
    return '$name - ランクを選択';
  }

  @override
  String get galleryQueuedOne => 'キューに追加しました (1件) -「キュー」タブで確認できます';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count 枚の画像をCBNラインの「受信」ステージへ移動します: jpg + EXIFタグ。ビルド (SAM、線画、領域) はそこで開始します。\n\nどのレーティングにしますか?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count 枚の画像をステージ2へ移動します: jpg + EXIFタグ。動画があれば一緒に移動します。\n\nどのレーティングにしますか?';
  }

  @override
  String get galleryAcceptStarted => '開始しました - 進行状況は「ライン」タブで確認できます';

  @override
  String get galleryExtractTooltip => '衣装を抽出 - 画像の衣装をワードローブに取り込む';

  @override
  String get galleryMakeCharacterTooltip => 'キャラクターを作成 - 新しいキャラクターを作る';

  @override
  String get galleryAddToCandidatesTooltip => '候補に追加 - 既存のキャラクターにコピー';

  @override
  String get galleryAddToCollectionTooltip => 'コレクションに追加 - ランクを選択';

  @override
  String get galleryAcceptTooltip => '承認 - ステージ2へ送る';

  @override
  String get galleryDeleteSelected => '選択した項目を削除';

  @override
  String get galleryFilterImage => '画像';

  @override
  String get galleryFilterVideo => '動画';

  @override
  String get galleryFilterFavorite => 'お気に入り';

  @override
  String galleryQueuedAt(Object position) {
    return 'キュー待ち $position';
  }

  @override
  String get galleryEmpty => '生成はまだありません';

  @override
  String get galleryEmptyHint => '「生成」タブから始められます';

  @override
  String get galleryDeleteOneConfirm => 'この生成とそのファイルを削除しますか?';

  @override
  String get galleryAcceptOneCbn =>
      'CBNラインの「受信」ステージへ移動します (jpg + EXIFタグ)。\n\nどのレーティングにしますか?';

  @override
  String get galleryAcceptOneJigsaw =>
      'ステージ2へ移動します (jpg + EXIFタグ)。\n\nどのレーティングにしますか?';

  @override
  String get galleryAccepted => '承認しました - タグ付け中です。「ライン」タブで確認できます';

  @override
  String get galleryRejected => '却下しました';

  @override
  String get galleryEditBody =>
      'この画像が元画像になり、編集エンジン (Qwen Image Edit、人物の同一性を保持) が新しい生成を開始します。何を変更しますか?';

  @override
  String get galleryEditPromptLabel => '追加プロンプト';

  @override
  String get galleryEditPromptHint =>
      '例: change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued => '編集をキューに追加しました - 結果は「生成済み」に表示されます';

  @override
  String get galleryEditTooltip => '編集 - 編集エンジンで新しく生成';

  @override
  String galleryPoolInfo(Object name) {
    return 'プール $name';
  }

  @override
  String get genPromptUnchanged => 'プロンプトは変更されませんでした (ローカルLLMが応答しませんでした)';

  @override
  String get genPromptWritten => 'プロンプトを書き込みました';

  @override
  String get commonUndo => '元に戻す';

  @override
  String get genVariantFailed => 'バリエーションを生成できませんでした (ローカルLLMが応答しませんでした)';

  @override
  String get genPickVariant => 'バリエーションを選択';

  @override
  String get genEnrich => '肉付け';

  @override
  String get genFix => '修正';

  @override
  String get genVariant => 'バリエーション';

  @override
  String get genFileUnreadable => 'ファイルを読み込めませんでした';

  @override
  String get genPromptEmpty => 'プロンプトは空にできません';

  @override
  String genMissingInputs(Object inputs) {
    return '不足している入力: $inputs';
  }

  @override
  String get genNeedsImagePick => 'このタスクには入力画像が必要です - 生成済みから1枚選択してください';

  @override
  String get genNeedsImage => 'このタスクには入力画像が必要です';

  @override
  String genQueuedCount(Object count) {
    return '$count 件のジョブをキューに追加しました';
  }

  @override
  String get genQueued => 'キューに追加しました';

  @override
  String genQueueBadge(Object count) {
    return '$count 件待機中';
  }

  @override
  String get genComfyOffBody =>
      'ComfyUI は停止中です。ジョブはキューに入りますが開始されません - パソコンで起動する必要があります。';

  @override
  String get genTask => 'タスク';

  @override
  String get genWorkflowInputs => 'ワークフローの入力';

  @override
  String get genInputImage => '入力画像';

  @override
  String get genPositive1 => 'ポジティブプロンプト 1 - 被写体';

  @override
  String get genPositive1Hint => '例: police officer';

  @override
  String get genPositive2 => 'ポジティブプロンプト 2 - テンプレート';

  @override
  String genPositive2Help(Object marker) {
    return '$marker は1つ目のプロンプトに置き換えられます。空欄でも構いません。';
  }

  @override
  String get genFinalPrompt => '送信されるプロンプト';

  @override
  String get genNegative => 'ネガティブプロンプト';

  @override
  String get genTurboHint => '高速モード';

  @override
  String genDurationSeconds(Object seconds) {
    return '長さ: $seconds 秒';
  }

  @override
  String genCount(Object count) {
    return '枚数: $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'サイズ: $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'サイズ: $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'キューに追加';

  @override
  String get genFootnote => 'ジョブは順番に生成されます。「キュー」タブで確認できます。';

  @override
  String get genDetailsTitle => '詳細 - 空欄可、ロックした項目はシャッフルされません';

  @override
  String genRandomGenerate(Object count) {
    return 'ランダム生成  $count';
  }

  @override
  String get genLockedTooltip => 'ロック中 - シャッフルしても固定';

  @override
  String get genOptionsEmpty => '選択肢のリストが空です';

  @override
  String get genOptional => '任意';

  @override
  String get genUploading => 'アップロード中...';

  @override
  String get genNotSelected => '未選択';

  @override
  String get genFromGallery => 'ギャラリーから';

  @override
  String get genFromFile => 'ファイルから';

  @override
  String get genNoSource => '入力に使える生成がありません。先に画像を生成してください。';

  @override
  String genPickerTitle(Object slot) {
    return '$slot -「生成済み」から選択';
  }

  @override
  String get genPickerSearch => 'プロンプト内を検索';

  @override
  String get genPickerEmpty => 'この種類の完了済み生成はありません。';

  @override
  String optionsFileMissing(Object items) {
    return 'オプションファイルに不足: $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (フィールド定義なし)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'オプションファイルを読み込めませんでした: $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return '$name のオプションファイルを読み込めませんでした: $error';
  }

  @override
  String get fieldLocation => '場所';

  @override
  String get fieldEra => '時代 / 美学';

  @override
  String get fieldWeather => '天気';

  @override
  String get fieldWeatherLight => '天気 / 光';

  @override
  String get fieldJob => '職業';

  @override
  String get fieldFantasy => 'ファンタジー';

  @override
  String get fieldOutfitColor => '衣装の色';

  @override
  String get fieldOutfit => '衣装';

  @override
  String get fieldHair => '髪';

  @override
  String get fieldHairColor => '髪の色';

  @override
  String get fieldHairstyle => '髪型';

  @override
  String get fieldEyes => '目';

  @override
  String get fieldRace => '人種';

  @override
  String get fieldExpression => '表情';

  @override
  String get fieldPose => 'ポーズ';

  @override
  String get fieldAngle => 'アングル';

  @override
  String get fieldStyle => 'スタイル';

  @override
  String get fieldMood => '雰囲気';

  @override
  String get fieldColor => '色';

  @override
  String get fieldCreature => 'クリーチャー';

  @override
  String get fieldClass => 'クラス';

  @override
  String get fieldAge => '年齢';

  @override
  String get fieldOrigin => '出身';

  @override
  String get fieldBody => '体型';

  @override
  String get fieldSkin => '肌';

  @override
  String get fieldFace => '顔';

  @override
  String get fieldGesture => 'ジェスチャー';

  @override
  String get cardNotReady => 'サーバーのエンドポイントはまだ準備できていません';

  @override
  String get cardKindNormal => '通常';

  @override
  String get cardKindDealer => 'ディーラー';

  @override
  String get cardStagePushed => 'プッシュ済み';

  @override
  String get cardStageWebp => 'webp完了';

  @override
  String get cardStageVideo => '動画完了';

  @override
  String get cardStageStill => 'スチル完了';

  @override
  String get cardStageEmpty => '空';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (要確認)';
  }

  @override
  String get cardVideoIntro =>
      '最初のフレーム = 最後のフレーム (ループ)。カメラは固定されます - 構図、スケール、背景は変わりません。出力はまずプールに入り、タグを選ぶとそこにも割り当てられます。';

  @override
  String get cardVideoTemplate => 'テンプレート (テキストを入力)';

  @override
  String get cardVideoMotion => '動きの文 (送信されるプロンプト)';

  @override
  String get cardVideoMotionHelp => '見える動きを記述してください。最後は開始ポーズに戻るようにします';

  @override
  String get cardVideoAssignTag => 'タグに割り当て';

  @override
  String get cardVideoPoolOnly => '(プールのみ - 後で割り当てる)';

  @override
  String get cardVideoNewTag => '新しいタグ...';

  @override
  String get cardVideoNewTagName => '新しいタグ名';

  @override
  String get cardTagHint => '例: victory';

  @override
  String get cardGestureTitle => 'アニメーション - ジェスチャーを選択';

  @override
  String get cardGestureIntro =>
      'MiniMax H3: idle 6秒、victory 2秒。カメラは固定されます - 構図、スケール、背景は変わりません。';

  @override
  String get cardGestureCustom => 'カスタムの動き';

  @override
  String get cardGestureCustomHint => '例: 腰を軽く揺らす、足は固定';

  @override
  String get cardGestureCustomHelp => '短い動きの文 - カメラは固定のまま';

  @override
  String get cardCutTitle => '3 WebP - 切り抜きモード';

  @override
  String get cardCutHybrid => '旧グリーンバックのGrokマスター - クロマ + SAM 併用';

  @override
  String get cardCutSam => '既定 - SAM3のみ、無地のライトグレー背景';

  @override
  String get cardCutAction => '切り抜く';

  @override
  String cardEditTitle(Object name) {
    return '編集 - $name';
  }

  @override
  String get cardEditSentence => '修正の指示文';

  @override
  String get cardEditSentenceHint => '例: 髪を短くする / 手袋を外す';

  @override
  String get cardEditBody =>
      '承認済みのスチルをこの文で編集します。人物の同一性、ポーズ、背景は保持されます。新しい画像は自動的に承認されます。';

  @override
  String get cardEditUnrestricted => '制限なし編集 (NSFW LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Qwenが拒否する場合にオン - MCNL LoRA、20ステップ、少し遅くなります';

  @override
  String cardQueuedJobs(Object count) {
    return 'キューに追加しました ($count 件) -「キュー」タブで確認できます';
  }

  @override
  String get cardQueued => 'キューに追加しました -「キュー」タブで確認できます';

  @override
  String cardQueuedOp(Object op) {
    return 'キューに追加しました (op $op) -「キュー」タブで確認できます';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - 近日対応';
  }

  @override
  String get cardSoonBody =>
      'サーバーのカード用エンドポイントはまだ公開されていません。公開されると、この画面は自動的に使えるようになります。';

  @override
  String get cardNewCollection => '新しいコレクション';

  @override
  String get cardIdLabel => '識別子 (id)';

  @override
  String get cardIdHintCollection => '例: police_royale';

  @override
  String get commonName => '名前';

  @override
  String get cardNameHintCollection => '例: Police Royale';

  @override
  String get cardPickPreset => 'プリセットカードを選択 (任意)';

  @override
  String get cardThemeHint => '例: sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      '書式: アイデンティティ + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'ジョーカー (2枚)';

  @override
  String get cardJokersHint => '13ランクではなく15ランク';

  @override
  String get cardNewCollectionNote =>
      'ランクごとにスチル1枚がキューに入ります (肌 / 髪 / 衣装 / ポーズのローテーション)。確認はありません - 微調整は ✎ / ↻ で行います。';

  @override
  String get cardIdNameRequired => '識別子と名前は空にできません';

  @override
  String get cardNewDealer => '新しいディーラー';

  @override
  String get cardIdHintDealer => '例: scarlett';

  @override
  String get cardNameHintDealer => '例: Scarlett';

  @override
  String get cardDealerTheme => 'テーマ / 衣装';

  @override
  String get cardDealerThemeHint => '例: カジノベストと蝶ネクタイ、ノワール調の赤いドレス';

  @override
  String get cardDealerNote =>
      'ディーラーは上半身の構図で生成されます (手はテーブルの上、カメラ目線)。ランクはなく、1つの項目が4つのステージを通ります。';

  @override
  String get cardNightPickGesture => '夜間モード - ジェスチャーを選択';

  @override
  String get cardNightMode => '夜間モード';

  @override
  String cardNightBody(Object gesture) {
    return 'すべてのカードとディーラーを再アニメーション化します: 現在のスチル -> LTX-2.5 i2v ($gesture) -> SAM切り抜き -> シート。\n\n時間がかかり、すべてキューに入ります。プッシュは行いません。';
  }

  @override
  String get cardRestillTitle => '背景をグレーにする';

  @override
  String get cardRestillBody =>
      'すべてのカードとディーラーのスチル背景を無地のライトグレーに変更します (人物はそのまま)。元の画像は still_green.png として保存され、既にグレーのものはスキップされます。\n\n動画は生成しません。';

  @override
  String get cardManifestPreview => 'マニフェストのプレビュー';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return 'コレクション $collections、ディーラー $dealers';
  }

  @override
  String get cardManifestNote =>
      'マニフェストファイルはプッシュ時に書き込まれます (先にファイル、次にマニフェスト)。これはプレビューのみです。';

  @override
  String get cardCollectionCardSettings => 'コレクションカード (設定)';

  @override
  String get cardCollectionCardSettingsHint => 'テーマ、16スロット、モデル、顔のレタッチ';

  @override
  String get cardReanimate => '再アニメーション化';

  @override
  String get cardReanimateHint => 'スチル -> i2v -> 切り抜き (このコレクション)';

  @override
  String get cardRealify => 'アニメ -> 実写風 (コレクション)';

  @override
  String get cardRealifyHint => '各スチルを edit_qwen で実写風の写真に変換';

  @override
  String get cardDeleteCollection => 'コレクションを削除';

  @override
  String get cardDeleteCollectionHint => 'フォルダーは全カードごと削除されます - 元に戻せません';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'コレクションを削除 - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'ディーラーを削除 - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'コレクションフォルダーは全ファイルごと削除されます。\n\n元に戻せません。R2にプッシュ済みのファイルはバケットに残ります。';

  @override
  String get cardDeleteDealerBody =>
      'ディーラーフォルダーは全ファイルごと削除されます。\n\n元に戻せません。R2にプッシュ済みのファイルはバケットに残ります。';

  @override
  String cardDeletedNamed(Object name) {
    return '$name を削除しました';
  }

  @override
  String get cardDealerCardSettings => 'ディーラーカード (設定)';

  @override
  String get cardDealerCardSettingsHint => 'テーマ、テンプレート、モデル、顔のレタッチ';

  @override
  String get cardDeleteDealer => 'ディーラーを削除';

  @override
  String get cardDeleteDealerHint => 'フォルダーは全ファイルごと削除されます - 元に戻せません';

  @override
  String get cardFlowTitle => 'カードライン';

  @override
  String get cardBulkActions => '一括操作';

  @override
  String get cardNightMenu => '夜間モード: すべて再アニメーション化';

  @override
  String get cardRestillMenu => '背景をグレーにする (すべて)';

  @override
  String get cardManifestMenu => 'マニフェストをプレビュー';

  @override
  String get cardDealers => 'ディーラー';

  @override
  String get cardEmptyCollections =>
      'コレクションはまだありません。\n\n「+ 新しいコレクション」で識別子、名前、テーマを入力すると、13 (または15) ランク分のスチルが1枚ずつキューに入り、その後 2 Video と 3 WebP のステージに進みます。';

  @override
  String get cardEmptyDealers =>
      'ディーラーはまだいません。\n\n「+ 新しいディーラー」で名前、テーマ、ジェスチャーを入力すると、上半身の構図で1つの項目が生成され、4つのステージを通ります。';

  @override
  String cardGestureLine(Object gesture) {
    return 'ジェスチャー: $gesture';
  }

  @override
  String cardAnimateTitle(Object count) {
    return '2 Video ($count 枚)';
  }

  @override
  String cardAnimateBody(Object total) {
    return '各カードに2つのアニメーションを生成し、それぞれのタグに割り当てます:\n• idle - 6秒、制御された1つのジェスチャー\n• victory - 2秒、フレーム内での短い喜びの動き\n合計 $total 本の動画。古いものはプールに残ります。';
  }

  @override
  String get cardEditNeedsOne => '編集は1ランクのみ対象です - カードを1枚選択してください';

  @override
  String cardPushTitle(Object name) {
    return 'プッシュ - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'シートとサムネイルのファイルをR2 (cards) にアップロードし、その後マニフェストを書き込みます。現在 $ready/$total ランクのwebpが完成しています。\n\nこれは公開操作で、元に戻せません。';
  }

  @override
  String get cardPushQueued => 'プッシュをキューに追加しました -「キュー」タブで確認できます';

  @override
  String get cardCollectionCardTooltip => 'コレクションカード - テーマ、16スロット、モデル、顔のレタッチ';

  @override
  String get commonMore => 'その他';

  @override
  String get cardNoThemeTap => 'テーマなし - タップ: コレクションカード';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nコレクションカード: タップ (テーマ、16スロット、モデル、顔のレタッチ)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'コレクションフォルダーは全カードごと削除されます (スチル $stills 枚)。\n\n元に戻せません。R2にプッシュ済みのファイルはバケットに残ります。';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'コレクションフォルダーは全カードごと削除されます (スチル $stills 枚、プッシュ済み $pushed 枚)。\n\n元に戻せません。R2にプッシュ済みのファイルはバケットに残ります。';
  }

  @override
  String get cardClearCards => 'カードをクリア';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - スチル、候補、動画、webpを削除します。ランクは空のまま残ります (「1 Still」で再生成できます)。';
  }

  @override
  String cardsCleared(Object count) {
    return '$count 枚のカードをクリアしました';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count 枚のカードをクリアできませんでした';
  }

  @override
  String get cardGenerateStill => '1 Still を生成';

  @override
  String get cardGenerateVideo => '2 Video を生成';

  @override
  String get cardGenerateWebp => '3 WebP を生成';

  @override
  String get cardBackUpper => '裏面';

  @override
  String cardAssetVideo(Object tag) {
    return '動画 ($tag)';
  }

  @override
  String cardAssetSheet(Object tag) {
    return 'WebP / 切り抜き ($tag)';
  }

  @override
  String cardAssetMissing(Object asset) {
    return '$asset がありません';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return '$asset を削除しますか?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'このタグの動画だけを削除します。プール内のコピー、スチル、webpは残ります。';

  @override
  String get cardAssetDeleteSheetBody =>
      'sheet.webp、サムネイル、切り抜きフレームだけを削除します。動画とスチルは残ります。';

  @override
  String get cardAssetDeleteStillBody => '選択中のスチルだけを削除します。候補、動画、webpは残ります。';

  @override
  String get cardPoolDelete => 'プールから削除';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id をプールから削除します。タグに割り当て済みのコピー ($tags) は残ります。';
  }

  @override
  String get cardNone => 'なし';

  @override
  String get cardNewAnimTag => '新しいアニメーションタグ';

  @override
  String get cardNewAnimTagHelp => 'ゲームはこの名前で読み込みます (idle, wink, victory ...)';

  @override
  String get cardUnassigned => '未割り当て';

  @override
  String cardAssignedTo(Object tags) {
    return '割り当て済み: $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return '割り当て: $name';
  }

  @override
  String get cardAssignNewTag => '新しいタグに割り当て...';

  @override
  String get cardAnimReady => '動画 + webp 完了';

  @override
  String get cardAnimVideoOnly => '動画あり、webpなし';

  @override
  String get cardPoolEmpty => 'プールに動画がありません - 先に「2 Video」を実行してください';

  @override
  String get cardDeleteVideoKeepTag => '動画を削除 (タグは残ります)';

  @override
  String get cardDeleteSheet => 'WebP / 切り抜きを削除';

  @override
  String get cardDeleteTag => 'タグを削除 (動画 + webp ごと)';

  @override
  String cardVideosHeader(Object count) {
    return '動画 ($count) - タップ = 割り当て / プレビュー / 削除';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return '$name のフォルダーは全ファイルごと削除されます。元に戻せません。';
  }

  @override
  String get cardClearCard => 'カードをクリア';

  @override
  String cardClearCardBody(Object name) {
    return '$name: スチル、候補、動画、webp、アニメーションを削除します。ランクは空のまま残ります (「1 Still」で再生成できます)。';
  }

  @override
  String get cardClearCardTooltip => 'カードをクリア (ランクは空に戻ります)';

  @override
  String get cardViewCut => '切り抜き';

  @override
  String cardDeleteThisVideo(Object tag) {
    return 'この動画を削除 ($tag)';
  }

  @override
  String cardDeleteSheetTag(Object tag) {
    return 'WebP / 切り抜きを削除 ($tag)';
  }

  @override
  String get cardDeleteStill => 'スチルを削除';

  @override
  String get cardNoVideo => '動画がありません -「2 Video」で生成してください';

  @override
  String get cardNoCut => '切り抜きがありません -「3 WebP」で生成してください';

  @override
  String get cardCutFrameFailed => '切り抜きフレームを読み込めませんでした';

  @override
  String get cardNoStill => 'スチルがありません -「1 Still」で生成してください';

  @override
  String get cardStillFailed => 'スチルを読み込めませんでした';

  @override
  String cardPromptTitleAge(Object age) {
    return 'プロンプト  ·  $age歳';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - 構図のずれ / ズーム / マスク欠け。動画または切り抜きを再生成してください。';

  @override
  String get cardAnimsHeader => 'アニメーション - タップ = 選択、長押し = 割り当て / 削除';

  @override
  String cardAnimOpened(Object tag) {
    return '「$tag」を作成しました - 2 Video で生成するか、プールから割り当ててください';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return '「$tag」用の動画をプールから選択';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return '候補 ($count) - タップ = 選択';
  }

  @override
  String get cardCandidatePicked => '候補を選択中のスチルにしました';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step: $error';
  }
}

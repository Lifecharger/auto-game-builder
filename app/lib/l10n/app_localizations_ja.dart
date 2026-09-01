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
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get about => 'Hakkında';

  @override
  String get aboutApp => 'Uygulama';

  @override
  String actionTriggered(Object action) {
    return '$action başlatıldı';
  }

  @override
  String get add => 'Ekle';

  @override
  String agentLabelWith(Object agent) {
    return 'Ajan: $agent';
  }

  @override
  String get agentLocal => 'Yerel';

  @override
  String get agentNone => 'Yok';

  @override
  String get agentRunsOnServer =>
      'Ajan, proje düzeyinde erişimle sunucuda çalışır';

  @override
  String agentTriggeredFor(Object agent, Object title) {
    return '\"$title\" için $agent yapay zekâsı başlatıldı';
  }

  @override
  String get aiAgent => 'Yapay Zekâ Ajanı';

  @override
  String get aiAgentUpdated => 'Yapay zekâ ajanı güncellendi';

  @override
  String get aiResponse => 'Yapay Zekâ Yanıtı';

  @override
  String get allApps => 'Tüm Uygulamalar';

  @override
  String get allAppsCompletedOrPostponed =>
      'Tüm uygulamalar tamamlandı veya ertelendi';

  @override
  String get allAppsHaveAutomations => 'Tüm uygulamaların zaten otomasyonu var';

  @override
  String get allAppsHint => 'Tüm uygulamalar';

  @override
  String get allPendingBlocked =>
      'Bekleyen tüm maddeler bağımlılıklar yüzünden engellenmiş';

  @override
  String get apiConnection => 'API Bağlantısı';

  @override
  String get apiUrlSaved => 'API adresi kaydedildi';

  @override
  String get appCreated => 'Uygulama oluşturuldu!';

  @override
  String get appDetail => 'Uygulama Detayı';

  @override
  String get appFallback => 'Uygulama';

  @override
  String get appNameHint => 'Uygulama Adı (örn. Oyunum)';

  @override
  String get appStatusBuilding => 'derleniyor';

  @override
  String get appStatusDeploying => 'dağıtılıyor';

  @override
  String get appStatusError => 'hata';

  @override
  String get appStatusFixing => 'düzeltiliyor';

  @override
  String get appStatusIdle => 'boşta';

  @override
  String get appStatusPublished => 'yayında';

  @override
  String get appStatusQueued => 'sırada';

  @override
  String get appStatusUploading => 'yükleniyor';

  @override
  String get appStatusWorking => 'çalışıyor';

  @override
  String get appTitle => 'Auto Game Builder';

  @override
  String get appTypeFlutterDesc =>
      'Google Play dağıtımı destekli mobil/masaüstü uygulaması';

  @override
  String get appTypeGodotDesc =>
      'Dışa aktarma hedefli oyun projesi (Windows, Android, Web)';

  @override
  String get appTypePhaserDesc =>
      'Phaser 3 + TypeScript oyunu, Capacitor ile Android AAB olarak paketlenir';

  @override
  String get appTypePythonDesc =>
      'Betik çalıştırıcı ve pip yönetimi olan Python projesi';

  @override
  String get appTypeWebDesc =>
      'Statik barındırma dağıtımı destekli web uygulaması';

  @override
  String get apps => 'Uygulamalar';

  @override
  String get archivedLabel => 'arşivlendi';

  @override
  String get artAndAssets => 'Sanat ve Varlıklar';

  @override
  String get artBible => 'Sanat Kılavuzu';

  @override
  String get artBibleCardSubtitle => 'Görsel kimlik referans belgesi';

  @override
  String get artBibleHint =>
      'Kimlik ifadesi, palet (hex), tipografi, yasaklar, teknik özellikler...';

  @override
  String get artBibleSaved => 'Sanat kılavuzu kaydedildi';

  @override
  String get artBibleShort => 'Sanat kılavuzu';

  @override
  String get artBibleSubtitle =>
      'Görsel kimlik çıpası — palet, tipografi, stil yasakları. Her varlık görevi buna dayanır.';

  @override
  String get artBibleTaskCreated => 'Sanat kılavuzu görevi oluşturuldu';

  @override
  String artBibleTitle(Object app) {
    return 'Sanat Kılavuzu - $app';
  }

  @override
  String get askAQuestionHint => 'Bir soru sorun...';

  @override
  String get askAgent => 'Ajana Sor';

  @override
  String get askAnythingAboutYourApps =>
      'Uygulamalarınız hakkında her şeyi sorun';

  @override
  String get assetAudit => 'Varlık Denetimi';

  @override
  String get assetAuditSubtitle =>
      'Kırık referanslar, sahipsiz dosyalar, yer tutucular';

  @override
  String get assetAuditTaskCreated => 'Varlık denetimi görevi oluşturuldu';

  @override
  String get assetSpecTaskCreated => 'Varlık şartnamesi görevi oluşturuldu';

  @override
  String get assetSpecs => 'Varlık Şartnameleri';

  @override
  String get assetSpecsSubtitle => 'Kılavuzdan varlık başına istemler';

  @override
  String get attachments => 'Ekler';

  @override
  String attachmentsCount(Object count) {
    return 'Ekler ($count)';
  }

  @override
  String get automationCreated => 'Otomasyon oluşturuldu';

  @override
  String get automationStateStarted => 'başlatıldı';

  @override
  String get automationStateStopped => 'durduruldu';

  @override
  String automationToggled(Object app, Object state) {
    return '$app $state';
  }

  @override
  String get automationUpdated => 'Otomasyon güncellendi';

  @override
  String get back => 'Geri';

  @override
  String get backend => 'Arka Uç';

  @override
  String get balanceCheck => 'Denge Kontrolü';

  @override
  String get balanceCheckSubtitle => 'Ekonomi, ilerleme, ödüller';

  @override
  String get balanceCheckTaskCreated => 'Denge kontrolü görevi oluşturuldu';

  @override
  String batchRunError(Object error) {
    return 'Toplu çalıştırma sırasında hata: $error';
  }

  @override
  String blockedByList(Object ids) {
    return 'engelleyen: $ids';
  }

  @override
  String blockedByTask(Object id) {
    return '#$id tarafından engellendi';
  }

  @override
  String blockedCountLabel(Object count) {
    return '$count engelli';
  }

  @override
  String blockerNotInList(Object id) {
    return '#$id numaralı görev listede yok (arşivlenmiş veya silinmiş)';
  }

  @override
  String get brainstormAndCreate => 'Fikir Üret ve Oluştur';

  @override
  String get brainstormConceptHint =>
      'Konsept tohumu (örn. \"karınca kolonisi idle oyunu\", \"yer çekimli bulmaca\")';

  @override
  String get brainstormCreated => 'Proje, fikir üretme göreviyle oluşturuldu!';

  @override
  String get brainstormDesc =>
      'Fikir üretme göreviyle yeni bir proje oluşturur. Görev çalıştığında yapay zekâ tam bir GDD ve başlangıç görevleri üretir.';

  @override
  String get brainstormNameHint =>
      'Proje adı (isteğe bağlı — yapay zekâ önerebilir)';

  @override
  String get brainstormNewGame => 'Yeni Oyun İçin Fikir Üret';

  @override
  String get build => 'Derle';

  @override
  String get buildAndDeploy => 'Derle ve Dağıt';

  @override
  String get buildCancelled => 'Derleme iptal edildi';

  @override
  String get buildFailedLabel => 'derleme başarısız';

  @override
  String buildListTitle(Object version, Object buildType) {
    return 'v$version - $buildType';
  }

  @override
  String get buildPollingTimedOut =>
      'Derleme sorgulaması 30 dakika sonra zaman aşımına uğradı - sunucu günlüklerine bakın';

  @override
  String get buildTarget => 'Derleme Hedefi';

  @override
  String get builds => 'Yapımlar';

  @override
  String builtCount(Object count) {
    return 'Yapıldı ($count)';
  }

  @override
  String get buyMeACoffee => 'Bana bir kahve ısmarla';

  @override
  String buyMeACoffeeWithPrice(Object price) {
    return 'Bana bir kahve ısmarla  $price';
  }

  @override
  String get cancel => 'İptal';

  @override
  String get cannotReachServer => 'Sunucuya ulaşılamıyor';

  @override
  String cannotReachServerWith(Object error) {
    return 'Sunucuya ulaşılamıyor: $error';
  }

  @override
  String get cannotSaveEmptyArtBible => 'Boş sanat kılavuzu kaydedilemez';

  @override
  String get cannotSaveEmptyClaudeMd => 'Boş CLAUDE.md kaydedilemez';

  @override
  String get cannotSaveEmptyDesignDoc => 'Boş tasarım belgesi kaydedilemez';

  @override
  String get catBugsCrashes => 'Hatalar ve Çökmeler';

  @override
  String get catCodeStyle => 'Kod Stili';

  @override
  String get catDeadCode => 'Ölü Kod';

  @override
  String get catErrorHandling => 'Hata Yönetimi';

  @override
  String get catMemory => 'Bellek';

  @override
  String get categoryAccessibility => 'Erişilebilirlik';

  @override
  String get categoryBug => 'Hata';

  @override
  String get categoryFeatures => 'Özellikler';

  @override
  String get categoryMonetization => 'Gelir Modeli';

  @override
  String get categoryOther => 'Diğer';

  @override
  String get categoryPerformance => 'Performans';

  @override
  String get categorySecurity => 'Güvenlik';

  @override
  String get categorySuggestion => 'Öneri';

  @override
  String get categoryUiUx => 'UI/UX';

  @override
  String charactersCount(Object count) {
    return '$count karakter';
  }

  @override
  String get chatHistory => 'Sohbet Geçmişi';

  @override
  String get chatLogs => 'Raporlar';

  @override
  String chatSessionSubtitle(Object count, Object date) {
    return '$count mesaj • $date';
  }

  @override
  String get checkBugsCrashes => 'Hatalar ve çökmeler';

  @override
  String get checkCodeStyle => 'Kod stili';

  @override
  String get checkDeadCode => 'Ölü kod';

  @override
  String get checkErrorHandling => 'Hata yönetimi';

  @override
  String get checkMemoryLeaks => 'Bellek sızıntıları';

  @override
  String get checkPerformanceIssues => 'Performans sorunları';

  @override
  String get checkSecurityVulnerabilities => 'Güvenlik açıkları';

  @override
  String get checksToRun => 'Çalıştırılacak kontroller:';

  @override
  String get claudeMdHint =>
      'Proje kuralları, derleme komutları, talimatlar...';

  @override
  String get claudeMdSaved => 'CLAUDE.md kaydedildi';

  @override
  String get claudeMdSubtitle =>
      'Bu uygulamada çalışan yapay zekâ ajanları için proje talimatları.';

  @override
  String claudeMdTitle(Object app) {
    return 'CLAUDE.md - $app';
  }

  @override
  String get clear => 'Temizle';

  @override
  String get clearFilters => 'Filtreleri temizle';

  @override
  String get clearMessages => 'Mesajları Temizle';

  @override
  String clearMessagesConfirm(Object count) {
    return 'Bu sohbetteki $count mesajın tamamı silinsin mi?';
  }

  @override
  String get close => 'Kapat';

  @override
  String get codeCheck => 'Kod Kontrolü';

  @override
  String get codeCheckBody =>
      'Bu, yapay zekâ ajanının kodunuzu incelemesi ve bulguları sorun olarak bildirmesi için bir görev oluşturur.';

  @override
  String get codeCheckRequested => 'Kod kontrolü istendi';

  @override
  String get codeCheckResults => 'Kod Kontrolü Sonuçları';

  @override
  String get codeReview => 'Kod İncelemesi';

  @override
  String get codeReviewSubtitle => 'Hatalar, çökmeler, kod kalitesi';

  @override
  String get complete => 'Tamamla';

  @override
  String completedCount(Object count) {
    return 'Tamamlandı ($count)';
  }

  @override
  String get connectToYourServer => 'Sunucunuza Bağlanın';

  @override
  String get connectYourPhone => 'Telefonunuzu bağlayın';

  @override
  String get connectedSuccessfully => 'Bağlantı kuruldu';

  @override
  String connectedTo(Object server) {
    return '$server sunucusuna bağlanıldı';
  }

  @override
  String get connecting => 'Bağlanılıyor...';

  @override
  String get connectionFailed => 'Bağlantı başarısız';

  @override
  String get connectionSuccessful => 'Bağlantı başarılı!';

  @override
  String get connectionTimedOut => 'Bağlantı zaman aşımına uğradı';

  @override
  String get consistencyCheck => 'Tutarlılık Kontrolü';

  @override
  String get consistencyCheckSubtitle => 'GDD ↔ kod ↔ veri sapması';

  @override
  String get consistencyCheckTaskCreated =>
      'Tutarlılık kontrolü görevi oluşturuldu';

  @override
  String get console => 'Konsol';

  @override
  String get contentAudit => 'İçerik Denetimi';

  @override
  String get contentAuditSubtitle => 'Bölümler, karakterler, eşyalar, metin';

  @override
  String get contentAuditTaskCreated => 'İçerik denetimi görevi oluşturuldu';

  @override
  String get continueLabel => 'Devam';

  @override
  String get control => 'Kontrol';

  @override
  String get copiedToClipboard => 'Panoya kopyalandı';

  @override
  String copiedToClipboardNamed(Object label) {
    return '$label panoya kopyalandı';
  }

  @override
  String get copy => 'Kopyala';

  @override
  String get copyAiResponse => 'Yapay Zekâ Yanıtını Kopyala';

  @override
  String get copyDescription => 'Açıklamayı Kopyala';

  @override
  String get copyTitle => 'Başlığı Kopyala';

  @override
  String get copyUrl => 'Adresi Kopyala';

  @override
  String get couldNotDownloadPdf => 'PDF indirilemedi';

  @override
  String get couldNotLoadBuildTargets => 'Derleme hedefleri yüklenemedi';

  @override
  String get couldNotLoadDirectives => 'Direktifler yüklenemedi';

  @override
  String get couldNotOpenLink => 'Bağlantı açılamadı';

  @override
  String couldNotOpenPdf(Object error) {
    return 'PDF açılamadı: $error';
  }

  @override
  String get couldNotOpenPicker => 'Seçici açılamadı.';

  @override
  String get create => 'Oluştur';

  @override
  String get createApp => 'Uygulama Oluştur';

  @override
  String get createFirstApp => 'Başlamak için ilk uygulamanızı oluşturun';

  @override
  String get createIssue => 'Sorun Oluştur';

  @override
  String createdAgo(Object time) {
    return '$time oluşturuldu';
  }

  @override
  String get creating => 'Oluşturuluyor...';

  @override
  String criticalCount(Object count) {
    return '$count kritik';
  }

  @override
  String get customAutomationPromptHint => 'Özel otomasyon istemi...';

  @override
  String get customPrompt => 'Özel istem';

  @override
  String get dashboard => 'Panel';

  @override
  String get delete => 'Sil';

  @override
  String get deleteAutomation => 'Otomasyonu Sil';

  @override
  String deleteAutomationConfirm(Object app) {
    return '$app otomasyonu kaldırılsın mı?';
  }

  @override
  String get deleteChat => 'Sohbeti Sil';

  @override
  String get deleteChatConfirm => 'Bu konuşma silinsin mi?';

  @override
  String deleteConfirmTitled(Object title) {
    return '\"$title\" silinsin mi?\nBu işlem geri alınamaz.';
  }

  @override
  String get deleteFailed => 'Silme başarısız';

  @override
  String get deleteReportBody =>
      'Bu işlem raporu ve ekran görüntülerini kalıcı olarak siler.';

  @override
  String get deleteReportTitle => 'Rapor silinsin mi?';

  @override
  String get deleted => 'Silindi';

  @override
  String get dependsOn => 'Bağımlılıklar';

  @override
  String get deploy => 'Dağıt';

  @override
  String get deployToProduction => 'Üretime Dağıt';

  @override
  String get deployToProductionBody =>
      'Bu işlem derleyip Google Play üzerindeki TÜM kullanıcılara yayınlar.\n\nÖnce dahili/beta kanalında test ettiğinizden emin olun.';

  @override
  String get deployToProductionTitle => 'Üretime dağıtılsın mı?';

  @override
  String get descriptionHint => 'Açıklama...';

  @override
  String get designDoc => 'Tasarım Belgesi';

  @override
  String get designDocHint =>
      'Uygulama vizyonunuzu, özellikleri ve hedefleri anlatın...';

  @override
  String get designDocSaved => 'Tasarım belgesi kaydedildi';

  @override
  String get designDocShort => 'Tasarım belgesi';

  @override
  String get designDocSubtitle =>
      'Yapay zekâ bunu, bu uygulamadaki tüm işler için bağlam olarak kullanır.';

  @override
  String designDocTitle(Object app) {
    return 'Tasarım Belgesi - $app';
  }

  @override
  String get designDocument => 'Tasarım Belgesi';

  @override
  String get designReview => 'Tasarım İncelemesi';

  @override
  String get designReviewSubtitle => 'GDD, mekanikler, UX denetimi';

  @override
  String get designReviewTaskCreated => 'Tasarım incelemesi görevi oluşturuldu';

  @override
  String get details => 'Ayrıntılar';

  @override
  String get detectingServer => 'Sunucu aranıyor...';

  @override
  String get developer => 'Geliştirici';

  @override
  String get directServerUrlLan => 'Doğrudan Sunucu Adresi (LAN)';

  @override
  String get directiveHistory => 'Direktif geçmişi';

  @override
  String get dismiss => 'Kapat';

  @override
  String get display => 'Görünüm';

  @override
  String get doIt => 'Yap';

  @override
  String get done => 'Tamam';

  @override
  String doneOfTotal(Object done, Object total) {
    return '$done / $total tamamlandı';
  }

  @override
  String durationLabelWith(Object seconds) {
    return 'Süre: ${seconds}sn';
  }

  @override
  String get edit => 'Düzenle';

  @override
  String editNamed(Object label) {
    return '$label düzenle';
  }

  @override
  String editTitleNamed(Object app) {
    return 'Düzenle: $app';
  }

  @override
  String get editWorkerUrl => 'Worker Adresini Düzenle';

  @override
  String get engine => 'Motor';

  @override
  String engineChanged(Object previous, Object current) {
    return 'Motor değişti: $previous -> $current';
  }

  @override
  String engineConfirmed(Object engine) {
    return 'Motor doğrulandı: $engine';
  }

  @override
  String get engineDetectionFailed => 'Motor algılama başarısız';

  @override
  String get enhance => 'Geliştir';

  @override
  String get enhanceConfirmBody =>
      'Yapay zekâ belgeyi yeniden yazacak. Bu işlem geri alınamaz.';

  @override
  String enhanceConfirmTitle(Object label) {
    return '$label geliştirilsin mi?';
  }

  @override
  String enhanceError(Object label, Object error) {
    return '$label geliştirme hatası: $error';
  }

  @override
  String enhanceStarted(Object label) {
    return '$label geliştirmesi sunucuda başladı...';
  }

  @override
  String enhanceSucceeded(Object label) {
    return '$label başarıyla geliştirildi';
  }

  @override
  String get enhancementFailed => 'Geliştirme başarısız';

  @override
  String get enterConceptOrName => 'Bir konsept veya proje adı girin';

  @override
  String get enterServerUrlDesc =>
      'Auto Game Builder sunucunuzun adresini girin';

  @override
  String get enterUrlInPhoneApp =>
      'Uzaktan bağlanmak için bu adresi telefon uygulamasına girin';

  @override
  String get enterValidUrl =>
      'Geçerli bir adres girin (örn. http://192.168.1.100:8000)';

  @override
  String get enterWorkerUrlDesc =>
      'Uzaktan bağlanmak için Worker adresinizi girin';

  @override
  String errorWithMessage(Object error) {
    return 'Hata: $error';
  }

  @override
  String everyMinutes(Object minutes) {
    return 'Her $minutes dk';
  }

  @override
  String exitLabelWith(Object code) {
    return 'Çıkış: $code';
  }

  @override
  String get expandFoldersOrCreate =>
      'Aşağıdaki klasörleri açın veya yeni bir uygulama oluşturun';

  @override
  String get failed => 'Başarısız';

  @override
  String failedCountLabel(Object count) {
    return '$count başarısız';
  }

  @override
  String get failedToBrainstorm => 'Fikir üretilemedi';

  @override
  String get failedToCreateApp => 'Uygulama oluşturulamadı';

  @override
  String get failedToCreateItem => 'Madde oluşturulamadı';

  @override
  String get failedToCreateTestTask => 'Test görevi oluşturulamadı';

  @override
  String get failedToDelete => 'Silinemedi';

  @override
  String get failedToLoadApp => 'Uygulama yüklenemedi';

  @override
  String get failedToLoadAutomations => 'Otomasyonlar yüklenemedi';

  @override
  String get failedToLoadLogs => 'Günlükler yüklenemedi';

  @override
  String get failedToLoadTasks => 'Görevler yüklenemedi';

  @override
  String failedToLoadWithError(Object error) {
    return 'Yüklenemedi: $error';
  }

  @override
  String get failedToRefreshApp => 'Uygulama yenilenemedi';

  @override
  String get failedToRequestCodeCheck => 'Kod kontrolü istenemedi';

  @override
  String get failedToRequestIdeas => 'Fikir istenemedi';

  @override
  String get failedToReset => 'Sıfırlanamadı';

  @override
  String get failedToRunTask => 'Görev çalıştırılamadı';

  @override
  String failedToSave(Object error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String get failedToStartReupload => 'Yeniden yükleme başlatılamadı';

  @override
  String failedToStartServer(Object error) {
    return 'Sunucu başlatılamadı: $error';
  }

  @override
  String failedToStartWithError(Object error) {
    return 'Başlatılamadı: $error';
  }

  @override
  String failedToTrigger(Object action) {
    return '$action tetiklenemedi';
  }

  @override
  String get failedToTriggerRun => 'Çalıştırma tetiklenemedi';

  @override
  String get failedToUpdate => 'Güncellenemedi';

  @override
  String get failedToUpdateAiAgent => 'Yapay zekâ ajanı güncellenemedi';

  @override
  String get failedToUpdateMcp => 'MCP güncellenemedi';

  @override
  String get favoritesOnly => 'Sadece favoriler';

  @override
  String get feedback => 'Geri Bildirim';

  @override
  String fileTooLarge(Object max, Object files) {
    return 'Çok büyük (en fazla $max MB): $files';
  }

  @override
  String get filterAll => 'Tümü';

  @override
  String get filterClosed => 'Kapalı';

  @override
  String get filterOpen => 'Açık';

  @override
  String findingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bulgu',
      one: '1 bulgu',
    );
    return '$_temp0';
  }

  @override
  String finishedDoneAgo(Object time) {
    return '$time bitti';
  }

  @override
  String finishedFailedAgo(Object time) {
    return '$time başarısız oldu';
  }

  @override
  String forceRefreshFailed(Object error) {
    return 'Zorunlu yenileme başarısız: $error';
  }

  @override
  String get forceRefreshTooltip =>
      'Sunucudan zorla yenile (yerel önbelleği temizler)';

  @override
  String get fullAutoMode => 'Tam Otomatik Mod';

  @override
  String get fullAutoModeOn =>
      'Yapay zekâ görevleri okur, düzeltir, yeni fikirler üretir ve tekrarlar';

  @override
  String get generate => 'Üret';

  @override
  String get generateIdeas => 'Fikir Üret';

  @override
  String get generateIdeasHint => 'örn. \"Arayüzü iyileştirme fikirleri\"';

  @override
  String get genre => 'Tür';

  @override
  String get genreAction => 'Aksiyon';

  @override
  String get genreAny => 'Fark etmez';

  @override
  String get genreArcade => 'Arcade';

  @override
  String get genreCardGame => 'Kart Oyunu';

  @override
  String get genreIdleClicker => 'Idle/Tıklama';

  @override
  String get genrePuzzle => 'Bulmaca';

  @override
  String get genreRpg => 'RPG';

  @override
  String get genreSimulation => 'Simülasyon';

  @override
  String get genreStrategy => 'Strateji';

  @override
  String get genreTowerDefense => 'Kule Savunma';

  @override
  String get getStarted => 'Başla';

  @override
  String get googleAccount => 'Google Hesabı';

  @override
  String get hide => 'Gizle';

  @override
  String highCount(Object count) {
    return '$count yüksek';
  }

  @override
  String get ideaGenerationRequested => 'Fikir üretimi istendi';

  @override
  String get installed => 'kurulu';

  @override
  String get intervalMinLabel => 'Aralık (dk): ';

  @override
  String get invalidQrData => 'Geçersiz QR kod verisi';

  @override
  String get issueCreated => 'Sorun oluşturuldu';

  @override
  String get issueTitleHint => 'Sorun başlığı';

  @override
  String get issues => 'Sorunlar';

  @override
  String get itemCreated => 'Madde oluşturuldu';

  @override
  String get justNow => 'Az önce';

  @override
  String get language => 'Dil';

  @override
  String get later => 'Sonra';

  @override
  String get links => 'Bağlantılar';

  @override
  String get loginTagline => 'Oyun projelerinizi her yerden yönetin';

  @override
  String get logs => 'Günlükler';

  @override
  String get maintenanceOnly => 'Yalnızca bakım';

  @override
  String get markAsCompleted => 'Tamamlandı Olarak İşaretle';

  @override
  String get markComplete => 'Tamamlandı İşaretle';

  @override
  String markCompleteConfirm(Object title) {
    return '\"$title\" tamamlandı olarak işaretlensin mi?';
  }

  @override
  String get markedAsCompleted => 'Tamamlandı olarak işaretlendi';

  @override
  String maxMinutes(Object minutes) {
    return 'En fazla $minutes dk';
  }

  @override
  String get maxSessionMinLabel => 'En uzun oturum (dk): ';

  @override
  String get mcpConfiguredPerApp =>
      'MCP sunucuları uygulama detay sayfasından uygulama bazında ayarlanır.';

  @override
  String get mcpServers => 'MCP Sunucuları';

  @override
  String mcpServersActive(Object count) {
    return 'MCP Sunucuları ($count etkin)';
  }

  @override
  String get mcpServersDesc =>
      'Bu uygulamadaki tüm yapay zekâ çalıştırmalarında kullanılabilen araç sunucuları';

  @override
  String mediumCount(Object count) {
    return '$count orta';
  }

  @override
  String get moveBackToActive => 'Etkine Geri Taşı';

  @override
  String get moveToCompletedFolder => 'Tamamlananlar klasörüne taşı';

  @override
  String get nameIsRequired => 'Ad zorunludur';

  @override
  String get needHelpSettingUp => 'Kurulumda yardım gerekiyor mu?';

  @override
  String get newApp => 'Yeni Uygulama';

  @override
  String get newAutomation => 'Yeni Otomasyon';

  @override
  String get newChat => 'Yeni Sohbet';

  @override
  String get newItem => 'Yeni Madde';

  @override
  String get newPrompt => 'Yeni istem';

  @override
  String newReportsCount(Object count) {
    return '$count yeni rapor';
  }

  @override
  String get nextRunIn => 'Sonraki çalıştırmaya kalan';

  @override
  String get noApiKeyFound =>
      'API anahtarı bulunamadı — bir tane üretmek için sunucuyu yeniden başlatın';

  @override
  String get noAppsMatch => 'Eşleşen uygulama yok';

  @override
  String get noAppsYet => 'Henüz uygulama yok';

  @override
  String get noArtBibleYet =>
      'Henüz sanat kılavuzu yok. Görsel kimliği tanımlamak için Ekle düğmesine dokunun — palet, tipografi, yasaklar.';

  @override
  String get noAutomationsMatchFilters => 'Filtrelerle eşleşen otomasyon yok';

  @override
  String get noAutomationsYet => 'Henüz otomasyon yok';

  @override
  String noBuildTargetsFor(Object type) {
    return '$type projeleri için derleme hedefi yok.';
  }

  @override
  String get noBuildsYet => 'Henüz yapım yok';

  @override
  String get noChatsYet => 'Henüz sohbet yok';

  @override
  String get noClaudeMdYet =>
      'Henüz CLAUDE.md yok. Yapay zekâ için proje talimatlarını belirlemek üzere Ekle düğmesine dokunun.';

  @override
  String get noDesignDocYet =>
      'Henüz tasarım belgesi yok. Uygulama vizyonunuzu anlatmak için Ekle düğmesine dokunun.';

  @override
  String get noDirectivesYet => 'Henüz direktif gönderilmedi.';

  @override
  String get noFavoritePrompts => 'Henüz favori istem yok';

  @override
  String get noItemsFound => 'Madde bulunamadı';

  @override
  String get noLogsFound => 'Günlük bulunamadı';

  @override
  String get noNewReports => 'Yeni rapor yok';

  @override
  String get noOpenReports => 'Açık rapor yok';

  @override
  String get noOpenTasksToDependOn => 'Bağımlılık kurulacak açık görev yok';

  @override
  String get noPendingItems => 'Üzerinde çalışılacak bekleyen madde yok';

  @override
  String get noPromptHistory =>
      'Henüz istem geçmişi yok.\nGeçmiş oluşturmak için fikir üretin.';

  @override
  String get noReportsHere => 'Burada rapor yok';

  @override
  String get noWorkerUrlDetected =>
      'settings.json içinde Worker adresi bulunamadı.\nUzaktan erişimi etkinleştirmek için bir Cloudflare Worker kurun.';

  @override
  String get notAvailableShort => 'Yok';

  @override
  String get notConfigured => 'Ayarlanmadı';

  @override
  String get notConnected => 'Bağlı değil';

  @override
  String get notInstalled => 'kurulu değil';

  @override
  String get notPaired => 'Eşleştirilmedi';

  @override
  String get notSet => '(ayarlanmadı)';

  @override
  String get notYetUploaded => 'henüz yüklenmedi';

  @override
  String get onHold => 'Beklemede';

  @override
  String get oneShotRunEndsIn => 'Tek seferlik çalıştırmanın bitmesine';

  @override
  String oneTimeRunTriggered(Object app) {
    return '$app için tek seferlik çalıştırma başlatıldı';
  }

  @override
  String openCountLabel(Object count) {
    return '$count açık';
  }

  @override
  String get openPdf => 'PDF Aç';

  @override
  String get openingPdf => 'PDF açılıyor…';

  @override
  String get orSeparator => 'VEYA';

  @override
  String get output => 'Çıktı';

  @override
  String get packageName => 'Paket Adı';

  @override
  String get paired => 'Eşleştirildi';

  @override
  String get pairedSuccessfully => 'Eşleştirme başarılı!';

  @override
  String get perfProfileTaskCreated => 'Performans profili görevi oluşturuldu';

  @override
  String get performanceProfile => 'Performans Profili';

  @override
  String get performanceProfileSubtitle =>
      'Kare düşmeleri, bellek, yükleme süresi';

  @override
  String get photo => 'Fotoğraf';

  @override
  String get postpone => 'Ertele';

  @override
  String postponedCount(Object count) {
    return 'Ertelendi ($count)';
  }

  @override
  String get pressBackAgainToExit => 'Çıkmak için geri tuşuna tekrar basın';

  @override
  String get previousChat => 'Önceki Sohbet';

  @override
  String get priority => 'Öncelik';

  @override
  String processingTasks(Object done, Object total) {
    return '$total görevden $done tanesi işleniyor...';
  }

  @override
  String get projectPath => 'Proje Yolu';

  @override
  String get promptHistory => 'İstem Geçmişi';

  @override
  String get promptHistoryTooltip => 'İstem geçmişi';

  @override
  String get publish => 'Yayın';

  @override
  String get pullAndRebuild => 'Çek ve Yeniden Derle';

  @override
  String get pullFailed => 'Çekme başarısız';

  @override
  String get pullNow => 'Şimdi çek';

  @override
  String get pullOnly => 'Sadece Çek';

  @override
  String purchaseFailed(Object error) {
    return 'Satın alma başarısız: $error';
  }

  @override
  String get putOnHoldForLater => 'Sonrası için beklemeye al';

  @override
  String get pythonSectionDesc =>
      'Sunucu üzerinden betikleri çalıştırın ve Python projesini yönetin.';

  @override
  String get quickIssue => 'Hızlı Sorun';

  @override
  String get rePairWithQr => 'QR Kod ile Yeniden Eşleştir';

  @override
  String get rebuild => 'Yeniden Derle';

  @override
  String get rebuildBody => 'Sıfırdan yeni bir derleme başlatılsın mı?';

  @override
  String get rebuildTitle => 'Yeniden derlensin mi?';

  @override
  String get recentBuilds => 'Son Yapımlar';

  @override
  String get refresh => 'Yenile';

  @override
  String refreshFailedShowingCached(Object message) {
    return 'Yenileme başarısız — son eşitlenen veriler gösteriliyor. $message';
  }

  @override
  String get refreshedFromServer => 'Sunucudan yenilendi';

  @override
  String get reload => 'Yeniden yükle';

  @override
  String get reopen => 'Yeniden Aç';

  @override
  String get reportBugOrSuggestion => 'Hata / Öneri Bildir';

  @override
  String get reportBugSubtitle =>
      'Neyi düzeltmemizi veya eklememizi istediğinizi yazın';

  @override
  String get shareUsageStats => 'Anonim kullanım istatistiklerini paylaş';

  @override
  String get shareUsageStatsDesc =>
      'Oturumların ve açılan ekranların anonim sayımları. Proje adı, görev metni veya yol bilgisi gönderilmez.';

  @override
  String get reportConsent =>
      'Bu raporun cihaz bilgilerimle (model, işletim sistemi ve uygulama sürümü) birlikte, sorunların giderilmesine yardımcı olmak üzere geliştiriciye gönderilmesini kabul ediyorum.';

  @override
  String get reportHint => 'Ne oldu ya da ne görmek istersiniz?';

  @override
  String get reportSentThanks => 'Teşekkürler! Raporunuz gönderildi.';

  @override
  String get reset => 'Sıfırla';

  @override
  String get resetServer => 'Sunucuyu Sıfırla';

  @override
  String get resetServerBody => 'Bu işlem arka uç sunucusunu yeniden başlatır.';

  @override
  String resetServerRunningNote(Object count) {
    return 'Otomatik yeniden başlamayı önlemek için önce çalışan $count otomasyon durdurulacak.';
  }

  @override
  String get resumeActiveDevelopment => 'Etkin geliştirmeye devam et';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get retryUpload => 'Yüklemeyi Yeniden Dene';

  @override
  String get reuploadStarted => 'Yeniden yükleme başladı';

  @override
  String get run => 'Çalıştır';

  @override
  String get runAgainBody =>
      'Tek seferlik bir çalıştırma zaten sürüyor ancak yapay zekâ erken durmuş olabilir. Yeni bir çalıştırma başlatılsın mı?';

  @override
  String get runAgainTitle => 'Tekrar çalıştırılsın mı?';

  @override
  String get runAnyway => 'Yine de Çalıştır';

  @override
  String get runCheck => 'Kontrolü Çalıştır';

  @override
  String get runOnce => 'Bir Kez Çalıştır';

  @override
  String get runOnceInProgress => 'Bir Kez Çalıştır (sürüyor)';

  @override
  String get running => 'Çalışıyor';

  @override
  String get save => 'Kaydet';

  @override
  String get saveChanges => 'Değişiklikleri Kaydet';

  @override
  String get saveEmptyGddBody => 'Bu işlem mevcut tasarım belgesini siler.';

  @override
  String get saveEmptyGddTitle => 'Boş GDD kaydedilsin mi?';

  @override
  String get saving => 'Kaydediliyor...';

  @override
  String scanError(Object error) {
    return 'Tarama hatası: $error';
  }

  @override
  String scanFailedStatus(Object status) {
    return 'Tarama başarısız: sunucu $status döndürdü';
  }

  @override
  String get scanForProjects => 'Projeleri tara';

  @override
  String get scanPairingQrTitle => 'Eşleştirme QR Kodunu Tara';

  @override
  String get scanQrToPair => 'Eşleştirmek İçin QR Kod Tara';

  @override
  String scanResult(Object found, Object imported, Object skipped) {
    return '$found klasör tarandı: $imported içe aktarıldı, $skipped atlandı';
  }

  @override
  String get scanThisQr => 'Bu QR kodu telefonunuzdan tarayın';

  @override
  String get scanToInstall => 'Telefonunuza kurmak için tarayın';

  @override
  String get scopeCheck => 'Kapsam Kontrolü';

  @override
  String get scopeCheckSubtitle => 'Çıkarma listesi + gerçekçilik denetimi';

  @override
  String get scopeCheckTaskCreated => 'Kapsam kontrolü görevi oluşturuldu';

  @override
  String get screenshotsOptional => 'Ekran görüntüleri (isteğe bağlı)';

  @override
  String get screenshotsTooLarge =>
      'Ekran görüntüleri büyük — birini kaldırmanız gerekebilir.';

  @override
  String get searchAppsHint => 'Uygulama ara...';

  @override
  String searchFilterChip(Object query) {
    return 'Arama: \"$query\"';
  }

  @override
  String get searchHint => 'Ara...';

  @override
  String get sectionAiAgents => 'Yapay Zekâ Ajanları';

  @override
  String get sectionGameEngines => 'Oyun Motorları';

  @override
  String get sectionPaths => 'Yollar';

  @override
  String get sectionServices => 'Servisler';

  @override
  String get sectionSystemTools => 'Sistem Araçları';

  @override
  String get selectAnApp => 'Bir uygulama seçin';

  @override
  String get selectAnAppFirst => 'Önce bir uygulama seçin';

  @override
  String get selectApp => 'Uygulama seç';

  @override
  String get selectAppForContext =>
      'Bağlam için bir uygulama seçin veya genel sorular sorun';

  @override
  String get selectAppToViewItems => 'Maddeleri görmek için bir uygulama seçin';

  @override
  String get selectCategoriesOrPrompt =>
      'Kategori seçin veya kendi isteminizi yazın.';

  @override
  String get sendReport => 'Raporu gönder';

  @override
  String get sending => 'Gönderiliyor…';

  @override
  String get server => 'Sunucu';

  @override
  String get serverConfiguration => 'Sunucu Yapılandırması';

  @override
  String get serverConnection => 'Sunucu Bağlantısı';

  @override
  String serverReturnedStatus(Object status) {
    return 'Sunucu $status durum kodu döndürdü';
  }

  @override
  String get serverStarted => 'Sunucu başlatıldı!';

  @override
  String get serverStartedHealthFailed =>
      'Sunucu başlatıldı ancak sağlık kontrolü başarısız';

  @override
  String get serverStopped => 'Sunucu durduruldu';

  @override
  String get serverUnreachable => 'Sunucuya ulaşılamıyor';

  @override
  String get serverUrl => 'Sunucu Adresi';

  @override
  String get sessionEndsIn => 'Oturumun bitmesine';

  @override
  String get sessionRefreshed => 'Oturum yenilendi — son bağlam korundu';

  @override
  String get settings => 'Ayarlar';

  @override
  String get settingsJsonNotFound => 'settings.json bulunamadı';

  @override
  String get settingsJsonRestartNote =>
      'settings.json — değişikliklerden sonra sunucuyu yeniden başlatın';

  @override
  String get settingsSavedRestart =>
      'Ayarlar kaydedildi — uygulamak için sunucuyu yeniden başlatın';

  @override
  String get setupInstructions => 'Kurulum Talimatları';

  @override
  String get setupServerFirst => 'Önce bilgisayarınızda sunucuyu kurun';

  @override
  String get setupStepCloneRepo => 'Depoyu klonlayın:';

  @override
  String get setupStepEnterUrl =>
      'Terminalde görünen adresi girin (örn. http://192.168.1.100:8000):';

  @override
  String get setupStepInstallDeps => 'Bağımlılıkları kurun:';

  @override
  String get setupStepInstallPython => 'Bilgisayarınıza Python 3.10+ kurun';

  @override
  String get setupStepRunWizard => 'Kurulum sihirbazını çalıştırın:';

  @override
  String get setupStepStartServer => 'Sunucuyu başlatın:';

  @override
  String get show => 'Göster';

  @override
  String get showAll => 'Tümünü göster';

  @override
  String get showAppIcons => 'Uygulama simgelerini göster';

  @override
  String get showAppIconsDesc =>
      'Panelde genel tür simgeleri yerine gerçek uygulama simgelerini göster';

  @override
  String get showPairingQr => 'Eşleştirme QR Kodunu Göster';

  @override
  String get signInCancelled => 'Oturum açma iptal edildi';

  @override
  String signInFailed(Object error) {
    return 'Oturum açılamadı: $error';
  }

  @override
  String get signInWithGoogle => 'Google ile oturum aç';

  @override
  String get signOut => 'Oturumu Kapat';

  @override
  String get signingIn => 'Oturum açılıyor...';

  @override
  String get skipForNow => 'Şimdilik atla';

  @override
  String get start => 'Başlat';

  @override
  String get startBuildFromCardAbove =>
      'Yukarıdaki karttan bir derleme başlatın';

  @override
  String get startServer => 'Sunucuyu Başlat';

  @override
  String get startServerNotFound => 'start_server.py bulunamadı';

  @override
  String get status => 'Durum';

  @override
  String get statusActive => 'Etkin';

  @override
  String get statusAll => 'Tümü';

  @override
  String get statusBuilt => 'Yapıldı';

  @override
  String get statusBuiltLower => 'Yapıldı';

  @override
  String get statusCompleted => 'Tamamlandı';

  @override
  String get statusDivided => 'Bölündü';

  @override
  String get statusDone => 'Bitti';

  @override
  String get statusFailedLower => 'Başarısız';

  @override
  String statusFilterChip(Object value) {
    return 'Durum: $value';
  }

  @override
  String get statusInProgress => 'Sürüyor';

  @override
  String get statusPending => 'Bekliyor';

  @override
  String get statusPendingLower => 'Bekliyor';

  @override
  String get statusPostponed => 'Ertelendi';

  @override
  String get stop => 'Durdur';

  @override
  String get stopServer => 'Sunucuyu Durdur';

  @override
  String get stoppedLabel => 'Durduruldu';

  @override
  String stuckSuffix(Object time) {
    return '$time TAKILDI';
  }

  @override
  String stuckTasksAutoFailed(Object count) {
    return '30 dakikalık zaman aşımı sonrası $count takılı görev otomatik olarak başarısız işaretlendi';
  }

  @override
  String get studioReviews => 'Stüdyo İncelemeleri';

  @override
  String get submit => 'Gönder';

  @override
  String get submitting => 'Gönderiliyor...';

  @override
  String get suggestApiBackend => 'API ve Arka Uç';

  @override
  String get suggestFeatureIntegration => 'Özellik Entegrasyonu';

  @override
  String get suggestFixFailures => 'Hataları Gider';

  @override
  String get suggestGddAligned => 'GDD Uyumlu';

  @override
  String get suggestImproveCodebase => 'Kod Tabanını İyileştir';

  @override
  String get suggestNextMilestone => 'Sonraki Kilometre Taşı';

  @override
  String get suggestPerformanceBoost => 'Performans Artışı';

  @override
  String get suggestRevenueIdeas => 'Gelir Fikirleri';

  @override
  String get suggestSecurityHardening => 'Güvenlik Sıkılaştırma';

  @override
  String get suggestTaskPrioritization => 'Görev Önceliklendirme';

  @override
  String get suggestTestingQa => 'Test ve Kalite';

  @override
  String get suggestUserEngagement => 'Kullanıcı Etkileşimi';

  @override
  String get suggestUxPolish => 'UX Cilası';

  @override
  String get suggestedForYou => 'Sizin için önerilenler';

  @override
  String get summary => 'Özet';

  @override
  String get supportDevelopment => 'Geliştirmeyi Destekle';

  @override
  String get supportDevelopmentDesc =>
      'Uygulamayı beğendiniz mi? Geliştirmeyi desteklemeyi düşünün!';

  @override
  String get syncFailed => 'Eşitleme başarısız';

  @override
  String syncedAgo(Object time) {
    return '$time eşitlendi';
  }

  @override
  String get tapPlusToCreateAutomation =>
      'İlk otomasyonunuzu oluşturmak için + düğmesine dokunun';

  @override
  String get tapPlusToStartConversation =>
      'Konuşma başlatmak için + düğmesine dokunun';

  @override
  String get tapToAddLongPressToEdit =>
      'Eklemek için dokunun, düzenlemek için basılı tutun';

  @override
  String get tapToOpenLongPressToEdit =>
      'Açmak için dokunun, düzenlemek için basılı tutun';

  @override
  String get tapToRedetectEngine =>
      'Motoru diskten yeniden algılamak için dokunun';

  @override
  String taskLabelWith(Object task) {
    return 'Görev: $task';
  }

  @override
  String get taskOverview => 'Görev Özeti';

  @override
  String get taskResetToPending => 'Görev bekliyor durumuna sıfırlandı';

  @override
  String get tasks => 'Görevler';

  @override
  String get techDebtScan => 'Teknik Borç Taraması';

  @override
  String get techDebtScanSubtitle => 'Şişkin betikler, tekrarlar, TODO’lar';

  @override
  String get techDebtTaskCreated => 'Teknik borç taraması görevi oluşturuldu';

  @override
  String get tellUsMore => 'Biraz daha anlatın';

  @override
  String get test => 'Test';

  @override
  String get testConnection => 'Bağlantıyı Test Et';

  @override
  String get testTaskCreated => 'Test görevi oluşturuldu';

  @override
  String get testing => 'Test ediliyor...';

  @override
  String get theme => 'Tema';

  @override
  String get thinking => 'Düşünüyor...';

  @override
  String timeDaysAgo(Object days) {
    return '$days gün önce';
  }

  @override
  String timeHoursAgo(Object hours) {
    return '$hours sa önce';
  }

  @override
  String get timeJustNow => 'az önce';

  @override
  String timeMinutesAgo(Object minutes) {
    return '$minutes dk önce';
  }

  @override
  String timeMonthsAgo(Object months) {
    return '$months ay önce';
  }

  @override
  String timeSecondsAgo(Object seconds) {
    return '$seconds sn önce';
  }

  @override
  String timeWeeksAgo(Object weeks) {
    return '$weeks hf önce';
  }

  @override
  String get titleHint => 'Başlık';

  @override
  String get titleIsRequired => 'Başlık zorunludur';

  @override
  String get trackAlpha => 'Alfa';

  @override
  String get trackBeta => 'Beta';

  @override
  String get trackInternal => 'Dahili';

  @override
  String get trackProd => 'Üretim';

  @override
  String triggeredOfItems(Object done, Object total) {
    return '$total maddeden $done tanesi tetiklendi';
  }

  @override
  String get tryChangingFilters =>
      'Kategori veya durum filtresini değiştirmeyi deneyin';

  @override
  String get type => 'Tür';

  @override
  String get typeBug => 'Hata';

  @override
  String get typeFeature => 'Özellik';

  @override
  String typeFilterChip(Object value) {
    return 'Tür: $value';
  }

  @override
  String get typeFix => 'Düzeltme';

  @override
  String get typeIdea => 'Fikir';

  @override
  String get typeIssue => 'Sorun';

  @override
  String get updateAvailable => 'Güncelleme Mevcut';

  @override
  String get updateAvailableBody =>
      'GitHub üzerinde yeni bir sürüm var.\nGüncellemek için son kodu çekip yeniden derleyin.';

  @override
  String get updateFailed => 'Güncelleme başarısız';

  @override
  String updatedAgo(Object time) {
    return '$time güncellendi';
  }

  @override
  String updatedNamed(Object label) {
    return '$label güncellendi';
  }

  @override
  String get uploadToGooglePlay => 'Google Play’e yükle';

  @override
  String urgentCountLabel(Object count) {
    return '$count acil';
  }

  @override
  String get urgentLabel => 'acil';

  @override
  String get userFallback => 'Kullanıcı';

  @override
  String get version => 'Sürüm';

  @override
  String versionWithNumber(Object version) {
    return 'v$version';
  }

  @override
  String get viewFailedTasks => 'Başarısız görevleri gör';

  @override
  String get viewIssues => 'Sorunları gör';

  @override
  String get viewOnGitHub => 'GitHub’da görüntüle';

  @override
  String get warningPublishesToAll => 'Uyarı: Bu, tüm kullanıcılara yayınlar!';

  @override
  String get webDeploy => 'Web Dağıtımı';

  @override
  String get webDeploySectionDesc =>
      'Web uygulamasını sunucu üzerinden derleyip dağıtın.';

  @override
  String get website => 'Web Sitesi';

  @override
  String get whatIsThis => 'Bu nedir?';

  @override
  String get workOnAll => 'Tümü Üzerinde Çalış';

  @override
  String workOnAllBlockedNote(Object count) {
    return '\n(Engellenen $count madde atlanacak.)';
  }

  @override
  String workOnAllConfirm(Object count) {
    return 'Bekleyen $count maddenin tamamında yapay zekâ çalıştırılsın mı?\nSırayla işlenecekler.';
  }

  @override
  String get workOnAllPending => 'Bekleyenlerin Tümü Üzerinde Çalış';

  @override
  String get workOnThis => 'Bunun Üzerinde Çalış';

  @override
  String workOnThisConfirm(Object agent, Object title) {
    return '$agent yapay zekâsı şunun üzerinde çalıştırılsın mı:\n\"$title\"';
  }

  @override
  String get workerUrl => 'Worker Adresi';

  @override
  String get workerUrlAutoDetected =>
      'settings.json içinden otomatik algılandı (salt okunur)';

  @override
  String get workerUrlCopied => 'Worker adresi kopyalandı';

  @override
  String get workerUrlHelp =>
      'Bu adresi masaüstü uygulamasından veya sunucu yöneticinizden alın';

  @override
  String get workerUrlSaved => 'Worker adresi kaydedildi';

  @override
  String get workerUrlSetHint =>
      'server/config/settings.json içinde cloudflare.worker_url değerini ayarlayın';

  @override
  String get youreAllSet => 'Her Şey Hazır!';

  @override
  String agentsMdTitle(Object app) {
    return 'AGENTS.md - $app';
  }

  @override
  String get noAgentsMdYet =>
      'Henüz AGENTS.md yok. Yapay zekâ için proje talimatlarını belirlemek üzere Ekle düğmesine dokunun.';

  @override
  String get cannotSaveEmptyAgentsMd => 'Boş AGENTS.md kaydedilemez';

  @override
  String get agentsMdSaved => 'AGENTS.md kaydedildi';

  @override
  String get reportEmailLabel => 'E-posta (isteğe bağlı)';

  @override
  String get reportEmailHint => 'yanıt istersen e-posta adresin';

  @override
  String get reportEmailNote =>
      'Yalnızca bu rapora yanıt vermek için kullanılır. Anonim kalmak için boş bırak.';

  @override
  String get reportEmailInvalid => 'Bu bir e-posta adresine benzemiyor.';

  @override
  String get reportReply => 'Yanıtla';

  @override
  String reportReplySubject(String app) {
    return '$app raporun hakkında';
  }

  @override
  String get navGenerate => 'Üretim';

  @override
  String get navGallery => 'Üretilenler';

  @override
  String get navFlow => 'Hat';

  @override
  String get navQueue => 'Sıra';

  @override
  String get navDelivery => 'Dağıtım';

  @override
  String get navBuckets => 'Kovalar';

  @override
  String get assetModeTooltip => 'Asset modu';

  @override
  String get deliveryModeTooltip => 'Dağıtım modu';

  @override
  String get videoPlaybackFailed => 'Video oynatılamadı';

  @override
  String get apiKeyRefusedBanner =>
      'API anahtarı reddedildi - Ayarlar\'da düzeltmek için dokun';

  @override
  String get errOffline => 'Sunucuya ulaşılamıyor - bağlantını kontrol et';

  @override
  String get errTimeout => 'Sunucu zamanında yanıt vermedi - tekrar dene';

  @override
  String errGatewayTimeout(int status) {
    return 'Sunucu zamanında yanıt vermedi (ağ geçidi zaman aşımı $status)';
  }

  @override
  String errGateway(int status) {
    return 'Sunucuya ağ geçidi üzerinden ulaşılamıyor (ağ geçidi hatası $status) - çalıştığını kontrol et';
  }

  @override
  String errServer(int status) {
    return 'Sunucu hatası ($status) - daha sonra tekrar dene';
  }

  @override
  String errUnauthorized(int status) {
    return 'Yetki yok ($status) - Ayarlar\'daki API anahtarını kontrol et';
  }

  @override
  String errNotFound(int status) {
    return 'Sunucuda bulunamadı ($status)';
  }

  @override
  String errRateLimited(int status) {
    return 'Çok fazla istek ($status) - biraz bekleyip tekrar dene';
  }

  @override
  String errTooLarge(int status) {
    return 'Sunucu için fazla büyük ($status)';
  }

  @override
  String errRejected(int status) {
    return 'Sunucu isteği reddetti ($status)';
  }

  @override
  String get errBadResponse =>
      'Sunucu, uygulamanın okuyamadığı bir yanıt gönderdi';

  @override
  String get errUnknown => 'İstek başarısız oldu - tekrar dene';

  @override
  String bucketsCounting(String bucket) {
    return '$bucket sayılıyor...';
  }

  @override
  String get bucketsTakedownTitle => 'Takedown (yeni + eski)';

  @override
  String get bucketsDeleteForeverTitle => 'Kalıcı olarak sil';

  @override
  String bucketsDeleteWarning(int count) {
    return '$count nesne silinecek. GERİ ALINAMAZ.';
  }

  @override
  String bucketsUnmappedNote(int count) {
    return '$count anahtarın eski ikizde karşılığı yok - yalnız bu kovadan silinir.';
  }

  @override
  String bucketsTypeNameToConfirm(String bucket) {
    return 'Onaylamak için kova adını yaz: $bucket';
  }

  @override
  String get bucketsTakedown => 'Takedown';

  @override
  String bucketsDeleted(int count) {
    return '$count nesne silindi';
  }

  @override
  String bucketsDeletedWithTwin(int count, int twin) {
    return '$count nesne silindi, eski ikizden $twin';
  }

  @override
  String bucketsCopySource(String path) {
    return 'Kaynak: $path';
  }

  @override
  String bucketsCopySourceTree(String path) {
    return 'Kaynak ağaç: $path';
  }

  @override
  String get bucketsWholeBucket => '(tüm kova)';

  @override
  String get bucketsCopyNote =>
      'Kopya depolama servisinin içinde çalışır - telefondan bayt geçmez.';

  @override
  String get bucketsTargetKey => 'Hedef anahtar';

  @override
  String get bucketsTargetPrefix => 'Hedef önek';

  @override
  String bucketsCopyStarted(String op) {
    return 'Kopya başladı ($op)';
  }

  @override
  String get bucketsFixHeadersTitle => 'Başlıkları düzelt';

  @override
  String bucketsFixHeadersBody(String path) {
    return '$path altındaki nesnelerin Cache-Control başlığı denetlenir; standarttan sapan nesne yerinde yeniden yazılır (Content-Type korunur). Bayt inmez.\n\nBilerek değişken bırakılan önekler atlanır.';
  }

  @override
  String bucketsFixStarted(String op) {
    return 'Başlık onarımı başladı ($op)';
  }

  @override
  String get bucketsOperations => 'İşlemler';

  @override
  String get bucketsNoOperations => 'Henüz işlem yok';

  @override
  String bucketsOpStatus(String status, int ok, int failed) {
    return '$status  ·  tamam $ok  ·  hata $failed';
  }

  @override
  String get bucketsTwinDiffRunning => 'İkiz farkı hesaplanıyor...';

  @override
  String get bucketsLocalDiffRunning => 'Yerel fark hesaplanıyor...';

  @override
  String bucketsTwinDiffTitle(String bucket, String twin) {
    return '$bucket <-> $twin (eski ikiz)';
  }

  @override
  String bucketsLocalDiffTitle(String bucket) {
    return 'Yerel Pushed <-> $bucket';
  }

  @override
  String get bucketsMissingInLegacy => 'Eski ikizde eksik';

  @override
  String get bucketsMissingInBucket => 'Kovada eksik';

  @override
  String get bucketsOnlyInLegacy => 'Yalnız eski ikizde';

  @override
  String get bucketsOnlyInBucket => 'Yalnız kovada';

  @override
  String get bucketsSizeMismatch => 'Boyut farkı';

  @override
  String get bucketsUnmapped => 'Eşleşmeyen (kural yok)';

  @override
  String get bucketsDerived => 'Kovada üretilen (thumbs)';

  @override
  String bucketsDiffCount(String title, int count) {
    return '$title: $count';
  }

  @override
  String get bucketsFixFolderHeaders => 'Bu klasörün başlıklarını düzelt';

  @override
  String get bucketsDiffs => 'Farklar';

  @override
  String get bucketsTwinDiff => 'Eski ikiz farkı';

  @override
  String get bucketsLocalDiff => 'Yerel Pushed farkı';

  @override
  String get bucketsIntro =>
      'Kova = içeriğin adıyla anılan depo. Sayılar istek üzerine hesaplanır (yalnız listeleme, bayt inmez).';

  @override
  String get bucketsBadgeLegacy => 'ESKİ';

  @override
  String get bucketsBadgePrivate => 'özel';

  @override
  String get bucketsBadgeContent => 'içerik';

  @override
  String get bucketsNotCounted => 'sayılmadı';

  @override
  String bucketsObjectCount(int count) {
    return '$count nesne';
  }

  @override
  String bucketsTwinLabel(String twin) {
    return 'ikiz: $twin';
  }

  @override
  String get bucketsCount => 'Say';

  @override
  String get bucketsEmptyFolder => 'Bu klasör boş';

  @override
  String get bucketsTruncated => 'Liste kesildi - daha dar bir klasöre gir';

  @override
  String bucketsSelectedCount(int count) {
    return '$count seçili';
  }

  @override
  String get bucketsClearSelection => 'Seçimi bırak';

  @override
  String get bucketsTakedownTooltip => 'Takedown (eski ikizden de sil)';

  @override
  String get bucketsSize => 'Boyut';

  @override
  String get bucketsContentType => 'Tür';

  @override
  String get bucketsModified => 'Değişiklik';

  @override
  String get bucketsNone => '(yok)';

  @override
  String get bucketsMutableOnPurpose => 'Bilerek değişken - standart aranmaz';

  @override
  String bucketsHeaderOk(String kind) {
    return 'Önbellek standardına uygun ($kind)';
  }

  @override
  String bucketsHeaderExpected(String expected) {
    return 'Standart: $expected';
  }

  @override
  String get bucketsLegacyTwin => 'Eski ikiz';

  @override
  String get bucketsAddressCopied => 'Adres kopyalandı';

  @override
  String get bucketsCopyAddress => 'Adresi kopyala';

  @override
  String get bucketsOpen => 'Aç';

  @override
  String get bucketsPrivateNoAddress => 'Bu kova özel - genel adresi yok';

  @override
  String get kindCard => 'Kart';

  @override
  String get kindCharacter => 'Karakter';

  @override
  String get assetCodeMode => 'Code modu';

  @override
  String get assetPickFinishedImage => 'Tamamlanmış bir görsel seç';

  @override
  String get assetGenerateVideo => 'Video üret';

  @override
  String get assetEnlarge => 'Büyüt';

  @override
  String percentValue(Object value) {
    return '%$value';
  }

  @override
  String get commonCategory => 'Kategori';

  @override
  String durSeconds(Object seconds) {
    return '$seconds sn';
  }

  @override
  String durMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes dk $seconds sn';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '$hours sa $minutes dk';
  }

  @override
  String get charKindFemale => 'Kadın';

  @override
  String get charKindMale => 'Erkek';

  @override
  String get charKindAnimal => 'Hayvan';

  @override
  String get charKindMachine => 'Makine';

  @override
  String get outfitCatSet => 'Set';

  @override
  String get outfitCatTop => 'Üst';

  @override
  String get outfitCatBottom => 'Alt';

  @override
  String get outfitCatShoes => 'Ayakkabı';

  @override
  String get outfitCatSocks => 'Çorap';

  @override
  String get outfitCatHat => 'Şapka';

  @override
  String get outfitCatHeadgear => 'Kafalık';

  @override
  String get outfitCatAccessory => 'Aksesuar';

  @override
  String get outfitCatWeapon => 'Silah';

  @override
  String get audioLabel => 'Ses';

  @override
  String get audioDownloading => 'İndiriliyor...';

  @override
  String get audioOpen => 'Sesi aç';

  @override
  String get outfitExtractTitle => 'Kıyafet çıkar';

  @override
  String get outfitExtractBody =>
      'Seçili görseldeki kişi silinir, üzerindeki kıyafet düz gri fonda hayalet manken ürün karesi olarak gardıroba yazılır. Sonra her karakterde skin olarak giydirilir.';

  @override
  String get outfitExtractName => 'Kıyafet adı';

  @override
  String get outfitExtractNameHint => 'örn. Kırmızı gece elbisesi';

  @override
  String get outfitExtractNote => 'Not (isteğe bağlı)';

  @override
  String get outfitExtractNoteHint => 'örn. sadece elbise, ayakkabılar hariç';

  @override
  String get outfitExtractHelp =>
      'Set: kişinin üstündeki her şey tek karede. Silah / aksesuar: yalnız o nesne, mankensiz.';

  @override
  String get outfitExtractAction => 'Çıkar';

  @override
  String equipSlotTitle(Object category) {
    return '$category yuvası';
  }

  @override
  String get equipSlotMultiHint => 'çoklu seçim - dokun: giydir / çıkar';

  @override
  String get equipSlotSingleHint =>
      'tek seçim - dokun: giydir, tekrar dokun: çıkar';

  @override
  String get equipSlotEmpty => '(boş)';

  @override
  String get equipSlotNoOutfits =>
      'Bu kategoride hazır kıyafet yok - \"+ Kıyafet üret\" ya da \"Kıyafet çıkar\"';

  @override
  String get equipBaseLabel => 'Base:';

  @override
  String get equipUndress => 'Soyun';

  @override
  String get equipPickSourceTitle => 'Kaynak görsel seç';

  @override
  String get equipPickSourceHint =>
      'Son tamamlanmış üretimler (her kip). Jigsaw hattındaki incoming / staging / pushed için Hat > Jigsaw ekranını kullan.';

  @override
  String get equipNoFinishedImage => 'Tamamlanmış görsel yok';

  @override
  String get freeFlowTitle => 'Free hattı';

  @override
  String get freeFlowEditTitle => 'Düzenle - edit motoru';

  @override
  String get freeFlowEditLabel => 'Ne değişsin';

  @override
  String get freeFlowEditHint =>
      'örn. change the dress to red, keep face and pose';

  @override
  String get freeFlowEditQueued => 'Düzenleme sıraya eklendi';

  @override
  String get freeFlowNoVideoTask => 'Free kipinde video görevi yok';

  @override
  String freeFlowVideoTitle(Object task) {
    return 'Video üret - $task';
  }

  @override
  String get freeFlowMotionLabel => 'Hareket';

  @override
  String get freeFlowMotionHint =>
      'örn. she turns her head slowly toward the camera, hair moving in the breeze';

  @override
  String get freeFlowVideoQueued =>
      'Video sıraya eklendi - bitince bu kartta oynatma işareti çıkar';

  @override
  String get freeFlowDeleteConfirm => 'Bu üretim silinsin mi?';

  @override
  String get freeFlowDeleteWithVideosConfirm =>
      'Bu üretim ve videoları silinsin mi?';

  @override
  String get freeFlowEmpty =>
      'Free kipinde üretim yok - Üretim sekmesinden başlat';

  @override
  String get queueKindGeneration => 'Üretim';

  @override
  String get queueKindTag => 'Etiket';

  @override
  String get queueKindMusic => 'Müzik';

  @override
  String get queueKindJob => 'İş';

  @override
  String get queueCancelRunningTitle => 'Çalışan işi iptal et';

  @override
  String get queueRemoveTitle => 'Sıradan çıkar';

  @override
  String get queueCancelIt => 'İptal et';

  @override
  String get queueClearTitle => 'Sırayı temizle';

  @override
  String get queueClearBody =>
      'Bekleyen üretim işleri iptal edilsin mi? Çalışan iş devam eder.';

  @override
  String get queueCancelWaiting => 'Bekleyenleri iptal et';

  @override
  String get queueEmpty => 'Sıra boş';

  @override
  String get queueEmptyHint => 'Üretim sekmesinden iş ekleyebilirsin';

  @override
  String get queueNow => 'Şu an';

  @override
  String queueWaitingCount(Object count) {
    return 'Bekleyen ($count)';
  }

  @override
  String queueGenerationJobsCount(Object count) {
    return 'Üretim işleri ($count)';
  }

  @override
  String get queueOneQueue => 'Tek sıra - bütün işler';

  @override
  String queueJobCount(Object count) {
    return '$count iş';
  }

  @override
  String get queueMoveUp => 'Yukarı taşı';

  @override
  String get queueMoveDown => 'Aşağı taşı';

  @override
  String get queueUp => 'Yukarı';

  @override
  String get queueDown => 'Aşağı';

  @override
  String queueElapsed(Object time) {
    return 'geçen $time';
  }

  @override
  String queueWaitingFor(Object time) {
    return 'bekliyor $time';
  }

  @override
  String get queueWaiting => 'bekliyor';

  @override
  String get queueComfyReady => 'ComfyUI hazır';

  @override
  String get queueComfyOff => 'ComfyUI kapalı';

  @override
  String get deliveryPoolNeverRan => 'hiç çalışmadı';

  @override
  String deliveryPoolDryRun(Object status) {
    return '$status (deneme)';
  }

  @override
  String deliveryPoolSummary(
    Object status,
    Object total,
    Object valid,
    Object tagged,
    Object failed,
  ) {
    return '$status · $total görsel, $valid geçerli, $tagged etiketlendi, $failed başarısız';
  }

  @override
  String get reportErrEmpty => 'Lütfen önce bir mesaj yazın.';

  @override
  String get reportErrTooLarge =>
      'Ekler çok büyük. Birini kaldırıp tekrar deneyin.';

  @override
  String flowOpError(Object message) {
    return 'İşlem hatası: $message';
  }

  @override
  String get flowOpCancelled => 'İşlem iptal edildi';

  @override
  String flowOpDone(Object ok) {
    return '$ok tamam';
  }

  @override
  String flowOpDoneWithFailed(Object ok, Object failed) {
    return '$ok tamam, $failed hata';
  }

  @override
  String get flowCollection => 'Koleksiyon';

  @override
  String get flowAllParen => '(hepsi)';

  @override
  String get flowAll => 'hepsi';

  @override
  String get flowSelectAll => 'Tümünü seç';

  @override
  String get flowRetag => 'Yeniden etiketle';

  @override
  String get flowRetagShort => 'Etiketle';

  @override
  String get flowRetagStarted => 'Etiketleme başladı';

  @override
  String get flowReadOnly => 'Salt görünüm';

  @override
  String get flowPush => 'Push';

  @override
  String get flowPreview => 'Ön izleme';

  @override
  String get flowYes => 'var';

  @override
  String get flowNo => 'yok';

  @override
  String get flowMissingUpper => 'YOK';

  @override
  String get flowBadgeNoTags => 'etiket yok';

  @override
  String get flowTabPushed => '4 Push edilmiş';

  @override
  String get flowSelectAssetFirst => 'Önce varlık seç';

  @override
  String get flowAccept => 'Kabul et';

  @override
  String get flowReject => 'Reddet';

  @override
  String get flowUpload => 'Yükle';

  @override
  String get flowNew => 'Yeni';

  @override
  String get flowReadFailed => 'Akış okunamadı';

  @override
  String flowFilesDeleted(Object count) {
    return '$count dosya silindi';
  }

  @override
  String get flowNegative => 'Negatif';

  @override
  String get flowPositive2 => 'Pozitif 2';

  @override
  String get flowDuration => 'Süre';

  @override
  String get flowAddToQueue => 'Sıraya ekle';

  @override
  String get commonDescription => 'Açıklama';

  @override
  String get cbnFlowTitle => 'CBN hattı';

  @override
  String get cbnFlowTabIncoming => '2 Gelen';

  @override
  String get cbnFlowTabReady => '3 Hazır';

  @override
  String cbnFlowBuildTitle(Object count) {
    return 'İnşa et - $count varlık';
  }

  @override
  String get cbnFlowBuildBodyHot =>
      'Bölgeleme + palet + numaralı şablon + reveal videosu (CPU). SAM aşaması önceden yapılmış olmalı; kontur SAM sınırlarından gelir. (Hot: inşa, çizgi sayfasını Qwen ile kendisi üretir; C adımı isteğe bağlı ön izleme.)';

  @override
  String get cbnFlowBuildBodyKid =>
      'Bölgeleme + palet + numaralı şablon + SVG (CPU). SAM aşaması önceden yapılmış olmalı.';

  @override
  String get cbnFlowBuild => 'İnşa et';

  @override
  String get cbnFlowBuildStarted => 'İnşa başladı - ilerleme üstte';

  @override
  String cbnFlowStageStarted(Object stage, Object count) {
    return '$stage başladı ($count varlık)';
  }

  @override
  String get cbnFlowStageObjects => 'Nesne listesi';

  @override
  String get cbnFlowLineart => 'Çizgi';

  @override
  String cbnFlowPushTitle(Object count) {
    return 'Push - $count varlık';
  }

  @override
  String get cbnFlowPushBody =>
      'Varlık klasörleri R2\'ye yüklenecek ve \"Push edilmiş\"e taşınacak.\n\nBu bir YAYIN işlemidir, geri alınamaz.';

  @override
  String cbnFlowDeleteBody(Object count) {
    return '$count varlık silinecek.';
  }

  @override
  String cbnFlowDeleted(Object count) {
    return '$count silindi';
  }

  @override
  String get cbnFlowEmptyIncoming =>
      'Bu akışta varlık yok.\n\"Üretilenler\" ekranında CBN kipinde KABUL ET ile buraya düşür.';

  @override
  String get cbnFlowEmptyStaging =>
      'Henüz inşa edilmiş varlık yok.\n\"Gelen\" sekmesinden seç ve İNŞA ET.';

  @override
  String get cbnFlowEmptyPushed => 'Push edilmiş varlık yok.';

  @override
  String get cbnFlowBadgeTagged => 'E';

  @override
  String get cbnFlowBadgeObjects => 'N';

  @override
  String cbnFlowBadgeBuilt(Object regions, Object colors) {
    return '${regions}b ${colors}r';
  }

  @override
  String get cbnFlowLayerNumbered => 'Numaralı';

  @override
  String get cbnFlowLayerFinished => 'Bitmiş';

  @override
  String get cbnFlowLayerSource => 'Kaynak';

  @override
  String get cbnFlowLayerObjects => 'Nesneler';

  @override
  String cbnFlowInfo(
    Object label,
    Object regions,
    Object colors,
    Object verdict,
  ) {
    return '$label   $regions bölge · $colors renk · $verdict';
  }

  @override
  String cbnFlowTagLine(Object label, Object state) {
    return '$label   etiket: $state';
  }

  @override
  String get cbnFlowFindObjects => 'A) Nesneleri bul';

  @override
  String get cbnFlowSamMasks => 'B) SAM maskeleri';

  @override
  String get cbnFlowLineartPage => 'C) Çizgi sayfası (isteğe bağlı, Qwen)';

  @override
  String get cbnFlowBuildStep => 'D) İnşa et';

  @override
  String get cbnFlowStepMissingA => 'A (nesne listesi) adımı yapılmamış';

  @override
  String get cbnFlowStepMissingB => 'B (SAM maskeleri) adımı yapılmamış';

  @override
  String get cbnFlowStepMissingC => 'C (çizgi sayfası) adımı yapılmamış';

  @override
  String get cbnFlowImageFailed => 'Görüntü alınamadı';

  @override
  String get jigsawFlowTitle => 'Jigsaw hattı';

  @override
  String get jigsawFlowTabTagged => '2 Etiketli';

  @override
  String get jigsawFlowTabToPush => '3 Push bekleyen';

  @override
  String get jigsawFlowQueueAll => 'QUE ALL';

  @override
  String jigsawFlowQueueAllTitle(Object count) {
    return 'QUE ALL - $count varlık';
  }

  @override
  String jigsawFlowVideoTitle(Object count) {
    return 'Video üret - $count varlık';
  }

  @override
  String get jigsawFlowPositive1 => 'Pozitif 1 - konu';

  @override
  String get jigsawFlowPositive1Help => 'boş = her varlığın kendi prompt\'u';

  @override
  String get jigsawFlowMotionPreset => 'Hazır hareket şablonu';

  @override
  String get jigsawFlowSpreadInTurn => '(sırayla dağıt)';

  @override
  String get jigsawFlowPositive2 => 'Pozitif 2 - hareket';

  @override
  String jigsawFlowPositive2Help(Object marker) {
    return '$marker = konu promptunun yeri. Boş = şablonlar sırayla.';
  }

  @override
  String jigsawFlowPresetsSpread(Object count) {
    return 'Hazır $count şablon sırayla dağıtılacak.';
  }

  @override
  String get jigsawFlowNoAssetWithoutVideo => 'Videosu olmayan varlık yok';

  @override
  String get jigsawFlowSelectWithoutVideo => 'Videosu olmayan varlık seç';

  @override
  String jigsawFlowVideosQueued(Object queued) {
    return '$queued video sıraya eklendi - bitince buraya düşer';
  }

  @override
  String jigsawFlowVideosQueuedSkipped(Object queued, Object skipped) {
    return '$queued video sıraya eklendi, $skipped atlandı - bitince buraya düşer';
  }

  @override
  String get jigsawFlowNoVideoTitle => 'Video yok';

  @override
  String jigsawFlowNoVideoBody(Object count) {
    return '$count varlığın videosu yok - sadece jpg yazılacak. Devam?';
  }

  @override
  String get jigsawFlowMusicNotReady => 'Müzik modeli hazır değil';

  @override
  String get jigsawFlowNoMusicMissing => 'Müziği eksik tematik koleksiyon yok';

  @override
  String jigsawFlowHasMusic(Object collection) {
    return '$collection zaten müzikli ya da Generic';
  }

  @override
  String jigsawFlowMusicBody(Object count, Object names) {
    return '$count koleksiyon için 30 saniyelik enstrümantal müzik üretilecek (ACE-Step, yerel).\n\n$names\n\nHer biri birkaç dakika sürebilir.';
  }

  @override
  String jigsawFlowPushBody(Object count) {
    return '$count varlık R2 kovasına YÜKLENECEK.\n\nBu geri alınamaz bir yayın işlemidir - yüklenen dosyalar uygulamada görünür.';
  }

  @override
  String jigsawFlowDeleteBody(Object count) {
    return '$count varlık (jpg + mp4 + webp + json) kalıcı olarak silinsin mi?';
  }

  @override
  String get jigsawFlowWebpStarted => 'Eksik webp üretimi başladı';

  @override
  String jigsawFlowCollectionTitle(Object mode) {
    return '$mode koleksiyonu';
  }

  @override
  String get jigsawFlowCollectionHelp => 'listeden seç ya da YENİ bir ad yaz';

  @override
  String jigsawFlowCollectionHelpFull(Object count) {
    return 'listeden seç ya da YENİ bir ad yaz  -  $count dolu koleksiyon gizlendi';
  }

  @override
  String jigsawFlowCollectionRow(Object total, Object next) {
    return '$total varlık - sıradaki $next';
  }

  @override
  String get jigsawFlowEmptyIncoming =>
      'Bu akışta varlık yok.\n\"Üretilenler\" ekranından KABUL ET ile buraya düşür.';

  @override
  String get jigsawFlowEmpty => 'Bu akışta varlık yok.';

  @override
  String get jigsawFlowBadgeNoWebp => 'webp yok';

  @override
  String jigsawFlowPreviewInfo(Object label, Object video, Object webp) {
    return '$label\nvideo: $video   webp: $webp';
  }

  @override
  String jigsawFlowPreviewTags(Object state) {
    return 'etiket: $state';
  }

  @override
  String get jigsawFlowNoVideoInSelection => 'Seçilenlerde video yok';

  @override
  String get jigsawFlowDeleteVideo => 'Videoyu sil';

  @override
  String jigsawFlowDeleteVideoBody(Object count) {
    return '$count varlığın mp4 + webp\'i silinecek; görsel kalır, yeniden video üretebilirsin.';
  }

  @override
  String get jigsawFlowDeleteVideoTooltip => 'Videoyu sil (görsel kalır)';

  @override
  String get jigsawFlowExtractNeedsOne =>
      'Kıyafet tek görselden çıkarılır - birini seç';

  @override
  String outfitExtractStarted(Object name) {
    return '$name gardıroba çıkarılıyor - Karakter > Gardırop';
  }

  @override
  String get jigsawFlowMetaFile => 'Dosya';

  @override
  String get jigsawFlowMetaTags => 'Etiketler';

  @override
  String get jigsawFlowMetaSubject => 'Konu';

  @override
  String get jigsawFlowMetaPolicy => 'Politika';

  @override
  String jigsawFlowMetaVideoValue(Object video, Object webp) {
    return '$video   webp: $webp';
  }

  @override
  String get jigsawFlowTagsMetadata => 'Etiket / metadata';

  @override
  String get jigsawFlowMissingWebp => 'Eksik webp';

  @override
  String deliverySavedLive(Object time) {
    return 'Kaydedildi ve CANLI ($time) - sayılar yenileniyor';
  }

  @override
  String get deliveryReindexTitle => 'Metadata\'yı yeniden oku';

  @override
  String get deliveryReindexBody =>
      'Kovada EXIF\'i değişen görseller için. Dosya adlarını virgülle yaz (örn. 12.jpg, 340.jpg); boş bırakırsan Generic\'in TAMAMI yeniden okunur (~1500 dosya, birkaç dakika).';

  @override
  String get deliveryReindexNames => 'Dosya adları';

  @override
  String get deliveryReindexAction => 'Oku';

  @override
  String deliveryReindexed(Object count) {
    return '$count görsel yeniden okundu - manifestler tazelendi';
  }

  @override
  String deliveryReindexedMissing(Object count, Object missing) {
    return '$count görsel yeniden okundu, $missing bulunamadı - manifestler tazelendi';
  }

  @override
  String get deliveryDryRunStarted =>
      'Deneme koşusu başladı - yalnız rapor üretir';

  @override
  String get deliveryNormalizeStarted => 'Normalizasyon başladı';

  @override
  String get deliveryCancelRequested => 'İptal istendi';

  @override
  String get deliveryNeverSaved => 'hiç kaydedilmedi';

  @override
  String get deliveryPoolJigsaw => 'Jigsaw havuzu';

  @override
  String get deliveryPoolCards => 'Kartlar';

  @override
  String get deliveryPoolEvents => 'Etkinlikler';

  @override
  String get deliveryEvent => 'Etkinlik';

  @override
  String deliverySummaryLine(
    Object pool,
    Object total,
    Object tagged,
    Object untagged,
  ) {
    return '$pool havuzu: $total görsel, $tagged etiketli, $untagged etiketsiz';
  }

  @override
  String get deliverySaveBeforeSwitch =>
      'Havuz değiştirmeden önce değişiklikleri kaydet.';

  @override
  String get deliveryReindexTooltip =>
      'Metadata\'yı yeniden oku (EXIF değiştiyse)';

  @override
  String deliveryLastRule(Object time, Object served, Object total) {
    return 'Son kural: $time  ·  varsayılan sunulan: $served / $total';
  }

  @override
  String get deliveryIntro =>
      'Anahtar KAPALI = o değerdeki görseller manifestten çıkar. Kaydet anlık canlıdır ve artık HER koleksiyon / deste filtrelenir; kuralın kaçırdığı tek bir öğeyi Engelle listesiyle kapatırsın.';

  @override
  String get deliveryNormalizeTitle => 'Normalize - eksik etiketleri üret';

  @override
  String get deliveryDryRun => 'Deneme';

  @override
  String get deliveryNormalizeNoStatus =>
      'Durum alınamadı - sunucu /api/normalize/status yanıt vermedi';

  @override
  String deliveryIndex(Object index) {
    return 'İndeks: $index';
  }

  @override
  String deliveryLastRun(Object summary) {
    return 'Son koşu: $summary';
  }

  @override
  String get deliveryBlockScopeGlobal => 'her uygulama (global)';

  @override
  String deliveryBlockTitle(Object scope) {
    return 'Engelle · $scope';
  }

  @override
  String get deliveryOpenList => 'Listeyi aç';

  @override
  String get deliveryBlockIntro =>
      'Global engel HER uygulamada geçerlidir; bir uygulama seçince yalnız o uygulama için engellersin. Kurallardan SONRA uygulanır.';

  @override
  String get deliveryBlockEmpty =>
      'Bu havuzda engellenecek öğe yok (kova boş).';

  @override
  String deliveryGroupSubtitle(Object count, Object tagged) {
    return '$count öğe · $tagged/$count etiketli';
  }

  @override
  String deliveryGroupSubtitleBlocked(Object count, Object tagged) {
    return '$count öğe · $tagged/$count etiketli · TAMAMI ENGELLİ';
  }

  @override
  String get deliveryAppsHint =>
      'Uygulamalar - dokun = o uygulamanın kuralını düzenle';

  @override
  String deliveryDefaultChip(Object served, Object total) {
    return 'Varsayılan  $served/$total';
  }

  @override
  String get deliveryDefaultRuleTitle =>
      'Varsayılan kural - ?app= göndermeyen eski sürümler ve özel kuralı olmayan uygulamalar';

  @override
  String deliveryCustomRuleTitle(Object app) {
    return '$app için özel kural';
  }

  @override
  String get deliveryCustomRuleOn => 'Kapatırsan varsayılana döner';

  @override
  String get deliveryCustomRuleOff =>
      'Kapalı: varsayılan kural uygulanır. Açınca varsayılanın kopyasıyla başlar.';

  @override
  String get deliveryScopeTitle => 'Yalnız seçili koleksiyonlar';

  @override
  String deliveryScopeOn(Object selected, Object total) {
    return '$selected/$total koleksiyon - yeni yayınlananlar bu uygulamaya GİTMEZ';
  }

  @override
  String get deliveryScopeOff =>
      'Kapalı: yeni yayınlanan her koleksiyon bu uygulamaya da gider';

  @override
  String get deliveryScopeNone =>
      'Hiçbiri seçili değil - boş liste kaydedilmez, kural \"hepsi\"ne döner.';

  @override
  String get deliveryRulesEnabled => 'Kurallar etkin';

  @override
  String get deliveryRulesEnabledHint =>
      'Kapalı = bu kural seti hiç filtrelemez';

  @override
  String get deliveryServeUntagged => 'Etiketsiz görselleri sun';

  @override
  String deliveryUntaggedCount(Object count) {
    return '$count görselin metadata\'sı yok';
  }

  @override
  String get deliveryQuick => 'Hızlı:';

  @override
  String deliveryOffCount(Object count) {
    return '$count kapalı';
  }

  @override
  String deliveryFieldSubtitle(Object field, Object count) {
    return '$field · $count değer';
  }

  @override
  String get deliveryUnsaved => 'Kaydedilmemiş değişiklik var';

  @override
  String get deliveryInSync => 'Sunucuyla aynı';

  @override
  String get deliverySavePublish => 'Kaydet ve yayınla';

  @override
  String get commonApply => 'Uygula';

  @override
  String get commonModel => 'Model';

  @override
  String get cardTplShuffled => 'Karıştırıldı - kilitli eksenlere dokunulmadı';

  @override
  String cardTplRankShuffled(Object rank) {
    return '$rank karıştırıldı';
  }

  @override
  String cardTplAxisAllTitle(Object axis) {
    return '$axis - hepsine';
  }

  @override
  String get cardTplAxisAllBack => 'Kart arkasına yazılır ve KİLİTLENİR.';

  @override
  String get cardTplAxisAllFront =>
      '13 kart + 2 jokere birden yazılır ve KİLİTLENİR - karıştırmada değişmez.';

  @override
  String get cardTplValue => 'Değer';

  @override
  String get cardTplAllWritten => 'Hepsine yazıldı ve kilitlendi';

  @override
  String cardTplRankTitle(Object rank) {
    return '$rank şablonu';
  }

  @override
  String get cardTplLocked => 'Kilitli';

  @override
  String get cardTplLock => 'Kilitle';

  @override
  String get cardTplManual => 'Manuel ek (serbest metin)';

  @override
  String get cardTplManualHint => 'örn. holding a golden card fan';

  @override
  String get cardTplManualHelp => 'Şablonun sonuna eklenir - karıştırma silmez';

  @override
  String cardTplRankSaved(Object rank) {
    return '$rank kaydedildi';
  }

  @override
  String cardTplSlotQueued(Object slot) {
    return '$slot sıraya girdi';
  }

  @override
  String cardTplTitle(Object title) {
    return 'Koleksiyon Kartı - $title';
  }

  @override
  String get cardTplShuffle => 'Karıştır';

  @override
  String get cardTplNoTheme => 'Tema yok - dokun ve yaz';

  @override
  String get cardTplThemeTitle => 'Tema (P1)';

  @override
  String get cardTplPresetCard => 'Hazır kart';

  @override
  String get cardTplTheme => 'Tema';

  @override
  String get cardTplThemeHelp => 'kimlik + STRICT PALETTE + Signature pieces';

  @override
  String get cardTplThemeEmpty => 'Tema boş olamaz';

  @override
  String get cardTplThemeSaved => 'Tema kaydedildi';

  @override
  String cardTplModelSet(Object name) {
    return 'Model: $name';
  }

  @override
  String get cardTplFaceDetail => 'Yüz rötuşu';

  @override
  String get cardTplFaceDetailHint =>
      '+15 sn/kart - yüzü ayrı geçişten geçirir';

  @override
  String get cardTplFaceDetailOn => 'Yüz rötuşu açık';

  @override
  String get cardTplFaceDetailOff => 'Yüz rötuşu kapalı';

  @override
  String get cardTplVideoEngine => 'Video motoru (ilk kare = son kare)';

  @override
  String cardTplEngineUnavailable(Object engine) {
    return '$engine (kurulu değil)';
  }

  @override
  String cardTplVideoEngineSet(Object name) {
    return 'Video motoru: $name';
  }

  @override
  String get cardTplApplyToAll => 'Hepsine uygula:';

  @override
  String get cardTplPickAxis => 'eksen seç';

  @override
  String cardTplBackAxis(Object axis) {
    return '$axis  (arka)';
  }

  @override
  String cardTplLockedAxes(Object count) {
    return '$count eksen kilitli';
  }

  @override
  String get cardTplShuffleSlot => 'Bu yuvayı karıştır';

  @override
  String get cardTplGenerateSlot => 'Bu yuvayı üret';

  @override
  String galleryDeleteSelectedConfirm(Object count) {
    return '$count üretim ve dosyası silinsin mi?';
  }

  @override
  String galleryDeleted(Object count) {
    return '$count üretim silindi';
  }

  @override
  String galleryDeleteFailed(Object count) {
    return '$count silinemedi';
  }

  @override
  String get galleryCharacterNeedsOne =>
      'Karakter tek görselden açılır - birini seç';

  @override
  String get galleryMakeCharacter => 'Karakter yap';

  @override
  String get galleryMakeCharacterBody =>
      'Seçili görsel doğrudan base olur; portre, hikâye ve 7 yön kendiliğinden üretilir - onay sorulmaz.';

  @override
  String galleryCharacterQueued(Object name) {
    return '$name sıraya eklendi - pipeline Sıra sekmesinde';
  }

  @override
  String get galleryCreateCharacterFirst =>
      'Önce \"Karakter yap\" ile bir karakter oluştur';

  @override
  String galleryAddToCandidatesTitle(Object count) {
    return 'Adaylara ekle - $count görsel';
  }

  @override
  String galleryAddedToCandidates(Object count, Object name) {
    return '$name adaylarına $count görsel eklendi';
  }

  @override
  String get galleryCollectionNeedsOne =>
      'Koleksiyona tek görsel eklenir - birini seç';

  @override
  String get galleryCreateCollectionFirst =>
      'Önce Kart hattında bir koleksiyon ya da krupiye oluştur';

  @override
  String get galleryAddToCollection => 'Koleksiyona ekle';

  @override
  String get galleryDealerNoRank => 'krupiye (rütbe yok)';

  @override
  String galleryPickRank(Object name) {
    return '$name - rütbe seç';
  }

  @override
  String get galleryQueuedOne =>
      'Sıraya eklendi (1 iş) - Sıra sekmesinden izle';

  @override
  String galleryAcceptBodyCbn(Object count) {
    return '$count görsel CBN hattının \"Gelen\" akışına taşınacak: jpg + EXIF etiketi. İnşa (SAM, çizgi, bölgeler) orada başlatılır.\n\nHangi derece?';
  }

  @override
  String galleryAcceptBodyJigsaw(Object count) {
    return '$count görsel 2. akışa taşınacak: jpg + EXIF etiketi, varsa videosu da yanında.\n\nHangi derece?';
  }

  @override
  String get galleryAcceptStarted =>
      'Başladı - ilerlemeyi \"Hat\" sekmesinden izle';

  @override
  String get galleryExtractTooltip =>
      'Kıyafet çıkar - görseldeki kıyafeti gardıroba al';

  @override
  String get galleryMakeCharacterTooltip =>
      'Karakter yap - yeni karakter oluştur';

  @override
  String get galleryAddToCandidatesTooltip =>
      'Adaylara ekle - mevcut karaktere kopyala';

  @override
  String get galleryAddToCollectionTooltip => 'Koleksiyona ekle - rütbe seç';

  @override
  String get galleryAcceptTooltip => 'Kabul et - 2. akışa gönder';

  @override
  String get galleryDeleteSelected => 'Seçilenleri sil';

  @override
  String get galleryFilterImage => 'Görsel';

  @override
  String get galleryFilterVideo => 'Video';

  @override
  String get galleryFilterFavorite => 'Favori';

  @override
  String galleryQueuedAt(Object position) {
    return 'sırada $position';
  }

  @override
  String get galleryEmpty => 'Henüz üretim yok';

  @override
  String get galleryEmptyHint => 'Üretim sekmesinden başlayabilirsin';

  @override
  String get galleryDeleteOneConfirm => 'Bu üretim ve dosyası silinsin mi?';

  @override
  String get galleryAcceptOneCbn =>
      'CBN hattının \"Gelen\" akışına taşınacak (jpg + EXIF etiketi).\n\nHangi derece?';

  @override
  String get galleryAcceptOneJigsaw =>
      '2. akışa taşınacak (jpg + EXIF etiketi).\n\nHangi derece?';

  @override
  String get galleryAccepted =>
      'Kabul edildi - etiketleniyor, \"Hat\" sekmesinden izle';

  @override
  String get galleryRejected => 'Reddedildi';

  @override
  String get galleryEditBody =>
      'Bu görsel kaynak olur; edit motoru (Qwen Image Edit, kimlik korur) yeni bir üretim açar. Ne değişsin?';

  @override
  String get galleryEditPromptLabel => 'Ek prompt';

  @override
  String get galleryEditPromptHint =>
      'örn. change the dress to a red pleated miniskirt, keep face and pose';

  @override
  String get galleryEditQueued =>
      'Düzenleme sıraya eklendi - sonucu Üretilenler\'de görürsün';

  @override
  String get galleryEditTooltip => 'Düzenle - edit motoruyla yeni üretim';

  @override
  String galleryPoolInfo(Object name) {
    return 'havuz $name';
  }

  @override
  String get genPromptUnchanged => 'Prompt değişmedi (yerel LLM yanıt vermedi)';

  @override
  String get genPromptWritten => 'Prompt yazıldı';

  @override
  String get commonUndo => 'Geri al';

  @override
  String get genVariantFailed =>
      'Varyant üretilemedi (yerel LLM yanıt vermedi)';

  @override
  String get genPickVariant => 'Varyant seç';

  @override
  String get genEnrich => 'Zenginleştir';

  @override
  String get genFix => 'Düzelt';

  @override
  String get genVariant => 'Varyant';

  @override
  String get genFileUnreadable => 'Dosya okunamadı';

  @override
  String get genPromptEmpty => 'Prompt boş olamaz';

  @override
  String genMissingInputs(Object inputs) {
    return 'Eksik girdi: $inputs';
  }

  @override
  String get genNeedsImagePick =>
      'Bu görev bir girdi görseli istiyor - üretilenlerden birini seç';

  @override
  String get genNeedsImage => 'Bu görev bir girdi görseli istiyor';

  @override
  String genQueuedCount(Object count) {
    return '$count iş sıraya eklendi';
  }

  @override
  String get genQueued => 'Sıraya eklendi';

  @override
  String genQueueBadge(Object count) {
    return '$count sırada';
  }

  @override
  String get genComfyOffBody =>
      'ComfyUI kapalı. İşler sıraya girer ama başlamaz - bilgisayarda açılması gerekiyor.';

  @override
  String get genTask => 'Görev';

  @override
  String get genWorkflowInputs => 'İş akışının girdileri';

  @override
  String get genInputImage => 'Girdi görseli';

  @override
  String get genPositive1 => 'Pozitif prompt 1 - konu';

  @override
  String get genPositive1Hint => 'örn. police officer';

  @override
  String get genPositive2 => 'Pozitif prompt 2 - şablon';

  @override
  String genPositive2Help(Object marker) {
    return '$marker birinci promptun yerine geçer. Boş bırakılabilir.';
  }

  @override
  String get genFinalPrompt => 'Gidecek prompt';

  @override
  String get genNegative => 'Negatif prompt';

  @override
  String get genTurboHint => 'hızlı mod';

  @override
  String genDurationSeconds(Object seconds) {
    return 'Süre: $seconds saniye';
  }

  @override
  String genCount(Object count) {
    return 'Adet: $count';
  }

  @override
  String genSizeAspect(Object width, Object height, Object aspect) {
    return 'Ölçü: $width x $height  ($aspect)';
  }

  @override
  String genSize(Object width, Object height) {
    return 'Ölçü: $width x $height';
  }

  @override
  String get genAddToQueueUpper => 'SIRAYA EKLE';

  @override
  String get genFootnote =>
      'İşler sırayla üretilir. Takibi Sıra sekmesinden yapabilirsin.';

  @override
  String get genDetailsTitle =>
      'Detaylar - boş bırakılabilir, kilitli olanlar karışmaz';

  @override
  String genRandomGenerate(Object count) {
    return 'Rastgele üret  $count';
  }

  @override
  String get genLockedTooltip => 'kilitli - karışımda sabit';

  @override
  String get genOptionsEmpty => 'Seçenek listesi boş';

  @override
  String get genOptional => 'isteğe bağlı';

  @override
  String get genUploading => 'yükleniyor...';

  @override
  String get genNotSelected => 'seçilmedi';

  @override
  String get genFromGallery => 'Galeriden seç';

  @override
  String get genFromFile => 'Dosyadan seç';

  @override
  String get genNoSource =>
      'Girdi olarak kullanılabilecek üretim yok. Önce bir görsel üret.';

  @override
  String genPickerTitle(Object slot) {
    return '$slot - Üretilenlerden seç';
  }

  @override
  String get genPickerSearch => 'promptta ara';

  @override
  String get genPickerEmpty => 'Bu türe uygun bitmiş üretim yok.';

  @override
  String optionsFileMissing(Object items) {
    return 'Seçenek dosyasında eksik: $items';
  }

  @override
  String optionsFieldsMissing(Object label) {
    return '$label (alan tanımı yok)';
  }

  @override
  String optionsFileUnreadable(Object error) {
    return 'Seçenek dosyası okunamadı: $error';
  }

  @override
  String optionsFileUnreadableNamed(Object name, Object error) {
    return '$name seçenek dosyası okunamadı: $error';
  }

  @override
  String get fieldLocation => 'Mekân';

  @override
  String get fieldEra => 'Dönem / estetik';

  @override
  String get fieldWeather => 'Hava';

  @override
  String get fieldWeatherLight => 'Hava / ışık';

  @override
  String get fieldJob => 'Meslek';

  @override
  String get fieldFantasy => 'Fantazi';

  @override
  String get fieldOutfitColor => 'Kıyafet rengi';

  @override
  String get fieldOutfit => 'Kıyafet';

  @override
  String get fieldHair => 'Saç';

  @override
  String get fieldHairColor => 'Saç rengi';

  @override
  String get fieldHairstyle => 'Saç stili';

  @override
  String get fieldEyes => 'Göz';

  @override
  String get fieldRace => 'Irk';

  @override
  String get fieldExpression => 'İfade';

  @override
  String get fieldPose => 'Poz';

  @override
  String get fieldAngle => 'Açı';

  @override
  String get fieldStyle => 'Stil';

  @override
  String get fieldMood => 'Hava';

  @override
  String get fieldColor => 'Renk';

  @override
  String get fieldCreature => 'Yaratık';

  @override
  String get fieldClass => 'Sınıf';

  @override
  String get fieldAge => 'Yaş';

  @override
  String get fieldOrigin => 'Köken';

  @override
  String get fieldBody => 'Vücut';

  @override
  String get fieldSkin => 'Ten';

  @override
  String get fieldFace => 'Yüz';

  @override
  String get fieldGesture => 'Jest';

  @override
  String get cardNotReady => 'Sunucu ucu henüz hazır değil';

  @override
  String get cardKindNormal => 'Normal';

  @override
  String get cardKindDealer => 'Krupiye';

  @override
  String get cardStagePushed => 'push edilmiş';

  @override
  String get cardStageWebp => 'webp hazır';

  @override
  String get cardStageVideo => 'video hazır';

  @override
  String get cardStageStill => 'still hazır';

  @override
  String get cardStageEmpty => 'boş';

  @override
  String cardRankTooltip(Object rank, Object stage) {
    return '$rank - $stage';
  }

  @override
  String cardRankTooltipWarn(Object rank, Object stage) {
    return '$rank - $stage (kontrol)';
  }

  @override
  String get cardVideoIntro =>
      'İlk kare = son kare (döngü). Kamera kilitli kalır - kadraj, ölçek ve fon değişmez. Çıktı önce HAVUZA girer; etiket seçersen oraya da atanır.';

  @override
  String get cardVideoTemplate => 'Şablon (metni doldurur)';

  @override
  String get cardVideoMotion => 'Hareket cümlesi (giden prompt)';

  @override
  String get cardVideoMotionHelp =>
      'Görünür hareket tarif et; sonunda başlangıç pozuna dönsün';

  @override
  String get cardVideoAssignTag => 'Etikete ata';

  @override
  String get cardVideoPoolOnly => '(yalnız havuza - sonra atarım)';

  @override
  String get cardVideoNewTag => 'Yeni etiket...';

  @override
  String get cardVideoNewTagName => 'Yeni etiket adı';

  @override
  String get cardTagHint => 'örn. victory';

  @override
  String get cardGestureTitle => 'Animasyon - jest seç';

  @override
  String get cardGestureIntro =>
      'MiniMax H3: idle 6 sn, victory 2 sn. Kamera kilitli kalır - kadraj, ölçek ve fon değişmez.';

  @override
  String get cardGestureCustom => 'Özel hareket';

  @override
  String get cardGestureCustomHint =>
      'örnek: hafifçe kalça sallama, ayaklar sabit';

  @override
  String get cardGestureCustomHelp =>
      'Kısa bir hareket cümlesi - kamera yine kilitli';

  @override
  String get cardCutTitle => '3 WebP - kesim kipi';

  @override
  String get cardCutHybrid =>
      'Eski yeşil Grok masterları - chroma + SAM birlikte';

  @override
  String get cardCutSam => 'Varsayılan - yalnız SAM3, düz açık gri fon';

  @override
  String get cardCutAction => 'Kes';

  @override
  String cardEditTitle(Object name) {
    return 'Düzenle - $name';
  }

  @override
  String get cardEditSentence => 'Düzeltme cümlesi';

  @override
  String get cardEditSentenceHint => 'örn. saçını kısalt / eldivenleri çıkar';

  @override
  String get cardEditBody =>
      'Kabul edilen still bu cümleyle düzenlenir; kimlik, poz ve fon korunur. Yeni görsel otomatik kabul edilir.';

  @override
  String get cardEditUnrestricted => 'Sınırsız düzenleme (NSFW LoRA)';

  @override
  String get cardEditUnrestrictedHint =>
      'Qwen reddederse aç - MCNL LoRA, 20 adım, biraz daha yavaş';

  @override
  String cardQueuedJobs(Object count) {
    return 'Sıraya eklendi ($count iş) - Sıra sekmesinden izle';
  }

  @override
  String get cardQueued => 'Sıraya eklendi - Sıra sekmesinden izle';

  @override
  String cardQueuedOp(Object op) {
    return 'Sıraya eklendi (op $op) - Sıra sekmesinden izle';
  }

  @override
  String cardSoonTitle(Object what) {
    return '$what - yakında';
  }

  @override
  String get cardSoonBody =>
      'Sunucudaki kart uçları henüz açık değil. Uçlar açılınca bu ekran kendiliğinden çalışır.';

  @override
  String get cardNewCollection => 'Yeni koleksiyon';

  @override
  String get cardIdLabel => 'Kimlik (id)';

  @override
  String get cardIdHintCollection => 'örn. police_royale';

  @override
  String get commonName => 'Ad';

  @override
  String get cardNameHintCollection => 'örn. Police Royale';

  @override
  String get cardPickPreset => 'Hazır kart seç (isteğe bağlı)';

  @override
  String get cardThemeHint =>
      'örn. sexy police costume with badge and duty belt';

  @override
  String get cardThemeFormula =>
      'Formül: kimlik + STRICT PALETTE + Signature pieces';

  @override
  String get cardJokers => 'Joker (2 adet)';

  @override
  String get cardJokersHint => '13 rütbe yerine 15';

  @override
  String get cardNewCollectionNote =>
      'Her rütbe için 1 still sıraya girer (ten / saç / kıyafet / poz rotasyonu). Onay sorulmaz - ince ayar ✎ / ↻ ile yapılır.';

  @override
  String get cardIdNameRequired => 'Kimlik ve ad boş olamaz';

  @override
  String get cardNewDealer => 'Yeni krupiye';

  @override
  String get cardIdHintDealer => 'örn. scarlett';

  @override
  String get cardNameHintDealer => 'örn. Scarlett';

  @override
  String get cardDealerTheme => 'Tema / kıyafet';

  @override
  String get cardDealerThemeHint =>
      'örn. kumarhane yeleği ve papyon, noir kırmızı elbise';

  @override
  String get cardDealerNote =>
      'Krupiye bel üstü kadrajda üretilir (eller masada, kameraya bakıyor). Rütbe yoktur - tek öğe dört aşamadan geçer.';

  @override
  String get cardNightPickGesture => 'Gece modu - jest seç';

  @override
  String get cardNightMode => 'Gece modu';

  @override
  String cardNightBody(Object gesture) {
    return 'Bütün kartlar VE krupiyeler yeniden canlandırılır: mevcut still -> LTX-2.5 i2v ($gesture) -> SAM kesim -> sheet.\n\nUzun sürer, hepsi sıraya girer. Push YAPILMAZ.';
  }

  @override
  String get cardRestillTitle => 'Fonları griye al';

  @override
  String get cardRestillBody =>
      'Bütün kartların VE krupiyelerin still fonu düz açık griye çevrilir (kadın aynen kalır). İlk hâl still_green.png olarak saklanır, zaten gri olanlar atlanır.\n\nVideo üretilmez.';

  @override
  String get cardManifestPreview => 'Manifest ön izleme';

  @override
  String cardManifestCounts(Object collections, Object dealers) {
    return '$collections koleksiyon, $dealers krupiye';
  }

  @override
  String get cardManifestNote =>
      'Manifest dosyası PUSH sırasında yazılır (önce dosyalar, sonra manifest). Bu yalnızca ön izlemedir.';

  @override
  String get cardCollectionCardSettings => 'Koleksiyon Kartı (ayarlar)';

  @override
  String get cardCollectionCardSettingsHint =>
      'tema, 16 yuva, model, yüz rötuşu';

  @override
  String get cardReanimate => 'Yeniden canlandır';

  @override
  String get cardReanimateHint => 'still -> i2v -> kesim (bu koleksiyon)';

  @override
  String get cardRealify => 'Anime -> gerçekçi (koleksiyon)';

  @override
  String get cardRealifyHint => 'her still edit_qwen ile gerçekçi fotoğrafa';

  @override
  String get cardDeleteCollection => 'Koleksiyonu sil';

  @override
  String get cardDeleteCollectionHint =>
      'klasör bütün kartlarıyla silinir - geri alınamaz';

  @override
  String cardDeleteCollectionTitle(Object name) {
    return 'Koleksiyonu sil - $name';
  }

  @override
  String cardDeleteDealerTitle(Object name) {
    return 'Krupiyeyi sil - $name';
  }

  @override
  String get cardDeleteCollectionBody =>
      'Koleksiyon klasörü bütün dosyalarıyla silinir.\n\nGERİ ALINAMAZ. R2\'ye push edilmiş dosyalar kovada kalır.';

  @override
  String get cardDeleteDealerBody =>
      'Krupiye klasörü bütün dosyalarıyla silinir.\n\nGERİ ALINAMAZ. R2\'ye push edilmiş dosyalar kovada kalır.';

  @override
  String cardDeletedNamed(Object name) {
    return '$name silindi';
  }

  @override
  String get cardDealerCardSettings => 'Krupiye Kartı (ayarlar)';

  @override
  String get cardDealerCardSettingsHint => 'tema, şablon, model, yüz rötuşu';

  @override
  String get cardDeleteDealer => 'Krupiyeyi sil';

  @override
  String get cardDeleteDealerHint =>
      'klasör bütün dosyalarıyla silinir - geri alınamaz';

  @override
  String get cardFlowTitle => 'Kart hattı';

  @override
  String get cardBulkActions => 'Toplu işlemler';

  @override
  String get cardNightMenu => 'Gece modu: hepsini yeniden canlandır';

  @override
  String get cardRestillMenu => 'Fonları griye al (hepsi)';

  @override
  String get cardManifestMenu => 'Manifest ön izle';

  @override
  String get cardDealers => 'Krupiyeler';

  @override
  String get cardEmptyCollections =>
      'Henüz koleksiyon yok.\n\n\"+ Yeni koleksiyon\" ile kimlik, ad ve tema ver - 13 (istersen 15) rütbe için 1\'er still sıraya girer, sonra 2 Video ve 3 WebP aşamaları.';

  @override
  String get cardEmptyDealers =>
      'Henüz krupiye yok.\n\n\"+ Yeni krupiye\" ile ad, tema ve jest ver - bel üstü kadrajda tek öğe üretilir ve dört aşamadan geçer.';

  @override
  String cardGestureLine(Object gesture) {
    return 'jest: $gesture';
  }

  @override
  String cardAnimateTitle(Object count) {
    return '2 Video ($count kart)';
  }

  @override
  String cardAnimateBody(Object total) {
    return 'Her karta 2 animasyon üretilir ve etiketine atanır:\n• idle - 6 sn, tek kontrollü jest\n• victory - 2 sn, kadraj içinde kısa sevinme\nToplam $total video; eskileri havuzda kalır.';
  }

  @override
  String get cardEditNeedsOne => 'Düzenleme tek rütbe için - bir kart seç';

  @override
  String cardPushTitle(Object name) {
    return 'Push - $name';
  }

  @override
  String cardPushBody(Object ready, Object total) {
    return 'Sheet ve thumb dosyaları R2 (cards) üzerine yüklenir, sonra manifest yazılır. Şu an $ready/$total rütbenin webp\'i hazır.\n\nBu bir YAYIN işlemidir, GERİ ALINAMAZ.';
  }

  @override
  String get cardPushQueued => 'Push sıraya eklendi - Sıra sekmesinden izle';

  @override
  String get cardCollectionCardTooltip =>
      'Koleksiyon Kartı - tema, 16 yuva, model, yüz rötuşu';

  @override
  String get commonMore => 'Daha fazla';

  @override
  String get cardNoThemeTap => 'Tema yok - dokun: Koleksiyon Kartı';

  @override
  String cardThemeTap(Object theme) {
    return '$theme\nKoleksiyon Kartı: dokun (tema, 16 yuva, model, yüz rötuşu)';
  }

  @override
  String cardDeleteCollectionStills(Object stills) {
    return 'Koleksiyon klasörü bütün kartlarıyla silinir ($stills still).\n\nGERİ ALINAMAZ. R2\'ye push edilmiş dosyalar kovada kalır.';
  }

  @override
  String cardDeleteCollectionStillsPushed(Object stills, Object pushed) {
    return 'Koleksiyon klasörü bütün kartlarıyla silinir ($stills still, $pushed push edilmiş).\n\nGERİ ALINAMAZ. R2\'ye push edilmiş dosyalar kovada kalır.';
  }

  @override
  String get cardClearCards => 'Kartları temizle';

  @override
  String cardClearCardsBody(Object ranks) {
    return '$ranks - still, adaylar, video ve webp silinir; rütbe boş kalır (\"1 Still\" ile yeniden üretilir).';
  }

  @override
  String cardsCleared(Object count) {
    return '$count kart temizlendi';
  }

  @override
  String cardsClearFailed(Object count) {
    return '$count kart temizlenemedi';
  }

  @override
  String get cardGenerateStill => '1 Still üret';

  @override
  String get cardGenerateVideo => '2 Video üret';

  @override
  String get cardGenerateWebp => '3 WebP üret';

  @override
  String get cardBackUpper => 'ARKA';

  @override
  String cardAssetVideo(Object tag) {
    return 'Video ($tag)';
  }

  @override
  String cardAssetSheet(Object tag) {
    return 'WebP / kesim ($tag)';
  }

  @override
  String cardAssetMissing(Object asset) {
    return '$asset yok';
  }

  @override
  String cardAssetDeleteConfirm(Object asset) {
    return '$asset silinsin mi?';
  }

  @override
  String get cardAssetDeleteVideoBody =>
      'Yalnız bu etiketin videosu silinir; havuzdaki kopya, still ve webp kalır.';

  @override
  String get cardAssetDeleteSheetBody =>
      'Yalnız sheet.webp, thumb ve kesim kareleri silinir; video ve still kalır.';

  @override
  String get cardAssetDeleteStillBody =>
      'Yalnız seçili still silinir; adaylar, video ve webp kalır.';

  @override
  String get cardPoolDelete => 'Havuzdan sil';

  @override
  String cardPoolDeleteBody(Object id, Object tags) {
    return '$id havuzdan silinir. Etiketlere atanmış kopyalar ($tags) kalır.';
  }

  @override
  String get cardNone => 'yok';

  @override
  String get cardNewAnimTag => 'Yeni animasyon etiketi';

  @override
  String get cardNewAnimTagHelp =>
      'Oyun bu adla okur (idle, wink, victory ...)';

  @override
  String get cardUnassigned => 'atanmadı';

  @override
  String cardAssignedTo(Object tags) {
    return 'atandı: $tags';
  }

  @override
  String cardAssignTo(Object name) {
    return 'Ata: $name';
  }

  @override
  String get cardAssignNewTag => 'Yeni etikete ata...';

  @override
  String get cardAnimReady => 'video + webp hazır';

  @override
  String get cardAnimVideoOnly => 'video var, webp yok';

  @override
  String get cardPoolEmpty => 'Havuzda video yok - önce \"2 Video\"';

  @override
  String get cardDeleteVideoKeepTag => 'Videoyu sil (etiket kalır)';

  @override
  String get cardDeleteSheet => 'WebP / kesimi sil';

  @override
  String get cardDeleteTag => 'Etiketi sil (video + webp ile)';

  @override
  String cardVideosHeader(Object count) {
    return 'Videolar ($count) - dokun = ata / ön izle / sil';
  }

  @override
  String cardDeleteThisDealerBody(Object name) {
    return '$name klasörü bütün dosyalarıyla silinir. GERİ ALINAMAZ.';
  }

  @override
  String get cardClearCard => 'Kartı temizle';

  @override
  String cardClearCardBody(Object name) {
    return '$name: still, adaylar, video, webp ve animasyonlar silinir; rütbe boş kalır (\"1 Still\" ile yeniden üretilir).';
  }

  @override
  String get cardClearCardTooltip => 'Kartı temizle (rütbe boşa döner)';

  @override
  String get cardViewCut => 'Kesim';

  @override
  String cardDeleteThisVideo(Object tag) {
    return 'Bu videoyu sil ($tag)';
  }

  @override
  String cardDeleteSheetTag(Object tag) {
    return 'WebP / kesimi sil ($tag)';
  }

  @override
  String get cardDeleteStill => 'Still\'i sil';

  @override
  String get cardNoVideo => 'Video yok - \"2 Video\" ile üret';

  @override
  String get cardNoCut => 'Kesim yok - \"3 WebP\" ile üret';

  @override
  String get cardCutFrameFailed => 'Kesim karesi okunamadı';

  @override
  String get cardNoStill => 'Still yok - \"1 Still\" ile üret';

  @override
  String get cardStillFailed => 'Still okunamadı';

  @override
  String cardPromptTitleAge(Object age) {
    return 'Prompt  ·  $age yaş';
  }

  @override
  String get cardGuardFail =>
      'Guard FAIL - kadraj kayması / zoom / maske kopması. Videoyu ya da kesimi yeniden üret.';

  @override
  String get cardAnimsHeader =>
      'Animasyonlar - dokun = seç, uzun bas = ata / sil';

  @override
  String cardAnimOpened(Object tag) {
    return '\"$tag\" açıldı - 2 Video ile üret ya da havuzdan ata';
  }

  @override
  String cardPickPoolVideo(Object tag) {
    return '\"$tag\" için havuzdan video seç';
  }

  @override
  String cardCandidatesHeader(Object count) {
    return 'Adaylar ($count) - dokun = seç';
  }

  @override
  String get cardCandidatePicked => 'Aday seçili still oldu';

  @override
  String cardRunFailed(Object step, Object error) {
    return '$step: $error';
  }
}

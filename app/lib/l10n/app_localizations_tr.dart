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
}

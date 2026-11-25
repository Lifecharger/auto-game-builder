/// What Google Play and the App Store currently have for an app, as the
/// server last saw it (`store_status` in the app dict, see
/// server/core/store_status.py).
///
/// Display rule (mirrors the server's `pick_display`): per store the HIGHEST
/// version found, labelled with the track it is on; when the same version is
/// on several tracks the most public one wins - production > beta > alpha >
/// internal on Play, live > review > TestFlight on Apple.
library;

class StoreEntry {
  /// Play: production | beta | alpha | internal | (custom track).
  /// Apple: live | approved | review | testflight | prepare.
  final String track;
  final String version;

  /// Play versionCode (null on Apple).
  final int? code;

  /// Apple build number ('' on Play).
  final String build;

  /// Play release status (completed, inProgress, draft, halted) or Apple
  /// state (READY_FOR_SALE, WAITING_FOR_REVIEW, IN_BETA_TESTING, ...).
  final String status;

  /// Play staged-rollout fraction.
  final double? fraction;

  /// Apple TestFlight build id (for attaching).
  final String buildId;

  const StoreEntry({
    required this.track,
    required this.version,
    this.code,
    this.build = '',
    this.status = '',
    this.fraction,
    this.buildId = '',
  });

  factory StoreEntry.fromJson(Map<String, dynamic> j) => StoreEntry(
        track: j['track'] as String? ?? '',
        version: j['version'] as String? ?? '',
        code: (j['code'] as num?)?.toInt(),
        build: '${j['build'] ?? ''}',
        status: j['status'] as String? ?? '',
        fraction: (j['fraction'] as num?)?.toDouble(),
        buildId: j['build_id'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'track': track,
        'version': version,
        if (code != null) 'code': code,
        'build': build,
        'status': status,
        if (fraction != null) 'fraction': fraction,
        if (buildId.isNotEmpty) 'build_id': buildId,
      };

  /// Version plus build number for Apple ("1.0.12 (34)"), plain version on Play.
  String get label => build.isNotEmpty ? '$version ($build)' : version;
}

/// A TestFlight build as listed by App Store Connect.
class AppleBuild {
  final String buildId;
  final String version;
  final String build;
  final String processing;
  final bool expired;
  final String externalState;
  final String internalState;

  const AppleBuild({
    required this.buildId,
    required this.version,
    required this.build,
    required this.processing,
    this.expired = false,
    this.externalState = '',
    this.internalState = '',
  });

  bool get attachable => processing == 'VALID' && !expired;

  factory AppleBuild.fromJson(Map<String, dynamic> j) => AppleBuild(
        buildId: j['build_id'] as String? ?? '',
        version: j['version'] as String? ?? '',
        build: '${j['build'] ?? ''}',
        processing: j['processing'] as String? ?? '',
        expired: j['expired'] == true,
        externalState: j['external_state'] as String? ?? '',
        internalState: j['internal_state'] as String? ?? '',
      );
}

class StoreInfo {
  final String store; // play | apple
  final StoreEntry? display;
  final List<StoreEntry> entries;
  final String? refreshedAt;
  final String error;

  /// The version players get: Apple's live App Store version, Play's newest
  /// production release that is out.
  final StoreEntry? live;

  /// Apple: the App Store version that can still take a build
  /// (PREPARE_FOR_SUBMISSION, rejected, ...): {version, state, build, ...}.
  final Map<String, dynamic>? editableVersion;
  final List<AppleBuild> builds;

  const StoreInfo({
    required this.store,
    this.display,
    this.entries = const [],
    this.refreshedAt,
    this.error = '',
    this.live,
    this.editableVersion,
    this.builds = const [],
  });

  factory StoreInfo.fromJson(String store, Map<String, dynamic> j) {
    StoreEntry? entry(dynamic v) =>
        v is Map ? StoreEntry.fromJson(Map<String, dynamic>.from(v)) : null;
    final entries = (j['entries'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => StoreEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return StoreInfo(
      store: store,
      // The server sends its pick; recompute when it is missing so an older
      // server's raw list still shows the right line.
      display: entry(j['display']) ?? pickDisplay(store, entries),
      entries: entries,
      refreshedAt: j['refreshed_at'] as String?,
      error: j['error'] as String? ?? '',
      live: entry(j['live']) ?? liveEntry(store, entries),
      editableVersion: j['editable_version'] is Map
          ? Map<String, dynamic>.from(j['editable_version'] as Map)
          : null,
      builds: (j['builds'] as List? ?? const [])
          .whereType<Map>()
          .map((b) => AppleBuild.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }

  bool get isEmpty => display == null && entries.isEmpty;

  /// Play tracks that have a live release (the sources a promote can use).
  List<String> get liveTracks => [
        for (final t in playTracks)
          if (entries.any((e) => e.track == t && playLiveStatuses.contains(e.status))) t
      ];

  List<AppleBuild> get attachableBuilds => builds.where((b) => b.attachable).toList();
}

class StoreStatus {
  final StoreInfo? play;
  final StoreInfo? apple;

  const StoreStatus({this.play, this.apple});

  static const empty = StoreStatus();

  bool get isEmpty => (play?.isEmpty ?? true) && (apple?.isEmpty ?? true);

  factory StoreStatus.fromJson(dynamic raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    StoreInfo? info(String store) => m[store] is Map
        ? StoreInfo.fromJson(store, Map<String, dynamic>.from(m[store] as Map))
        : null;
    return StoreStatus(play: info('play'), apple: info('apple'));
  }
}

// ── Display rule ─────────────────────────────────────────────────────────

const playTracks = ['production', 'beta', 'alpha', 'internal'];
const playLiveStatuses = ['completed', 'inProgress'];
const _playPriority = {'production': 4, 'beta': 3, 'alpha': 2, 'internal': 1};
const _applePriority = {'live': 5, 'approved': 4, 'review': 3, 'testflight': 1, 'prepare': 0};

int trackPriority(String store, String track) =>
    (store == 'play' ? _playPriority[track] : _applePriority[track]) ?? 0;

List<int> _versionParts(String v) =>
    RegExp(r'\d+').allMatches(v).map((m) => int.parse(m.group(0)!)).toList();

/// Compares two entries of the same store by version: Play by versionCode,
/// Apple by marketing version then build number.
int compareVersions(StoreEntry a, StoreEntry b) {
  if (a.code != null && b.code != null) return a.code!.compareTo(b.code!);
  final pa = [..._versionParts(a.version), int.tryParse(a.build) ?? -1];
  final pb = [..._versionParts(b.version), int.tryParse(b.build) ?? -1];
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : -1;
    final y = i < pb.length ? pb[i] : -1;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

bool _isOut(String store, StoreEntry e) => store == 'play'
    ? playLiveStatuses.contains(e.status)
    : const ['live', 'approved', 'review', 'testflight'].contains(e.track);

/// The release players get (when the server did not send one): Play's
/// newest production release that is out, Apple's newest live version.
StoreEntry? liveEntry(String store, List<StoreEntry> entries) {
  final live = entries.where((e) => store == 'play'
      ? e.track == 'production' && playLiveStatuses.contains(e.status)
      : e.track == 'live');
  StoreEntry? best;
  for (final e in live) {
    if (best == null || compareVersions(e, best) > 0) best = e;
  }
  return best;
}

/// The rows the expanded card shows for a store: one per channel, most public
/// first, and a channel only when it carries something NEWER than every more
/// public channel above it. A closed or stopped test track that still holds
/// an old release, the pile of older TestFlight builds, halted and draft Play
/// releases all drop out. Apple's "being prepared" App Store version is not a
/// row: it is only the draft release a TestFlight build gets attached to (the
/// Attach / Submit buttons cover it).
List<StoreEntry> visibleEntries(String store, List<StoreEntry> entries) {
  final candidates = entries.where((e) => _isOut(store, e)).toList()
    ..sort((a, b) {
      final p = trackPriority(store, b.track).compareTo(trackPriority(store, a.track));
      return p != 0 ? p : compareVersions(b, a);
    });
  final shown = <StoreEntry>[];
  StoreEntry? top; // highest version among the rows already shown
  for (final e in candidates) {
    if (shown.any((s) => s.track == e.track)) continue; // newest per channel only
    if (top == null || compareVersions(e, top) > 0) {
      shown.add(e);
      top = e;
    }
  }
  return shown; // already most public first
}

/// The entry to show for a store: highest version first, then most public
/// track. Entries that are not out (drafts, versions being prepared) count
/// only when nothing else exists.
StoreEntry? pickDisplay(String store, List<StoreEntry> entries) {
  final out = entries.where((e) => _isOut(store, e)).toList();
  final pool = out.isNotEmpty ? out : entries;
  StoreEntry? best;
  for (final e in pool) {
    if (best == null) {
      best = e;
      continue;
    }
    final c = compareVersions(e, best);
    if (c > 0 ||
        (c == 0 && trackPriority(store, e.track) > trackPriority(store, best.track))) {
      best = e;
    }
  }
  return best;
}

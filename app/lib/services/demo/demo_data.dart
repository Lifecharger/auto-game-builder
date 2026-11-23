/// Bundled sample data for demo mode: four made-up games, their tasks,
/// builds, store status, player reports and notes. Every name, package and
/// text here is invented; none of it describes a real app or person.
library;

String demoIso(DateTime t) => t.toUtc().toIso8601String().split('.').first;
String demoIsoZ(DateTime t) => '${demoIso(t)}Z';

/// Store entries are kept as raw maps in the shape of the server's
/// `store_status` (see server/core/store_status.py).
class DemoStore {
  List<Map<String, dynamic>> play;
  List<Map<String, dynamic>> apple;
  List<Map<String, dynamic>> appleBuilds;
  Map<String, dynamic>? editableVersion;
  DateTime refreshedAt;

  DemoStore({
    required this.play,
    required this.apple,
    required this.appleBuilds,
    this.editableVersion,
    required this.refreshedAt,
  });
}

class DemoApp {
  final int id;
  String name;
  final String slug;
  final String appType;
  final String packageName;
  String version;
  String status;
  String publishStatus;
  String notes;
  String lastUploadTrack;
  String lastIosUploadTrack;
  String updatedAt;
  final DemoStore store;
  final List<Map<String, dynamic>> tasks;
  String gdd;
  String claudeMd;

  DemoApp({
    required this.id,
    required this.name,
    required this.slug,
    required this.appType,
    required this.packageName,
    required this.version,
    required this.store,
    required this.tasks,
    this.status = 'idle',
    this.publishStatus = 'published',
    this.notes = '',
    this.lastUploadTrack = '',
    this.lastIosUploadTrack = '',
    this.gdd = '',
    this.claudeMd = '',
  }) : updatedAt = demoIso(DateTime.now());
}

Map<String, dynamic> _task(int id, String title, String status,
    {String type = 'feature', String priority = 'medium', String response = '', int ageHours = 5}) {
  final t = DateTime.now().subtract(Duration(hours: ageHours));
  return {
    'id': id,
    'title': title,
    'description': title,
    'type': type,
    'task_type': type,
    'priority': priority,
    'status': status,
    'source': 'manual',
    'response': response,
    'ai_response': response,
    'issue_id': 0,
    'created_at': demoIso(t),
    'updated_at': demoIso(t.add(const Duration(hours: 1))),
    'completed_at': status == 'completed' || status == 'built' ? demoIso(t.add(const Duration(hours: 2))) : '',
    if (status == 'in_progress') 'started_at': demoIso(DateTime.now().subtract(const Duration(minutes: 3))),
    'built_version': status == 'built' ? '1.4.2' : '',
    'agent': 'claude',
    'blocked_by': <int>[],
    'blocked': false,
  };
}

Map<String, dynamic> _play(String track, String version, int code, {String status = 'completed'}) =>
    {'track': track, 'version': version, 'code': code, 'codes': [code], 'name': version, 'status': status};

Map<String, dynamic> _tf(String version, String build, String state) =>
    {'track': 'testflight', 'version': version, 'build': build, 'status': state, 'build_id': 'demo-b$build'};

Map<String, dynamic> _build(String version, String build, {String ext = 'IN_BETA_TESTING'}) => {
      'build_id': 'demo-b$build',
      'version': version,
      'build': build,
      'processing': 'VALID',
      'expired': false,
      'uploaded_at': demoIsoZ(DateTime.now().subtract(const Duration(days: 1))),
      'internal_state': 'IN_BETA_TESTING',
      'external_state': ext,
    };

List<DemoApp> buildDemoApps() {
  final now = DateTime.now();
  return [
    DemoApp(
      id: 1,
      name: 'Puzzle Garden',
      slug: 'puzzle-garden',
      appType: 'flutter',
      packageName: 'com.example.puzzlegarden',
      version: '1.4.3+43',
      lastUploadTrack: 'internal',
      lastIosUploadTrack: 'internal',
      notes: 'Relaxing tile puzzle with seasonal gardens.',
      gdd: '# Puzzle Garden\n\nSwap tiles to grow flowers. 120 levels in four seasons.\n\n'
          '## Core loop\n1. Match three tiles\n2. Earn seeds\n3. Decorate the garden\n',
      claudeMd: '# Puzzle Garden: agent notes\n\n- Flutter, portrait only\n- Levels live in `assets/levels/*.json`\n',
      store: DemoStore(
        play: [
          _play('production', '1.4.2', 42),
          _play('beta', '1.4.2', 42),
          _play('internal', '1.4.3', 43),
        ],
        apple: [
          {'track': 'live', 'version': '1.4.1', 'build': '41', 'status': 'READY_FOR_SALE', 'build_id': 'demo-b41'},
          _tf('1.4.3', '43', 'IN_BETA_TESTING'),
          _tf('1.4.2', '42', 'IN_BETA_TESTING'),
        ],
        appleBuilds: [_build('1.4.3', '43'), _build('1.4.2', '42')],
        editableVersion: {
          'version_id': 'demo-v143',
          'version': '1.4.3',
          'state': 'PREPARE_FOR_SUBMISSION',
          'build_id': null,
          'build': '',
        },
        refreshedAt: now.subtract(const Duration(hours: 2)),
      ),
      tasks: [
        _task(101, 'Add autumn season with 30 new levels', 'in_progress', priority: 'high'),
        _task(102, 'Daily reward calendar', 'pending'),
        _task(103, 'Fix hint button staying grey after a level restart', 'completed',
            type: 'bug', response: 'Hint state is reset on restart; added a widget test.'),
        _task(104, 'Smoother tile swap animation', 'built', response: 'Swap now eases over 180 ms.'),
        _task(105, 'Tablet layout for the garden screen', 'pending', priority: 'low'),
      ],
    ),
    DemoApp(
      id: 2,
      name: 'Sky Courier',
      slug: 'sky-courier',
      appType: 'godot',
      packageName: 'com.example.skycourier',
      version: '0.9.7+17',
      lastUploadTrack: 'alpha',
      lastIosUploadTrack: 'internal',
      publishStatus: 'testing',
      notes: 'Arcade delivery flyer, closed test.',
      gdd: '# Sky Courier\n\nFly parcels between floating islands before the storm hits.\n',
      claudeMd: '# Sky Courier: agent notes\n\n- Godot 4, GDScript\n- Physics tuning in `config/flight.tres`\n',
      store: DemoStore(
        play: [_play('alpha', '0.9.7', 17), _play('internal', '0.9.7', 17)],
        apple: [_tf('0.9.7', '17', 'IN_BETA_TESTING')],
        appleBuilds: [_build('0.9.7', '17')],
        refreshedAt: now.subtract(const Duration(hours: 5)),
      ),
      tasks: [
        _task(201, 'Storm weather effect on level 4', 'in_progress', priority: 'high'),
        _task(202, 'Parcel counter overlaps the pause button on small phones', 'failed',
            type: 'bug', priority: 'high', response: 'Needs a layout pass on 360 dp screens.'),
        _task(203, 'Second airship skin', 'pending'),
      ],
    ),
    DemoApp(
      id: 3,
      name: 'Word Orchard',
      slug: 'word-orchard',
      appType: 'flutter',
      packageName: 'com.example.wordorchard',
      version: '2.1.0+210',
      lastUploadTrack: 'production',
      lastIosUploadTrack: 'production',
      notes: 'Word search with a fruit-picking theme.',
      gdd: '# Word Orchard\n\nFind words, pick fruit, fill the basket.\n',
      claudeMd: '# Word Orchard: agent notes\n\n- Word lists per language in `assets/words/`\n',
      store: DemoStore(
        play: [_play('production', '2.1.0', 210), _play('internal', '2.1.0', 210)],
        apple: [
          {'track': 'review', 'version': '2.1.0', 'build': '210', 'status': 'WAITING_FOR_REVIEW', 'build_id': 'demo-b210'},
          {'track': 'live', 'version': '2.0.4', 'build': '204', 'status': 'READY_FOR_SALE', 'build_id': 'demo-b204'},
          _tf('2.1.0', '210', 'IN_BETA_TESTING'),
        ],
        appleBuilds: [_build('2.1.0', '210')],
        refreshedAt: now.subtract(const Duration(minutes: 40)),
      ),
      tasks: [
        _task(301, 'Spanish word list', 'completed', response: 'Added 2,400 checked words.'),
        _task(302, 'Weekly tournament', 'pending', priority: 'high'),
      ],
    ),
    DemoApp(
      id: 4,
      name: 'Tiny Tactics',
      slug: 'tiny-tactics',
      appType: 'flutter',
      packageName: 'com.example.tinytactics',
      version: '0.3.0+3',
      lastUploadTrack: 'internal',
      publishStatus: 'development',
      notes: 'Turn-based skirmish prototype.',
      gdd: '# Tiny Tactics\n\nFive-unit squads on a 6x6 board.\n',
      store: DemoStore(
        play: [_play('internal', '0.3.0', 3, status: 'draft')],
        apple: const [],
        appleBuilds: const [],
        refreshedAt: now.subtract(const Duration(days: 1)),
      ),
      tasks: [
        _task(401, 'Enemy turn preview arrows', 'pending'),
        _task(402, 'Unit stats from config file', 'completed', response: 'Stats load from units.json.'),
      ],
    ),
  ];
}

List<Map<String, dynamic>> buildDemoReports() {
  final now = DateTime.now();
  Map<String, dynamic> r(String id, int appId, String app, String pkg, String cat, String msg, String ver,
          int hoursAgo, {String status = 'open'}) =>
      {
        'id': id,
        'app_id': appId,
        'app_name': app,
        'package': pkg,
        'category': cat,
        'message': msg,
        'app_version': ver,
        'platform': 'android',
        'install_id': 'demo-install-$id',
        'shot_count': 0,
        'status': status,
        'received_at': demoIso(now.subtract(Duration(hours: hoursAgo))),
        'pulled_at': demoIso(now.subtract(Duration(hours: hoursAgo))),
        'closed_at': status == 'closed' ? demoIso(now) : '',
        'meta': {
          'brand': 'Example',
          'manufacturer': 'Example',
          'model': 'Phone 8',
          'device': 'phone8',
          'product': 'phone8',
          'os_version': '15',
          'sdk_int': 35,
        },
        'contact_email': '',
      };
  return [
    r('demo-r1', 1, 'Puzzle Garden', 'com.example.puzzlegarden', 'bug',
        'Level 57 says I have no moves left, but I can still swap the two roses.', '1.4.2', 3),
    r('demo-r2', 3, 'Word Orchard', 'com.example.wordorchard', 'suggestion',
        'Please add a dark theme for playing at night.', '2.1.0', 20),
    r('demo-r3', 2, 'Sky Courier', 'com.example.skycourier', 'other',
        'Love the storm level! Music could be a bit louder.', '0.9.7', 48, status: 'closed'),
  ];
}

List<Map<String, dynamic>> buildDemoNotices() {
  final now = DateTime.now();
  return [
    {
      'id': 1,
      'source': 'weekly_report',
      'title': 'Weekly report',
      'body': '**Installs** up 12% this week.\n\n- Puzzle Garden: 4.6 average rating\n'
          '- Word Orchard: 2.1.0 waiting for App Review\n- Sky Courier: 38 closed testers',
      'key': 'demo-weekly',
      'user_id': null,
      'read': false,
      'created_at': demoIso(now.subtract(const Duration(hours: 6))),
      'updated_at': demoIso(now.subtract(const Duration(hours: 6))),
    },
    {
      'id': 2,
      'source': 'review_replies',
      'title': 'Two new store reviews to answer',
      'body': 'Puzzle Garden got two new 5-star reviews. Draft replies are ready.',
      'key': 'demo-reviews',
      'user_id': null,
      'read': true,
      'created_at': demoIso(now.subtract(const Duration(days: 1))),
      'updated_at': demoIso(now.subtract(const Duration(days: 1))),
    },
  ];
}

/// What a build prints, step by step (shown as the running build progresses).
const demoBuildSteps = [
  'Bumping version',
  'Resolving dependencies',
  'Running static analysis: no issues found',
  'Running 148 tests: all passed',
  'Compiling release bundle',
  'Shrinking and optimizing resources',
  'Signing the app bundle',
  'Verifying the bundle',
];

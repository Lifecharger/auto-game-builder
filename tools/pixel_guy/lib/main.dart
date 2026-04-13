import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'screens/pipeline_screen.dart';

void main() => runApp(const PixelGuyApp());

class PixelGuyApp extends StatelessWidget {
  const PixelGuyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const _MainShell());
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tabIndex = 0;
  final _screens = const [CharacterGallery(), PipelineScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: const Color(0xFF1a1a2e),
        selectedItemColor: const Color(0xFFe94560),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Gallery'),
          BottomNavigationBarItem(icon: Icon(Icons.filter), label: 'Pipeline'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// Data Models (unchanged)
// ══════════════════════════════════════════

class CharacterInfo {
  final String name, dirPath;
  final int frameCount, width, height;
  CharacterInfo({required this.name, required this.dirPath, required this.frameCount, required this.width, required this.height});
  String get thumbnailPath => '$dirPath/frame_000.png';
  String framePath(int index) => '$dirPath/frame_${index.toString().padLeft(3, '0')}.png';
}

String _findCharactersDir() {
  // Prefer explicit override via env var for deployed builds.
  final envOverride = Platform.environment['PIXEL_GUY_CHARS_DIR'];
  if (envOverride != null && envOverride.isNotEmpty && Directory(envOverride).existsSync()) {
    return envOverride;
  }
  // Walk up from the executable looking for a sibling pubspec.yaml (dev mode).
  final exePath = Platform.resolvedExecutable;
  var dir = Directory(exePath).parent;
  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return '${dir.path}/assets/characters';
    dir = dir.parent;
  }
  // Walk up from current working directory as a fallback.
  dir = Directory.current;
  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return '${dir.path}/assets/characters';
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return 'assets/characters';
}

Future<List<CharacterInfo>> discoverCharacters() async {
  final d = Directory(_findCharactersDir());
  final List<CharacterInfo> r = [];
  if (!await d.exists()) return r;
  await for (final e in d.list()) {
    if (e is! Directory) continue;
    final p = e.path.replaceAll('\\', '/');
    final n = p.split('/').last;
    if (!n.endsWith('_anim')) continue;
    final f = File('$p/anim.json');
    if (!await f.exists()) continue;
    try {
      final m = json.decode(await f.readAsString()) as Map<String, dynamic>;
      final fc = m['frame_count'] as int? ?? 0;
      if (fc > 0) {
        r.add(CharacterInfo(
          name: n.replaceAll('_anim', '').replaceAll('_', ' ').split(' ')
              .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '),
          dirPath: p, frameCount: fc, width: m['width'] as int? ?? 0, height: m['height'] as int? ?? 0,
        ));
      }
    } catch (_) {}
  }
  r.sort((a, b) => a.name.compareTo(b.name));
  return r;
}

const Map<String, Color> kDirColors = {
  'n': Color(0xFFF44336), 'ne': Color(0xFFFF9800), 'e': Color(0xFFFFEB3B), 'se': Color(0xFF4CAF50),
  's': Color(0xFF00BCD4), 'sw': Color(0xFF2196F3), 'w': Color(0xFF9C27B0), 'nw': Color(0xFFE91E63),
};
const Map<String, String> kDirLabels = {
  'n': 'N', 'ne': 'NE', 'e': 'E', 'se': 'SE', 's': 'S', 'sw': 'SW', 'w': 'W', 'nw': 'NW',
};
const List<String> kDirOrder = ['s', 'sw', 'w', 'nw', 'n', 'ne', 'e', 'se'];
const Map<String, String> kDirFullNames = {
  'n': 'north', 'ne': 'northeast', 'e': 'east', 'se': 'southeast',
  's': 'south', 'sw': 'southwest', 'w': 'west', 'nw': 'northwest',
};
String _transitionFolderName(String from, String to) => '${kDirFullNames[from]}_to_${kDirFullNames[to]}';

class DirectionData {
  Map<String, List<int>> directions = {'nw': [], 'n': [], 'ne': [], 'w': [], 'e': [], 'sw': [], 's': [], 'se': []};
  Map<String, List<int>> transitions = {};
  String? getFrameDirection(int i) { for (final e in directions.entries) { if (e.value.contains(i)) return e.key; } return null; }
  String? getFrameTransition(int i) { for (final e in transitions.entries) { if (e.value.contains(i)) return e.key; } return null; }
  Color? getFrameColor(int i) { final d = getFrameDirection(i); if (d != null) return kDirColors[d]; if (getFrameTransition(i) != null) return Colors.grey.shade600; return null; }
  void removeFrameFromAll(int i) { for (final l in directions.values) l.remove(i); for (final l in transitions.values) l.remove(i); }
  Map<String, dynamic> toJson() => {'directions': directions.map((k, v) => MapEntry(k, List<int>.from(v))), 'transitions': transitions.map((k, v) => MapEntry(k, List<int>.from(v)))};
  static DirectionData fromJson(Map<String, dynamic> j) {
    final d = DirectionData();
    (j['directions'] as Map<String, dynamic>?)?.forEach((k, v) => d.directions[k] = List<int>.from(v));
    (j['transitions'] as Map<String, dynamic>?)?.forEach((k, v) => d.transitions[k] = List<int>.from(v));
    return d;
  }
}

class VisualTransition {
  String id;
  Offset position;
  String? fromDir;
  String? toDir;
  VisualTransition({required this.id, required this.position, this.fromDir, this.toDir});
  String get key => fromDir != null && toDir != null ? '${fromDir}_to_$toDir' : '';
  Map<String, dynamic> toJson() => {'id': id, 'x': position.dx, 'y': position.dy, 'from': fromDir, 'to': toDir};
  static VisualTransition fromJson(Map<String, dynamic> j) => VisualTransition(id: j['id'], position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()), fromDir: j['from'], toDir: j['to']);
}

class AnimationNode {
  String id;
  String name; // e.g. "cross punch", "idle", "walk"
  Offset position;
  String? connectedDir; // connected to a direction
  List<int> frames; // frame indices for this animation
  String? sourceFolder; // optional: path to extracted frames

  AnimationNode({required this.id, required this.name, required this.position, this.connectedDir, this.frames = const [], this.sourceFolder});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'x': position.dx, 'y': position.dy, 'dir': connectedDir, 'frames': frames, 'sourceFolder': sourceFolder};
  static AnimationNode fromJson(Map<String, dynamic> j) => AnimationNode(
    id: j['id'], name: j['name'] ?? '', position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
    connectedDir: j['dir'], frames: List<int>.from(j['frames'] ?? []), sourceFolder: j['sourceFolder'],
  );
}

class ProjectInfo {
  String name, path;
  ProjectInfo({required this.name, required this.path});
  Map<String, dynamic> toJson() => {'name': name, 'path': path};
  static ProjectInfo fromJson(Map<String, dynamic> j) => ProjectInfo(name: j['name'], path: j['path']);
}

class FolderNode {
  final String name, fullPath;
  final int depth, pngCount;
  List<FolderNode> children;
  bool expanded;
  FolderNode({required this.name, required this.fullPath, this.depth = 0, this.pngCount = 0, this.children = const [], this.expanded = false});
}

// Resolve user-data paths (projects.json, state.json) alongside the source tree
// in dev mode, or next to the executable in release mode. Override via env vars
// PIXEL_GUY_PROJECTS_CONFIG / PIXEL_GUY_STATE for deployments.
String _resolveUserDataPath(String filename, String envVar) {
  final override = Platform.environment[envVar];
  if (override != null && override.isNotEmpty) return override;
  // Walk up from the executable looking for pubspec.yaml (dev mode).
  var dir = Directory(Platform.resolvedExecutable).parent;
  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return '${dir.path}/$filename';
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  // Walk up from cwd.
  dir = Directory.current;
  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return '${dir.path}/$filename';
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return filename;
}

final String _projectsConfigPath = _resolveUserDataPath('projects.json', 'PIXEL_GUY_PROJECTS_CONFIG');
final String _statePath = _resolveUserDataPath('state.json', 'PIXEL_GUY_STATE');

// extract_single.py lookup: walk from executable/cwd to find it, then PATH, then env override.
const List<String> _extractScriptCandidates = ['extract_single.py'];
final List<String> _preferredExtractionPythonPaths = [
  if ((Platform.environment['PIXEL_GUY_PYTHON'] ?? '').isNotEmpty) Platform.environment['PIXEL_GUY_PYTHON']!,
];

String? _resolveExtractionScriptPath() {
  final exeDir = Directory(Platform.resolvedExecutable).parent;
  final searchDirs = <Directory>[
    Directory.current,
    exeDir,
    exeDir.parent,
    exeDir.parent.parent,
    exeDir.parent.parent.parent,
  ];
  for (final dir in searchDirs) {
    final candidate = File('${dir.path}/extract_single.py');
    if (candidate.existsSync()) return candidate.absolute.path.replaceAll('\\', '/');
  }
  for (final path in _extractScriptCandidates.skip(1)) {
    if (File(path).existsSync()) return File(path).absolute.path.replaceAll('\\', '/');
  }
  return null;
}

bool _pythonSupportsGpuExtraction(String pythonExe) {
  try {
    final result = Process.runSync(pythonExe, [
      '-c',
      "import importlib.util, sys; "
          "mods=('cv2','numpy','PIL','onnxruntime'); "
          "missing=[m for m in mods if importlib.util.find_spec(m) is None]; "
          "__import__('sys').exit(10) if missing else None; "
          "import onnxruntime as ort; "
          "providers=ort.get_available_providers(); "
          "sys.stdout.write('|'.join(providers)); "
          "sys.exit(0 if 'CUDAExecutionProvider' in providers else 11)"
    ]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String? _resolveExtractionPython() {
  // 1. Explicit override via PIXEL_GUY_PYTHON (populated into _preferredExtractionPythonPaths above).
  for (final path in _preferredExtractionPythonPaths) {
    if (File(path).existsSync() && _pythonSupportsGpuExtraction(path)) return path;
  }
  // 2. PYTHON env var.
  final envPython = Platform.environment['PYTHON'];
  if (envPython != null && envPython.isNotEmpty && File(envPython).existsSync() && _pythonSupportsGpuExtraction(envPython)) {
    return envPython;
  }
  // 3. Search PATH for python.exe / python3.exe.
  final pathEnv = Platform.environment['PATH'] ?? '';
  final sep = Platform.isWindows ? ';' : ':';
  final exeNames = Platform.isWindows ? ['python.exe', 'python3.exe'] : ['python3', 'python'];
  for (final dir in pathEnv.split(sep)) {
    if (dir.isEmpty) continue;
    for (final exe in exeNames) {
      final candidate = '$dir${Platform.pathSeparator}$exe';
      if (File(candidate).existsSync() && _pythonSupportsGpuExtraction(candidate)) return candidate;
    }
  }
  return null;
}

Future<List<ProjectInfo>> loadProjects() async {
  final f = File(_projectsConfigPath);
  if (!await f.exists()) {
    // First run: start with an empty project list. User adds projects via the UI.
    await saveProjects(const []);
    return const [];
  }
  try { return ((jsonDecode(await f.readAsString()))['projects'] as List).map((e) => ProjectInfo.fromJson(e)).toList(); } catch (_) { return []; }
}

Future<void> saveProjects(List<ProjectInfo> p) async {
  await File(_projectsConfigPath).writeAsString(const JsonEncoder.withIndent('  ').convert({'projects': p.map((e) => e.toJson()).toList()}));
}

Future<FolderNode> scanFolder(String path, {int depth = 0, int maxDepth = 4}) async {
  final dir = Directory(path);
  final name = path.replaceAll('\\', '/').split('/').last;
  int pngs = 0;
  if (await dir.exists()) { try { await for (final f in dir.list()) { if (f is File && f.path.endsWith('.png')) pngs++; } } catch (_) {} }
  final node = FolderNode(name: name, fullPath: path.replaceAll('\\', '/'), depth: depth, pngCount: pngs);
  if (depth >= maxDepth || !await dir.exists()) return node;
  final ch = <FolderNode>[];
  try { await for (final e in dir.list()) { if (e is Directory) { final cn = e.path.replaceAll('\\', '/').split('/').last; if (!cn.startsWith('.') && cn != 'originals') ch.add(await scanFolder(e.path.replaceAll('\\', '/'), depth: depth + 1, maxDepth: maxDepth)); } } } catch (_) {}
  ch.sort((a, b) => a.name.compareTo(b.name));
  node.children = ch;
  return node;
}

// ══════════════════════════════════════════
// Dock Layout System
// ══════════════════════════════════════════

enum DropZone { left, right, top, bottom }

abstract class DockLayout {
  Map<String, dynamic> toJson();
  static DockLayout fromJson(Map<String, dynamic> j) {
    if (j['type'] == 'panel') return DockPanel(j['id']);
    return DockSplit(
      first: DockLayout.fromJson(j['first']), second: DockLayout.fromJson(j['second']),
      horizontal: j['horizontal'] ?? true, ratio: (j['ratio'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class DockPanel extends DockLayout {
  final String id;
  DockPanel(this.id);
  @override Map<String, dynamic> toJson() => {'type': 'panel', 'id': id};
}

class DockSplit extends DockLayout {
  DockLayout first, second;
  bool horizontal;
  double ratio;
  DockSplit({required this.first, required this.second, this.horizontal = true, this.ratio = 0.5});
  @override Map<String, dynamic> toJson() => {'type': 'split', 'horizontal': horizontal, 'ratio': ratio, 'first': first.toJson(), 'second': second.toJson()};
}

DockLayout get _defaultLayout => DockSplit(
  horizontal: true, ratio: 0.18,
  first: DockSplit(
    horizontal: false, ratio: 0.6,
    first: DockPanel('projects'),
    second: DockPanel('editor'),
  ),
  second: DockSplit(
    horizontal: true, ratio: 0.6,
    first: DockPanel('preview'),
    second: DockSplit(horizontal: false, ratio: 0.45, first: DockPanel('directions'), second: DockPanel('frames')),
  ),
);

bool _containsPanel(DockLayout layout, String id) {
  if (layout is DockPanel) return layout.id == id;
  if (layout is DockSplit) return _containsPanel(layout.first, id) || _containsPanel(layout.second, id);
  return false;
}

DockLayout? _removePanel(DockLayout layout, String id) {
  if (layout is DockPanel) return layout.id == id ? null : layout;
  final s = layout as DockSplit;
  if (s.first is DockPanel && (s.first as DockPanel).id == id) return s.second;
  if (s.second is DockPanel && (s.second as DockPanel).id == id) return s.first;
  final f = _removePanel(s.first, id);
  if (f == null) return s.second;
  final sc = _removePanel(s.second, id);
  if (sc == null) return s.first;
  s.first = f; s.second = sc;
  return s;
}

DockLayout _insertPanel(DockLayout layout, String panelId, String targetId, DropZone zone) {
  if (layout is DockPanel && layout.id == targetId) {
    final p = DockPanel(panelId);
    return switch (zone) {
      DropZone.left => DockSplit(first: p, second: layout, horizontal: true, ratio: 0.5),
      DropZone.right => DockSplit(first: layout, second: p, horizontal: true, ratio: 0.5),
      DropZone.top => DockSplit(first: p, second: layout, horizontal: false, ratio: 0.5),
      DropZone.bottom => DockSplit(first: layout, second: p, horizontal: false, ratio: 0.5),
    };
  }
  if (layout is DockSplit) {
    layout.first = _insertPanel(layout.first, panelId, targetId, zone);
    layout.second = _insertPanel(layout.second, panelId, targetId, zone);
  }
  return layout;
}

// ══════════════════════════════════════════
// Main Gallery
// ══════════════════════════════════════════

class CharacterGallery extends StatefulWidget {
  const CharacterGallery({super.key});
  @override State<CharacterGallery> createState() => _CharacterGalleryState();
}

class _CharacterGalleryState extends State<CharacterGallery> {
  List<CharacterInfo>? _characters;
  int _selectedChar = 0;
  bool _loading = true;
  CharacterInfo? _currentChar;

  final ValueNotifier<int> _displayFrame = ValueNotifier(0);
  int _currentFrame = 0;
  bool _playing = true;
  Timer? _animTimer;
  List<int>? _previewFrames;
  int _previewIndex = 0;
  String? _previewLabel;

  Set<int> _selectedFrames = {};
  int? _lastClickedFrame;

  DirectionData _dirData = DirectionData();
  String? _activeDirection;
  bool _transitionMode = false;
  String? _transFrom, _transTo;

  // Compass node editor
  Map<String, Offset> _dirPositions = {};
  List<VisualTransition> _visualTransitions = [];
  List<AnimationNode> _animationNodes = [];
  String? _connectingTransId; // transition being connected
  String? _connectingAnimId; // animation being connected to direction
  int _connectStep = 0; // 0=idle, 1=picking from, 2=picking to

  String? _selectedNodeId; // currently selected node (trans or anim id, or dir key)

  // Frames panel filter
  int _framesTab = 0; // 0=all, 1=node frames
  String? _filteredNodeLabel;
  List<int>? _filteredFrames;

  // Frame editor
  double _brushSize = 20;
  bool _eraseMode = true; // true=erase, false=restore from original

  final Map<int, ImageProvider> _imageCache = {};

  List<ProjectInfo> _projects = [];
  int _selectedProject = 0;
  FolderNode? _projectTree;
  String? _selectedFolder;

  bool _extracting = false;
  String _extractProgress = '';

  // Dock layout
  late DockLayout _dockLayout;

  @override
  void initState() {
    super.initState();
    _dockLayout = _defaultLayout;
    _init();
  }

  @override
  void dispose() { _animTimer?.cancel(); _displayFrame.dispose(); super.dispose(); }

  Future<void> _init() async {
    await _loadProjects();
    await _loadCharacters();
    await _restoreState();
  }

  Future<void> _saveState() async {
    await File(_statePath).writeAsString(const JsonEncoder.withIndent('  ').convert({
      'selectedProject': _selectedProject, 'selectedFolder': _selectedFolder,
      'selectedChar': _currentChar?.dirPath, 'dockLayout': _dockLayout.toJson(),
    }));
  }

  Future<void> _restoreState() async {
    final f = File(_statePath);
    if (!await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString());
      if (j['dockLayout'] != null) _dockLayout = DockLayout.fromJson(j['dockLayout']);
      final pi = j['selectedProject'] as int? ?? 0;
      if (pi < _projects.length) { _selectedProject = pi; await _scanCurrentProject(); }
      final fo = j['selectedFolder'] as String?;
      if (fo != null && await Directory(fo).exists()) _selectedFolder = fo;
      final cp = j['selectedChar'] as String?;
      if (cp != null) {
        final idx = (_characters ?? []).indexWhere((c) => c.dirPath == cp);
        if (idx >= 0) _switchCharacter(idx);
        else if (await Directory(cp).exists()) await _loadFromFolder(cp);
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadProjects() async { final p = await loadProjects(); setState(() => _projects = p); if (p.isNotEmpty) await _scanCurrentProject(); }
  Future<void> _scanCurrentProject() async { if (_projects.isEmpty) return; final t = await scanFolder(_projects[_selectedProject].path); t.expanded = true; setState(() => _projectTree = t); }
  Future<void> _loadCharacters() async { final c = await discoverCharacters(); setState(() { _characters = c; _loading = false; }); }

  void _loadChar(CharacterInfo char) {
    _animTimer?.cancel(); _imageCache.clear(); _currentFrame = 0; _displayFrame.value = 0;
    setState(() { _currentChar = char; _selectedFrames.clear(); _activeDirection = null; _transitionMode = false; _transFrom = null; _transTo = null; _dirData = DirectionData(); _previewFrames = null; _previewLabel = null; });
    for (int i = 0; i < char.frameCount; i++) _imageCache[i] = FileImage(File(char.framePath(i)));
    _loadDirectionData(char); if (_playing) _startTimer(); _saveState();
  }

  void _switchCharacter(int i) { setState(() => _selectedChar = i); _loadChar(_characters![i]); }

  Future<void> _loadFromFolder(String path) async {
    int fc = 0; int w = 0, h = 0;
    final af = File('$path/anim.json');
    if (await af.exists()) { try { final m = jsonDecode(await af.readAsString()); fc = m['frame_count'] ?? 0; w = m['width'] ?? 0; h = m['height'] ?? 0; } catch (_) {} }
    if (fc == 0) { try { await for (final f in Directory(path).list()) { if (f is File && RegExp(r'frame_\d+\.png$').hasMatch(f.path.replaceAll('\\', '/'))) fc++; } } catch (_) {} }
    if (fc == 0) return;
    _loadChar(CharacterInfo(name: path.split('/').last, dirPath: path, frameCount: fc, width: w, height: h));
  }

  void _startTimer() {
    _animTimer?.cancel(); final c = _currentChar; if (c == null) return;
    _animTimer = Timer.periodic(const Duration(milliseconds: 42), (_) {
      if (!_playing) return;
      if (_previewFrames != null && _previewFrames!.isNotEmpty) { _previewIndex = (_previewIndex + 1) % _previewFrames!.length; _currentFrame = _previewFrames![_previewIndex]; }
      else { _currentFrame = (_currentFrame + 1) % c.frameCount; }
      _displayFrame.value = _currentFrame;
    });
  }

  void _playSubset(List<int> frames, String label) {
    if (frames.isEmpty) return; _currentFrame = frames.first; _displayFrame.value = _currentFrame;
    setState(() { _previewFrames = List<int>.from(frames)..sort(); _previewIndex = 0; _previewLabel = label; _playing = true; }); _startTimer();
  }

  void _playAll() { setState(() { _previewFrames = null; _previewLabel = null; _previewIndex = 0; _playing = true; }); _startTimer(); }

  Future<void> _loadDirectionData(CharacterInfo c) async {
    final f = File('${c.dirPath}/directions.json');
    if (await f.exists()) {
      try {
        final j = jsonDecode(await f.readAsString());
        final dd = DirectionData.fromJson(j);
        // Load visual layout
        Map<String, Offset> pos = {};
        List<VisualTransition> vt = [];
        if (j['layout'] != null) {
          final lay = j['layout'] as Map<String, dynamic>;
          if (lay['dirPositions'] != null) {
            (lay['dirPositions'] as Map<String, dynamic>).forEach((k, v) {
              final l = v as List; pos[k] = Offset((l[0] as num).toDouble(), (l[1] as num).toDouble());
            });
          }
          if (lay['transitionNodes'] != null) {
            vt = (lay['transitionNodes'] as List).map((e) => VisualTransition.fromJson(e)).toList();
          }
          if (lay['animationNodes'] != null) {
            _animationNodes = (lay['animationNodes'] as List).map((e) => AnimationNode.fromJson(e)).toList();
          }
        }
        setState(() { _dirData = dd; _dirPositions = pos; _visualTransitions = vt; });
      } catch (_) {}
    }
  }

  Future<void> _saveDirectionData() async {
    final c = _currentChar; if (c == null) return;
    final data = _dirData.toJson();
    data['layout'] = {
      'dirPositions': _dirPositions.map((k, v) => MapEntry(k, [v.dx, v.dy])),
      'transitionNodes': _visualTransitions.map((t) => t.toJson()).toList(),
      'animationNodes': _animationNodes.map((a) => a.toJson()).toList(),
    };
    await File('${c.dirPath}/directions.json').writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  void _assignToTransition(String from, String to) {
    if (_selectedFrames.isEmpty) return; final key = '${from}_to_$to';
    setState(() { _dirData.transitions.putIfAbsent(key, () => []); for (final f in _selectedFrames) { if (!_dirData.transitions[key]!.contains(f)) _dirData.transitions[key]!.add(f); } _dirData.transitions[key]!.sort(); _selectedFrames.clear(); });
    _saveDirectionData();
    _exportTransitionToSubfolder(from, to);
  }

  Future<void> _exportTransitionToSubfolder(String from, String to) async {
    final c = _currentChar; if (c == null) return;
    final key = '${from}_to_$to';
    final frames = _dirData.transitions[key]; if (frames == null || frames.isEmpty) return;
    final folderName = _transitionFolderName(from, to);
    final dir = Directory('${c.dirPath}/transitions/$folderName');
    await dir.create(recursive: true);
    // Clear old frames
    try { await for (final f in dir.list()) { if (f is File && f.path.endsWith('.png')) await f.delete(); } } catch (_) {}
    for (int i = 0; i < frames.length; i++) await File(c.framePath(frames[i])).copy('${dir.path}/frame_${i.toString().padLeft(3, '0')}.png');
    await File('${dir.path}/anim.json').writeAsString(const JsonEncoder.withIndent('  ').convert({'frame_count': frames.length, 'transition': key, 'source_frames': frames, 'width': c.width, 'height': c.height}));
    await _scanCurrentProject();
  }

  void _onFrameTap(int index, {bool shift = false, bool ctrl = false}) {
    setState(() {
      if (shift && _lastClickedFrame != null) { final a = _lastClickedFrame! < index ? _lastClickedFrame! : index; final b = _lastClickedFrame! > index ? _lastClickedFrame! : index; for (int i = a; i <= b; i++) _selectedFrames.add(i); }
      else if (ctrl) { _selectedFrames.contains(index) ? _selectedFrames.remove(index) : _selectedFrames.add(index); }
      else { _selectedFrames.clear(); _selectedFrames.add(index); }
      _lastClickedFrame = index; _currentFrame = index; _displayFrame.value = index; _playing = false;
    });
  }

  // --- Dock operations ---
  void _handlePanelDrop(String draggedId, String targetId, DropZone zone) {
    if (draggedId == targetId) return;
    final removed = _removePanel(_dockLayout, draggedId);
    if (removed == null) return;
    _dockLayout = _insertPanel(removed, draggedId, targetId, zone);
    setState(() {}); _saveState();
  }

  void _resetLayout() { setState(() => _dockLayout = _defaultLayout); _saveState(); }

  // --- Folder management ---
  Future<void> _moveFolder(String src, String tgt) async {
    if (src == tgt || tgt.startsWith('$src/')) return;
    final n = src.split('/').last;
    try { await Directory(src).rename('$tgt/$n'); await _scanCurrentProject(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved $n'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Move failed: $e'), backgroundColor: Colors.red.shade800)); }
  }

  Future<void> _renameFolder(String path) async {
    final cur = path.split('/').last; String nn = cur;
    final r = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Rename'), content: TextFormField(initialValue: cur, onChanged: (v) => nn = v, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Rename'))]));
    if (r == true && nn.isNotEmpty && nn != cur) { final p = path.substring(0, path.lastIndexOf('/')); try { await Directory(path).rename('$p/$nn'); if (_selectedFolder == path) _selectedFolder = '$p/$nn'; await _scanCurrentProject(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800)); } }
  }

  Future<void> _deleteFolder(String path) async {
    final r = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${path.split('/').last}" and all contents?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    if (r == true) { try { await Directory(path).delete(recursive: true); if (_selectedFolder == path) _selectedFolder = null; await _scanCurrentProject(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800)); } }
  }

  void _showFolderMenu(Offset pos, FolderNode node) {
    final root = _projects.isNotEmpty ? _projects[_selectedProject].path : '';
    final parentPath = node.fullPath.contains('/') ? node.fullPath.substring(0, node.fullPath.lastIndexOf('/')) : null;
    final canMoveUp = node.fullPath != root && parentPath != null && parentPath != node.fullPath;
    final grandParent = canMoveUp && parentPath!.contains('/') ? parentPath.substring(0, parentPath.lastIndexOf('/')) : null;
    final hasGrandParent = grandParent != null && grandParent.isNotEmpty;

    showMenu<String>(context: context, position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1), color: const Color(0xFF1a1a3e), items: [
      const PopupMenuItem(value: 'copy_path', child: Row(children: [Icon(Icons.copy, size: 16, color: Colors.cyan), SizedBox(width: 8), Text('Copy Full Path', style: TextStyle(fontSize: 12))])),
      const PopupMenuItem(value: 'new', child: Row(children: [Icon(Icons.create_new_folder, size: 16, color: Colors.white54), SizedBox(width: 8), Text('New Subfolder', style: TextStyle(fontSize: 12))])),
      if (hasGrandParent) PopupMenuItem(value: 'move_up', child: Row(children: [const Icon(Icons.drive_file_move_outline, size: 16, color: Colors.amber), const SizedBox(width: 8), Text('Move to ${grandParent.split('/').last}', style: const TextStyle(fontSize: 12))])),
      if (node.fullPath != root) const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.white54), SizedBox(width: 8), Text('Rename', style: TextStyle(fontSize: 12))])),
      if (node.fullPath != root) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red))])),
    ]).then((a) {
      if (a == 'copy_path') { Clipboard.setData(ClipboardData(text: node.fullPath)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: ${node.fullPath}'), duration: const Duration(seconds: 1))); }
      else if (a == 'new') { _selectedFolder = node.fullPath; _createSubfolder(); }
      else if (a == 'move_up' && hasGrandParent) _moveFolder(node.fullPath, grandParent);
      else if (a == 'rename') _renameFolder(node.fullPath);
      else if (a == 'delete') _deleteFolder(node.fullPath);
    });
  }

  Future<void> _copyFramesToFolder() async {
    final c = _currentChar; if (_selectedFolder == null || _selectedFrames.isEmpty || c == null) return;
    await Directory(_selectedFolder!).create(recursive: true);
    final sf = _selectedFrames.toList()..sort();
    for (int i = 0; i < sf.length; i++) await File(c.framePath(sf[i])).copy('${_selectedFolder!}/frame_${i.toString().padLeft(3, '0')}.png');
    await File('${_selectedFolder!}/anim.json').writeAsString(const JsonEncoder.withIndent('  ').convert({'frame_count': sf.length, 'source': c.name, 'source_frames': sf, 'width': c.width, 'height': c.height}));
    await _scanCurrentProject();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${sf.length} frames')));
  }

  Future<void> _addProject() async {
    String name = '', path = '';
    final r = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Add Project'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(decoration: const InputDecoration(labelText: 'Name'), onChanged: (v) => name = v), const SizedBox(height: 8), TextField(decoration: const InputDecoration(labelText: 'Path', hintText: 'C:/Projects/Game/assets'), onChanged: (v) => path = v)]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add'))]));
    if (r == true && name.isNotEmpty && path.isNotEmpty) { _projects.add(ProjectInfo(name: name, path: path.replaceAll('\\', '/'))); await saveProjects(_projects); await Directory(path).create(recursive: true); setState(() => _selectedProject = _projects.length - 1); await _scanCurrentProject(); _saveState(); }
  }

  Future<void> _createSubfolder() async {
    final parent = _selectedFolder ?? _projects[_selectedProject].path; String fn = '';
    final r = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('New Folder'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('In: ${parent.split('/').last}', style: const TextStyle(fontSize: 12, color: Colors.white54)), const SizedBox(height: 8), TextField(decoration: const InputDecoration(labelText: 'Name'), onChanged: (v) => fn = v, autofocus: true)]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create'))]));
    if (r == true && fn.isNotEmpty) { await Directory('$parent/$fn').create(recursive: true); await _scanCurrentProject(); }
  }

  Future<void> _exportDirections() async {
    if (_selectedFolder == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a target folder first'))); return; }
    final c = _currentChar; if (c == null) return; int exp = 0;
    for (final e in _dirData.directions.entries) { if (e.value.isEmpty) continue; final d = Directory('${_selectedFolder!}/${e.key}'); await d.create(recursive: true); for (int i = 0; i < e.value.length; i++) await File(c.framePath(e.value[i])).copy('${d.path}/frame_${i.toString().padLeft(3, '0')}.png'); await File('${d.path}/anim.json').writeAsString(const JsonEncoder.withIndent('  ').convert({'frame_count': e.value.length, 'direction': e.key, 'source_frames': e.value, 'width': c.width, 'height': c.height})); exp += e.value.length; }
    for (final e in _dirData.transitions.entries) { if (e.value.isEmpty) continue; final d = Directory('${_selectedFolder!}/transitions/${e.key}'); await d.create(recursive: true); for (int i = 0; i < e.value.length; i++) await File(c.framePath(e.value[i])).copy('${d.path}/frame_${i.toString().padLeft(3, '0')}.png'); await File('${d.path}/anim.json').writeAsString(const JsonEncoder.withIndent('  ').convert({'frame_count': e.value.length, 'transition': e.key, 'source_frames': e.value, 'width': c.width, 'height': c.height})); exp += e.value.length; }
    await _scanCurrentProject(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported $exp frames')));
  }

  Future<void> _showExtractDialog() async {
    // If an animation node is selected, use its folder
    if (_selectedNodeId != null) {
      final selAnim = _animationNodes.where((a) => a.id == _selectedNodeId).toList();
      if (selAnim.isNotEmpty) { _showExtractDialogForAnim(selAnim.first); return; }
    }
    String vp = '', tf = _selectedFolder ?? (_projects.isNotEmpty ? _projects[_selectedProject].path : '');
    bool rb = true; double gamma = 1.0; double threshold = 1.0;
    final vpCtrl = TextEditingController();
    final tfCtrl = TextEditingController(text: tf);
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      title: const Text('Extract Frames'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Expanded(child: TextField(controller: vpCtrl, decoration: const InputDecoration(labelText: 'Video (MP4)', isDense: true), onChanged: (v) => vp = v)),
          IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Browse video', onPressed: () async { final p = await Process.run('powershell', ['-Command', 'Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Filter = "MP4|*.mp4|All|*.*"; if(\$f.ShowDialog() -eq "OK"){\$f.FileName}']); final pk = p.stdout.toString().trim(); if (pk.isNotEmpty) { vp = pk.replaceAll('\\', '/'); vpCtrl.text = vp; ss(() {}); } })]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: tfCtrl, decoration: const InputDecoration(labelText: 'Output Folder', isDense: true), onChanged: (v) => tf = v)),
          IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Browse folder', onPressed: () async { final p = await Process.run('powershell', ['-Command', 'Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.FolderBrowserDialog; if(\$f.ShowDialog() -eq "OK"){\$f.SelectedPath}']); final pk = p.stdout.toString().trim(); if (pk.isNotEmpty) { tf = pk.replaceAll('\\', '/'); tfCtrl.text = tf; ss(() {}); } })]),
        const SizedBox(height: 12),
        Row(children: [Checkbox(value: rb, onChanged: (v) => ss(() => rb = v ?? true)), const Text('Remove background', style: TextStyle(fontSize: 12))]),
        if (rb) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Model: BiRefNet (GPU only)', style: TextStyle(fontSize: 11, color: Colors.lightGreenAccent)),
          ),
        ],
        if (rb) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Edge: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
            Expanded(child: Slider(value: gamma, min: 0.3, max: 3.0, divisions: 27,
              onChanged: (v) => ss(() => gamma = v))),
            Text(gamma.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
          Text(gamma < 0.7 ? 'Soft edges — keeps everything' : gamma > 1.5 ? 'Sharp edges — tight cutout' : 'Balanced — original mask',
            style: TextStyle(fontSize: 10, color: gamma < 0.7 ? Colors.green : gamma > 1.5 ? Colors.orange : Colors.white38)),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Cutoff: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
            Expanded(child: Slider(value: threshold, min: 0.0, max: 1.0, divisions: 20,
              onChanged: (v) => ss(() => threshold = v))),
            Text(threshold >= 1.0 ? 'OFF' : threshold.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
          Text(threshold >= 1.0 ? 'No hard cutoff' : 'Pixels below ${(threshold * 100).toInt()}% become transparent',
            style: TextStyle(fontSize: 10, color: threshold < 0.3 ? Colors.orange : Colors.white38)),
        ],
      ])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, {'video': vp, 'output': tf, 'rb': rb, 'gamma': gamma, 'threshold': threshold}), child: const Text('Extract'))])));
    if (r != null && r['video'].toString().isNotEmpty) _runExtraction(r['video'], r['output'], r['rb'], gamma: r['gamma'] ?? 1.0, threshold: r['threshold'] ?? 1.0);
  }

  Future<void> _showExtractDialogForAnim(AnimationNode an) async {
    final c = _currentChar; if (c == null) return;
    final dirName = an.connectedDir != null ? kDirFullNames[an.connectedDir!] ?? an.connectedDir! : 'unlinked';
    final animFolder = '${c.dirPath}/animations/${an.name.replaceAll(' ', '_')}/$dirName';
    await Directory(animFolder).create(recursive: true);

    String vp = ''; final tf = animFolder;
    bool rb = true; double gamma = 1.0; double threshold = 1.0;
    final vpCtrl = TextEditingController();
    final tfCtrl = TextEditingController(text: tf);
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: Text('Extract: ${an.name} (${kDirLabels[an.connectedDir] ?? dirName})'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.withOpacity(0.3))),
          child: Row(children: [const Icon(Icons.folder, size: 14, color: Colors.green), const SizedBox(width: 6), Expanded(child: Text(animFolder.split(c.dirPath + '/').last, style: const TextStyle(fontSize: 11, color: Colors.green)))])),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: vpCtrl, decoration: const InputDecoration(labelText: 'Video (MP4)', isDense: true), onChanged: (v) => vp = v)),
          IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Browse video', onPressed: () async { final p = await Process.run('powershell', ['-Command', 'Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Filter = "MP4|*.mp4|All|*.*"; if(\$f.ShowDialog() -eq "OK"){\$f.FileName}']); final pk = p.stdout.toString().trim(); if (pk.isNotEmpty) { vp = pk.replaceAll('\\', '/'); vpCtrl.text = vp; ss(() {}); } })]),
        const SizedBox(height: 12),
        Row(children: [Checkbox(value: rb, onChanged: (v) => ss(() => rb = v ?? true)), const Text('Remove background', style: TextStyle(fontSize: 12))]),
        if (rb) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Model: BiRefNet (GPU only)', style: TextStyle(fontSize: 11, color: Colors.lightGreenAccent)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Edge: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
            Expanded(child: Slider(value: gamma, min: 0.3, max: 3.0, divisions: 27, onChanged: (v) => ss(() => gamma = v))),
            Text(gamma.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Cutoff: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
            Expanded(child: Slider(value: threshold, min: 0.0, max: 1.0, divisions: 20, onChanged: (v) => ss(() => threshold = v))),
            Text(threshold >= 1.0 ? 'OFF' : threshold.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ],
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, {'video': vp, 'output': tf, 'rb': rb, 'gamma': gamma, 'threshold': threshold}), child: const Text('Extract'))])));
    if (r != null && r['video'].toString().isNotEmpty) {
      an.sourceFolder = animFolder;
      _saveDirectionData();
      _runExtraction(r['video'], r['output'], r['rb'], gamma: r['gamma'] ?? 1.0, threshold: r['threshold'] ?? 1.0);
    }
  }

  Future<void> _runExtraction(String vp, String od, bool rb, {double gamma = 1.0, double threshold = 1.0}) async {
    setState(() { _extracting = true; _extractProgress = 'Starting...'; });
    try {
      final pythonExe = _resolveExtractionPython();
      if (pythonExe == null) {
        throw Exception('No Python runtime found with CUDAExecutionProvider and extraction dependencies.');
      }
      final extractScriptPath = _resolveExtractionScriptPath();
      if (extractScriptPath == null) {
        throw Exception('Missing extract script. Checked: ${_extractScriptCandidates.join(', ')}');
      }
      final p = await Process.start(pythonExe, [extractScriptPath, '--input', vp, '--output', od, if (!rb) '--no-rembg', '--gamma', gamma.toString(), '--threshold', threshold.toString(), '--model', 'birefnet']);
      final errBuf = StringBuffer();
      p.stdout.transform(const SystemEncoding().decoder).listen((l) { for (final s in l.split('\n')) { final t = s.trim(); if (t.startsWith('PROGRESS:')) setState(() => _extractProgress = t.replaceFirst('PROGRESS:', '')); else if (t.startsWith('DONE:')) { setState(() { _extracting = false; _extractProgress = ''; }); _scanCurrentProject(); } else if (t.isNotEmpty) setState(() => _extractProgress = t.length > 40 ? '${t.substring(0, 40)}...' : t); } });
      p.stderr.transform(const SystemEncoding().decoder).listen((l) => errBuf.write(l));
      p.exitCode.then((code) { if (code != 0 && _extracting) { setState(() { _extracting = false; _extractProgress = ''; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extract failed (code $code): ${errBuf.toString().trim().split('\n').last}'), backgroundColor: Colors.red.shade800, duration: const Duration(seconds: 5))); } });
    } catch (e) { setState(() { _extracting = false; _extractProgress = ''; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extract error: $e'), backgroundColor: Colors.red.shade800)); }
  }

  // ══════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF0a0a1a), body: Center(child: CircularProgressIndicator()));
    final dc = _currentChar;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        title: Row(children: [
          Text(dc?.name ?? 'Pixel Guy'),
          if (dc != null) ...[const SizedBox(width: 8), ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, f, __) => Text('Frame ${f + 1}/${dc.frameCount}', style: const TextStyle(fontSize: 13, color: Colors.white54)))],
          if (_previewLabel != null) ...[const SizedBox(width: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text(_previewLabel!, style: const TextStyle(fontSize: 11, color: Colors.amber)))],
        ]),
        actions: [
          if (_extracting) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 6), Text(_extractProgress, style: const TextStyle(fontSize: 11, color: Colors.amber))])),
          if (_previewFrames != null) IconButton(icon: const Icon(Icons.all_inclusive, size: 20), tooltip: 'Play All', onPressed: _playAll),
          IconButton(icon: const Icon(Icons.video_file, size: 20), tooltip: 'Extract Video', onPressed: _extracting ? null : _showExtractDialog),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: () async { setState(() => _loading = true); await _loadProjects(); await _loadCharacters(); }),
          IconButton(icon: const Icon(Icons.save_alt), tooltip: 'Export Directions', onPressed: _exportDirections),
          PopupMenuButton<String>(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Layout',
            color: const Color(0xFF1a1a3e),
            onSelected: (v) {
              if (v == 'reset') _resetLayout();
              else _reopenPanel(v);
            },
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[];
              for (final id in ['projects', 'preview', 'directions', 'frames', 'editor']) {
                if (!_containsPanel(_dockLayout, id)) {
                  const labels = {'projects': 'Projects', 'preview': 'Preview', 'directions': 'Directions', 'frames': 'Frames'};
                  items.add(PopupMenuItem(value: id, child: Row(children: [const Icon(Icons.add, size: 16, color: Colors.green), const SizedBox(width: 8), Text('Open ${labels[id]}', style: const TextStyle(fontSize: 12))])));
                }
              }
              items.add(const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.restart_alt, size: 16, color: Colors.white54), SizedBox(width: 8), Text('Reset Layout', style: TextStyle(fontSize: 12))])));
              return items;
            },
          ),
        ],
      ),
      body: _buildDockNode(_dockLayout),
    );
  }

  // --- Dock Layout Renderer ---
  Widget _buildDockNode(DockLayout node) {
    if (node is DockPanel) return _wrapPanel(node.id);
    final s = node as DockSplit;
    return LayoutBuilder(builder: (ctx, box) {
      if (s.horizontal) {
        final fw = (box.maxWidth - 6) * s.ratio;
        final sw = box.maxWidth - 6 - fw;
        return Row(children: [
          SizedBox(width: fw, child: _buildDockNode(s.first)),
          MouseRegion(cursor: SystemMouseCursors.resizeColumn, child: GestureDetector(behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => setState(() => s.ratio = (s.ratio + d.delta.dx / (box.maxWidth - 6)).clamp(0.1, 0.9)),
            onHorizontalDragEnd: (_) => _saveState(),
            child: Container(width: 6, color: Colors.transparent, child: Center(child: Container(width: 2, height: double.infinity, color: Colors.white12))))),
          SizedBox(width: sw, child: _buildDockNode(s.second)),
        ]);
      } else {
        final fh = (box.maxHeight - 6) * s.ratio;
        final sh = box.maxHeight - 6 - fh;
        return Column(children: [
          SizedBox(height: fh, child: _buildDockNode(s.first)),
          MouseRegion(cursor: SystemMouseCursors.resizeRow, child: GestureDetector(behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => setState(() => s.ratio = (s.ratio + d.delta.dy / (box.maxHeight - 6)).clamp(0.1, 0.9)),
            onVerticalDragEnd: (_) => _saveState(),
            child: Container(height: 6, color: Colors.transparent, child: Center(child: Container(height: 2, width: double.infinity, color: Colors.white12))))),
          SizedBox(height: sh, child: _buildDockNode(s.second)),
        ]);
      }
    });
  }

  void _closePanel(String id) {
    final removed = _removePanel(_dockLayout, id);
    if (removed != null) {
      setState(() => _dockLayout = removed);
      _saveState();
    }
  }

  void _reopenPanel(String id) {
    if (_containsPanel(_dockLayout, id)) return;
    setState(() {
      _dockLayout = DockSplit(first: _dockLayout, second: DockPanel(id), horizontal: true, ratio: 0.75);
    });
    _saveState();
  }

  Widget _wrapPanel(String id) {
    const titles = {'projects': 'Projects', 'preview': 'Preview', 'directions': 'Directions', 'frames': 'Frames', 'editor': 'Frame Editor'};
    return DockPanelWrapper(
      id: id, title: titles[id] ?? id,
      onDrop: (draggedId, zone) => _handlePanelDrop(draggedId, id, zone),
      onClose: () => _closePanel(id),
      child: _buildPanelContent(id),
    );
  }

  Widget _buildPanelContent(String id) {
    switch (id) {
      case 'projects': return _buildProjectsContent();
      case 'preview': return _currentChar != null ? _buildPreviewContent(_currentChar!) : const Center(child: Text('Select a folder with frames', style: TextStyle(color: Colors.white24)));
      case 'directions': return _currentChar != null ? _buildDirectionsContent() : const SizedBox();
      case 'frames': return _currentChar != null ? _buildFramesContent(_currentChar!) : const SizedBox();
      case 'editor': return _currentChar != null ? _buildEditorContent(_currentChar!) : const Center(child: Text('Load a character first', style: TextStyle(color: Colors.white24)));
      default: return const SizedBox();
    }
  }

  // ══════════════════════════════════════════
  // Panel Contents
  // ══════════════════════════════════════════

  // --- Projects ---
  Widget _buildProjectsContent() {
    return Column(children: [
      // Project selector
      Padding(padding: const EdgeInsets.all(6), child: Row(children: [
        Expanded(child: DropdownButton<int>(value: _projects.isNotEmpty ? _selectedProject : null, isExpanded: true, dropdownColor: const Color(0xFF1a1a3e), style: const TextStyle(fontSize: 12), underline: const SizedBox(), hint: const Text('No projects', style: TextStyle(fontSize: 11, color: Colors.white38)),
          items: List.generate(_projects.length, (i) => DropdownMenuItem(value: i, child: Text(_projects[i].name, overflow: TextOverflow.ellipsis))),
          onChanged: (v) { if (v != null) { setState(() { _selectedProject = v; _selectedFolder = null; }); _scanCurrentProject(); _saveState(); } })),
        const SizedBox(width: 4),
        InkWell(onTap: _addProject, borderRadius: BorderRadius.circular(4), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 18, color: Colors.white54))),
      ])),
      const Divider(height: 1, color: Colors.white12),
      // Folder tree
      Expanded(child: _buildFolderTree()),
      // Actions
      Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Column(children: [
        Row(children: [
          Expanded(child: _actionBtn(Icons.create_new_folder, 'New', _createSubfolder)),
          const SizedBox(width: 4),
          Expanded(child: _actionBtn(Icons.content_copy, 'Copy ${_selectedFrames.length}', _selectedFrames.isNotEmpty && _selectedFolder != null ? _copyFramesToFolder : null)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _actionBtn(Icons.edit, 'Rename', _selectedFolder != null ? () => _renameFolder(_selectedFolder!) : null)),
          const SizedBox(width: 4),
          Expanded(child: _actionBtn(Icons.delete_outline, 'Delete', _selectedFolder != null ? () => _deleteFolder(_selectedFolder!) : null, danger: true)),
        ]),
      ])),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback? onTap, {bool danger = false}) {
    final on = onTap != null; final c = danger ? Colors.red.shade300 : Colors.amber;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(4), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: on ? c.withOpacity(0.5) : Colors.white12), borderRadius: BorderRadius.circular(4), color: on ? c.withOpacity(0.08) : null),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 12, color: on ? c : Colors.white24), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 9, color: on ? c : Colors.white24))]),
    ));
  }

  Widget _buildFolderTree() {
    if (_projectTree == null) return const Center(child: Text('No project', style: TextStyle(fontSize: 11, color: Colors.white24)));
    final flat = <FolderNode>[]; void fl(FolderNode n) { flat.add(n); if (n.expanded) for (final c in n.children) fl(c); } fl(_projectTree!);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}),
      child: ListView.builder(itemCount: flat.length, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), itemBuilder: (_, i) {
        final n = flat[i]; final sel = _selectedFolder == n.fullPath; final hc = n.children.isNotEmpty; final hp = n.pngCount > 0;
        final thumbFile = File('${n.fullPath}/frame_000.png');
        final content = Container(
          padding: EdgeInsets.only(left: 4.0 + n.depth * 12.0, top: 3, bottom: 3, right: 4), height: hp ? 52 : null,
          decoration: BoxDecoration(color: sel ? Colors.amber.withOpacity(0.15) : null, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            if (hp) ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 40, height: 46, child: Image.file(thumbFile, fit: BoxFit.contain, filterQuality: FilterQuality.medium, errorBuilder: (_, __, ___) => Icon(Icons.folder, size: 18, color: sel ? Colors.amber : Colors.green.shade300))))
            else Icon(hc ? (n.expanded ? Icons.folder_open : Icons.folder) : Icons.folder_outlined, size: 14, color: sel ? Colors.amber : Colors.white38),
            const SizedBox(width: 6),
            Expanded(child: Text(n.name, style: TextStyle(fontSize: 11, color: sel ? Colors.amber : Colors.white70, fontWeight: sel ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
            if (hp) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('${n.pngCount}', style: TextStyle(fontSize: 8, color: Colors.green.shade300))),
          ]),
        );
        return DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data != n.fullPath && !d.data.startsWith('${n.fullPath}/'),
          onAcceptWithDetails: (d) => _moveFolder(d.data, n.fullPath),
          builder: (_, cd, __) => Draggable<String>(
            data: n.fullPath,
            feedback: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF2a2a4e), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.5))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.folder, size: 14, color: Colors.amber), const SizedBox(width: 6), Text(n.name, style: const TextStyle(fontSize: 11, color: Colors.white, decoration: TextDecoration.none))]))),
            childWhenDragging: Opacity(opacity: 0.3, child: content),
            child: GestureDetector(behavior: HitTestBehavior.opaque,
              onTap: () { setState(() { _selectedFolder = n.fullPath; if (hc) n.expanded = !n.expanded; }); _saveState(); if (hp) _loadFromFolder(n.fullPath); },
              onSecondaryTapDown: (d) => _showFolderMenu(d.globalPosition, n),
              child: Container(decoration: BoxDecoration(border: cd.isNotEmpty ? Border.all(color: Colors.amber, width: 2) : null, borderRadius: BorderRadius.circular(4), color: cd.isNotEmpty ? Colors.amber.withOpacity(0.1) : null), child: content)),
          ),
        );
      }),
    );
  }

  // --- Preview ---
  Widget _buildPreviewContent(CharacterInfo char) {
    return Column(children: [
      ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, f, __) {
        final d = _dirData.getFrameDirection(f); final t = _dirData.getFrameTransition(f);
        if (d == null && t == null) return const SizedBox.shrink();
        return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), color: (d != null ? kDirColors[d] : Colors.grey)?.withOpacity(0.2),
          child: Text(d != null ? 'Direction: ${kDirLabels[d]}' : 'Transition: $t', style: TextStyle(fontSize: 12, color: d != null ? kDirColors[d] : Colors.grey)));
      }),
      Expanded(child: Center(child: ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, f, __) {
        final p = _imageCache[f] ?? FileImage(File(char.framePath(f)));
        return Image(image: p, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true);
      }))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: const Color(0xFF16213e), child: Row(children: [
        IconButton(iconSize: 18, icon: Icon(_playing ? Icons.pause : Icons.play_arrow), onPressed: () { setState(() => _playing = !_playing); if (_playing) _startTimer(); }),
        IconButton(iconSize: 18, icon: const Icon(Icons.skip_previous), onPressed: () {
          _playing = false;
          if (_previewFrames != null && _previewFrames!.isNotEmpty) { _previewIndex = (_previewIndex - 1 + _previewFrames!.length) % _previewFrames!.length; _currentFrame = _previewFrames![_previewIndex]; }
          else _currentFrame = (_currentFrame - 1 + char.frameCount) % char.frameCount;
          _displayFrame.value = _currentFrame; setState(() {});
        }),
        IconButton(iconSize: 18, icon: const Icon(Icons.skip_next), onPressed: () {
          _playing = false;
          if (_previewFrames != null && _previewFrames!.isNotEmpty) { _previewIndex = (_previewIndex + 1) % _previewFrames!.length; _currentFrame = _previewFrames![_previewIndex]; }
          else _currentFrame = (_currentFrame + 1) % char.frameCount;
          _displayFrame.value = _currentFrame; setState(() {});
        }),
        Expanded(child: ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, f, __) => SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
          child: Slider(value: f.toDouble(), min: 0, max: (char.frameCount - 1).toDouble().clamp(1, double.infinity), divisions: char.frameCount > 1 ? char.frameCount - 1 : null,
            onChanged: (v) { _currentFrame = v.round(); _displayFrame.value = _currentFrame; _playing = false; setState(() {}); })))),
        ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, f, __) => Text('${f + 1}/${char.frameCount}', style: const TextStyle(fontSize: 10, color: Colors.white70))),
      ])),
    ]);
  }

  // --- Directions ---
  Widget _buildDirectionsContent() {
    return _buildCompassEditor();
  }

  // --- Compass Node Editor ---

  Map<String, Offset> _getDefaultDirPositions(double w, double h) {
    final cx = w / 2; final cy = h / 2;
    final r = (w < h ? w : h) / 2 - 30;
    const d = 0.7071;
    return {'n': Offset(cx, cy - r), 'ne': Offset(cx + r * d, cy - r * d), 'e': Offset(cx + r, cy), 'se': Offset(cx + r * d, cy + r * d), 's': Offset(cx, cy + r), 'sw': Offset(cx - r * d, cy + r * d), 'w': Offset(cx - r, cy), 'nw': Offset(cx - r * d, cy - r * d)};
  }

  Widget _buildCompassEditor() {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth; final h = box.maxHeight;
      // Init default positions if empty
      if (_dirPositions.isEmpty) _dirPositions = _getDefaultDirPositions(w, h);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (det) {
          final local = det.localPosition;
          showMenu<String>(context: context,
            position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1),
            color: const Color(0xFF1a1a3e),
            items: [
              const PopupMenuItem(value: 'add_trans', child: Row(children: [Icon(Icons.add_circle_outline, size: 16, color: Colors.amber), SizedBox(width: 8), Text('Add Transition', style: TextStyle(fontSize: 12))])),
              const PopupMenuItem(value: 'add_anim', child: Row(children: [Icon(Icons.movie_creation, size: 16, color: Colors.green), SizedBox(width: 8), Text('Add Animation', style: TextStyle(fontSize: 12))])),
              const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.restart_alt, size: 16, color: Colors.white54), SizedBox(width: 8), Text('Reset Positions', style: TextStyle(fontSize: 12))])),
            ],
          ).then((a) async {
            if (a == 'add_trans') {
              final id = 't${DateTime.now().millisecondsSinceEpoch}';
              setState(() {
                _visualTransitions.add(VisualTransition(id: id, position: local));
                _connectingTransId = id;
                _connectStep = 1;
              });
              _saveDirectionData();
            } else if (a == 'add_anim') {
              String animName = '';
              final result = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                title: const Text('New Animation'),
                content: TextField(decoration: const InputDecoration(labelText: 'Name (e.g. cross punch, idle, walk)'), onChanged: (v) => animName = v, autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
                ],
              ));
              if (result == true && animName.isNotEmpty) {
                final id = 'a${DateTime.now().millisecondsSinceEpoch}';
                setState(() {
                  _animationNodes.add(AnimationNode(id: id, name: animName, position: local));
                  _connectingAnimId = id;
                  _connectStep = 1;
                });
                _saveDirectionData();
              }
            } else if (a == 'reset') {
              setState(() => _dirPositions = _getDefaultDirPositions(w, h));
              _saveDirectionData();
            }
          });
        },
        child: Stack(children: [
          // Arrow painter behind everything
          Positioned.fill(child: CustomPaint(painter: _ArrowPainter(
            dirPositions: _dirPositions,
            transitions: _visualTransitions,
            animations: _animationNodes,
            connectingId: _connectingTransId,
            btnSize: 52,
          ))),
          // Status bar
          if (_connectStep > 0)
            Positioned(left: 8, top: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(
                _connectingAnimId != null ? 'Click direction to connect animation' :
                _connectStep == 1 ? 'Click FROM direction' : 'Click TO direction',
                style: const TextStyle(fontSize: 11, color: Colors.amber)),
            )),
          // Direction nodes
          ...kDirLabels.keys.map((dir) {
            final pos = _dirPositions[dir] ?? Offset(w / 2, h / 2);
            return Positioned(
              left: pos.dx - 26, top: pos.dy - 26,
              child: _buildDirNode(dir),
            );
          }),
          // Transition nodes
          ..._visualTransitions.map((vt) => Positioned(
            left: vt.position.dx - 20, top: vt.position.dy - 20,
            child: _buildTransNode(vt),
          )),
          // Animation nodes
          ..._animationNodes.map((an) => Positioned(
            left: an.position.dx - 30, top: an.position.dy - 18,
            child: _buildAnimNode(an),
          )),
        ]),
      );
    });
  }

  Widget _buildDirNode(String dir) {
    final cnt = _dirData.directions[dir]?.length ?? 0;
    final col = kDirColors[dir]!;
    final isConnecting = _connectStep > 0;
    final isActive = _activeDirection == dir;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) {
        setState(() => _dirPositions[dir] = (_dirPositions[dir] ?? Offset.zero) + d.delta);
      },
      onPanEnd: (_) => _saveDirectionData(),
      onTap: () {
        if (isConnecting && _connectingTransId != null) {
          final vt = _visualTransitions.firstWhere((t) => t.id == _connectingTransId);
          setState(() {
            if (_connectStep == 1) { vt.fromDir = dir; _connectStep = 2; }
            else if (_connectStep == 2) { vt.toDir = dir; _connectStep = 0; _connectingTransId = null; }
          });
          _saveDirectionData();
        } else if (isConnecting && _connectingAnimId != null) {
          final an = _animationNodes.firstWhere((a) => a.id == _connectingAnimId);
          setState(() { an.connectedDir = dir; _connectStep = 0; _connectingAnimId = null; });
          _saveDirectionData();
        } else {
          final frames = _dirData.directions[dir] ?? [];
          setState(() {
            _activeDirection = dir;
            _selectedNodeId = 'dir_$dir';
            _filteredNodeLabel = kDirLabels[dir];
            _filteredFrames = frames.isNotEmpty ? List<int>.from(frames) : null;
            _framesTab = frames.isNotEmpty ? 1 : 0;
          });
        }
      },
      onDoubleTap: () { final fr = _dirData.directions[dir] ?? []; if (fr.isNotEmpty) _playSubset(fr, kDirLabels[dir]!); },
      onSecondaryTapDown: (det) {
        if (cnt == 0) return;
        showMenu<String>(context: context, position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1), color: const Color(0xFF1a1a3e), items: [
          PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.clear, size: 16, color: col), const SizedBox(width: 8), Text('Clear ${kDirLabels[dir]} ($cnt)', style: const TextStyle(fontSize: 12))])),
        ]).then((a) { if (a == 'clear') { setState(() => _dirData.directions[dir]!.clear()); _saveDirectionData(); } });
      },
      child: DragTarget<Set<int>>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (dd) { setState(() { for (final f in dd.data) { if (!_dirData.directions[dir]!.contains(f)) _dirData.directions[dir]!.add(f); } _dirData.directions[dir]!.sort(); _selectedFrames.clear(); }); _saveDirectionData(); },
        builder: (_, cd, __) {
          final dropping = cd.isNotEmpty;
          return Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dropping ? col.withOpacity(0.4) : isActive ? col.withOpacity(0.25) : cnt > 0 ? col.withOpacity(0.1) : Colors.white.withOpacity(0.03),
              border: Border.all(color: dropping || isActive ? col : col.withOpacity(0.4), width: dropping ? 3 : isActive ? 2.5 : 1.5),
              boxShadow: isConnecting ? [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)] : null,
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(kDirLabels[dir]!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col)),
              if (cnt > 0) Text('$cnt', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.5))),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildTransNode(VisualTransition vt) {
    final connected = vt.fromDir != null && vt.toDir != null;
    final frameCount = connected ? (_dirData.transitions[vt.key]?.length ?? 0) : 0;
    final isConnecting = _connectingTransId == vt.id;
    final isSelected = _selectedNodeId == vt.id;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) { setState(() => vt.position = vt.position + d.delta); },
      onPanEnd: (_) => _saveDirectionData(),
      onTap: () {
        if (connected) {
          final frames = _dirData.transitions[vt.key] ?? [];
          final label = '${kDirLabels[vt.fromDir!]} \u2192 ${kDirLabels[vt.toDir!]}';
          setState(() { _selectedNodeId = vt.id; _filteredNodeLabel = label; _filteredFrames = frames.isNotEmpty ? List<int>.from(frames) : null; _framesTab = 1; });
          if (frames.isNotEmpty) _playSubset(frames, label);
        } else {
          setState(() { _connectingTransId = vt.id; _connectStep = vt.fromDir == null ? 1 : 2; });
        }
      },
      onSecondaryTapDown: (det) {
        showMenu<String>(context: context, position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1), color: const Color(0xFF1a1a3e), items: [
          if (connected && frameCount > 0) PopupMenuItem(value: 'play', child: Row(children: [const Icon(Icons.play_arrow, size: 16, color: Colors.green), const SizedBox(width: 8), Text('Play ($frameCount)', style: const TextStyle(fontSize: 12))])),
          if (connected && frameCount > 0) const PopupMenuItem(value: 'clear_frames', child: Row(children: [Icon(Icons.clear_all, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Clear Frames', style: TextStyle(fontSize: 12))])),
          const PopupMenuItem(value: 'reconnect', child: Row(children: [Icon(Icons.link, size: 16, color: Colors.amber), SizedBox(width: 8), Text('Reconnect', style: TextStyle(fontSize: 12))])),
          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red))])),
        ]).then((a) {
          if (a == 'play' && connected) _playSubset(_dirData.transitions[vt.key]!, '${kDirLabels[vt.fromDir!]} \u2192 ${kDirLabels[vt.toDir!]}');
          else if (a == 'clear_frames' && connected) { setState(() => _dirData.transitions[vt.key]?.clear()); _saveDirectionData(); _exportTransitionToSubfolder(vt.fromDir!, vt.toDir!); }
          else if (a == 'reconnect') { setState(() { vt.fromDir = null; vt.toDir = null; _connectingTransId = vt.id; _connectStep = 1; }); _saveDirectionData(); }
          else if (a == 'delete') { setState(() { if (connected) _dirData.transitions.remove(vt.key); _visualTransitions.remove(vt); }); _saveDirectionData(); }
        });
      },
      child: DragTarget<Set<int>>(
        onWillAcceptWithDetails: (_) => connected,
        onAcceptWithDetails: (dd) {
          if (!connected) return;
          setState(() {
            _dirData.transitions.putIfAbsent(vt.key, () => []);
            for (final f in dd.data) { if (!_dirData.transitions[vt.key]!.contains(f)) _dirData.transitions[vt.key]!.add(f); }
            _dirData.transitions[vt.key]!.sort(); _selectedFrames.clear();
          });
          _saveDirectionData();
          _exportTransitionToSubfolder(vt.fromDir!, vt.toDir!);
        },
        builder: (_, cd, __) {
          final dropping = cd.isNotEmpty;
          return Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: dropping ? Colors.amber.withOpacity(0.3) : isSelected ? Colors.amber.withOpacity(0.35) : isConnecting ? Colors.amber.withOpacity(0.2) : connected ? Colors.grey.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              border: Border.all(color: isSelected ? Colors.amber : isConnecting ? Colors.amber : connected ? Colors.grey : Colors.white24, width: isSelected ? 2.5 : isConnecting ? 2 : 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (connected) Text('${kDirLabels[vt.fromDir!]}\u2192${kDirLabels[vt.toDir!]}', style: TextStyle(fontSize: 8, color: isSelected ? Colors.amber : Colors.white54))
              else const Icon(Icons.link_off, size: 14, color: Colors.white24),
              if (frameCount > 0) Text('$frameCount', style: const TextStyle(fontSize: 8, color: Colors.amber)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildAnimNode(AnimationNode an) {
    final connected = an.connectedDir != null;
    final isConnecting = _connectingAnimId == an.id;
    final isSelected = _selectedNodeId == an.id;
    final frameCount = an.frames.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) { setState(() => an.position = an.position + d.delta); },
      onPanEnd: (_) => _saveDirectionData(),
      onTap: () {
        final label = connected ? '${kDirLabels[an.connectedDir!]} ${an.name}' : an.name;
        setState(() { _selectedNodeId = an.id; _filteredNodeLabel = label; _filteredFrames = an.frames.isNotEmpty ? List<int>.from(an.frames) : null; _framesTab = 1; });
        if (an.frames.isNotEmpty) _playSubset(an.frames, label);
        else if (!connected) setState(() { _connectingAnimId = an.id; _connectStep = 1; });
      },
      onSecondaryTapDown: (det) {
        showMenu<String>(context: context,
          position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1),
          color: const Color(0xFF1a1a3e),
          items: [
            if (frameCount > 0) PopupMenuItem(value: 'play', child: Row(children: [const Icon(Icons.play_arrow, size: 16, color: Colors.green), const SizedBox(width: 8), Text('Play ${an.name} ($frameCount)', style: const TextStyle(fontSize: 12))])),
            if (frameCount > 0) PopupMenuItem(value: 'clear_frames', child: Row(children: [const Icon(Icons.clear_all, size: 16, color: Colors.orange), const SizedBox(width: 8), Text('Clear Frames', style: const TextStyle(fontSize: 12))])),
            PopupMenuItem(value: 'reconnect', child: Row(children: [const Icon(Icons.link, size: 16, color: Colors.amber), const SizedBox(width: 8), Text('Connect to Direction', style: const TextStyle(fontSize: 12))])),
            PopupMenuItem(value: 'rename', child: Row(children: [const Icon(Icons.edit, size: 16, color: Colors.white54), const SizedBox(width: 8), Text('Rename', style: const TextStyle(fontSize: 12))])),
            PopupMenuItem(value: 'extract', child: Row(children: [const Icon(Icons.video_file, size: 16, color: Colors.blue), const SizedBox(width: 8), Text('Extract from Video', style: const TextStyle(fontSize: 12))])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red))])),
          ],
        ).then((a) async {
          if (a == 'play') _playSubset(an.frames, an.name);
          else if (a == 'clear_frames') { setState(() => an.frames = []); _saveDirectionData(); }
          else if (a == 'reconnect') { setState(() { an.connectedDir = null; _connectingAnimId = an.id; _connectStep = 1; }); }
          else if (a == 'rename') {
            String nn = an.name;
            final r = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('Rename Animation'),
              content: TextFormField(initialValue: an.name, onChanged: (v) => nn = v, autofocus: true),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Rename'))],
            ));
            if (r == true && nn.isNotEmpty) { setState(() => an.name = nn); _saveDirectionData(); }
          }
          else if (a == 'extract') _showExtractDialogForAnim(an);
          else if (a == 'delete') { setState(() => _animationNodes.remove(an)); _saveDirectionData(); }
        });
      },
      child: DragTarget<Set<int>>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (dd) {
          setState(() { for (final f in dd.data) { if (!an.frames.contains(f)) an.frames.add(f); } an.frames.sort(); _selectedFrames.clear(); });
          _saveDirectionData();
        },
        builder: (_, cd, __) {
          final dropping = cd.isNotEmpty;
          final dirColor = connected ? kDirColors[an.connectedDir] : null;
          return Container(
            width: 60, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: dropping ? Colors.green.withOpacity(0.3) : isSelected ? Colors.green.withOpacity(0.4) : isConnecting ? Colors.green.withOpacity(0.2) : dirColor?.withOpacity(0.1) ?? Colors.green.withOpacity(0.05),
              border: Border.all(color: isSelected ? Colors.white : isConnecting ? Colors.green : dirColor ?? Colors.green.shade700, width: isSelected ? 2.5 : isConnecting || dropping ? 2.5 : 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(an.name, style: TextStyle(fontSize: 8, color: isSelected ? Colors.white : dirColor ?? Colors.green.shade300, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (frameCount > 0) Text('$frameCount', style: TextStyle(fontSize: 7, color: Colors.white.withOpacity(0.4))),
            ]),
          );
        },
      ),
    );
  }

  // --- Frames ---
  Widget _buildFramesContent(CharacterInfo char) {
    return Column(children: [
      // Tab bar
      Container(
        color: const Color(0xFF16213e),
        child: Row(children: [
          _tabBtn('All Frames', 0),
          _tabBtn(_filteredNodeLabel ?? 'Node', 1, badge: _filteredFrames?.length),
          const Spacer(),
          Text('Sel: ${_selectedFrames.length} ', style: const TextStyle(fontSize: 9, color: Colors.white38)),
          if (_selectedFrames.isNotEmpty) _miniBtn('Clear', () => setState(() => _selectedFrames.clear())),
          const SizedBox(width: 4),
          _miniBtn('All', () => setState(() => _selectedFrames = Set<int>.from(List.generate(char.frameCount, (i) => i)))),
          const SizedBox(width: 4),
        ]),
      ),
      const Divider(height: 1, color: Colors.white12),
      Expanded(child: _framesTab == 0 ? _buildAllFramesGrid(char) : _buildFilteredFramesGrid(char)),
    ]);
  }

  Widget _tabBtn(String label, int index, {int? badge}) {
    final sel = _framesTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _framesTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sel ? Colors.amber : Colors.transparent, width: 2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 10, color: sel ? Colors.amber : Colors.white38, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          if (badge != null && badge > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('$badge', style: const TextStyle(fontSize: 8, color: Colors.amber)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildAllFramesGrid(CharacterInfo char) {
    return ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, curFrame, __) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}),
          child: GridView.builder(padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.75, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: char.frameCount, itemBuilder: (_, i) {
              final sel = _selectedFrames.contains(i); final cur = i == curFrame; final dc = _dirData.getFrameColor(i); final dir = _dirData.getFrameDirection(i); final trans = _dirData.getFrameTransition(i);
              final fw = Container(
                decoration: BoxDecoration(border: Border.all(color: cur ? Colors.white : sel ? Colors.amber : dc?.withOpacity(0.6) ?? Colors.white12, width: cur ? 3 : sel ? 2 : 1), borderRadius: BorderRadius.circular(4), color: dc?.withOpacity(0.12)),
                child: Column(children: [
                  Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(3)), child: Image(image: _imageCache[i] ?? FileImage(File(char.framePath(i))), fit: BoxFit.contain, filterQuality: FilterQuality.low, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 14, color: Colors.white24)))),
                  Container(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$i', style: TextStyle(fontSize: 9, color: dc ?? Colors.white38)),
                    if (dir != null) Text(' ${kDirLabels[dir]}', style: TextStyle(fontSize: 8, color: dc, fontWeight: FontWeight.bold)),
                    if (trans != null) Text(' \u2194', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                  ])),
                ]),
              );
              final dragData = _selectedFrames.contains(i) && _selectedFrames.length > 1 ? Set<int>.from(_selectedFrames) : {i};
              return Draggable<Set<int>>(data: dragData,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(color: Colors.transparent, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFF2a2a4e), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber)), child: Center(child: Text('${dragData.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber, decoration: TextDecoration.none))))),
                childWhenDragging: Opacity(opacity: 0.3, child: fw),
                child: GestureDetector(behavior: HitTestBehavior.opaque,
                  onTap: () => _onFrameTap(i, shift: HardwareKeyboard.instance.isShiftPressed, ctrl: HardwareKeyboard.instance.isControlPressed),
                  onSecondaryTapDown: (det) {
                    // Use selected frames if this frame is part of selection, otherwise just this frame
                    final targets = _selectedFrames.contains(i) && _selectedFrames.length > 1 ? Set<int>.from(_selectedFrames) : {i};
                    final count = targets.length;
                    final items = <PopupMenuEntry<String>>[];
                    if (dir != null) items.add(PopupMenuItem(value: 'clear_dir', child: Row(children: [const Icon(Icons.clear, size: 16, color: Colors.orange), const SizedBox(width: 8), Text('Remove $count from ${kDirLabels[dir]}', style: const TextStyle(fontSize: 12))])));
                    if (trans != null) items.add(PopupMenuItem(value: 'clear_trans', child: Row(children: [const Icon(Icons.clear, size: 16, color: Colors.orange), const SizedBox(width: 8), Text('Remove $count from transition', style: const TextStyle(fontSize: 12))])));
                    items.add(PopupMenuItem(value: 'delete_all', child: Row(children: [const Icon(Icons.delete, size: 16, color: Colors.red), const SizedBox(width: 8), Text('Remove $count from all nodes', style: const TextStyle(fontSize: 12, color: Colors.red))])));
                    // Check if originals exist
                    final ch = _currentChar;
                    if (ch != null) {
                      final origDir = '${ch.dirPath}/originals';
                      if (Directory(origDir).existsSync()) {
                        items.add(PopupMenuItem(value: 'restore', child: Row(children: [const Icon(Icons.restore, size: 16, color: Colors.blue), const SizedBox(width: 8), Text('Restore $count from original', style: const TextStyle(fontSize: 12))])));
                      }
                    }
                    items.add(PopupMenuItem(value: 'delete_files', child: Row(children: [const Icon(Icons.delete_forever, size: 16, color: Colors.red), const SizedBox(width: 8), Text('Delete $count frame files permanently', style: const TextStyle(fontSize: 12, color: Colors.red))])));
                    items.add(PopupMenuItem(value: 'copy_path', child: Row(children: [const Icon(Icons.copy, size: 16, color: Colors.cyan), const SizedBox(width: 8), Text('Copy Full Path${count > 1 ? ' ($count)' : ''}', style: const TextStyle(fontSize: 12))])));
                    showMenu<String>(context: context, position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1), color: const Color(0xFF1a1a3e), items: items).then((a) async {
                      if (a == 'clear_dir') { setState(() { for (final f in targets) _dirData.removeFrameFromAll(f); }); _saveDirectionData(); }
                      else if (a == 'clear_trans') { setState(() { for (final f in targets) _dirData.removeFrameFromAll(f); }); _saveDirectionData(); }
                      else if (a == 'delete_all') { setState(() { for (final f in targets) { _dirData.removeFrameFromAll(f); for (final an in _animationNodes) an.frames.remove(f); } }); _saveDirectionData(); }
                      else if (a == 'restore') {
                        final ch = _currentChar; if (ch == null) return;
                        int restored = 0;
                        for (final f in targets) {
                          final origFile = File('${ch.dirPath}/originals/frame_${f.toString().padLeft(3, '0')}.png');
                          final destFile = File(ch.framePath(f));
                          if (await origFile.exists()) { await origFile.copy(destFile.path); restored++; }
                        }
                        // Clear image cache for restored frames
                        for (final f in targets) _imageCache[f] = FileImage(File(ch.framePath(f)));
                        setState(() {});
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $restored frames from originals')));
                      }
                      else if (a == 'delete_files') {
                        final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                          title: const Text('Delete Frame Files?'),
                          content: Text('Permanently delete $count frame PNG files from disk? This cannot be undone.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
                        ));
                        if (confirm == true) {
                          final ch = _currentChar; if (ch == null) return;
                          for (final f in targets) {
                            _dirData.removeFrameFromAll(f);
                            for (final an in _animationNodes) an.frames.remove(f);
                            try { await File(ch.framePath(f)).delete(); } catch (_) {}
                          }
                          _saveDirectionData();
                          // Reload character to update frame count
                          await _loadFromFolder(ch.dirPath);
                        }
                      }
                      else if (a == 'copy_path') {
                        final ch = _currentChar; if (ch == null) return;
                        final paths = targets.toList()..sort();
                        final text = paths.map((f) => ch.framePath(f)).join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${paths.length} path${paths.length > 1 ? 's' : ''}'), duration: const Duration(seconds: 1)));
                      }
                    });
                  },
                  child: fw),
              );
            }),
        );
      });
  }

  Widget _buildFilteredFramesGrid(CharacterInfo char) {
    if (_filteredFrames == null || _filteredFrames!.isEmpty) {
      return Center(child: Text(_filteredNodeLabel != null ? 'No frames in $_filteredNodeLabel' : 'Click a node to see its frames',
        style: const TextStyle(fontSize: 12, color: Colors.white24)));
    }
    final frames = _filteredFrames!;
    return ValueListenableBuilder<int>(valueListenable: _displayFrame, builder: (_, curFrame, __) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}),
        child: GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.75, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: frames.length,
          itemBuilder: (_, idx) {
            final i = frames[idx];
            final sel = _selectedFrames.contains(i);
            final cur = i == curFrame;
            final dc = _dirData.getFrameColor(i);
            final fw = Container(
              decoration: BoxDecoration(
                border: Border.all(color: cur ? Colors.white : sel ? Colors.amber : dc?.withOpacity(0.6) ?? Colors.white12, width: cur ? 3 : sel ? 2 : 1),
                borderRadius: BorderRadius.circular(4), color: dc?.withOpacity(0.12)),
              child: Column(children: [
                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  child: Image(image: _imageCache[i] ?? FileImage(File(char.framePath(i))), fit: BoxFit.contain, filterQuality: FilterQuality.low, gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 14, color: Colors.white24)))),
                Container(padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('$i', style: TextStyle(fontSize: 9, color: dc ?? Colors.white38))),
              ]),
            );
            final dragData = _selectedFrames.contains(i) && _selectedFrames.length > 1 ? Set<int>.from(_selectedFrames) : {i};
            return Draggable<Set<int>>(data: dragData,
              feedback: Material(color: Colors.transparent, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFF2a2a4e), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber)), child: Center(child: Text('${dragData.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber, decoration: TextDecoration.none))))),
              childWhenDragging: Opacity(opacity: 0.3, child: fw),
              child: GestureDetector(behavior: HitTestBehavior.opaque,
                onTap: () => _onFrameTap(i, shift: HardwareKeyboard.instance.isShiftPressed, ctrl: HardwareKeyboard.instance.isControlPressed),
                onSecondaryTapDown: (det) {
                  final targets = _selectedFrames.contains(i) && _selectedFrames.length > 1 ? Set<int>.from(_selectedFrames) : {i};
                  final count = targets.length;
                  showMenu<String>(context: context, position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1), color: const Color(0xFF1a1a3e), items: [
                    PopupMenuItem(value: 'copy_path', child: Row(children: [const Icon(Icons.copy, size: 16, color: Colors.cyan), const SizedBox(width: 8), Text('Copy Full Path${count > 1 ? ' ($count)' : ''}', style: const TextStyle(fontSize: 12))])),
                  ]).then((a) {
                    if (a == 'copy_path') {
                      final ch = _currentChar; if (ch == null) return;
                      final paths = targets.toList()..sort();
                      final text = paths.map((f) => ch.framePath(f)).join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${paths.length} path${paths.length > 1 ? 's' : ''}'), duration: const Duration(seconds: 1)));
                    }
                  });
                },
                child: fw),
            );
          },
        ),
      );
    });
  }

  // --- Frame Editor ---
  Widget _buildEditorContent(CharacterInfo char) {
    return ValueListenableBuilder<int>(
      valueListenable: _displayFrame,
      builder: (ctx, frame, _) {
        final filePath = char.framePath(frame);
        final origPath = '${char.dirPath}/originals/frame_${frame.toString().padLeft(3, '0')}.png';
        final hasOriginal = File(origPath).existsSync();

        return Column(children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: const Color(0xFF16213e),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('F$frame', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ChoiceChip(
                  label: const Text('Erase', style: TextStyle(fontSize: 9)),
                  selected: _eraseMode,
                  onSelected: (_) => setState(() => _eraseMode = true),
                  selectedColor: Colors.red.shade800,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                GestureDetector(
                  onTap: () {
                    if (hasOriginal) { setState(() => _eraseMode = false); }
                    else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No originals. Re-extract video first.'))); }
                  },
                  child: ChoiceChip(
                    label: const Text('Restore', style: TextStyle(fontSize: 9)),
                    selected: !_eraseMode,
                    onSelected: hasOriginal ? (_) => setState(() => _eraseMode = false) : null,
                    selectedColor: Colors.blue.shade800,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.brush, size: 12, color: Colors.white38),
                  SizedBox(width: 80, child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                    child: Slider(value: _brushSize, min: 5, max: 80, onChanged: (v) => setState(() => _brushSize = v)),
                  )),
                  Text('${_brushSize.round()}', style: const TextStyle(fontSize: 9, color: Colors.white54)),
                ]),
                if (hasOriginal) _miniBtn('Full Restore', () async {
                  final orig = File(origPath);
                  if (await orig.exists()) {
                    await orig.copy(filePath);
                    imageCache.clear(); imageCache.clearLiveImages();
                    _imageCache[frame] = FileImage(File(filePath));
                    setState(() {});
                  }
                }),
              ],
            ),
          ),
          // Canvas
          Expanded(
            child: LayoutBuilder(builder: (ctx, box) {
              return _FrameEditorCanvas(
                key: ValueKey('editor_$frame'),
                framePath: filePath,
                originalPath: hasOriginal ? origPath : null,
                brushSize: _brushSize,
                eraseMode: _eraseMode,
                onSaved: () {
                  final c = _currentChar; if (c == null) return;
                  // Evict only the edited frame's cache
                  final oldProvider = _imageCache[frame];
                  if (oldProvider is FileImage) oldProvider.evict();
                  // Create fresh provider with unique scale to bypass cache
                  _imageCache[frame] = FileImage(File(c.framePath(frame)), scale: 1.0 + DateTime.now().millisecondsSinceEpoch % 1000 / 100000);
                  // Force all ValueNotifier listeners to rebuild
                  final cur = _displayFrame.value;
                  _displayFrame.value = -1;
                  Future.microtask(() {
                    _displayFrame.value = cur;
                    setState(() {});
                  });
                },
              );
            }),
          ),
        ]);
      },
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(4), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60))));
  }
}

// ══════════════════════════════════════════
// Dock Panel Wrapper (drag + drop zones)
// ══════════════════════════════════════════

class DockPanelWrapper extends StatefulWidget {
  final String id, title;
  final Widget child;
  final void Function(String draggedId, DropZone zone) onDrop;
  final VoidCallback? onClose;
  const DockPanelWrapper({super.key, required this.id, required this.title, required this.child, required this.onDrop, this.onClose});
  @override State<DockPanelWrapper> createState() => _DockPanelWrapperState();
}

class _DockPanelWrapperState extends State<DockPanelWrapper> {
  DropZone? _hover;

  DropZone _getZone(Offset local, Size size) {
    final rx = local.dx / size.width, ry = local.dy / size.height;
    if (rx < 0.25 && ry > 0.15 && ry < 0.85) return DropZone.left;
    if (rx > 0.75 && ry > 0.15 && ry < 0.85) return DropZone.right;
    if (ry < 0.3) return DropZone.top;
    return DropZone.bottom;
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != widget.id,
      onAcceptWithDetails: (d) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(d.offset);
        widget.onDrop(d.data, _getZone(local, box.size));
        setState(() => _hover = null);
      },
      onMove: (d) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(d.offset);
        final z = _getZone(local, box.size);
        if (z != _hover) setState(() => _hover = z);
      },
      onLeave: (_) => setState(() => _hover = null),
      builder: (_, cd, __) => Container(
        decoration: BoxDecoration(color: const Color(0xFF0d0d20), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(children: [
          // Title bar — draggable
          Draggable<String>(
            data: widget.id,
            feedback: Material(color: Colors.transparent, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF2a2a4e), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber)),
              child: Text(widget.title, style: const TextStyle(fontSize: 12, color: Colors.amber, decoration: TextDecoration.none)),
            )),
            childWhenDragging: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: const Color(0xFF16213e).withOpacity(0.3),
              child: Row(children: [const Icon(Icons.drag_indicator, size: 14, color: Colors.white24), const SizedBox(width: 4), Text(widget.title, style: const TextStyle(fontSize: 11, color: Colors.white24))]),
            ),
            child: GestureDetector(
              onSecondaryTapDown: (det) {
                showMenu<String>(context: context,
                  position: RelativeRect.fromLTRB(det.globalPosition.dx, det.globalPosition.dy, det.globalPosition.dx + 1, det.globalPosition.dy + 1),
                  color: const Color(0xFF1a1a3e),
                  items: [
                    if (widget.onClose != null) const PopupMenuItem(value: 'close', child: Row(children: [Icon(Icons.close, size: 16, color: Colors.red), SizedBox(width: 8), Text('Close Panel', style: TextStyle(fontSize: 12))])),
                  ],
                ).then((a) { if (a == 'close') widget.onClose?.call(); });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: const Color(0xFF16213e),
                child: Row(children: [const Icon(Icons.drag_indicator, size: 14, color: Colors.white38), const SizedBox(width: 4), Text(widget.title, style: const TextStyle(fontSize: 11, color: Colors.white70))]),
              ),
            ),
          ),
          // Content + drop overlays
          Expanded(child: LayoutBuilder(builder: (_, box) {
            return Stack(children: [
              Positioned.fill(child: widget.child),
              if (_hover == DropZone.left) Positioned(left: 0, top: 0, bottom: 0, child: Container(width: box.maxWidth * 0.3, color: Colors.amber.withOpacity(0.15))),
              if (_hover == DropZone.right) Positioned(right: 0, top: 0, bottom: 0, child: Container(width: box.maxWidth * 0.3, color: Colors.amber.withOpacity(0.15))),
              if (_hover == DropZone.top) Positioned(left: 0, top: 0, right: 0, child: Container(height: box.maxHeight * 0.3, color: Colors.amber.withOpacity(0.15))),
              if (_hover == DropZone.bottom) Positioned(left: 0, bottom: 0, right: 0, child: Container(height: box.maxHeight * 0.3, color: Colors.amber.withOpacity(0.15))),
            ]);
          })),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// Frame Editor Canvas
// ══════════════════════════════════════════

class _FrameEditorCanvas extends StatefulWidget {
  final String framePath;
  final String? originalPath;
  final double brushSize;
  final bool eraseMode;
  final VoidCallback onSaved;

  const _FrameEditorCanvas({super.key, required this.framePath, this.originalPath, required this.brushSize, required this.eraseMode, required this.onSaved});

  @override State<_FrameEditorCanvas> createState() => _FrameEditorCanvasState();
}

class _FrameEditorCanvasState extends State<_FrameEditorCanvas> {
  List<_BrushStroke> _strokes = [];
  _BrushStroke? _currentStroke;
  bool _dirty = false;
  Size _imageSize = const Size(1280, 720);

  // Zoom & pan
  double _zoom = 1.0;
  Offset _panOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant _FrameEditorCanvas old) {
    super.didUpdateWidget(old);
    if (old.framePath != widget.framePath) {
      _strokes.clear();
      _currentStroke = null;
      _dirty = false;
      _zoom = 1.0;
      _panOffset = Offset.zero;
      _loadImageSize();
    }
  }

  bool _sizeLoaded = false;

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.framePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        _sizeLoaded = true;
      });
    } catch (_) {}
  }

  Offset _screenToImage(Offset screenPos, Size canvasSize) {
    final baseScale = _getBaseScale(canvasSize, _imageSize);
    final totalScale = baseScale * _zoom;
    final fitW = _imageSize.width * totalScale;
    final fitH = _imageSize.height * totalScale;
    final cx = (canvasSize.width - fitW) / 2 + _panOffset.dx;
    final cy = (canvasSize.height - fitH) / 2 + _panOffset.dy;
    return (screenPos - Offset(cx, cy)) / totalScale;
  }

  void _onPanStart(Offset localPos, Size canvasSize, Size imageSize) {
    final imgPos = _screenToImage(localPos, canvasSize);
    final baseScale = _getBaseScale(canvasSize, imageSize);
    _currentStroke = _BrushStroke(points: [imgPos], size: widget.brushSize / (baseScale * _zoom), erase: widget.eraseMode);
    setState(() {});
  }

  void _onPanUpdate(Offset localPos, Size canvasSize, Size imageSize) {
    if (_currentStroke == null) return;
    _currentStroke!.points.add(_screenToImage(localPos, canvasSize));
    setState(() {});
  }

  void _onPanEnd() {
    if (_currentStroke != null) {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
      _dirty = true;
      setState(() {});
    }
  }

  double _getBaseScale(Size canvas, Size image) {
    final sx = canvas.width / image.width;
    final sy = canvas.height / image.height;
    return sx < sy ? sx : sy;
  }

  Offset _getBaseOffset(Size canvas, Size image, double scale) {
    return Offset((canvas.width - image.width * scale) / 2, (canvas.height - image.height * scale) / 2);
  }

  void _handleScroll(PointerScrollEvent event, Size canvasSize) {
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final newZoom = (_zoom * factor).clamp(0.3, 15.0);
    // Zoom toward mouse cursor: adjust panOffset so mouse stays on same image point
    final mousePos = event.localPosition;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final mouseFromCenter = mousePos - center - _panOffset;
    final zoomRatio = newZoom / _zoom;
    setState(() {
      _panOffset = _panOffset - mouseFromCenter * (zoomRatio - 1);
      _zoom = newZoom;
    });
  }

  Future<void> _saveEdits() async {
    if (!_dirty || _strokes.isEmpty) return;
    // Load image with dart:io, apply strokes, save
    final file = File(widget.framePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final uiImage = frameInfo.image;
    final w = uiImage.width;
    final h = uiImage.height;

    // Get pixel data
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;
    final pixels = byteData.buffer.asUint8List();

    // Load original for restore mode
    Uint8List? origPixels;
    if (widget.originalPath != null) {
      final origFile = File(widget.originalPath!);
      if (await origFile.exists()) {
        final origBytes = await origFile.readAsBytes();
        final origCodec = await ui.instantiateImageCodec(origBytes);
        final origFrame = await origCodec.getNextFrame();
        final origData = await origFrame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        origPixels = origData?.buffer.asUint8List();
      }
    }

    // Apply strokes
    for (final stroke in _strokes) {
      for (final pt in stroke.points) {
        final int cx = pt.dx.round();
        final int cy = pt.dy.round();
        final int r = (stroke.size / 2).round();
        for (int dy = -r; dy <= r; dy++) {
          for (int dx = -r; dx <= r; dx++) {
            if (dx * dx + dy * dy > r * r) continue;
            final int px = cx + dx;
            final int py = cy + dy;
            if (px < 0 || px >= w || py < 0 || py >= h) continue;
            final idx = (py * w + px) * 4;
            if (stroke.erase) {
              pixels[idx + 3] = 0; // Set alpha to 0
            } else if (origPixels != null && idx < origPixels.length) {
              pixels[idx] = origPixels[idx];
              pixels[idx + 1] = origPixels[idx + 1];
              pixels[idx + 2] = origPixels[idx + 2];
              pixels[idx + 3] = origPixels[idx + 3];
            }
          }
        }
      }
    }

    // Encode back to PNG and save
    final result = await _encodePng(w, h, pixels);
    await file.writeAsBytes(result);
    // Evict old image from cache
    FileImage(file).evict();
    _strokes.clear();
    _dirty = false;
    _imageVersion++;
    setState(() {});
    widget.onSaved();
  }

  int _imageVersion = 0;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Offset _screenToImageViaCtrl(Offset screenPos) {
    final inv = Matrix4.inverted(_transformCtrl.value);
    final v = inv.transform3(Vector3(screenPos.dx, screenPos.dy, 0));
    return Offset(v.x, v.y);
  }

  @override
  Widget build(BuildContext context) {
    if (!_sizeLoaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final imageWidget = SizedBox(
      width: _imageSize.width,
      height: _imageSize.height,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _CheckerPainter())),
        if (widget.originalPath != null)
          Positioned.fill(child: Opacity(opacity: 0.25, child: Image.file(
            File(widget.originalPath!),
            filterQuality: FilterQuality.low,
            alignment: Alignment.center,
          ))),
        Positioned.fill(child: Image.file(
          File(widget.framePath),
          key: ValueKey('${widget.framePath}_$_imageVersion'),
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          alignment: Alignment.center,
        )),
      ]),
    );

    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0xFF0a0a0a))),
      Positioned.fill(
        child: Listener(
          onPointerDown: (e) {
            if (e.buttons == 1) {
              // Left click — start brush stroke
              final imgPos = _screenToImageViaCtrl(e.localPosition);
              final currentScale = _transformCtrl.value.getMaxScaleOnAxis();
              setState(() {
                _currentStroke = _BrushStroke(
                  points: [imgPos],
                  size: widget.brushSize / currentScale,
                  erase: widget.eraseMode,
                );
              });
            }
          },
          onPointerMove: (e) {
            if (_currentStroke != null && e.buttons == 1) {
              final imgPos = _screenToImageViaCtrl(e.localPosition);
              setState(() => _currentStroke!.points.add(imgPos));
            }
          },
          onPointerUp: (e) {
            if (_currentStroke != null) {
              _strokes.add(_currentStroke!);
              _currentStroke = null;
              _dirty = true;
              setState(() {});
            }
          },
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            minScale: 0.3,
            maxScale: 15.0,
            boundaryMargin: const EdgeInsets.all(500),
            panEnabled: false, // we handle left-click for brush
            scaleEnabled: true,
            child: imageWidget,
          ),
        ),
      ),
      // Brush overlay
      if (_currentStroke != null || _strokes.isNotEmpty)
        Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
          animation: _transformCtrl,
          builder: (_, __) => CustomPaint(painter: _BrushOverlayPainterV2(
            strokes: [..._strokes, if (_currentStroke != null) _currentStroke!],
            transform: _transformCtrl.value,
          )),
        ))),
      // Zoom indicator
      Positioned(left: 8, bottom: 8, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _transformCtrl,
            builder: (_, __) => Text(
              '${(_transformCtrl.value.getMaxScaleOnAxis() * 100).round()}%',
              style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ),
          const SizedBox(width: 8),
          InkWell(onTap: () => _transformCtrl.value = Matrix4.identity(),
            child: const Text('Reset', style: TextStyle(fontSize: 9, color: Colors.amber))),
        ]),
      )),
      if (_dirty)
        Positioned(right: 8, bottom: 8, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Save', style: TextStyle(fontSize: 12)),
          onPressed: _saveEdits,
        )),
      if (_strokes.isNotEmpty)
        Positioned(right: 8, bottom: _dirty ? 48 : 8, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Undo', style: TextStyle(fontSize: 12)),
          onPressed: () => setState(() { _strokes.removeLast(); _dirty = _strokes.isNotEmpty; }),
        )),
    ]);
  }
}

Future<Uint8List> _encodePng(int width, int height, Uint8List rgba) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
  final img = await completer.future;
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

class _BrushStroke {
  List<Offset> points;
  double size;
  bool erase;
  _BrushStroke({required this.points, required this.size, required this.erase});
}

class _BrushOverlayPainter extends CustomPainter {
  final List<_BrushStroke> strokes;
  final Size canvasSize, imageSize;
  final double zoom;
  final Offset panOffset;
  _BrushOverlayPainter({required this.strokes, required this.canvasSize, required this.imageSize, this.zoom = 1.0, this.panOffset = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = canvasSize.width / imageSize.width;
    final sy = canvasSize.height / imageSize.height;
    final baseScale = sx < sy ? sx : sy;
    final scale = baseScale * zoom;
    final fitW = imageSize.width * scale;
    final fitH = imageSize.height * scale;
    final ox = (canvasSize.width - fitW) / 2 + panOffset.dx;
    final oy = (canvasSize.height - fitH) / 2 + panOffset.dy;

    for (final s in strokes) {
      final paint = Paint()
        ..color = s.erase ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3)
        ..strokeWidth = s.size * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(Offset(s.points[0].dx * scale + ox, s.points[0].dy * scale + oy), s.size * scale / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path();
        path.moveTo(s.points[0].dx * scale + ox, s.points[0].dy * scale + oy);
        for (int i = 1; i < s.points.length; i++) {
          path.lineTo(s.points[i].dx * scale + ox, s.points[i].dy * scale + oy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override bool shouldRepaint(covariant _BrushOverlayPainter old) => true;
}

class _BrushOverlayPainterV2 extends CustomPainter {
  final List<_BrushStroke> strokes;
  final Matrix4 transform;
  _BrushOverlayPainterV2({required this.strokes, required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.erase ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final scale = transform.getMaxScaleOnAxis();
      paint.strokeWidth = s.size * scale;

      if (s.points.length == 1) {
        final p = _transformPoint(s.points[0]);
        canvas.drawCircle(p, s.size * scale / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path();
        path.moveTo(_transformPoint(s.points[0]).dx, _transformPoint(s.points[0]).dy);
        for (int i = 1; i < s.points.length; i++) {
          final p = _transformPoint(s.points[i]);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  Offset _transformPoint(Offset imgPoint) {
    final v = transform.transform3(Vector3(imgPoint.dx, imgPoint.dy, 0));
    return Offset(v.x, v.y);
  }

  @override bool shouldRepaint(covariant _BrushOverlayPainterV2 old) => true;
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const s = 10.0;
    final light = Paint()..color = const Color(0xFF2a2a2a);
    final dark = Paint()..color = const Color(0xFF1a1a1a);
    for (double y = 0; y < size.height; y += s) {
      for (double x = 0; x < size.width; x += s) {
        final isLight = ((x / s).floor() + (y / s).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), isLight ? light : dark);
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════
// Arrow Painter for compass connections
// ══════════════════════════════════════════

class _ArrowPainter extends CustomPainter {
  final Map<String, Offset> dirPositions;
  final List<VisualTransition> transitions;
  final List<AnimationNode> animations;
  final String? connectingId;
  final double btnSize;

  _ArrowPainter({required this.dirPositions, required this.transitions, this.animations = const [], this.connectingId, this.btnSize = 52});

  @override
  void paint(Canvas canvas, Size size) {
    for (final vt in transitions) {
      final isConn = vt.id == connectingId;
      if (vt.fromDir != null && dirPositions.containsKey(vt.fromDir)) {
        _drawArrow(canvas, dirPositions[vt.fromDir!]!, vt.position, isConn ? Colors.amber : Colors.grey.shade600);
      }
      if (vt.toDir != null && dirPositions.containsKey(vt.toDir)) {
        _drawArrow(canvas, vt.position, dirPositions[vt.toDir!]!, isConn ? Colors.amber : Colors.grey.shade600);
      }
    }
    // Animation connections
    for (final an in animations) {
      if (an.connectedDir != null && dirPositions.containsKey(an.connectedDir)) {
        _drawArrow(canvas, dirPositions[an.connectedDir!]!, an.position, Colors.green.shade600);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()..color = color.withOpacity(0.6)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);
    final dir = to - from; final len = dir.distance; if (len < 10) return;
    final n = dir / len; final p = Offset(-n.dy, n.dx);
    final tip = to - n * (btnSize / 2); const s = 8.0;
    final p1 = tip - n * s + p * s * 0.5; final p2 = tip - n * s - p * s * 0.5;
    canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(), Paint()..color = color.withOpacity(0.8)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => true;
}

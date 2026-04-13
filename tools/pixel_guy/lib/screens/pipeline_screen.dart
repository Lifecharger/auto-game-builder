import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pipeline_model.dart';
import '../services/pipeline_api.dart';

class AppColors {
  static const bgDark = Color(0xFF1a1a2e);
  static const bgSidebar = Color(0xFF16213e);
  static const bgCard = Color(0xFF0f3460);
  static const bgCardHover = Color(0xFF1a4080);
  static const accent = Color(0xFFe94560);
  static const accentHover = Color(0xFFff6b81);
  static const textPrimary = Color(0xFFffffff);
  static const textSecondary = Color(0xFFa0a0b0);
  static const textMuted = Color(0xFF606080);
  static const success = Color(0xFF2ecc71);
  static const warning = Color(0xFFf39c12);
  static const error = Color(0xFFe74c3c);
  static const info = Color(0xFF3498db);
  static const border = Color(0xFF2a2a4a);
}

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _pairs = [];  // From /api/pipeline/pairs
  List<PipelineCollectionModel> _collections = [];
  List<PipelineOpStatus> _activeOps = [];
  final Set<String> _selectedStems = {};   // Selected pair stems ("1", "2", etc.)
  bool _loading = false;
  bool _scanning = false;
  bool _appInForeground = true;
  Timer? _pollTimer;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        _loadAll();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final hasActiveOps = _activeOps.any((op) => !op.isDone);
    if (!hasActiveOps) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_appInForeground) return;
      if (_activeOps.any((op) => !op.isDone)) {
        _pollOps();
      } else {
        _loadAll(silent: true);
        _pollTimer?.cancel();
      }
    });
  }

  void _restartPolling() {
    _pollTimer?.cancel();
    _startPolling();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    await Future.wait([
      _loadPairs(silent: true),
      _loadCollections(silent: true),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPairs({bool silent = false}) async {
    final result = await PipelineApi.getPipelinePairs();
    if (mounted && result.ok) {
      setState(() {
        _pairs = (result.data!).map((j) => j as Map<String, dynamic>).toList();
        _selectedStems.retainWhere(
            (s) => _pairs.any((p) => p['stem'] == s));
      });
    }
  }

  Future<void> _loadCollections({bool silent = false}) async {
    final result = await PipelineApi.getPipelineCollections();
    if (mounted && result.ok) {
      setState(() {
        _collections = (result.data!)
            .map((j) => PipelineCollectionModel.fromJson(j as Map<String, dynamic>))
            .toList();
      });
    }
  }


  Future<void> _pollOps() async {
    final updated = <PipelineOpStatus>[];
    for (final op in _activeOps) {
      if (op.isDone) {
        updated.add(op);
        continue;
      }
      final result = await PipelineApi.getPipelineOpStatus(op.opId);
      if (result.ok) {
        updated.add(PipelineOpStatus.fromJson(result.data!));
      } else {
        updated.add(op);
      }
    }
    if (mounted) {
      final hadActive = _activeOps.any((op) => !op.isDone);
      setState(() => _activeOps = updated);
      final hasActive = _activeOps.any((op) => !op.isDone);
      // If all ops just finished, reload data and adjust polling
      if (hadActive && !hasActive) {
        _loadAll(silent: true);
        _restartPolling();
      }
    }
  }

  void _trackOp(String opId, String type) {
    final op = PipelineOpStatus(
      opId: opId,
      type: type,
      phase: 'running',
      message: 'Starting...',
      progress: 0,
      total: 0,
      startedAt: DateTime.now().toIso8601String(),
    );
    setState(() => _activeOps.insert(0, op));
    _restartPolling();
  }

  // -- Actions -----------------------------------------------------

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final scanResult = await PipelineApi.scanPipeline();
    setState(() => _scanning = false);
    if (!mounted) return;
    if (!scanResult.ok) {
      _showSnack(scanResult.error ?? 'Scan failed', isError: true);
      return;
    }
    final newAssets = scanResult.data!['new_assets'] ?? 0;
    _showSnack('Found $newAssets new files');
    _loadAll(silent: true);
  }

  Future<void> _matchSelected() async {
    // Show match strategy dialog
    final strategy = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Match Strategy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_search, color: AppColors.accent),
              title: const Text('Visual (First Frame)',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text('Compare video first frames with images for accurate matching',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.accent),
              ),
              onTap: () => Navigator.pop(ctx, 'visual'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.grey),
              title: const Text('Name Only',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text('Match by filename pattern (faster, less accurate)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade700),
              ),
              onTap: () => Navigator.pop(ctx, 'name'),
            ),
          ],
        ),
      ),
    );

    if (strategy == null || !mounted) return;

    final result = await PipelineApi.startPipelineMatch(
      checkFirstFrame: strategy == 'visual',
    );
    if (mounted) {
      if (result.ok) {
        final opId = result.data!['op_id']?.toString() ?? '';
        if (opId.isNotEmpty) _trackOp(opId, 'match');
        _showSnack(strategy == 'visual'
            ? 'Visual matching started (checking first frames)'
            : 'Name matching started');
      } else {
        _showSnack(result.error ?? 'Match failed', isError: true);
      }
    }
  }

  Future<void> _tagSelected() async {
    final result = await PipelineApi.startPipelineTag();
    if (mounted) {
      if (result.ok) {
        final opId = result.data!['op_id']?.toString() ?? '';
        if (opId.isNotEmpty) _trackOp(opId, 'tag');
        _showSnack('Tagging started');
      } else {
        _showSnack(result.error ?? 'Tag failed', isError: true);
      }
    }
  }

  Future<void> _acceptSelected() async {
    if (_selectedStems.isEmpty) {
      _showSnack('Select pairs first', isError: true);
      return;
    }

    final selectedPairs = _pairs.where((p) => _selectedStems.contains(p['stem'])).toList();

    // Build pairs list with video choices
    final List<Map<String, String>> acceptPairs = [];
    for (final p in selectedPairs) {
      final image = (p['image'] ?? '') as String;
      String video = (p['video'] ?? '') as String;

      if (p['has_extras'] == true) {
        // Show picker for this pair
        final extras = (p['extras'] as List).cast<String>();
        final allVideos = [if (video.isNotEmpty) video, ...extras];
        if (allVideos.length > 1) {
          final chosen = await _showVideoPickerDialog(p['stem'] as String, image, allVideos);
          if (chosen == null) return; // User cancelled
          video = chosen;
        }
      }
      acceptPairs.add({'image': image, 'video': video});
    }

    _showAcceptSheet(acceptPairs);
  }

  Future<String?> _showVideoPickerDialog(String stem, String image, List<String> videos) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Pair $stem — Pick Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    PipelineApi.pipelineFileThumbUrl(image),
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 60),
                  ),
                ),
              ),
            const Text('Select which video to keep:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            ...videos.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(v.contains('extra') ? Icons.movie_filter : Icons.videocam),
                  label: Text(v, style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: v.contains('extra')
                        ? AppColors.warning.withValues(alpha: 0.2)
                        : AppColors.accent.withValues(alpha: 0.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx, v),
                ),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAcceptSheet(List<Map<String, String>> acceptPairs) {
    String? selectedCollection;
    String acceptRating = 'teen';
    final nameController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final mq = MediaQuery.of(ctx);
            final existingCollections = _collections
                .where((c) => c.rating == acceptRating)
                .toList();
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accept ${acceptPairs.length} pair(s)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'kid', label: Text('Kid')),
                      ButtonSegment(value: 'teen', label: Text('Teen')),
                      ButtonSegment(value: 'adult', label: Text('Adult')),
                    ],
                    selected: {acceptRating},
                    onSelectionChanged: (val) {
                      setSheetState(() {
                        acceptRating = val.first;
                        selectedCollection = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Collection', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (existingCollections.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedCollection,
                      decoration: const InputDecoration(
                        hintText: 'Select existing collection',
                        prefixIcon: Icon(Icons.folder),
                      ),
                      dropdownColor: AppColors.bgCard,
                      items: existingCollections.map((c) => DropdownMenuItem(
                        value: c.name,
                        child: Text('${c.name} (${c.assetCount})'),
                      )).toList(),
                      onChanged: (val) => setSheetState(() {
                        selectedCollection = val;
                        nameController.clear();
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text('or create new:',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    const SizedBox(height: 4),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'New collection name...',
                      prefixIcon: Icon(Icons.create_new_folder),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        setSheetState(() => selectedCollection = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton.icon(
                      onPressed: submitting ? null : () async {
                        final collName = nameController.text.trim().isNotEmpty
                            ? nameController.text.trim()
                            : selectedCollection;
                        if (collName == null || collName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pick or name a collection'),
                                backgroundColor: AppColors.warning));
                          return;
                        }
                        setSheetState(() => submitting = true);
                        final result = await PipelineApi.acceptPipelinePairs(
                          pairs: acceptPairs,
                          collection: collName,
                          rating: acceptRating,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          _showSnack(result.ok ? 'Pairs accepted' : result.error ?? 'Failed',
                              isError: !result.ok);
                          if (result.ok) {
                            setState(() => _selectedStems.clear());
                            _loadAll(silent: true);
                          }
                        }
                      },
                      icon: submitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(submitting ? 'Accepting...' : 'Accept'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rejectSelected() async {
    if (_selectedStems.isEmpty) {
      _showSnack('Select pairs first', isError: true);
      return;
    }
    // Get filenames for selected stems
    final filenames = <String>[];
    for (final p in _pairs) {
      if (_selectedStems.contains(p['stem'])) {
        if (p['image'] != null) filenames.add(p['image'] as String);
      }
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Reject & Delete'),
        content: Text('Delete ${_selectedStems.length} pair(s) and all their files? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await PipelineApi.rejectPipelineAssets(filenames);
    if (mounted) {
      final data = result.data;
      final errors = data != null && data['errors'] is List ? data['errors'] as List : [];
      if (result.ok && errors.isEmpty) {
        _showSnack('Pairs deleted');
      } else if (result.ok && errors.isNotEmpty) {
        _showSnack('Deleted with ${errors.length} error(s): ${errors.first}', isError: true);
      } else {
        _showSnack(result.error ?? 'Failed', isError: true);
      }
      if (result.ok) {
        setState(() => _selectedStems.clear());
        _loadAll(silent: true);
      }
    }
  }

  Future<void> _pushCollection(PipelineCollectionModel coll) async {
    final result = await PipelineApi.pushPipelineCollection(
      collection: coll.name,
      rating: coll.rating,
    );
    if (mounted) {
      if (result.ok) {
        final opId = result.data!['op_id']?.toString() ?? '';
        if (opId.isNotEmpty) _trackOp(opId, 'push');
        _showSnack('Push started for ${coll.name}');
      } else {
        _showSnack(result.error ?? 'Push failed', isError: true);
      }
    }
  }

  Future<void> _cancelOp(PipelineOpStatus op) async {
    final result = await PipelineApi.cancelPipelineOp(op.opId);
    if (mounted) {
      _showSnack(result.ok ? 'Cancelled' : result.error ?? 'Failed', isError: !result.ok);
      if (result.ok) _pollOps();
    }
  }

  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();
    String rating = 'teen';
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: const Text('New Collection'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Collection name'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'kid', label: Text('Kid')),
                      ButtonSegment(value: 'teen', label: Text('Teen')),
                      ButtonSegment(value: 'adult', label: Text('Adult')),
                    ],
                    selected: {rating},
                    onSelectionChanged: (val) =>
                        setDialogState(() => rating = val.first),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    setDialogState(() => submitting = true);
                    final result = await PipelineApi.createPipelineCollection(
                      name: name, rating: rating,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      _showSnack(result.ok ? 'Collection created' : result.error ?? 'Failed',
                          isError: !result.ok);
                      if (result.ok) _loadCollections(silent: true);
                    }
                  },
                  child: Text(submitting ? 'Creating...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _showPairDetail(String stem, String? imageFile, String? videoFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) {
            final bottomPad = MediaQuery.of(ctx).padding.bottom;
            return _PairDetailContent(
              stem: stem,
              imageFile: imageFile,
              videoFile: videoFile,
              scrollCtrl: scrollCtrl,
              bottomPad: bottomPad,
              onPlayVideo: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _VideoPlayerPage(
                    videoUrl: PipelineApi.pipelineFileUrl(videoFile!),
                    title: 'Pair $stem',
                  ),
                ));
              },
            );
          },
        );
      },
    );
  }

  // -- Helper widgets ----------------------------------------------

  static Color _ratingColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'kid': return AppColors.success;
      case 'teen': return AppColors.warning;
      case 'adult': return AppColors.error;
      default: return Colors.grey;
    }
  }

  // -- Build -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pipeline'),
          actions: [
            IconButton(
              icon: _scanning
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.radar),
              tooltip: 'Scan for downloads',
              onPressed: _scanning ? null : _scan,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadAll(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Favorites'),
              Tab(text: 'Accepted'),
              Tab(text: 'Pushed'),
            ],
          ),
        ),
        body: (_loading || !_initialLoadDone)
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDownloadsTab(),
                  _buildAcceptedTab(),
                  _buildPushedTab(),
                ],
              ),
      ),
    );
  }

  // -- Tab 1: Downloads --------------------------------------------

  Widget _buildDownloadsTab() {
    final hasExtras = _pairs.any((p) => p['has_extras'] == true);
    final hasSolos = _pairs.any((p) => p['is_solo'] == true);
    final pairedCount = _pairs.where((p) => p['is_solo'] != true).length;
    final soloCount = _pairs.where((p) => p['is_solo'] == true).length;
    final extraCount = _pairs.where((p) => p['has_extras'] == true).length;

    return Column(
      children: [
        // Summary bar
        if (_pairs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                if (pairedCount > 0)
                  _summaryChip('Pairs', pairedCount, AppColors.accent),
                if (pairedCount > 0) const SizedBox(width: 6),
                if (hasExtras)
                  _summaryChip('Extras', extraCount, AppColors.warning),
                if (hasExtras) const SizedBox(width: 6),
                if (hasSolos)
                  _summaryChip('Solos', soloCount, Colors.grey),
              ],
            ),
          ),
        // Grid or empty state
        Expanded(
          child: _pairs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_outlined, size: 64,
                          color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text('Tap scan to find new downloads',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () => _loadPairs(silent: true),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _pairs.length,
                    itemBuilder: (ctx, index) {
                      final pair = _pairs[index];
                      final stem = pair['stem'] as String;
                      final selected = _selectedStems.contains(stem);
                      final isSolo = pair['is_solo'] == true;
                      final hasVideo = pair['video'] != null;
                      final hasExtrasFlag = pair['has_extras'] == true;
                      final imageFile = pair['image'] as String?;

                      final videoFile = pair['video'] as String?;

                      return _PairCard(
                        key: ValueKey(stem),
                        stem: stem,
                        imageFile: imageFile,
                        videoFile: videoFile,
                        selected: selected,
                        isSolo: isSolo,
                        hasVideo: hasVideo,
                        hasExtras: hasExtrasFlag,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedStems.remove(stem);
                            } else {
                              _selectedStems.add(stem);
                            }
                          });
                        },
                        onLongPress: () {
                          // Show full image + play video option
                          _showPairDetail(stem, imageFile, videoFile);
                        },
                      );
                    },
                  ),
                ),
        ),
        // Bottom action bar
        _buildBottomActionBar(),
      ],
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: SafeArea(
        top: false,
        child: _selectedStems.isNotEmpty
            ? Row(
                children: [
                  Text('${_selectedStems.length} selected',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const Spacer(),
                  _actionBtn('Match', Icons.compare_arrows, _matchSelected),
                  const SizedBox(width: 6),
                  _actionBtn('Tag', Icons.label, _tagSelected),
                  const SizedBox(width: 6),
                  _actionBtn('Accept', Icons.check_circle, _acceptSelected,
                      color: AppColors.success),
                  const SizedBox(width: 6),
                  _actionBtn('Reject', Icons.cancel, _rejectSelected,
                      color: AppColors.error),
                ],
              )
            : Row(
                children: [
                  Text('${_pairs.length} pairs',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const Spacer(),
                  if (_pairs.isNotEmpty) ...[
                    _actionBtn('Match All', Icons.compare_arrows, _matchSelected),
                    const SizedBox(width: 6),
                    _actionBtn('Tag All', Icons.label, () async {
                      final result = await PipelineApi.startPipelineTag();
                      if (mounted) {
                        if (result.ok) {
                          final opId = result.data!['op_id']?.toString() ?? '';
                          if (opId.isNotEmpty) _trackOp(opId, 'tag');
                          _showSnack('Tagging all assets');
                        } else {
                          _showSnack(result.error ?? 'Tag failed', isError: true);
                        }
                      }
                    }),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedStems.addAll(
                              _pairs.map((p) => p['stem'] as String));
                        });
                      },
                      icon: const Icon(Icons.select_all, size: 16),
                      label: const Text('Select All',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onPressed,
      {Color? color}) {
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label),
      ),
    );
  }

  // -- Tab 2: Accepted (non-pushed collections) ----------------------

  Widget _buildAcceptedTab() {
    final nonPushed = _collections.where((c) => !c.isPushed).toList();

    // Group by rating
    final grouped = <String, List<PipelineCollectionModel>>{};
    for (final c in nonPushed) {
      grouped.putIfAbsent(c.rating, () => []).add(c);
    }
    final ratingOrder = ['kid', 'teen', 'adult'];

    final hasActiveOps = _activeOps.isNotEmpty;

    if (nonPushed.isEmpty && !hasActiveOps) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text('No accepted collections yet',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Accept pairs from the Favorites tab',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showCreateCollectionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Collection'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => _loadCollections(silent: true),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Active operations section
              if (hasActiveOps) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('ACTIVE OPERATIONS',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.info,
                        letterSpacing: 0.5,
                      )),
                ),
                ..._activeOps.map((op) => _OpCard(op: op, onCancel: () => _cancelOp(op))),
                if (nonPushed.isNotEmpty) const SizedBox(height: 12),
              ],
              // Non-pushed collections
              for (final rating in ratingOrder)
                if (grouped.containsKey(rating)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ratingColor(rating),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(rating.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: _ratingColor(rating),
                          )),
                    ]),
                  ),
                  ...grouped[rating]!.map((coll) => _CollectionCard(
                        collection: coll,
                        onPush: () => _pushCollection(coll),
                      )),
                ],
            ],
          ),
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            onPressed: _showCreateCollectionDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // -- Tab 3: Pushed collections ------------------------------------

  Widget _buildPushedTab() {
    final pushed = _collections.where((c) => c.isPushed).toList();

    if (pushed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text('No pushed collections yet',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Push collections from the Accepted tab',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    // Group by rating
    final grouped = <String, List<PipelineCollectionModel>>{};
    for (final c in pushed) {
      grouped.putIfAbsent(c.rating, () => []).add(c);
    }
    final ratingOrder = ['kid', 'teen', 'adult'];

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _loadCollections(silent: true),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final rating in ratingOrder)
            if (grouped.containsKey(rating)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ratingColor(rating),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(rating.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _ratingColor(rating),
                      )),
                ]),
              ),
              ...grouped[rating]!.map((coll) => _CollectionCard(
                    collection: coll,
                    onPush: null, // Already pushed
                  )),
            ],
        ],
      ),
    );
  }
}

// -- Pair Card Widget -----------------------------------------------

// -- Pair Detail Content (fetches metadata) --------------------------------

class _PairDetailContent extends StatefulWidget {
  final String stem;
  final String? imageFile;
  final String? videoFile;
  final ScrollController scrollCtrl;
  final double bottomPad;
  final VoidCallback? onPlayVideo;

  const _PairDetailContent({
    required this.stem,
    required this.imageFile,
    required this.videoFile,
    required this.scrollCtrl,
    required this.bottomPad,
    this.onPlayVideo,
  });

  @override
  State<_PairDetailContent> createState() => _PairDetailContentState();
}

class _PairDetailContentState extends State<_PairDetailContent> {
  Map<String, dynamic>? _imageMetadata;
  Map<String, dynamic>? _videoMetadata;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      if (widget.imageFile != null) {
        final r = await PipelineApi.getPipelineFileMetadata(widget.imageFile!);
        if (r.ok && mounted) setState(() => _imageMetadata = r.data);
      }
      if (widget.videoFile != null) {
        final r = await PipelineApi.getPipelineFileMetadata(widget.videoFile!);
        if (r.ok && mounted) setState(() => _videoMetadata = r.data);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Widget _metaSection(String title, Map<String, dynamic> meta) {
    // Key fields to show prominently
    final description = meta['description']?.toString() ?? '';
    final tags = meta['tags']?.toString() ?? '';
    final adult = meta['adult']?.toString() ?? '';
    final racy = meta['racy']?.toString() ?? '';
    final violence = meta['violence']?.toString() ?? '';
    final rating = meta['rating']?.toString() ?? '';
    final safety = meta['safety']?.toString() ?? meta['safety_level']?.toString() ?? '';
    final voyeur = meta['voyeur']?.toString() ?? meta['voyeur_risk']?.toString() ?? '';
    final pose = meta['pose']?.toString() ?? meta['pose_type']?.toString() ?? '';
    final framing = meta['framing']?.toString() ?? '';
    final skin = meta['skin']?.toString() ?? meta['skin_exposure']?.toString() ?? '';
    final context_flag = meta['context']?.toString() ?? meta['context_flag']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (description.isNotEmpty) ...[
          Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
          const SizedBox(height: 10),
        ],
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 4, runSpacing: 4,
            children: tags.split(',').take(15).map((t) => Chip(
              label: Text(t.trim(), style: const TextStyle(fontSize: 10)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
            )).toList(),
          ),
          const SizedBox(height: 10),
        ],
        // Scores row
        if (adult.isNotEmpty || racy.isNotEmpty || violence.isNotEmpty)
          Row(
            children: [
              if (adult.isNotEmpty) _scoreBadge('Adult', adult),
              if (racy.isNotEmpty) _scoreBadge('Racy', racy),
              if (violence.isNotEmpty) _scoreBadge('Violence', violence),
              if (rating.isNotEmpty) _scoreBadge('Rating', rating, isText: true),
            ],
          ),
        const SizedBox(height: 8),
        // Detail fields
        if (safety.isNotEmpty) _detailRow('Safety', safety),
        if (voyeur.isNotEmpty) _detailRow('Voyeur Risk', voyeur),
        if (pose.isNotEmpty) _detailRow('Pose', pose),
        if (framing.isNotEmpty) _detailRow('Framing', framing),
        if (skin.isNotEmpty) _detailRow('Skin', skin),
        if (context_flag.isNotEmpty) _detailRow('Context', context_flag),
      ],
    );
  }

  Widget _scoreBadge(String label, String value, {bool isText = false}) {
    Color color;
    if (isText) {
      color = _PipelineScreenState._ratingColor(value);
    } else {
      final num = int.tryParse(value) ?? 0;
      color = num <= 1 ? AppColors.success : num <= 3 ? AppColors.warning : AppColors.error;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isText ? value.toUpperCase() : '$value/5',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollCtrl,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + widget.bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Pair ${widget.stem}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Full image
          if (widget.imageFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                PipelineApi.pipelineFileUrl(widget.imageFile!),
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.broken_image, size: 60)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.imageFile!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 16),
          // Play video button
          if (widget.videoFile != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_circle_outline, size: 24),
                label: Text('Play ${widget.videoFile}'),
                onPressed: widget.onPlayVideo,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Metadata
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else ...[
            if (_imageMetadata != null && _imageMetadata!.isNotEmpty) ...[
              _metaSection('Image Metadata', _imageMetadata!),
              const SizedBox(height: 16),
            ],
            if (_videoMetadata != null && _videoMetadata!.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              _metaSection('Video Metadata', _videoMetadata!),
            ],
            if ((_imageMetadata == null || _imageMetadata!.isEmpty) &&
                (_videoMetadata == null || _videoMetadata!.isEmpty))
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('No metadata. Tap "Tag All" to generate.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// -- Pair Card Widget -----------------------------------------------

class _PairCard extends StatelessWidget {
  final String stem;
  final String? imageFile;
  final String? videoFile;
  final bool selected;
  final bool isSolo;
  final bool hasVideo;
  final bool hasExtras;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PairCard({
    super.key,
    required this.stem,
    required this.imageFile,
    this.videoFile,
    required this.selected,
    required this.isSolo,
    required this.hasVideo,
    required this.hasExtras,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? const BorderSide(color: AppColors.accent, width: 2)
              : BorderSide.none,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail from server (small, cached)
            if (imageFile != null)
              Image.network(
                PipelineApi.pipelineFileThumbUrl(imageFile!),
                fit: BoxFit.contain,
                cacheWidth: 200,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.bgDark,
                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade600),
                ),
              )
            else
              Container(
                color: AppColors.bgDark,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 40, color: Colors.grey.shade600),
                    ],
                ),
              ),
            ),
            // Bottom gradient with stem number
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Text(
                  'Pair $stem',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
            // Top-left badges
            Positioned(
              left: 6, top: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSolo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Solo',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                              color: Colors.grey.shade400)),
                    ),
                  ],
                  if (!isSolo && hasVideo) ...[
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.videocam, size: 12,
                          color: AppColors.info),
                    ),
                  ],
                  if (hasExtras) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Extra',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                              color: AppColors.warning)),
                    ),
                  ],
                ],
              ),
            ),
            // Checkbox overlay
            Positioned(
              right: 6, top: 6,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.accent
                      : Colors.black.withValues(alpha: 0.4),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Collection Card Widget ----------------------------------------

class _CollectionCard extends StatefulWidget {
  final PipelineCollectionModel collection;
  final VoidCallback? onPush;

  const _CollectionCard({required this.collection, this.onPush});

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _collFiles = [];
  bool _loadingAssets = false;

  Future<void> _loadCollectionFiles() async {
    setState(() => _loadingAssets = true);
    final result = await PipelineApi.getCollectionFiles(
      widget.collection.name,
      widget.collection.rating,
      pushed: widget.collection.isPushed,
    );
    if (mounted && result.ok) {
      setState(() {
        _collFiles = (result.data!)
            .map((j) => j as Map<String, dynamic>)
            .toList();
        _loadingAssets = false;
      });
    } else if (mounted) {
      setState(() => _loadingAssets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coll = widget.collection;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded && _collFiles.isEmpty) _loadCollectionFiles();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.folder,
                      color: _PipelineScreenState._ratingColor(coll.rating)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(coll.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          '${coll.assetCount}${coll.maxItems != null ? ' / ${coll.maxItems}' : ''} assets',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  if (coll.isPushed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14,
                              color: AppColors.success),
                          SizedBox(width: 4),
                          Text('Pushed',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  else if (widget.onPush != null)
                    SizedBox(
                      height: 30,
                      child: FilledButton.icon(
                        onPressed: widget.onPush,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        icon: const Icon(Icons.upload, size: 14),
                        label: const Text('Push'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (_loadingAssets)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_collFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No assets in this collection',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13)),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _collFiles.where((f) => f['file_type'] == 'image').length,
                  itemBuilder: (ctx, index) {
                    final imageFiles = _collFiles.where((f) => f['file_type'] == 'image').toList();
                    final file = imageFiles[index];
                    final filename = file['filename'] as String;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        PipelineApi.pipelineCollectionFileThumbUrl(
                          widget.collection.name,
                          filename,
                          widget.collection.rating,
                          pushed: widget.collection.isPushed,
                        ),
                        key: ValueKey('${widget.collection.name}_$filename'),
                        fit: BoxFit.contain,
                        cacheWidth: 200,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: AppColors.bgDark,
                          child: const Icon(Icons.broken_image,
                              size: 20, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// -- Operation Card Widget -----------------------------------------

class _OpCard extends StatelessWidget {
  final PipelineOpStatus op;
  final VoidCallback onCancel;

  const _OpCard({required this.op, required this.onCancel});

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'match': return Icons.compare_arrows;
      case 'tag': return Icons.label;
      case 'push': return Icons.upload;
      case 'scan': return Icons.radar;
      default: return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = op.isDone;
    final isFailed = op.phase == 'failed';
    final isCancelled = op.phase == 'cancelled';
    final statusColor = isFailed
        ? AppColors.error
        : isCancelled
            ? AppColors.warning
            : isDone
                ? AppColors.success
                : AppColors.info;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_typeIcon(op.type), size: 20, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.type.toUpperCase(),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                    const SizedBox(height: 2),
                    Text(op.message,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFailed
                        ? 'Failed'
                        : isCancelled
                            ? 'Cancelled'
                            : 'Done',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                )
              else
                IconButton(
                  onPressed: onCancel,
                  icon:
                      const Icon(Icons.cancel_outlined, color: AppColors.error),
                  iconSize: 20,
                  tooltip: 'Cancel',
                ),
            ]),
            if (!isDone) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: op.progressPercent > 0 ? op.progressPercent : null,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  color: statusColor,
                ),
              ),
              if (op.total > 0) ...[
                const SizedBox(height: 4),
                Text('${op.progress} / ${op.total}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// -- Video Player Page ------------------------------------------------

class _VideoPlayerPage extends StatelessWidget {
  final String videoUrl;
  final String title;

  const _VideoPlayerPage({required this.videoUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            const SizedBox(height: 8),
            Text(videoUrl, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

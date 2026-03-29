import 'dart:convert';

class PipelineSessionModel {
  final int id;
  final String rating;
  final String phase;
  final String message;
  final String sourceFolder;
  final int totalAssets;
  final int processedAssets;
  final int taggedCount;
  final int matchedCount;
  final int failedCount;
  final String startedAt;
  final String completedAt;
  final String createdAt;

  PipelineSessionModel({
    required this.id,
    required this.rating,
    required this.phase,
    required this.message,
    required this.sourceFolder,
    required this.totalAssets,
    required this.processedAssets,
    required this.taggedCount,
    required this.matchedCount,
    required this.failedCount,
    required this.startedAt,
    required this.completedAt,
    required this.createdAt,
  });

  factory PipelineSessionModel.fromJson(Map<String, dynamic> json) {
    return PipelineSessionModel(
      id: json['id'] ?? 0,
      rating: json['rating'] ?? 'teen',
      phase: json['phase'] ?? 'idle',
      message: json['message'] ?? '',
      sourceFolder: json['source_folder'] ?? '',
      totalAssets: json['total_assets'] ?? 0,
      processedAssets: json['processed_assets'] ?? 0,
      taggedCount: json['tagged_count'] ?? 0,
      matchedCount: json['matched_count'] ?? 0,
      failedCount: json['failed_count'] ?? 0,
      startedAt: json['started_at'] ?? '',
      completedAt: json['completed_at'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PipelineAssetModel {
  final int id;
  final int sessionId;
  final String filename;
  final String filePath;
  final String fileType;
  final String rating;
  final String collection;
  final String status;
  final String tags;
  final String description;
  final int adultScore;
  final int racyScore;
  final int violenceScore;
  final String safetyLevel;
  final String voyeurRisk;
  final String contextFlag;
  final String skinExposure;
  final String poseType;
  final String framing;
  final String clothingCoverage;
  final int? pairedAssetId;
  final String thumbnailPath;
  final Map<String, dynamic> metadata;
  final String createdAt;

  PipelineAssetModel({
    required this.id,
    required this.sessionId,
    required this.filename,
    required this.filePath,
    required this.fileType,
    required this.rating,
    required this.collection,
    required this.status,
    required this.tags,
    required this.description,
    required this.adultScore,
    required this.racyScore,
    required this.violenceScore,
    required this.safetyLevel,
    required this.voyeurRisk,
    required this.contextFlag,
    required this.skinExposure,
    required this.poseType,
    required this.framing,
    required this.clothingCoverage,
    required this.pairedAssetId,
    required this.thumbnailPath,
    required this.metadata,
    required this.createdAt,
  });

  bool get isImage => fileType == 'image';
  bool get isVideo => fileType == 'video';
  bool get isTagged => status == 'tagged' || status == 'accepted' || status == 'pushed';
  bool get isPaired => pairedAssetId != null && pairedAssetId! > 0;

  /// Parse match index from filename pattern: "1.jpg", "2.mp4", "3-extra.mp4"
  /// Limits to 1-4 digit numbers to avoid matching UUID filenames
  int? get matchIndex {
    if (metadata['match_index'] != null) {
      return int.tryParse(metadata['match_index'].toString());
    }
    final match = RegExp(r'^(\d{1,4})[\.\-]').firstMatch(filename);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Whether this is an extra video (e.g. 1-extra.mp4, 1-extra2.mp4)
  bool get isExtra {
    if (metadata['is_extra'] == true) return true;
    return RegExp(r'^\d+-extra', caseSensitive: false).hasMatch(filename);
  }

  /// 'paired' = matched image or its primary video, 'extra' = extra video, 'solo' = unmatched
  String get pairType {
    if (isExtra) return 'extra';
    if (isPaired) return 'paired';
    return 'solo';
  }

  /// Best available display name: filename (after rename) > matched name > description
  String get displayName {
    // If file was renamed to sequential pattern, show that
    if (RegExp(r'^\d+[\.\-]').hasMatch(filename)) {
      return filename;
    }
    final matchedName = metadata['matched_name'] ?? metadata['name'] ?? metadata['display_name'];
    if (matchedName != null && matchedName.toString().isNotEmpty) {
      return matchedName.toString();
    }
    if (description.isNotEmpty) return description;
    return filename;
  }

  factory PipelineAssetModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    final rawMeta = json['metadata_json'];
    if (rawMeta is Map) {
      meta = Map<String, dynamic>.from(rawMeta);
    } else if (rawMeta is String && rawMeta.isNotEmpty && rawMeta != '{}') {
      try {
        meta = Map<String, dynamic>.from(jsonDecode(rawMeta));
      } catch (_) {}
    }

    return PipelineAssetModel(
      id: json['id'] ?? 0,
      sessionId: json['session_id'] ?? 0,
      filename: json['filename'] ?? '',
      filePath: json['file_path'] ?? '',
      fileType: json['file_type'] ?? 'image',
      rating: json['rating'] ?? '',
      collection: json['collection'] ?? '',
      status: json['status'] ?? 'pending',
      tags: json['tags'] ?? '',
      description: json['description'] ?? '',
      adultScore: json['adult_score'] ?? 0,
      racyScore: json['racy_score'] ?? 0,
      violenceScore: json['violence_score'] ?? 0,
      safetyLevel: json['safety_level'] ?? '',
      voyeurRisk: json['voyeur_risk'] ?? '',
      contextFlag: json['context_flag'] ?? '',
      skinExposure: json['skin_exposure'] ?? '',
      poseType: json['pose_type'] ?? '',
      framing: json['framing'] ?? '',
      clothingCoverage: json['clothing_coverage'] ?? '',
      pairedAssetId: json['paired_asset_id'] as int?,
      thumbnailPath: json['thumbnail_path'] ?? '',
      metadata: meta,
      createdAt: json['created_at'] ?? '',
    );
  }

}

class PipelineCollectionModel {
  final int id;
  final String name;
  final String rating;
  final String folderPath;
  final int assetCount;
  final int? maxItems;
  final bool isPushed;
  final String pushedAt;
  final String createdAt;

  PipelineCollectionModel({
    required this.id,
    required this.name,
    required this.rating,
    required this.folderPath,
    required this.assetCount,
    required this.maxItems,
    required this.isPushed,
    required this.pushedAt,
    required this.createdAt,
  });

  factory PipelineCollectionModel.fromJson(Map<String, dynamic> json) {
    return PipelineCollectionModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      rating: json['rating'] ?? 'teen',
      folderPath: json['folder_path'] ?? '',
      assetCount: json['asset_count'] ?? 0,
      maxItems: json['max_items'] as int?,
      isPushed: json['is_pushed'] == true || json['is_pushed'] == 1,
      pushedAt: json['pushed_at'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PipelineOpStatus {
  final String opId;
  final String type;
  final String phase;
  final String message;
  final int progress;
  final int total;
  final String startedAt;

  PipelineOpStatus({
    required this.opId,
    required this.type,
    required this.phase,
    required this.message,
    required this.progress,
    required this.total,
    required this.startedAt,
  });

  bool get isDone => phase == 'done' || phase == 'failed' || phase == 'cancelled';
  double get progressPercent => total > 0 ? progress / total : 0;

  factory PipelineOpStatus.fromJson(Map<String, dynamic> json) {
    return PipelineOpStatus(
      opId: json['op_id'] ?? '',
      type: json['type'] ?? '',
      phase: json['phase'] ?? '',
      message: json['message'] ?? '',
      progress: json['progress'] ?? 0,
      total: json['total'] ?? 0,
      startedAt: json['started_at'] ?? '',
    );
  }
}

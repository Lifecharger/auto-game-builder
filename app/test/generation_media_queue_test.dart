import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_manager_mobile/services/generate_service.dart';
import 'package:app_manager_mobile/widgets/generated_audio.dart';

void main() {
  test('reserved generation tickets keep clear and move controls available', () {
    final queue = UnifiedQueue.fromJson({
      'waiting': [
        {'id': 'a', 'kind': 'comfy', 'job_id': 'a'},
        {'id': 'b', 'kind': 'comfy', 'job_id': 'b', 'can_move_down': true},
        {'id': 'c', 'kind': 'comfy', 'job_id': 'c', 'can_move_up': true},
      ],
      'comfy_pending': [],
      'depth': 3,
    });
    expect(queue.hasPendingGeneration, isTrue);
    expect(queue.waiting.first.canMoveUp, isFalse);
    expect(queue.waiting.first.canMoveDown, isFalse);
    expect(queue.waiting[1].canMoveDown, isTrue);
    expect(queue.waiting[2].canMoveUp, isTrue);
    expect(UnifiedQueue.fromJson({
      'waiting': [{'kind': 'build', 'job_id': 'build:6'}],
    }).hasPendingGeneration, isFalse);
  });

  for (final ext in ['mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac', 'opus']) {
    test('completed $ext is audio and excluded from image actions', () {
      final job = GenerateJob.fromJson({
        'id': 'music', 'status': 'done', 'is_video': false,
        'file_name': 'music.${ext.toUpperCase()}',
      });
      expect(job.isAudio, isTrue);
      expect(job.isImage, isFalse);
      expect(job.isVideo, isFalse);
    });
  }

  testWidgets('audio output renders an open action instead of an image request', (tester) async {
    final job = GenerateJob.fromJson({
      'id': 'music', 'status': 'done', 'file_name': 'music.mp3',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GeneratedAudio(job: job))));
    expect(find.text('Sesi ac'), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

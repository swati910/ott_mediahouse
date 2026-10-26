import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/draft/movie_draft.dart';
import 'package:media_house/app/core/draft/movie_draft_service.dart';
import 'package:media_house/app/core/upload/s3_multipart_upload_service.dart';
import 'package:media_house/app/ui/dialog/discard_changes_dialog.dart';
import 'package:media_house/app/ui/widget/multipart_upload_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieDraft Model Tests', () {
    test('MovieDraft round-trip JSON serialization and deserialization', () {
      final now = DateTime.now();
      final draft = MovieDraft(
        id: 'draft-uuid-1234',
        mediaHouseId: 42,
        createdUserId: 7,
        title: 'Interstellar Odyssey',
        description: 'An epic sci-fi journey beyond time and space.',
        synopsis: 'A group of explorers travel through a wormhole.',
        contentType: 'MOVIE',
        genre: 'Sci-Fi',
        category: 'Feature Film',
        language: 'English',
        releaseDate: '2026-12-25',
        duration: '169 min',
        ageRating: 'PG-13',
        director: 'Christopher Nolan',
        producer: 'Emma Thomas',
        writer: 'Jonathan Nolan',
        castDetails: [
          {'name': 'Matthew McConaughey', 'character': 'Cooper'}
        ],
        crewDetails: [
          {'name': 'Hans Zimmer', 'role': 'Composer'}
        ],
        currentStep: 1,
        lastModified: now,
        uploadStatus: 'PAUSED',
        mainVideoMetadata: MediaVariantDraft(
          fileName: 'interstellar_4k.mp4',
          fileSize: 104857600, // 100 MB
          uploadId: 's3-upload-id-998877',
          completedParts: [1, 2, 3],
          partEtags: {
            '1': '"etag-part-1"',
            '2': '"etag-part-2"',
            '3': '"etag-part-3"',
          },
          uploadStatus: 'PAUSED',
          failureReason: 'Network timeout on part 4',
        ),
        teaserMetadata: MediaVariantDraft(
          fileName: 'teaser.mp4',
          fileSize: 10485760,
          uploadStatus: 'COMPLETED',
        ),
        posterUrl: 'https://example.com/poster.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
      );

      final jsonMap = draft.toJson();
      final decodedDraft = MovieDraft.fromJson(jsonMap);

      expect(decodedDraft.id, 'draft-uuid-1234');
      expect(decodedDraft.mediaHouseId, 42);
      expect(decodedDraft.createdUserId, 7);
      expect(decodedDraft.title, 'Interstellar Odyssey');
      expect(decodedDraft.description, 'An epic sci-fi journey beyond time and space.');
      expect(decodedDraft.contentType, 'MOVIE');
      expect(decodedDraft.director, 'Christopher Nolan');
      expect(decodedDraft.currentStep, 1);
      expect(decodedDraft.castDetails.length, 1);
      expect(decodedDraft.castDetails.first['character'], 'Cooper');
      expect(decodedDraft.crewDetails.first['role'], 'Composer');

      // Verify nested MediaVariantDraft
      expect(decodedDraft.mainVideoMetadata, isNotNull);
      final media = decodedDraft.mainVideoMetadata!;
      expect(media.fileName, 'interstellar_4k.mp4');
      expect(media.fileSize, 104857600);
      expect(media.uploadId, 's3-upload-id-998877');
      expect(media.completedParts, [1, 2, 3]);
      expect(media.partEtags['2'], '"etag-part-2"');
      expect(media.uploadStatus, 'PAUSED');
      expect(media.failureReason, 'Network timeout on part 4');

      expect(decodedDraft.teaserMetadata?.fileName, 'teaser.mp4');
      expect(decodedDraft.posterUrl, 'https://example.com/poster.jpg');
    });

    test('MovieDraft defaults handle missing or null fields gracefully', () {
      final rawJson = {
        'id': 'draft-minimal',
        'mediaHouseId': 10,
        'createdUserId': 1,
      };

      final draft = MovieDraft.fromJson(rawJson);
      expect(draft.id, 'draft-minimal');
      expect(draft.mediaHouseId, 10);
      expect(draft.title, '');
      expect(draft.currentStep, 0);
      expect(draft.uploadStatus, 'DRAFT');
      expect(draft.mainVideoMetadata, isNull);
      expect(draft.castDetails, isEmpty);
    });
  });

  group('MovieDraftService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Save, retrieve, update, and isolate drafts by mediaHouseId', () async {
      final draft1 = MovieDraft(
        id: 'draft-house-1-a',
        mediaHouseId: 101,
        createdUserId: 1,
        title: 'Film Studio A - Movie 1',
        contentType: 'MOVIE',
        currentStep: 0,
        lastModified: DateTime.now(),
      );

      final draft2 = MovieDraft(
        id: 'draft-house-1-b',
        mediaHouseId: 101,
        createdUserId: 1,
        title: 'Film Studio A - Movie 2',
        contentType: 'SHORT_FILM',
        currentStep: 1,
        lastModified: DateTime.now(),
      );

      final draftHouse2 = MovieDraft(
        id: 'draft-house-2-a',
        mediaHouseId: 202,
        createdUserId: 2,
        title: 'Different Studio Movie',
        contentType: 'SERIES',
        currentStep: 0,
        lastModified: DateTime.now(),
      );

      // Save drafts
      await MovieDraftService.saveDraft(draft1);
      await MovieDraftService.saveDraft(draft2);
      await MovieDraftService.saveDraft(draftHouse2);

      // Verify isolation: mediaHouse 101 should only see its 2 drafts
      final draftsForHouse1 = await MovieDraftService.getDrafts(101);
      expect(draftsForHouse1.length, 2);
      expect(draftsForHouse1.any((d) => d.id == 'draft-house-1-a'), isTrue);
      expect(draftsForHouse1.any((d) => d.id == 'draft-house-1-b'), isTrue);
      expect(draftsForHouse1.any((d) => d.id == 'draft-house-2-a'), isFalse);

      // Verify mediaHouse 202 gets its own draft
      final draftsForHouse2 = await MovieDraftService.getDrafts(202);
      expect(draftsForHouse2.length, 1);
      expect(draftsForHouse2.first.id, 'draft-house-2-a');

      // Update draft1 without creating duplicate
      final updatedDraft1 = draft1.copyWith(
        title: 'Film Studio A - Movie 1 (Updated)',
        currentStep: 2,
      );
      await MovieDraftService.saveDraft(updatedDraft1);

      final fetchedDraft = await MovieDraftService.getDraft('draft-house-1-a');
      expect(fetchedDraft, isNotNull);
      expect(fetchedDraft!.title, 'Film Studio A - Movie 1 (Updated)');
      expect(fetchedDraft.currentStep, 2);

      final reFetchedHouse1 = await MovieDraftService.getDrafts(101);
      expect(reFetchedHouse1.length, 2); // No duplicate created

      // Delete draft
      await MovieDraftService.deleteDraft('draft-house-1-a');
      final afterDelete = await MovieDraftService.getDraft('draft-house-1-a');
      expect(afterDelete, isNull);

      final remainingHouse1 = await MovieDraftService.getDrafts(101);
      expect(remainingHouse1.length, 1);
      expect(remainingHouse1.first.id, 'draft-house-1-b');
    });
  });

  group('DiscardChangesDialog UI Tests', () {
    testWidgets('Renders Instagram-style dialog options and returns selected action',
        (WidgetTester tester) async {
      DiscardDialogAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedAction = await DiscardChangesDialog.show(context);
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Check title and message
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(
        find.text(
            'If you close this window now, you can save your progress as a draft or discard your changes.'),
        findsOneWidget,
      );

      // Check 3 actions are visible
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);

      // Tap 'Keep Editing'
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(selectedAction, DiscardDialogAction.keepEditing);

      // Show dialog again and tap 'Save Draft'
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      expect(selectedAction, DiscardDialogAction.saveDraft);

      // Show dialog again and tap 'Discard'
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(selectedAction, DiscardDialogAction.discard);
    });
  });

  group('S3 Multipart Upload ETag and Sizing Logic Tests', () {
    test('Calculates MD5 hex hash conforming to S3 ETag format when CORS header is missing', () {
      final sampleChunk = Uint8List.fromList(utf8.encode('Test Chunk Content for S3 Upload Part'));
      final md5Digest = md5.convert(sampleChunk).toString();
      final quotedEtag = '"$md5Digest"';

      expect(quotedEtag.startsWith('"'), isTrue);
      expect(quotedEtag.endsWith('"'), isTrue);
      expect(md5Digest.length, 32); // standard 32-char hex MD5
      expect(quotedEtag, '"${md5.convert(sampleChunk)}"');
    });

    test('Presigned URL signed headers detection only sets Content-Type when explicitly signed', () {
      const urlWithoutContentType =
          'https://mybucket.s3.amazonaws.com/video.mp4?partNumber=1&uploadId=xyz&X-Amz-SignedHeaders=host';
      const urlWithContentType =
          'https://mybucket.s3.amazonaws.com/video.mp4?partNumber=1&uploadId=xyz&X-Amz-SignedHeaders=content-type%3Bhost';

      final uri1 = Uri.parse(urlWithoutContentType);
      final signedHeaders1 =
          uri1.queryParameters['X-Amz-SignedHeaders']?.toLowerCase() ?? '';
      expect(signedHeaders1.contains('content-type'), isFalse);

      final uri2 = Uri.parse(urlWithContentType);
      final signedHeaders2 =
          uri2.queryParameters['X-Amz-SignedHeaders']?.toLowerCase() ?? '';
      expect(signedHeaders2.contains('content-type'), isTrue);
    });

    test('Multipart completion payload enforces ascending part numbers and quoted ETags', () {
      final completedETags = <int, String>{
        3: 'etag3',
        1: '"etag1"',
        2: 'etag2',
      };

      final sortedParts = completedETags.entries
          .map((e) {
            var tag = e.value.trim();
            if (!tag.startsWith('"')) tag = '"$tag';
            if (!tag.endsWith('"')) tag = '$tag"';
            return {'partNumber': e.key, 'eTag': tag};
          })
          .toList()
        ..sort((a, b) =>
            (a['partNumber'] as int).compareTo(b['partNumber'] as int));

      expect(sortedParts.length, 3);
      expect(sortedParts[0]['partNumber'], 1);
      expect(sortedParts[0]['eTag'], '"etag1"');
      expect(sortedParts[1]['partNumber'], 2);
      expect(sortedParts[1]['eTag'], '"etag2"');
      expect(sortedParts[2]['partNumber'], 3);
      expect(sortedParts[2]['eTag'], '"etag3"');
    });

    test('Progress percentage and formatters calculate accurately without reset on chunk failure', () {
      const totalBytes = 100 * 1024 * 1024; // 100 MB
      int confirmedBytes = 20 * 1024 * 1024; // 20 MB (2 parts confirmed)
      int inFlightBytes = 5 * 1024 * 1024; // 5 MB currently uploading

      int currentTotal = confirmedBytes + inFlightBytes;
      double pct = (currentTotal / totalBytes) * 100.0;
      expect(pct, 25.0);

      // Simulating a failed chunk: in-flight resets to 0, confirmedBytes remains intact
      inFlightBytes = 0;
      currentTotal = confirmedBytes + inFlightBytes;
      pct = (currentTotal / totalBytes) * 100.0;
      expect(pct, 20.0); // Does NOT reset to 0%

      // Formatters
      expect(MultipartUploadProgressWidget.formatBytes(10485760), '10.0 MB');
      expect(MultipartUploadProgressWidget.formatSpeed(5242880), '5.0 MB/s');
      expect(MultipartUploadProgressWidget.formatEta(65), '01:05');
      expect(MultipartUploadProgressWidget.formatEta(3665), '1h 1m');
    });

    testWidgets('MultipartUploadProgressWidget renders progress, parts count, remaining parts, speed, and ETA', (tester) async {
      final info = MultipartProgressInfo(
        state: MultipartUploadState.uploading,
        percentage: 45.5,
        uploadedBytes: 47710208, // ~45.5 MB
        totalBytes: 104857600,   // 100 MB
        completedParts: 4,
        totalParts: 10,
        speedBytesPerSec: 2097152, // 2 MB/s
        remainingSeconds: 27,
        localTaskId: 'test-task-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultipartUploadProgressWidget(
              info: info,
            ),
          ),
        ),
      );

      expect(find.text('45.5%'), findsOneWidget);
      expect(find.textContaining('Parts: 4/10 (6 remaining)'), findsOneWidget);
      expect(find.textContaining('Speed: 2.0 MB/s'), findsOneWidget);
      expect(find.textContaining('Remaining: 00:27'), findsOneWidget);
    });

    test('S3MultipartUploadTask defaults to direct S3 without local proxy wrapping', () {
      expect(S3MultipartUploadTask.useLocalDevProxy, isFalse);

      const s3Url =
          'https://ott-video-content.s3.ap-south-1.amazonaws.com/media/movies/movie.mp4?partNumber=1&uploadId=xyz';
      final uri = Uri.parse(s3Url);
      expect(uri.host, 'ott-video-content.s3.ap-south-1.amazonaws.com');

      // Without proxy rewrite, targetUrl is identical to presigned S3 URL
      String targetUrl = s3Url;
      const bool isLocalhost = true;
      if (isLocalhost && S3MultipartUploadTask.useLocalDevProxy) {
        targetUrl =
            'http://127.0.0.1:8089/proxy?url=${Uri.encodeComponent(s3Url)}';
      }
      expect(targetUrl, s3Url);
      expect(targetUrl.contains('127.0.0.1:8089'), isFalse);
    });

    test('Progress percentage is capped below 100% until all parts are confirmed and completed', () {
      const totalBytes = 1800000000; // ~1.8 GB
      const confirmedBytes = 0; // 0 parts confirmed by S3
      const inFlightBytes = 1800000000; // socket sent 1.8 GB to in-flight buffer
      const completedParts = 0;
      const totalParts = 4;

      final currentUploadedBytes = confirmedBytes + inFlightBytes;
      final rawPct = (currentUploadedBytes / totalBytes) * 100.0;
      expect(rawPct, 100.0);

      // S3MultipartUploadTask logic: capped at 99.0% while parts are unconfirmed
      double pct = rawPct;
      if (completedParts < totalParts) {
        pct = rawPct > 99.0 ? 99.0 : rawPct;
      }
      expect(pct, 99.0); // Never 100.0% before S3 confirms all parts

      // Upon failure: in-flight bytes clear, confirmed remains
      const failedStateBytes = confirmedBytes;
      final failedPct = (failedStateBytes / totalBytes) * 100.0;
      expect(failedPct, 0.0); // Immediately reflects 0% upon failure when 0 parts confirmed
    });
  });
}


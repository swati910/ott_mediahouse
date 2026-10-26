import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/upload/s3_multipart_upload_service.dart';
import 'package:media_house/app/provider/videoProvider.dart';
import 'package:media_house/app/ui/pages/DisplayTrailer.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_media_helpers.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (_) {}

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Upload Video View & Format Helpers Tests', () {
    test('isVideoFile correctly classifies video vs non-video media labels', () {
      expect(UploadMediaHelpers.isVideoFile('Movie File'), isTrue);
      expect(UploadMediaHelpers.isVideoFile('Trailer File'), isTrue);
      expect(UploadMediaHelpers.isVideoFile('Teaser File'), isTrue);
      expect(UploadMediaHelpers.isVideoFile('Video File'), isTrue);

      expect(UploadMediaHelpers.isVideoFile('Poster 1'), isFalse);
      expect(UploadMediaHelpers.isVideoFile('Poster 2'), isFalse);
      expect(UploadMediaHelpers.isVideoFile('Poster 3'), isFalse);
      expect(UploadMediaHelpers.isVideoFile('Censor Certificate'), isFalse);
      expect(UploadMediaHelpers.isVideoFile('Cast Image'), isFalse);
      expect(UploadMediaHelpers.isVideoFile('Crew Image'), isFalse);
    });

    test('formatPlayableVideoUrl preserves full HTTP, HTTPS, blob, and local URLs', () {
      expect(
        UploadMediaHelpers.formatPlayableVideoUrl('https://example.com/video.mp4'),
        equals('https://example.com/video.mp4'),
      );
      expect(
        UploadMediaHelpers.formatPlayableVideoUrl('http://example.com/video.mp4'),
        equals('http://example.com/video.mp4'),
      );
      expect(
        UploadMediaHelpers.formatPlayableVideoUrl('blob:http://localhost:8080/uuid-1234'),
        equals('blob:http://localhost:8080/uuid-1234'),
      );
      expect(
        UploadMediaHelpers.formatPlayableVideoUrl('/var/mobile/video.mp4'),
        equals('/var/mobile/video.mp4'),
      );
      expect(
        UploadMediaHelpers.formatPlayableVideoUrl(''),
        equals(''),
      );
    });

    test('formatPlayableVideoUrl prefixes S3 key paths with cloud endpoint', () {
      const s3Key = 'input/1001/uuid-1234/movie.mp4';
      final formatted = UploadMediaHelpers.formatPlayableVideoUrl(s3Key);
      expect(formatted, equals('https://ott-video-content.s3.ap-south-1.amazonaws.com/$s3Key'));
    });

    test('getVideoUrl retrieves controller URLs for all video labels', () {
      final provider = VideoProvider();
      provider.trailerUrlController.text = 'https://s3.amazonaws.com/trailer.mp4';
      provider.teaserUrlController.text = 'https://s3.amazonaws.com/teaser.mp4';
      provider.movieUrlController.text = 'https://s3.amazonaws.com/movie.mp4';

      expect(
        UploadMediaHelpers.getVideoUrl('Trailer File', provider),
        equals('https://s3.amazonaws.com/trailer.mp4'),
      );
      expect(
        UploadMediaHelpers.getVideoUrl('Teaser File', provider),
        equals('https://s3.amazonaws.com/teaser.mp4'),
      );
      expect(
        UploadMediaHelpers.getVideoUrl('Movie File', provider),
        equals('https://s3.amazonaws.com/movie.mp4'),
      );
      expect(
        UploadMediaHelpers.getVideoUrl('Video File', provider),
        equals('https://s3.amazonaws.com/movie.mp4'),
      );
      expect(
        UploadMediaHelpers.getVideoUrl('Poster 1', provider),
        isNull,
      );
    });
  });

  group('Delete Video Functionality & State Lifecycle Tests', () {
    test('deleteMediaByLabel cleanly deletes Teaser and resets all states', () async {
      final provider = VideoProvider();
      provider.teaserUrlController.text = 'https://s3.amazonaws.com/teaser.mp4';
      provider.teaserFileName = 'teaser.mp4';
      provider.teaserUploadProgress = 1.0;
      provider.teaserUploadProgressInfo = MultipartProgressInfo(
        state: MultipartUploadState.completed,
        percentage: 100.0,
        uploadedBytes: 5000,
        totalBytes: 5000,
        completedParts: 1,
        totalParts: 1,
        speedBytesPerSec: 0,
        remainingSeconds: 0,
        localTaskId: 'teaser_task_1',
      );
      provider.movieVariantController('Hindi', 'teaser').text =
          'https://s3.amazonaws.com/teaser.mp4';

      expect(UploadMediaHelpers.getUploadStatus('Teaser File', provider), isTrue);

      await UploadMediaHelpers.deleteMediaByLabel('Teaser File', provider);

      expect(provider.teaserUrlController.text, isEmpty);
      expect(provider.teaserFileName, isNull);
      expect(provider.teaserUploadProgress, equals(0.0));
      expect(provider.teaserUploadProgressInfo, isNull);
      expect(provider.activeTeaserProgressInfo, isNull);
      expect(provider.teaserSelectedFile, isNull);
      expect(provider.teaserUploadTask, isNull);
      expect(provider.isTeaserUploading, isFalse);
      expect(provider.movieVariantController('Hindi', 'teaser').text, isEmpty);
      expect(UploadMediaHelpers.getUploadStatus('Teaser File', provider), isFalse);
    });

    test('deleteMediaByLabel cleanly deletes Trailer and resets all states', () async {
      final provider = VideoProvider();
      provider.trailerUrlController.text = 'https://s3.amazonaws.com/trailer.mp4';
      provider.trailerFileName = 'trailer.mp4';
      provider.trailerUploadProgress = 1.0;
      provider.trailerUploadProgressInfo = MultipartProgressInfo(
        state: MultipartUploadState.completed,
        percentage: 100.0,
        uploadedBytes: 8000,
        totalBytes: 8000,
        completedParts: 2,
        totalParts: 2,
        speedBytesPerSec: 0,
        remainingSeconds: 0,
        localTaskId: 'trailer_task_1',
      );
      provider.movieVariantController('English', 'trailer').text =
          'https://s3.amazonaws.com/trailer.mp4';

      expect(UploadMediaHelpers.getUploadStatus('Trailer File', provider), isTrue);

      await UploadMediaHelpers.deleteMediaByLabel('Trailer File', provider);

      expect(provider.trailerUrlController.text, isEmpty);
      expect(provider.trailerFileName, isNull);
      expect(provider.trailerUploadProgress, equals(0.0));
      expect(provider.trailerUploadProgressInfo, isNull);
      expect(provider.activeTrailerProgressInfo, isNull);
      expect(provider.trailerSelectedFile, isNull);
      expect(provider.trailerUploadTask, isNull);
      expect(provider.isTrailerUploading, isFalse);
      expect(provider.movieVariantController('English', 'trailer').text, isEmpty);
      expect(UploadMediaHelpers.getUploadStatus('Trailer File', provider), isFalse);
    });

    test('deleteMediaByLabel cleanly deletes Movie File and resets all states', () async {
      final provider = VideoProvider();
      provider.movieUrlController.text = 'https://s3.amazonaws.com/movie.mp4';
      provider.movieFileName = 'movie.mp4';
      provider.movieUploadProgress = 1.0;
      provider.primaryUploadProgressInfo = MultipartProgressInfo(
        state: MultipartUploadState.completed,
        percentage: 100.0,
        uploadedBytes: 50000,
        totalBytes: 50000,
        completedParts: 5,
        totalParts: 5,
        speedBytesPerSec: 0,
        remainingSeconds: 0,
        localTaskId: 'primary_task_1',
      );
      provider.movieVariantController('Hindi', 'movie').text =
          'https://s3.amazonaws.com/movie.mp4';

      expect(UploadMediaHelpers.getUploadStatus('Movie File', provider), isTrue);

      await UploadMediaHelpers.deleteMediaByLabel('Movie File', provider);

      expect(provider.movieUrlController.text, isEmpty);
      expect(provider.movieFileName, isNull);
      expect(provider.movieUploadProgress, equals(0.0));
      expect(provider.primaryUploadProgressInfo, isNull);
      expect(provider.activePrimaryProgressInfo, isNull);
      expect(provider.primarySelectedFile, isNull);
      expect(provider.primaryUploadTask, isNull);
      expect(provider.isMovieUploading, isFalse);
      expect(provider.movieVariantController('Hindi', 'movie').text, isEmpty);
      expect(UploadMediaHelpers.getUploadStatus('Movie File', provider), isFalse);
    });

    test('clearMovieVariant aborts and resets video field and language controller', () {
      final provider = VideoProvider();
      provider.teaserUrlController.text = 'https://s3.amazonaws.com/teaser.mp4';
      provider.movieVariantController('Hindi', 'teaser').text =
          'https://s3.amazonaws.com/teaser.mp4';
      provider.teaserFileName = 'teaser.mp4';

      provider.clearMovieVariant('Hindi', 'teaser');

      expect(provider.movieVariantController('Hindi', 'teaser').text, isEmpty);
      expect(provider.teaserUrlController.text, isEmpty);
      expect(provider.teaserFileName, isNull);
      expect(provider.isTeaserUploading, isFalse);
      expect(provider.teaserUploadProgress, equals(0.0));
    });
  });

  group('showVideoPreview Dialog & Controller Disposal Tests', () {
    testWidgets('showVideoPreview dialog opens with label, close button, and TrailerPage', (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              testContext = ctx;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    UploadMediaHelpers.showVideoPreview(
                      ctx,
                      'https://example.com/teaser.mp4',
                      'Teaser File',
                      ThemeData.dark(),
                    );
                  },
                  child: const Text('Open Preview'),
                ),
              );
            },
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Open Preview'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      // Open the preview dialog
      await tester.tap(find.text('Open Preview'));
      await tester.pump();

      // Dialog is displayed with correct title and components
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Teaser File'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(TrailerPage), findsOneWidget);

      // Close the preview dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog is dismissed and underlying screen remains intact
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Open Preview'), findsOneWidget);
    });

    testWidgets('confirmDeleteMedia dialog displays confirmation and respects user response', (tester) async {
      bool? userResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    userResult = await UploadMediaHelpers.confirmDeleteMedia(ctx, 'Teaser File');
                  },
                  child: const Text('Delete Action'),
                ),
              );
            },
          ),
        ),
      );

      // Tap to open confirm dialog
      await tester.tap(find.text('Delete Action'));
      await tester.pump();

      expect(find.text('Delete Teaser File?'), findsOneWidget);
      expect(find.text('Are you sure you want to delete this Teaser File?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Cancel dismissal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(userResult, isFalse);
      expect(find.byType(AlertDialog), findsNothing);

      // Reopen and confirm delete
      await tester.tap(find.text('Delete Action'));
      await tester.pump();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(userResult, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/upload/s3_multipart_upload_service.dart';
import 'package:media_house/app/provider/videoProvider.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_media_helpers.dart';
import 'package:media_house/app/ui/widget/multipart_upload_progress_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multipart Abort API Constant Tests', () {
    test('API 1: Abort by Session ID generates correct endpoint URL', () {
      final endpoint = ApiConstant.multipartAbort(56);
      expect(endpoint, equals('${ApiConstant.baseUrl}api/video/multipart/56'));
    });

    test('API 2: Abort with Request Body endpoint URL is correctly defined', () {
      expect(
        ApiConstant.multipartAbortWithBody,
        equals('${ApiConstant.baseUrl}api/video/multipart/abort'),
      );
    });
  });

  group('MultipartUploadState and MultipartProgressInfo Abort Tests', () {
    test('MultipartUploadState includes aborting and aborted states', () {
      expect(MultipartUploadState.values, contains(MultipartUploadState.aborting));
      expect(MultipartUploadState.values, contains(MultipartUploadState.aborted));
    });

    test('MultipartProgressInfo.isAborting is true only in aborting state', () {
      final abortingInfo = MultipartProgressInfo(
        state: MultipartUploadState.aborting,
        percentage: 45.0,
        uploadedBytes: 4500,
        totalBytes: 10000,
        completedParts: 1,
        totalParts: 2,
        speedBytesPerSec: 0,
        remainingSeconds: 0,
        localTaskId: 'test-task',
      );
      expect(abortingInfo.isAborting, isTrue);

      final uploadingInfo = MultipartProgressInfo(
        state: MultipartUploadState.uploading,
        percentage: 45.0,
        uploadedBytes: 4500,
        totalBytes: 10000,
        completedParts: 1,
        totalParts: 2,
        speedBytesPerSec: 1024,
        remainingSeconds: 5,
        localTaskId: 'test-task',
      );
      expect(uploadingInfo.isAborting, isFalse);
    });
  });

  group('MultipartUploadProgressWidget Abort UI Tests', () {
    testWidgets('Displays Cancelling... and disables button during aborting state',
        (tester) async {
      final info = MultipartProgressInfo(
        state: MultipartUploadState.aborting,
        percentage: 60.0,
        uploadedBytes: 600,
        totalBytes: 1000,
        completedParts: 3,
        totalParts: 5,
        speedBytesPerSec: 0,
        remainingSeconds: 0,
        localTaskId: 'test-abort',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultipartUploadProgressWidget(info: info),
          ),
        ),
      );

      // Verify title and status
      expect(find.text('Cancelling upload...'), findsOneWidget);
      expect(find.text('Cancelling...'), findsOneWidget);

      // Cancel Upload and Pause/Resume buttons should not be active
      expect(find.text('Cancel Upload'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('Clicking Cancel Upload opens confirmation dialog and calls onAbort',
        (tester) async {
      bool abortCalled = false;
      final info = MultipartProgressInfo(
        state: MultipartUploadState.uploading,
        percentage: 40.0,
        uploadedBytes: 400,
        totalBytes: 1000,
        completedParts: 2,
        totalParts: 5,
        speedBytesPerSec: 1024,
        remainingSeconds: 10,
        localTaskId: 'test-task',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultipartUploadProgressWidget(
              info: info,
              onAbort: () {
                abortCalled = true;
              },
            ),
          ),
        ),
      );

      // Click Cancel Upload
      final cancelButton = find.text('Cancel Upload');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Cancel Upload?'), findsOneWidget);
      expect(find.text('No, keep upload'), findsOneWidget);
      expect(find.text('Yes, Cancel Upload'), findsOneWidget);

      // Confirm abort
      await tester.tap(find.text('Yes, Cancel Upload'));
      await tester.pumpAndSettle();

      expect(abortCalled, isTrue);
    });

    testWidgets('Dismissing Cancel Upload confirmation preserves upload state',
        (tester) async {
      bool abortCalled = false;
      final info = MultipartProgressInfo(
        state: MultipartUploadState.uploading,
        percentage: 40.0,
        uploadedBytes: 400,
        totalBytes: 1000,
        completedParts: 2,
        totalParts: 5,
        speedBytesPerSec: 1024,
        remainingSeconds: 10,
        localTaskId: 'test-task',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultipartUploadProgressWidget(
              info: info,
              onAbort: () {
                abortCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel Upload'));
      await tester.pumpAndSettle();

      // Click No, keep upload
      await tester.tap(find.text('No, keep upload'));
      await tester.pumpAndSettle();

      expect(abortCalled, isFalse);
      expect(find.text('Cancel Upload?'), findsNothing);
    });
  });

  group('S3MultipartUploadTask Abort Logic & Race Condition Safeguards', () {
    test('Abort without backend uploadSessionId immediately clears local state', () async {
      final task = S3MultipartUploadTask(
        localTaskId: 'local-test-1',
        contentId: '1001',
      );
      task.state = MultipartUploadState.initiating;

      final success = await task.abort();
      expect(success, isTrue);
      expect(task.state, equals(MultipartUploadState.aborted));
      expect(task.isAborting, isFalse);
    });

    test('Prevents duplicate abort calls when cancellation is already in progress', () async {
      final task = S3MultipartUploadTask(
        localTaskId: 'local-test-dup',
        contentId: '1001',
      );
      task.uploadSessionId = null;

      final future1 = task.abort();
      final future2 = task.abort();

      final results = await Future.wait([future1, future2]);
      expect(results[0], isTrue);
      expect(results[1], isTrue);
    });

    test('Selects Body API when uploadId and key are present', () {
      final task = S3MultipartUploadTask(
        localTaskId: 'task-body',
        contentId: '1001',
      );
      task.uploadSessionId = 57;
      task.uploadId = 's3-upload-id-abc';
      task.key = 'input/1001/video.mp4';

      final bool useBodyApi = !S3MultipartUploadTask.preferSessionIdAbort &&
          task.uploadId.isNotEmpty &&
          task.key.isNotEmpty;

      expect(useBodyApi, isTrue);
    });

    test('Selects Session ID Alone API when uploadId or key is missing or forced', () {
      final task = S3MultipartUploadTask(
        localTaskId: 'task-session',
        contentId: '1001',
      );
      task.uploadSessionId = 56;
      task.uploadId = '';
      task.key = '';

      final bool useBodyApi = !S3MultipartUploadTask.preferSessionIdAbort &&
          task.uploadId.isNotEmpty &&
          task.key.isNotEmpty;

      expect(useBodyApi, isFalse);
    });
  });

  group('VideoProvider Abort & Cleanup Tests', () {
    test('abortPrimaryMultipartUpload clears url controller and variant fields', () async {
      final provider = VideoProvider();
      provider.movieUrlController.text = 'https://s3.amazonaws.com/test.mp4';
      provider.movieVariantController('Tamil', 'movie').text = 'https://s3.amazonaws.com/test.mp4';

      final result = await provider.abortPrimaryMultipartUpload();
      expect(result, isTrue);
      expect(provider.movieUrlController.text, isEmpty);
      expect(provider.movieVariantController('Tamil', 'movie').text, isEmpty);
      expect(provider.primaryUploadTask, isNull);
    });

    test('abortTeaserMultipartUpload clears teaser url controller and variant', () async {
      final provider = VideoProvider();
      provider.teaserUrlController.text = 'https://s3.amazonaws.com/teaser.mp4';
      provider.movieVariantController('Tamil', 'teaser').text = 'https://s3.amazonaws.com/teaser.mp4';

      final result = await provider.abortTeaserMultipartUpload();
      expect(result, isTrue);
      expect(provider.teaserUrlController.text, isEmpty);
      expect(provider.movieVariantController('Tamil', 'teaser').text, isEmpty);
      expect(provider.teaserUploadTask, isNull);
    });

    test('abortTrailerMultipartUpload clears trailer url controller and variant', () async {
      final provider = VideoProvider();
      provider.trailerUrlController.text = 'https://s3.amazonaws.com/trailer.mp4';
      provider.movieVariantController('Tamil', 'trailer').text = 'https://s3.amazonaws.com/trailer.mp4';

      final result = await provider.abortTrailerMultipartUpload();
      expect(result, isTrue);
      expect(provider.trailerUrlController.text, isEmpty);
      expect(provider.movieVariantController('Tamil', 'trailer').text, isEmpty);
      expect(provider.trailerUploadTask, isNull);
    });

    test('abortAllActiveMultipartUploads succeeds when no tasks or all cleaned up', () async {
      final provider = VideoProvider();
      final result = await provider.abortAllActiveMultipartUploads();
      expect(result, isTrue);
    });

    test('hasActiveOrIncompleteUploads correctly detects active upload tasks', () {
      final provider = VideoProvider();
      expect(provider.hasActiveOrIncompleteUploads, isFalse);

      final task = S3MultipartUploadTask(
        localTaskId: 'active-1',
        contentId: '1001',
      );
      task.state = MultipartUploadState.uploading;
      provider.primaryUploadTask = task;

      expect(provider.hasActiveOrIncompleteUploads, isTrue);

      task.state = MultipartUploadState.completed;
      expect(provider.hasActiveOrIncompleteUploads, isFalse);
    });
  });

  group('UploadMediaHelpers Delete & Confirm Dialog Tests', () {
    testWidgets('confirmDeleteMedia returns true on Delete and false on Cancel',
        (tester) async {
      bool? confirmedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmedResult =
                    await UploadMediaHelpers.confirmDeleteMedia(context, 'Trailer File');
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      // 1. Test Cancel
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Trailer File?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(confirmedResult, isFalse);

      // 2. Test Delete
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(confirmedResult, isTrue);
    });

    test('deleteMediaByLabel clears controllers and resets progress', () async {
      final provider = VideoProvider();
      provider.trailerUrlController.text = 'https://s3.amazonaws.com/trailer.mp4';
      provider.trailerUploadProgress = 0.8;

      await UploadMediaHelpers.deleteMediaByLabel('Trailer File', provider);

      expect(provider.trailerUrlController.text, isEmpty);
      expect(provider.trailerUploadProgress, equals(0.0));
      expect(provider.trailerUploadTask, isNull);
    });
  });
}

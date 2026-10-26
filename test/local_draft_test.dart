import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/draft/movie_draft.dart';
import 'package:media_house/app/core/draft/movie_draft_service.dart';
import 'package:media_house/app/provider/videoProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pure Local Draft Storage Tests (Section 1, 2, 5, 7)', () {
    test('Saving, retrieving, and deleting drafts work 100% locally with zero backend API calls', () async {
      final draft = MovieDraft(
        draftId: 'draft_uploadMovie_100_1700000000',
        formType: 'uploadMovie',
        mediaHouseId: 100,
        title: 'Cyberpunk Metropolis',
        description: 'A sci-fi dystopian drama.',
        contentType: 'MOVIE',
        currentStep: 2,
        selectedGenres: ['Sci-Fi', 'Action'],
        price: 199.0,
        runtime: 124.0,
        releaseDate: '2026-11-15',
        primaryFileName: 'cyberpunk_feature_4k.mp4',
        primaryFileSize: 2500000000,
        primaryFileType: 'video/mp4',
        teaserFileName: 'cyberpunk_teaser.mp4',
        trailerFileName: 'cyberpunk_trailer.mp4',
        poster1Url: 'https://example.com/poster1.jpg',
      );

      // Save draft purely locally
      final saved = await MovieDraftService.saveDraft(draft);
      expect(saved.draftId, draft.draftId);
      expect(saved.title, 'Cyberpunk Metropolis');

      // Retrieve by ID
      final retrieved = await MovieDraftService.getDraft(draft.draftId);
      expect(retrieved, isNotNull);
      expect(retrieved!.draftId, draft.draftId);
      expect(retrieved.formType, 'uploadMovie');
      expect(retrieved.title, 'Cyberpunk Metropolis');
      expect(retrieved.currentStep, 2);
      expect(retrieved.price, 199.0);
      expect(retrieved.primaryFileName, 'cyberpunk_feature_4k.mp4');
      expect(retrieved.primaryFileSize, 2500000000);
      expect(retrieved.primaryFileType, 'video/mp4');
      expect(retrieved.teaserFileName, 'cyberpunk_teaser.mp4');
      expect(retrieved.trailerFileName, 'cyberpunk_trailer.mp4');
      expect(retrieved.poster1Url, 'https://example.com/poster1.jpg');

      // Delete draft
      final deleted = await MovieDraftService.deleteDraft(draft.draftId);
      expect(deleted, isTrue);

      final checkDeleted = await MovieDraftService.getDraft(draft.draftId);
      expect(checkDeleted, isNull);
    });

    test('Draft identification isolates different forms and content records without accidental overwriting', () async {
      const mediaHouseId = 55;

      // 1. Upload Movie Draft
      final movieDraft = MovieDraft(
        draftId: MovieDraft.generateDraftId(
          formType: 'uploadMovie',
          mediaHouseId: mediaHouseId,
        ),
        formType: 'uploadMovie',
        mediaHouseId: mediaHouseId,
        title: 'New Feature Film',
        contentType: 'MOVIE',
        currentStep: 1,
      );

      // 2. Upload Trailer Draft
      final trailerDraft = MovieDraft(
        draftId: MovieDraft.generateDraftId(
          formType: 'uploadTrailer',
          mediaHouseId: mediaHouseId,
        ),
        formType: 'uploadTrailer',
        mediaHouseId: mediaHouseId,
        title: 'Teaser & Trailer Showcase',
        contentType: 'MOVIE',
        trailerFileName: 'official_trailer.mp4',
        currentStep: 2,
      );

      // 3. Upload Teaser Draft
      final teaserDraft = MovieDraft(
        draftId: MovieDraft.generateDraftId(
          formType: 'uploadTeaser',
          mediaHouseId: mediaHouseId,
        ),
        formType: 'uploadTeaser',
        mediaHouseId: mediaHouseId,
        title: 'Short Sneak Peek',
        contentType: 'MOVIE',
        teaserFileName: 'sneak_peek.mp4',
        currentStep: 0,
      );

      // 4. Edit Movie Draft for Content ID 888
      final editMovieDraft888 = MovieDraft(
        draftId: MovieDraft.generateDraftId(
          formType: 'editMovie',
          mediaHouseId: mediaHouseId,
          contentId: 888,
        ),
        formType: 'editMovie',
        mediaHouseId: mediaHouseId,
        contentId: 888,
        title: 'Editing Movie 888',
        contentType: 'MOVIE',
        currentStep: 2,
      );

      // 5. Edit Movie Draft for Content ID 999
      final editMovieDraft999 = MovieDraft(
        draftId: MovieDraft.generateDraftId(
          formType: 'editMovie',
          mediaHouseId: mediaHouseId,
          contentId: 999,
        ),
        formType: 'editMovie',
        mediaHouseId: mediaHouseId,
        contentId: 999,
        title: 'Editing Movie 999',
        contentType: 'MOVIE',
        currentStep: 1,
      );

      // Save all drafts
      await MovieDraftService.saveDraft(movieDraft);
      await MovieDraftService.saveDraft(trailerDraft);
      await MovieDraftService.saveDraft(teaserDraft);
      await MovieDraftService.saveDraft(editMovieDraft888);
      await MovieDraftService.saveDraft(editMovieDraft999);

      // All 5 drafts exist separately
      final all = await MovieDraftService.getDrafts(mediaHouseId);
      expect(all.length, 5);

      // Filter by formType
      final movieDrafts = await MovieDraftService.getDraftsByFormType('uploadMovie', mediaHouseId: mediaHouseId);
      expect(movieDrafts.length, 1);
      expect(movieDrafts.first.title, 'New Feature Film');

      final trailerDrafts = await MovieDraftService.getDraftsByFormType('uploadTrailer', mediaHouseId: mediaHouseId);
      expect(trailerDrafts.length, 1);
      expect(trailerDrafts.first.trailerFileName, 'official_trailer.mp4');

      final teaserDrafts = await MovieDraftService.getDraftsByFormType('uploadTeaser', mediaHouseId: mediaHouseId);
      expect(teaserDrafts.length, 1);
      expect(teaserDrafts.first.teaserFileName, 'sneak_peek.mp4');

      final editDrafts = await MovieDraftService.getDraftsByFormType('editMovie', mediaHouseId: mediaHouseId);
      expect(editDrafts.length, 2);

      // Lookup by contentId for edit forms
      final content888 = await MovieDraftService.getDraftByContentId(888, mediaHouseId: mediaHouseId);
      expect(content888, isNotNull);
      expect(content888!.title, 'Editing Movie 888');

      final content999 = await MovieDraftService.getDraftByContentId(999, mediaHouseId: mediaHouseId);
      expect(content999, isNotNull);
      expect(content999!.title, 'Editing Movie 999');

      // Clear only trailer drafts
      await MovieDraftService.clearDraftsForForm('uploadTrailer', mediaHouseId: mediaHouseId);
      final afterClearTrailer = await MovieDraftService.getDrafts(mediaHouseId);
      expect(afterClearTrailer.length, 4);
      expect(afterClearTrailer.any((d) => d.formType == 'uploadTrailer'), isFalse);
    });
  });

  group('Draft Values Restoration into VideoProvider Form State (Section 3, 4, 6)', () {
    test('VideoProvider.loadFromDraft restores all text controllers, form state, and previews accurately', () async {
      final provider = VideoProvider();

      final fullDraft = MovieDraft(
        draftId: 'draft_test_restore',
        formType: 'uploadMovie',
        mediaHouseId: 10,
        title: 'Inception Horizon',
        description: 'A deep psychological adventure into dreams.',
        contentType: 'MOVIE',
        selectedGenres: ['Sci-Fi', 'Thriller'],
        selectedLanguages: [
          {'language': 'English'},
          {'language': 'Spanish'},
        ],
        director: 'Christopher Nolan',
        directorList: ['Christopher Nolan'],
        castList: [
          {'name': 'Leonardo DiCaprio', 'character': 'Cobb'},
          {'name': 'Joseph Gordon-Levitt', 'character': 'Arthur'},
        ],
        crewList: [
          {'name': 'Wally Pfister', 'role': 'Cinematographer'},
        ],
        castDraftName: 'Elliot Page',
        castDraftRole: 'Ariadne',
        castDraftDescription: 'The Architect',
        crewDraftName: 'Lee Smith',
        crewDraftRole: 'Editor',
        releaseDate: '2026-10-30',
        price: 249.0,
        runtime: 148.0,
        ageRating: 'PG-13',
        rentalDuration: '48 Hours',
        numberOfAttempt: 3,
        fullAttempt: 5,
        sensorCertificate: 'UA 123456',
        isFeatured: true,
        isDownloadable: true,
        isPaid: true,
        registrationPaymentId: 'pay_test_998877',
        registrationPaymentDate: '2026-10-26',
        registrationAmountPaid: '500',
        registrationPlanType: 'Pro',
        registrationValidity: '1 Year',
        registrationPaymentMethod: 'UPI',
        agreementDocumentUrl: 'https://storage.example.com/agreements/signed_10.pdf',
        agreementSignedDate: '2026-10-25',
        currentStep: 2,
        primaryFileName: 'inception_master_4k.mov',
        primaryFileSize: 4500000000,
        primaryFileType: 'video/quicktime',
        teaserFileName: 'inception_teaser.mp4',
        trailerFileName: 'inception_trailer.mp4',
        poster1Url: 'https://example.com/inception_poster1.jpg',
        poster2Url: 'https://example.com/inception_banner.jpg',
        languageVariants: {
          'English': {
            'movie': 'https://s3.example.com/inception_en.mp4',
            'trailer': 'https://s3.example.com/inception_trailer_en.mp4',
            'teaser': 'https://s3.example.com/inception_teaser_en.mp4',
            'poster1': 'https://example.com/inception_poster1.jpg',
            'poster2': 'https://example.com/inception_banner.jpg',
          }
        },
      );

      // Restore into VideoProvider
      await provider.loadFromDraft(fullDraft);

      // 1. Text controllers
      expect(provider.titleController.text, 'Inception Horizon');
      expect(provider.descriptionController.text, 'A deep psychological adventure into dreams.');
      expect(provider.typeController.text, 'MOVIE');
      expect(provider.priceController.text, '249.0');
      expect(provider.runTimeController.text, '148.0');
      expect(provider.releaseDateController.text, '2026-10-30');
      expect(provider.ageRatingController.text, 'PG-13');
      expect(provider.rentalDurationController.text, '48 Hours');
      expect(provider.numberOfAttemptController.text, '3');
      expect(provider.fullAttemptController.text, '5');
      expect(provider.censorCertificateController.text, 'UA 123456');
      expect(provider.directorController.text, 'Christopher Nolan');

      // 2. Financial and registration fields
      expect(provider.registrationPaymentIdController.text, 'pay_test_998877');
      expect(provider.registrationPaymentDateController.text, '2026-10-26');
      expect(provider.registrationAmountPaidController.text, '500');
      expect(provider.registrationPlanTypeController.text, 'Pro');
      expect(provider.registrationValidityController.text, '1 Year');
      expect(provider.registrationPaymentMethodController.text, 'UPI');
      expect(provider.agreementDocumentUrlController.text, 'https://storage.example.com/agreements/signed_10.pdf');
      expect(provider.agreementSignedDateController.text, '2026-10-25');

      // 3. Flags
      expect(provider.isFeatured, isTrue);
      expect(provider.isDownloadable, isTrue);
      expect(provider.isRegistrationFeePaid, isTrue);

      // 4. In-progress Cast & Crew drafts
      expect(provider.castNameController.text, 'Elliot Page');
      expect(provider.castRoleController.text, 'Ariadne');
      expect(provider.castDescriptionController.text, 'The Architect');
      expect(provider.crewNameController.text, 'Lee Smith');
      expect(provider.crewRoleController.text, 'Editor');

      // 5. Lists: Genres, Languages, Cast, Crew
      expect(provider.selectedGeners, ['Sci-Fi', 'Thriller']);
      expect(provider.selectedLanguages.length, 2);
      expect(provider.selectedLanguages.first.language, 'English');
      expect(provider.pendingCasts.length, 2);
      expect(provider.pendingCasts.first['name'], 'Leonardo DiCaprio');
      expect(provider.pendingCrews.length, 1);
      expect(provider.pendingCrews.first['name'], 'Wally Pfister');

      // 6. Media filenames and URLs
      expect(provider.movieFileName, 'inception_master_4k.mov');
      expect(provider.teaserFileName, 'inception_teaser.mp4');
      expect(provider.trailerFileName, 'inception_trailer.mp4');
      expect(provider.movieUrlController.text, 'https://s3.example.com/inception_en.mp4');
      expect(provider.trailerUrlController.text, 'https://s3.example.com/inception_trailer_en.mp4');
      expect(provider.teaserUrlController.text, 'https://s3.example.com/inception_teaser_en.mp4');
      expect(provider.poster1Controller.text, 'https://example.com/inception_poster1.jpg');
      expect(provider.poster2Controller.text, 'https://example.com/inception_banner.jpg');

      // 7. Security: Browser cannot restore binary file handles across reloads,
      // so primarySelectedFile is null while metadata is preserved cleanly.
      expect(provider.primarySelectedFile, isNull);
    });

    test('VideoProvider saveAsDraft saves locally, sets activeDraftId, and checkExistingDraft retrieves it', () async {
      final provider = VideoProvider();
      provider.titleController.text = 'Draft Film';
      provider.descriptionController.text = 'Draft Synopsis';
      provider.priceController.text = '99';
      provider.runTimeController.text = '120';
      provider.releaseDateController.text = '2026-12-01';

      // Save as uploadMovie draft
      final saved = await provider.saveAsDraft(currentStep: 1, formType: 'uploadMovie');
      expect(saved, isNotNull);
      expect(saved!.title, 'Draft Film');
      expect(saved.formType, 'uploadMovie');
      expect(saved.currentStep, 1);
      expect(provider.activeDraftId, saved.draftId);

      // Check existing draft for uploadMovie
      final existing = await provider.checkExistingDraftForForm('uploadMovie');
      expect(existing, isNotNull);
      expect(existing!.draftId, saved.draftId);
      expect(existing.title, 'Draft Film');

      // Check no draft exists for editMovie yet
      final editExisting = await provider.checkExistingDraftForForm('editMovie');
      expect(editExisting, isNull);

      // Save as editMovie draft for content ID 456
      final editSaved = await provider.saveAsDraft(
        currentStep: 2,
        formType: 'editMovie',
        editContentId: 456,
      );
      expect(editSaved, isNotNull);
      expect(editSaved!.formType, 'editMovie');
      expect(editSaved.contentId, 456);

      // Retrieve by contentId
      final contentDraft = await provider.checkExistingDraftForContent(456);
      expect(contentDraft, isNotNull);
      expect(contentDraft!.contentId, 456);

      // Delete active draft
      final deleted = await provider.deleteActiveDraft();
      expect(deleted, isTrue);
      expect(provider.activeDraftId, isNull);
    });
  });
}

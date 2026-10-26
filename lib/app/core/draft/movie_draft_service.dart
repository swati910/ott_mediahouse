import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../upload/multipart_upload_persistence.dart';
import 'local_draft_storage.dart';
import 'movie_draft.dart';

/// Draft management service operating purely on the frontend.
///
/// Strictly calls zero backend APIs.
class MovieDraftService {
  MovieDraftService._();

  /// Saves or updates a draft in local storage (IndexedDB).
  ///
  /// Zero backend API calls are made.
  static Future<MovieDraft> saveDraft(MovieDraft draft) async {
    return LocalDraftStorage.saveDraft(draft);
  }

  /// Retrieves all drafts belonging to a specific Production House.
  static Future<List<MovieDraft>> getDrafts(int mediaHouseId) async {
    return LocalDraftStorage.getAllDrafts(mediaHouseId: mediaHouseId);
  }

  /// Retrieves drafts filtered by formType (e.g. 'uploadMovie', 'editMovie', 'uploadTrailer', etc.)
  static Future<List<MovieDraft>> getDraftsByFormType(
    String formType, {
    int? mediaHouseId,
  }) async {
    return LocalDraftStorage.getDraftsByFormType(
      formType,
      mediaHouseId: mediaHouseId,
    );
  }

  /// Retrieves a specific draft by draftId.
  static Future<MovieDraft?> getDraft(
    String draftId, {
    int? mediaHouseId,
  }) async {
    return LocalDraftStorage.getDraft(draftId, mediaHouseId: mediaHouseId);
  }

  /// Retrieves a draft by existing contentId (for Edit Movie / Edit Content).
  static Future<MovieDraft?> getDraftByContentId(
    int contentId, {
    String? formType,
    int? mediaHouseId,
  }) async {
    return LocalDraftStorage.getDraftByContentId(
      contentId,
      formType: formType,
      mediaHouseId: mediaHouseId,
    );
  }

  /// Deletes a draft from local storage and cleans up any related multipart sessions.
  static Future<bool> deleteDraft(
    String draftId, {
    int? mediaHouseId,
  }) async {
    final success = await LocalDraftStorage.deleteDraft(
      draftId,
      mediaHouseId: mediaHouseId,
    );

    // Clean up associated multipart upload persistence
    MultipartUploadPersistence.removeSession('primary_$draftId');
    MultipartUploadPersistence.removeSession('teaser_$draftId');
    MultipartUploadPersistence.removeSession('trailer_$draftId');

    return success;
  }

  /// Clears all drafts matching a given formType.
  static Future<bool> clearDraftsForForm(
    String formType, {
    int? mediaHouseId,
  }) async {
    return LocalDraftStorage.clearDraftsForForm(
      formType,
      mediaHouseId: mediaHouseId,
    );
  }

  /// Clears all drafts for a given mediaHouseId.
  static Future<void> clearAllDrafts({int? mediaHouseId}) async {
    return LocalDraftStorage.clearAllDrafts(mediaHouseId: mediaHouseId);
  }
}

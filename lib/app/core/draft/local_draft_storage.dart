import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import '../storage/storage_keys.dart';
import 'movie_draft.dart';

/// Browser-based local draft storage service powered by IndexedDB.
///
/// Strictly operates on the frontend: DOES NOT call any backend API for
/// saving, updating, retrieving, or deleting drafts.
class LocalDraftStorage {
  LocalDraftStorage._();

  static const String _draftIndexPrefix = 'mh_drafts_index_';
  static const String _draftItemPrefix = 'mh_draft_item_';
  static const String _boxName = HiveBoxes.localDrafts;

  static Box<String>? _boxInstance;
  static bool _hiveAttempted = false;

  static String _indexKey(int mediaHouseId) => '$_draftIndexPrefix$mediaHouseId';
  static String _itemKey(int mediaHouseId, String draftId) =>
      '$_draftItemPrefix${mediaHouseId}_$draftId';

  static bool get _canUseHive {
    if (kIsWeb) return true;
    try {
      return (Hive as dynamic).homePath != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns open Hive box (which is stored in IndexedDB on Web).
  static Future<Box<String>?> _getBox() async {
    if (_boxInstance != null && _boxInstance!.isOpen) {
      return _boxInstance;
    }
    if (!_canUseHive) {
      return null;
    }
    try {
      if (Hive.isBoxOpen(_boxName)) {
        _boxInstance = Hive.box<String>(_boxName);
      } else {
        _boxInstance = await Hive.openBox<String>(_boxName);
      }
      return _boxInstance;
    } catch (e) {
      _hiveAttempted = true;
      debugPrint('[LocalDraftStorage] IndexedDB/Hive box fallback notice: $e');
      return null;
    }
  }

  /// Saves or updates a draft locally in IndexedDB (and lightweight metadata index).
  static Future<MovieDraft> saveDraft(MovieDraft draft) async {
    final updated = draft.copyWith(lastModified: DateTime.now());
    final jsonStr = jsonEncode(updated.toJson());
    final itemKey = _itemKey(updated.mediaHouseId, updated.draftId);
    final indexKey = _indexKey(updated.mediaHouseId);

    // 1. Primary persistence: IndexedDB via Hive box
    final box = await _getBox();
    if (box != null && box.isOpen) {
      try {
        await box.put(itemKey, jsonStr);
      } catch (e) {
        debugPrint('[LocalDraftStorage] Error writing to IndexedDB box: $e');
      }
    }

    // 2. Lightweight metadata & backup persistence: SharedPreferences + localStorage on Web
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(itemKey, jsonStr);

      final currentIds = prefs.getStringList(indexKey) ?? [];
      if (!currentIds.contains(updated.draftId)) {
        currentIds.insert(0, updated.draftId);
        await prefs.setStringList(indexKey, currentIds);
      }
    } catch (_) {}

    if (kIsWeb) {
      try {
        html.window.localStorage[itemKey] = jsonStr;
        final rawIndex = html.window.localStorage[indexKey];
        List<dynamic> ids = [];
        if (rawIndex != null && rawIndex.isNotEmpty) {
          try {
            ids = jsonDecode(rawIndex) as List<dynamic>;
          } catch (_) {}
        }
        if (!ids.contains(updated.draftId)) {
          ids.insert(0, updated.draftId);
          html.window.localStorage[indexKey] = jsonEncode(ids);
        }
      } catch (_) {}
    }

    return updated;
  }

  /// Retrieves a specific draft by draftId.
  static Future<MovieDraft?> getDraft(
    String draftId, {
    int? mediaHouseId,
  }) async {
    final box = await _getBox();
    int resolvedMediaHouseId = mediaHouseId ?? 0;

    // If mediaHouseId is not known, search keys
    if (resolvedMediaHouseId == 0) {
      if (box != null && box.isOpen) {
        for (final key in box.keys) {
          final k = key.toString();
          if (k.startsWith(_draftItemPrefix) && k.endsWith('_$draftId')) {
            final remainder = k.substring(_draftItemPrefix.length);
            final underscore = remainder.indexOf('_');
            if (underscore != -1) {
              resolvedMediaHouseId =
                  int.tryParse(remainder.substring(0, underscore)) ?? 0;
              break;
            }
          }
        }
      }

      if (resolvedMediaHouseId == 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          for (final k in prefs.getKeys()) {
            if (k.startsWith(_draftItemPrefix) && k.endsWith('_$draftId')) {
              final remainder = k.substring(_draftItemPrefix.length);
              final underscore = remainder.indexOf('_');
              if (underscore != -1) {
                resolvedMediaHouseId =
                    int.tryParse(remainder.substring(0, underscore)) ?? 0;
                break;
              }
            }
          }
        } catch (_) {}
      }
    }

    final itemKey = _itemKey(resolvedMediaHouseId, draftId);

    // Try IndexedDB first
    if (box != null && box.isOpen) {
      final val = box.get(itemKey);
      if (val != null && val.isNotEmpty) {
        try {
          return MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
        } catch (_) {}
      }
    }

    // Try SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(itemKey);
      if (val != null && val.isNotEmpty) {
        return MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
      }
    } catch (_) {}

    // Try Web localStorage fallback
    if (kIsWeb) {
      try {
        final val = html.window.localStorage[itemKey];
        if (val != null && val.isNotEmpty) {
          return MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    return null;
  }

  /// Retrieves all drafts for a mediaHouseId, sorted newest first.
  static Future<List<MovieDraft>> getAllDrafts({int? mediaHouseId}) async {
    final drafts = <MovieDraft>[];
    final box = await _getBox();
    final mId = mediaHouseId ?? 0;

    final seenIds = <String>{};

    // 1. Read from IndexedDB box
    if (box != null && box.isOpen) {
      for (final key in box.keys) {
        final k = key.toString();
        if (k.startsWith(_draftItemPrefix)) {
          if (mId > 0 && !k.startsWith('$_draftItemPrefix${mId}_')) {
            continue;
          }
          final val = box.get(k);
          if (val != null && val.isNotEmpty) {
            try {
              final draft = MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
              if (mId == 0 || draft.mediaHouseId == mId) {
                if (seenIds.add(draft.draftId)) {
                  drafts.add(draft);
                }
              }
            } catch (_) {}
          }
        }
      }
    }

    // 2. Check SharedPreferences if empty or for any additional drafts
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexKey = _indexKey(mId);
      final draftIds = prefs.getStringList(indexKey) ?? [];

      for (final id in draftIds) {
        if (!seenIds.contains(id)) {
          final itemKey = _itemKey(mId, id);
          final val = prefs.getString(itemKey);
          if (val != null && val.isNotEmpty) {
            try {
              final draft = MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
              if (seenIds.add(draft.draftId)) {
                drafts.add(draft);
              }
            } catch (_) {}
          }
        }
      }

      // Check all keys if mId == 0
      if (mId == 0) {
        for (final k in prefs.getKeys()) {
          if (k.startsWith(_draftItemPrefix)) {
            final val = prefs.getString(k);
            if (val != null && val.isNotEmpty) {
              try {
                final draft = MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
                if (seenIds.add(draft.draftId)) {
                  drafts.add(draft);
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    // 3. Fallback on Web localStorage
    if (kIsWeb && drafts.isEmpty) {
      try {
        final indexKey = _indexKey(mId);
        final raw = html.window.localStorage[indexKey];
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            for (final id in decoded) {
              final itemKey = _itemKey(mId, id.toString());
              final val = html.window.localStorage[itemKey];
              if (val != null && val.isNotEmpty) {
                try {
                  final draft = MovieDraft.fromJson(jsonDecode(val) as Map<String, dynamic>);
                  if (seenIds.add(draft.draftId)) {
                    drafts.add(draft);
                  }
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }

    drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return drafts;
  }

  /// Retrieves drafts filtered by formType (e.g. 'uploadMovie', 'editMovie', 'uploadTrailer', etc.)
  static Future<List<MovieDraft>> getDraftsByFormType(
    String formType, {
    int? mediaHouseId,
  }) async {
    final all = await getAllDrafts(mediaHouseId: mediaHouseId);
    return all.where((d) => d.formType.toLowerCase() == formType.toLowerCase()).toList();
  }

  /// Retrieves a draft associated with a specific contentId (for Edit Content / Edit Movie).
  static Future<MovieDraft?> getDraftByContentId(
    int contentId, {
    String? formType,
    int? mediaHouseId,
  }) async {
    final all = await getAllDrafts(mediaHouseId: mediaHouseId);
    for (final d in all) {
      if (d.contentId == contentId) {
        if (formType == null || d.formType.toLowerCase() == formType.toLowerCase()) {
          return d;
        }
      }
    }
    return null;
  }

  /// Deletes a specific draft locally.
  static Future<bool> deleteDraft(
    String draftId, {
    int? mediaHouseId,
  }) async {
    final box = await _getBox();
    int resolvedMediaHouseId = mediaHouseId ?? 0;

    if (resolvedMediaHouseId == 0) {
      if (box != null && box.isOpen) {
        for (final key in box.keys) {
          final k = key.toString();
          if (k.startsWith(_draftItemPrefix) && k.endsWith('_$draftId')) {
            final remainder = k.substring(_draftItemPrefix.length);
            final underscore = remainder.indexOf('_');
            if (underscore != -1) {
              resolvedMediaHouseId =
                  int.tryParse(remainder.substring(0, underscore)) ?? 0;
              break;
            }
          }
        }
      }
      if (resolvedMediaHouseId == 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          for (final k in prefs.getKeys()) {
            if (k.startsWith(_draftItemPrefix) && k.endsWith('_$draftId')) {
              final remainder = k.substring(_draftItemPrefix.length);
              final underscore = remainder.indexOf('_');
              if (underscore != -1) {
                resolvedMediaHouseId =
                    int.tryParse(remainder.substring(0, underscore)) ?? 0;
                break;
              }
            }
          }
        } catch (_) {}
      }
    }

    final itemKey = _itemKey(resolvedMediaHouseId, draftId);
    final indexKey = _indexKey(resolvedMediaHouseId);

    // Remove from IndexedDB box
    if (box != null && box.isOpen) {
      try {
        await box.delete(itemKey);
      } catch (_) {}
    }

    // Remove from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(itemKey);
      final currentIds = prefs.getStringList(indexKey) ?? [];
      currentIds.remove(draftId);
      await prefs.setStringList(indexKey, currentIds);
    } catch (_) {}

    // Remove from Web localStorage
    if (kIsWeb) {
      try {
        html.window.localStorage.remove(itemKey);
        final raw = html.window.localStorage[indexKey];
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            decoded.remove(draftId);
            html.window.localStorage[indexKey] = jsonEncode(decoded);
          }
        }
      } catch (_) {}
    }

    return true;
  }

  /// Clears all drafts matching a given formType.
  static Future<bool> clearDraftsForForm(
    String formType, {
    int? mediaHouseId,
  }) async {
    final drafts = await getDraftsByFormType(formType, mediaHouseId: mediaHouseId);
    for (final d in drafts) {
      await deleteDraft(d.draftId, mediaHouseId: d.mediaHouseId);
    }
    return true;
  }

  /// Clears all drafts for a mediaHouseId.
  static Future<void> clearAllDrafts({int? mediaHouseId}) async {
    final drafts = await getAllDrafts(mediaHouseId: mediaHouseId);
    for (final d in drafts) {
      await deleteDraft(d.draftId, mediaHouseId: d.mediaHouseId);
    }
  }
}

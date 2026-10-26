import 'dart:convert';

class MediaVariantDraft {
  final String fileName;
  final int fileSize;
  final String? uploadId;
  final List<int> completedParts;
  final Map<String, String> partEtags;
  final String uploadStatus;
  final String? failureReason;

  MediaVariantDraft({
    this.fileName = '',
    this.fileSize = 0,
    this.uploadId,
    this.completedParts = const [],
    this.partEtags = const {},
    this.uploadStatus = 'DRAFT',
    this.failureReason,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fileSize': fileSize,
        'uploadId': uploadId,
        'completedParts': completedParts,
        'partEtags': partEtags,
        'uploadStatus': uploadStatus,
        'failureReason': failureReason,
      };

  factory MediaVariantDraft.fromJson(Map<String, dynamic> json) =>
      MediaVariantDraft(
        fileName: json['fileName']?.toString() ?? '',
        fileSize: int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
        uploadId: json['uploadId']?.toString(),
        completedParts: (json['completedParts'] as List<dynamic>?)
                ?.map((e) => int.tryParse(e.toString()) ?? 0)
                .toList() ??
            const [],
        partEtags: (json['partEtags'] as Map<dynamic, dynamic>?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
        uploadStatus: json['uploadStatus']?.toString() ?? 'idle',
        failureReason: json['failureReason']?.toString(),
      );
}

class MovieDraft {
  final String draftId;
  final String formType; // uploadMovie, editMovie, uploadShortFilm, uploadSeries, uploadTrailer, uploadTeaser
  final int mediaHouseId;
  final String userId;
  final String title;
  final String description;
  final String synopsis;
  final String contentType; // MOVIE, SHORT_FILM, SERIES
  final List<String> selectedGenres;
  final List<Map<String, dynamic>> selectedLanguages;
  final List<Map<String, dynamic>> castList;
  final List<Map<String, dynamic>> crewList;
  final List<String> directorList;
  final String director;
  final String producer;
  final String writer;
  final String releaseDate;
  final double price;
  final double runtime;
  final String ageRating;
  final String rentalDuration;
  final int numberOfAttempt;
  final int fullAttempt;
  final String sensorCertificate;
  final bool isFeatured;
  final bool isDownloadable;
  final bool isPaid;
  final String registrationFeePaid;
  final String registrationFeeDetails;
  final String registrationPaymentId;
  final String registrationPaymentDate;
  final String registrationAmountPaid;
  final String registrationPlanType;
  final String registrationValidity;
  final String registrationPaymentMethod;
  final String agreementDocumentUrl;
  final String agreementSignedDate;
  final int currentStep;
  final DateTime lastModified;
  final int? contentId;
  final String uploadStatus;
  final double uploadProgress;
  final String? uploadErrorMessage;

  // Language variants (language -> {field: value})
  final Map<String, Map<String, String>> languageVariants;
  final List<String> selectedAudioFormat;
  final List<String> selectedSubLanguages;

  // Multipart upload resumption state
  final String? primaryUploadTaskId;
  final dynamic primaryUploadSessionId;
  final String? primaryUploadId;
  final String? primaryS3Key;
  final int? primaryPartSize;
  final int? primaryTotalParts;
  final Map<int, String>? primaryCompletedETags;

  // File metadata (browser-safe, no binary bloat)
  final String? primaryFileName;
  final int? primaryFileSize;
  final String? primaryFileType;
  final int? primaryFileLastModified;

  final String? teaserFileName;
  final int? teaserFileSize;
  final String? teaserFileType;
  final int? teaserFileLastModified;

  final String? trailerFileName;
  final int? trailerFileSize;
  final String? trailerFileType;
  final int? trailerFileLastModified;

  final String? poster1FileName;
  final String? poster2FileName;
  final String? poster3FileName;
  final String? poster1Url;
  final String? poster2Url;
  final String? poster3Url;

  // In-progress cast & crew unsubmitted drafts
  final String? castDraftName;
  final String? castDraftRole;
  final String? castDraftDescription;
  final String? castDraftImage;
  final String? crewDraftName;
  final String? crewDraftRole;
  final String? crewDraftImage;

  MovieDraft({
    String? draftId,
    String? id,
    String? formType,
    required this.mediaHouseId,
    dynamic userId,
    dynamic createdUserId,
    this.title = '',
    this.description = '',
    this.synopsis = '',
    this.contentType = 'MOVIE',
    List<String>? selectedGenres,
    String? genre,
    String? category,
    this.selectedLanguages = const [],
    List<Map<String, dynamic>>? castList,
    List<Map<String, dynamic>>? crewList,
    List<Map<String, dynamic>>? castDetails,
    List<Map<String, dynamic>>? crewDetails,
    List<String>? directorList,
    String? director,
    this.producer = '',
    this.writer = '',
    this.releaseDate = '',
    this.price = 0.0,
    double? runtime,
    String? duration,
    this.ageRating = '',
    this.rentalDuration = '',
    this.numberOfAttempt = 0,
    this.fullAttempt = 0,
    this.sensorCertificate = '',
    this.isFeatured = false,
    this.isDownloadable = true,
    this.isPaid = false,
    this.registrationFeePaid = 'N',
    this.registrationFeeDetails = '',
    this.registrationPaymentId = '',
    this.registrationPaymentDate = '',
    this.registrationAmountPaid = '',
    this.registrationPlanType = '',
    this.registrationValidity = '',
    this.registrationPaymentMethod = '',
    this.agreementDocumentUrl = '',
    this.agreementSignedDate = '',
    this.currentStep = 0,
    DateTime? lastModified,
    this.contentId,
    this.uploadStatus = 'DRAFT',
    this.uploadProgress = 0.0,
    String? uploadErrorMessage,
    Map<String, Map<String, String>>? languageVariants,
    this.selectedAudioFormat = const [],
    this.selectedSubLanguages = const [],
    this.primaryUploadTaskId,
    this.primaryUploadSessionId,
    String? primaryUploadId,
    this.primaryS3Key,
    this.primaryPartSize,
    this.primaryTotalParts,
    Map<int, String>? primaryCompletedETags,
    String? primaryFileName,
    int? primaryFileSize,
    this.primaryFileType,
    this.primaryFileLastModified,
    String? teaserFileName,
    int? teaserFileSize,
    this.teaserFileType,
    this.teaserFileLastModified,
    this.trailerFileName,
    this.trailerFileSize,
    this.trailerFileType,
    this.trailerFileLastModified,
    this.poster1FileName,
    this.poster2FileName,
    this.poster3FileName,
    this.poster1Url,
    this.poster2Url,
    this.poster3Url,
    this.castDraftName,
    this.castDraftRole,
    this.castDraftDescription,
    this.castDraftImage,
    this.crewDraftName,
    this.crewDraftRole,
    this.crewDraftImage,
    MediaVariantDraft? mainVideoMetadata,
    MediaVariantDraft? teaserMetadata,
    MediaVariantDraft? trailerMetadata,
    String? posterUrl,
    String? bannerUrl,
    String? language,
  })  : draftId = id ?? draftId ?? '',
        formType = formType ??
            (contentId != null && contentId > 0 ? 'editMovie' : 'uploadMovie'),
        userId = userId?.toString() ?? createdUserId?.toString() ?? '',
        selectedGenres = selectedGenres ??
            (genre != null && genre.isNotEmpty
                ? [genre]
                : (category != null && category.isNotEmpty
                    ? [category]
                    : const [])),
        castList = castList ?? castDetails ?? const [],
        crewList = crewList ?? crewDetails ?? const [],
        directorList = directorList ??
            (director != null && director.isNotEmpty ? [director] : const []),
        director = director ??
            (directorList != null && directorList.isNotEmpty
                ? directorList.first
                : ''),
        runtime = runtime ??
            (duration != null
                ? (double.tryParse(
                        duration.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                    0.0)
                : 0.0),
        lastModified = lastModified ?? DateTime.now(),
        primaryFileName = primaryFileName ?? mainVideoMetadata?.fileName,
        primaryFileSize = primaryFileSize ?? mainVideoMetadata?.fileSize,
        primaryUploadId = primaryUploadId ?? mainVideoMetadata?.uploadId,
        primaryCompletedETags = primaryCompletedETags ??
            (mainVideoMetadata?.partEtags != null
                ? mainVideoMetadata!.partEtags.map((k, v) =>
                    MapEntry(int.tryParse(k.toString()) ?? 0, v.toString()))
                : null),
        teaserFileName = teaserFileName ?? teaserMetadata?.fileName,
        teaserFileSize = teaserFileSize ?? teaserMetadata?.fileSize,
        uploadErrorMessage =
            uploadErrorMessage ?? mainVideoMetadata?.failureReason,
        languageVariants = _buildVariants(
          languageVariants,
          posterUrl,
          bannerUrl,
          language,
        );

  static Map<String, Map<String, String>> _buildVariants(
    Map<String, Map<String, String>>? existing,
    String? posterUrl,
    String? bannerUrl,
    String? language,
  ) {
    final result = <String, Map<String, String>>{};
    if (existing != null) {
      existing.forEach((k, v) {
        result[k] = Map<String, String>.from(v);
      });
    }
    if (posterUrl != null || bannerUrl != null) {
      final langKey = (language != null && language.isNotEmpty) ? language : 'Default';
      final current = Map<String, String>.from(result[langKey] ?? {});
      if (posterUrl != null) current['posterUrl'] = posterUrl;
      if (bannerUrl != null) current['bannerUrl'] = bannerUrl;
      result[langKey] = current;
    }
    return result;
  }

  /// Generates a standardized draft ID isolated by formType, mediaHouseId, and contentId.
  static String generateDraftId({
    required String formType,
    required int mediaHouseId,
    int? contentId,
  }) {
    if (contentId != null && contentId > 0) {
      return 'draft_${formType}_${mediaHouseId}_$contentId';
    }
    return 'draft_${formType}_${mediaHouseId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Convenience getters
  String get id => draftId;
  bool get isEdit => (contentId != null && contentId! > 0) || formType.startsWith('edit');
  String get genre => selectedGenres.isNotEmpty ? selectedGenres.first : '';
  List<Map<String, dynamic>> get castDetails => castList;
  List<Map<String, dynamic>> get crewDetails => crewList;
  int? get createdUserId => int.tryParse(userId);

  String? get posterUrl {
    if (poster1Url != null && poster1Url!.isNotEmpty) return poster1Url;
    for (final variant in languageVariants.values) {
      final url = variant['posterUrl'] ?? variant['poster1'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? get bannerUrl {
    for (final variant in languageVariants.values) {
      final url = variant['bannerUrl'] ?? variant['poster2'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? get movieUrl {
    for (final variant in languageVariants.values) {
      final url = variant['movie'] ?? variant['video'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? get teaserUrl {
    for (final variant in languageVariants.values) {
      final url = variant['teaser'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? get trailerUrl {
    for (final variant in languageVariants.values) {
      final url = variant['trailer'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  MediaVariantDraft? get mainVideoMetadata {
    if (primaryFileName == null &&
        primaryUploadId == null &&
        (primaryFileSize == null || primaryFileSize == 0)) {
      return null;
    }
    return MediaVariantDraft(
      fileName: primaryFileName ?? '',
      fileSize: primaryFileSize ?? 0,
      uploadId: primaryUploadId,
      completedParts: primaryCompletedETags?.keys.toList() ?? [],
      partEtags: primaryCompletedETags
              ?.map((k, v) => MapEntry(k.toString(), v)) ??
          {},
      uploadStatus: uploadStatus,
      failureReason: uploadErrorMessage,
    );
  }

  MediaVariantDraft? get teaserMetadata {
    if (teaserFileName == null && (teaserFileSize == null || teaserFileSize == 0)) {
      return null;
    }
    return MediaVariantDraft(
      fileName: teaserFileName ?? '',
      fileSize: teaserFileSize ?? 0,
      uploadStatus: uploadStatus,
    );
  }

  MediaVariantDraft? get trailerMetadata {
    if (trailerFileName == null && (trailerFileSize == null || trailerFileSize == 0)) {
      return null;
    }
    return MediaVariantDraft(
      fileName: trailerFileName ?? '',
      fileSize: trailerFileSize ?? 0,
      uploadStatus: uploadStatus,
    );
  }

  MovieDraft copyWith({
    String? draftId,
    String? id,
    String? formType,
    int? mediaHouseId,
    String? userId,
    String? title,
    String? description,
    String? synopsis,
    String? contentType,
    List<String>? selectedGenres,
    List<Map<String, dynamic>>? selectedLanguages,
    List<Map<String, dynamic>>? castList,
    List<Map<String, dynamic>>? crewList,
    List<String>? directorList,
    String? director,
    String? producer,
    String? writer,
    String? releaseDate,
    double? price,
    double? runtime,
    String? ageRating,
    String? rentalDuration,
    int? numberOfAttempt,
    int? fullAttempt,
    String? sensorCertificate,
    bool? isFeatured,
    bool? isDownloadable,
    bool? isPaid,
    String? registrationFeePaid,
    String? registrationFeeDetails,
    String? registrationPaymentId,
    String? registrationPaymentDate,
    String? registrationAmountPaid,
    String? registrationPlanType,
    String? registrationValidity,
    String? registrationPaymentMethod,
    String? agreementDocumentUrl,
    String? agreementSignedDate,
    int? currentStep,
    DateTime? lastModified,
    int? contentId,
    String? uploadStatus,
    double? uploadProgress,
    String? uploadErrorMessage,
    Map<String, Map<String, String>>? languageVariants,
    List<String>? selectedAudioFormat,
    List<String>? selectedSubLanguages,
    String? primaryUploadTaskId,
    dynamic primaryUploadSessionId,
    String? primaryUploadId,
    String? primaryS3Key,
    int? primaryPartSize,
    int? primaryTotalParts,
    Map<int, String>? primaryCompletedETags,
    String? primaryFileName,
    int? primaryFileSize,
    String? primaryFileType,
    int? primaryFileLastModified,
    String? teaserFileName,
    int? teaserFileSize,
    String? teaserFileType,
    int? teaserFileLastModified,
    String? trailerFileName,
    int? trailerFileSize,
    String? trailerFileType,
    int? trailerFileLastModified,
    String? poster1FileName,
    String? poster2FileName,
    String? poster3FileName,
    String? poster1Url,
    String? poster2Url,
    String? poster3Url,
    String? castDraftName,
    String? castDraftRole,
    String? castDraftDescription,
    String? castDraftImage,
    String? crewDraftName,
    String? crewDraftRole,
    String? crewDraftImage,
  }) {
    return MovieDraft(
      draftId: id ?? draftId ?? this.draftId,
      formType: formType ?? this.formType,
      mediaHouseId: mediaHouseId ?? this.mediaHouseId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      synopsis: synopsis ?? this.synopsis,
      contentType: contentType ?? this.contentType,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      castList: castList ?? this.castList,
      crewList: crewList ?? this.crewList,
      directorList: directorList ?? this.directorList,
      director: director ?? this.director,
      producer: producer ?? this.producer,
      writer: writer ?? this.writer,
      releaseDate: releaseDate ?? this.releaseDate,
      price: price ?? this.price,
      runtime: runtime ?? this.runtime,
      ageRating: ageRating ?? this.ageRating,
      rentalDuration: rentalDuration ?? this.rentalDuration,
      numberOfAttempt: numberOfAttempt ?? this.numberOfAttempt,
      fullAttempt: fullAttempt ?? this.fullAttempt,
      sensorCertificate: sensorCertificate ?? this.sensorCertificate,
      isFeatured: isFeatured ?? this.isFeatured,
      isDownloadable: isDownloadable ?? this.isDownloadable,
      isPaid: isPaid ?? this.isPaid,
      registrationFeePaid: registrationFeePaid ?? this.registrationFeePaid,
      registrationFeeDetails:
          registrationFeeDetails ?? this.registrationFeeDetails,
      registrationPaymentId:
          registrationPaymentId ?? this.registrationPaymentId,
      registrationPaymentDate:
          registrationPaymentDate ?? this.registrationPaymentDate,
      registrationAmountPaid:
          registrationAmountPaid ?? this.registrationAmountPaid,
      registrationPlanType: registrationPlanType ?? this.registrationPlanType,
      registrationValidity: registrationValidity ?? this.registrationValidity,
      registrationPaymentMethod:
          registrationPaymentMethod ?? this.registrationPaymentMethod,
      agreementDocumentUrl: agreementDocumentUrl ?? this.agreementDocumentUrl,
      agreementSignedDate: agreementSignedDate ?? this.agreementSignedDate,
      currentStep: currentStep ?? this.currentStep,
      lastModified: lastModified ?? this.lastModified,
      contentId: contentId ?? this.contentId,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadErrorMessage: uploadErrorMessage ?? this.uploadErrorMessage,
      languageVariants: languageVariants ?? this.languageVariants,
      selectedAudioFormat: selectedAudioFormat ?? this.selectedAudioFormat,
      selectedSubLanguages: selectedSubLanguages ?? this.selectedSubLanguages,
      primaryUploadTaskId: primaryUploadTaskId ?? this.primaryUploadTaskId,
      primaryUploadSessionId:
          primaryUploadSessionId ?? this.primaryUploadSessionId,
      primaryUploadId: primaryUploadId ?? this.primaryUploadId,
      primaryS3Key: primaryS3Key ?? this.primaryS3Key,
      primaryPartSize: primaryPartSize ?? this.primaryPartSize,
      primaryTotalParts: primaryTotalParts ?? this.primaryTotalParts,
      primaryCompletedETags:
          primaryCompletedETags ?? this.primaryCompletedETags,
      primaryFileName: primaryFileName ?? this.primaryFileName,
      primaryFileSize: primaryFileSize ?? this.primaryFileSize,
      primaryFileType: primaryFileType ?? this.primaryFileType,
      primaryFileLastModified:
          primaryFileLastModified ?? this.primaryFileLastModified,
      teaserFileName: teaserFileName ?? this.teaserFileName,
      teaserFileSize: teaserFileSize ?? this.teaserFileSize,
      teaserFileType: teaserFileType ?? this.teaserFileType,
      teaserFileLastModified:
          teaserFileLastModified ?? this.teaserFileLastModified,
      trailerFileName: trailerFileName ?? this.trailerFileName,
      trailerFileSize: trailerFileSize ?? this.trailerFileSize,
      trailerFileType: trailerFileType ?? this.trailerFileType,
      trailerFileLastModified:
          trailerFileLastModified ?? this.trailerFileLastModified,
      poster1FileName: poster1FileName ?? this.poster1FileName,
      poster2FileName: poster2FileName ?? this.poster2FileName,
      poster3FileName: poster3FileName ?? this.poster3FileName,
      poster1Url: poster1Url ?? this.poster1Url,
      poster2Url: poster2Url ?? this.poster2Url,
      poster3Url: poster3Url ?? this.poster3Url,
      castDraftName: castDraftName ?? this.castDraftName,
      castDraftRole: castDraftRole ?? this.castDraftRole,
      castDraftDescription: castDraftDescription ?? this.castDraftDescription,
      castDraftImage: castDraftImage ?? this.castDraftImage,
      crewDraftName: crewDraftName ?? this.crewDraftName,
      crewDraftRole: crewDraftRole ?? this.crewDraftRole,
      crewDraftImage: crewDraftImage ?? this.crewDraftImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': draftId,
      'draftId': draftId,
      'formType': formType,
      'mediaHouseId': mediaHouseId,
      'userId': userId,
      'title': title,
      'description': description,
      'synopsis': synopsis,
      'contentType': contentType,
      'genre': genre,
      'selectedGenres': selectedGenres,
      'selectedLanguages': selectedLanguages,
      'castList': castList,
      'crewList': crewList,
      'castDetails': castList,
      'crewDetails': crewList,
      'directorList': directorList,
      'director': director,
      'producer': producer,
      'writer': writer,
      'releaseDate': releaseDate,
      'price': price,
      'runtime': runtime,
      'ageRating': ageRating,
      'rentalDuration': rentalDuration,
      'numberOfAttempt': numberOfAttempt,
      'fullAttempt': fullAttempt,
      'sensorCertificate': sensorCertificate,
      'isFeatured': isFeatured,
      'isDownloadable': isDownloadable,
      'isPaid': isPaid,
      'registrationFeePaid': registrationFeePaid,
      'registrationFeeDetails': registrationFeeDetails,
      'registrationPaymentId': registrationPaymentId,
      'registrationPaymentDate': registrationPaymentDate,
      'registrationAmountPaid': registrationAmountPaid,
      'registrationPlanType': registrationPlanType,
      'registrationValidity': registrationValidity,
      'registrationPaymentMethod': registrationPaymentMethod,
      'agreementDocumentUrl': agreementDocumentUrl,
      'agreementSignedDate': agreementSignedDate,
      'currentStep': currentStep,
      'lastModified': lastModified.toIso8601String(),
      'contentId': contentId,
      'uploadStatus': uploadStatus,
      'uploadProgress': uploadProgress,
      'uploadErrorMessage': uploadErrorMessage,
      'languageVariants': languageVariants,
      'selectedAudioFormat': selectedAudioFormat,
      'selectedSubLanguages': selectedSubLanguages,
      'primaryUploadTaskId': primaryUploadTaskId,
      'primaryUploadSessionId': primaryUploadSessionId,
      'primaryUploadId': primaryUploadId,
      'primaryS3Key': primaryS3Key,
      'primaryPartSize': primaryPartSize,
      'primaryTotalParts': primaryTotalParts,
      'primaryCompletedETags': primaryCompletedETags?.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'primaryFileName': primaryFileName,
      'primaryFileSize': primaryFileSize,
      'primaryFileType': primaryFileType,
      'primaryFileLastModified': primaryFileLastModified,
      'teaserFileName': teaserFileName,
      'teaserFileSize': teaserFileSize,
      'teaserFileType': teaserFileType,
      'teaserFileLastModified': teaserFileLastModified,
      'trailerFileName': trailerFileName,
      'trailerFileSize': trailerFileSize,
      'trailerFileType': trailerFileType,
      'trailerFileLastModified': trailerFileLastModified,
      'poster1FileName': poster1FileName,
      'poster2FileName': poster2FileName,
      'poster3FileName': poster3FileName,
      'poster1Url': poster1Url,
      'poster2Url': poster2Url,
      'poster3Url': poster3Url,
      'posterUrl': posterUrl,
      'bannerUrl': bannerUrl,
      'castDraftName': castDraftName,
      'castDraftRole': castDraftRole,
      'castDraftDescription': castDraftDescription,
      'castDraftImage': castDraftImage,
      'crewDraftName': crewDraftName,
      'crewDraftRole': crewDraftRole,
      'crewDraftImage': crewDraftImage,
      if (mainVideoMetadata != null)
        'mainVideoMetadata': mainVideoMetadata!.toJson(),
      if (teaserMetadata != null) 'teaserMetadata': teaserMetadata!.toJson(),
      if (trailerMetadata != null) 'trailerMetadata': trailerMetadata!.toJson(),
    };
  }

  factory MovieDraft.fromJson(Map<String, dynamic> json) {
    Map<int, String>? parsedETags;
    if (json['primaryCompletedETags'] != null) {
      final raw = json['primaryCompletedETags'] as Map<String, dynamic>;
      parsedETags = {};
      raw.forEach((k, v) {
        final p = int.tryParse(k);
        if (p != null) parsedETags![p] = v.toString();
      });
    }

    Map<String, Map<String, String>> parsedVariants = {};
    if (json['languageVariants'] != null) {
      final raw = json['languageVariants'] as Map<String, dynamic>;
      raw.forEach((lang, fields) {
        if (fields is Map) {
          final fieldMap = <String, String>{};
          fields.forEach((k, v) {
            fieldMap[k.toString()] = (v ?? '').toString();
          });
          parsedVariants[lang] = fieldMap;
        }
      });
    }

    // Handle posterUrl / bannerUrl from json if present
    final jsonPoster = json['posterUrl']?.toString();
    final jsonBanner = json['bannerUrl']?.toString();
    if (jsonPoster != null || jsonBanner != null) {
      final defaultVariant = Map<String, String>.from(parsedVariants['Default'] ?? {});
      if (jsonPoster != null) defaultVariant['posterUrl'] = jsonPoster;
      if (jsonBanner != null) defaultVariant['bannerUrl'] = jsonBanner;
      parsedVariants['Default'] = defaultVariant;
    }

    MediaVariantDraft? parsedMainMedia;
    if (json['mainVideoMetadata'] != null && json['mainVideoMetadata'] is Map) {
      parsedMainMedia = MediaVariantDraft.fromJson(
          Map<String, dynamic>.from(json['mainVideoMetadata'] as Map));
      if (parsedETags == null && parsedMainMedia.partEtags.isNotEmpty) {
        parsedETags = {};
        parsedMainMedia.partEtags.forEach((k, v) {
          final p = int.tryParse(k);
          if (p != null) parsedETags![p] = v;
        });
      }
    }

    MediaVariantDraft? parsedTeaserMedia;
    if (json['teaserMetadata'] != null && json['teaserMetadata'] is Map) {
      parsedTeaserMedia = MediaVariantDraft.fromJson(
          Map<String, dynamic>.from(json['teaserMetadata'] as Map));
    }

    MediaVariantDraft? parsedTrailerMedia;
    if (json['trailerMetadata'] != null && json['trailerMetadata'] is Map) {
      parsedTrailerMedia = MediaVariantDraft.fromJson(
          Map<String, dynamic>.from(json['trailerMetadata'] as Map));
    }

    final rawGenres = (json['selectedGenres'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (json['genre'] != null ? [json['genre'].toString()] : const <String>[]);

    final rawCast = (json['castList'] as List<dynamic>?)
            ?.map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList() ??
        (json['castDetails'] as List<dynamic>?)
            ?.map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];

    final rawCrew = (json['crewList'] as List<dynamic>?)
            ?.map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList() ??
        (json['crewDetails'] as List<dynamic>?)
            ?.map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];

    final contentId = json['contentId'] != null
        ? int.tryParse(json['contentId'].toString())
        : null;

    final formType = json['formType']?.toString() ??
        (contentId != null && contentId > 0 ? 'editMovie' : 'uploadMovie');

    return MovieDraft(
      draftId: json['id']?.toString() ?? json['draftId']?.toString() ?? '',
      formType: formType,
      mediaHouseId: int.tryParse(json['mediaHouseId']?.toString() ?? '0') ?? 0,
      userId: json['userId']?.toString() ?? json['createdUserId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      synopsis: json['synopsis']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? 'MOVIE',
      selectedGenres: rawGenres,
      selectedLanguages: (json['selectedLanguages'] as List<dynamic>?)
              ?.map((e) => e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      castList: rawCast,
      crewList: rawCrew,
      directorList: (json['directorList'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['director'] != null ? [json['director'].toString()] : const []),
      director: json['director']?.toString() ?? '',
      producer: json['producer']?.toString() ?? '',
      writer: json['writer']?.toString() ?? '',
      releaseDate: json['releaseDate']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      runtime: double.tryParse(json['runtime']?.toString() ?? '0') ?? 0.0,
      ageRating: json['ageRating']?.toString() ?? '',
      rentalDuration: json['rentalDuration']?.toString() ?? '',
      numberOfAttempt:
          int.tryParse(json['numberOfAttempt']?.toString() ?? '0') ?? 0,
      fullAttempt: int.tryParse(json['fullAttempt']?.toString() ?? '0') ?? 0,
      sensorCertificate: json['sensorCertificate']?.toString() ?? '',
      isFeatured: json['isFeatured'] == true,
      isDownloadable: json['isDownloadable'] ?? true,
      isPaid: json['isPaid'] == true,
      registrationFeePaid: json['registrationFeePaid']?.toString() ?? 'N',
      registrationFeeDetails:
          json['registrationFeeDetails']?.toString() ?? '',
      registrationPaymentId: json['registrationPaymentId']?.toString() ?? '',
      registrationPaymentDate:
          json['registrationPaymentDate']?.toString() ?? '',
      registrationAmountPaid: json['registrationAmountPaid']?.toString() ?? '',
      registrationPlanType: json['registrationPlanType']?.toString() ?? '',
      registrationValidity: json['registrationValidity']?.toString() ?? '',
      registrationPaymentMethod:
          json['registrationPaymentMethod']?.toString() ?? '',
      agreementDocumentUrl: json['agreementDocumentUrl']?.toString() ?? '',
      agreementSignedDate: json['agreementSignedDate']?.toString() ?? '',
      currentStep: int.tryParse(json['currentStep']?.toString() ?? '0') ?? 0,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'].toString()) ?? DateTime.now()
          : DateTime.now(),
      contentId: contentId,
      uploadStatus: json['uploadStatus']?.toString() ?? 'DRAFT',
      uploadProgress:
          double.tryParse(json['uploadProgress']?.toString() ?? '0') ?? 0.0,
      uploadErrorMessage: json['uploadErrorMessage']?.toString() ??
          parsedMainMedia?.failureReason,
      languageVariants: parsedVariants,
      selectedAudioFormat: (json['selectedAudioFormat'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      selectedSubLanguages: (json['selectedSubLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      primaryUploadTaskId: json['primaryUploadTaskId']?.toString(),
      primaryUploadSessionId: json['primaryUploadSessionId'],
      primaryUploadId: parsedMainMedia?.uploadId ?? json['primaryUploadId']?.toString(),
      primaryS3Key: json['primaryS3Key']?.toString(),
      primaryPartSize:
          int.tryParse(json['primaryPartSize']?.toString() ?? '0'),
      primaryTotalParts:
          int.tryParse(json['primaryTotalParts']?.toString() ?? '0'),
      primaryCompletedETags: parsedETags,
      primaryFileName: parsedMainMedia?.fileName ?? json['primaryFileName']?.toString(),
      primaryFileSize: parsedMainMedia?.fileSize ??
          int.tryParse(json['primaryFileSize']?.toString() ?? '0'),
      primaryFileType: json['primaryFileType']?.toString(),
      primaryFileLastModified:
          int.tryParse(json['primaryFileLastModified']?.toString() ?? ''),
      teaserFileName: parsedTeaserMedia?.fileName ?? json['teaserFileName']?.toString(),
      teaserFileSize: parsedTeaserMedia?.fileSize ??
          int.tryParse(json['teaserFileSize']?.toString() ?? '0'),
      teaserFileType: json['teaserFileType']?.toString(),
      teaserFileLastModified:
          int.tryParse(json['teaserFileLastModified']?.toString() ?? ''),
      trailerFileName: parsedTrailerMedia?.fileName ?? json['trailerFileName']?.toString(),
      trailerFileSize: parsedTrailerMedia?.fileSize ??
          int.tryParse(json['trailerFileSize']?.toString() ?? '0'),
      trailerFileType: json['trailerFileType']?.toString(),
      trailerFileLastModified:
          int.tryParse(json['trailerFileLastModified']?.toString() ?? ''),
      poster1FileName: json['poster1FileName']?.toString(),
      poster2FileName: json['poster2FileName']?.toString(),
      poster3FileName: json['poster3FileName']?.toString(),
      poster1Url: json['poster1Url']?.toString(),
      poster2Url: json['poster2Url']?.toString(),
      poster3Url: json['poster3Url']?.toString(),
      castDraftName: json['castDraftName']?.toString(),
      castDraftRole: json['castDraftRole']?.toString(),
      castDraftDescription: json['castDraftDescription']?.toString(),
      castDraftImage: json['castDraftImage']?.toString(),
      crewDraftName: json['crewDraftName']?.toString(),
      crewDraftRole: json['crewDraftRole']?.toString(),
      crewDraftImage: json['crewDraftImage']?.toString(),
    );
  }
}

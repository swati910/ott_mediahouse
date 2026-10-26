class ApiConstant {
  static const String baseUrl = "https://filmytell.com/ott/";
  // static const String baseUrl =
  //     "http://ec2-13-201-27-141.ap-south-1.compute.amazonaws.com:8080/ott/";
  static const String signedPlaybackUrl =
      "${baseUrl}anti-piracy/playback/signed-url";

  static String twoStepLogin = "${baseUrl}auth/two-step/login";
  static String twoStepVerifyOtp = "${baseUrl}auth/two-step/verify-otp";
  static String refreshAuthToken = "${baseUrl}auth/refresh-token";

  static const String forgotPasswordSendOtp =
      "${baseUrl}user/forgotPassword/findUserAndSendOTP";
  static const String forgotPasswordVerifyOtp = "${baseUrl}user/verifyOTP";
  static const String forgotPasswordReset = "${baseUrl}user/resetPassword";

  static String login(mobileNumber) => Uri.parse(forgotPasswordSendOtp).replace(
      queryParameters: {'mobileNumber': mobileNumber.toString()}).toString();
  static String verifyOtp(mobileNumber, otp) =>
      Uri.parse(forgotPasswordVerifyOtp).replace(queryParameters: {
        'mobileNumber': mobileNumber.toString(),
        'otp': otp.toString(),
      }).toString();
  static String registration = '${baseUrl}user/RegisterUser';
  static String getAllUser = "${baseUrl}user/getAllActiveUsers";
  static String editUserById = "${baseUrl}user/updateUserBy/%7Bid%7D";
  static String getUserById(id) => "${baseUrl}user/getUser/$id";
  static String deleteUserById(id) => "${baseUrl}user/deleteUserBy/$id";
  static String searchUser(char) => "${baseUrl}user/search?search=$char";

  static String saveMediaHouse =
      '${baseUrl}userNew/saveMediaHouseWithDirectorCEO/newUser';
  static String editMediaHouseById = "${baseUrl}api/MediaHouse/Update";
  static String getAllMediaHouse = "${baseUrl}api/MediaHouse/getAll";
  static String getMediaHouseByUserId(id) =>
      "${baseUrl}api/MediaHouse/getByUserId?userId=$id";
  static String deleteMediaHouseById(id) =>
      "${baseUrl}api/deleteMediaHouseBy/$id";
  static String searchMediaHouse(char) =>
      "${baseUrl}api/searchByanyKey?search=$char";
  static String getMediaHouseByStatus(status) =>
      "${baseUrl}api/MediaHouse/getByStatus?status=$status";
  static String changeMediaHouseStatus(status, id) =>
      "${baseUrl}api/ApproveMediaHouseBy?mediaHouseId=$id&status=$status";
  static String getMediaHouseById(id) =>
      "${baseUrl}api/v2/mediaHouse/getMediaHouseById/$id";
  static String getMediaHouseDashboardCount(id) =>
      "${baseUrl}api/v2/mediaHouse/getMediaHouseDashboardCountForAdmin/$id";
  static String movieTransactionsByMediaHouse(
    dynamic mediaHouseId, {
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) {
    final params = <String, String>{};
    if (page != null) params['page'] = '$page';
    if (size != null) params['size'] = '$size';
    if (startDate != null && startDate.trim().isNotEmpty) {
      params['startDate'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['endDate'] = endDate.trim();
    }
    if (params.isEmpty) {
      return "${baseUrl}api/v2/user/movie-transactions-by-media-house/$mediaHouseId";
    }
    final query = params.entries
        .map((item) => '${item.key}=${Uri.encodeQueryComponent(item.value)}')
        .join('&');
    return "${baseUrl}api/v2/user/movie-transactions-by-media-house/$mediaHouseId?$query";
  }

  static String productionHouseNotifications({
    required int userId,
    required int mediaHouseId,
    required int pageNo,
    required int pageSize,
  }) =>
      "${baseUrl}api/notifications/user/$userId/push?mediaHouseId=$mediaHouseId&pageNo=$pageNo&pageSize=$pageSize";

  static String productionHouseWalletSummary(int productionHouseId) =>
      "${baseUrl}api/production-house-wallet/$productionHouseId/summary";

  static String productionHouseWalletTransactions(
    int productionHouseId, {
    required int page,
    required int size,
    String? search,
    String? transactionType,
    String? status,
    String? entryType,
    DateTime? fromDate,
    DateTime? toDate,
    double? minAmount,
    double? maxAmount,
  }) {
    final params = <String, String>{'page': '$page', 'size': '$size'};
    void add(String key, Object? value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) params[key] = text;
    }

    add('search', search);
    add('transactionType', transactionType);
    add('status', status);
    add('entryType', entryType);
    add('fromDate', fromDate?.toIso8601String().split('T').first);
    add('toDate', toDate?.toIso8601String().split('T').first);
    add('minAmount', minAmount);
    add('maxAmount', maxAmount);
    final query = params.entries
        .map((item) => '${item.key}=${Uri.encodeQueryComponent(item.value)}')
        .join('&');
    return "${baseUrl}api/production-house-wallet/$productionHouseId/transactions?$query";
  }

  static String withdrawWalletAmount = "${baseUrl}wallet/withdraw";
  static String walletHistory(int id) => "${baseUrl}wallet/history/$id";

  static String saveVideo = '${baseUrl}api/addContent';
  static String saveCast = '${baseUrl}api/saveCast';
  static String updateCast = '${baseUrl}api/Cast/Update';
  static String getCastByContentId(int contentId) =>
      "${baseUrl}api/Cast/getByContentId?contentId=$contentId";
  static String getCastByShortId(int shortId) =>
      "${baseUrl}api/Cast/getByShortId?shortId=$shortId";
  static String getCastByContentIdAndSeasonId({
    required int contentId,
    required int seasonId,
  }) =>
      "${baseUrl}api/Cast/getByContentIdAndSeasonId?contentId=$contentId&seasonId=$seasonId";
  static String editVideoById(id) => "${baseUrl}api/contentList/update/$id";
  static String getAllVideo = "${baseUrl}api/ContentList/getAll";
  static String getVideoById(id) => "${baseUrl}api/ContentList/getById?id=$id";
  static String getRatingReviewByContentId(int id) =>
      "${baseUrl}api/content/$id";
  static String getVideoByMediaHouseId(
    id, {
    String type = "MOVIE",
    String? searchKeyword,
    int page = 0,
    int size = 10,
  }) =>
      "${baseUrl}api/content/byMediaHouseAndType/pages?mediaHouseId=$id&type=$type&keyword=${searchKeyword ?? ''}&page=$page&size=$size";
  static String searchContent(char) =>
      "${baseUrl}api/searchByanyKey?search=$char";
  static String deleteVideoById(id) => "${baseUrl}api/deleteContentBy/$id";
  static String getVideoByStatusAndMediaHouse(
    status,
    id, {
    String? searchKeyword,
    int page = 0,
    int size = 10,
  }) =>
      "${baseUrl}api/Approvalstatus/mediahouseid2?approvalStatus=$status&mediaHouseId=$id&keyword=${searchKeyword ?? ''}&page=$page&size=$size";
  static String changeContentStatus(status, id) =>
      "${baseUrl}api/ApprovecontentListBy?contentListId=$id&status=$status";
  static String getReleaseVideoByMediaHouse(id,
          {int page = 0, int size = 10, String? searchKeyword}) =>
      "${baseUrl}api/getReleaseContentByMediahouseId?mediaHouseId=$id&keyword=$searchKeyword&page=$page&size=$size";

  static String filterAdvancedContent({
    required int mediaHouseId,
    required String type,
    required String approvalStatus,
    String? startDate,
    String? endDate,
    String? searchKeyword,
    int page = 0,
    int size = 10,
  }) {
    final params = <String, String>{
      'mediaHouseId': '$mediaHouseId',
      'type': type,
      'approvalStatus': approvalStatus,
      'keyword': searchKeyword ?? '',
      'page': '$page',
      'size': '$size',
    };

    if (startDate != null && startDate.trim().isNotEmpty) {
      params['startDate'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['endDate'] = endDate.trim();
    }

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/content/filter-advanced?$query";
  }

  static String savePromoter = '${baseUrl}api/savePromoters2';
  static String editPromoterById = "${baseUrl}user/updateUserBy/%7Bid%7D";
  static String getAllPromoter = "${baseUrl}api/Promoters/getAll";
  static String getPromoterById(id) => "${baseUrl}user/getUser/$id";
  static String deletePromoterById(id) => "${baseUrl}api/deletePromotersBy/$id";
  static String getPromoterByStatus(status) =>
      "${baseUrl}api/Promoters/getByStatus?status=$status";
  static String changePromoterStatus(status, id) =>
      "${baseUrl}api/ApprovecontentListBy?contentListId=$id&status=$status";
  static String getUsersByPromoterCode(code) =>
      "${baseUrl}user/getUsersByPromoterReferralCode2?refferedBy=$code";
  static String getPromotersByPromoterCode(code) =>
      "${baseUrl}user/getPromotersByPromoterReferralCode2?refferedBy=$code";
  static String getUserAndRevenueGraph(startDate, endEnd, promoterId) =>
      "${baseUrl}api/admin/userOnboardedGraphByPromoterId2?start_date=$startDate&end_date=$endEnd&promoterId=$promoterId";

  static String uploadFile = "${baseUrl}api/other/upload-file";
  static String uploadImg = "${baseUrl}api/documents/upload";
  static String uploadContentImg = "${baseUrl}api/documents/upload";
  static String uploadDocument = "${baseUrl}api/documents/upload";
  static String uploadVideo = "${baseUrl}api/video/upload";
  static String uploadVideoMetadata = "${baseUrl}api/video-metadata/extract";
  static String uploadSubtitle = "${baseUrl}api/video-metadata/subtitle/upload";
  static String uploadAudioMetadata =
      "${baseUrl}api/video-metadata/audio/extract";
  static String multipartInitiate = "${baseUrl}api/video/multipart/initiate";
  static String multipartPresign = "${baseUrl}api/video/multipart/presign";
  static String multipartStatus(dynamic uploadSessionId) =>
      "${baseUrl}api/video/multipart/$uploadSessionId/status";
  static String multipartComplete = "${baseUrl}api/video/multipart/complete";
  static String multipartAbort(dynamic uploadSessionId) =>
      "${baseUrl}api/video/multipart/$uploadSessionId";
  static String multipartAbortWithBody = "${baseUrl}api/video/multipart/abort";
  static String allLanguagesWithGrouping = "${baseUrl}api/all/withGrouping";
  static String sendNotification = "${baseUrl}api/notifications/send";
  static String scheduleNotification = "${baseUrl}api/notifications/schedule";
  static String resendNotification(id) =>
      "${baseUrl}api/notifications/$id/resend";
  static String notificationAnalytics({
    required int mediaHouseId,
    String timeRange = "",
  }) =>
      "${baseUrl}api/notifications/analytics/show?mediaHouseId=$mediaHouseId";
  static String notificationsByMediaHouse({
    required int mediaHouseId,
    required int page,
    required int size,
    String sortBy = "createdDate",
    String sortDir = "desc",
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{
      "mediaHouseId": "$mediaHouseId",
      "page": "$page",
      "size": "$size",
      "sortBy": sortBy,
      "sortDir": sortDir,
    };
    if (startDate != null && startDate.trim().isNotEmpty) {
      params["startDate"] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params["endDate"] = endDate.trim();
    }
    final query = params.entries
        .map((entry) => "${entry.key}=${Uri.encodeQueryComponent(entry.value)}")
        .join("&");
    return "${baseUrl}api/notifications/analytics/by-media-house?$query";
  }

  static String dashboardCount = "${baseUrl}api/admin/dashboardCounts";
  static String activeRegistrationFeeRule({
    required String contentType,
    String audienceScope = "INDIA",
  }) =>
      "${baseUrl}api/admin/registration-fee-rule/getActiveRule?contentType=${Uri.encodeQueryComponent(contentType)}&audienceScope=${Uri.encodeQueryComponent(audienceScope)}";

  static String resetPassword(mobile, password) =>
      "${baseUrl}user/resetPassword?mobileNumber=$mobile&password=$password";
  static String forgotPassword(mobile) =>
      "${baseUrl}user/forgotPassword/findUserAndSendOTP?mobileNumber=$mobile";

  static String raiseTicket = "${baseUrl}api/TicketRaised/add";
  static String deleteTicket(id) =>
      "${baseUrl}api/TicketRaised/deleteTicketRaisedBy/$id";
  static String updateTicket(id) => "${baseUrl}api/TicketRaised/update/$id";
  static String getRaisedTicket =
      "${baseUrl}api/TicketRaised/getAllTicketRaised";
  static String getRaisedTicketByUserId(userId) =>
      "${baseUrl}api/TicketRaised/user/$userId";
  static String getRaisedTicketByFlag(isResolved, userId) =>
      "${baseUrl}api/TicketRaised/userIsResolved?userId=$userId&isResolved=$isResolved";
  static String searchAndFilterTickets({
    String role = "MEDIA_HOUSE",
    String? keyword,
    String? status,
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{'role': role};
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (startDate != null && startDate.trim().isNotEmpty) {
      params['startDate'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['endDate'] = endDate.trim();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/TicketRaised/searchAndFilter?$query";
  }

  static String weeklySettlementDataForMediaHouse(dynamic userId) =>
      "${baseUrl}api/v2/settlement/weeklySettelementDataForMediaHouse/$userId";
  static String weeklySettlementByMediaHouseAlias(dynamic id) =>
      "${baseUrl}api/settelment/mediaHouse/$id";
  static String weeklySettlementReportById(dynamic settlementId) =>
      "${baseUrl}api/admin/weekly-settlement-report/$settlementId";
  static String transactionSettlementReport(dynamic transactionId) =>
      "${baseUrl}api/admin/transaction-settlement-report/$transactionId";

  static String mediaHouseSettlements(
    int mediaHouseId, {
    int page = 0,
    int size = 10,
  }) =>
      "${baseUrl}api/settlements/media-house/$mediaHouseId?page=$page&size=$size";

  static String mediaHouseWeeklySettlementReport(
    int mediaHouseId, {
    String? settlementBatchReference,
  }) {
    final reference = settlementBatchReference?.trim();
    final query = reference == null || reference.isEmpty
        ? ''
        : '?settlementBatchReference=${Uri.encodeQueryComponent(reference)}';
    return "${baseUrl}api/media-house/weekly-settlement-report/$mediaHouseId$query";
  }

  static String topRevenueContentGraph(
    id,
    startDate,
    endDate,
    isYear,
    isMonth,
    isWeek, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) {
    final params = <String, String>{
      'mediaHouseId': '$id',
      'startDate': '$startDate',
      'endDate': '$endDate',
      'isYear': '$isYear',
      'isMonth': '$isMonth',
      'isWeek': '$isWeek',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/mediaHouseLineCharts/top-revenue-content-by-media-house?$query";
  }

  static String topRatedContentGraph(
    id,
    startDate,
    endDate,
    isYear,
    isMonth,
    isWeek, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) {
    final params = <String, String>{
      'mediaHouseId': '$id',
      'startDate': '$startDate',
      'endDate': '$endDate',
      'isYear': '$isYear',
      'isMonth': '$isMonth',
      'isWeek': '$isWeek',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/mediaHouseLineCharts/top-rated-content-by-media-house?$query";
  }

  static String contentRevenueGraph(
    id,
    startDate,
    endDate,
    isYear,
    isMonth,
    isWeek, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) {
    final params = <String, String>{
      'contentListId': '$id',
      'startDate': '$startDate',
      'endDate': '$endDate',
      'isYear': '$isYear',
      'isMonth': '$isMonth',
      'isWeek': '$isWeek',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/contentList/graph?$query";
  }

  static String setPercentage = "${baseUrl}api/admin/saveMoviePercentAndRate";
  static String reportAndData(
    id, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
    String? startDate,
    String? endDate,
    String? ageGroup,
    String? gender,
  }) {
    final params = <String, String>{
      'id': '$id',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);
    putIfNotBlank('startDate', startDate);
    putIfNotBlank('endDate', endDate);
    putIfNotBlank('ageGroup', ageGroup);
    putIfNotBlank('gender', gender);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/reportAndDataMediaHouse/getById?$query";
  }

  static String releaseMovieCountGraphByMediaHouse(
    id,
    startDate,
    endDate,
    isYear,
    isMonth,
    isWeek, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) {
    final params = <String, String>{
      'mediaHouseid': '$id',
      'startDate': '$startDate',
      'endDate': '$endDate',
      'isYear': '$isYear',
      'isMonth': '$isMonth',
      'isWeek': '$isWeek',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/mediaHouseLineCharts/releaseMovieCountChart?$query";
  }

  static String viewCountGraphByMediaHouse(
    id,
    startDate,
    endDate,
    isYear,
    isMonth,
    isWeek, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) {
    final params = <String, String>{
      'mediahouseId': '$id',
      'startDate': '$startDate',
      'endDate': '$endDate',
      'isYear': '$isYear',
      'isMonth': '$isMonth',
      'isWeek': '$isWeek',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/viewCountChartByMediaHouseId?$query";
  }

  static String revenueGraphByMediaHouse(
    id,
    startDate,
    endDate,
    isYear,
    isMonth,
    isWeek, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) {
    final params = <String, String>{
      'mediaHouseId': '$id',
      'startDate': '$startDate',
      'endDate': '$endDate',
      'isYear': '$isYear',
      'isMonth': '$isMonth',
      'isWeek': '$isWeek',
    };

    void putIfNotBlank(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    putIfNotBlank('contentType', contentType);
    putIfNotBlank('country', country);
    putIfNotBlank('state', state);
    putIfNotBlank('district', district);
    putIfNotBlank('taluka', taluka);
    putIfNotBlank('city', city);

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/transactionDashboard/mediaHouse/graph?$query";
  }

  static String revenueGraphByMediaHouseV2({
    required dynamic mediaId,
    required String startDate,
    required String endDate,
    String? type,
  }) {
    final params = <String, String>{
      'mediaId': '$mediaId',
      'startDate': startDate,
      'endDate': endDate,
    };
    if (type != null && type.trim().isNotEmpty) {
      params['type'] = type.trim();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/v2/mediaHouse/revenueGraphByMediaHouse?$query";
  }

  static String contentRevenueBreakdown(
    dynamic mediaHouseId, {
    int? contentId,
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{};
    if (contentId != null) params['contentId'] = '$contentId';
    if (startDate != null && startDate.trim().isNotEmpty) {
      params['startDate'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['endDate'] = endDate.trim();
    }
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return "${baseUrl}api/v1/analytics/production-house/$mediaHouseId/content-revenue$query";
  }

  static String purchasedUsersByContentId({
    required int contentId,
    String? startDate,
    String? endDate,
    String? state,
    String? city,
    int page = 0,
    int size = 10,
  }) {
    final params = <String, String>{
      'contentId': '$contentId',
      'page': '$page',
      'size': '$size',
    };
    if (startDate != null && startDate.trim().isNotEmpty) {
      params['startDate'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['endDate'] = endDate.trim();
    }
    if (state != null && state.trim().isNotEmpty) {
      params['state'] = state.trim();
    }
    if (city != null && city.trim().isNotEmpty) {
      params['city'] = city.trim();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/contentList/getUsersByContentId?$query";
  }

  static String audienceLocationWise({
    required int contentId,
    String? fromDate,
    String? toDate,
  }) {
    final params = <String, String>{'contentId': '$contentId'};
    if (fromDate != null && fromDate.trim().isNotEmpty) {
      params['fromDate'] = fromDate.trim();
    }
    if (toDate != null && toDate.trim().isNotEmpty) {
      params['toDate'] = toDate.trim();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}ott/admin/analytics/location-wise?$query";
  }

  static String audienceAgeWise({
    required int contentId,
    String? fromDate,
    String? toDate,
  }) {
    final params = <String, String>{'contentId': '$contentId'};
    if (fromDate != null && fromDate.trim().isNotEmpty) {
      params['fromDate'] = fromDate.trim();
    }
    if (toDate != null && toDate.trim().isNotEmpty) {
      params['toDate'] = toDate.trim();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}ott/admin/analytics/age-wise-views?$query";
  }

  //shorts
  static String shortsByMediaHouse(
    dynamic mediaHouseId, {
    int page = 0,
    int size = 10,
    String? keyword,
  }) {
    final params = <String, String>{'page': '$page', 'size': '$size'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return "${baseUrl}api/v2/shorts/by-media-house/$mediaHouseId?$query";
  }

  static String shortsMaster(
    id, {
    String keyword = '',
    int page = 0,
    int size = 10,
  }) =>
      "${baseUrl}api/shortsMaster/by-mediahouse/$id?keyword=${Uri.encodeQueryComponent(keyword)}&page=$page&size=$size";
  static String shortsMasterForAdmin(dynamic shortMasterId) =>
      "${baseUrl}api/shortsMaster/forAdmin/$shortMasterId";
  static String shortsTrending({
    String? lang,
    int page = 0,
    int size = 10,
  }) {
    final params = <String, String>{
      "page": "$page",
      "size": "$size",
    };
    if (lang != null && lang.trim().isNotEmpty) {
      params["lang"] = lang.trim();
    }
    final query = params.entries
        .map((e) => "${e.key}=${Uri.encodeQueryComponent(e.value)}")
        .join("&");
    return "${baseUrl}api/shortsMaster/trending?$query";
  }

  static String filterShorts({
    required int mediaHouseId,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = 10,
  }) {
    final params = <String, String>{
      "mediaHouseId": "$mediaHouseId",
      "page": "$page",
      "size": "$size",
    };
    if (startDate != null && startDate.trim().isNotEmpty) {
      params["startDate"] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params["endDate"] = endDate.trim();
    }
    final query = params.entries
        .map((e) => "${e.key}=${Uri.encodeQueryComponent(e.value)}")
        .join("&");
    return "${baseUrl}api/shortsMaster/shorts/filter?$query";
  }

  static String shortsDetails(id, userId) =>
      "${baseUrl}api/shortsMaster/$id?userId=$userId";
  static String addShortMaster = '${baseUrl}api/shortsMaster';
  static const deleteShortMaster = "${baseUrl}api/shortsMaster";
  static const updateShortMaster = "${baseUrl}api/shortsMaster";

  static String createShortPart = "${baseUrl}api/short-parts";

  static deletePart(partId) => "${baseUrl}api/short-parts/$partId";

  static String saveSeries = '${baseUrl}series/createSeries';
  static String seriesDetails(seriesId) => "${baseUrl}series/$seriesId/details";
  static String getSeriesByMediaHouse(id) =>
      "${baseUrl}api/content/byMediaHouseAndType/pages?mediaHouseId=$id&type=SERIES";
}

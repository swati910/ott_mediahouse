int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

class Content {
  int? id;
  String? title;
  String? description;
  int? runtime;
  dynamic releaseDate;
  double? ratings;
  double? price;
  List<LanguageList>? languageList;
  List<String>? castList;
  List<String>? genreList;
  List<String>? directorList;
  int? views;
  int? totalPurchase;
  double? totalRevenue;
  double? mediaHouseRevenue;
  double? mediaHouseGrossRevenue;
  double? mediaHouseNetRevenue;
  String? ageRating;
  List<String>? posterUrlList;
  String? teaserUrl;
  String? trailerUrl;
  String? contentUrl;
  String? approvalStatus;
  String? type;
  String? sensorCertificate;
  bool? isPaid;
  bool? isAggrement;
  String? aggrementDocument;
  bool? isFeatured;
  String? registrationFeePaid;
  String? registrationFeeDetails;
  Availability? availability;
  List<String>? audioFormatList;
  List<String>? subtitleLanguageList;
  bool? isDownloadable;
  int? uploadDateTime;
  int? approvedDateTime;
  String? mediaHouseName;
  int? mediaHouseId;
  int? ratingCount;
  String? rentlDuration;
  int? numberOfAttempt;
  int? fullAttempt;
  double? adminIncentivePecentage;
  double? mediaHouseIncentivePecentage;
  String? reason;
  dynamic active;
  dynamic watchedSeconds;
  dynamic watchedPercentage;
  dynamic seasonId;
  dynamic episodeId;

  Content({
    this.id,
    this.title,
    this.description,
    this.runtime,
    this.releaseDate,
    this.ratings,
    this.price,
    this.languageList,
    this.castList,
    this.genreList,
    this.directorList,
    this.views,
    this.totalPurchase,
    this.totalRevenue,
    this.mediaHouseRevenue,
    this.mediaHouseGrossRevenue,
    this.mediaHouseNetRevenue,
    this.ageRating,
    this.posterUrlList,
    this.teaserUrl,
    this.trailerUrl,
    this.contentUrl,
    this.approvalStatus,
    this.type,
    this.sensorCertificate,
    this.isPaid,
    this.isAggrement,
    this.aggrementDocument,
    this.isFeatured,
    this.registrationFeePaid,
    this.registrationFeeDetails,
    this.availability,
    this.audioFormatList,
    this.subtitleLanguageList,
    this.isDownloadable,
    this.uploadDateTime,
    this.approvedDateTime,
    this.mediaHouseName,
    this.mediaHouseId,
    this.ratingCount,
    this.rentlDuration,
    this.numberOfAttempt,
    this.fullAttempt,
    this.adminIncentivePecentage,
    this.mediaHouseIncentivePecentage,
    this.reason,
    this.active,
    this.watchedSeconds,
    this.watchedPercentage,
    this.seasonId,
    this.episodeId
  });

  factory Content.fromJson(Map<String, dynamic> json) => Content(
    id: _asInt(json["id"]),
    title: json["title"],
    description: json["description"],
    runtime: _asInt(json["runtime"]),
    releaseDate: json["releaseDate"],
    ratings: json["ratings"]?.toDouble(),
    price: json["price"]?.toDouble(),
      languageList: json["languageList"] == null ? [] : List<LanguageList>.from(json["languageList"]!.map((x) => LanguageList.fromJson(x))),
      castList: json["castList"] == null ? [] : List<String>.from(json["castList"]!.map((x) => x)),
    genreList: json["genreList"] == null ? [] : List<String>.from(json["genreList"]!.map((x) => x)),
    directorList: json["directorList"] == null ? [] : List<String>.from(json["directorList"]!.map((x) => x)),
    views: _asInt(json["views"]),
    totalPurchase: _asInt(json["totalPurchase"]),
    totalRevenue: json["totalRevenue"]?.toDouble(),
    mediaHouseRevenue: _asDouble(json["mediaHouseRevenue"]),
    mediaHouseGrossRevenue: _asDouble(json["mediaHouseGrossRevenue"]),
    mediaHouseNetRevenue: _asDouble(json["mediaHouseNetRevenue"]),
    ageRating: json["ageRating"],
    posterUrlList: json["posterUrlList"] == null ? [] : List<String>.from(json["posterUrlList"]!.map((x) => x)),
    teaserUrl: json["teaserUrl"],
    trailerUrl: json["trailerUrl"],
    contentUrl: json["contentUrl"],
    approvalStatus: json["approvalStatus"],
    type: json["type"],
    sensorCertificate: json["sensorCertificate"],
    isPaid: json["isPaid"],
    isAggrement: json["isAggrement"],
    aggrementDocument: json["aggrementDocument"],
    isFeatured: json["isFeatured"],
    registrationFeePaid: json["registrationFeePaid"],
    registrationFeeDetails: json["registrationFeeDetails"],
    availability: json["availability"] == null ? null : Availability.fromJson(json["availability"]),
    audioFormatList: json["audioFormatList"] == null ? [] : List<String>.from(json["audioFormatList"]!.map((x) => x)),
    subtitleLanguageList: json["subtitleLanguageList"] == null ? [] : List<String>.from(json["subtitleLanguageList"]!.map((x) => x)),
    isDownloadable: json["isDownloadable"],
    uploadDateTime: _asInt(json["uploadDateTime"]),
    approvedDateTime: _asInt(json["approvedDateTime"]),
    mediaHouseName: json["mediaHouseName"],
    mediaHouseId: _asInt(json["mediaHouseId"]),
    ratingCount: _asInt(json["ratingCount"]),
    rentlDuration: json["rentlDuration"],
    numberOfAttempt: _asInt(json["numberOfAttempt"]),
    fullAttempt: _asInt(json["fullAttempt"]),
    adminIncentivePecentage: json["adminIncentivePecentage"],
    mediaHouseIncentivePecentage: json["mediaHouseIncentivePecentage"],
      reason: json['reason'],
    active: json["active"],
    watchedSeconds: json["watchedSeconds"],
    watchedPercentage: json["watchedPercentage"],
    seasonId: json["seasonId"],
    episodeId: json["episodeId"]
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "runtime": runtime,
    "releaseDate": releaseDate,
    "ratings": ratings,
    "price": price,
    "languageList": languageList == null ? [] : List<dynamic>.from(languageList!.map((x) => x.toJson())),
    "castList": castList == null ? [] : List<dynamic>.from(castList!.map((x) => x)),
    "genreList": genreList == null ? [] : List<dynamic>.from(genreList!.map((x) => x)),
    "directorList": directorList == null ? [] : List<dynamic>.from(directorList!.map((x) => x)),
    "views": views,
    "totalPurchase": totalPurchase,
    "totalRevenue": totalRevenue,
    "mediaHouseRevenue": mediaHouseRevenue,
    "mediaHouseGrossRevenue": mediaHouseGrossRevenue,
    "mediaHouseNetRevenue": mediaHouseNetRevenue,
    "ageRating": ageRating,
    "posterUrlList": posterUrlList == null ? [] : List<dynamic>.from(posterUrlList!.map((x) => x)),
    "teaserUrl": teaserUrl,
    "trailerUrl": trailerUrl,
    "contentUrl": contentUrl,
    "approvalStatus": approvalStatus,
    "type": type,
    "sensorCertificate": sensorCertificate,
    "isPaid": isPaid,
    "isAggrement": isAggrement,
    "aggrementDocument": aggrementDocument,
    "isFeatured": isFeatured,
    "registrationFeePaid": registrationFeePaid,
    "registrationFeeDetails": registrationFeeDetails,
    "availability": availability?.toJson(),
    "audioFormatList": audioFormatList == null ? [] : List<dynamic>.from(audioFormatList!.map((x) => x)),
    "subtitleLanguageList": subtitleLanguageList == null ? [] : List<dynamic>.from(subtitleLanguageList!.map((x) => x)),
    "isDownloadable": isDownloadable,
    "uploadDateTime": uploadDateTime,
    "approvedDateTime": approvedDateTime,
    "mediaHouseName": mediaHouseName,
    "mediaHouseId": mediaHouseId,
    "ratingCount": ratingCount,
    "rentlDuration": rentlDuration,
    "numberOfAttempt": numberOfAttempt,
    "fullAttempt": fullAttempt,
    "adminIncentivePecentage":adminIncentivePecentage,
    "mediaHouseIncentivePecentage": mediaHouseIncentivePecentage,
    "active": active,
    "reason": reason,
    "watchedSeconds": watchedSeconds,
    "watchedPercentage": watchedPercentage,
    "seasonId": seasonId,
    "episodeId": episodeId
  };

  double get effectiveMediaHouseNetRevenue =>
      mediaHouseNetRevenue ?? mediaHouseRevenue ?? totalRevenue ?? 0.0;

  double get effectiveMediaHouseGrossRevenue =>
      mediaHouseGrossRevenue ?? mediaHouseRevenue ?? totalRevenue ?? 0.0;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class Availability {
  List<String>? regions;
  List<String>? platforms;

  Availability({
    this.regions,
    this.platforms,
  });

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
    regions: json["regions"] == null ? [] : List<String>.from(json["regions"]!.map((x) => x)),
    platforms: json["platforms"] == null ? [] : List<String>.from(json["platforms"]!.map((x) => x)),
  );

  Map<String, dynamic> toJson() => {
    "regions": regions == null ? [] : List<dynamic>.from(regions!.map((x) => x)),
    "platforms": platforms == null ? [] : List<dynamic>.from(platforms!.map((x) => x)),
  };
}

class LanguageList {
  String? language;
  String? fileUrl;

  LanguageList({
    this.language,
    this.fileUrl,
  });

  factory LanguageList.fromJson(Map<String, dynamic> json) => LanguageList(
    language: json["language"],
    fileUrl: json["fileUrl"],
  );

  Map<String, dynamic> toJson() => {
    "language": language,
    "fileUrl": fileUrl,
  };
}

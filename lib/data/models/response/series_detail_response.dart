class SeriesDetailsResponse {
  final List<SeasonBundle> seasons;
  final Series series;

  SeriesDetailsResponse({
    required this.seasons,
    required this.series,
  });

  factory SeriesDetailsResponse.fromJson(Map<String, dynamic> json) {
    final payload = _asMap(json['data']) ?? json;
    return SeriesDetailsResponse(
      seasons: _asMapList(payload['seasons'])
          .map((e) => SeasonBundle.fromJson(e))
          .toList(),
      series: Series.fromJson(_asMap(payload['series']) ?? const {}),
    );
  }
}

class SeasonBundle {
  final Season season;
  final List<Episode> episodes;

  SeasonBundle({
    required this.season,
    required this.episodes,
  });

  factory SeasonBundle.fromJson(Map<String, dynamic> json) {
    return SeasonBundle(
      season: Season.fromJson(_asMap(json['season']) ?? const {}),
      episodes: _asMapList(json['episodes'])
          .map((e) => Episode.fromJson(e))
          .toList(),
    );
  }
}

class Episode {
  int? id;
  int? episodeNumber;
  String? title;
  String? description;
  String? videoUrl;
  String? posterUrl;
  int? runtime;
  int? releaseDate;
  int? seasonId;
  num? amount;
  int? viewCount;
  String? partName;
  bool? free;
  bool? active;

  Episode({
    this.id,
    this.episodeNumber,
    this.title,
    this.description,
    this.videoUrl,
    this.posterUrl,
    this.runtime,
    this.releaseDate,
    this.seasonId,
    this.amount,
    this.viewCount,
    this.partName,
    this.free,
    this.active,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: _toInt(json["id"]),
    episodeNumber: _toInt(json["episodeNumber"]),
    title: _toStringOrNull(json["title"]),
    description: _toStringOrNull(json["description"]),
    videoUrl: _toStringOrNull(json["videoUrl"]),
    posterUrl: _toStringOrNull(json["posterUrl"]),
    runtime: _toInt(json["runtime"]),
    releaseDate: _toInt(json["releaseDate"]),
    seasonId: _toInt(json["seasonId"]),
    amount: _toNum(json["amount"]),
    viewCount: _toInt(json["viewCount"]),
    partName: _toStringOrNull(json["partName"]),
    free: _toBool(json["free"]),
    active: _toBool(json["active"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "episodeNumber": episodeNumber,
    "title": title,
    "description": description,
    "videoUrl": videoUrl,
    "posterUrl": posterUrl,
    "runtime": runtime,
    "releaseDate": releaseDate,
    "seasonId": seasonId,
    "amount": amount,
    "viewCount": viewCount,
    "partName": partName,
    "free": free,
    "active": active,
  };
}

class Season {
  int? id;
  String? title;
  String? description;
  dynamic posterUrl;
  int? seasonNumber;
  num? amount;
  int? releaseDate;
  int? viewCount;
  int? contentId;
  bool? active;

  Season({
    this.id,
    this.title,
    this.description,
    this.posterUrl,
    this.seasonNumber,
    this.amount,
    this.releaseDate,
    this.viewCount,
    this.contentId,
    this.active,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    id: _toInt(json["id"]),
    title: _toStringOrNull(json["title"]),
    description: _toStringOrNull(json["description"]),
    posterUrl: json["posterUrl"],
    seasonNumber: _toInt(json["seasonNumber"]),
    amount: _toNum(json["amount"]),
    releaseDate: _toInt(json["releaseDate"]),
    viewCount: _toInt(json["viewCount"]),
    contentId: _toInt(json["contentId"]),
    active: _toBool(json["active"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "posterUrl": posterUrl,
    "seasonNumber": seasonNumber,
    "amount": amount,
    "releaseDate": releaseDate,
    "viewCount": viewCount,
    "contentId": contentId,
    "active": active,
  };
}

class Series {
  final int id;
  final String title;
  final String description;
  final double ratings;
  final int ratingCount;
  final num price;
  final List<String> genreList;
  final List<String> directorList;
  final List<String> castList;
  final List<String> posterUrlList;
  final String trailerURL;
  final String teaserURL;
  final String type;
  final String? ageRating;

  Series({
    required this.id,
    required this.title,
    required this.description,
    required this.ratings,
    required this.ratingCount,
    required this.price,
    required this.genreList,
    required this.directorList,
    required this.castList,
    required this.posterUrlList,
    required this.trailerURL,
    required this.teaserURL,
    required this.type,
    this.ageRating,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'];
    final rawRatingCount = json['ratingCount'];
    final rawPrice = json['price'];
    final rawTrailer = json['trailerURL'] ?? json['trailerUrl'];
    final rawTeaser = json['teaserURL'] ?? json['teaserUrl'];

    return Series(
      id: _toInt(json['id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      ratings: rawRatings is num
          ? rawRatings.toDouble()
          : double.tryParse("$rawRatings") ?? 0.0,
      ratingCount: _toInt(rawRatingCount) ?? 0,
      price: rawPrice is num ? rawPrice : num.tryParse("$rawPrice") ?? 0,
      genreList: _toStringList(json['genreList']),
      directorList: _toStringList(json['directorList']),
      castList: _toStringList(json['castList']),
      posterUrlList: _toStringList(json['posterUrlList']),
      trailerURL: (rawTrailer ?? '').toString(),
      teaserURL: (rawTeaser ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      ageRating: json['ageRating'],
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

num? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

bool? _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

String? _toStringOrNull(dynamic value) {
  if (value == null) return null;
  final out = value.toString().trim();
  return out.isEmpty ? null : out;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

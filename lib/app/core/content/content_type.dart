abstract final class ContentTypeValue {
  static const movie = 'MOVIE';
  static const shortFilm = 'SHORT_FILM';
  static const series = 'SERIES';
  static const miniSeries = 'MINI_SERIES';

  static const supported = <String>[
    movie,
    shortFilm,
    series,
    miniSeries,
  ];

  static String normalize(String? value) =>
      (value ?? '').trim().toUpperCase().replaceAll(' ', '_');

  static bool isMovieLike(String? value) {
    final type = normalize(value);
    return type == movie || type == shortFilm;
  }

  static bool isShortFilm(String? value) => normalize(value) == shortFilm;

  static String displayLabel(String? value) {
    switch (normalize(value)) {
      case movie:
        return 'Movie';
      case shortFilm:
        return 'Short Film';
      case series:
        return 'Series';
      case miniSeries:
        return 'Mini Series';
      default:
        final raw = value?.trim();
        return raw == null || raw.isEmpty ? 'Unknown' : raw;
    }
  }
}

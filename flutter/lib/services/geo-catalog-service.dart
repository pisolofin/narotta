import 'dart:math' as math;

import '../l10n/app_localizations.dart';

import 'geo-cell-service.dart';

/// Classification of searchable geographic entities.
enum GeoPlaceType {
  country,
  region,
  city;

  /// Returns the localized label for this place type.
  String getLocalizedLabel(AppLocalizations l10n) {
    if (this == GeoPlaceType.country) {
      return l10n.mapDownloadPlaceTypeCountry;
    }
    if (this == GeoPlaceType.region) {
      return l10n.mapDownloadPlaceTypeRegion;
    }
    return l10n.mapDownloadPlaceTypeCity;
  }
}

/// Represents a searchable country, administrative region, or city that can be selected completely on the world map.
class SearchableGeoPlaceModel {
  final String id;
  final String italianName;
  final String englishName;
  final String italianParentLabel;
  final String englishParentLabel;
  final GeoPlaceType type;
  final double minLongitude;
  final double minLatitude;
  final double maxLongitude;
  final double maxLatitude;
  final List<List<math.Point<double>>> polygonList;

  const SearchableGeoPlaceModel({
    required this.id,
    required this.italianName,
    required this.englishName,
    required this.italianParentLabel,
    required this.englishParentLabel,
    required this.type,
    required this.minLongitude,
    required this.minLatitude,
    required this.maxLongitude,
    required this.maxLatitude,
    this.polygonList = const [],
  });

  /// Convenience factory for a city centered at [longitude], [latitude] with a metropolitan radius in degrees.
  factory SearchableGeoPlaceModel.city({
    required String id,
    required String italianName,
    required String englishName,
    required String italianParentLabel,
    required String englishParentLabel,
    required double longitude,
    required double latitude,
    double halfSpanDegrees = 0.18,
  }) {
    return SearchableGeoPlaceModel(
      id                : id,
      italianName       : italianName,
      englishName       : englishName,
      italianParentLabel: italianParentLabel,
      englishParentLabel: englishParentLabel,
      type              : GeoPlaceType.city,
      minLongitude      : longitude - halfSpanDegrees,
      minLatitude       : latitude - halfSpanDegrees,
      maxLongitude      : longitude + halfSpanDegrees,
      maxLatitude       : latitude + halfSpanDegrees,
    );
  }

  /// Returns the display name localized for [localeCode].
  String getDisplayName(String localeCode) {
    if (localeCode == 'it') {
      return this.italianName;
    }
    return this.englishName;
  }

  /// Returns the parent geographic context label localized for [localeCode].
  String getParentLabel(String localeCode) {
    if (localeCode == 'it') {
      return this.italianParentLabel;
    }
    return this.englishParentLabel;
  }

  /// Computes the complete list of 0.5° × 0.5° [GeoCellModel] cells covering this geographic entity.
  List<GeoCellModel> resolveCellList() {
    if (this.polygonList.isNotEmpty) {
      return GeoCellService.getIntersectingCellListForMultiPolygon(this.polygonList);
    }
    return GeoCellService.getIntersectingCellListForBoundingBox(
      this.minLongitude,
      this.minLatitude,
      this.maxLongitude,
      this.maxLatitude,
    );
  }
}

/// Offline geographic catalog enabling instant search and complete selection of cities, regions, and countries.
class GeoCatalogService {
  /// Searches countries, regions, and cities matching [rawQuery].
  static List<SearchableGeoPlaceModel> searchPlaceList(String rawQuery, { int maxResults = 15 }) {
    final String normalizedQuery = _normalizeSearchText(rawQuery);
    if (normalizedQuery.isEmpty) {
      return [];
    }

    final List<SearchableGeoPlaceModel> prefixMatchList   = [];
    final List<SearchableGeoPlaceModel> containsMatchList = [];

    for (final SearchableGeoPlaceModel place in _placeCatalogList) {
      final String normIt     = _normalizeSearchText(place.italianName);
      final String normEn     = _normalizeSearchText(place.englishName);
      final String normParent = _normalizeSearchText('${place.italianParentLabel} ${place.englishParentLabel}');

      if (normIt.startsWith(normalizedQuery) || normEn.startsWith(normalizedQuery)) {
        prefixMatchList.add(place);
      }else if (normIt.contains(normalizedQuery) ||
                normEn.contains(normalizedQuery) ||
                normParent.contains(normalizedQuery)) {
        containsMatchList.add(place);
      }
    }

    final List<SearchableGeoPlaceModel> combinedList = [
      ...prefixMatchList,
      ...containsMatchList,
    ];

    if (combinedList.length > maxResults) {
      return combinedList.sublist(0, maxResults);
    }
    return combinedList;
  }

  /// Normalizes accents and casing for forgiving offline search.
  static String _normalizeSearchText(String input) {
    return input
      .trim()
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('á', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('í', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ó', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ä', 'a')
      .replaceAll('î', 'i')
    ;
  }

  // Polygon outlines for accurate land-only selection of major countries and islands
  static const List<math.Point<double>> _italyPeninsulaPolygon = [
    math.Point(6.7, 45.1),
    math.Point(7.0, 45.9),
    math.Point(8.5, 46.2),
    math.Point(10.5, 46.8),
    math.Point(12.2, 47.0),
    math.Point(13.8, 46.5),
    math.Point(13.8, 45.6),
    math.Point(12.4, 45.4),
    math.Point(12.3, 44.4),
    math.Point(13.6, 43.6),
    math.Point(14.9, 42.1),
    math.Point(16.2, 41.9),
    math.Point(18.5, 40.1),
    math.Point(17.9, 39.8),
    math.Point(17.1, 40.4),
    math.Point(16.6, 39.0),
    math.Point(15.7, 38.0),
    math.Point(15.8, 39.8),
    math.Point(14.0, 40.8),
    math.Point(12.2, 41.7),
    math.Point(10.5, 42.9),
    math.Point(9.9, 44.1),
    math.Point(8.9, 44.4),
    math.Point(7.5, 43.8),
    math.Point(6.7, 45.1),
  ];

  static const List<math.Point<double>> _sicilyPolygon = [
    math.Point(12.4, 37.9),
    math.Point(15.6, 38.2),
    math.Point(15.2, 36.7),
    math.Point(12.5, 37.5),
    math.Point(12.4, 37.9),
  ];

  static const List<math.Point<double>> _sardiniaPolygon = [
    math.Point(8.2, 41.2),
    math.Point(9.7, 41.2),
    math.Point(9.7, 39.1),
    math.Point(8.4, 38.9),
    math.Point(8.2, 41.2),
  ];

  static const List<math.Point<double>> _franceMainlandPolygon = [
    math.Point(-4.7, 48.4),
    math.Point(-1.6, 49.6),
    math.Point(2.5, 51.0),
    math.Point(8.1, 49.0),
    math.Point(7.6, 47.6),
    math.Point(6.8, 45.8),
    math.Point(7.5, 43.8),
    math.Point(5.4, 43.2),
    math.Point(3.1, 42.5),
    math.Point(-1.8, 43.3),
    math.Point(-1.2, 46.0),
    math.Point(-4.7, 48.4),
  ];

  static const List<math.Point<double>> _corsicaPolygon = [
    math.Point(8.6, 42.9),
    math.Point(9.5, 42.9),
    math.Point(9.4, 41.4),
    math.Point(8.7, 41.5),
    math.Point(8.6, 42.9),
  ];

  static const List<math.Point<double>> _spainPolygon = [
    math.Point(-9.2, 43.0),
    math.Point(-1.8, 43.4),
    math.Point(3.2, 42.4),
    math.Point(0.8, 40.7),
    math.Point(-0.4, 39.4),
    math.Point(-0.7, 37.6),
    math.Point(-5.6, 36.0),
    math.Point(-7.4, 37.2),
    math.Point(-6.9, 39.0),
    math.Point(-6.2, 41.5),
    math.Point(-8.8, 42.0),
    math.Point(-9.2, 43.0),
  ];

  static const List<math.Point<double>> _ukPolygon = [
    math.Point(-5.6, 50.1),
    math.Point(1.4, 51.3),
    math.Point(1.7, 52.7),
    math.Point(-0.1, 54.1),
    math.Point(-1.8, 55.8),
    math.Point(-2.0, 57.7),
    math.Point(-5.0, 58.5),
    math.Point(-5.6, 56.5),
    math.Point(-4.8, 54.8),
    math.Point(-3.1, 53.4),
    math.Point(-5.1, 51.7),
    math.Point(-5.6, 50.1),
  ];

  static final List<SearchableGeoPlaceModel> _placeCatalogList = [
    // =========================================================================
    // COUNTRIES (Stati)
    // =========================================================================
    const SearchableGeoPlaceModel(
      id                : 'country:italy',
      italianName       : 'Italia',
      englishName       : 'Italy',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 6.62,
      minLatitude       : 36.60,
      maxLongitude      : 18.52,
      maxLatitude       : 47.09,
      polygonList       : [
        _italyPeninsulaPolygon,
        _sicilyPolygon,
        _sardiniaPolygon,
      ],
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:france',
      italianName       : 'Francia',
      englishName       : 'France',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : -4.80,
      minLatitude       : 41.35,
      maxLongitude      : 9.56,
      maxLatitude       : 51.09,
      polygonList       : [
        _franceMainlandPolygon,
        _corsicaPolygon,
      ],
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:germany',
      italianName       : 'Germania',
      englishName       : 'Germany',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 6.0,
      minLatitude       : 47.3,
      maxLongitude      : 14.9,
      maxLatitude       : 54.9,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:spain',
      italianName       : 'Spagna',
      englishName       : 'Spain',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : -9.3,
      minLatitude       : 36.0,
      maxLongitude      : 3.3,
      maxLatitude       : 43.8,
      polygonList       : [_spainPolygon],
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:switzerland',
      italianName       : 'Svizzera',
      englishName       : 'Switzerland',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 6.0,
      minLatitude       : 45.8,
      maxLongitude      : 10.5,
      maxLatitude       : 47.8,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:austria',
      italianName       : 'Austria',
      englishName       : 'Austria',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 9.5,
      minLatitude       : 46.4,
      maxLongitude      : 17.1,
      maxLatitude       : 49.0,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:united_kingdom',
      italianName       : 'Regno Unito',
      englishName       : 'United Kingdom',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : -5.7,
      minLatitude       : 50.0,
      maxLongitude      : 1.8,
      maxLatitude       : 58.6,
      polygonList       : [_ukPolygon],
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:portugal',
      italianName       : 'Portogallo',
      englishName       : 'Portugal',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : -9.5,
      minLatitude       : 37.0,
      maxLongitude      : -6.3,
      maxLatitude       : 42.1,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:netherlands',
      italianName       : 'Paesi Bassi',
      englishName       : 'Netherlands',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 3.4,
      minLatitude       : 50.8,
      maxLongitude      : 7.2,
      maxLatitude       : 53.5,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:belgium',
      italianName       : 'Belgio',
      englishName       : 'Belgium',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 2.6,
      minLatitude       : 49.5,
      maxLongitude      : 6.4,
      maxLatitude       : 51.5,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:slovenia',
      italianName       : 'Slovenia',
      englishName       : 'Slovenia',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 13.4,
      minLatitude       : 45.4,
      maxLongitude      : 16.5,
      maxLatitude       : 46.8,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:croatia',
      italianName       : 'Croazia',
      englishName       : 'Croatia',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 13.5,
      minLatitude       : 42.4,
      maxLongitude      : 19.4,
      maxLatitude       : 46.5,
    ),
    const SearchableGeoPlaceModel(
      id                : 'country:greece',
      italianName       : 'Grecia',
      englishName       : 'Greece',
      italianParentLabel: 'Europa',
      englishParentLabel: 'Europe',
      type              : GeoPlaceType.country,
      minLongitude      : 19.6,
      minLatitude       : 35.0,
      maxLongitude      : 26.6,
      maxLatitude       : 41.7,
    ),

    // =========================================================================
    // ITALIAN REGIONS (Tutte le 20 Regioni)
    // =========================================================================
    const SearchableGeoPlaceModel(
      id                : 'region:italy/abruzzo',
      italianName       : 'Abruzzo',
      englishName       : 'Abruzzo',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 13.0,
      minLatitude       : 41.7,
      maxLongitude      : 14.8,
      maxLatitude       : 42.9,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/basilicata',
      italianName       : 'Basilicata',
      englishName       : 'Basilicata',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 15.3,
      minLatitude       : 40.0,
      maxLongitude      : 16.8,
      maxLatitude       : 41.1,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/calabria',
      italianName       : 'Calabria',
      englishName       : 'Calabria',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 15.6,
      minLatitude       : 37.9,
      maxLongitude      : 17.2,
      maxLatitude       : 40.1,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/campania',
      italianName       : 'Campania',
      englishName       : 'Campania',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 13.9,
      minLatitude       : 40.0,
      maxLongitude      : 15.8,
      maxLatitude       : 41.5,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/emilia_romagna',
      italianName       : 'Emilia-Romagna',
      englishName       : 'Emilia-Romagna',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 9.2,
      minLatitude       : 43.8,
      maxLongitude      : 12.7,
      maxLatitude       : 45.1,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/friuli_venezia_giulia',
      italianName       : 'Friuli-Venezia Giulia',
      englishName       : 'Friuli-Venezia Giulia',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 12.3,
      minLatitude       : 45.6,
      maxLongitude      : 13.9,
      maxLatitude       : 46.6,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/lazio',
      italianName       : 'Lazio',
      englishName       : 'Lazio',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 11.5,
      minLatitude       : 41.2,
      maxLongitude      : 14.0,
      maxLatitude       : 42.8,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/liguria',
      italianName       : 'Liguria',
      englishName       : 'Liguria',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 7.5,
      minLatitude       : 43.8,
      maxLongitude      : 10.0,
      maxLatitude       : 44.6,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/lombardia',
      italianName       : 'Lombardia',
      englishName       : 'Lombardy',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 8.5,
      minLatitude       : 44.7,
      maxLongitude      : 11.4,
      maxLatitude       : 46.6,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/marche',
      italianName       : 'Marche',
      englishName       : 'Marche',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 12.2,
      minLatitude       : 42.7,
      maxLongitude      : 13.9,
      maxLatitude       : 43.9,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/molise',
      italianName       : 'Molise',
      englishName       : 'Molise',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 14.0,
      minLatitude       : 41.4,
      maxLongitude      : 15.1,
      maxLatitude       : 42.0,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/piemonte',
      italianName       : 'Piemonte',
      englishName       : 'Piedmont',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 6.7,
      minLatitude       : 44.1,
      maxLongitude      : 8.8,
      maxLatitude       : 46.4,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/puglia',
      italianName       : 'Puglia',
      englishName       : 'Apulia',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 15.0,
      minLatitude       : 39.8,
      maxLongitude      : 18.5,
      maxLatitude       : 41.9,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/sardegna',
      italianName       : 'Sardegna',
      englishName       : 'Sardinia',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 8.1,
      minLatitude       : 38.9,
      maxLongitude      : 9.8,
      maxLatitude       : 41.3,
      polygonList       : [_sardiniaPolygon],
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/sicilia',
      italianName       : 'Sicilia',
      englishName       : 'Sicily',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 12.4,
      minLatitude       : 36.6,
      maxLongitude      : 15.6,
      maxLatitude       : 38.3,
      polygonList       : [_sicilyPolygon],
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/toscana',
      italianName       : 'Toscana',
      englishName       : 'Tuscany',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 9.7,
      minLatitude       : 42.3,
      maxLongitude      : 12.3,
      maxLatitude       : 44.4,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/trentino_alto_adige',
      italianName       : 'Trentino-Alto Adige',
      englishName       : 'Trentino-South Tyrol',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 10.4,
      minLatitude       : 45.7,
      maxLongitude      : 12.4,
      maxLatitude       : 47.0,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/umbria',
      italianName       : 'Umbria',
      englishName       : 'Umbria',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 11.9,
      minLatitude       : 42.4,
      maxLongitude      : 13.2,
      maxLatitude       : 43.6,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/valle_d_aosta',
      italianName       : 'Valle d\'Aosta',
      englishName       : 'Aosta Valley',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 6.8,
      minLatitude       : 45.5,
      maxLongitude      : 7.9,
      maxLatitude       : 45.9,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:italy/veneto',
      italianName       : 'Veneto',
      englishName       : 'Veneto',
      italianParentLabel: 'Italia',
      englishParentLabel: 'Italy',
      type              : GeoPlaceType.region,
      minLongitude      : 10.6,
      minLatitude       : 44.8,
      maxLongitude      : 13.0,
      maxLatitude       : 46.6,
    ),

    // =========================================================================
    // EUROPEAN REGIONS
    // =========================================================================
    const SearchableGeoPlaceModel(
      id                : 'region:france/ile_de_france',
      italianName       : 'Ile-de-France',
      englishName       : 'Ile-de-France',
      italianParentLabel: 'Francia',
      englishParentLabel: 'France',
      type              : GeoPlaceType.region,
      minLongitude      : 1.5,
      minLatitude       : 48.1,
      maxLongitude      : 3.5,
      maxLatitude       : 49.2,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:france/paca',
      italianName       : 'Provenza-Alpi-Costa Azzurra',
      englishName       : 'Provence-Alpes-Cote d\'Azur',
      italianParentLabel: 'Francia',
      englishParentLabel: 'France',
      type              : GeoPlaceType.region,
      minLongitude      : 4.3,
      minLatitude       : 43.1,
      maxLongitude      : 7.6,
      maxLatitude       : 45.0,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:france/corsica',
      italianName       : 'Corsica',
      englishName       : 'Corsica',
      italianParentLabel: 'Francia',
      englishParentLabel: 'France',
      type              : GeoPlaceType.region,
      minLongitude      : 8.5,
      minLatitude       : 41.3,
      maxLongitude      : 9.6,
      maxLatitude       : 43.0,
      polygonList       : [_corsicaPolygon],
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:germany/bavaria',
      italianName       : 'Baviera',
      englishName       : 'Bavaria',
      italianParentLabel: 'Germania',
      englishParentLabel: 'Germany',
      type              : GeoPlaceType.region,
      minLongitude      : 9.0,
      minLatitude       : 47.3,
      maxLongitude      : 13.8,
      maxLatitude       : 50.5,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:spain/catalonia',
      italianName       : 'Catalogna',
      englishName       : 'Catalonia',
      italianParentLabel: 'Spagna',
      englishParentLabel: 'Spain',
      type              : GeoPlaceType.region,
      minLongitude      : 0.2,
      minLatitude       : 40.6,
      maxLongitude      : 3.3,
      maxLatitude       : 42.8,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:spain/andalusia',
      italianName       : 'Andalusia',
      englishName       : 'Andalusia',
      italianParentLabel: 'Spagna',
      englishParentLabel: 'Spain',
      type              : GeoPlaceType.region,
      minLongitude      : -7.5,
      minLatitude       : 36.0,
      maxLongitude      : -1.6,
      maxLatitude       : 38.7,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:switzerland/ticino',
      italianName       : 'Canton Ticino',
      englishName       : 'Ticino',
      italianParentLabel: 'Svizzera',
      englishParentLabel: 'Switzerland',
      type              : GeoPlaceType.region,
      minLongitude      : 8.4,
      minLatitude       : 45.8,
      maxLongitude      : 9.2,
      maxLatitude       : 46.6,
    ),
    const SearchableGeoPlaceModel(
      id                : 'region:austria/tyrol',
      italianName       : 'Tirolo',
      englishName       : 'Tyrol',
      italianParentLabel: 'Austria',
      englishParentLabel: 'Austria',
      type              : GeoPlaceType.region,
      minLongitude      : 10.1,
      minLatitude       : 46.7,
      maxLongitude      : 12.9,
      maxLatitude       : 47.7,
    ),

    // =========================================================================
    // CITIES (Città Italiane ed Internazionali)
    // =========================================================================
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/milano',
      italianName       : 'Milano',
      englishName       : 'Milan',
      italianParentLabel: 'Lombardia, Italia',
      englishParentLabel: 'Lombardy, Italy',
      longitude         : 9.1900,
      latitude          : 45.4642,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/roma',
      italianName       : 'Roma',
      englishName       : 'Rome',
      italianParentLabel: 'Lazio, Italia',
      englishParentLabel: 'Lazio, Italy',
      longitude         : 12.4964,
      latitude          : 41.9028,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/napoli',
      italianName       : 'Napoli',
      englishName       : 'Naples',
      italianParentLabel: 'Campania, Italia',
      englishParentLabel: 'Campania, Italy',
      longitude         : 14.2681,
      latitude          : 40.8518,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/torino',
      italianName       : 'Torino',
      englishName       : 'Turin',
      italianParentLabel: 'Piemonte, Italia',
      englishParentLabel: 'Piedmont, Italy',
      longitude         : 7.6869,
      latitude          : 45.0703,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/firenze',
      italianName       : 'Firenze',
      englishName       : 'Florence',
      italianParentLabel: 'Toscana, Italia',
      englishParentLabel: 'Tuscany, Italy',
      longitude         : 11.2558,
      latitude          : 43.7696,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/bologna',
      italianName       : 'Bologna',
      englishName       : 'Bologna',
      italianParentLabel: 'Emilia-Romagna, Italia',
      englishParentLabel: 'Emilia-Romagna, Italy',
      longitude         : 11.3426,
      latitude          : 44.4949,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/venezia',
      italianName       : 'Venezia',
      englishName       : 'Venice',
      italianParentLabel: 'Veneto, Italia',
      englishParentLabel: 'Veneto, Italy',
      longitude         : 12.3155,
      latitude          : 45.4408,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/genova',
      italianName       : 'Genova',
      englishName       : 'Genoa',
      italianParentLabel: 'Liguria, Italia',
      englishParentLabel: 'Liguria, Italy',
      longitude         : 8.9463,
      latitude          : 44.4056,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/verona',
      italianName       : 'Verona',
      englishName       : 'Verona',
      italianParentLabel: 'Veneto, Italia',
      englishParentLabel: 'Veneto, Italy',
      longitude         : 10.9916,
      latitude          : 45.4384,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/trento',
      italianName       : 'Trento',
      englishName       : 'Trento',
      italianParentLabel: 'Trentino-Alto Adige, Italia',
      englishParentLabel: 'Trentino-South Tyrol, Italy',
      longitude         : 11.1217,
      latitude          : 46.0748,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/bolzano',
      italianName       : 'Bolzano',
      englishName       : 'Bolzano',
      italianParentLabel: 'Trentino-Alto Adige, Italia',
      englishParentLabel: 'Trentino-South Tyrol, Italy',
      longitude         : 11.3548,
      latitude          : 46.4983,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/trieste',
      italianName       : 'Trieste',
      englishName       : 'Trieste',
      italianParentLabel: 'Friuli-Venezia Giulia, Italia',
      englishParentLabel: 'Friuli-Venezia Giulia, Italy',
      longitude         : 13.7768,
      latitude          : 45.6495,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/palermo',
      italianName       : 'Palermo',
      englishName       : 'Palermo',
      italianParentLabel: 'Sicilia, Italia',
      englishParentLabel: 'Sicily, Italy',
      longitude         : 13.3615,
      latitude          : 38.1157,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/catania',
      italianName       : 'Catania',
      englishName       : 'Catania',
      italianParentLabel: 'Sicilia, Italia',
      englishParentLabel: 'Sicily, Italy',
      longitude         : 15.0830,
      latitude          : 37.5079,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/bari',
      italianName       : 'Bari',
      englishName       : 'Bari',
      italianParentLabel: 'Puglia, Italia',
      englishParentLabel: 'Apulia, Italy',
      longitude         : 16.8719,
      latitude          : 41.1171,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/cagliari',
      italianName       : 'Cagliari',
      englishName       : 'Cagliari',
      italianParentLabel: 'Sardegna, Italia',
      englishParentLabel: 'Sardinia, Italy',
      longitude         : 9.1217,
      latitude          : 39.2238,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/perugia',
      italianName       : 'Perugia',
      englishName       : 'Perugia',
      italianParentLabel: 'Umbria, Italia',
      englishParentLabel: 'Umbria, Italy',
      longitude         : 12.3908,
      latitude          : 43.1107,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/ancona',
      italianName       : 'Ancona',
      englishName       : 'Ancona',
      italianParentLabel: 'Marche, Italia',
      englishParentLabel: 'Marche, Italy',
      longitude         : 13.5189,
      latitude          : 43.6158,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/laquila',
      italianName       : 'L\'Aquila',
      englishName       : 'L\'Aquila',
      italianParentLabel: 'Abruzzo, Italia',
      englishParentLabel: 'Abruzzo, Italy',
      longitude         : 13.3995,
      latitude          : 42.3498,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/aosta',
      italianName       : 'Aosta',
      englishName       : 'Aosta',
      italianParentLabel: 'Valle d\'Aosta, Italia',
      englishParentLabel: 'Aosta Valley, Italy',
      longitude         : 7.3131,
      latitude          : 45.7372,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/bergamo',
      italianName       : 'Bergamo',
      englishName       : 'Bergamo',
      italianParentLabel: 'Lombardia, Italia',
      englishParentLabel: 'Lombardy, Italy',
      longitude         : 9.6773,
      latitude          : 45.6983,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/brescia',
      italianName       : 'Brescia',
      englishName       : 'Brescia',
      italianParentLabel: 'Lombardia, Italia',
      englishParentLabel: 'Lombardy, Italy',
      longitude         : 10.2118,
      latitude          : 45.5416,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:italy/padova',
      italianName       : 'Padova',
      englishName       : 'Padua',
      italianParentLabel: 'Veneto, Italia',
      englishParentLabel: 'Veneto, Italy',
      longitude         : 11.8768,
      latitude          : 45.4064,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:france/paris',
      italianName       : 'Parigi',
      englishName       : 'Paris',
      italianParentLabel: 'Ile-de-France, Francia',
      englishParentLabel: 'Ile-de-France, France',
      longitude         : 2.3522,
      latitude          : 48.8566,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:france/lyon',
      italianName       : 'Lione',
      englishName       : 'Lyon',
      italianParentLabel: 'Francia',
      englishParentLabel: 'France',
      longitude         : 4.8357,
      latitude          : 45.7640,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:france/nice',
      italianName       : 'Nizza',
      englishName       : 'Nice',
      italianParentLabel: 'Francia',
      englishParentLabel: 'France',
      longitude         : 7.2620,
      latitude          : 43.7102,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:germany/berlin',
      italianName       : 'Berlino',
      englishName       : 'Berlin',
      italianParentLabel: 'Germania',
      englishParentLabel: 'Germany',
      longitude         : 13.4050,
      latitude          : 52.5200,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:germany/munich',
      italianName       : 'Monaco di Baviera',
      englishName       : 'Munich',
      italianParentLabel: 'Baviera, Germania',
      englishParentLabel: 'Bavaria, Germany',
      longitude         : 11.5820,
      latitude          : 48.1351,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:spain/madrid',
      italianName       : 'Madrid',
      englishName       : 'Madrid',
      italianParentLabel: 'Spagna',
      englishParentLabel: 'Spain',
      longitude         : -3.7038,
      latitude          : 40.4168,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:spain/barcelona',
      italianName       : 'Barcellona',
      englishName       : 'Barcelona',
      italianParentLabel: 'Catalogna, Spagna',
      englishParentLabel: 'Catalonia, Spain',
      longitude         : 2.1734,
      latitude          : 41.3874,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:switzerland/zurich',
      italianName       : 'Zurigo',
      englishName       : 'Zurich',
      italianParentLabel: 'Svizzera',
      englishParentLabel: 'Switzerland',
      longitude         : 8.5417,
      latitude          : 47.3769,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:switzerland/lugano',
      italianName       : 'Lugano',
      englishName       : 'Lugano',
      italianParentLabel: 'Canton Ticino, Svizzera',
      englishParentLabel: 'Ticino, Switzerland',
      longitude         : 8.9511,
      latitude          : 46.0037,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:austria/vienna',
      italianName       : 'Vienna',
      englishName       : 'Vienna',
      italianParentLabel: 'Austria',
      englishParentLabel: 'Austria',
      longitude         : 16.3738,
      latitude          : 48.2082,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:austria/innsbruck',
      italianName       : 'Innsbruck',
      englishName       : 'Innsbruck',
      italianParentLabel: 'Tirolo, Austria',
      englishParentLabel: 'Tyrol, Austria',
      longitude         : 11.4041,
      latitude          : 47.2692,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:uk/london',
      italianName       : 'Londra',
      englishName       : 'London',
      italianParentLabel: 'Regno Unito',
      englishParentLabel: 'United Kingdom',
      longitude         : -0.1276,
      latitude          : 51.5072,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:portugal/lisbon',
      italianName       : 'Lisbona',
      englishName       : 'Lisbon',
      italianParentLabel: 'Portogallo',
      englishParentLabel: 'Portugal',
      longitude         : -9.1393,
      latitude          : 38.7223,
    ),
    SearchableGeoPlaceModel.city(
      id                : 'city:netherlands/amsterdam',
      italianName       : 'Amsterdam',
      englishName       : 'Amsterdam',
      italianParentLabel: 'Paesi Bassi',
      englishParentLabel: 'Netherlands',
      longitude         : 4.9041,
      latitude          : 52.3676,
    ),
  ];
}

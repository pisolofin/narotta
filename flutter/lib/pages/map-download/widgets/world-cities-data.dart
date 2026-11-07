import 'dart:math' as math;

/// Represents a city landmark displayed on the global base map.
class WorldCityModel {
  final String name;
  final double longitude;
  final double latitude;
  final int tier;

  const WorldCityModel({
    required this.name,
    required this.longitude,
    required this.latitude,
    required this.tier,
  });
}

/// Represents an arterial highway corridor displayed on the global base map.
class WorldHighwayModel {
  final String name;
  final List<math.Point<double>> pointList;

  const WorldHighwayModel({
    required this.name,
    required this.pointList,
  });
}

/// Provides curated global and regional cities and arterial highway spines for the offline base map.
class WorldCitiesData {
  /// Returns the list of cities for base map visualization.
  static List<WorldCityModel> getCityList() {
    return _cityList;
  }

  /// Returns the arterial highway spines for base map visualization.
  static List<WorldHighwayModel> getHighwayList() {
    return _highwayList;
  }

  static const List<WorldCityModel> _cityList = [
    // World Capitals & Global Metropolises (Tier 1)
    WorldCityModel(name: 'Roma', longitude: 12.4964, latitude: 41.9028, tier: 1),
    WorldCityModel(name: 'Milano', longitude: 9.1900, latitude: 45.4642, tier: 1),
    WorldCityModel(name: 'Napoli', longitude: 14.2681, latitude: 40.8518, tier: 1),
    WorldCityModel(name: 'Torino', longitude: 7.6869, latitude: 45.0703, tier: 1),
    WorldCityModel(name: 'Parigi', longitude: 2.3522, latitude: 48.8566, tier: 1),
    WorldCityModel(name: 'Londra', longitude: -0.1278, latitude: 51.5074, tier: 1),
    WorldCityModel(name: 'Madrid', longitude: -3.7038, latitude: 40.4168, tier: 1),
    WorldCityModel(name: 'Berlino', longitude: 13.4050, latitude: 52.5200, tier: 1),
    WorldCityModel(name: 'Vienna', longitude: 16.3738, latitude: 48.2082, tier: 1),
    WorldCityModel(name: 'Berna', longitude: 7.4474, latitude: 46.9480, tier: 1),
    WorldCityModel(name: 'Zurigo', longitude: 8.5417, latitude: 47.3769, tier: 1),
    WorldCityModel(name: 'Bruxelles', longitude: 4.3517, latitude: 50.8503, tier: 1),
    WorldCityModel(name: 'Amsterdam', longitude: 4.9041, latitude: 52.3676, tier: 1),
    WorldCityModel(name: 'Lisbona', longitude: -9.1393, latitude: 38.7223, tier: 1),
    WorldCityModel(name: 'Atene', longitude: 23.7275, latitude: 37.9838, tier: 1),
    WorldCityModel(name: 'Stoccolma', longitude: 18.0686, latitude: 59.3293, tier: 1),
    WorldCityModel(name: 'Oslo', longitude: 10.7522, latitude: 59.9139, tier: 1),
    WorldCityModel(name: 'Helsinki', longitude: 24.9384, latitude: 60.1699, tier: 1),
    WorldCityModel(name: 'Copenaghen', longitude: 12.5683, latitude: 55.6761, tier: 1),
    WorldCityModel(name: 'Varsavia', longitude: 21.0122, latitude: 52.2297, tier: 1),
    WorldCityModel(name: 'Praga', longitude: 14.4378, latitude: 50.0755, tier: 1),
    WorldCityModel(name: 'Budapest', longitude: 19.0402, latitude: 47.4979, tier: 1),
    WorldCityModel(name: 'Bucarest', longitude: 26.1025, latitude: 44.4268, tier: 1),
    WorldCityModel(name: 'Dublino', longitude: -6.2603, latitude: 53.3498, tier: 1),
    WorldCityModel(name: 'Washington', longitude: -77.0369, latitude: 38.9072, tier: 1),
    WorldCityModel(name: 'New York', longitude: -74.0060, latitude: 40.7128, tier: 1),
    WorldCityModel(name: 'Los Angeles', longitude: -118.2437, latitude: 34.0522, tier: 1),
    WorldCityModel(name: 'Tokyo', longitude: 139.6917, latitude: 35.6895, tier: 1),
    WorldCityModel(name: 'Pechino', longitude: 116.4074, latitude: 39.9042, tier: 1),
    WorldCityModel(name: 'New Delhi', longitude: 77.2090, latitude: 28.6139, tier: 1),
    WorldCityModel(name: 'Il Cairo', longitude: 31.2357, latitude: 30.0444, tier: 1),
    WorldCityModel(name: 'Sydney', longitude: 151.2093, latitude: -33.8688, tier: 1),
    WorldCityModel(name: 'Buenos Aires', longitude: -58.3816, latitude: -34.6037, tier: 1),
    WorldCityModel(name: 'San Paolo', longitude: -46.6333, latitude: -23.5505, tier: 1),

    // Major Regional Cities and Capoluoghi (Tier 2)
    WorldCityModel(name: 'Firenze', longitude: 11.2558, latitude: 43.7696, tier: 2),
    WorldCityModel(name: 'Bologna', longitude: 11.3426, latitude: 44.4949, tier: 2),
    WorldCityModel(name: 'Venezia', longitude: 12.3155, latitude: 45.4408, tier: 2),
    WorldCityModel(name: 'Genova', longitude: 8.9463, latitude: 44.4056, tier: 2),
    WorldCityModel(name: 'Verona', longitude: 10.9916, latitude: 45.4384, tier: 2),
    WorldCityModel(name: 'Palermo', longitude: 13.3615, latitude: 38.1157, tier: 2),
    WorldCityModel(name: 'Catania', longitude: 15.0873, latitude: 37.5079, tier: 2),
    WorldCityModel(name: 'Bari', longitude: 16.8719, latitude: 41.1171, tier: 2),
    WorldCityModel(name: 'Trieste', longitude: 13.7768, latitude: 45.6495, tier: 2),
    WorldCityModel(name: 'Cagliari', longitude: 9.1217, latitude: 39.2238, tier: 2),
    WorldCityModel(name: 'Ancona', longitude: 13.5189, latitude: 43.6158, tier: 2),
    WorldCityModel(name: 'Perugia', longitude: 12.3908, latitude: 43.1107, tier: 2),
    WorldCityModel(name: 'Trento', longitude: 11.1211, latitude: 46.0748, tier: 2),
    WorldCityModel(name: 'Bolzano', longitude: 11.3548, latitude: 46.4983, tier: 2),
    WorldCityModel(name: 'Reggio Calabria', longitude: 15.6514, latitude: 38.1113, tier: 2),
    WorldCityModel(name: 'Pescara', longitude: 14.2144, latitude: 42.4618, tier: 2),
    WorldCityModel(name: 'Brescia', longitude: 10.2118, latitude: 45.5416, tier: 2),
    WorldCityModel(name: 'Parma', longitude: 10.3279, latitude: 44.8015, tier: 2),
    WorldCityModel(name: 'Livorno', longitude: 10.3106, latitude: 43.5485, tier: 2),
    WorldCityModel(name: 'Padova', longitude: 11.8768, latitude: 45.4064, tier: 2),
    WorldCityModel(name: 'Sassari', longitude: 8.5559, latitude: 40.7259, tier: 2),
    WorldCityModel(name: 'Taranto', longitude: 17.2405, latitude: 40.4644, tier: 2),
  ];

  static const List<WorldHighwayModel> _highwayList = [
    // A1 - Autostrada del Sole (Milano -> Bologna -> Firenze -> Roma -> Napoli)
    WorldHighwayModel(
      name     : 'A1 - Autostrada del Sole',
      pointList: [
        math.Point(9.1900, 45.4642), // Milano
        math.Point(9.6974, 45.0526), // Piacenza
        math.Point(10.3279, 44.8015), // Parma
        math.Point(10.6300, 44.6980), // Reggio Emilia
        math.Point(10.9250, 44.6471), // Modena
        math.Point(11.3426, 44.4949), // Bologna
        math.Point(11.2558, 43.7696), // Firenze
        math.Point(11.8800, 43.4630), // Arezzo
        math.Point(12.1100, 42.7180), // Orvieto
        math.Point(12.4964, 41.9028), // Roma
        math.Point(13.3400, 41.6400), // Frosinone
        math.Point(14.3300, 41.0700), // Caserta
        math.Point(14.2681, 40.8518), // Napoli
      ],
    ),

    // A4 - Serenissima (Torino -> Milano -> Brescia -> Verona -> Venezia -> Trieste)
    WorldHighwayModel(
      name     : 'A4 - Serenissima',
      pointList: [
        math.Point(7.6869, 45.0703), // Torino
        math.Point(8.6200, 45.4469), // Novara
        math.Point(9.1900, 45.4642), // Milano
        math.Point(9.6700, 45.6983), // Bergamo
        math.Point(10.2118, 45.5416), // Brescia
        math.Point(10.9916, 45.4384), // Verona
        math.Point(11.5400, 45.5455), // Vicenza
        math.Point(11.8768, 45.4064), // Padova
        math.Point(12.3155, 45.4408), // Venezia
        math.Point(13.7768, 45.6495), // Trieste
      ],
    ),

    // A14 - Dorsale Adriatica (Bologna -> Rimini -> Ancona -> Pescara -> Bari -> Taranto)
    WorldHighwayModel(
      name     : 'A14 - Dorsale Adriatica',
      pointList: [
        math.Point(11.3426, 44.4949), // Bologna
        math.Point(12.0400, 44.2227), // Forli
        math.Point(12.2400, 44.1390), // Cesena
        math.Point(12.5600, 44.0678), // Rimini
        math.Point(12.9100, 43.9125), // Pesaro
        math.Point(13.5189, 43.6158), // Ancona
        math.Point(13.8800, 42.9550), // San Benedetto
        math.Point(14.2144, 42.4618), // Pescara
        math.Point(15.5500, 41.4622), // Foggia
        math.Point(16.8719, 41.1171), // Bari
        math.Point(17.2405, 40.4644), // Taranto
      ],
    ),

    // A2 - Autostrada del Mediterraneo (Salerno -> Cosenza -> Reggio Calabria)
    WorldHighwayModel(
      name     : 'A2 - Autostrada del Mediterraneo',
      pointList: [
        math.Point(14.2681, 40.8518), // Napoli
        math.Point(14.7681, 40.6824), // Salerno
        math.Point(16.2500, 39.3000), // Cosenza
        math.Point(16.3100, 38.9600), // Lamezia
        math.Point(15.6514, 38.1113), // Reggio Calabria
      ],
    ),

    // A22 - Autostrada del Brennero (Brennero -> Bolzano -> Trento -> Verona -> Modena)
    WorldHighwayModel(
      name     : 'A22 - Brennero',
      pointList: [
        math.Point(11.5050, 47.0060), // Brennero
        math.Point(11.3548, 46.4983), // Bolzano
        math.Point(11.1211, 46.0748), // Trento
        math.Point(10.9916, 45.4384), // Verona
        math.Point(10.7900, 45.1564), // Mantova
        math.Point(10.9250, 44.6471), // Modena
      ],
    ),

    // A10/A12 - Corridoio Ligure-Tirrenico (Ventimiglia -> Genova -> Livorno -> Roma)
    WorldHighwayModel(
      name     : 'A10/A12 - Tirrenica',
      pointList: [
        math.Point(7.6000, 43.7900), // Ventimiglia
        math.Point(8.9463, 44.4056), // Genova
        math.Point(9.8200, 44.1025), // La Spezia
        math.Point(10.3106, 43.5485), // Livorno
        math.Point(11.1100, 42.7600), // Grosseto
        math.Point(11.7900, 42.0900), // Civitavecchia
        math.Point(12.4964, 41.9028), // Roma
      ],
    ),

    // European Corridor: Paris -> Brussels -> Amsterdam
    WorldHighwayModel(
      name     : 'Trans-European North',
      pointList: [
        math.Point(2.3522, 48.8566), // Parigi
        math.Point(3.0573, 50.6292), // Lille
        math.Point(4.3517, 50.8503), // Bruxelles
        math.Point(4.4025, 51.2194), // Anversa
        math.Point(4.4777, 51.9244), // Rotterdam
        math.Point(4.9041, 52.3676), // Amsterdam
      ],
    ),

    // European Corridor: Berlin -> Leipzig -> Nuremberg -> Munich
    WorldHighwayModel(
      name     : 'A9 Germany Spine',
      pointList: [
        math.Point(13.4050, 52.5200), // Berlino
        math.Point(12.3731, 51.3397), // Lipsia
        math.Point(11.0767, 49.4521), // Norimberga
        math.Point(11.5820, 48.1351), // Monaco
      ],
    ),

    // European Corridor: Madrid -> Zaragoza -> Barcelona
    WorldHighwayModel(
      name     : 'A2 Spain Spine',
      pointList: [
        math.Point(-3.7038, 40.4168), // Madrid
        math.Point(-0.8891, 41.6488), // Saragozza
        math.Point(2.1734, 41.3851), // Barcellona
      ],
    ),
  ];
}

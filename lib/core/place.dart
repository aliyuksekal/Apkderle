import 'cities.dart';
import 'settings.dart';

/// Vakit hesabında kullanılan konum.
class Place {
  const Place(this.name, this.lat, this.lng, this.utcOffset);
  final String name;
  final double lat;
  final double lng;
  final Duration utcOffset;

  /// Konumun yerel saatinde "şimdi" (DateTime.utc olarak temsil edilir).
  DateTime nowLocal([DateTime? nowUtc]) =>
      (nowUtc ?? DateTime.now().toUtc()).add(utcOffset);
}

Place? placeFromSettings(AppSettings s) {
  if (s.cityName == 'GPS' && s.gpsLat != null && s.gpsLng != null) {
    return Place(
      'Konumum',
      s.gpsLat!,
      s.gpsLng!,
      DateTime.now().timeZoneOffset,
    );
  }
  final c = cityByName(s.cityName);
  if (c == null) return null;
  return Place(c.name, c.lat, c.lng, kTurkeyOffset);
}

import 'dart:math' as math;

class City {
  const City(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

/// Türkiye saat farkı (2016'dan beri yaz saati uygulaması yok, sabit UTC+3).
const Duration kTurkeyOffset = Duration(hours: 3);

/// 81 il merkezi (yaklaşık koordinatlar). Alfabetik sıralı.
const List<City> kCities = [
  City('Adana', 37.00, 35.32),
  City('Adıyaman', 37.76, 38.28),
  City('Afyonkarahisar', 38.76, 30.54),
  City('Ağrı', 39.72, 43.05),
  City('Aksaray', 38.37, 34.03),
  City('Amasya', 40.65, 35.83),
  City('Ankara', 39.93, 32.86),
  City('Antalya', 36.89, 30.71),
  City('Ardahan', 41.11, 42.70),
  City('Artvin', 41.18, 41.82),
  City('Aydın', 37.85, 27.85),
  City('Balıkesir', 39.65, 27.88),
  City('Bartın', 41.64, 32.34),
  City('Batman', 37.88, 41.13),
  City('Bayburt', 40.26, 40.23),
  City('Bilecik', 40.14, 29.98),
  City('Bingöl', 38.88, 40.50),
  City('Bitlis', 38.40, 42.11),
  City('Bolu', 40.74, 31.61),
  City('Burdur', 37.72, 30.29),
  City('Bursa', 40.19, 29.06),
  City('Çanakkale', 40.15, 26.41),
  City('Çankırı', 40.60, 33.62),
  City('Çorum', 40.55, 34.95),
  City('Denizli', 37.78, 29.09),
  City('Diyarbakır', 37.91, 40.24),
  City('Düzce', 40.84, 31.16),
  City('Edirne', 41.68, 26.56),
  City('Elazığ', 38.68, 39.22),
  City('Erzincan', 39.75, 39.49),
  City('Erzurum', 39.90, 41.27),
  City('Eskişehir', 39.78, 30.52),
  City('Gaziantep', 37.07, 37.38),
  City('Giresun', 40.91, 38.39),
  City('Gümüşhane', 40.46, 39.48),
  City('Hakkari', 37.58, 43.74),
  City('Hatay', 36.20, 36.16),
  City('Iğdır', 39.92, 44.04),
  City('Isparta', 37.76, 30.55),
  City('İstanbul', 41.01, 28.98),
  City('İzmir', 38.42, 27.14),
  City('Kahramanmaraş', 37.58, 36.94),
  City('Karabük', 41.20, 32.62),
  City('Karaman', 37.18, 33.22),
  City('Kars', 40.60, 43.10),
  City('Kastamonu', 41.38, 33.78),
  City('Kayseri', 38.73, 35.48),
  City('Kilis', 36.72, 37.12),
  City('Kırıkkale', 39.85, 33.51),
  City('Kırklareli', 41.73, 27.22),
  City('Kırşehir', 39.15, 34.16),
  City('Kocaeli', 40.77, 29.92),
  City('Konya', 37.87, 32.48),
  City('Kütahya', 39.42, 29.98),
  City('Malatya', 38.35, 38.31),
  City('Manisa', 38.61, 27.43),
  City('Mardin', 37.31, 40.74),
  City('Mersin', 36.81, 34.64),
  City('Muğla', 37.22, 28.36),
  City('Muş', 38.75, 41.49),
  City('Nevşehir', 38.62, 34.71),
  City('Niğde', 37.97, 34.68),
  City('Ordu', 40.98, 37.88),
  City('Osmaniye', 37.07, 36.25),
  City('Rize', 41.02, 40.52),
  City('Sakarya', 40.78, 30.40),
  City('Samsun', 41.29, 36.33),
  City('Siirt', 37.93, 41.94),
  City('Sinop', 42.03, 35.15),
  City('Sivas', 39.75, 37.02),
  City('Şanlıurfa', 37.16, 38.80),
  City('Şırnak', 37.52, 42.46),
  City('Tekirdağ', 40.98, 27.51),
  City('Tokat', 40.31, 36.55),
  City('Trabzon', 41.00, 39.72),
  City('Tunceli', 39.11, 39.55),
  City('Uşak', 38.68, 29.41),
  City('Van', 38.49, 43.38),
  City('Yalova', 40.66, 29.27),
  City('Yozgat', 39.82, 34.81),
  City('Zonguldak', 41.45, 31.79),
];

City? cityByName(String? name) {
  if (name == null) return null;
  for (final c in kCities) {
    if (c.name == name) return c;
  }
  return null;
}

/// Türkçe büyük/küçük harf duyarsız arama.
String trLower(String s) => s
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase();

List<City> searchCities(String q) {
  final n = trLower(q.trim());
  if (n.isEmpty) return kCities;
  return kCities.where((c) => trLower(c.name).contains(n)).toList();
}

// --- Kıble

const double kKaabaLat = 21.4225;
const double kKaabaLng = 39.8262;

/// Coğrafi kuzeye göre kıble açısı (derece, saat yönünde 0–360).
double qiblaBearing(double lat, double lng) {
  double rad(double d) => d * math.pi / 180;
  final phi = rad(lat);
  final kPhi = rad(kKaabaLat);
  final dl = rad(kKaabaLng - lng);
  final y = math.sin(dl);
  final x = math.cos(phi) * math.tan(kPhi) - math.sin(phi) * math.cos(dl);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

String compassPoint(double deg) {
  const names = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
  return names[((deg % 360) / 45).round() % 8];
}

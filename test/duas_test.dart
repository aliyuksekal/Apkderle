import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/duas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Her duanın Arapçası ve Türkçe anlamı var', () async {
    final lib = await loadDuas();
    expect(lib.duas.length, greaterThanOrEqualTo(14));
    for (final d in lib.duas) {
      expect(d.verified, isTrue, reason: d.id);
      expect(d.source, isNotNull, reason: d.id);
      for (final v in d.verses) {
        expect(v.arabic, isNotEmpty, reason: d.id);
        expect(v.meaning, isNotEmpty, reason: d.id);
        expect(v.transliteration, isNotEmpty, reason: d.id);
      }
    }
  });

  test('Ses dosyaları uygulamanın içinde', () async {
    final lib = await loadDuas();
    for (final f in lib.duas.expand((d) => d.audioFiles).toSet()) {
      final data = await rootBundle.load(f);
      expect(data.lengthInBytes, greaterThan(5000), reason: f);
    }
  });

  test('Yâsîn 83 ayet, sırası doğru ve sesli', () async {
    final y = (await loadDuas()).byId('yasin');
    expect(y.verses.length, 83);
    expect(y.verses.first.ayah, 1);
    expect(y.verses.last.ayah, 83);
    expect(y.audioFiles.length, 83);
    expect(y.verses.first.transliteration, 'Yâ sîn');
  });

  test('Namaz duaları: Sübhâneke, Ettehiyyâtü, Salli, Bârik, Kunut', () async {
    final lib = await loadDuas();
    final namaz = lib.duas
        .where((d) => d.category == 'Namaz Duaları')
        .map((d) => d.id);
    expect(
      namaz,
      containsAll([
        'subhaneke',
        'tahiyyat',
        'salli',
        'barik',
        'rabbena_atina',
        'rabbenagfirli',
        'kunut1',
        'kunut2',
      ]),
    );
    expect(lib.byId('rabbenagfirli').hasAudio, isTrue);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/duas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sesli dualar: her ayetin metni, meali ve ses dosyası var', () async {
    final lib = await loadDuas();
    expect(lib.reciter, contains('Husarî'));
    final withAudio = lib.duas.where((d) => d.hasAudio).toList();
    expect(withAudio.length, greaterThanOrEqualTo(7));
    for (final d in withAudio) {
      expect(d.verified, isTrue, reason: d.id);
      expect(d.source, isNotNull, reason: d.id);
      expect(d.transliteration, isNotEmpty, reason: d.id);
      for (final v in d.verses) {
        expect(v.arabic, isNotEmpty);
        expect(v.meaning, isNotEmpty);
        final data = await rootBundle.load(v.audio!);
        expect(
          data.lengthInBytes,
          greaterThan(10000),
          reason: '${d.id} ${v.audio}',
        );
      }
    }
  });

  test('Kaynağı olmayan dua doğrulanmış sayılmaz ve ses çalmaz', () async {
    final lib = await loadDuas();
    final yemek = lib.duas.firstWhere((d) => d.id == 'yemek');
    expect(yemek.verified, isFalse);
    expect(yemek.hasAudio, isFalse);
    expect(yemek.hasText, isFalse);
  });

  test('Sınav duası Tâhâ 25-28, sırası doğru', () async {
    final d = (await loadDuas()).duas.firstWhere((d) => d.id == 'sinav');
    expect(d.verses.map((v) => '${v.surah}:${v.ayah}'), [
      '20:25',
      '20:26',
      '20:27',
      '20:28',
    ]);
    expect(d.audioFiles.first, 'content/audio/husary/020025.mp3');
  });
}

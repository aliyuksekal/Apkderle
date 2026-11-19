import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_asistani/core/zikr.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 19, 10);
  });

  Future<ZikrCounter> make() async =>
      ZikrCounter(await SharedPreferences.getInstance(), clock: () => now);

  test('+1 sayar ve günlük toplamı artırır', () async {
    final z = await make();
    for (var i = 0; i < 5; i++) {
      await z.increment();
    }
    expect(z.count, 5);
    expect(z.todayTotal, 5);
  });

  test('Hedef tam ulaşıldığında bir kez tamamlandı döner', () async {
    final z = await make();
    await z.setTarget(3);
    expect(await z.increment(), isFalse);
    expect(await z.increment(), isFalse);
    expect(await z.increment(), isTrue);
    expect(z.goalReached, isTrue);
    expect(await z.increment(), isFalse); // 4. dokunuş tekrar tetiklemez
  });

  test('Geri al ve sıfırla', () async {
    final z = await make();
    await z.increment();
    await z.increment();
    await z.undo();
    expect(z.count, 1);
    expect(z.todayTotal, 1);
    await z.reset();
    expect(z.count, 0);
    expect(z.todayTotal, 1, reason: 'sıfırlama günlük toplamı silmez');
    await z.undo(); // 0'da geri al etkisiz
    expect(z.count, 0);
  });

  test('Gün değişince bugünkü toplam yeni günden başlar', () async {
    final z = await make();
    await z.increment();
    now = DateTime(2026, 11, 20, 9);
    expect(z.todayTotal, 0);
    await z.increment();
    expect(z.todayTotal, 1);
    expect(z.lastDays(2).map((e) => e.value), [1, 1]);
  });

  test('Durum kalıcı olarak saklanır', () async {
    final z = await make();
    await z.setZikr('Elhamdülillah');
    await z.setTarget(99);
    await z.increment();
    final z2 = await make();
    expect(z2.name, 'Elhamdülillah');
    expect(z2.target, 99);
    expect(z2.count, 1);
    expect(z2.todayTotal, 1);
  });

  test('Binlik ayıracı', () {
    expect(trThousands(1240), '1.240');
    expect(trThousands(999), '999');
    expect(trThousands(1000000), '1.000.000');
  });
}

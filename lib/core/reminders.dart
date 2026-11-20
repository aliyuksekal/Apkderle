import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'place.dart';
import 'prayer_times.dart';

class Medicine {
  Medicine({required this.id, required this.name, required this.times});

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
    id: j['id'] as String,
    name: j['name'] as String,
    times: (j['times'] as List).cast<String>(),
  );

  final String id;
  String name;

  /// "HH:mm" (telefon saatine göre, her gün)
  List<String> times;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'times': times};
}

/// Namaz vakti ve ilaç hatırlatma ayarları (cihazda saklanır).
class ReminderSettings extends ChangeNotifier {
  ReminderSettings(this._p) {
    _load();
  }

  final SharedPreferences _p;
  static const _k = 'reminders_v1';

  /// Bildirim gelecek vakitler.
  Set<PrayerName> prayers = {
    PrayerName.imsak,
    PrayerName.ogle,
    PrayerName.ikindi,
    PrayerName.aksam,
    PrayerName.yatsi,
  };
  bool prayerOn = false;

  /// Vakitten kaç dakika önce (0 = vakit girince).
  int minutesBefore = 0;

  List<Medicine> medicines = [];

  void _load() {
    final raw = _p.getString(_k);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      prayerOn = m['prayerOn'] as bool? ?? false;
      minutesBefore = m['minutesBefore'] as int? ?? 0;
      prayers = ((m['prayers'] as List?) ?? const [])
          .map((e) => PrayerName.values.byName(e as String))
          .toSet();
      medicines = ((m['medicines'] as List?) ?? const [])
          .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> save() async {
    await _p.setString(
      _k,
      jsonEncode({
        'prayerOn': prayerOn,
        'minutesBefore': minutesBefore,
        'prayers': prayers.map((e) => e.name).toList(),
        'medicines': medicines.map((e) => e.toJson()).toList(),
      }),
    );
    notifyListeners();
  }
}

/// Planlanacak tek bildirim (test edilebilir saf veri).
class PlannedNotification {
  const PlannedNotification(
    this.id,
    this.atUtc,
    this.title,
    this.body,
    this.channel,
  );
  final int id;
  final DateTime atUtc;
  final String title;
  final String body;
  final String channel;
}

/// Önümüzdeki [days] gün için bildirim listesini üretir.
List<PlannedNotification> planNotifications({
  required ReminderSettings r,
  required Place? place,
  required DateTime nowUtc,
  int days = 14,
}) {
  final out = <PlannedNotification>[];
  if (r.prayerOn && place != null) {
    final localNow = place.nowLocal(nowUtc);
    for (var d = 0; d < days; d++) {
      final date = DateTime.utc(
        localNow.year,
        localNow.month,
        localNow.day + d,
      );
      final t = PrayerTimes.calculate(
        latitude: place.lat,
        longitude: place.lng,
        date: date,
        utcOffset: place.utcOffset,
      );
      for (final p in PrayerName.values) {
        if (!r.prayers.contains(p)) continue;
        // Yerel temsil → gerçek UTC an
        final at = t[p]
            .subtract(place.utcOffset)
            .subtract(Duration(minutes: r.minutesBefore));
        if (!at.isAfter(nowUtc)) continue;
        final title = p.isPrayer
            ? (r.minutesBefore == 0
                  ? '${p.label} vakti girdi'
                  : '${p.label} vaktine ${r.minutesBefore} dk var')
            : (r.minutesBefore == 0
                  ? 'Güneş doğdu'
                  : 'Güneş doğuşuna ${r.minutesBefore} dk var');
        out.add(
          PlannedNotification(
            d * 10 + p.index,
            at,
            title,
            '${place.name} • ${hhmm(t[p])}',
            'vakit',
          ),
        );
      }
    }
  }
  final localNow = nowUtc.toLocal();
  for (var mi = 0; mi < r.medicines.length && mi < 20; mi++) {
    final m = r.medicines[mi];
    for (var ti = 0; ti < m.times.length && ti < 6; ti++) {
      final parts = m.times[ti].split(':');
      final h = int.parse(parts[0]), min = int.parse(parts[1]);
      for (var d = 0; d < days; d++) {
        final at = DateTime(
          localNow.year,
          localNow.month,
          localNow.day + d,
          h,
          min,
        ).toUtc();
        if (!at.isAfter(nowUtc)) continue;
        out.add(
          PlannedNotification(
            1000 + mi * 200 + ti * 30 + d,
            at,
            'İlaç vakti',
            '${m.name} • ${m.times[ti]}',
            'ilac',
          ),
        );
      }
    }
  }
  return out;
}

/// Android bildirimlerini planlar. Uygulama her açıldığında ve ayar
/// değiştiğinde yeniden kurulur (14 gün ileriye).
class ReminderScheduler {
  ReminderScheduler._();
  static final instance = ReminderScheduler._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_guide'),
      ),
    );
    final a = _android;
    await a?.createNotificationChannel(
      const AndroidNotificationChannel(
        'vakit',
        'Namaz vakitleri',
        description: 'Vakit girince hatırlatma',
        importance: Importance.high,
      ),
    );
    await a?.createNotificationChannel(
      const AndroidNotificationChannel(
        'ilac',
        'İlaç hatırlatma',
        description: 'İlaç saatleri',
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Bildirim ve tam zamanlı alarm izinlerini ister.
  Future<void> requestPermissions() async {
    try {
      await _init();
      await _android?.requestNotificationsPermission();
      if (await _android?.canScheduleExactNotifications() == false) {
        await _android?.requestExactAlarmsPermission();
      }
    } catch (_) {}
  }

  Future<void> reschedule({
    required ReminderSettings r,
    required Place? place,
    required bool enabled,
  }) async {
    try {
      await _init();
      await _plugin.cancelAll();
      if (!enabled) return;
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final mode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      for (final n in planNotifications(
        r: r,
        place: place,
        nowUtc: DateTime.now().toUtc(),
      )) {
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.atUtc, tz.UTC),
          title: n.title,
          body: n.body,
          androidScheduleMode: mode,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              n.channel,
              n.channel == 'vakit' ? 'Namaz vakitleri' : 'İlaç hatırlatma',
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Bildirim planlanamadı: $e');
    }
  }
}

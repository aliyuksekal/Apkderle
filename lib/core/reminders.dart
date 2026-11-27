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
  bool prayerOn = true;

  /// Vakitten kaç dakika önce (0 = vakit girince).
  int minutesBefore = 0;

  List<Medicine> medicines = [];

  /// Vakit bildirimi sesi: 'ezan1', 'ezan2' ya da 'bildirim'.
  String ezanSound = 'ezan1';

  void _load() {
    final raw = _p.getString(_k);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      prayerOn = m['prayerOn'] as bool? ?? true;
      minutesBefore = m['minutesBefore'] as int? ?? 0;
      ezanSound = m['ezanSound'] as String? ?? 'ezan1';
      prayers = ((m['prayers'] as List?) ?? const [])
          .map((e) => PrayerName.values.byName(e as String))
          .toSet();
      medicines = ((m['medicines'] as List?) ?? const [])
          .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  /// İzin bir kez, ilk açılışta istensin.
  bool get permissionAsked => _p.getBool('notif_asked') ?? false;
  Future<void> markPermissionAsked() => _p.setBool('notif_asked', true);

  Future<void> save() async {
    await _p.setString(
      _k,
      jsonEncode({
        'prayerOn': prayerOn,
        'minutesBefore': minutesBefore,
        'ezanSound': ezanSound,
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

  /// Ezan seçenekleri: kanal kimliği, ad, res/raw dosyası.
  static const ezanOptions = <String, (String, String?)>{
    'ezan1': ('Ezan 1', 'ezan1'),
    'ezan2': ('Ezan 2', 'ezan2'),
    'bildirim': ('Kısa bildirim sesi', null),
  };

  static String vakitChannel(String sound) => 'vakit_$sound';

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_guide'),
      ),
    );
    final a = _android;
    for (final e in ezanOptions.entries) {
      final raw = e.value.$2;
      await a?.createNotificationChannel(
        AndroidNotificationChannel(
          vakitChannel(e.key),
          'Namaz vakti — ${e.value.$1}',
          description: 'Vakit girince hatırlatma',
          importance: Importance.max,
          sound: raw == null ? null : RawResourceAndroidNotificationSound(raw),
          audioAttributesUsage: raw == null
              ? AudioAttributesUsage.notification
              : AudioAttributesUsage.alarm,
        ),
      );
    }
    await a?.createNotificationChannel(
      const AndroidNotificationChannel(
        'ilac',
        'İlaç hatırlatma',
        description: 'İlaç saatleri',
        importance: Importance.max,
      ),
    );
    _ready = true;
  }

  NotificationDetails _details(String channel, ReminderSettings r) {
    final isVakit = channel == 'vakit';
    final sound = ezanOptions[r.ezanSound]?.$2;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        isVakit ? vakitChannel(r.ezanSound) : 'ilac',
        isVakit
            ? 'Namaz vakti — ${ezanOptions[r.ezanSound]?.$1 ?? ''}'
            : 'İlaç hatırlatma',
        importance: Importance.max,
        priority: Priority.max,
        category: isVakit
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        sound: isVakit && sound != null
            ? RawResourceAndroidNotificationSound(sound)
            : null,
        audioAttributesUsage: isVakit && sound != null
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  /// Hemen bir deneme bildirimi gösterir (ses ve izin kontrolü için).
  Future<String?> showTest(ReminderSettings r) async {
    try {
      await _init();
      if (await _android?.areNotificationsEnabled() == false) {
        return 'Bildirim izni kapalı. Telefon ayarlarından açın.';
      }
      await _plugin.show(
        id: 9999,
        title: 'Deneme: Öğle vakti girdi',
        body: 'Bildirimler çalışıyor.',
        notificationDetails: _details('vakit', r),
      );
      return null;
    } catch (e) {
      return 'Bildirim gösterilemedi: $e';
    }
  }

  /// 1 dakika sonrasına deneme bildirimi kurar (zamanlama kontrolü için).
  Future<String?> scheduleTest(ReminderSettings r) async {
    try {
      await _init();
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      await _plugin.zonedSchedule(
        id: 9998,
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().toUtc().add(const Duration(minutes: 1)),
          tz.UTC,
        ),
        title: 'Deneme: 1 dakika doldu',
        body: 'Zamanlı bildirimler çalışıyor.',
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: _details('vakit', r),
      );
      return exact
          ? null
          : 'Tam zamanlı alarm izni kapalı; bildirim birkaç dakika gecikebilir.';
    } catch (e) {
      return 'Bildirim kurulamadı: $e';
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Bildirim ve tam zamanlı alarm izinlerini ister.
  /// Yalnızca bildirim izni (uygulama içi pencere; ayarlara atmaz).
  Future<void> requestNotificationPermission() async {
    try {
      await _init();
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Bildirim + tam zamanlı alarm izni. Alarm izni telefon ayarlarını açar;
  /// yalnızca kullanıcı Hatırlatmalar ekranında istediğinde çağrılır.
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
          notificationDetails: _details(n.channel, r),
        );
      }
    } catch (e) {
      debugPrint('Bildirim planlanamadı: $e');
    }
  }
}

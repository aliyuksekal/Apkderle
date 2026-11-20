import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_log.dart';
import 'zikr.dart' show ZikrCounter;

/// "Annem Kıldı Mı?" — aile takibi.
///
/// Paylaşan taraf (örn. anne) bir paylaşım kodu oluşturur; yalnızca son 7
/// günün "kıldım" işaretleri ve adı sunucuya gider. Takip eden taraf kodu
/// girer ve görür. Paylaşım istenildiği an kapatılır (sunucudan silinir).
class FamilyApi {
  static const base = String.fromEnvironment(
    'FAMILY_API',
    defaultValue: 'https://namaz-aile.aliyuksekal.workers.dev',
  );

  static http.Client client = http.Client();

  static Future<bool> push({
    required String code,
    required String secret,
    required String name,
    required Map<String, List<String>> days,
  }) async {
    final r = await client
        .post(
          Uri.parse('$base/v1/share'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'code': code,
            'secret': secret,
            'name': name,
            'days': days,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return r.statusCode == 200;
  }

  static Future<void> delete(String code, String secret) async {
    await client
        .post(
          Uri.parse('$base/v1/unshare'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'code': code, 'secret': secret}),
        )
        .timeout(const Duration(seconds: 15));
  }

  /// null = bulunamadı.
  static Future<FamilyStatus?> fetch(String code) async {
    final r = await client
        .get(Uri.parse('$base/v1/status/${Uri.encodeComponent(code)}'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return FamilyStatus.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}

class FamilyStatus {
  FamilyStatus(this.name, this.days, this.updatedAt);
  factory FamilyStatus.fromJson(Map<String, dynamic> j) => FamilyStatus(
    j['name'] as String? ?? '',
    (j['days'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as List).cast<String>().toSet()),
    ),
    DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int? ?? 0),
  );

  final String name;
  final Map<String, Set<String>> days;
  final DateTime updatedAt;
}

const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String newShareCode([Random? rnd]) {
  final r = rnd ?? Random.secure();
  return List.generate(8, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

String newSecret([Random? rnd]) {
  final r = rnd ?? Random.secure();
  return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
}

/// "K7M2QX9P" → "K7M2-QX9P"
String prettyCode(String c) =>
    c.length == 8 ? '${c.substring(0, 4)}-${c.substring(4)}' : c;

String normalizeCode(String c) =>
    c.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class FollowedPerson {
  FollowedPerson(this.code, this.label);
  final String code;
  String label;
  FamilyStatus? last;
  String? error;
}

/// Aile paylaşımı + takip durumu.
class FamilyStore extends ChangeNotifier {
  FamilyStore(this._p, this.log) {
    _load();
    log.onMarksChanged = () => pushNow();
  }

  final SharedPreferences _p;
  final PrayerLog log;
  static const _k = 'family_v1';

  // Paylaşan taraf
  String? shareCode;
  String? shareSecret;
  String shareName = '';
  bool pushing = false;
  String? pushError;
  DateTime? lastPushOk;

  // Takip eden taraf
  List<FollowedPerson> following = [];

  bool get sharing => shareCode != null;

  void _load() {
    final raw = _p.getString(_k);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      shareCode = m['code'] as String?;
      shareSecret = m['secret'] as String?;
      shareName = m['name'] as String? ?? '';
      following = ((m['following'] as List?) ?? const [])
          .map((e) => FollowedPerson(e['code'] as String, e['label'] as String))
          .toList();
    } catch (_) {}
  }

  Future<void> _save() async {
    await _p.setString(
      _k,
      jsonEncode({
        'code': shareCode,
        'secret': shareSecret,
        'name': shareName,
        'following': [
          for (final f in following) {'code': f.code, 'label': f.label},
        ],
      }),
    );
  }

  Map<String, List<String>> _lastDays() {
    final now = DateTime.now();
    return {
      for (var i = 0; i < 7; i++)
        ZikrCounter.dayKey(DateTime(now.year, now.month, now.day - i)): log
            .marksFor(
              ZikrCounter.dayKey(DateTime(now.year, now.month, now.day - i)),
            )
            .toList(),
    };
  }

  Future<void> startSharing(String name) async {
    shareName = name.trim();
    shareCode ??= newShareCode();
    shareSecret ??= newSecret();
    await _save();
    notifyListeners();
    await pushNow();
  }

  Future<void> rename(String name) async {
    shareName = name.trim();
    await _save();
    await pushNow();
  }

  Future<void> stopSharing() async {
    final c = shareCode, s = shareSecret;
    shareCode = null;
    shareSecret = null;
    await _save();
    notifyListeners();
    if (c != null && s != null) {
      try {
        await FamilyApi.delete(c, s);
      } catch (_) {}
    }
  }

  Future<void> pushNow() async {
    final c = shareCode, s = shareSecret;
    if (c == null || s == null) return;
    pushing = true;
    notifyListeners();
    try {
      final ok = await FamilyApi.push(
        code: c,
        secret: s,
        name: shareName,
        days: _lastDays(),
      );
      pushError = ok ? null : 'Sunucu kabul etmedi';
      if (ok) lastPushOk = DateTime.now();
    } catch (_) {
      pushError = 'İnternet yok — bağlanınca tekrar gönderilir';
    }
    pushing = false;
    notifyListeners();
  }

  Future<String?> follow(String code, String label) async {
    final c = normalizeCode(code);
    if (c.length != 8) return 'Kod 8 karakter olmalı (ör. K7M2-QX9P).';
    if (following.any((f) => f.code == c)) {
      return 'Bu kişiyi zaten takip ediyorsunuz.';
    }
    try {
      final st = await FamilyApi.fetch(c);
      if (st == null) return 'Bu kodla paylaşım bulunamadı. Kodu kontrol edin.';
      final p = FollowedPerson(c, label.trim().isEmpty ? st.name : label.trim())
        ..last = st;
      following.add(p);
      await _save();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Bağlanılamadı. İnternetinizi kontrol edin.';
    }
  }

  Future<void> unfollow(FollowedPerson p) async {
    following.remove(p);
    await _save();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final f in following) {
      try {
        final st = await FamilyApi.fetch(f.code);
        f.last = st;
        f.error = st == null ? 'Paylaşım kapatılmış' : null;
      } catch (_) {
        f.error = 'Bağlanılamadı';
      }
    }
    notifyListeners();
  }
}

/// Bugün hangi vakitlerin kılındığını özetler.
String familySummary(FamilyStatus s, DateTime now) {
  final today = s.days[ZikrCounter.dayKey(now)] ?? const <String>{};
  final done = Farz.values.where((f) => today.contains(f.name)).toList();
  if (done.isEmpty) return 'Bugün henüz işaretleme yok';
  if (done.length == 5) return 'Bugün 5 vaktin hepsini kıldı';
  return 'Bugün ${done.map((f) => f.label).join(', ')} kılındı';
}

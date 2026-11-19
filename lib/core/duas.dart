import 'dart:convert';

import 'package:flutter/services.dart';

class Dua {
  Dua.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        arabic = j['arabic'] as String?,
        transliteration = j['transliteration'] as String?,
        meaning = j['meaning'] as String?,
        audio = j['audio'] as String?,
        source = j['source'] as String?,
        verified = j['verified'] as bool? ?? false;

  final String id;
  final String title;
  final String? arabic;
  final String? transliteration;
  final String? meaning;
  final String? audio;
  final String? source;
  final bool verified;

  bool get hasText =>
      verified && (arabic != null || transliteration != null || meaning != null);
  bool get hasAudio => verified && audio != null;
}

Future<List<Dua>> loadDuas({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString('content/duas.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return (j['duas'] as List)
      .map((e) => Dua.fromJson(e as Map<String, dynamic>))
      .toList();
}

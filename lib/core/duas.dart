import 'dart:convert';

import 'package:flutter/services.dart';

/// Duadaki tek ayet: Arapça metin, meal ve hafız kaydı.
class DuaVerse {
  DuaVerse.fromJson(Map<String, dynamic> j)
    : surah = j['surah'] as int,
      ayah = j['ayah'] as int,
      arabic = j['arabic'] as String,
      meaning = j['meaning'] as String?,
      audio = j['audio'] as String?;

  final int surah;
  final int ayah;
  final String arabic;
  final String? meaning;
  final String? audio;
}

class Dua {
  Dua.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String,
      reference = j['reference'] as String?,
      verses = ((j['verses'] as List?) ?? const [])
          .map((e) => DuaVerse.fromJson(e as Map<String, dynamic>))
          .toList(),
      transliteration = j['transliteration'] as String?,
      source = j['source'] as String?,
      note = j['note'] as String?,
      verified = j['verified'] as bool? ?? false;

  final String id;
  final String title;
  final String? reference;
  final List<DuaVerse> verses;
  final String? transliteration;
  final String? source;
  final String? note;
  final bool verified;

  bool get hasText => verified && verses.isNotEmpty;
  List<String> get audioFiles => verified
      ? [
          for (final v in verses)
            if (v.audio != null) v.audio!,
        ]
      : const [];
  bool get hasAudio => audioFiles.isNotEmpty;
  String get arabic => verses.map((v) => v.arabic).join(' ۝ ');
  String get meaning => verses.map((v) => v.meaning ?? '').join(' ');
}

class DuaLibrary {
  DuaLibrary(this.duas, this.reciter);
  final List<Dua> duas;
  final String reciter;
}

Future<DuaLibrary> loadDuas({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString('content/duas.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return DuaLibrary(
    (j['duas'] as List)
        .map((e) => Dua.fromJson(e as Map<String, dynamic>))
        .toList(),
    j['reciter'] as String? ?? '',
  );
}

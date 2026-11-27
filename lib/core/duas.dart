import 'dart:convert';

import 'package:flutter/services.dart';

/// Duadaki tek parça (ayet ya da dua metni).
class DuaVerse {
  DuaVerse.fromJson(Map<String, dynamic> j)
    : surah = j['surah'] as int?,
      ayah = j['ayah'] as int?,
      arabic = j['arabic'] as String,
      transliteration = j['transliteration'] as String?,
      meaning = j['meaning'] as String?,
      audio = j['audio'] as String?;

  final int? surah;
  final int? ayah;
  final String arabic;
  final String? transliteration;
  final String? meaning;
  final String? audio;
}

class Dua {
  Dua.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String,
      category = j['category'] as String? ?? 'Dualar',
      reference = j['reference'] as String?,
      verses = ((j['verses'] as List?) ?? const [])
          .map((e) => DuaVerse.fromJson(e as Map<String, dynamic>))
          .toList(),
      source = j['source'] as String?,
      note = j['note'] as String?,
      verified = j['verified'] as bool? ?? false;

  final String id;
  final String title;
  final String category;
  final String? reference;
  final List<DuaVerse> verses;
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
}

class DuaLibrary {
  DuaLibrary(this.duas, this.reciter);
  final List<Dua> duas;
  final String reciter;

  /// Kategoriler, dosyadaki sırayla.
  List<String> get categories =>
      <String>{for (final d in duas) d.category}.toList();

  Dua byId(String id) => duas.firstWhere((d) => d.id == id);
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

import 'package:flutter/material.dart';

import '../../core/dua_player.dart';
import '../../core/duas.dart';
import '../widgets.dart';

/// 🔊 düğmesi: normalden biraz büyük, yaşlıların rahat basabileceği boyutta.
class SpeakerButton extends StatelessWidget {
  const SpeakerButton({
    super.key,
    required this.playing,
    required this.enabled,
    required this.onPressed,
    required this.label,
    this.size = 34,
  });

  final bool playing;
  final bool enabled;
  final VoidCallback onPressed;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = playing ? cs.primary : cs.secondary;
    final fg = playing ? cs.onPrimary : cs.onSecondary;
    return Semantics(
      button: true,
      label: playing ? '$label durdur' : '$label dinle',
      excludeSemantics: true,
      child: Material(
        color: enabled ? bg : cs.onSurface.withValues(alpha: .12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: size + 30,
            height: size + 30,
            child: Icon(
              playing ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: size,
              color: enabled ? fg : cs.onSurface.withValues(alpha: .4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kıble + Dua sekmesindeki dua bölümü.
class DuaSection extends StatefulWidget {
  const DuaSection({super.key});

  @override
  State<DuaSection> createState() => _DuaSectionState();
}

class _DuaSectionState extends State<DuaSection> {
  late final Future<DuaLibrary> _future = loadDuas();
  final player = DuaPlayer.instance;

  void _toggle(Dua d) {
    if (player.isPlayingDua(d)) {
      player.stop();
    } else if (d.hasAudio) {
      player.playDua(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<DuaLibrary>(
      future: _future,
      builder: (context, snap) {
        final lib = snap.data;
        if (lib == null) return const SizedBox(height: 120);
        return ListenableBuilder(
          listenable: player,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final cat in lib.categories) ...[
                Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(cat, style: t.titleLarge),
                        ),
                        Text(
                          cat == 'Namaz Duaları'
                              ? 'Okuyan: Hocamız'
                              : 'Okuyan: Hafız ${lib.reciter}',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        for (final d in lib.duas.where(
                          (d) => d.category == cat,
                        ))
                          _DuaRow(
                            dua: d,
                            playing: player.isPlayingDua(d),
                            onOpen: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DuaDetailScreen(
                                  dua: d,
                                  reciter: lib.reciter,
                                ),
                              ),
                            ),
                            onPlay: () => _toggle(d),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DuaRow extends StatelessWidget {
  const _DuaRow({
    required this.dua,
    required this.playing,
    required this.onOpen,
    required this.onPlay,
  });

  final Dua dua;
  final bool playing;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dua.title, style: t.titleMedium),
                  Text(
                    playing
                        ? 'Okunuyor…'
                        : dua.hasAudio
                        ? (dua.reference ?? '')
                        : 'Arapça + anlamı (ses kaydı yok)',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SpeakerButton(
              playing: playing,
              enabled: dua.hasAudio,
              onPressed: onPlay,
              label: dua.title,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dua / sure sayfası: her ayet için Arapça, okunuş, meal ve 🔊.
class DuaDetailScreen extends StatefulWidget {
  const DuaDetailScreen({super.key, required this.dua, required this.reciter});
  final Dua dua;
  final String reciter;

  @override
  State<DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends State<DuaDetailScreen> {
  final player = DuaPlayer.instance;
  late final keys = List.generate(widget.dua.verses.length, (_) => GlobalKey());
  int _shown = -1;

  @override
  void initState() {
    super.initState();
    player.addListener(_follow);
  }

  @override
  void dispose() {
    player.removeListener(_follow);
    super.dispose();
  }

  /// Okunan ayet ekranda görünsün.
  void _follow() {
    if (!player.isPlayingDua(widget.dua)) return;
    final v = player.currentVerse;
    if (v == _shown || v < 0 || v >= keys.length) return;
    _shown = v;
    final ctx = keys[v].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        alignment: .15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dua;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(d.title)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final playing = player.isPlayingDua(d);
            final verse = playing ? player.currentVerse : -1;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (d.reference != null)
                  Text(d.reference!, style: t.titleSmall),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    backgroundColor: cs.secondary,
                    foregroundColor: cs.onSecondary,
                  ),
                  onPressed: d.hasAudio
                      ? () => playing ? player.stop() : player.playDua(d)
                      : null,
                  icon: Icon(
                    playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 38,
                  ),
                  label: Text(
                    d.hasAudio
                        ? (playing ? 'Durdur' : 'Hocadan Dinle')
                        : 'Ses kaydı henüz yok',
                  ),
                ),
                if (d.hasAudio)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      d.category == 'Namaz Duaları'
                          ? 'Okuyan: Hocamız'
                          : 'Okuyan: Hafız ${widget.reciter}',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium,
                    ),
                  ),
                if (d.note != null) ...[
                  const SizedBox(height: 12),
                  NoticeBox(text: d.note!),
                ],
                const SizedBox(height: 12),
                for (var i = 0; i < d.verses.length; i++)
                  _VerseCard(
                    key: keys[i],
                    verse: d.verses[i],
                    number: d.verses.length > 1 ? d.verses[i].ayah : null,
                    active: i == verse,
                    onPlay: d.verses[i].audio == null
                        ? null
                        : () => player.playDua(d, fromVerse: i),
                  ),
                if (d.source != null) ...[
                  const SizedBox(height: 8),
                  Text('Kaynak: ${d.source}', style: t.bodySmall),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    super.key,
    required this.verse,
    required this.number,
    required this.active,
    required this.onPlay,
  });

  final DuaVerse verse;
  final int? number;
  final bool active;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? cs.secondaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: active ? Border.all(color: cs.secondary, width: 3) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (number != null)
                Text('$number. ayet', style: t.titleSmall)
              else
                const SizedBox.shrink(),
              const Spacer(),
              if (onPlay != null)
                SpeakerButton(
                  playing: active,
                  enabled: true,
                  onPressed: active ? DuaPlayer.instance.stop : onPlay!,
                  label: number == null ? 'Dua' : '$number. ayet',
                  size: 30,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            verse.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 30,
              height: 2.0,
              color: cs.onSurface,
            ),
          ),
          if (verse.transliteration != null) ...[
            const SizedBox(height: 6),
            Text('Okunuşu', style: t.titleSmall),
            Text(verse.transliteration!, style: t.bodyLarge),
          ],
          if (verse.meaning != null) ...[
            const SizedBox(height: 8),
            Text('Türkçe anlamı', style: t.titleSmall),
            Text(verse.meaning!, style: t.bodyLarge),
          ],
        ],
      ),
    );
  }
}

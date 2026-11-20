import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/cities.dart';
import '../../core/dua_player.dart';
import '../../core/duas.dart';
import '../../core/native.dart';
import '../../core/place.dart';
import '../../core/vibration_patterns.dart';
import '../app_scope.dart';
import '../widgets.dart';

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key, required this.active});

  /// Sekme görünürken pusula dinlenir (pil tasarrufu).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Kıble + Dua')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final place = placeFromSettings(s);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (place == null)
                  const NoticeBox(
                    text:
                        'Kıble yönünü hesaplamak için önce Ana Sayfa\'dan şehrinizi seçin.',
                    warning: true,
                  )
                else
                  _Compass(place: place, active: active),
                const SizedBox(height: 24),
                const _DuaList(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Compass extends StatefulWidget {
  const _Compass({required this.place, required this.active});
  final Place place;
  final bool active;

  @override
  State<_Compass> createState() => _CompassState();
}

class _CompassState extends State<_Compass> {
  StreamSubscription<CompassReading>? _sub;
  CompassReading? reading;
  bool noSensor = false;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Compass old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active ||
        old.place.lat != widget.place.lat ||
        old.place.lng != widget.place.lng) {
      _sync();
    }
  }

  void _sync() {
    _sub?.cancel();
    _sub = null;
    if (!widget.active) return;
    NativeBridge.instance.setCompassLocation(
      widget.place.lat,
      widget.place.lng,
    );
    _sub = NativeBridge.instance.compass().listen(
      (r) {
        if (!mounted) return;
        final qibla = qiblaBearing(widget.place.lat, widget.place.lng);
        final aligned = (((qibla - r.heading + 540) % 360) - 180).abs() <= 5;
        if (aligned && !_wasAligned && context.settingsRead.vibrationOn) {
          NativeBridge.instance.vibrate(Signal.ruku);
        }
        _wasAligned = aligned;
        setState(() => reading = r);
      },
      onError: (Object e) {
        if (mounted) setState(() => noSensor = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final qibla = qiblaBearing(widget.place.lat, widget.place.lng);
    final q = qibla.round();
    final r = reading;

    if (noSensor || (r == null && !widget.active)) {
      return Column(
        children: [
          _QiblaValue(text: 'Kıble yönü: $q°'),
          const SizedBox(height: 12),
          NoticeBox(
            text: noSensor
                ? 'Bu telefonda pusula algılayıcısı bulunamadı. Kıble, kuzeyden saat yönünde $q° (${compassPoint(qibla)}) yöndedir. Bir pusula veya güneşin konumuyla yönü bulabilirsiniz.'
                : 'Pusula hazırlanıyor…',
            warning: noSensor,
          ),
        ],
      );
    }

    final heading = r?.heading ?? 0;
    final diff = ((qibla - heading + 540) % 360) - 180; // −180…180
    final aligned = r != null && diff.abs() <= 5;
    final String hint;
    if (r == null) {
      hint = 'Pusula hazırlanıyor…';
    } else if (aligned) {
      hint = 'Kıbleye dönüksünüz';
    } else if (diff > 0) {
      hint = 'Sağa dönün (${diff.abs().round()}°)';
    } else {
      hint = 'Sola dönün (${diff.abs().round()}°)';
    }

    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth * 0.85, 320.0);
        return Column(
          children: [
            Semantics(
              liveRegion: true,
              label: 'Kıble yönü $q derece. $hint',
              excludeSemantics: true,
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _DialPainter(
                    heading: heading,
                    qibla: qibla,
                    aligned: aligned,
                    cs: cs,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _QiblaValue(text: 'Kıble yönünüz: $q°'),
            const SizedBox(height: 8),
            Text(
              hint,
              style: t.headlineSmall!.copyWith(
                color: aligned
                    ? (cs.brightness == Brightness.dark
                          ? cs.secondary
                          : cs.primary)
                    : null,
              ),
            ),
            if (r != null && r.needsCalibration) ...[
              const SizedBox(height: 12),
              const NoticeBox(
                warning: true,
                text:
                    'Pusula ayarı zayıf. Telefonu düz tutun ve havada birkaç kez sekiz (8) çizin. Mıknatıs, hoparlör ve metal eşyalardan uzak durun.',
              ),
            ] else ...[
              const SizedBox(height: 12),
              const NoticeBox(
                text:
                    'Telefonu yere paralel, düz tutun. Yön, manyetik sapma düzeltilerek coğrafi kuzeye göre gösterilir.',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QiblaValue extends StatelessWidget {
  const _QiblaValue({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cs.secondary, width: 2),
      ),
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.heading,
    required this.qibla,
    required this.aligned,
    required this.cs,
  });

  final double heading;
  final double qibla;
  final bool aligned;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = cs.primary);
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = aligned ? cs.secondary : cs.secondary.withValues(alpha: .6),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * math.pi / 180);

    // Çentikler
    final tick = Paint()
      ..color = cs.onPrimary.withValues(alpha: .7)
      ..strokeWidth = 2;
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180;
      final long = i % 18 == 0;
      final inner = r - (long ? 26 : 16);
      canvas.drawLine(
        Offset(math.sin(a) * inner, -math.cos(a) * inner),
        Offset(math.sin(a) * (r - 10), -math.cos(a) * (r - 10)),
        tick,
      );
    }

    // Yön harfleri (Türkçe: K, D, G, B)
    const letters = {'K': 0.0, 'D': 90.0, 'G': 180.0, 'B': 270.0};
    letters.forEach((l, deg) {
      final a = deg * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: l,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: r * .16,
            fontWeight: FontWeight.w800,
            color: l == 'K' ? cs.secondary : cs.onPrimary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = Offset(math.sin(a) * (r - 46), -math.cos(a) * (r - 46));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(heading * math.pi / 180); // harfler dik kalsın
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    });

    // Kıble işareti (Kâbe simgesi)
    final qa = qibla * math.pi / 180;
    final qp = Offset(math.sin(qa) * (r * .55), -math.cos(qa) * (r * .55));
    canvas.drawLine(
      Offset.zero,
      qp,
      Paint()
        ..color = cs.secondary
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    final box = Rect.fromCenter(center: qp, width: r * .26, height: r * .26);
    canvas.save();
    canvas.translate(qp.dx, qp.dy);
    canvas.rotate(heading * math.pi / 180);
    canvas.translate(-qp.dx, -qp.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = const Color(0xFF151515),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        box.left,
        box.top + box.height * .28,
        box.width,
        box.height * .14,
      ),
      Paint()..color = const Color(0xFFE9B949),
    );
    canvas.restore();

    canvas.restore();

    // Telefonun baktığı yön (sabit ok, üstte)
    final arrow = Path()
      ..moveTo(c.dx, c.dy - r * .78)
      ..lineTo(c.dx - r * .09, c.dy - r * .52)
      ..lineTo(c.dx + r * .09, c.dy - r * .52)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()..color = aligned ? cs.secondary : cs.onPrimary,
    );
    canvas.drawCircle(c, 8, Paint()..color = cs.secondary);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.heading != heading || old.qibla != qibla || old.aligned != aligned;
}

class _DuaList extends StatefulWidget {
  const _DuaList();

  @override
  State<_DuaList> createState() => _DuaListState();
}

class _DuaListState extends State<_DuaList> {
  late final Future<DuaLibrary> _future = loadDuas();
  final player = DuaPlayer.instance;

  void _toggle(Dua d) {
    if (player.isPlayingDua(d)) {
      player.stop();
    } else if (d.hasAudio) {
      player.playDua(d);
    }
  }

  void _open(Dua d, String reciter) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (c, scroll) => ListenableBuilder(
          listenable: player,
          builder: (c, _) => _DuaDetail(
            dua: d,
            reciter: reciter,
            controller: scroll,
            playing: player.isPlayingDua(d),
            verse: player.isPlayingDua(d) ? player.currentVerse : -1,
            onToggle: () => _toggle(d),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<DuaLibrary>(
      future: _future,
      builder: (context, snap) {
        final lib = snap.data;
        final duas = lib?.duas ?? const <Dua>[];
        return ListenableBuilder(
          listenable: player,
          builder: (context, _) => Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volunteer_activism_rounded,
                        size: 32,
                        color: cs.tertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'En Çok Okunan Dualar',
                            style: t.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (lib != null && lib.reciter.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Okuyan: Hafız ${lib.reciter}',
                        style: t.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < duas.length; i++)
                    _DuaRow(
                      index: i + 1,
                      dua: duas[i],
                      playing: player.isPlayingDua(duas[i]),
                      onOpen: () => _open(duas[i], lib!.reciter),
                      onPlay: () => _toggle(duas[i]),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(68),
                      backgroundColor: cs.secondary,
                      foregroundColor: cs.onSecondary,
                    ),
                    onPressed: duas.any((d) => d.hasAudio)
                        ? () => player.playing
                              ? player.stop()
                              : player.playAll(duas)
                        : null,
                    icon: Icon(
                      player.playing
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      size: 32,
                    ),
                    label: Text(player.playing ? 'Durdur' : 'Duaları Dinle'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DuaRow extends StatelessWidget {
  const _DuaRow({
    required this.index,
    required this.dua,
    required this.playing,
    required this.onOpen,
    required this.onPlay,
  });

  final int index;
  final Dua dua;
  final bool playing;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.brightness == Brightness.dark
        ? cs.secondary
        : cs.tertiary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 68,
      title: Text('$index. ${dua.title}'),
      subtitle: Text(
        playing
            ? 'Okunuyor…'
            : dua.hasAudio
            ? (dua.reference ?? '')
            : 'Ses kaydı henüz yok',
      ),
      onTap: onOpen,
      trailing: IconButton(
        tooltip: playing ? '${dua.title} durdur' : '${dua.title} dinle',
        iconSize: 52,
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        onPressed: dua.hasAudio ? onPlay : null,
        icon: Icon(
          playing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
          color: dua.hasAudio ? accent : cs.onSurface.withValues(alpha: .3),
        ),
      ),
    );
  }
}

class _DuaDetail extends StatelessWidget {
  const _DuaDetail({
    required this.dua,
    required this.reciter,
    required this.controller,
    required this.playing,
    required this.verse,
    required this.onToggle,
  });

  final Dua dua;
  final String reciter;
  final ScrollController controller;
  final bool playing;
  final int verse;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(dua.title, style: t.headlineSmall),
        if (dua.reference != null) Text(dua.reference!, style: t.titleSmall),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            backgroundColor: cs.secondary,
            foregroundColor: cs.onSecondary,
          ),
          onPressed: dua.hasAudio ? onToggle : null,
          icon: Icon(
            playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 38,
          ),
          label: Text(
            dua.hasAudio
                ? (playing ? 'Durdur' : 'Hocadan Dinle')
                : 'Ses kaydı henüz yok',
          ),
        ),
        if (dua.hasAudio)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Okuyan: Hafız $reciter',
              textAlign: TextAlign.center,
              style: t.bodyMedium,
            ),
          ),
        const SizedBox(height: 16),
        if (!dua.hasText)
          NoticeBox(
            warning: true,
            text:
                dua.note ??
                'İçerik doğrulama bekliyor. Metin ve ses kaydı güvenilir kaynaktan eklenecek.',
          )
        else ...[
          for (var i = 0; i < dua.verses.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: i == verse ? cs.secondaryContainer : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dua.verses[i].arabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 30,
                  height: 2.0,
                  color: cs.onSurface,
                ),
              ),
            ),
          if (dua.transliteration != null) ...[
            const SizedBox(height: 8),
            Text('Okunuşu', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(dua.transliteration!, style: t.bodyLarge),
          ],
          const SizedBox(height: 16),
          Text('Anlamı', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(dua.meaning, style: t.bodyLarge),
          if (dua.source != null) ...[
            const SizedBox(height: 16),
            Text('Kaynak: ${dua.source}', style: t.bodySmall),
          ],
        ],
      ],
    );
  }
}

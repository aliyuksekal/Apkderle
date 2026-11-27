import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/cities.dart';
import '../../core/native.dart';
import '../../core/place.dart';
import '../../core/vibration_patterns.dart';
import '../app_scope.dart';
import '../widgets.dart';
import 'dua_screens.dart';

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
                const DuaSection(),
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
        final off = (((qibla - r.heading + 540) % 360) - 180).abs();
        // Gecikmeli eşik: kıbleye girince (≤5°) bir kez güçlü titreşir,
        // 10°'den fazla sapınca yeniden hazır olur.
        if (!_wasAligned && off <= 5) {
          _wasAligned = true;
          if (context.settingsRead.vibrationOn) {
            NativeBridge.instance.vibrate(Signal.qibla, strong: true);
          }
        } else if (_wasAligned && off > 10) {
          _wasAligned = false;
        }
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
    final aligned = r != null && _wasAligned;
    final String hint;
    if (r == null) {
      hint = 'Pusula hazırlanıyor…';
    } else if (aligned) {
      hint = 'Kıble bulundu ✓';
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

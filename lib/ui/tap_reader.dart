import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/native.dart';
import '../core/speech.dart';

/// Büyüklerimiz Modu: dokunulan düğmenin / yazının etiketini sesli okur.
/// Ekranın erişilebilirlik (semantik) ağacından, dokunulan noktadaki en
/// içteki etiketi bulur.
class TapReader extends StatefulWidget {
  const TapReader({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<TapReader> createState() => _TapReaderState();
}

class _TapReaderState extends State<TapReader> {
  SemanticsHandle? _semantics;
  Offset? _down;
  DateTime? _downAt;
  String? _label;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TapReader old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.enabled && _semantics == null) {
      _semantics = SemanticsBinding.instance.ensureSemantics();
      NativeBridge.instance; // olay işleyicisi
    } else if (!widget.enabled && _semantics != null) {
      _semantics!.dispose();
      _semantics = null;
    }
  }

  @override
  void dispose() {
    _semantics?.dispose();
    super.dispose();
  }

  String? _labelAt(Offset logical) {
    final views = RendererBinding.instance.renderViews;
    if (views.isEmpty) return null;
    final root = views.first.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) return null;
    final dpr = View.of(context).devicePixelRatio;
    final p = logical * dpr;
    String? best;
    void visit(SemanticsNode n, Matrix4 parent) {
      final m = n.transform == null ? parent : parent.multiplied(n.transform!);
      final r = MatrixUtils.transformRect(m, n.rect);
      if (!r.contains(p)) return;
      final text = [
        n.label,
        n.value,
      ].where((e) => e.trim().isNotEmpty).join(', ');
      if (text.isNotEmpty) best = text;
      n.visitChildren((c) {
        visit(c, m);
        return true;
      });
    }

    visit(root, Matrix4.identity());
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _down = e.position;
        _downAt = DateTime.now();
        // Dokunuş anındaki etiket (sayfa değişmeden önce).
        _label = _labelAt(e.position);
      },
      onPointerUp: (e) {
        final d = _down, t = _downAt, label = _label;
        _down = null;
        if (d == null || t == null || label == null) return;
        final isTap =
            (e.position - d).distance < 24 &&
            DateTime.now().difference(t) < const Duration(milliseconds: 800);
        if (isTap) Speech.instance.speak(label.replaceAll('\n', '. '));
      },
      child: widget.child,
    );
  }
}

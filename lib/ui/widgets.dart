import 'package:flutter/material.dart';

/// Ana eylem butonu: büyük, ikon + metin, en az 72 dp yükseklik.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onPressed,
    this.gold = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = gold ? cs.secondary : cs.primary;
    final fg = gold ? cs.onSecondary : cs.onPrimary;
    return Semantics(
      button: true,
      label: subtitle == null ? label : '$label. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 40, color: fg),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall!.copyWith(color: fg),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(color: fg),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 36, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçim kutusu (tek seçim) — büyük, tamamen dokunulabilir.
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.primary : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? cs.secondary : cs.outlineVariant,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 32,
                  color: selected ? cs.secondary : cs.onSurface,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: selected ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: selected ? cs.onPrimary : cs.onSurface,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bilgi / uyarı kutusu.
class NoticeBox extends StatelessWidget {
  const NoticeBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.warning = false,
  });

  final String text;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning ? cs.secondaryContainer : cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : icon,
            size: 30,
            color: warning ? cs.onSecondaryContainer : cs.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: warning
                    ? cs.onSecondaryContainer
                    : cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onay penceresi (sıfırlama/silme gibi geri alınamaz işlemler için).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String yes = 'Evet',
  String no = 'Vazgeç',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: Theme.of(c).textTheme.headlineSmall),
      content: Text(message, style: Theme.of(c).textTheme.bodyLarge),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(no),
        ),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../theme.dart';
import 'app_logo.dart';

/// The white (or dark) rounded panel most screens are built from.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: context.colors.card, borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

/// The small header at the top of each tab: the mark and "Oh baby baby!".
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 20, color: context.colors.ink)),
    );
  }
}

/// An entry type's icon in its tinted circle.
class TypeIcon extends StatelessWidget {
  const TypeIcon(this.type, {super.key, this.size = 44, this.icon});

  final EntryType type;
  final double size;

  /// Overrides the type's usual icon, e.g. a bath for a bath routine.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.tintFor(type);
    final outlined = type == EntryType.other;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : tint.bg,
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: context.colors.ink, width: 1.5) : null,
      ),
      child: Icon(icon ?? iconFor(type), size: size * 0.48, color: tint.fg),
    );
  }
}

/// A circular button with a soft fill, for chevrons and steppers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.size = 44});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? c.pill : c.pill.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, color: enabled ? c.ink : c.muted.withValues(alpha: 0.5), size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// "QUICK ADD", "APPEARANCE": a small spaced capital label above a section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: context.colors.muted),
    );
  }
}

/// "36 m breastfed": a soft pill with an icon, a bold value and a word.
class SummaryPill extends StatelessWidget {
  const SummaryPill({super.key, required this.type, required this.value, required this.label});

  final EntryType type;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.pill, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(type), size: 18, color: c.tintFor(type).line),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                TextSpan(text: ' $label', style: TextStyle(color: c.muted)),
              ]),
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of pill segments ("Week | Month", "Match phone | Light | Dark").
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.selected, required this.onChanged, this.expand = false});

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Stretch the segments across the width instead of fitting their text.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final keys = options.keys.toList();
    Widget segment(T key) {
      final on = key == selected;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          onTap: () => onChanged(key),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: expand ? 6 : 16, vertical: 9),
            color: on ? c.selected : Colors.transparent,
            child: Text(
              options[key]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: c.selected, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1.5, thickness: 1.5, color: c.selected),
              if (expand) Expanded(child: segment(keys[i])) else segment(keys[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// The baby's photo, or the mark on a soft blue circle.
class BabyAvatar extends StatelessWidget {
  const BabyAvatar({super.key, this.photo, this.size = 52});

  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A3530) : const Color(0xFFD5E3EA),
        border: Border.all(color: c.card, width: size > 80 ? 0 : 2),
        image: photo == null ? null : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: photo == null ? AppMark(size: size * 0.62) : null,
    );
  }
}

/// A dialog with one text field. Resolves to the text, or null when cancelled.
/// It owns its controller, so the field outlives the closing animation.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? suffix,
  String done = 'Done',
  int maxLength = 80,
  TextInputType? keyboardType,
  TextCapitalization capitalization = TextCapitalization.none,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        initial: initial,
        hint: hint,
        suffix: suffix,
        done: done,
        maxLength: maxLength,
        keyboardType: keyboardType,
        capitalization: capitalization,
      ),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.done,
    required this.maxLength,
    required this.capitalization,
    this.hint,
    this.suffix,
    this.keyboardType,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? suffix;
  final String done;
  final int maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.capitalization,
        decoration: InputDecoration(hintText: widget.hint, suffixText: widget.suffix, counterText: ''),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(widget.done)),
      ],
    );
  }
}

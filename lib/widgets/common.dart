import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

// ------------------------------------------------------------------ โทนสี
enum Tone { accent, high, mid, low, blue, gray }

const _toneFg = [AppColors.accent, AppColors.high, AppColors.mid, AppColors.low, AppColors.blue, AppColors.muted];
const _toneBg = [AppColors.accentSoft, AppColors.highSoft, AppColors.midSoft, AppColors.lowSoft, AppColors.blueSoft, AppColors.graySoft];

Color toneFg(Tone t) => _toneFg[t.index];
Color toneBg(Tone t) => _toneBg[t.index];
Tone priorityTone(Priority p) => const [Tone.low, Tone.mid, Tone.high][p.index];
Tone statusTone(ActivityStatus s) => const [Tone.gray, Tone.blue, Tone.low][s.index];
Tone riskTone(Risk r) => const [Tone.low, Tone.mid, Tone.high][r.index];

Color optionColor(String code) => code == 'A' ? AppColors.accent : (code == 'B' ? AppColors.blue : AppColors.mid);
Color optionSoft(String code) => code == 'A' ? AppColors.accentSoft : (code == 'B' ? AppColors.blueSoft : AppColors.midSoft);

// ------------------------------------------------------------ การนำทาง
/// กลับไปหน้าหลักและเปิดแท็บที่ต้องการ (0 หน้าหลัก, 1 กิจกรรม, 2 ตาราง, 3 รายงาน)
void goHomeTab(BuildContext context, int tab) {
  appState.homeTab.value = tab;
  Navigator.of(context).popUntil(ModalRoute.withName(Routes.home));
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirmText = 'ยืนยัน', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText, style: TextStyle(color: danger ? AppColors.high : AppColors.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ------------------------------------------------------------ หัวหน้าจอ
PreferredSizeWidget appHeader(String title, {String? subtitle, List<Widget>? actions, bool back = true}) {
  return AppBar(
    automaticallyImplyLeading: back,
    titleSpacing: back ? 0 : 20,
    toolbarHeight: subtitle == null ? 60 : 72,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppText.title, overflow: TextOverflow.ellipsis),
        if (subtitle != null) Text(subtitle, style: AppText.muted, overflow: TextOverflow.ellipsis),
      ],
    ),
    actions: actions,
  );
}

/// แถบปุ่มด้านล่างของหน้าจอ
Widget bottomBar(List<Widget> children) {
  return SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(children: children),
    ),
  );
}

// ------------------------------------------------------------ ส่วนประกอบ
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(size / 3.5)),
      child: Icon(Icons.more_time_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.accent, this.icon});
  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: toneBg(tone), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: toneFg(tone)), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: toneFg(tone))),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = AppColors.line,
    this.borderWidth = 1,
    this.color = AppColors.surface,
    this.radius = 16,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double borderWidth;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

enum ButtonVariant { primary, ghost, danger, white }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.expand = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    switch (variant) {
      case ButtonVariant.primary:
        bg = AppColors.accent;
        fg = Colors.white;
        border = AppColors.accent;
        break;
      case ButtonVariant.ghost:
        bg = AppColors.surface;
        fg = AppColors.ink;
        border = AppColors.line;
        break;
      case ButtonVariant.danger:
        bg = AppColors.surface;
        fg = AppColors.high;
        border = const Color(0xFFE8C7B8);
        break;
      case ButtonVariant.white:
        bg = Colors.white;
        fg = AppColors.accent;
        border = Colors.white;
        break;
    }
    final disabled = onPressed == null;
    final style = TextButton.styleFrom(
      backgroundColor: disabled ? AppColors.graySoft : bg,
      foregroundColor: fg,
      disabledForegroundColor: AppColors.muted,
      minimumSize: expand ? Size.fromHeight(height) : Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: disabled ? AppColors.line : border),
      textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
    );
    return TextButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          // ปุ่มแบบเต็มความกว้างอยู่ในพื้นที่ที่มีขอบเขตเสมอ จึงใช้ Flexible ได้อย่างปลอดภัย
          if (expand)
            Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))
          else
            Text(label, textAlign: TextAlign.center, maxLines: 1),
        ],
      ),
    );
  }
}

class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: AppText.h2)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppText.label),
      );
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 18, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

/// ปุ่มแบ่งส่วน (segmented control) ตามต้นแบบ
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.height = 40,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.segmentBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o == value ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: o == value ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))] : null,
                    ),
                    child: Text(
                      labelOf(o),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                        color: o == value ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text, this.tone = Tone.accent, this.textColor});
  final IconData icon;
  final String text;
  final Tone tone;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: toneBg(tone), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: toneFg(tone)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: textColor ?? toneFg(tone)))),
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.color = AppColors.accent, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        backgroundColor: AppColors.graySoft,
        color: color,
      ),
    );
  }
}

class StepperBox extends StatelessWidget {
  const StepperBox({super.key, required this.label, this.onMinus, this.onPlus});
  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    Widget square(IconData icon, VoidCallback? f, String tip) => SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            onPressed: f,
            tooltip: tip,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF0EEE8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(icon, size: 18),
          ),
        );
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          square(Icons.remove, onMinus, 'ลด'),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: AppText.bodyStrong)),
          square(Icons.add, onPlus, 'เพิ่ม'),
        ],
      ),
    );
  }
}

class PickerBox extends StatelessWidget {
  const PickerBox({super.key, required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          Icon(icon, size: 18, color: AppColors.muted),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar(this.name, {super.key, this.radius = 22});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.avatar,
      child: Text(
        name.trim().isEmpty ? '?' : (name.trim().length >= 2 ? name.trim().substring(0, 2) : name.trim()),
        style: TextStyle(fontSize: radius * 0.72, fontWeight: FontWeight.w700, color: AppColors.accent),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(title, style: AppText.bodyStrong, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(message, style: AppText.muted, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// แถวข้อความ label ซ้าย / ค่า ขวา พร้อมเส้นคั่นด้านล่าง
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.last = false});
  final String label;
  final Widget value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.muted)),
          const SizedBox(width: 8),
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}

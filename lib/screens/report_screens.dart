import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 6.3.10 หน้ารายงานสรุป (Output 2.6)
class ReportTab extends StatefulWidget {
  const ReportTab({super.key});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  int _range = 7;
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final from = s.today.subtract(Duration(days: _range - 1));
        final done = s.activities
            .where((a) => a.status == ActivityStatus.done && a.completedAt != null && !a.completedAt!.isBefore(from))
            .toList();
        final pending = s.pending.length;
        final completion = (done.length + pending) == 0 ? 0 : (done.length / (done.length + pending) * 100).round();
        final planned = done.fold<int>(0, (x, a) => x + a.minutes);
        final actual = done.fold<int>(0, (x, a) => x + (a.actualMinutes ?? a.minutes));
        final postponed = s.postponeCounts.values.fold<int>(0, (x, v) => x + v);
        final rated = done.where((a) => a.feedbackGood != null).toList();
        final good = rated.where((a) => a.feedbackGood == true).length;

        final byType = <ActivityType, List<int>>{for (final t in ActivityType.values) t: [0, 0]};
        for (final a in done) {
          byType[a.type]![0] += a.minutes;
          byType[a.type]![1] += a.actualMinutes ?? a.minutes;
        }
        final bars = [
          for (final t in ActivityType.values) _BarGroup(t.label, byType[t]![0] / 60, byType[t]![1] / 60),
        ];

        ActivityType? worst;
        var worstPct = 0;
        for (final t in ActivityType.values) {
          final p = byType[t]![0];
          if (p == 0) continue;
          final pct = ((byType[t]![1] - p) / p * 100).round();
          if (pct > worstPct) {
            worst = t;
            worstPct = pct;
          }
        }
        final insight = worst == null
            ? 'ช่วงนี้คุณใช้เวลาได้ตามที่ประเมินไว้ ระบบจะคงรูปแบบการจัดสรรเวลาเดิม'
            : 'งานประเภท “${worst.label}” ใช้เวลาจริงมากกว่าที่ประเมินไว้ $worstPct% ครั้งต่อไประบบจะเผื่อเวลาให้อัตโนมัติ';

        final topPostponed = s.postponeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: appHeader(
            'รายงานสรุป',
            subtitle: '${dateShort(from)} – ${dateWithYear(s.today)}',
            back: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton.outlined(
                  tooltip: 'ส่งออกรายงาน',
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface, side: const BorderSide(color: AppColors.line)),
                  onPressed: () => showSnack(context, 'ส่งออกรายงาน (PDF) — ฟังก์ชันจำลองในต้นแบบ'),
                  icon: const Icon(Icons.download_outlined),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Segmented<int>(
                options: const [7, 30],
                value: _range,
                labelOf: (v) => v == 7 ? '7 วันล่าสุด' : '30 วันล่าสุด',
                onChanged: (v) => setState(() => _range = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Kpi(value: '$completion%', label: 'กิจกรรมสำเร็จ', sub: '${done.length} จาก ${done.length + pending} รายการ')),
                const SizedBox(width: 10),
                Expanded(child: _Kpi(value: '${fmtHours(actual / 60)} ชม.', label: 'เวลาที่ใช้จริง', sub: 'วางแผนไว้ ${fmtHours(planned / 60)} ชม.')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _Kpi(
                    value: '$postponed ครั้ง',
                    label: 'กิจกรรมที่ถูกเลื่อน',
                    sub: topPostponed.isEmpty ? '—' : 'มากสุด: ${topPostponed.first.key}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _Kpi(value: '$good / ${rated.length}', label: 'คำแนะนำที่เหมาะสม', sub: 'จาก Feedback ของคุณ')),
              ]),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เวลาที่วางแผน vs ใช้จริง (ชั่วโมง)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Row(children: [
                      _Legend(color: AppColors.chartPlanned, label: 'วางแผน'),
                      SizedBox(width: 16),
                      _Legend(color: AppColors.chartActual, label: 'ใช้จริง'),
                    ]),
                    const SizedBox(height: 8),
                    if (_table)
                      _ReportTable(bars: bars)
                    else
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: Semantics(
                          label: 'กราฟแท่งเปรียบเทียบเวลาที่วางแผนกับเวลาที่ใช้จริงตามประเภทกิจกรรม',
                          child: CustomPaint(painter: _BarChartPainter(bars)),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: LinkText(_table ? 'ดูเป็นกราฟ' : 'ดูเป็นตาราง', onTap: () => setState(() => _table = !_table)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoBanner(icon: Icons.auto_awesome, textColor: AppColors.ink, text: 'ข้อสังเกตจาก AI: $insight'),
              const SizedBox(height: 18),
              const SectionTitle('กิจกรรมที่ถูกเลื่อนบ่อย'),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: topPostponed.isEmpty
                    ? const Padding(padding: EdgeInsets.all(10), child: Text('ยังไม่มีกิจกรรมที่ถูกเลื่อน', style: AppText.muted))
                    : Column(
                        children: [
                          for (var i = 0; i < math.min(3, topPostponed.length); i++)
                            KeyValueRow(
                              topPostponed[i].key,
                              Text('${topPostponed[i].value} ครั้ง', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              last: i == math.min(3, topPostponed.length) - 1,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              AppButton('ดูประวัติการวางแผน', variant: ButtonVariant.ghost, icon: Icons.history, onPressed: () => Navigator.pushNamed(context, Routes.history)),
            ],
          ),
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.sub});
  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
          Text(sub, style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppText.small),
      ],
    );
  }
}

class _BarGroup {
  const _BarGroup(this.label, this.planned, this.actual);
  final String label;
  final double planned;
  final double actual;
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.bars});
  final List<_BarGroup> bars;

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {bool bold = false, TextAlign align = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t, textAlign: align, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
      border: const TableBorder(horizontalInside: BorderSide(color: AppColors.line)),
      children: [
        TableRow(children: [
          cell('ประเภท', bold: true, align: TextAlign.left),
          cell('วางแผน', bold: true),
          cell('ใช้จริง', bold: true),
          cell('ต่าง', bold: true),
        ]),
        for (final b in bars)
          TableRow(children: [
            cell(b.label, align: TextAlign.left),
            cell(fmtHours(b.planned)),
            cell(fmtHours(b.actual)),
            cell('${b.actual - b.planned >= 0 ? '+' : ''}${fmtHours(b.actual - b.planned)}'),
          ]),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(this.bars);
  final List<_BarGroup> bars;

  TextPainter _text(String t, double size, Color color, {FontWeight weight = FontWeight.w400}) {
    return TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const top = 14.0;
    const bottomLabel = 24.0;
    final chartH = size.height - top - bottomLabel;
    var maxV = 1.0;
    for (final b in bars) {
      maxV = math.max(maxV, math.max(b.planned, b.actual));
    }
    final step = (maxV / 3).ceilToDouble().clamp(1.0, 1000.0).toDouble();
    final niceMax = step * 3;

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = step * i;
      final y = top + chartH - v / niceMax * chartH;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final tp = _text(fmtHours(v), 10, AppColors.muted);
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    final groupW = (size.width - left) / bars.length;
    final barW = math.min(24.0, groupW / 3);
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final cx = left + groupW * i + groupW / 2;
      final values = [b.planned, b.actual];
      final colors = [AppColors.chartPlanned, AppColors.chartActual];
      for (var j = 0; j < 2; j++) {
        final v = values[j];
        final h = v / niceMax * chartH;
        final x = j == 0 ? cx - barW - 1 : cx + 1;
        final y = top + chartH - h;
        if (h > 0) {
          final r = RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          );
          canvas.drawRRect(r, Paint()..color = colors[j]);
        }
        final tp = _text(fmtHours(v), 10, AppColors.muted);
        tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, y - tp.height - 2));
      }
      final lp = _text(b.label, 12, AppColors.ink);
      lp.paint(canvas, Offset(cx - lp.width / 2, top + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => oldDelegate.bars != bars;
}

/// 6.3.10 หน้าประวัติการวางแผน (FR-16)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DecisionKind? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final all = appState.history;
        final list = all.where((h) => _filter == null || h.kind == _filter).toList();
        return Scaffold(
          appBar: appHeader('ประวัติการวางแผน', subtitle: 'การตัดสินใจทั้งหมด ${all.length} ครั้ง'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Segmented<DecisionKind?>(
                options: const [null, DecisionKind.accepted, DecisionKind.adjusted, DecisionKind.rejected],
                value: _filter,
                labelOf: (v) => v == null ? 'ทั้งหมด' : v.label,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty) const EmptyState(icon: Icons.history, title: 'ไม่มีประวัติในหมวดนี้', message: 'ประวัติจะถูกบันทึกเมื่อคุณเลือก ปรับ หรือปฏิเสธแผน'),
              for (final h in list) _HistoryItem(entry: h),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final h = entry;
    final color = h.optionCode == null ? AppColors.muted : optionColor(h.optionCode!);
    final soft = h.optionCode == null ? AppColors.graySoft : optionSoft(h.optionCode!);
    final Tone resultTone;
    if (h.result == 'กำลังดำเนินการ') {
      resultTone = Tone.blue;
    } else if (h.result.startsWith('สำเร็จ')) {
      resultTone = Tone.low;
    } else {
      resultTone = Tone.gray;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('${dateWithDow(h.time)} · ${timeOf(h.time)}', style: AppText.muted)),
                    Pill(h.result, tone: resultTone),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(6)),
                    child: Text(h.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(height: 6),
                  Text(h.detail, style: AppText.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6.3.11 หน้าข้อมูลส่วนตัว (FR-01)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: appState.userName);
    final mail = TextEditingController(text: appState.email);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขข้อมูลส่วนตัว'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้')),
            const SizedBox(height: 10),
            TextField(controller: mail, decoration: const InputDecoration(labelText: 'อีเมล')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (ok == true) appState.updateProfile(name.text, mail.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        return Scaffold(
          appBar: appHeader('ข้อมูลส่วนตัว'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  UserAvatar(s.userName, radius: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.userName, style: AppText.title),
                        Text(s.email, style: AppText.muted),
                        Text('สมาชิกตั้งแต่ ${dateWithYear(s.joined)}', style: AppText.small),
                      ],
                    ),
                  ),
                  IconButton.outlined(tooltip: 'แก้ไขข้อมูลส่วนตัว', onPressed: () => _edit(context), icon: const Icon(Icons.edit_outlined)),
                ],
              ),
              const _Label('บัญชี'),
              _menu([
                _MenuRow(icon: Icons.person_outline, title: 'แก้ไขชื่อผู้ใช้และอีเมล', onTap: () => _edit(context)),
                _MenuRow(icon: Icons.lock_outline, title: 'เปลี่ยนรหัสผ่าน', onTap: () => showSnack(context, 'ส่งลิงก์เปลี่ยนรหัสผ่านไปที่ ${s.email} แล้ว')),
                _MenuRow(icon: Icons.track_changes, title: 'เป้าหมายและเวลาว่าง', onTap: () => Navigator.pushNamed(context, Routes.setup, arguments: true)),
              ]),
              const _Label('การใช้งาน'),
              _menu([
                _MenuRow(icon: Icons.notifications_none, title: 'การแจ้งเตือน', onTap: () => Navigator.pushNamed(context, Routes.notifications)),
                _MenuRow(icon: Icons.history, title: 'ประวัติการวางแผน', onTap: () => Navigator.pushNamed(context, Routes.history)),
                _MenuRow(
                  icon: Icons.auto_awesome,
                  title: 'ให้ AI เรียนรู้จากประวัติของฉัน',
                  trailing: Switch(value: s.aiLearn, onChanged: s.setAiLearn),
                ),
              ]),
              const _Label('ความเป็นส่วนตัวและข้อมูล'),
              _menu([
                _MenuRow(icon: Icons.download_outlined, title: 'ดาวน์โหลดข้อมูลของฉัน', onTap: () => showSnack(context, 'กำลังเตรียมไฟล์ข้อมูล — ฟังก์ชันจำลองในต้นแบบ')),
                _MenuRow(
                  icon: Icons.delete_outline,
                  title: 'ลบบัญชีและข้อมูลทั้งหมด',
                  danger: true,
                  onTap: () async {
                    final ok = await confirmDialog(context, title: 'ลบบัญชี', message: 'ข้อมูลกิจกรรมและประวัติทั้งหมดจะถูกลบ ต้องการดำเนินการต่อหรือไม่?', confirmText: 'ลบบัญชี', danger: true);
                    if (ok && context.mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false);
                  },
                ),
              ]),
              const _Label('สำหรับการสาธิต'),
              _menu([
                _MenuRow(icon: Icons.admin_panel_settings_outlined, title: 'หน้าผู้ดูแลระบบ', onTap: () => Navigator.pushNamed(context, Routes.admin)),
              ]),
              const SizedBox(height: 16),
              AppButton(
                'ออกจากระบบ',
                variant: ButtonVariant.ghost,
                icon: Icons.logout,
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menu(List<_MenuRow> rows) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(indent: 12, endIndent: 12),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, this.onTap, this.trailing, this.danger = false});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.high : AppColors.ink;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? AppColors.high : AppColors.muted),
      title: Text(title, style: TextStyle(fontSize: 15, color: color)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.muted),
      minVerticalPadding: 12,
    );
  }
}

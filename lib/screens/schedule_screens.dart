import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 6.3.8 หน้าตารางเวลา (FR-13)
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _week = false;
  late DateTime _selected = appState.today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final monday = s.today.subtract(Duration(days: s.today.weekday - 1));
        final days = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
        final sunday = days.last;
        final isToday = daysBetween(_selected, s.today) == 0;
        return Scaffold(
          appBar: appHeader(
            'ตารางเวลา',
            subtitle: '${dateShort(monday)} – ${dateShort(sunday)} ${sunday.year + 543}',
            back: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 150,
                  child: Segmented<bool>(
                    options: const [false, true],
                    value: _week,
                    height: 34,
                    labelOf: (v) => v ? 'สัปดาห์' : 'วัน',
                    onChanged: (v) => setState(() => _week = v),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Row(
                children: [
                  for (final d in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _DayButton(
                          date: d,
                          selected: daysBetween(d, _selected) == 0,
                          onTap: () => setState(() {
                            _selected = d;
                            _week = false;
                          }),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_week)
                for (final d in days) _weekRow(d)
              else if (!isToday)
                EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'ยังไม่มีแผนสำหรับ${dateWithDow(_selected)}',
                  message: s.activeDays.contains(_selected.weekday)
                      ? 'ระบบวางแผนเป็นรายวัน กลับมาขอคำแนะนำจาก AI ในวันนั้น'
                      : 'วันนี้ไม่ได้ตั้งเป็นวันที่มีเวลาว่าง',
                )
              else if (s.plan.isEmpty)
                EmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'ยังไม่มีแผนสำหรับวันนี้',
                  message: 'เลือกทางเลือกจาก AI แล้วระบบจะสร้างตารางเวลาให้อัตโนมัติ',
                  action: AppButton('ขอคำแนะนำจาก AI', icon: Icons.auto_awesome, onPressed: () => Navigator.pushNamed(context, Routes.askAi)),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill('แผน: ทางเลือก ${s.planCode}${s.planAdjusted ? ' (ปรับแล้ว)' : ''}'),
                    if (s.planConfirmedAt != null) Text('ยืนยันเมื่อ ${timeOf(s.planConfirmedAt!)} น.', style: AppText.muted),
                  ],
                ),
                const SizedBox(height: 12),
                DayTimeline(blocks: s.plan, slots: s.slots),
                const SizedBox(height: 4),
                const Text('แตะที่กิจกรรมเพื่อบันทึกผลการทำจริง', style: AppText.small),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _weekRow(DateTime d) {
    final s = appState;
    final today = daysBetween(d, s.today) == 0;
    final total = s.plan.fold<int>(0, (x, b) => x + b.minutes);
    final String detail;
    if (today && s.plan.isNotEmpty) {
      detail = '${s.plan.length} กิจกรรม · ${duration(total)}';
    } else if (!s.activeDays.contains(d.weekday)) {
      detail = 'ไม่ได้ตั้งเวลาว่าง';
    } else {
      detail = 'เวลาว่าง ${duration(s.freeMinutes)} · ยังไม่มีแผน';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        borderColor: today ? AppColors.accent : AppColors.line,
        onTap: () => setState(() {
          _selected = d;
          _week = false;
        }),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(dateWithDow(d), style: AppText.label)),
            Expanded(child: Text(detail, style: AppText.muted)),
            if (today) const Pill('วันนี้'),
          ],
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.date, required this.selected, required this.onTap});
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: selected ? AppColors.accent : AppColors.surface,
      borderColor: selected ? AppColors.accent : AppColors.line,
      onTap: onTap,
      child: Column(
        children: [
          Text(thaiDaysShort[date.weekday - 1], style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.muted)),
          Text('${date.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
        ],
      ),
    );
  }
}

/// ไทม์ไลน์รายวัน 08:00–22:00
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.blocks, required this.slots});
  final List<PlanBlock> blocks;
  final List<TimeSlot> slots;

  static const startHour = 8;
  static const endHour = 22;
  static const hourHeight = 48.0;
  static const topPad = 10.0;

  double _y(int minute) => topPad + (minute - startHour * 60) / 60 * hourHeight;

  @override
  Widget build(BuildContext context) {
    final nowTime = DateTime.now();
    final nowMin = nowTime.hour * 60 + nowTime.minute;
    return SizedBox(
      height: _y(endHour * 60) + 12,
      child: Stack(
        children: [
          for (var h = startHour; h <= endHour; h++)
            Positioned(
              top: _y(h * 60) - 9,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  SizedBox(width: 50, child: Text('${two(h)}:00', style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5))),
                  Expanded(child: Container(height: 1, color: AppColors.line)),
                ],
              ),
            ),
          for (final s in slots)
            if (s.end > startHour * 60 && s.start < endHour * 60)
              Positioned(
                top: _y(s.start),
                height: s.minutes / 60 * hourHeight,
                left: 56,
                right: 0,
                child: Container(decoration: BoxDecoration(color: const Color(0x140E6B63), borderRadius: BorderRadius.circular(10))),
              ),
          for (final b in blocks) _block(context, b),
          if (nowMin >= startHour * 60 && nowMin <= endHour * 60)
            Positioned(
              top: _y(nowMin) - 5,
              left: 50,
              right: 0,
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.high, shape: BoxShape.circle)),
                  Expanded(child: Container(height: 2, color: AppColors.high)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, PlanBlock b) {
    final a = appState.byId(b.activityId);
    final height = b.minutes / 60 * hourHeight - 4;
    final done = a?.status == ActivityStatus.done;
    final bg = done ? AppColors.low : AppColors.accent;
    final compact = height < 44;
    final time = '${hm(b.start)}–${hm(b.end)}';
    return Positioned(
      top: _y(b.start) + 2,
      height: height < 20 ? 20 : height,
      left: 60,
      right: 4,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: a == null ? null : () => Navigator.pushNamed(context, Routes.track, arguments: a.id),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 2 : 6),
            child: compact
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${a?.name ?? ''} · $time', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(
                        done ? '$time · เสร็จแล้ว' : (appState.notifyBefore ? '$time · แจ้งเตือนก่อน ${appState.settings.reminderMinutes} นาที' : time),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// หน้าการแจ้งเตือน (Output 2.5)
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _icons = {
    NoticeKind.reminder: (Icons.schedule, Tone.accent),
    NoticeKind.planChanged: (Icons.refresh, Tone.blue),
    NoticeKind.deadline: (Icons.flag_outlined, Tone.high),
    NoticeKind.logResult: (Icons.edit_note, Tone.mid),
    NoticeKind.report: (Icons.bar_chart_rounded, Tone.low),
  };

  void _open(BuildContext context, AppNotice n) {
    appState.markRead(n);
    final route = n.route;
    if (route == null) return;
    if (route.startsWith('tab:')) {
      goHomeTab(context, int.parse(route.substring(4)));
    } else if (route.startsWith('track:')) {
      Navigator.pushNamed(context, Routes.track, arguments: route.substring(6));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final today = s.notices.where((n) => daysBetween(n.time, s.now) == 0).toList();
        final earlier = s.notices.where((n) => daysBetween(n.time, s.now) != 0).toList();
        return Scaffold(
          appBar: appHeader(
            'การแจ้งเตือน',
            actions: [TextButton(onPressed: s.unreadCount == 0 ? null : s.markAllRead, child: const Text('อ่านทั้งหมด'))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (s.notifyBefore && s.plan.isNotEmpty) ...[
                const _GroupLabel('การแจ้งเตือนที่ตั้งไว้'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < s.plan.length; i++)
                        KeyValueRow(
                          '${hm((s.plan[i].start - s.settings.reminderMinutes).clamp(0, 24 * 60).toInt())} น.',
                          Text('ก่อนเริ่ม “${s.byId(s.plan[i].activityId)?.name ?? ''}”', style: AppText.label),
                          last: i == s.plan.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
              if (today.isNotEmpty) ...[const _GroupLabel('วันนี้'), for (final n in today) _tile(context, n)],
              if (earlier.isNotEmpty) ...[const _GroupLabel('ก่อนหน้านี้'), for (final n in earlier) _tile(context, n)],
              const _GroupLabel('ตั้งค่าการแจ้งเตือน'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    _switchRow('แจ้งเตือนก่อนเริ่มกิจกรรม ${s.settings.reminderMinutes} นาที', s.notifyBefore, s.setNotifyBefore),
                    const Divider(),
                    _switchRow('แจ้งเมื่อแผนมีการเปลี่ยนแปลง', s.notifyChange, s.setNotifyChange),
                    const Divider(),
                    _switchRow('เตือนให้บันทึกผลหลังจบกิจกรรม', s.notifyLog, s.setNotifyLog),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _tile(BuildContext context, AppNotice n) {
    final meta = _icons[n.kind] ?? (Icons.notifications_none, Tone.gray);
    final tone = meta.$2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: n.unread ? AppColors.surface : Colors.transparent,
        borderColor: n.unread ? AppColors.line : Colors.transparent,
        padding: const EdgeInsets.all(14),
        onTap: () => _open(context, n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: toneBg(tone), borderRadius: BorderRadius.circular(12)),
              child: Icon(meta.$1, size: 20, color: toneFg(tone)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    Text(timeOf(n.time), style: AppText.small),
                  ]),
                  const SizedBox(height: 2),
                  Text(n.body, style: AppText.muted),
                ],
              ),
            ),
            if (n.unread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
      );
}

/// 6.3.9 หน้าติดตามผลและบันทึกเวลาจริง / Feedback (FR-14, FR-15)
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  bool _initialized = false;
  Activity? _activity;
  int _planned = 60;
  int _actual = 60;
  ActivityStatus _status = ActivityStatus.done;
  bool? _good;
  final _note = TextEditingController();
  Timer? _timer;
  int _seconds = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    final a = id == null ? null : appState.byId(id);
    _activity = a;
    if (a != null) {
      _planned = appState.plannedMinutesFor(a.id);
      _actual = a.actualMinutes ?? _planned;
      _status = a.status == ActivityStatus.todo ? ActivityStatus.done : a.status;
      _good = a.feedbackGood;
      _note.text = a.feedbackNote;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() {
        _timer = null;
        _actual = (_seconds / 60).ceil().clamp(1, 24 * 60).toInt();
      });
      return;
    }
    setState(() {
      _seconds = 0;
      _status = ActivityStatus.inProgress;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    });
  }

  void _save() {
    final a = _activity;
    if (a == null) return;
    _timer?.cancel();
    appState.recordResult(a.id, status: _status, actualMinutes: _actual, good: _good, note: _note.text.trim());
    showSnack(context, 'บันทึกผลแล้ว ระบบจะใช้ข้อมูลนี้ปรับคำแนะนำครั้งถัดไป');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;
    if (a == null) {
      return Scaffold(appBar: appHeader('บันทึกผลกิจกรรม'), body: const Center(child: Text('ไม่พบกิจกรรม')));
    }
    final blocks = appState.plan.where((b) => b.activityId == a.id).toList();
    final range = blocks.isEmpty ? '' : ' · ${blocks.map((b) => '${hm(b.start)}–${hm(b.end)}').join(', ')}';
    final diff = _actual - _planned;
    final diffText = diff > 0 ? 'มากกว่าแผน ${duration(diff)}' : (diff < 0 ? 'น้อยกว่าแผน ${duration(-diff)}' : 'ตรงตามแผน');
    final diffColor = diff > 0 ? AppColors.high : (diff < 0 ? AppColors.low : AppColors.muted);
    final running = _timer != null;

    Widget bigTime(String label, int minutes, String sub, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.small),
              Text('${minutes ~/ 60}:${two(minutes % 60)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color, height: 1.3)),
              Text(sub, style: TextStyle(fontSize: 12, color: color == AppColors.ink ? AppColors.muted : color)),
            ],
          ),
        );

    return Scaffold(
      appBar: appHeader('บันทึกผลกิจกรรม', subtitle: '${a.name}$range'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const FieldLabel('สถานะ'),
          Segmented<ActivityStatus>(
            options: ActivityStatus.values,
            value: _status,
            height: 44,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bigTime('เวลาที่วางแผน', _planned, 'ชั่วโมง', AppColors.ink),
                    bigTime('เวลาที่ใช้จริง', _actual, diffText, diffColor == AppColors.muted ? AppColors.ink : diffColor),
                  ],
                ),
                const SizedBox(height: 14),
                const FieldLabel('แก้ไขเวลาที่ใช้จริง'),
                StepperBox(
                  label: duration(_actual),
                  onMinus: _actual > 5 && !running ? () => setState(() => _actual -= 5) : null,
                  onPlus: !running ? () => setState(() => _actual += 5) : null,
                ),
                const SizedBox(height: 10),
                AppButton(
                  running ? 'หยุดจับเวลา (${two(_seconds ~/ 60)}:${two(_seconds % 60)})' : 'ใช้ตัวจับเวลาแทนการกรอกเอง',
                  variant: ButtonVariant.ghost,
                  icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  height: 44,
                  onPressed: _toggleTimer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('คำแนะนำของ AI ครั้งนี้เหมาะสมหรือไม่'),
          Row(
            children: [
              Expanded(child: _FeedbackButton(label: 'เหมาะสม', icon: Icons.thumb_up_alt_outlined, selected: _good == true, onTap: () => setState(() => _good = true))),
              const SizedBox(width: 8),
              Expanded(child: _FeedbackButton(label: 'ไม่เหมาะสม', icon: Icons.thumb_down_alt_outlined, selected: _good == false, negative: true, onTap: () => setState(() => _good = false))),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(label: 'ความคิดเห็นเพิ่มเติม', controller: _note, hint: 'เช่น เนื้อหาเยอะกว่าที่คิด ครั้งหน้าควรเผื่อเวลา', maxLines: 2),
        ],
      ),
      bottomNavigationBar: bottomBar([Expanded(child: AppButton('บันทึกผล', icon: Icons.check, onPressed: _save))]),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({required this.label, required this.icon, required this.selected, required this.onTap, this.negative = false});
  final String label;
  final IconData icon;
  final bool selected;
  final bool negative;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = negative ? Tone.high : Tone.low;
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        radius: 12,
        padding: const EdgeInsets.symmetric(vertical: 13),
        color: selected ? toneBg(tone) : AppColors.surface,
        borderColor: selected ? toneFg(tone) : AppColors.line,
        borderWidth: selected ? 1.5 : 1,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? toneFg(tone) : AppColors.ink),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? toneFg(tone) : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

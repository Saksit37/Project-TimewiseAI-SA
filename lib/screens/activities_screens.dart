import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// รายการกิจกรรม (FR-02, FR-14)
class ActivitiesTab extends StatefulWidget {
  const ActivitiesTab({super.key});

  @override
  State<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<ActivitiesTab> {
  String _query = '';
  ActivityStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final list = s.activities.where((a) {
          if (_filter != null && a.status != _filter) return false;
          if (_query.isNotEmpty && !a.name.toLowerCase().contains(_query.toLowerCase())) return false;
          return true;
        }).toList()
          ..sort((a, b) {
            final st = a.status.index == 2 ? 1 : 0;
            final st2 = b.status.index == 2 ? 1 : 0;
            if (st != st2) return st.compareTo(st2);
            return a.deadline.compareTo(b.deadline);
          });
        return Scaffold(
          appBar: appHeader(
            'กิจกรรมของฉัน',
            subtitle: '${s.activities.length} รายการ · รอทำ ${s.pending.length}',
            back: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filled(
                  tooltip: 'เพิ่มกิจกรรม',
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pushNamed(context, Routes.activityForm),
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'ค้นหากิจกรรม', prefixIcon: Icon(Icons.search, color: AppColors.muted)),
              ),
              const SizedBox(height: 10),
              Segmented<ActivityStatus?>(
                options: const [null, ActivityStatus.todo, ActivityStatus.inProgress, ActivityStatus.done],
                value: _filter,
                labelOf: (v) => v == null ? 'ทั้งหมด' : v.label,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                const EmptyState(icon: Icons.inbox_outlined, title: 'ไม่พบกิจกรรม', message: 'ลองเปลี่ยนตัวกรอง หรือกดปุ่ม + เพื่อเพิ่มกิจกรรมใหม่')
              else
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ActivityCard(activity: a, now: s.now),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity, required this.now});
  final Activity activity;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    Widget iconText(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 15, color: AppColors.muted), const SizedBox(width: 4), Text(text, style: AppText.muted)],
        );
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.pushNamed(context, Routes.activityForm, arguments: a.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(a.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Pill(a.status.label, tone: statusTone(a.status)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              iconText(Icons.schedule, duration(a.minutes)),
              iconText(Icons.flag_outlined, a.recurring ? 'ทุกวัน' : '${dateShort(a.deadline)} ${timeOf(a.deadline)}'),
              Text(a.type.label, style: AppText.muted),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Pill('ความสำคัญ${a.priority.label}', tone: priorityTone(a.priority)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.status == ActivityStatus.done
                      ? 'ใช้เวลาจริง ${duration(a.actualMinutes ?? a.minutes)}'
                      : (a.recurring ? 'ประจำ' : relativeDeadline(a.deadline, now)),
                  style: AppText.small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 6.3.3 หน้าเพิ่ม/แก้ไขกิจกรรม พร้อม Deadline และความสำคัญ (FR-02 – FR-04)
class ActivityFormScreen extends StatefulWidget {
  const ActivityFormScreen({super.key});

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _initialized = false;
  Activity? _editing;
  ActivityType _type = ActivityType.study;
  int _minutes = 60;
  late DateTime _deadline;
  Priority _priority = Priority.medium;
  String _goal = '';
  bool _recurring = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    _editing = id == null ? null : appState.byId(id);
    final e = _editing;
    if (e != null) {
      _name.text = e.name;
      _note.text = e.note;
      _type = e.type;
      _minutes = e.minutes;
      _deadline = e.deadline;
      _priority = e.priority;
      _goal = e.goal;
      _recurring = e.recurring;
    } else {
      final n = appState.now;
      _deadline = DateTime(n.year, n.month, n.day + 1, 17, 0);
      _goal = appState.goals.isEmpty ? '' : appState.goals.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(_deadline.year - 1),
      lastDate: DateTime(appState.now.year + 2),
    );
    if (d == null) return;
    setState(() => _deadline = DateTime(d.year, d.month, d.day, _deadline.hour, _deadline.minute));
  }

  Future<void> _pickTime() async {
    final t = await pickTime(context, TimeOfDay(hour: _deadline.hour, minute: _deadline.minute));
    if (t == null) return;
    setState(() => _deadline = DateTime(_deadline.year, _deadline.month, _deadline.day, t.hour, t.minute));
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final e = _editing;
    if (e != null) {
      e
        ..name = _name.text.trim()
        ..type = _type
        ..minutes = _minutes
        ..deadline = _deadline
        ..priority = _priority
        ..goal = _goal
        ..recurring = _recurring
        ..note = _note.text.trim();
      appState.saveActivity(e);
    } else {
      appState.saveActivity(Activity(
        id: appState.newId(),
        name: _name.text.trim(),
        type: _type,
        minutes: _minutes,
        deadline: _deadline,
        priority: _priority,
        goal: _goal,
        recurring: _recurring,
        note: _note.text.trim(),
      ));
    }
    showSnack(context, e == null ? 'เพิ่มกิจกรรมแล้ว' : 'บันทึกการแก้ไขแล้ว');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final e = _editing;
    if (e == null) return;
    final ok = await confirmDialog(context, title: 'ลบกิจกรรม', message: 'ต้องการลบ “${e.name}” หรือไม่?', confirmText: 'ลบ', danger: true);
    if (!ok || !mounted) return;
    appState.deleteActivity(e.id);
    showSnack(context, 'ลบกิจกรรมแล้ว');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final goals = <String>['', ...appState.allGoals];
    if (!goals.contains(_goal)) goals.add(_goal);
    return Scaffold(
      appBar: appHeader(_editing == null ? 'เพิ่มกิจกรรม' : 'แก้ไขกิจกรรม'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            LabeledField(
              label: 'ชื่อกิจกรรม',
              controller: _name,
              hint: 'เช่น อ่านหนังสือสอบ',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อกิจกรรม' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('ประเภทกิจกรรม'),
            Segmented<ActivityType>(
              options: ActivityType.values,
              value: _type,
              labelOf: (t) => t.label,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 14),
            const FieldLabel('ระยะเวลาที่คาดว่าจะใช้'),
            Row(
              children: [
                Expanded(
                  child: StepperBox(
                    label: '${_minutes ~/ 60} ชั่วโมง',
                    onMinus: _minutes - 60 >= 15 ? () => setState(() => _minutes -= 60) : null,
                    onPlus: _minutes + 60 <= 12 * 60 ? () => setState(() => _minutes += 60) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StepperBox(
                    label: '${_minutes % 60} นาที',
                    onMinus: _minutes - 15 >= 15 ? () => setState(() => _minutes -= 15) : null,
                    onPlus: _minutes + 15 <= 12 * 60 ? () => setState(() => _minutes += 15) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Deadline'),
            Row(
              children: [
                Expanded(child: PickerBox(icon: Icons.calendar_today_outlined, text: dateWithYear(_deadline), onTap: _pickDate)),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: PickerBox(icon: Icons.schedule, text: timeOf(_deadline), onTap: _pickTime)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('กิจกรรมประจำ (ทำทุกวัน)', style: AppText.body)),
                Switch(value: _recurring, onChanged: (v) => setState(() => _recurring = v)),
              ],
            ),
            const SizedBox(height: 8),
            const FieldLabel('ความสำคัญ'),
            Row(
              children: [
                for (final p in Priority.values) ...[
                  if (p != Priority.low) const SizedBox(width: 8),
                  Expanded(child: _PriorityButton(priority: p, selected: _priority == p, onTap: () => setState(() => _priority = p))),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('เป้าหมายที่เกี่ยวข้อง'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _goal,
                  items: [for (final g in goals) DropdownMenuItem(value: g, child: Text(g.isEmpty ? 'ไม่ระบุ' : g))],
                  onChanged: (v) => setState(() => _goal = v ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(label: 'หมายเหตุ (ไม่บังคับ)', controller: _note, maxLines: 3),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar([
        if (_editing != null) ...[
          AppButton('ลบ', variant: ButtonVariant.danger, icon: Icons.delete_outline, expand: false, onPressed: _delete),
          const SizedBox(width: 10),
        ],
        Expanded(child: AppButton('บันทึกกิจกรรม', icon: Icons.check, onPressed: _save)),
      ]),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  const _PriorityButton({required this.priority, required this.selected, required this.onTap});
  final Priority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = priorityTone(priority);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? toneBg(tone) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? toneFg(tone) : AppColors.line, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(child: Text(priority.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: toneFg(tone)))),
          ),
        ),
      ),
    );
  }
}

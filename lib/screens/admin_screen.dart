import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 6.4 ส่วนผู้ดูแลระบบ
/// 0 ภาพรวม · 1 จัดการผู้ใช้งาน · 2 สถานะระบบ · 3 บันทึกข้อผิดพลาด · 4 ตั้งค่าระบบ
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _page = 0;

  // ผู้ใช้งาน
  String _query = '';
  String? _userFilter;

  // บันทึกข้อผิดพลาด
  String? _levelFilter;
  bool _pendingOnly = false;

  // ตั้งค่าระบบ (ฉบับร่างก่อนกดบันทึก)
  SystemSettings? _draft;

  static const _pages = ['ภาพรวม', 'จัดการผู้ใช้งาน', 'สถานะระบบ', 'บันทึกข้อผิดพลาด', 'ตั้งค่าระบบ'];

  void _go(int page, bool wide) {
    setState(() {
      _page = page;
      if (page == 4) _draft = appState.settings.copy();
    });
    if (!wide) Navigator.pop(context); // ปิด drawer
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final content = ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            switch (_page) {
              case 1:
                return _usersPage(context);
              case 2:
                return _statusPage(context);
              case 3:
                return _logsPage(context);
              case 4:
                return _settingsPage(context);
              default:
                return _overviewPage(context);
            }
          },
        );
        final sidebar = ListenableBuilder(
          listenable: appState,
          builder: (context, _) => _Sidebar(
            page: _page,
            pendingLogs: appState.logs.where((l) => l.pending).length,
            onSelect: (p) => _go(p, wide),
            onLogout: () => Navigator.pushNamedAndRemoveUntil(context, Routes.login, (r) => false),
          ),
        );
        return Scaffold(
          appBar: wide ? null : AppBar(title: Text('ผู้ดูแลระบบ · ${_pages[_page]}', style: AppText.title)),
          drawer: wide ? null : Drawer(child: sidebar),
          body: wide ? Row(children: [SizedBox(width: 250, child: sidebar), Expanded(child: content)]) : content,
        );
      },
    );
  }

  // ================================================================== ภาพรวม
  Widget _overviewPage(BuildContext context) {
    final s = appState;
    final users = s.users;
    final newUsers = users.where((u) => daysBetween(u.joined, s.now) <= 7).length;
    final activeUsers = users.where((u) => u.status == 'ใช้งาน').length;
    final avgLatency = s.aiLatency.reduce((a, b) => a + b) / s.aiLatency.length;
    final decided = s.history.length;
    final accepted = s.history.where((h) => h.kind != DecisionKind.rejected).length;
    final rated = s.activities.where((a) => a.feedbackGood != null).toList();
    final good = rated.where((a) => a.feedbackGood == true).length;
    final pending = s.logs.where((l) => l.pending).toList();
    final week = [...s.aiRequestsWeek, s.aiRequestsToday];
    final weekLabels = [for (var i = 6; i >= 0; i--) dateShort(s.today.subtract(Duration(days: i)))];

    final chart = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('จำนวนคำขอวิเคราะห์จาก AI (7 วันล่าสุด)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const Text('นับจากการกด “วิเคราะห์และสร้างทางเลือก” ของผู้ใช้ทุกคน', style: AppText.small),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Semantics(
              label: 'กราฟแท่งจำนวนคำขอ AI รายวัน 7 วันล่าสุด',
              child: CustomPaint(painter: _DailyBarPainter(week, weekLabels)),
            ),
          ),
        ],
      ),
    );

    final health = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('สถานะบริการ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            LinkText('ดูรายละเอียด', onTap: () => setState(() => _page = 2)),
          ]),
          const SizedBox(height: 4),
          KeyValueRow('Application Server', const Pill('ปกติ', tone: Tone.low)),
          KeyValueRow('Database (PostgreSQL)', const Pill('ปกติ', tone: Tone.low)),
          KeyValueRow('AI Service Provider', Pill(s.aiHealthy ? 'ปกติ' : 'ช้ากว่าปกติ', tone: s.aiHealthy ? Tone.low : Tone.mid)),
          KeyValueRow('Notification Service', const Pill('ปกติ', tone: Tone.low), last: true),
          if (s.settings.maintenanceMode) ...[
            const SizedBox(height: 8),
            const InfoBanner(icon: Icons.construction_outlined, tone: Tone.mid, text: 'เปิดโหมดปิดปรับปรุงอยู่ ผู้ใช้ทั่วไปเข้าสู่ระบบไม่ได้'),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) => ListView(
        padding: const EdgeInsets.all(28),
        children: [
          _title('ภาพรวมระบบ', 'ข้อมูล ณ ${dateWithDow(DateTime.now())} ${timeOf(DateTime.now())} น.', const []),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _stat('${users.length}', 'ผู้ใช้ทั้งหมด', 'ใหม่ใน 7 วัน $newUsers คน · ใช้งานอยู่ $activeUsers คน', icon: Icons.people_outline),
              _stat('${s.aiRequestsToday}', 'คำขอ AI วันนี้', 'เฉลี่ยตอบสนอง ${avgLatency.toStringAsFixed(1)} วินาที', icon: Icons.auto_awesome),
              _stat(decided == 0 ? '–' : '${(accepted / decided * 100).round()}%', 'ผู้ใช้ยอมรับหรือปรับแผน', 'จากการตัดสินใจ $decided ครั้ง', icon: Icons.task_alt),
              _stat(rated.isEmpty ? '–' : '${(good / rated.length * 100).round()}%', 'Feedback “เหมาะสม”', 'จาก $good / ${rated.length} ครั้ง', icon: Icons.thumb_up_alt_outlined),
              _stat('${pending.length}', 'ปัญหารอตรวจสอบ', pending.isEmpty ? 'ไม่มีปัญหาค้าง' : 'แตะเมนูบันทึกข้อผิดพลาด', icon: Icons.warning_amber_rounded, tone: pending.isEmpty ? Tone.low : Tone.high),
            ],
          ),
          const SizedBox(height: 20),
          if (c.maxWidth >= 900)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: chart), const SizedBox(width: 16), Expanded(flex: 2, child: health)])
          else ...[
            chart,
            const SizedBox(height: 16),
            health,
          ],
          const SizedBox(height: 20),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                  child: Row(children: [
                    const Expanded(child: Text('เหตุการณ์ล่าสุด', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    LinkText('ดูทั้งหมด', onTap: () => setState(() => _page = 3)),
                  ]),
                ),
                for (final l in s.logs.take(4)) _logRow(l, compact: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton('จัดการผู้ใช้งาน', variant: ButtonVariant.ghost, icon: Icons.people_outline, expand: false, onPressed: () => setState(() => _page = 1)),
              AppButton('ตั้งค่าระบบ', variant: ButtonVariant.ghost, icon: Icons.settings_outlined, expand: false, onPressed: () => setState(() {
                _page = 4;
                _draft = appState.settings.copy();
              })),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================== ผู้ใช้งาน
  Widget _usersPage(BuildContext context) {
    final users = appState.users;
    final list = users.where((u) {
      if (_userFilter != null && u.status != _userFilter) return false;
      final q = _query.toLowerCase();
      return q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
    }).toList();
    int count(String st) => users.where((u) => u.status == st).length;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _title(
          'จัดการผู้ใช้งาน',
          'เพิ่ม แก้ไข ระงับบัญชี และรีเซ็ตรหัสผ่านของผู้ใช้',
          [AppButton('เพิ่มผู้ใช้', icon: Icons.person_add_alt, expand: false, onPressed: () => _addUser(context))],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _stat('${users.length}', 'ผู้ใช้ทั้งหมด', 'ในระบบต้นแบบ'),
            _stat('${count('ใช้งาน')}', 'ใช้งานอยู่', '${users.isEmpty ? 0 : (count('ใช้งาน') / users.length * 100).round()}% ของผู้ใช้ทั้งหมด'),
            _stat('${count('ระงับ')}', 'บัญชีถูกระงับ', 'ปลดระงับได้จากตาราง'),
            _stat('${count('รอยืนยันอีเมล')}', 'รอยืนยันอีเมล', 'ส่งอีเมลซ้ำได้'),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(hintText: 'ค้นหาชื่อหรืออีเมล', prefixIcon: Icon(Icons.search), isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 400,
                      child: Segmented<String?>(
                        options: const [null, 'ใช้งาน', 'ระงับ', 'รอยืนยันอีเมล'],
                        value: _userFilter,
                        height: 34,
                        labelOf: (v) => v ?? 'ทั้งหมด',
                        onChanged: (v) => setState(() => _userFilter = v),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 930,
                  child: Column(children: [_userHeader(), for (final u in list) _userRow(context, u)]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('แสดง ${list.length} จาก ${users.length} รายการ', style: AppText.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _w = [170.0, 220.0, 120.0, 140.0, 130.0, 118.0];

  Widget _userHeader() {
    const labels = ['ผู้ใช้', 'อีเมล', 'วันที่สมัคร', 'ใช้งานล่าสุด', 'สถานะ', 'จัดการ'];
    return Container(
      color: const Color(0xFFFAF9F5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          SizedBox(width: _w[i], child: Text(labels[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted))),
      ]),
    );
  }

  Widget _userRow(BuildContext context, AppUser u) {
    final tone = u.status == 'ใช้งาน' ? Tone.low : (u.status == 'ระงับ' ? Tone.high : Tone.mid);
    final suspended = u.status == 'ระงับ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          SizedBox(
            width: _w[0],
            child: Row(children: [
              UserAvatar(u.name, radius: 16),
              const SizedBox(width: 10),
              Flexible(child: Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          SizedBox(width: _w[1], child: Text(u.email, style: AppText.muted, overflow: TextOverflow.ellipsis)),
          SizedBox(width: _w[2], child: Text(dateWithYear(u.joined), style: AppText.body)),
          SizedBox(width: _w[3], child: Text(u.lastActive, style: AppText.body)),
          SizedBox(width: _w[4], child: Align(alignment: Alignment.centerLeft, child: Pill(u.status, tone: tone))),
          SizedBox(
            width: _w[5],
            child: Row(children: [
              IconButton(tooltip: 'แก้ไข', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _rename(context, u)),
              IconButton(tooltip: 'รีเซ็ตรหัสผ่าน', icon: const Icon(Icons.lock_reset, size: 18), onPressed: () => showSnack(context, 'ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ ${u.email} แล้ว')),
              IconButton(
                tooltip: suspended ? 'ปลดระงับ' : 'ระงับบัญชี',
                icon: Icon(suspended ? Icons.check_circle_outline : Icons.block, size: 18, color: suspended ? AppColors.low : AppColors.high),
                onPressed: () => appState.toggleUserSuspended(u),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _addUser(BuildContext context) async {
    final name = TextEditingController();
    final mail = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มผู้ใช้'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'ชื่อ')),
          const SizedBox(height: 10),
          TextField(controller: mail, decoration: const InputDecoration(labelText: 'อีเมล')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('เพิ่ม')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && mail.text.contains('@')) {
      appState.addUser(name.text.trim(), mail.text.trim());
    }
  }

  Future<void> _rename(BuildContext context, AppUser u) async {
    final name = TextEditingController(text: u.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อผู้ใช้'),
        content: TextField(controller: name, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (ok == true) appState.renameUser(u, name.text);
  }

  // ============================================================= สถานะระบบ
  Widget _statusPage(BuildContext context) {
    final s = appState;
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('เวลาตอบสนองของ AI Service', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text('เฉลี่ยรายชั่วโมง · ${dateWithDow(s.now)}', style: AppText.small),
              const SizedBox(height: 10),
              SizedBox(
                height: 210,
                width: double.infinity,
                child: Semantics(
                  label: 'กราฟเส้นเวลาตอบสนองของ AI Service รายชั่วโมง',
                  child: CustomPaint(painter: _LinePainter(s.aiLatency, s.settings.aiTimeoutSeconds * 0.4)),
                ),
              ),
            ],
          ),
        );
        final logs = AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                child: Row(children: [
                  const Expanded(child: Text('เหตุการณ์ของวันนี้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  LinkText('ดูทั้งหมด', onTap: () => setState(() => _page = 3)),
                ]),
              ),
              for (final l in s.logs.where((l) => daysBetween(l.time, s.now) == 0)) _logRow(l),
            ],
          ),
        );
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _title(
              'ตรวจสอบสถานะระบบ',
              'อัปเดตล่าสุด ${timeOf(s.statusRefreshedAt)} น.',
              [
                AppButton('รีเฟรช', variant: ButtonVariant.ghost, icon: Icons.refresh, expand: false, onPressed: s.refreshStatus),
                AppButton('รีสตาร์ตบริการ AI', icon: Icons.restart_alt, expand: false, onPressed: s.aiHealthy
                    ? null
                    : () {
                        s.restartAi();
                        showSnack(context, 'รีสตาร์ตบริการ AI สำเร็จ');
                      }),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _service(Icons.dns_outlined, 'Application Server', 'ปกติ', Tone.low, const [('CPU', '32%'), ('หน่วยความจำ', '2.1 / 8 GB'), ('Uptime', '14 วัน')]),
                _service(Icons.storage, 'Database (PostgreSQL)', 'ปกติ', Tone.low, const [('การเชื่อมต่อ', '18 / 100'), ('พื้นที่ใช้', '1.2 / 20 GB'), ('สำรองล่าสุด', '08:30')]),
                _service(
                  Icons.auto_awesome,
                  'AI Service Provider',
                  s.aiHealthy ? 'ปกติ' : 'ช้ากว่าปกติ',
                  s.aiHealthy ? Tone.low : Tone.mid,
                  [('เวลาตอบสนองล่าสุด', '${s.aiLatency.last.toStringAsFixed(1)} s'), ('คำขอวันนี้', '${s.aiRequestsToday}'), ('เวลารอสูงสุด', '${s.settings.aiTimeoutSeconds} s')],
                ),
                _service(Icons.notifications_none, 'Notification Service', 'ปกติ', Tone.low, const [('ส่งวันนี้', '1,034'), ('คิวค้าง', '0'), ('อัตราส่งสำเร็จ', '99.6%')]),
              ],
            ),
            const SizedBox(height: 20),
            if (constraints.maxWidth >= 900)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 420, child: chart), const SizedBox(width: 16), Expanded(child: logs)])
            else ...[
              chart,
              const SizedBox(height: 16),
              logs,
            ],
          ],
        );
      },
    );
  }

  // ======================================================== บันทึกข้อผิดพลาด
  Widget _logsPage(BuildContext context) {
    final all = appState.logs;
    final list = all.where((l) => (_levelFilter == null || l.level == _levelFilter) && (!_pendingOnly || l.pending)).toList();
    int count(String level) => all.where((l) => l.level == level).length;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _title('บันทึกข้อผิดพลาด', 'เหตุการณ์ของระบบทั้งหมด ${all.length} รายการ · รอตรวจสอบ ${all.where((l) => l.pending).length} รายการ', const []),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _stat('${count('Error')}', 'Error', 'ข้อผิดพลาดที่กระทบผู้ใช้', tone: Tone.high),
            _stat('${count('Warning')}', 'Warning', 'สัญญาณเตือนที่ควรเฝ้าดู', tone: Tone.mid),
            _stat('${count('Info')}', 'Info', 'เหตุการณ์ทั่วไปของระบบ', tone: Tone.blue),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 380,
                      child: Segmented<String?>(
                        options: const [null, 'Error', 'Warning', 'Info'],
                        value: _levelFilter,
                        height: 34,
                        labelOf: (v) => v ?? 'ทั้งหมด',
                        onChanged: (v) => setState(() => _levelFilter = v),
                      ),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(value: _pendingOnly, onChanged: (v) => setState(() => _pendingOnly = v)),
                      const SizedBox(width: 6),
                      const Text('เฉพาะที่รอตรวจสอบ', style: AppText.body),
                    ]),
                  ],
                ),
              ),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('ไม่มีรายการตามเงื่อนไขที่เลือก', style: AppText.muted)),
              for (final l in list) _logRow(l, withDate: true, action: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logRow(SystemLog l, {bool withDate = false, bool action = false, bool compact = false}) {
    final levelTone = l.level == 'Error' ? Tone.high : (l.level == 'Warning' ? Tone.mid : Tone.blue);
    final statusTone = l.pending ? Tone.mid : Tone.low;
    final time = withDate || daysBetween(l.time, appState.now) != 0 ? '${dateShort(l.time)}\n${timeOf(l.time)}' : timeOf(l.time);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64, child: Text(time, style: AppText.muted)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l.service, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Pill(l.level, tone: levelTone),
                    Pill(l.status, tone: statusTone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l.detail, style: AppText.body, maxLines: compact ? 1 : null, overflow: compact ? TextOverflow.ellipsis : null),
              ],
            ),
          ),
          if (action && l.pending) ...[
            const SizedBox(width: 8),
            AppButton('แก้ไขแล้ว', variant: ButtonVariant.ghost, icon: Icons.check, expand: false, height: 38, onPressed: () => appState.resolveLog(l)),
          ],
        ],
      ),
    );
  }

  // ============================================================ ตั้งค่าระบบ
  Widget _settingsPage(BuildContext context) {
    final d = _draft ??= appState.settings.copy();
    final total = d.weightTotal;
    final valid = total == 100;

    Widget weightRow(String label, String hint, int value, ValueChanged<int> onChanged) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 190,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(hint, style: AppText.small),
                ]),
              ),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$value%',
                  onChanged: (v) => setState(() => onChanged(v.round())),
                ),
              ),
              SizedBox(width: 48, child: Text('$value%', textAlign: TextAlign.right, style: AppText.label)),
            ],
          ),
        );

    Widget choice<T>(String label, String hint, List<T> options, T value, String Function(T) labelOf, ValueChanged<T> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(hint, style: AppText.small),
                ]),
              ),
              SizedBox(
                width: 90.0 * options.length,
                child: Segmented<T>(options: options, value: value, height: 34, labelOf: labelOf, onChanged: (v) => setState(() => onChanged(v))),
              ),
            ],
          ),
        );

    Widget toggle(String label, String hint, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(hint, style: AppText.small),
              ]),
            ),
            Switch(value: value, onChanged: (v) => setState(() => onChanged(v))),
          ]),
        );

    Widget section(IconData icon, String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 20, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title('ตั้งค่าระบบ', 'ค่าที่บันทึกมีผลกับแอปฝั่งผู้ใช้ทันที และถูกบันทึกลงบันทึกเหตุการณ์', const []),
                const SizedBox(height: 20),
                section(Icons.auto_awesome, 'น้ำหนักปัจจัยในการตัดสินใจของ AI', [
                  const Text('ใช้คำนวณคะแนนรวมของทางเลือก A/B/C และเลือกทางเลือกที่แนะนำ น้ำหนักทั้ง 4 ด้านต้องรวมกันได้ 100%', style: AppText.muted),
                  const SizedBox(height: 10),
                  weightRow('Deadline', 'ความเสี่ยงที่งานจะเลยกำหนด', d.weightDeadline, (v) => d.weightDeadline = v),
                  weightRow('ความสำคัญ', 'งานสำคัญสูงได้อยู่ในแผน', d.weightPriority, (v) => d.weightPriority = v),
                  weightRow('เป้าหมาย', 'ความสอดคล้องกับเป้าหมายผู้ใช้', d.weightGoal, (v) => d.weightGoal = v),
                  weightRow('ประวัติการใช้เวลา', 'ลดการหั่นงานเป็นช่วงสั้น ๆ', d.weightHistory, (v) => d.weightHistory = v),
                  const SizedBox(height: 6),
                  Row(children: [
                    Pill('รวม $total%', tone: valid ? Tone.low : Tone.high),
                    const SizedBox(width: 10),
                    Expanded(child: Text(valid ? 'พร้อมบันทึก' : 'ปรับให้รวมกันเท่ากับ 100% ก่อนบันทึก', style: AppText.small)),
                  ]),
                ]),
                section(Icons.tune, 'การสร้างทางเลือก', [
                  choice<int>('เวลาสูงสุดต่องานในทางเลือก C', 'ทางเลือกเน้นความสมดุลจะไม่ให้งานใดเกินค่านี้', const [60, 90, 120], d.balancedCap, (v) => '$v นาที', (v) => d.balancedCap = v),
                  choice<int>('เวลารอ AI สูงสุด', 'เกินเวลานี้ถือว่า AI ตอบช้า', const [5, 10, 15], d.aiTimeoutSeconds, (v) => '$v วินาที', (v) => d.aiTimeoutSeconds = v),
                  toggle('แสดงแผนสำรองเมื่อ AI ตอบช้า', 'จัดตาม Deadline ให้ผู้ใช้ก่อน เพื่อไม่ให้ใช้งานสะดุด (NFR: Reliability)', d.fallbackPlan, (v) => d.fallbackPlan = v),
                ]),
                section(Icons.notifications_none, 'การแจ้งเตือน', [
                  choice<int>('แจ้งเตือนก่อนเริ่มกิจกรรม', 'ค่าเริ่มต้นสำหรับผู้ใช้ทุกคน', const [5, 10, 15, 30], d.reminderMinutes, (v) => '$v นาที', (v) => d.reminderMinutes = v),
                ]),
                section(Icons.shield_outlined, 'ความปลอดภัยและข้อมูล', [
                  choice<int>('ความยาวรหัสผ่านขั้นต่ำ', 'ใช้ตรวจตอนสมัครสมาชิกและเข้าสู่ระบบ (NFR: Security)', const [8, 10, 12], d.passwordMinLength, (v) => '$v ตัว', (v) => d.passwordMinLength = v),
                  choice<int>('ระยะเวลาเก็บประวัติการใช้งาน', 'ประวัติที่เก่ากว่านี้จะถูกลบอัตโนมัติ (NFR: Privacy)', const [90, 180, 365], d.dataRetentionDays, (v) => v == 365 ? '1 ปี' : '$v วัน', (v) => d.dataRetentionDays = v),
                  toggle('โหมดปิดปรับปรุงระบบ', 'ผู้ใช้ทั่วไปเข้าสู่ระบบไม่ได้ชั่วคราว ผู้ดูแลยังเข้าได้', d.maintenanceMode, (v) => d.maintenanceMode = v),
                ]),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    AppButton('คืนค่าเริ่มต้น', variant: ButtonVariant.ghost, icon: Icons.settings_backup_restore, expand: false, onPressed: () => setState(() => _draft = SystemSettings())),
                    AppButton('บันทึกการตั้งค่า', icon: Icons.check, expand: false, onPressed: valid
                        ? () {
                            appState.saveSettings(d.copy());
                            showSnack(context, 'บันทึกการตั้งค่าระบบแล้ว');
                          }
                        : null),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================ ส่วนประกอบ
  Widget _title(String title, String sub, List<Widget> actions) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            Text(sub, style: AppText.muted),
          ],
        ),
        if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }

  Widget _stat(String value, String label, String sub, {IconData? icon, Tone? tone}) {
    return SizedBox(
      width: 210,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: AppText.muted)),
              if (icon != null) Icon(icon, size: 18, color: tone == null ? AppColors.accent : toneFg(tone)),
            ]),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: tone == null ? AppColors.ink : toneFg(tone))),
            Text(sub, style: AppText.small),
          ],
        ),
      ),
    );
  }

  Widget _service(IconData icon, String name, String status, Tone tone, List<(String, String)> rows) {
    return SizedBox(
      width: 230,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFFF0EEE8), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 10),
            Pill(status, tone: tone),
            const SizedBox(height: 6),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(r.$1, style: AppText.muted)),
                  Text(r.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.page, required this.pendingLogs, required this.onSelect, required this.onLogout});
  final int page;
  final int pendingLogs;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, int target, {int badge = 0}) {
      final selected = target == page;
      final color = selected ? Colors.white : const Color(0xFFC9DBD8);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected ? const Color(0x1FFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(target),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color))),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.high, borderRadius: BorderRadius.circular(999)),
                    child: Text('$badge', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.sidebar,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 6, 22),
              child: Row(children: [
                AppLogo(size: 40),
                SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TimeWise AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('ผู้ดูแลระบบ', style: TextStyle(fontSize: 12, color: Color(0xFFB8CFCB))),
                ]),
              ]),
            ),
            item(Icons.dashboard_outlined, 'ภาพรวม', 0),
            item(Icons.people_outline, 'จัดการผู้ใช้งาน', 1),
            item(Icons.dns_outlined, 'สถานะระบบ', 2),
            item(Icons.warning_amber_rounded, 'บันทึกข้อผิดพลาด', 3, badge: pendingLogs),
            item(Icons.settings_outlined, 'ตั้งค่าระบบ', 4),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const CircleAvatar(radius: 18, backgroundColor: AppColors.avatar, child: Text('A', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent))),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('admin01', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('System Administrator', style: TextStyle(fontSize: 12, color: Color(0xFFB8CFCB))),
                  ]),
                ),
                IconButton(tooltip: 'ออกจากระบบ', onPressed: onLogout, icon: const Icon(Icons.logout, color: Colors.white, size: 18)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

TextPainter _label(String t, Color color, {double size = 11, FontWeight weight = FontWeight.w400}) => TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();

/// กราฟแท่งจำนวนคำขอ AI รายวัน (ชุดข้อมูลเดียว ใช้สีหลัก วันนี้เข้มกว่า)
class _DailyBarPainter extends CustomPainter {
  _DailyBarPainter(this.values, this.labels);
  final List<int> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const top = 16.0;
    const bottom = 24.0;
    final h = size.height - top - bottom;
    final maxRaw = values.fold<int>(1, (a, b) => math.max(a, b));
    final step = math.max(1, ((maxRaw / 4) / 100).ceil() * 100);
    final maxV = step * 4;
    double y(num v) => top + h - v / maxV * h;

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = step * i;
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), grid);
      final tp = _label('$v', AppColors.muted, size: 10);
      tp.paint(canvas, Offset(left - 6 - tp.width, y(v) - tp.height / 2));
    }

    final groupW = (size.width - left) / values.length;
    final barW = math.min(28.0, groupW * 0.55);
    for (var i = 0; i < values.length; i++) {
      final cx = left + groupW * i + groupW / 2;
      final top0 = y(values[i]);
      final isToday = i == values.length - 1;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, top0, barW, top + h - top0),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = isToday ? AppColors.accent : const Color(0xFF7FB5AE));
      final v = _label('${values[i]}', AppColors.ink, size: 10, weight: isToday ? FontWeight.w700 : FontWeight.w400);
      v.paint(canvas, Offset(cx - v.width / 2, top0 - v.height - 2));
      final l = _label(isToday ? 'วันนี้' : labels[i], AppColors.muted, size: 10);
      l.paint(canvas, Offset(cx - l.width / 2, top + h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _DailyBarPainter oldDelegate) => true;
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.threshold);
  final List<double> values;
  final double threshold; // เกณฑ์เตือน (วินาที)

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const top = 10.0;
    const bottom = 24.0;
    const maxV = 6.0;
    final h = size.height - top - bottom;
    final w = size.width - left - 10;
    double y(double v) => top + (1 - v.clamp(0, maxV) / maxV) * h;
    double x(int i) => left + (values.length <= 1 ? 0 : i * w / (values.length - 1));

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (final v in [0.0, 2.0, 4.0, 6.0]) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width - 10, y(v)), grid);
      final tp = _label('${v.toStringAsFixed(0)} s', AppColors.muted);
      tp.paint(canvas, Offset(left - 6 - tp.width, y(v) - tp.height / 2));
    }

    // เส้นเกณฑ์เตือน (เส้นประ)
    final dash = Paint()
      ..color = AppColors.high
      ..strokeWidth = 1;
    for (var dx = left; dx < size.width - 10; dx += 8) {
      canvas.drawLine(Offset(dx, y(threshold)), Offset(math.min(dx + 4, size.width - 10), y(threshold)), dash);
    }
    final th = _label('เกณฑ์เตือน ${threshold.toStringAsFixed(1)} s', AppColors.high);
    th.paint(canvas, Offset(size.width - 10 - th.width, y(threshold) - th.height - 2));

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.chartPlanned
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = AppColors.chartPlanned);
    }

    for (var i = 0; i < values.length; i += 3) {
      final label = _label('${two(10 + i)}:00', AppColors.muted);
      label.paint(canvas, Offset(x(i) - label.width / 2, top + h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}

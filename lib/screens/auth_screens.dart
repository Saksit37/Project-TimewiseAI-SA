import 'package:flutter/material.dart';

import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 6.3.1 หน้าเข้าสู่ระบบ (FR-01)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'mew.student@example.com');
  final _pass = TextEditingController(text: 'password123');
  bool _remember = true;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _login() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final email = _email.text.trim().toLowerCase();
    if (email == 'admin@timewise.app') {
      Navigator.pushReplacementNamed(context, Routes.admin);
      return;
    }
    if (appState.settings.maintenanceMode) {
      showSnack(context, 'ระบบอยู่ระหว่างปิดปรับปรุง ผู้ใช้ทั่วไปยังเข้าสู่ระบบไม่ได้');
      return;
    }
    appState.email = email;
    appState.homeTab.value = 0;
    Navigator.pushReplacementNamed(context, Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo()),
                    const SizedBox(height: 12),
                    const Text('TimeWise AI', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const Text(
                      'ผู้ช่วยตัดสินใจจัดสรรเวลาในแต่ละวัน\nด้วยปัญญาประดิษฐ์',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    if (appState.settings.maintenanceMode) ...[
                      const InfoBanner(
                        icon: Icons.construction_outlined,
                        tone: Tone.mid,
                        text: 'ระบบอยู่ระหว่างปิดปรับปรุงชั่วคราว ขออภัยในความไม่สะดวก (ผู้ดูแลระบบยังเข้าสู่ระบบได้)',
                      ),
                      const SizedBox(height: 16),
                    ],
                    LabeledField(
                      label: 'อีเมล',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      suffixIcon: Icons.mail_outline,
                      validator: (v) => (v == null || !v.contains('@')) ? 'กรุณากรอกอีเมลให้ถูกต้อง' : null,
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('รหัสผ่าน'),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      validator: (v) => (v == null || v.length < appState.settings.passwordMinLength)
                          ? 'รหัสผ่านต้องมีอย่างน้อย ${appState.settings.passwordMinLength} ตัวอักษร'
                          : null,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false)),
                        const Expanded(child: Text('จดจำฉันไว้', style: TextStyle(fontSize: 14, color: AppColors.muted))),
                        LinkText('ลืมรหัสผ่าน?', onTap: () => showSnack(context, 'ระบบจะส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่อีเมลของคุณ')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppButton('เข้าสู่ระบบ', onPressed: _login),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('หรือ', style: AppText.muted)),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppButton('เข้าสู่ระบบด้วยบัญชีมหาวิทยาลัย', variant: ButtonVariant.ghost, icon: Icons.school_outlined, onPressed: _login),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ยังไม่มีบัญชี?', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        LinkText('สมัครสมาชิก', onTap: () => Navigator.pushNamed(context, Routes.register)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const InfoBanner(
                      icon: Icons.info_outline,
                      tone: Tone.gray,
                      text: 'บัญชีทดลอง: ผู้ใช้ทั่วไปกรอกอีเมลใดก็ได้และรหัสผ่าน 8 ตัวขึ้นไป · ผู้ดูแลระบบใช้ admin@timewise.app',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 6.3.1 หน้าสมัครสมาชิก (FR-01)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _accept = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_accept) {
      showSnack(context, 'กรุณายอมรับเงื่อนไขการใช้งานก่อนสมัครสมาชิก');
      return;
    }
    appState.updateProfile(_name.text, _email.text);
    Navigator.pushNamed(context, Routes.setup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appHeader('สมัครสมาชิก', subtitle: 'ขั้นที่ 1 จาก 2 · ข้อมูลบัญชี'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Row(children: [
              Expanded(child: ProgressBar(1, height: 6)),
              SizedBox(width: 6),
              Expanded(child: ProgressBar(0, height: 6)),
            ]),
            const SizedBox(height: 16),
            LabeledField(label: 'ชื่อผู้ใช้', controller: _name, hint: 'เช่น มิว', validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อผู้ใช้' : null),
            const SizedBox(height: 14),
            LabeledField(
              label: 'อีเมล',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              hint: 'name@example.com',
              validator: (v) => (v == null || !v.contains('@')) ? 'กรุณากรอกอีเมลให้ถูกต้อง' : null,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'รหัสผ่าน',
              controller: _pass,
              obscure: true,
              validator: (v) {
                if (v == null || v.length < appState.settings.passwordMinLength) return 'รหัสผ่านต้องมีอย่างน้อย ${appState.settings.passwordMinLength} ตัวอักษร';
                if (!RegExp(r'[0-9]').hasMatch(v) || !RegExp(r'[A-Za-z]').hasMatch(v)) return 'ต้องมีทั้งตัวอักษรและตัวเลข';
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('อย่างน้อย ${appState.settings.passwordMinLength} ตัวอักษร ประกอบด้วยตัวอักษรและตัวเลข', style: AppText.small),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'ยืนยันรหัสผ่าน',
              controller: _confirm,
              obscure: true,
              validator: (v) => v != _pass.text ? 'รหัสผ่านไม่ตรงกัน' : null,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: _accept, onChanged: (v) => setState(() => _accept = v ?? false)),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'ฉันยอมรับเงื่อนไขการใช้งาน และยินยอมให้ระบบจัดเก็บข้อมูลกิจกรรมเพื่อใช้วิเคราะห์ตามนโยบายความเป็นส่วนตัว',
                      style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton('ถัดไป: ตั้งค่าเวลาและเป้าหมาย', onPressed: _submit),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('มีบัญชีอยู่แล้ว?', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                LinkText('เข้าสู่ระบบ', onTap: () => Navigator.pop(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 6.3.4 หน้ากำหนดเวลาว่างและเป้าหมาย (FR-05, FR-06)
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  Future<void> _addSlot(BuildContext context) async {
    final start = await pickTime(context, const TimeOfDay(hour: 18, minute: 0));
    if (start == null || !context.mounted) return;
    final end = await pickTime(context, TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute));
    if (end == null || !context.mounted) return;
    final error = appState.addSlot(start.hour * 60 + start.minute, end.hour * 60 + end.minute);
    if (error != null) showSnack(context, error);
  }

  Future<void> _addGoal(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มเป้าหมาย'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'เช่น ฝึกภาษาอังกฤษ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('เพิ่ม')),
        ],
      ),
    );
    if (result != null) appState.addGoal(result);
  }

  @override
  Widget build(BuildContext context) {
    final editMode = ModalRoute.of(context)?.settings.arguments == true;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        return Scaffold(
          appBar: appHeader('ตั้งค่าเวลาว่างและเป้าหมาย', subtitle: editMode ? 'ใช้เป็นข้อมูลให้ AI วิเคราะห์' : 'ขั้นที่ 2 จาก 2 · ใช้เป็นข้อมูลให้ AI วิเคราะห์'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (!editMode) ...[
                const Row(children: [
                  Expanded(child: ProgressBar(1, height: 6)),
                  SizedBox(width: 6),
                  Expanded(child: ProgressBar(1, height: 6)),
                ]),
                const SizedBox(height: 16),
              ],
              const SectionTitle('เป้าหมายของคุณ'),
              const SizedBox(height: 4),
              const Text('เลือกได้มากกว่า 1 ข้อ เป้าหมายที่เลือกก่อนจะถือเป็นเป้าหมายหลัก', style: AppText.muted),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in s.allGoals)
                    _GoalChip(
                      label: s.goals.contains(g) ? '$g${s.goals.indexOf(g) == 0 ? ' (หลัก)' : ''}' : g,
                      selected: s.goals.contains(g),
                      onTap: () => s.toggleGoal(g),
                    ),
                  _GoalChip(label: '+ เพิ่มเอง', selected: false, onTap: () => _addGoal(context)),
                ],
              ),
              const SizedBox(height: 22),
              const SectionTitle('ช่วงเวลาว่างที่ทำกิจกรรมได้'),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _DayCircle(
                          label: const ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'][d - 1],
                          selected: s.activeDays.contains(d),
                          onTap: () => s.toggleDay(d),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < s.slots.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    radius: 12,
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 18, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${_hm(s.slots[i].start)} – ${_hm(s.slots[i].end)} น.', style: AppText.bodyStrong)),
                        IconButton(
                          tooltip: 'ลบช่วงเวลา',
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                          onPressed: () => s.removeSlot(i),
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _addSlot(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มช่วงเวลาว่าง'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Expanded(child: Text('รวมเวลาว่างต่อวัน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent))),
                    Text(_dur(s.freeMinutes), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: bottomBar([
            Expanded(
              child: AppButton(
                editMode ? 'บันทึก' : 'บันทึกและเริ่มใช้งาน',
                icon: Icons.check,
                onPressed: () {
                  if (s.goals.isEmpty) {
                    showSnack(context, 'กรุณาเลือกเป้าหมายอย่างน้อย 1 ข้อ');
                    return;
                  }
                  if (s.slots.isEmpty) {
                    showSnack(context, 'กรุณาเพิ่มช่วงเวลาว่างอย่างน้อย 1 ช่วง');
                    return;
                  }
                  if (editMode) {
                    Navigator.pop(context);
                  } else {
                    appState.homeTab.value = 0;
                    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (r) => false);
                  }
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  static String _hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  static String _dur(int m) => m % 60 == 0 ? '${m ~/ 60} ชั่วโมง' : '${m ~/ 60} ชั่วโมง ${m % 60} นาที';
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accent : AppColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[const Icon(Icons.check, size: 16, color: AppColors.accent), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.accent : AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: selected ? AppColors.accent : AppColors.surface,
        shape: CircleBorder(side: BorderSide(color: selected ? AppColors.accent : AppColors.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink)),
          ),
        ),
      ),
    );
  }
}

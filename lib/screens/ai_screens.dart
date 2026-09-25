import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../services/decision_engine.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 6.3.5 หน้าขอคำแนะนำจาก AI (FR-07)
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  late final TextEditingController _note = TextEditingController(text: appState.aiNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final pending = s.pending;
        final included = s.aiCandidates;
        final sum = included.fold<int>(0, (x, a) => x + a.minutes);
        final canRun = included.isNotEmpty && s.freeMinutes > 0;
        return Scaffold(
          appBar: appHeader('ขอคำแนะนำจาก AI', subtitle: 'ตรวจข้อมูลที่ AI จะใช้วิเคราะห์'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  children: [
                    Row(children: [
                      const Expanded(child: Text('กิจกรรมที่จะจัดสรร', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      Pill('${included.length} รายการ · ${duration(sum)}'),
                    ]),
                    const SizedBox(height: 4),
                    if (pending.isEmpty)
                      const Padding(padding: EdgeInsets.all(12), child: Text('ไม่มีกิจกรรมที่รอทำ', style: AppText.muted)),
                    for (var i = 0; i < pending.length; i++)
                      Container(
                        decoration: BoxDecoration(border: i == pending.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.line))),
                        child: InkWell(
                          onTap: () => s.setIncluded(pending[i].id, s.excludedFromAi.contains(pending[i].id)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: !s.excludedFromAi.contains(pending[i].id),
                                  onChanged: (v) => s.setIncluded(pending[i].id, v ?? false),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pending[i].name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text(_meta(pending[i]), style: AppText.small),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.schedule,
                      label: 'เวลาว่างวันนี้',
                      value: s.slots.isEmpty
                          ? 'ยังไม่ได้กำหนด'
                          : '${s.slots.map((t) => '${hm(t.start)}–${hm(t.end)}').join(' และ ')} (${duration(s.freeMinutes)})',
                    ),
                    const Divider(height: 20),
                    _InfoRow(icon: Icons.track_changes, label: 'เป้าหมาย', value: s.goals.isEmpty ? 'ยังไม่ได้เลือก' : s.goals.join(', ')),
                  ],
                ),
              ),
              if (s.freeMinutes == 0) ...[
                const SizedBox(height: 12),
                const InfoBanner(icon: Icons.warning_amber_rounded, tone: Tone.mid, text: 'กรุณาเพิ่มช่วงเวลาว่างก่อน เพื่อให้ AI จัดสรรกิจกรรมได้'),
              ],
              const SizedBox(height: 14),
              const FieldLabel('สิ่งที่อยากให้ AI คำนึงถึงเพิ่มเติม (ไม่บังคับ)'),
              TextField(controller: _note, maxLines: 2, onChanged: (v) => s.aiNote = v),
            ],
          ),
          bottomNavigationBar: bottomBar([
            Expanded(
              child: AppButton(
                'วิเคราะห์และสร้างทางเลือก',
                icon: Icons.auto_awesome,
                onPressed: canRun ? () => Navigator.pushNamed(context, Routes.aiLoading) : null,
              ),
            ),
          ]),
        );
      },
    );
  }

  String _meta(Activity a) {
    final dl = a.recurring ? 'ประจำวัน' : 'Deadline ${dateShort(a.deadline)}';
    return '${duration(a.minutes)} · $dl · ${a.priority.label}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.small),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        LinkText('แก้ไข', onTap: () => Navigator.pushNamed(context, Routes.setup, arguments: true)),
      ],
    );
  }
}

/// หน้าระหว่างที่ AI กำลังวิเคราะห์
class AiLoadingScreen extends StatefulWidget {
  const AiLoadingScreen({super.key});

  @override
  State<AiLoadingScreen> createState() => _AiLoadingScreenState();
}

class _AiLoadingScreenState extends State<AiLoadingScreen> {
  static const _steps = [
    'ตรวจสอบ Deadline และความสำคัญ',
    'เทียบกับเป้าหมายของคุณ',
    'ใช้ประวัติเวลาที่ใช้จริงของคุณ',
    'สร้างทางเลือก A / B / C และผลกระทบ',
  ];
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) return;
      if (_step >= _steps.length - 1) {
        t.cancel();
        appState.runAnalysis();
        Navigator.pushReplacementNamed(context, Routes.options);
        return;
      }
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = appState;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('AI กำลังวิเคราะห์สถานการณ์', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'กำลังพิจารณากิจกรรม ${s.aiCandidates.length} รายการ\nกับเวลาว่าง ${duration(s.freeMinutes)} ของคุณ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
                ),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 16),
                          child: Row(
                            children: [
                              SizedBox(width: 28, height: 28, child: _marker(i)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _steps[i],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: i <= _step ? FontWeight.w600 : FontWeight.w400,
                                    color: i <= _step ? AppColors.ink : AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (s.settings.fallbackPlan)
                  InfoBanner(
                    icon: Icons.warning_amber_rounded,
                    tone: Tone.mid,
                    text: 'หาก AI ตอบสนองช้าเกิน ${s.settings.aiTimeoutSeconds} วินาที ระบบจะแสดงแผนสำรองที่จัดตาม Deadline ให้ก่อน',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _marker(int i) {
    if (i < _step) {
      return Container(
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    }
    if (i == _step) {
      return const Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent));
    }
    return Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.line, width: 2)));
  }
}

/// 6.3.6 หน้าเปรียบเทียบทางเลือก A/B/C พร้อมผลกระทบ (FR-08, FR-09)
class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  String _filter = 'ทั้งหมด';

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ไม่ใช้ทางเลือกเหล่านี้'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'เหตุผล (ไม่บังคับ) เช่น มีนัดที่ไม่ได้บันทึกไว้'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    appState.rejectOptions(reason);
    showSnack(context, 'บันทึกเหตุผลแล้ว ลองปรับกิจกรรมหรือเวลาว่าง แล้วขอคำแนะนำใหม่');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final result = appState.lastResult;
    if (result == null) {
      return Scaffold(appBar: appHeader('ทางเลือกการจัดสรรเวลา'), body: const Center(child: Text('ยังไม่มีผลการวิเคราะห์')));
    }
    final rec = result.recommendedCode;
    final visible = result.options.where((o) => _filter == 'ทั้งหมด' || o.code == _filter).toList();
    return Scaffold(
      appBar: appHeader('ทางเลือกการจัดสรรเวลา', subtitle: '${dateWithDow(appState.now)} · เวลาว่าง ${duration(appState.freeMinutes)}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          InfoBanner(
            icon: Icons.auto_awesome,
            textColor: AppColors.ink,
            text: 'คำแนะนำ: ${result.summaries[rec]} → AI แนะนำทางเลือก $rec (${result.recommended.title})',
          ),
          const SizedBox(height: 14),
          Segmented<String>(
            options: const ['ทั้งหมด', 'A', 'B', 'C'],
            value: _filter,
            labelOf: (v) => v,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 14),
          for (final o in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OptionCard(
                option: o,
                recommended: o.code == rec,
                onReason: () => Navigator.pushNamed(context, Routes.recommendation, arguments: o.code),
                onChoose: () {
                  appState.confirmPlan(o.code, o.blocks);
                  showSnack(context, 'ยืนยันแผนทางเลือก ${o.code} แล้ว');
                  goHomeTab(context, 2);
                },
              ),
            ),
          const Text('ระบบเป็นเพียงผู้เสนอทางเลือก การตัดสินใจสุดท้ายเป็นของคุณ', textAlign: TextAlign.center, style: AppText.small),
          const SizedBox(height: 10),
          AppButton('ไม่ใช้ทางเลือกเหล่านี้', variant: ButtonVariant.ghost, icon: Icons.refresh, onPressed: _reject),
        ],
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.option, required this.recommended, required this.onReason, required this.onChoose});
  final PlanOption option;
  final bool recommended;
  final VoidCallback onReason;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final color = optionColor(o.code);
    final soft = optionSoft(o.code);
    return AppCard(
      radius: 18,
      borderColor: recommended ? color : AppColors.line,
      borderWidth: recommended ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)),
                child: Text(o.code, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('ทางเลือก ${o.code}: ${o.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (recommended) const Pill('AI แนะนำ'),
            ],
          ),
          const SizedBox(height: 12),
          MiniTimeline(option: o),
          const SizedBox(height: 8),
          KeyValueRow('เวลาที่ใช้', Text('${duration(o.usedMinutes)} / ${duration(o.freeMinutes)}', style: AppText.label)),
          KeyValueRow(
            'งานที่เสร็จ',
            Text('${o.completedIds.length} งาน${o.partialIds.isEmpty ? '' : ' + ${o.partialIds.length} บางส่วน'}', style: AppText.label),
          ),
          KeyValueRow('งานที่ต้องเลื่อน', Text('${o.postponedIds.length} งาน', style: AppText.label)),
          KeyValueRow('ความเสี่ยงต่อ Deadline', Pill(o.risk.label, tone: riskTone(o.risk))),
          KeyValueRow('ความสอดคล้องกับเป้าหมาย', Text('${o.alignment}%', style: AppText.label)),
          KeyValueRow('คะแนนรวมตามน้ำหนักปัจจัย', Text('${o.score.toStringAsFixed(1)} / 100', style: AppText.label), last: true),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ProsCons(title: 'ข้อดี', text: o.pros, tone: Tone.low)),
              const SizedBox(width: 8),
              Expanded(child: _ProsCons(title: 'ข้อจำกัด', text: o.cons, tone: Tone.high)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppButton('ดูเหตุผล', variant: ButtonVariant.ghost, onPressed: onReason)),
              const SizedBox(width: 8),
              Expanded(child: AppButton('เลือกแผนนี้', onPressed: onChoose)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProsCons extends StatelessWidget {
  const _ProsCons({required this.title, required this.text, required this.tone});
  final String title;
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: toneBg(tone), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: toneFg(tone))),
          Text(text, style: TextStyle(fontSize: 12, height: 1.5, color: toneFg(tone))),
        ],
      ),
    );
  }
}

/// แถบเวลาย่อ แสดงกิจกรรมในแต่ละช่วงเวลาว่าง
class MiniTimeline extends StatelessWidget {
  const MiniTimeline({super.key, required this.option});
  final PlanOption option;

  @override
  Widget build(BuildContext context) {
    final slots = appState.slots;
    final color = optionColor(option.code);
    final soft = optionSoft(option.code);
    if (slots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                flex: slots[i].minutes,
                child: Text('${hm(slots[i].start)}–${hm(slots[i].end)}', maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(flex: slots[i].minutes, child: _slotRow(slots[i], color, soft)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _slotRow(TimeSlot slot, Color color, Color soft) {
    final blocks = option.blocks.where((b) => b.slotStart == slot.start).toList();
    final used = blocks.fold<int>(0, (s, b) => s + b.minutes);
    final rest = slot.minutes - used;
    return Row(
      children: [
        for (final b in blocks)
          Expanded(
            flex: b.minutes,
            child: Container(
              height: 30,
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: option.partialIds.contains(b.activityId) ? soft : color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                appState.byId(b.activityId)?.name ?? '',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: option.partialIds.contains(b.activityId) ? AppColors.ink : Colors.white,
                ),
              ),
            ),
          ),
        if (rest > 0)
          Expanded(
            flex: rest,
            child: Container(height: 30, decoration: BoxDecoration(color: AppColors.graySoft, borderRadius: BorderRadius.circular(6))),
          ),
      ],
    );
  }
}

/// 6.3.5 หน้าคำแนะนำพร้อมเหตุผล (FR-10, FR-11)
class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = appState.lastResult;
    final code = ModalRoute.of(context)?.settings.arguments as String? ?? result?.recommendedCode ?? 'A';
    if (result == null) {
      return Scaffold(appBar: appHeader('เหตุผลของคำแนะนำ'), body: const Center(child: Text('ยังไม่มีผลการวิเคราะห์')));
    }
    final o = result.byCode(code);
    final factors = result.factors[code] ?? const <DecisionFactor>[];
    final suggestions = result.suggestions[code] ?? const <String, String>{};
    return Scaffold(
      appBar: appHeader('เหตุผลของคำแนะนำ', subtitle: 'ทางเลือก ${o.code}: ${o.title}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (code != result.recommendedCode) ...[
            InfoBanner(
              icon: Icons.info_outline,
              tone: Tone.mid,
              text: 'AI แนะนำทางเลือก ${result.recommendedCode} แต่คุณยังเลือกทางเลือกนี้ได้ตามที่เห็นสมควร',
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome, size: 20, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('สรุปคำแนะนำ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ]),
                const SizedBox(height: 8),
                Text(result.summaries[code] ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
                const SizedBox(height: 8),
                for (final b in o.blocks)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 104, child: Text('${hm(b.start)}–${hm(b.end)}', style: AppText.label)),
                        Expanded(child: Text(appState.byId(b.activityId)?.name ?? '', style: AppText.body)),
                        if (o.partialIds.contains(b.activityId)) const Pill('บางส่วน', tone: Tone.mid),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('ปัจจัยที่ AI ใช้ตัดสินใจ'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < factors.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == factors.length - 1 ? 0 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(factors[i].name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                          Text('น้ำหนัก ${factors[i].weight}%', style: AppText.muted),
                        ]),
                        const SizedBox(height: 6),
                        ProgressBar(factors[i].weight / 100),
                        const SizedBox(height: 6),
                        Text(factors[i].note, style: AppText.small),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionTitle('งานที่ยังไม่เสร็จ และช่วงเวลาที่เสนอ'),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final e in suggestions.entries)
                    KeyValueRow(
                      appState.byId(e.key)?.name ?? '',
                      Text(e.value, style: AppText.muted),
                      last: e.key == suggestions.keys.last,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          InfoBanner(icon: Icons.warning_amber_rounded, tone: Tone.mid, text: 'ข้อจำกัด: ${o.cons} — หากต้องการ สามารถปรับแผนได้เอง'),
        ],
      ),
      bottomNavigationBar: bottomBar([
        Expanded(
          child: AppButton('ปรับแผน', variant: ButtonVariant.ghost, icon: Icons.edit_outlined, onPressed: () => Navigator.pushNamed(context, Routes.adjust, arguments: code)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton('ยอมรับแผนนี้', icon: Icons.check, onPressed: () {
            appState.confirmPlan(code, o.blocks);
            showSnack(context, 'ยืนยันแผนทางเลือก $code แล้ว');
            goHomeTab(context, 2);
          }),
        ),
      ]),
    );
  }
}

/// 6.3.7 หน้าเลือก/ปรับแผน (FR-12)
class AdjustPlanScreen extends StatefulWidget {
  const AdjustPlanScreen({super.key});

  @override
  State<AdjustPlanScreen> createState() => _AdjustPlanScreenState();
}

class _AdjustPlanScreenState extends State<AdjustPlanScreen> {
  bool _initialized = false;
  late String _code;
  late PlanOption _original;
  List<PlanBlock> _blocks = [];
  bool _changed = false;

  DecisionEngine get _engine => appState.engine();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final result = appState.lastResult;
    _code = ModalRoute.of(context)?.settings.arguments as String? ?? result?.recommendedCode ?? 'A';
    if (result != null) {
      _original = result.byCode(_code);
      _blocks = _original.blocks.map((b) => b.copy()).toList();
    } else {
      _original = _engine.evaluate(_code, '', []);
    }
  }

  int _usedIn(TimeSlot s) => _blocks.where((b) => b.slotStart == s.start).fold<int>(0, (x, b) => x + b.minutes);

  void _update(VoidCallback change) {
    setState(() {
      change();
      _changed = true;
      _blocks = _engine.layout(_blocks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eng = _engine;
    final current = eng.evaluate(_code, _original.title, eng.layout(_blocks));
    final alloc = <String, int>{};
    for (final b in _blocks) {
      alloc[b.activityId] = (alloc[b.activityId] ?? 0) + b.minutes;
    }
    final pool = eng.activities.where((a) => a.minutes - (alloc[a.id] ?? 0) > 0).toList();
    final slots = appState.slots;

    return Scaffold(
      appBar: appHeader('ปรับแผน', subtitle: 'เริ่มจากทางเลือก $_code · ปรับเวลา ย้าย หรือเพิ่มกิจกรรม'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final slot in slots) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'ช่วง ${hm(slot.start)}–${hm(slot.end)} · ว่างเหลือ ${duration(slot.minutes - _usedIn(slot))}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
            ),
            for (final b in _blocks.where((b) => b.slotStart == slot.start)) _blockTile(b, slot),
            const SizedBox(height: 8),
          ],
          const SectionTitle('งานที่ยังไม่อยู่ในแผน / ยังไม่ครบเวลา'),
          const SizedBox(height: 10),
          if (pool.isEmpty) const Text('ทุกกิจกรรมได้รับเวลาครบแล้ว', style: AppText.muted),
          for (final a in pool)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                radius: 12,
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(child: Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text('เหลือ ${duration(a.minutes - (alloc[a.id] ?? 0))}', style: AppText.small),
                    IconButton(
                      tooltip: 'เพิ่ม ${a.name} ลงแผน',
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                      onPressed: _bestSlot(slots) == null ? null : () => _add(a, a.minutes - (alloc[a.id] ?? 0), slots),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('ผลกระทบหลังปรับ (คำนวณใหม่)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                _diff('งานที่เสร็จ', '${_original.completedIds.length} งาน', '${current.completedIds.length} งาน'),
                _diff('งานที่ต้องเลื่อน', '${_original.postponedIds.length} งาน', '${current.postponedIds.length} งาน'),
                _diff('ความเสี่ยงต่อ Deadline', _original.risk.label, current.risk.label, tone: riskTone(current.risk)),
                _diff('ความสอดคล้องกับเป้าหมาย', '${_original.alignment}%', '${current.alignment}%', last: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomBar([
        Expanded(child: AppButton('ยกเลิก', variant: ButtonVariant.ghost, onPressed: () => Navigator.pop(context))),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton('ยืนยันแผน', icon: Icons.check, onPressed: () {
            appState.confirmPlan(_code, _blocks, adjusted: _changed);
            showSnack(context, _changed ? 'บันทึกแผนที่ปรับแล้ว' : 'ยืนยันแผนแล้ว');
            goHomeTab(context, 2);
          }),
        ),
      ]),
    );
  }

  TimeSlot? _bestSlot(List<TimeSlot> slots) {
    TimeSlot? best;
    var bestFree = 14;
    for (final s in slots) {
      final free = s.minutes - _usedIn(s);
      if (free > bestFree) {
        best = s;
        bestFree = free;
      }
    }
    return best;
  }

  void _add(Activity a, int remaining, List<TimeSlot> slots) {
    final slot = _bestSlot(slots);
    if (slot == null) return;
    final free = slot.minutes - _usedIn(slot);
    _update(() => _blocks.add(PlanBlock(activityId: a.id, slotStart: slot.start, minutes: remaining < free ? remaining : free, adjusted: true)));
  }

  Widget _blockTile(PlanBlock b, TimeSlot slot) {
    final a = appState.byId(b.activityId);
    final free = slot.minutes - _usedIn(slot);
    final others = appState.slots.where((s) => s.start != slot.start && s.minutes - _usedIn(s) >= b.minutes).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: 14,
        borderColor: b.adjusted ? AppColors.blue : AppColors.line,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            Container(width: 4, height: 44, decoration: BoxDecoration(color: a == null ? AppColors.line : toneFg(priorityTone(a.priority)), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(a?.name ?? '', style: AppText.bodyStrong),
                      if (b.adjusted) const Pill('ปรับแล้ว', tone: Tone.blue),
                    ],
                  ),
                  Text('${hm(b.start)} – ${hm(b.end)} · ${duration(b.minutes)}', style: AppText.muted),
                ],
              ),
            ),
            IconButton(
              tooltip: 'ลด 15 นาที',
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              onPressed: b.minutes > 15
                  ? () => _update(() {
                        b.minutes -= 15;
                        b.adjusted = true;
                      })
                  : null,
            ),
            IconButton(
              tooltip: 'เพิ่ม 15 นาที',
              icon: const Icon(Icons.add_circle_outline, size: 22),
              onPressed: free >= 15
                  ? () => _update(() {
                        b.minutes += 15;
                        b.adjusted = true;
                      })
                  : null,
            ),
            PopupMenuButton<String>(
              tooltip: 'ตัวเลือกเพิ่มเติม',
              onSelected: (v) {
                if (v == 'remove') {
                  _update(() => _blocks.remove(b));
                } else {
                  final target = int.parse(v);
                  _update(() {
                    b.slotStart = target;
                    b.adjusted = true;
                  });
                }
              },
              itemBuilder: (ctx) => [
                for (final s in others) PopupMenuItem(value: '${s.start}', child: Text('ย้ายไปช่วง ${hm(s.start)}–${hm(s.end)}')),
                const PopupMenuItem(value: 'remove', child: Text('นำออกจากแผน', style: TextStyle(color: AppColors.high))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _diff(String label, String before, String after, {Tone tone = Tone.blue, bool last = false}) {
    final same = before == after;
    return KeyValueRow(
      label,
      same
          ? Text(after, style: AppText.label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(before, style: const TextStyle(fontSize: 13, color: AppColors.muted, decoration: TextDecoration.lineThrough)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 14, color: AppColors.muted)),
                Pill(after, tone: tone),
              ],
            ),
      last: last,
    );
  }
}

import 'dart:math' as math;

import '../models/models.dart';
import '../utils/format.dart';

/// ส่วน "AI" ของต้นแบบ: วิเคราะห์สถานการณ์ (FR-07) สร้างทางเลือก A/B/C (FR-08)
/// ประเมินผลกระทบ (FR-09) สร้างคำแนะนำ (FR-10) และเหตุผล (FR-11)
///
/// ในต้นแบบนี้ใช้กฎการให้คะแนน (rule-based scoring) ที่อธิบายได้
/// หากเชื่อมต่อ AI Service จริง ให้แทนที่เมธอด [analyse] ด้วยการเรียก API
/// แล้วแปลงผลลัพธ์เป็น [AiResult] ในรูปแบบเดียวกัน
class DecisionEngine {
  DecisionEngine({
    required List<Activity> activities,
    required this.slots,
    required this.goals,
    required this.now,
    this.history = const [],
    this.weights = const [40, 30, 20, 10],
    this.balancedCap = 90,
  }) : activities = activities.where((a) => a.minutes > 0 && a.status != ActivityStatus.done).toList();

  final List<Activity> activities; // กิจกรรมที่ยังไม่เสร็จและถูกเลือกให้ AI พิจารณา
  final List<TimeSlot> slots;
  final List<String> goals; // เรียงตามลำดับความสำคัญ (ตัวแรก = เป้าหมายหลัก)
  final DateTime now;
  final List<Activity> history; // กิจกรรมที่เสร็จแล้ว ใช้ดูพฤติกรรมการใช้เวลา

  /// น้ำหนักปัจจัย [Deadline, ความสำคัญ, เป้าหมาย, ประวัติการใช้เวลา] จากหน้าตั้งค่าระบบ
  final List<int> weights;

  /// เวลาสูงสุดต่องานในทางเลือก C (นาที) จากหน้าตั้งค่าระบบ
  final int balancedCap;

  int get freeMinutes => slots.fold(0, (sum, s) => sum + s.minutes);

  Activity? _find(String id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  double goalWeight(Activity a) {
    final i = goals.indexOf(a.goal);
    if (i == 0) return 1.0;
    if (i > 0) return 0.8;
    if (a.type == ActivityType.health) return 0.3;
    return 0.2;
  }

  int daysLeft(Activity a) => a.recurring ? 99 : daysBetween(now, a.deadline);

  // ---------------------------------------------------------------- analyse
  AiResult analyse() {
    final options = <PlanOption>[
      evaluate('A', 'เน้น Deadline', _fill(_orderByDeadline())),
      evaluate('B', 'เน้นเป้าหมาย', _fill(_orderByGoal())),
      evaluate('C', 'เน้นความสมดุล', _fill(_orderBalanced(), cap: balancedCap)),
    ];
    final ranked = [...options]..sort(_compare);
    return AiResult(
      options: options,
      recommendedCode: ranked.first.code,
      summaries: {for (final o in options) o.code: summaryFor(o)},
      factors: {for (final o in options) o.code: factorsFor(o)},
      suggestions: {for (final o in options) o.code: suggestionsFor(o)},
    );
  }

  /// เกณฑ์เลือกคำแนะนำ: คะแนนรวมตามน้ำหนักสูงสุด → ความเสี่ยงต่ำกว่า → ทำเสร็จได้มากกว่า
  int _compare(PlanOption x, PlanOption y) {
    final s = y.score.compareTo(x.score);
    if (s != 0) return s;
    final r = x.risk.index.compareTo(y.risk.index);
    if (r != 0) return r;
    return y.completedIds.length.compareTo(x.completedIds.length);
  }

  /// คะแนนรวม 0–100 จากปัจจัย 4 ด้าน ถ่วงด้วยน้ำหนักที่ผู้ดูแลระบบตั้งไว้
  /// - Deadline: ความเสี่ยงต่ำ = 1, กลาง = 0.5, สูง = 0
  /// - ความสำคัญ: สัดส่วนงานความสำคัญสูงที่ได้อยู่ในแผน
  /// - เป้าหมาย: ความสอดคล้องกับเป้าหมาย (%)
  /// - ประวัติการใช้เวลา: สัดส่วนช่วงที่เป็นงานเต็ม (งานที่ถูกหั่นบางส่วนเสี่ยงใช้เวลาเกินตามพฤติกรรมเดิม)
  double _score(Risk risk, List<PlanBlock> blocks, int alignment, List<String> partial) {
    final total = weights.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 0;
    final deadline = 1 - risk.index / 2;
    final highs = activities.where((a) => a.priority == Priority.high).toList();
    final planned = blocks.map((b) => b.activityId).toSet();
    final priority = highs.isEmpty ? 1.0 : highs.where((a) => planned.contains(a.id)).length / highs.length;
    final goal = alignment / 100;
    final partialBlocks = blocks.where((b) => partial.contains(b.activityId)).length;
    final fit = blocks.isEmpty ? 0.0 : 1 - partialBlocks / blocks.length;
    final raw = weights[0] * deadline + weights[1] * priority + weights[2] * goal + weights[3] * fit;
    return raw / total * 100;
  }

  // ------------------------------------------------------- ลำดับตามกลยุทธ์
  int _byDeadline(Activity a, Activity b) {
    final r = (a.recurring ? 1 : 0).compareTo(b.recurring ? 1 : 0);
    if (r != 0) return r;
    final d = a.deadline.compareTo(b.deadline);
    if (d != 0) return d;
    return b.priority.index.compareTo(a.priority.index);
  }

  List<Activity> _orderByDeadline() => [...activities]..sort(_byDeadline);

  List<Activity> _orderByGoal() {
    int rank(Activity a) {
      final i = goals.indexOf(a.goal);
      if (i >= 0) return i;
      return goals.length + (a.type == ActivityType.health ? 0 : 1);
    }

    return [...activities]
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final p = b.priority.index.compareTo(a.priority.index);
        if (p != 0) return p;
        return _byDeadline(a, b);
      });
  }

  List<Activity> _orderBalanced() {
    double score(Activity a) {
      final d = daysLeft(a);
      final urgency = d <= 1 ? 3 : (d <= 3 ? 2 : 1);
      return (a.priority.weight * 2 + urgency).toDouble() + goalWeight(a) * 2;
    }

    final list = [...activities]..sort((a, b) => score(b).compareTo(score(a)));
    // ความสมดุล: ให้กิจกรรมด้านสุขภาพได้รับเวลาเป็นลำดับต้น ๆ
    final healthIndex = list.indexWhere((a) => a.type == ActivityType.health);
    if (healthIndex > 1) {
      final h = list.removeAt(healthIndex);
      list.insert(1, h);
    }
    return list;
  }

  // ------------------------------------------------------------ จัดลงช่องเวลา
  /// วางกิจกรรมตามลำดับลงช่วงเวลาว่างแบบ first-fit
  /// ถ้าไม่มีช่วงที่พอ จะใส่บางส่วนในช่วงที่เหลือมากที่สุด (อย่างน้อย 15 นาที)
  List<PlanBlock> _fill(List<Activity> order, {int? cap}) {
    final remaining = [for (final s in slots) s.minutes];
    final blocks = <PlanBlock>[];
    for (final a in order) {
      var want = cap == null ? a.minutes : math.min(a.minutes, cap);
      var idx = remaining.indexWhere((r) => r >= want);
      if (idx < 0) {
        var best = -1;
        var bestValue = 0;
        for (var i = 0; i < remaining.length; i++) {
          if (remaining[i] > bestValue) {
            best = i;
            bestValue = remaining[i];
          }
        }
        if (best < 0 || bestValue < 15) continue;
        idx = best;
        want = bestValue;
      }
      blocks.add(PlanBlock(activityId: a.id, slotStart: slots[idx].start, minutes: want));
      remaining[idx] -= want;
    }
    return layout(blocks);
  }

  /// คำนวณเวลาเริ่ม-สิ้นสุดของแต่ละช่วง เรียงต่อกันภายในช่วงเวลาว่างเดียวกัน
  List<PlanBlock> layout(List<PlanBlock> blocks) {
    final out = <PlanBlock>[];
    for (final s in slots) {
      var cursor = s.start;
      for (final b in blocks.where((b) => b.slotStart == s.start)) {
        b.start = cursor;
        cursor += b.minutes;
        out.add(b);
      }
    }
    return out;
  }

  // ------------------------------------------------------------ ประเมินผลกระทบ
  PlanOption evaluate(String code, String title, List<PlanBlock> blocks) {
    final alloc = <String, int>{};
    for (final b in blocks) {
      alloc[b.activityId] = (alloc[b.activityId] ?? 0) + b.minutes;
    }
    final completed = <String>[];
    final partial = <String>[];
    final postponed = <String>[];
    for (final a in activities) {
      final m = alloc[a.id] ?? 0;
      if (m >= a.minutes) {
        completed.add(a.id);
      } else if (m > 0) {
        partial.add(a.id);
      } else {
        postponed.add(a.id);
      }
    }
    final used = blocks.fold<int>(0, (s, b) => s + b.minutes);

    var risk = Risk.low;
    String? riskyName;
    for (final id in [...partial, ...postponed]) {
      final a = _find(id);
      if (a == null || a.recurring) continue;
      final d = daysLeft(a);
      final Risk r;
      if (d <= 1) {
        r = Risk.high;
      } else if (d <= 2 || (a.priority == Priority.high && d <= 5)) {
        r = Risk.medium;
      } else {
        r = Risk.low;
      }
      if (r.index > risk.index) {
        risk = r;
        riskyName = a.name;
      }
    }

    var weighted = 0.0;
    for (final b in blocks) {
      final a = _find(b.activityId);
      if (a != null) weighted += goalWeight(a) * b.minutes;
    }
    final alignment = used == 0 ? 0 : (weighted / used * 100).round();
    final hasHealth = blocks.any((b) => _find(b.activityId)?.type == ActivityType.health);
    final healthPending = activities.any((a) => a.type == ActivityType.health);

    final pros = <String>[
      if (completed.isNotEmpty) 'ทำเสร็จ ${completed.length} งาน',
      if (risk == Risk.low) 'ไม่มีงานเสี่ยงเลยกำหนด',
      if (alignment >= 90) 'ตรงกับเป้าหมายหลักมาก',
      if (hasHealth) 'มีเวลาดูแลสุขภาพ',
      if (freeMinutes > 0 && used >= freeMinutes) 'ใช้เวลาว่างครบ',
    ];
    final cons = <String>[
      if (riskyName != null) '${risk == Risk.high ? 'เสี่ยงไม่ทัน' : 'ต้องทำต่อ'}: $riskyName',
      if (!hasHealth && healthPending) 'ไม่มีเวลาออกกำลังกาย',
      if (postponed.length >= 3) 'ต้องเลื่อน ${postponed.length} งาน',
    ];

    return PlanOption(
      code: code,
      title: title,
      blocks: blocks,
      completedIds: completed,
      partialIds: partial,
      postponedIds: postponed,
      usedMinutes: used,
      freeMinutes: freeMinutes,
      risk: risk,
      alignment: alignment,
      pros: pros.isEmpty ? '—' : pros.take(2).join(' · '),
      cons: cons.isEmpty ? 'ไม่มีข้อจำกัดสำคัญ' : cons.take(2).join(' · '),
      score: _score(risk, blocks, alignment, partial),
    );
  }

  // ------------------------------------------------------ คำแนะนำและเหตุผล
  String summaryFor(PlanOption o) {
    if (o.blocks.isEmpty) return 'ยังไม่มีช่วงเวลาว่างเพียงพอสำหรับจัดกิจกรรม ลองเพิ่มช่วงเวลาว่าง';
    final first = _find(o.blocks.first.activityId);
    if (first == null) return '';
    final byDeadline = activities.where((a) => !a.recurring).toList()..sort((a, b) => a.deadline.compareTo(b.deadline));
    final reasons = <String>[
      if (byDeadline.isNotEmpty && byDeadline.first.id == first.id) 'มี Deadline ใกล้ที่สุด',
      if (first.priority == Priority.high) 'มีความสำคัญสูง',
      if (goals.isNotEmpty && first.goal == goals.first) 'สอดคล้องกับเป้าหมาย “${goals.first}”',
    ];
    final why = reasons.isEmpty ? '' : ' เนื่องจาก${reasons.join(' และ')}';
    return 'แนะนำให้ทำ “${first.name}” ก่อน$why';
  }

  List<DecisionFactor> factorsFor(PlanOption o) {
    final byDeadline = activities.where((a) => !a.recurring).toList()..sort((a, b) => a.deadline.compareTo(b.deadline));
    final nearest = byDeadline.isEmpty ? null : byDeadline.first;
    final planned = o.blocks.map((b) => b.activityId).toSet();
    final highs = activities.where((a) => a.priority == Priority.high).toList();
    final highsIn = highs.where((a) => planned.contains(a.id)).length;

    final logged = history.where((a) => a.actualMinutes != null && a.minutes > 0).toList();
    String historyNote;
    if (logged.length < 3) {
      historyNote = 'ยังมีข้อมูลประวัติไม่มากพอ ระบบจะเรียนรู้เพิ่มเมื่อคุณบันทึกผลการทำกิจกรรม';
    } else {
      final planSum = logged.fold<int>(0, (s, a) => s + a.minutes);
      final actualSum = logged.fold<int>(0, (s, a) => s + (a.actualMinutes ?? 0));
      final pct = ((actualSum - planSum) / planSum * 100).round();
      historyNote = pct > 0
          ? 'ที่ผ่านมาคุณใช้เวลาจริงมากกว่าที่ประเมินเฉลี่ย $pct% จึงจัดงานใหญ่เป็นช่วงยาวต่อเนื่อง'
          : 'ที่ผ่านมาคุณทำกิจกรรมได้ภายในเวลาที่ประเมินไว้';
    }

    final String deadlineNote;
    if (nearest == null) {
      deadlineNote = 'ไม่มีงานที่มีกำหนดส่ง';
    } else {
      final inPlan = planned.contains(nearest.id) ? 'อยู่ในแผนนี้' : 'ไม่อยู่ในแผนนี้';
      deadlineNote = 'งานที่ใกล้ครบกำหนดที่สุด: “${nearest.name}” (${relativeDeadline(nearest.deadline, now)}) — $inPlan';
    }
    final goalNote = goals.isEmpty ? '' : ' (เป้าหมายหลัก: ${goals.first})';

    return [
      DecisionFactor('Deadline', weights[0], deadlineNote),
      DecisionFactor('ความสำคัญ', weights[1], 'งานความสำคัญสูงอยู่ในแผน $highsIn จาก ${highs.length} งาน'),
      DecisionFactor('เป้าหมาย', weights[2], 'ความสอดคล้องกับเป้าหมาย ${o.alignment}%$goalNote'),
      DecisionFactor('ประวัติการใช้เวลา', weights[3], historyNote),
    ];
  }

  /// เสนอช่วงเวลาของวันพรุ่งนี้ให้กับงานที่ถูกเลื่อนหรือยังทำไม่เสร็จ
  Map<String, String> suggestionsFor(PlanOption o) {
    final alloc = <String, int>{};
    for (final b in o.blocks) {
      alloc[b.activityId] = (alloc[b.activityId] ?? 0) + b.minutes;
    }
    final remaining = [for (final s in slots) s.minutes];
    final cursor = [for (final s in slots) s.start];
    final result = <String, String>{};
    for (final id in [...o.partialIds, ...o.postponedIds]) {
      final a = _find(id);
      if (a == null) continue;
      final need = a.minutes - (alloc[id] ?? 0);
      final i = remaining.indexWhere((r) => r >= need);
      if (i < 0) {
        result[id] = 'ยังไม่มีช่วงว่างพอ (ต้องการ ${duration(need)})';
        continue;
      }
      result[id] = 'พรุ่งนี้ ${hm(cursor[i])} (${duration(need)})';
      cursor[i] += need;
      remaining[i] -= need;
    }
    return result;
  }
}

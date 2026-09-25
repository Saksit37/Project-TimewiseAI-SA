// โมเดลข้อมูลของระบบ (สอดคล้องกับ ER-Diagram: USER, ACTIVITY, RECOMMENDATION,
// SCHEDULE, SCHEDULE_ITEM, HISTORY_LOG)

enum Priority { low, medium, high }

extension PriorityX on Priority {
  String get label => const ['ต่ำ', 'กลาง', 'สูง'][index];
  int get weight => index + 1;
}

enum ActivityStatus { todo, inProgress, done }

extension ActivityStatusX on ActivityStatus {
  String get label => const ['ยังไม่เสร็จ', 'กำลังทำ', 'เสร็จแล้ว'][index];
}

enum ActivityType { study, work, health, personal }

extension ActivityTypeX on ActivityType {
  String get label => const ['การเรียน', 'งาน', 'สุขภาพ', 'ส่วนตัว'][index];
}

/// ACTIVITY + ข้อมูลผลการทำจริง (HISTORY_LOG)
class Activity {
  Activity({
    required this.id,
    required this.name,
    required this.type,
    required this.minutes,
    required this.deadline,
    required this.priority,
    this.goal = '',
    this.recurring = false,
    this.status = ActivityStatus.todo,
    this.note = '',
    this.actualMinutes,
    this.feedbackGood,
    this.feedbackNote = '',
    this.completedAt,
  });

  final String id;
  String name;
  ActivityType type;
  int minutes; // เวลาที่คาดว่าจะใช้ (นาที)
  DateTime deadline;
  Priority priority;
  String goal;
  bool recurring;
  ActivityStatus status;
  String note;
  int? actualMinutes; // เวลาที่ใช้จริง (FR-15)
  bool? feedbackGood; // Feedback ต่อคำแนะนำ
  String feedbackNote;
  DateTime? completedAt;
}

/// ช่วงเวลาว่าง เก็บเป็นนาทีนับจากเที่ยงคืน
class TimeSlot {
  const TimeSlot(this.start, this.end);
  final int start;
  final int end;
  int get minutes => end - start;
}

/// SCHEDULE_ITEM: กิจกรรมหนึ่งช่วงในแผน
class PlanBlock {
  PlanBlock({required this.activityId, required this.slotStart, required this.minutes, this.adjusted = false});

  final String activityId;
  int slotStart; // ระบุว่าอยู่ในช่วงเวลาว่างใด
  int minutes;
  bool adjusted;
  int start = 0; // คำนวณโดย DecisionEngine.layout()

  int get end => start + minutes;

  PlanBlock copy() => PlanBlock(activityId: activityId, slotStart: slotStart, minutes: minutes, adjusted: adjusted)..start = start;
}

enum Risk { low, medium, high }

extension RiskX on Risk {
  String get label => const ['ต่ำ', 'กลาง', 'สูง'][index];
}

/// ทางเลือกในการจัดสรรเวลา พร้อมผลกระทบ (Output 2.2, 2.3)
class PlanOption {
  PlanOption({
    required this.code,
    required this.title,
    required this.blocks,
    required this.completedIds,
    required this.partialIds,
    required this.postponedIds,
    required this.usedMinutes,
    required this.freeMinutes,
    required this.risk,
    required this.alignment,
    required this.pros,
    required this.cons,
    required this.score,
  });

  final String code;
  final String title;
  final List<PlanBlock> blocks;
  final List<String> completedIds;
  final List<String> partialIds;
  final List<String> postponedIds;
  final int usedMinutes;
  final int freeMinutes;
  final Risk risk;
  final int alignment; // ความสอดคล้องกับเป้าหมาย (%)
  final String pros;
  final String cons;
  final double score; // คะแนนรวมตามน้ำหนักปัจจัยที่ผู้ดูแลระบบตั้งไว้ (0–100)
}

class DecisionFactor {
  const DecisionFactor(this.name, this.weight, this.note);
  final String name;
  final int weight;
  final String note;
}

/// RECOMMENDATION: ผลลัพธ์จาก AI
class AiResult {
  AiResult({
    required this.options,
    required this.recommendedCode,
    required this.summaries,
    required this.factors,
    required this.suggestions,
  });

  final List<PlanOption> options;
  final String recommendedCode;
  final Map<String, String> summaries;
  final Map<String, List<DecisionFactor>> factors;
  final Map<String, Map<String, String>> suggestions;
  final DateTime createdAt = DateTime.now();

  PlanOption byCode(String code) => options.firstWhere((o) => o.code == code);
  PlanOption get recommended => byCode(recommendedCode);
}

enum DecisionKind { accepted, adjusted, rejected }

extension DecisionKindX on DecisionKind {
  String get label => const ['ยอมรับ', 'ปรับเอง', 'ปฏิเสธ'][index];
}

class HistoryEntry {
  HistoryEntry({
    required this.time,
    required this.kind,
    required this.title,
    required this.detail,
    required this.result,
    this.optionCode,
  });

  final DateTime time;
  final DecisionKind kind;
  final String title;
  final String detail;
  final String result;
  final String? optionCode;
}

enum NoticeKind { reminder, planChanged, deadline, logResult, report }

class AppNotice {
  AppNotice({
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.unread = true,
    this.route,
  });

  final NoticeKind kind;
  final String title;
  final String body;
  final DateTime time;
  bool unread;

  /// "tab:2" = ไปแท็บที่ 2 ของหน้าหลัก, "track:<id>" = ไปหน้าบันทึกผล
  final String? route;
}

class AppUser {
  AppUser({required this.name, required this.email, required this.joined, required this.lastActive, this.status = 'ใช้งาน'});

  String name;
  String email;
  DateTime joined;
  String lastActive;
  String status; // ใช้งาน / ระงับ / รอยืนยันอีเมล
}

/// บันทึกเหตุการณ์ของระบบ (ใช้ในหน้าผู้ดูแลระบบ)
class SystemLog {
  SystemLog({required this.time, required this.service, required this.level, required this.detail, this.status = 'รอตรวจสอบ'});

  final DateTime time;
  final String service;
  final String level; // Info / Warning / Error
  final String detail;
  String status; // รอตรวจสอบ / แก้ไขแล้ว / ปกติ

  bool get pending => status == 'รอตรวจสอบ';
}

/// การตั้งค่าระบบที่ผู้ดูแลกำหนด และมีผลกับการทำงานของแอปฝั่งผู้ใช้
class SystemSettings {
  SystemSettings({
    this.weightDeadline = 40,
    this.weightPriority = 30,
    this.weightGoal = 20,
    this.weightHistory = 10,
    this.balancedCap = 90,
    this.aiTimeoutSeconds = 10,
    this.fallbackPlan = true,
    this.reminderMinutes = 15,
    this.passwordMinLength = 8,
    this.dataRetentionDays = 365,
    this.maintenanceMode = false,
  });

  // น้ำหนักปัจจัยในการตัดสินใจของ AI (%) ต้องรวมกันได้ 100
  int weightDeadline;
  int weightPriority;
  int weightGoal;
  int weightHistory;
  int balancedCap; // เวลาสูงสุดต่องานในทางเลือก C (นาที)
  int aiTimeoutSeconds; // เวลารอ AI สูงสุดก่อนแสดงแผนสำรอง
  bool fallbackPlan;
  int reminderMinutes; // แจ้งเตือนก่อนเริ่มกิจกรรม (นาที)
  int passwordMinLength;
  int dataRetentionDays;
  bool maintenanceMode;

  int get weightTotal => weightDeadline + weightPriority + weightGoal + weightHistory;
  List<int> get weights => [weightDeadline, weightPriority, weightGoal, weightHistory];

  SystemSettings copy() => SystemSettings(
        weightDeadline: weightDeadline,
        weightPriority: weightPriority,
        weightGoal: weightGoal,
        weightHistory: weightHistory,
        balancedCap: balancedCap,
        aiTimeoutSeconds: aiTimeoutSeconds,
        fallbackPlan: fallbackPlan,
        reminderMinutes: reminderMinutes,
        passwordMinLength: passwordMinLength,
        dataRetentionDays: dataRetentionDays,
        maintenanceMode: maintenanceMode,
      );
}

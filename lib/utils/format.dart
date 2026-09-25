// ฟังก์ชันช่วยจัดรูปแบบวันที่/เวลาเป็นภาษาไทย (ไม่ต้องพึ่งแพ็กเกจ intl)

const _monthsShort = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
const _monthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const _daysFull = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
const thaiDaysShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

String two(int n) => n.toString().padLeft(2, '0');

/// นาทีนับจากเที่ยงคืน -> "HH:MM"
String hm(int minutes) => '${two(minutes ~/ 60)}:${two(minutes % 60)}';

String timeOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// 150 -> "2 ชม. 30 น."
String duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m น.';
  if (m == 0) return '$h ชม.';
  return '$h ชม. $m น.';
}

String dateShort(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';
String dateWithYear(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]} ${d.year + 543}';
String dateLong(DateTime d) => '${_daysFull[d.weekday - 1]}ที่ ${d.day} ${_monthsFull[d.month - 1]} ${d.year + 543}';
String dateWithDow(DateTime d) => '${thaiDaysShort[d.weekday - 1]}. ${d.day} ${_monthsShort[d.month - 1]} ${d.year + 543}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// จำนวนวันระหว่างสองวันที่ (ไม่สนใจเวลา)
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String relativeDeadline(DateTime deadline, DateTime now) {
  final days = daysBetween(now, deadline);
  if (days < 0) return 'เลยกำหนดแล้ว';
  if (days == 0) return 'ครบกำหนดวันนี้';
  if (days == 1) return 'ครบกำหนดพรุ่งนี้';
  return 'เหลือ $days วัน';
}

String initials(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return t.length >= 2 ? t.substring(0, 2) : t;
}

String fmtHours(double h) => h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1);

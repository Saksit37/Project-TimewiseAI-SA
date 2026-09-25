import 'package:flutter_test/flutter_test.dart';
import 'package:timewise_ai/models/models.dart';
import 'package:timewise_ai/state/app_state.dart';

void main() {
  group('DecisionEngine (FR-07 – FR-11)', () {
    late AppState state;
    late AiResult result;

    setUp(() {
      state = AppState();
      result = state.engine().analyse();
    });

    test('สร้างทางเลือก 3 แบบ (A, B, C)', () {
      expect(result.options.map((o) => o.code), ['A', 'B', 'C']);
    });

    test('ทุกทางเลือกใช้เวลาไม่เกินเวลาว่าง และไม่มีช่วงเวลาซ้อนกัน', () {
      for (final o in result.options) {
        expect(o.usedMinutes, lessThanOrEqualTo(state.freeMinutes));
        for (final slot in state.slots) {
          final blocks = o.blocks.where((b) => b.slotStart == slot.start).toList();
          for (final b in blocks) {
            expect(b.start, greaterThanOrEqualTo(slot.start));
            expect(b.end, lessThanOrEqualTo(slot.end));
          }
        }
      }
    });

    test('ทางเลือกที่แนะนำมีคะแนนรวมตามน้ำหนักสูงที่สุด', () {
      final best = result.recommended;
      for (final o in result.options) {
        expect(best.score, greaterThanOrEqualTo(o.score));
        expect(o.score, inInclusiveRange(0, 100));
      }
    });

    test('การตั้งค่าของผู้ดูแลมีผลกับ AI', () {
      final next = state.settings.copy()
        ..weightDeadline = 70
        ..weightPriority = 10
        ..weightGoal = 10
        ..weightHistory = 10
        ..balancedCap = 60;
      state.saveSettings(next);
      final r = state.engine().analyse();
      expect(r.factors[r.recommendedCode]!.first.weight, 70);
      for (final b in r.byCode('C').blocks) {
        expect(b.minutes, lessThanOrEqualTo(60));
      }
      expect(state.logs.first.service, 'ตั้งค่าระบบ');
    });

    test('มีคำอธิบายเหตุผลครบ 4 ปัจจัย', () {
      expect(result.factors[result.recommendedCode], hasLength(4));
      expect(result.summaries[result.recommendedCode], isNotEmpty);
    });
  });
}

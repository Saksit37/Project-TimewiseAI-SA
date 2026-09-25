import 'package:flutter_test/flutter_test.dart';
import 'package:timewise_ai/main.dart';

void main() {
  testWidgets('เปิดแอปแล้วแสดงหน้าเข้าสู่ระบบ', (tester) async {
    await tester.pumpWidget(const TimeWiseApp());
    await tester.pumpAndSettle();
    expect(find.text('TimeWise AI'), findsWidgets);
    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
  });
}

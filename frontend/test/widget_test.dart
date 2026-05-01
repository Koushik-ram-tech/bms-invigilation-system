import 'package:flutter_test/flutter_test.dart';

import 'package:bms_invigilation/main.dart';

void main() {
  testWidgets('BMS app shows upload workflow', (WidgetTester tester) async {
    await tester.pumpWidget(const BmsApp());
    await tester.pumpAndSettle();

    expect(find.text('Upload'), findsWidgets);
    expect(find.text('BMS Invigilation System'), findsOneWidget);
    expect(find.text('Teaching Timetable'), findsOneWidget);
    expect(find.text('CIE / Exam Schedule'), findsOneWidget);
  });
}


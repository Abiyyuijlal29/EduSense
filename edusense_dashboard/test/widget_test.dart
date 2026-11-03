import 'package:flutter_test/flutter_test.dart';
import 'package:edusense_dashboard/main.dart';

void main() {
  testWidgets('EduSense app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EduSenseApp());
    expect(find.text('Ringkasan Kampus Cerdas'), findsOneWidget);
  });
}

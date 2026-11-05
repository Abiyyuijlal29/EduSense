import 'package:flutter_test/flutter_test.dart';
import 'package:edusense_mobile/main.dart';

void main() {
  testWidgets('EduSense smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EduSenseApp());
    expect(find.text('EduSense'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterdraw/app/flutter_draw_app.dart';

void main() {
  testWidgets('renders the FlutterDraw workspace', (tester) async {
    await tester.pumpWidget(const FlutterDrawApp());

    expect(find.text('FlutterDraw'), findsOneWidget);
    expect(find.text('Свойства'), findsOneWidget);
    expect(find.text('Без названия'), findsOneWidget);
  });
}

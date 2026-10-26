import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(MyApp(), isA<MyApp>());
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/data/models/response/graphResponse.dart';

void main() {
  group('GraphResponse', () {
    test('parses decimal graph values returned by the revenue API', () {
      final response = GraphResponse.fromJson({
        'data': [
          {'label': '30-Jul', 'value': 2.5544},
        ],
        'statusCode': 200,
        'success': true,
      });

      expect(response.data, hasLength(1));
      expect(response.data!.single.label, '30-Jul');
      expect(response.data!.single.value, 2.5544);
    });

    test('also accepts integer and numeric string values', () {
      final response = GraphResponse.fromJson({
        'data': [
          {'label': '28-Jul', 'value': 0},
          {'label': '29-Jul', 'value': '1.25'},
        ],
      });

      expect(response.data!.map((point) => point.value), [0.0, 1.25]);
    });
  });
}

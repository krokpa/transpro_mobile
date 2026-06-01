// Smoke test — ensures the test suite itself runs cleanly.
// Full unit tests live in test/models/ and test/auth/.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test — test harness is healthy', (tester) async {
    expect(true, isTrue);
  });
}

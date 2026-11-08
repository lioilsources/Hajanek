import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Widget tests read Czech strings: the phone speaks Czech unless a test
/// says otherwise. Starting the binding here also installs its fake
/// HttpClient (every request 400); the API tests talk to local servers, so
/// it is taken back out.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.localesTestValue = const [Locale('cs', 'CZ')];
  HttpOverrides.global = null;
  await testMain();
}

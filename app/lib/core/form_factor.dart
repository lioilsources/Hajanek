import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phone (touch) or TV (remote, 10-foot UI). Branch on this, not on the OS:
/// `Platform.isIOS` is true on tvOS and Android TV is plain Android.
enum FormFactor { phone, tv }

/// Overridden in main() with [detectFormFactor].
final formFactorProvider = Provider<FormFactor>((ref) => FormFactor.phone);

/// `--dart-define=FORM_FACTOR=tv` forces the TV UI (e.g. on a phone emulator).
const _forced = String.fromEnvironment('FORM_FACTOR');

const _channel = MethodChannel('com.ol1n.hajanek/device');

/// Asks the platform (Android `UiModeManager`); no answer = phone.
Future<FormFactor> detectFormFactor() async {
  if (_forced == 'tv') return FormFactor.tv;
  if (_forced == 'phone') return FormFactor.phone;
  try {
    return await _channel.invokeMethod<bool>('isTv') == true ? FormFactor.tv : FormFactor.phone;
  } on MissingPluginException {
    return FormFactor.phone;
  } on PlatformException catch (e) {
    debugPrint('isTv: $e');
    return FormFactor.phone;
  }
}

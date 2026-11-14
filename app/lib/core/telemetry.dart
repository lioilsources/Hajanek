import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import '../features/timer/sleep_timer.dart';
import 'strings.dart';

/// The app version this build reports; `test/telemetry_test.dart` keeps it
/// equal to `version:` in `pubspec.yaml`.
const kAppVersion = '1.1.0';

/// The app's id in StoreMetrics (`apps.yaml`).
const kTelemetryApp = 'hajanek';

/// go_router route name (`GoRouterState.path`, the route pattern) → screen.
/// Phone and TV share the paths; `form` tells them apart.
const kScreenRoutes = {
  '/': 'home',
  '/tale/:id': 'tale',
  '/player': 'player',
  '/mixer': 'mixer',
  '/settings': 'settings',
  '/voice': 'voice',
  '/voice/record': 'voice_record',
};

/// Tales of the bundled catalog. A tale that arrives later with a catalog
/// update reports `other` until the dictionary learns it.
const kTelemetryTales = {
  'budulinek',
  'cervena-karkulka',
  'dlouhy-siroky-bystrozraky',
  'hrnecku-var',
  'o-smolickovi',
  'pernikova-chaloupka',
  'sipkova-ruzenka',
  'snehurka',
  'tri-prasatka',
  'zlatovlaska',
};

String telemetryTale(String id) => kTelemetryTales.contains(id) ? id : 'other';

String _timerToken(SleepTimerOption o) => switch (o.kind) {
      SleepTimerKind.off => 'off',
      SleepTimerKind.endOfTale => 'end_of_tale',
      SleepTimerKind.minutes => '${o.minutes}',
    };

/// The sleep timer choices as tokens: `off`, `5` … `60`, `end_of_tale`, and
/// `other` for a stored value that is no longer offered.
final kTimerTokens = {for (final c in SleepTimerOption.choices) _timerToken(c), 'other'};

String telemetryTimer(SleepTimerOption o) {
  final t = _timerToken(o);
  return kTimerTokens.contains(t) ? t : 'other';
}

/// What plays when the app goes to the background: `tale`, `jukebox`,
/// `paused` (a session is open but paused) or `none`. Kept up to date by
/// the player; read only by `session_pause`.
String telemetryAudio = 'none';

/// Ways a playback session ends.
const kPlayResults = {'stop', 'timer', 'replaced'};

/// The one event dictionary of Hajánek, mirrored in `docs/telemetry.md`.
final hajanekDictionary = TelemetryDictionary(
  appVersion: kAppVersion,
  languages: supportedLangs.toSet(),
  screens: kScreenRoutes.values.toSet(),
  features: {
    'ritual_skip',
    'timer',
    'jukebox',
    'mix_layers',
    'mix_save',
    'background',
    'favourite',
    'balance',
    'voice_record',
    'tv_pair',
    'lang',
  },
  errorKinds: {'script_load', 'voice_api', 'recording', 'tts_missing'},
  common: {
    'form': const EnumProp({'phone', 'tv'}),
  },
  sessionPause: {
    'audio': const EnumProp({'tale', 'jukebox', 'paused', 'none'}),
  },
  events: {
    ...TelemetryDictionary.flow(
      'tale_play',
      results: kPlayResults,
      start: {
        'tale': EnumProp({...kTelemetryTales, 'other'}),
        'voice': const EnumProp({'system', 'parent'}),
        'ritual': const BoolProp(),
        'timer': EnumProp(kTimerTokens),
        'layers': const IntProp(10),
      },
      end: {
        'voice_done': const BoolProp(),
        'pct': const IntProp(100),
        'mins': const IntProp(1440),
      },
    ),
    ...TelemetryDictionary.flow(
      'jukebox',
      results: kPlayResults,
      start: {'layers': const IntProp(10)},
      end: {'mins': const IntProp(1440)},
    ),
    'timer_set': {
      'timer': EnumProp(kTimerTokens),
      'during': const EnumProp({'tale', 'jukebox', 'none', 'settings'}),
    },
  },
);

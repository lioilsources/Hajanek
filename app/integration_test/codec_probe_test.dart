// Probes which audio containers/codecs just_audio can play on this platform.
// Run: flutter test integration_test/codec_probe_test.dart -d <simulator>
//   --dart-define=PROBE_DIR=/abs/dir/with/probe files
// (the iOS simulator can read host paths, a real device cannot).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';

const probeDir = String.fromEnvironment('PROBE_DIR');
const probes = [
  'probe.opus',
  'probe.caf',
  'probe_opus.mp4',
  'probe_opus.webm',
  'probe.m4a',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final name in probes) {
    testWidgets('probe $name', (tester) async {
      final player = AudioPlayer();
      String result;
      try {
        final duration = await player
            .setFilePath('$probeDir/$name')
            .timeout(const Duration(seconds: 10));
        player.setVolume(0);
        player.play();
        await Future<void>.delayed(const Duration(seconds: 2));
        final pos = player.position;
        result = 'duration=$duration position=$pos '
            'playing=${pos > const Duration(milliseconds: 500) ? 'YES' : 'NO'}';
      } catch (e) {
        result = 'ERROR ${e.toString().split('\n').first}';
      } finally {
        await player.dispose();
      }
      // ignore: avoid_print
      print('CODEC_PROBE $name: $result');
    });
  }
}

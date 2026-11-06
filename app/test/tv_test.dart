import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/app.dart';
import 'package:hajanek/core/db/database.dart';
import 'package:hajanek/core/form_factor.dart';
import 'package:hajanek/core/providers.dart';
import 'package:hajanek/core/strings.dart';
import 'package:hajanek/features/catalog/catalog_controller.dart';
import 'package:hajanek/features/player/player_controller.dart';
import 'package:hajanek/features/player/ritual.dart';
import 'package:hajanek/features/tv/tv_player_screen.dart';
import 'package:hajanek/features/tv/tv_voice_screen.dart';
import 'package:hajanek/features/voice/voice_api.dart';
import 'package:hajanek/features/voice/voice_controller.dart';
import 'package:hajanek/features/voice/voice_screen.dart';

import 'home_screen_test.dart' show bundledSnapshot;

/// Pairing without a server.
class _PairingApi extends VoiceApi {
  _PairingApi() : super(tokens: MemoryTokenStore());
  var claimed = false;
  final claims = <String>[];

  @override
  Future<PairingCode> createPairing() async =>
      PairingCode(code: '483920', expiresAt: DateTime.now().add(const Duration(minutes: 10)));

  @override
  Future<bool> pairingClaimed(String code) async => claimed;

  @override
  Future<void> claimPairing(String code) async {
    if (code != '483920') throw VoiceApiException('x', status: 404);
    claims.add(code);
  }

  @override
  Future<bool> hasDevice() async => false;
}

class _FixedPlayer extends PlayerController {
  _FixedPlayer(this.fixed);
  final PlayerState fixed;
  int toggles = 0;
  @override
  PlayerState build() => fixed;
  @override
  Future<void> togglePlay() async => toggles++;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app({
    FormFactor formFactor = FormFactor.tv,
    Widget? home,
    VoiceApi? api,
    PlayerController Function()? player,
    void Function(bool)? wakelock,
    bool cloning = true,
  }) =>
      ProviderScope(
        overrides: [
          formFactorProvider.overrideWithValue(formFactor),
          databaseProvider.overrideWithValue(db),
          initialCatalogProvider.overrideWithValue(bundledSnapshot()),
          favouritesProvider.overrideWithValue(const AsyncValue.data({})),
          userPresetsProvider.overrideWithValue(const AsyncValue.data([])),
          czechVoiceAvailableProvider.overrideWith((ref) async => true),
          voiceApiProvider.overrideWithValue(api),
          voiceCloningProvider.overrideWithValue(cloning),
          if (player != null) playerProvider.overrideWith(player),
          if (wakelock != null) wakelockProvider.overrideWithValue(wakelock),
        ],
        child: home == null ? const HajanekApp() : MaterialApp(home: home),
      );

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  /// Key of the nearest keyed ancestor of the focused widget that starts with [prefix].
  String? focused([String prefix = '']) {
    String? out;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
      final k = e.widget.key;
      if (k is ValueKey<String> && k.value.startsWith(prefix)) {
        out = k.value;
        return false;
      }
      return true;
    });
    return out;
  }

  String? focusedTale() => focused('tale-')?.substring(5);

  /// A 1080p TV: 960×540 logical pixels.
  void tvSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('TV home: grid driven by the remote, select opens the tale', (tester) async {
    tvSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text(S.tvBackground), findsOneWidget);
    expect(find.text(S.homeJukebox), findsNothing, reason: 'phone home is not used');

    final tales = bundledSnapshot().catalog.tales;
    expect(focusedTale(), tales[0].id, reason: 'first tale has focus');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedTale(), tales[1].id);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedTale(), tales[4].id, reason: '3 columns');

    await press(tester, LogicalKeyboardKey.select);
    expect(find.text(tales[4].title), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-play')), findsOneWidget);
    expect(focused('tv-'), 'tv-play');
    expect(find.text(S.voiceSystemTv), findsOneWidget, reason: 'TV voice, not the phone one');
  });

  testWidgets('TV routes have no recording screen', (tester) async {
    final router = buildRouter(FormFactor.tv);
    addTearDown(router.dispose);
    final paths = router.configuration.routes.map((r) => (r as dynamic).path as String);
    expect(paths, isNot(contains('/voice/record')));
    expect(buildRouter().configuration.routes.length, paths.length + 1);
  });

  testWidgets('TV player: fades out, first key only wakes, play/pause key toggles', (tester) async {
    tvSize(tester);
    late _FixedPlayer p;
    await tester.pumpWidget(app(
      home: const TvPlayerScreen(hideAfter: Duration(seconds: 10)),
      player: () => p = _FixedPlayer(PlayerState(
        kind: SessionKind.tale,
        tale: bundledSnapshot().catalog.tales.first,
        playing: true,
        phase: RitualPhase.voice,
        section: 'pribeh',
      )),
    ));
    await tester.pump();
    expect(find.textContaining('Příběh'), findsOneWidget);
    double opacity() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(opacity(), 1);

    await tester.pump(const Duration(seconds: 11));
    expect(opacity(), 0);

    // Select while dark only wakes; it doesn't press the focused button.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(opacity(), 1);
    expect(p.toggles, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(p.toggles, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(p.toggles, 2);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('TV player opened from "now playing" has focus on play/pause', (tester) async {
    tvSize(tester);
    late PlayerController ctrl;
    await tester.pumpWidget(app(player: () => ctrl = PlayerController()));
    await tester.pumpAndSettle();
    await ctrl.startMixer();
    await tester.pumpAndSettle();
    expect(focused('tv-'), 'tv-now-playing');
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(TvPlayerScreen), findsOneWidget);
    expect(focused('play-'), 'play-pause');
    // Back on the remote (Android sends it as a system pop).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.select);
    expect(focused('play-'), 'play-pause');
    await ctrl.stop();
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('TV keeps the screen on only while playing', (tester) async {
    tvSize(tester);
    final calls = <bool>[];
    late PlayerController ctrl;
    await tester.pumpWidget(app(wakelock: calls.add, player: () => ctrl = PlayerController()));
    await tester.pumpAndSettle();
    await ctrl.startMixer();
    await tester.pump();
    await ctrl.pause();
    await tester.pump();
    await ctrl.stop();
    await tester.pump();
    expect(calls, [true, false]);
  });

  testWidgets('TV pairing dialog shows the code and notices the claim', (tester) async {
    tvSize(tester);
    final api = _PairingApi();
    await tester.pumpWidget(app(home: const TvVoiceScreen(), api: api));
    await tester.pumpAndSettle();
    expect(find.text(S.voiceSystemTv), findsOneWidget);
    expect(find.text(S.voiceRecord), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tv-pair')));
    await tester.pumpAndSettle();
    expect(find.text('483 920'), findsOneWidget);
    expect(find.text(S.pairWaiting), findsOneWidget);

    api.claimed = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(S.pairDone), findsOneWidget);
    await tester.tap(find.text(S.pairClose));
    await tester.pumpAndSettle();
  });

  testWidgets('TV without cloning has no pairing', (tester) async {
    tvSize(tester);
    await tester.pumpWidget(app(home: const TvVoiceScreen(), cloning: false));
    await tester.pumpAndSettle();
    expect(find.text(S.voiceSystemTv), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-pair')), findsNothing);
    expect(find.text(S.voiceParentTvHint), findsNothing);
  });

  testWidgets('phone: Propojit televizi claims the typed code; wrong code explains', (tester) async {
    final api = _PairingApi();
    await tester.pumpWidget(app(formFactor: FormFactor.phone, home: const VoiceScreen(), api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pair-tv')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('pair-code-field')), '111 111');
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.pairConfirm));
    await tester.pumpAndSettle();
    expect(find.text(S.pairBadCode), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('pair-code-field')), '483920');
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.pairConfirm));
    await tester.pumpAndSettle();
    expect(api.claims, ['483920']);
    expect(find.text(S.pairTvDone), findsOneWidget);
  });

  testWidgets('a paired voice has no delete button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialCatalogProvider.overrideWithValue(bundledSnapshot()),
        czechVoiceAvailableProvider.overrideWith((ref) async => true),
        initialVoicesProvider.overrideWithValue(const [
          LocalVoice(id: 'v1', name: 'Jana'),
          LocalVoice(id: 'p1', name: 'Máma', owned: false),
        ]),
      ],
      child: const MaterialApp(home: VoiceScreen()),
    ));
    await tester.pumpAndSettle();
    Finder del(String id) =>
        find.descendant(of: find.byKey(ValueKey('voice-$id')), matching: find.byIcon(Icons.delete_outline));
    expect(del('v1'), findsOneWidget);
    expect(del('p1'), findsNothing);
  });
}

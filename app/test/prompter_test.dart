import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/theme.dart';
import 'package:hajanek/features/voice/prompter.dart';

void main() {
  const lines = ['Krátká věta.', 'Druhá věta je o něco delší než první.', 'Konec.'];

  test('promptLineAt follows the reading pace and a resync', () {
    final first = promptLineDuration(lines[0]);
    // 10 letters × 75 ms + 700 ms breath.
    expect(first, const Duration(milliseconds: 1450));
    expect(promptLineAt(lines, Duration.zero), 0);
    expect(promptLineAt(lines, first - const Duration(milliseconds: 1)), 0);
    expect(promptLineAt(lines, first), 1);
    expect(promptLineAt(lines, const Duration(minutes: 5)), 2);
    expect(promptLineAt(lines, Duration.zero, from: 2), 2);
  });

  testWidgets('active line is bright, tapping a line reports it', (tester) async {
    int? tapped;
    Widget build(int active) => MaterialApp(
      home: Scaffold(
        body: Prompter(lines: lines, active: active, onTapLine: (i) => tapped = i),
      ),
    );
    Color colorOf(String s) => tester
        .widget<DefaultTextStyle>(find.ancestor(of: find.text(s), matching: find.byType(DefaultTextStyle)).first)
        .style
        .color!;

    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();
    expect(colorOf(lines[0]), Night.textBright);
    expect(colorOf(lines[1]), Night.textDim);

    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();
    expect(colorOf(lines[1]), Night.textBright);
    expect(colorOf(lines[0]), isNot(Night.textBright));

    await tester.tap(find.text(lines[2]));
    expect(tapped, 2);
  });
}

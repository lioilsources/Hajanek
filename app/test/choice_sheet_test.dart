import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/widgets.dart';

void main() {
  testWidgets('choice sheet shows a heading where the group changes', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showChoiceSheet<String>(
            context: context,
            title: 'Zvuk',
            choices: const ['sea', 'rain', 'lullaby-harp-1'],
            label: (id) => id,
            group: (id) => id.startsWith('lullaby-') ? 'Ukolébavky' : 'Přírodní zvuky',
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Přírodní zvuky'), findsOneWidget);
    expect(find.text('Ukolébavky'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Ukolébavky')).dy,
        allOf(greaterThan(tester.getTopLeft(find.text('rain')).dy), lessThan(tester.getTopLeft(find.text('lullaby-harp-1')).dy)));
    await tester.tap(find.text('lullaby-harp-1'));
    await tester.pumpAndSettle();
    expect(picked, 'lullaby-harp-1');
  });
}

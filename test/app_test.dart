import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/app/app.dart';

void main() {
  testWidgets('renders the branded application foundation', (tester) async {
    await tester.pumpWidget(const NexusCrmApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'Nexus CRM');
    expect(find.text('Nexus CRM'), findsOneWidget);
    expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
  });
}

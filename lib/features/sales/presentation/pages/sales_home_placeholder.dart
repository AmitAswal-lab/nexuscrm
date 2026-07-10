import 'package:flutter/material.dart';
import 'package:nexuscrm/app/navigation/pages/navigation_placeholder_page.dart';

class SalesHomePlaceholder extends StatelessWidget {
  const SalesHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const NavigationPlaceholderPage(
      icon: Icons.trending_up,
      title: 'Sales workspace',
      message: 'The sales dashboard is planned for the next milestone.',
    );
  }
}

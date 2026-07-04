import 'package:flutter/material.dart';
import 'package:nexuscrm/app/navigation/pages/navigation_placeholder_page.dart';

class AdminHomePlaceholder extends StatelessWidget {
  const AdminHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const NavigationPlaceholderPage(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Admin workspace',
      message: 'The administrator overview is planned for a later milestone.',
    );
  }
}

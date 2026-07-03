import 'package:flutter/material.dart';
import 'package:nexuscrm/app/widgets/app_status_page.dart';

class SignInPlaceholderPage extends StatelessWidget {
  const SignInPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppStatusPage(
      icon: Icons.hub_outlined,
      title: 'Nexus CRM',
      message: 'Sign in to continue.',
    );
  }
}

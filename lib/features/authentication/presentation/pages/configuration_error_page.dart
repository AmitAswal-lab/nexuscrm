import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/app/widgets/app_status_page.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class ConfigurationErrorPage extends StatelessWidget {
  const ConfigurationErrorPage({required this.reason, super.key});

  final SessionConfigurationErrorReason reason;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      SessionConfigurationErrorReason.multipleActiveMemberships =>
        'Your account has more than one active workspace membership.',
      SessionConfigurationErrorReason.multipleInvitations =>
        'Your account has more than one pending workspace invitation.',
    };

    return AppStatusPage(
      icon: Icons.settings_outlined,
      title: 'Account configuration issue',
      message: '$message Contact an administrator for help.',
      actionLabel: 'Sign out',
      onAction: () {
        context.read<SessionBloc>().add(const SessionSignOutRequested());
      },
    );
  }
}

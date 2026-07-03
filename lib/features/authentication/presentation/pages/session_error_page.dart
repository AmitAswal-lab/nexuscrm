import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/app/widgets/app_status_page.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class SessionErrorPage extends StatelessWidget {
  const SessionErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStatusPage(
      icon: Icons.error_outline,
      title: 'Unable to load your session',
      message: 'Check your connection and try signing in again.',
      actionLabel: 'Sign out',
      onAction: () {
        context.read<SessionBloc>().add(const SessionSignOutRequested());
      },
    );
  }
}

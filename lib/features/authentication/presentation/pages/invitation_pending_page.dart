import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/app/widgets/app_status_page.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class InvitationPendingPage extends StatelessWidget {
  const InvitationPendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStatusPage(
      icon: Icons.mark_email_unread_outlined,
      title: 'Invitation pending',
      message: 'Complete account setup before entering Nexus CRM.',
      actionLabel: 'Sign out',
      onAction: () {
        context.read<SessionBloc>().add(const SessionSignOutRequested());
      },
    );
  }
}

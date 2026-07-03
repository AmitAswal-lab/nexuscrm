import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/app/widgets/app_status_page.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({required this.reason, super.key});

  final SessionAccessDeniedReason reason;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      SessionAccessDeniedReason.noMembership =>
        'Your account does not have access to a workspace.',
      SessionAccessDeniedReason.suspended =>
        'Your workspace membership is suspended.',
      SessionAccessDeniedReason.revoked =>
        'Your workspace access has been revoked.',
    };

    return AppStatusPage(
      icon: Icons.lock_outline,
      title: 'Access unavailable',
      message: message,
      actionLabel: 'Sign out',
      onAction: () {
        context.read<SessionBloc>().add(const SessionSignOutRequested());
      },
    );
  }
}

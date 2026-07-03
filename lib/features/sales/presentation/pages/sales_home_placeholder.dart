import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/app/widgets/app_status_page.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class SalesHomePlaceholder extends StatelessWidget {
  const SalesHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStatusPage(
      icon: Icons.trending_up,
      title: 'Sales workspace',
      message: 'The sales dashboard is ready for its next milestone.',
      actionLabel: 'Sign out',
      onAction: () {
        context.read<SessionBloc>().add(const SessionSignOutRequested());
      },
    );
  }
}

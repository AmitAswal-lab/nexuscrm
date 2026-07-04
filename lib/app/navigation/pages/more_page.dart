import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              subtitle: const Text('Return to the Nexus CRM sign-in page'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.read<SessionBloc>().add(
                  const SessionSignOutRequested(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

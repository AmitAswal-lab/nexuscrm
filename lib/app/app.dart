import 'package:flutter/material.dart';
import 'package:nexuscrm/app/theme/app_theme.dart';

class NexusCrmApp extends StatelessWidget {
  const NexusCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _FoundationScreen(),
    );
  }
}

class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Nexus CRM', style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}

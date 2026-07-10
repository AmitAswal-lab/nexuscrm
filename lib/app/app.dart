import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/app/router/app_router.dart';
import 'package:nexuscrm/app/theme/app_theme.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';

class NexusCrmApp extends StatefulWidget {
  const NexusCrmApp({
    required this.authenticationRepository,
    required this.membershipRepository,
    required this.contactRepository,
    required this.salesAssigneeRepository,
    super.key,
  });

  final AuthenticationRepository authenticationRepository;
  final MembershipRepository membershipRepository;
  final ContactRepository contactRepository;
  final SalesAssigneeRepository salesAssigneeRepository;

  @override
  State<NexusCrmApp> createState() => _NexusCrmAppState();
}

class _NexusCrmAppState extends State<NexusCrmApp> {
  late final SessionBloc _sessionBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _sessionBloc = SessionBloc(
      authenticationRepository: widget.authenticationRepository,
      membershipRepository: widget.membershipRepository,
    )..add(const SessionStarted());
    _appRouter = AppRouter(_sessionBloc);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    unawaited(_sessionBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthenticationRepository>.value(
          value: widget.authenticationRepository,
        ),
        RepositoryProvider<MembershipRepository>.value(
          value: widget.membershipRepository,
        ),
        RepositoryProvider<ContactRepository>.value(
          value: widget.contactRepository,
        ),
        RepositoryProvider<SalesAssigneeRepository>.value(
          value: widget.salesAssigneeRepository,
        ),
      ],
      child: BlocProvider.value(
        value: _sessionBloc,
        child: MaterialApp.router(
          title: 'Nexus CRM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}

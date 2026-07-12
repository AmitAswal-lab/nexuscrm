import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

class ContactActivityPage extends StatelessWidget {
  const ContactActivityPage({
    required this.workspaceId,
    required this.contactId,
    required this.activityRepository,
    required this.taskRepository,
    required this.taskAccessScope,
    required this.salesAssigneeRepository,
    required this.isSalesView,
    super.key,
  });

  final String workspaceId;
  final String contactId;
  final ActivityRepository activityRepository;
  final TaskRepository taskRepository;
  final TaskAccessScope taskAccessScope;
  final SalesAssigneeRepository salesAssigneeRepository;
  final bool isSalesView;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Contact activity',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ContactActivityTimeline(
                  title: 'Activity timeline',
                  maxEntries: null,
                  workspaceId: workspaceId,
                  contactId: contactId,
                  activityRepository: activityRepository,
                  taskRepository: taskRepository,
                  taskAccessScope: taskAccessScope,
                  salesAssigneeRepository: salesAssigneeRepository,
                  isSalesView: isSalesView,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

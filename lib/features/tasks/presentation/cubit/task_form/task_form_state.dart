part of 'task_form_cubit.dart';

enum TaskFormTaskStatus { loading, ready, notFound, failure }

enum TaskFormSubmissionStatus { idle, submitting, success, failure }

final class TaskFormState extends Equatable {
  const TaskFormState({
    this.isEditing = false,
    this.taskStatus = TaskFormTaskStatus.loading,
    this.task,
    this.contacts = const [],
    this.assignees = const [],
    this.contactsReady = false,
    this.assigneesReady = false,
    this.contactsFailure,
    this.assigneesFailure,
    this.taskFailure,
    this.submissionStatus = TaskFormSubmissionStatus.idle,
    this.submissionFailure,
  });
  final bool isEditing, contactsReady, assigneesReady;
  final TaskFormTaskStatus taskStatus;
  final CrmTask? task;
  final List<CrmContact> contacts;
  final List<SalesAssignee> assignees;
  final TaskFailure? contactsFailure,
      assigneesFailure,
      taskFailure,
      submissionFailure;
  final TaskFormSubmissionStatus submissionStatus;
  bool get canSubmit =>
      taskStatus == TaskFormTaskStatus.ready &&
      contactsReady &&
      assigneesReady &&
      submissionStatus != TaskFormSubmissionStatus.submitting;
  TaskFormState copyWith({
    TaskFormTaskStatus? taskStatus,
    CrmTask? task,
    List<CrmContact>? contacts,
    List<SalesAssignee>? assignees,
    bool? contactsReady,
    bool? assigneesReady,
    TaskFailure? contactsFailure,
    TaskFailure? assigneesFailure,
    TaskFailure? taskFailure,
    TaskFormSubmissionStatus? submissionStatus,
    TaskFailure? submissionFailure,
    bool clearSubmissionFailure = false,
  }) => TaskFormState(
    isEditing: isEditing,
    taskStatus: taskStatus ?? this.taskStatus,
    task: task ?? this.task,
    contacts: contacts ?? this.contacts,
    assignees: assignees ?? this.assignees,
    contactsReady: contactsReady ?? this.contactsReady,
    assigneesReady: assigneesReady ?? this.assigneesReady,
    contactsFailure: contactsFailure ?? this.contactsFailure,
    assigneesFailure: assigneesFailure ?? this.assigneesFailure,
    taskFailure: taskFailure ?? this.taskFailure,
    submissionStatus: submissionStatus ?? this.submissionStatus,
    submissionFailure: clearSubmissionFailure
        ? null
        : submissionFailure ?? this.submissionFailure,
  );
  @override
  List<Object?> get props => [
    isEditing,
    taskStatus,
    task,
    contacts,
    assignees,
    contactsReady,
    assigneesReady,
    contactsFailure,
    assigneesFailure,
    taskFailure,
    submissionStatus,
    submissionFailure,
  ];
}

abstract final class AppRoutes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const invitationPending = '/invitation-pending';
  static const accessDenied = '/access-denied';
  static const configurationError = '/configuration-error';
  static const error = '/error';
  static const admin = '/admin';
  static const adminHome = '$admin/home';
  static const adminLeads = '$admin/leads';
  static const adminArchivedContacts = '$adminLeads/archived';
  static const adminDocuments = '$admin/documents';
  static const adminNewLead = '$adminLeads/new';
  static const adminTasks = '$admin/tasks';
  static const adminNewTask = '$adminTasks/new';
  static const adminMore = '$admin/more';
  static const adminTeam = '$adminMore/team';
  static const adminInviteRepresentative = '$adminTeam/invite';
  static const sales = '/sales';
  static const salesHome = '$sales/home';
  static const salesLeads = '$sales/leads';
  static const salesArchivedContacts = '$salesLeads/archived';
  static const salesNewLead = '$salesLeads/new';
  static const salesTasks = '$sales/tasks';
  static const salesNewTask = '$salesTasks/new';
  static const salesMore = '$sales/more';

  static String adminContact(String contactId) => '$adminLeads/$contactId';

  static String salesContact(String contactId) => '$salesLeads/$contactId';

  static String adminEditContact(String contactId) =>
      '${adminContact(contactId)}/edit';

  static String salesEditContact(String contactId) =>
      '${salesContact(contactId)}/edit';

  static String adminLogCallNote(String contactId) =>
      '${adminContact(contactId)}/call-note';
  static String adminContactActivity(String contactId) =>
      '${adminContact(contactId)}/activity';
  static String adminContactShare(String contactId) =>
      '${adminContact(contactId)}/share';

  static String salesLogCallNote(String contactId) =>
      '${salesContact(contactId)}/call-note';
  static String salesContactActivity(String contactId) =>
      '${salesContact(contactId)}/activity';
  static String salesContactShare(String contactId) =>
      '${salesContact(contactId)}/share';

  static String adminTask(String taskId) => '$adminTasks/$taskId';
  static String salesTask(String taskId) => '$salesTasks/$taskId';
  static String adminEditTask(String taskId) => '${adminTask(taskId)}/edit';
  static String salesEditTask(String taskId) => '${salesTask(taskId)}/edit';
}

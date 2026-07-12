import 'package:nexuscrm/features/contacts/domain/services/phone_dialer.dart';
import 'package:url_launcher/url_launcher.dart';

final class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  @override
  Future<bool> dial(String phoneNumber) {
    final normalized = normalizeDialablePhoneNumber(phoneNumber);

    if (normalized == null) {
      return Future.value(false);
    }

    return launchUrl(
      Uri(scheme: 'tel', path: normalized),
      mode: LaunchMode.externalApplication,
    );
  }
}

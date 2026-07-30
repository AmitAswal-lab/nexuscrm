import 'package:nexuscrm/features/contacts/domain/services/phone_dialer.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/services/share_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

final class UrlLauncherShareLauncher implements ShareLauncher {
  const UrlLauncherShareLauncher();

  @override
  Future<bool> share({
    required ShareChannel channel,
    required String recipient,
    required String subject,
    required String message,
  }) {
    final target = switch (channel) {
      ShareChannel.whatsApp => _whatsAppUri(recipient, message),
      ShareChannel.email => _emailUri(recipient, subject, message),
    };

    if (target == null) {
      return Future.value(false);
    }

    return launchUrl(target, mode: LaunchMode.externalApplication);
  }

  static Uri? _whatsAppUri(String phoneNumber, String message) {
    final normalized = normalizeDialablePhoneNumber(phoneNumber);

    if (normalized == null) {
      return null;
    }

    return Uri.https('wa.me', '/${normalized.replaceAll('+', '')}', {
      'text': message,
    });
  }

  static Uri? _emailUri(String address, String subject, String message) {
    final normalized = address.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return null;
    }

    return Uri(
      scheme: 'mailto',
      path: normalized,
      query: Uri(
        queryParameters: {'subject': subject, 'body': message},
      ).query,
    );
  }
}

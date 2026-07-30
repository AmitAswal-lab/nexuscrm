import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';

/// Hands a prepared message to WhatsApp or the device's email application.
///
/// Only the link travels. The document itself never reaches the device.
abstract interface class ShareLauncher {
  Future<bool> share({
    required ShareChannel channel,
    required String recipient,
    required String subject,
    required String message,
  });
}

String shareMessage({
  required String contactName,
  required String documentTitle,
  required String link,
}) {
  return 'Hello $contactName, here is the $documentTitle you asked for: $link';
}

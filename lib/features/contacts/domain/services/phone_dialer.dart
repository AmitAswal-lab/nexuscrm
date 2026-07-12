/// Launches the device's native phone application for a dialable phone number.
abstract interface class PhoneDialer {
  Future<bool> dial(String phoneNumber);
}

/// Removes common display formatting and returns an E.164-style phone number.
///
/// The CRM does not infer a country code. A number must already contain between
/// five and fifteen digits, with an optional leading `+`.
String? normalizeDialablePhoneNumber(String? phoneNumber) {
  if (phoneNumber == null) {
    return null;
  }

  final normalized = phoneNumber.trim().replaceAll(RegExp(r'[\s().-]'), '');

  return RegExp(r'^\+?[0-9]{5,15}$').hasMatch(normalized) ? normalized : null;
}

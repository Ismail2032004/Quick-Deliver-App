import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final phoneServiceProvider = Provider<PhoneService>(
  (ref) => const PhoneService(),
);

class PhoneCallResult {
  const PhoneCallResult({
    required this.success,
    required this.message,
    this.sanitizedNumber,
  });

  final bool success;
  final String message;
  final String? sanitizedNumber;
}

class PhoneService {
  const PhoneService();

  Future<bool> callNumber(String phoneNumber) async {
    final result = await tryCallNumber(phoneNumber);
    return result.success;
  }

  String? sanitizePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null) {
      return null;
    }
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(sanitized)) {
      return null;
    }
    return sanitized;
  }

  Future<PhoneCallResult> tryCallNumber(String? phoneNumber) async {
    final sanitized = sanitizePhoneNumber(phoneNumber);
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return const PhoneCallResult(
        success: false,
        message: 'No phone number is available for this contact yet.',
      );
    }
    if (sanitized == null) {
      return const PhoneCallResult(
        success: false,
        message: 'This phone number looks invalid and could not be dialed.',
      );
    }

    final uri = Uri(scheme: 'tel', path: sanitized);
    try {
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri);
        return PhoneCallResult(
          success: launched,
          message: launched
              ? 'Calling $sanitized'
              : 'Your device could not start the phone call.',
          sanitizedNumber: sanitized,
        );
      }
    } catch (_) {
      return PhoneCallResult(
        success: false,
        message: 'Your device could not start a call to $sanitized.',
        sanitizedNumber: sanitized,
      );
    }
    return PhoneCallResult(
      success: false,
      message: 'Calling is not available on this device right now.',
      sanitizedNumber: sanitized,
    );
  }
}

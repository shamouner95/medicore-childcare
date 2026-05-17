import 'dart:convert';
import 'package:crypto/crypto.dart';

/// A service to handle Universal Health ID logic, following Open Source modularity.
/// This service is designed to be a "Global Public Good" as per UNICEF requirements,
/// allowing for offline health data continuity via QR codes.
class HealthIDService {
  /// Encodes patient data into a compact JSON string for QR code generation.
  /// In a production environment, this should include a digital signature or encryption.
  static String generateQRData(Map<String, dynamic> userData) {
    final Map<String, dynamic> qrMap = {
      'id': userData['uniqueId'] ?? 'PENDING',
      'n': userData['name'] ?? 'N/A',
      'b': userData['bloodGroup'] ?? 'N/A',
      'g': userData['genotype'] ?? 'N/A',
      'v': userData['vaccinationStatus'] ?? 'N/A',
      'w': userData['weight'] != null ? '${userData['weight']}kg' : 'N/A',
      'a': userData['allergies'] ?? 'None',
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    
    // We use short keys to keep the QR code density low, improving readability 
    // on low-end devices or in poor lighting (UNICEF Area 4: Point-of-Care).
    return jsonEncode(qrMap);
  }

  /// Verifies the integrity of a scanned QR code (Placeholder for digital signatures).
  static bool verifyDataIntegrity(String qrData) {
    try {
      final decoded = jsonDecode(qrData);
      return decoded.containsKey('id') && decoded.containsKey('ts');
    } catch (_) {
      return false;
    }
  }

  /// Generates a unique checksum for the data to detect tampering.
  static String generateChecksum(String data) {
    return sha256.convert(utf8.encode(data)).toString().substring(0, 8);
  }
}

import 'dart:typed_data';
import 'package:flutter/services.dart';

class PdfGenerator {
  static const MethodChannel _channel = MethodChannel('pdf_generator');

  static Future<Uint8List?> generatePdf({
    required String shopName,
    required String address,
    required String city,
    required String phone,
    required String headerText,
    required String footerText1,
    required String footerText2,
    required String footerText3,
    required int receiptNumber,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String language,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'shopName': shopName,
        'address': address,
        'city': city,
        'phone': phone,
        'headerText': headerText,
        'footerText1': footerText1,
        'footerText2': footerText2,
        'footerText3': footerText3,
        'receiptNumber': receiptNumber,
        'items': items,
        'totalAmount': totalAmount,
        'language': language,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final Uint8List? result = await _channel.invokeMethod(
        'generatePdf',
        arguments,
      );
      return result;
    } on PlatformException catch (e) {
      print("Failed to generate PDF: '${e.message}'.");
      return null;
    }
  }

  static Future<bool> savePdf({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('savePdf', {
        'pdfBytes': pdfBytes,
        'fileName': fileName,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to save PDF: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> sharePdf({
    required Uint8List pdfBytes,
    required String fileName,
    required String shareText,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('sharePdf', {
        'pdfBytes': pdfBytes,
        'fileName': fileName,
        'shareText': shareText,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to share PDF: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> printPdf({
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('printPdf', {
        'pdfBytes': pdfBytes,
        'jobName': jobName,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to print PDF: '${e.message}'.");
      return false;
    }
  }
}

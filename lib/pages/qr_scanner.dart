// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/qr_payload.dart';

/// Modal full-screen QR scanner (T3.2). Returns a [JoinPayload] when
/// the user scans something valid, or null on cancel/no-read.
///
/// Uses [MobileScanner] directly. The scanner keeps detecting until
/// the user dismisses (back gesture / close button); we take the first
/// `scythe://join?…` payload we see and pop.
///
/// Notes:
/// - The camera permission must already be granted before this opens.
///   Permission flow lives at the call site (JoinRoom "Scan QR"
///   button) — T3.5 can centralise this once the rest of the app
///   needs camera too.
/// - We don't bind the scanner's `controller` to a state field because
///   we only consume the first match; disposing the MobileScanner
///   widget is enough.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _consumed = false;
  String? _errorText;

  void _handleBarcode(BarcodeCapture capture) {
    if (_consumed) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.displayValue ?? barcode.rawValue;
      if (raw == null) continue;
      final payload = decodeJoin(raw);
      if (payload != null) {
        _consumed = true;
        Navigator.of(context).pop(payload);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Room QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _describeError(error),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          // Aim box: a translucent rectangle to suggest where to point
          // the camera. Pure decoration; MobileScanner works fine
          // without it but users do better with a target.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_errorText != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _describeError(MobileScannerException error) {
    // MobileScannerException already provides a human-readable message;
    // we only prepend the user-actionable bit for permissionDenied so
    // users know where to fix it.
    final code = error.errorCode;
    if (code == MobileScannerErrorCode.permissionDenied) {
      return 'Camera permission was denied. Grant it in Android '
          'Settings to scan a QR code.';
    }
    return code.message;
  }
}

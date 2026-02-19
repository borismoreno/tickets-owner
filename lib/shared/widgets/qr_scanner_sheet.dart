import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QrScannerSheet extends StatefulWidget {
  final String eventId;
  const QrScannerSheet({super.key, required this.eventId});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  bool processing = false;

  Future<void> _handleScan(String qrToken) async {
    if (processing) return;
    processing = true;

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'validate_ticket',
        body: {'qrToken': qrToken},
      );

      // if (!mounted) return;

      // if (res.status == 200) {
      //   Navigator.pop(context, {'ok': true});
      // } else {
      //   Navigator.pop(context, {
      //     'ok': false,
      //     'error': res.data['error'] ?? 'No válido',
      //   });
      // }
      final data = res.data;

      if (!mounted) return;

      Navigator.pop(context, {
        'ok': data['ok'] == true,
        'reason': data['reason'],
      });
    } catch (e) {
      Navigator.pop(context, {'ok': false, 'error': e.toString()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (barcodeCapture) {
              final barcode = barcodeCapture.barcodes.first;
              final value = barcode.rawValue;
              if (value != null) {
                _handleScan(value);
              }
            },
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

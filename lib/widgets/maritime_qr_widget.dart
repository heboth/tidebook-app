import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_security_service.dart';
import '../theme/gonordic_theme.dart';

class MaritimeQrWidget extends StatelessWidget {
  final String qrPayload;
  final double size;
  final bool showSecurityHash;

  const MaritimeQrWidget({
    super.key,
    required this.qrPayload,
    this.size = 180,
    this.showSecurityHash = true,
  });

  @override
  Widget build(BuildContext context) {
    if (qrPayload.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GoNordicTheme.border, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 48, color: GoNordicTheme.textSecondary),
            SizedBox(height: 8),
            Text(
              'Check-in påkrævet',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GoNordicTheme.pine),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final secCode = QrSecurityService.extractSecurityCode(qrPayload);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: GoNordicTheme.border, width: 2),
          ),
          child: QrImageView(
            data: qrPayload,
            version: QrVersions.auto,
            size: size,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: GoNordicTheme.pineDark,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: GoNordicTheme.pineDark,
            ),
          ),
        ),
        if (showSecurityHash && secCode != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 12, color: GoNordicTheme.teal),
              const SizedBox(width: 4),
              Text(
                'SOLAS GATE KONTROL: $secCode',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: GoNordicTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}


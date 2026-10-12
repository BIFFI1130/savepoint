import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_links.dart';

/// シェア画像の最下部に置く、インストール導線（QRコード・アプリ名・URL）。
/// SNSに転載された画像にはリンクが付かないため、画像そのものに載せる。
class ShareInstallFooter extends StatelessWidget {
  const ShareInstallFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: AppLinks.landingUrl,
            size: 58,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ゲーム人生を記録しよう',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'SavePoint（無料）',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                AppLinks.landingUrl.replaceFirst('https://', ''),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

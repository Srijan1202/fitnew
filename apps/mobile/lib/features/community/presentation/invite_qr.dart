import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/tokens.dart';
import '../domain/community.dart';

/// Beta 6.2 (C15, owner Q1): a QR code of a FITOS link, always black on
/// white so any phone camera reads it whatever the theme. Drawn from the
/// `barcode` package (already in the app through `pdf`): nothing is sent
/// anywhere to make it.
class InviteQr extends StatelessWidget {
  const InviteQr({required this.data, this.size = 220, super.key});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'QR code for $data',
        image: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(painter: QrPainter(data)),
          ),
        ),
      );
}

/// Paints the black modules of [data]'s QR code into the canvas.
class QrPainter extends CustomPainter {
  QrPainter(this.data);

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = Colors.black;
    final elements = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
    ).make(data, width: size.width, height: size.height);
    for (final e in elements) {
      if (e is BarcodeBar && e.black) {
        // A hair wider, so neighbouring modules leave no seam.
        canvas.drawRect(
          Rect.fromLTWH(e.left, e.top, e.width + 0.5, e.height + 0.5),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(QrPainter oldDelegate) => oldDelegate.data != data;
}

/// Your handle as a QR code and a link: a friend's camera opens FITOS on
/// "Add @you?".
Future<void> showHandleQr(BuildContext context, String handle) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) {
        final t = Theme.of(sheet).textTheme;
        final link = friendInviteUrl(handle);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FitSpacing.lg),
            child: Column(
              key: const ValueKey('community.qr'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your FITOS code', style: t.titleLarge),
                const SizedBox(height: FitSpacing.md),
                InviteQr(data: link),
                const SizedBox(height: FitSpacing.md),
                Text('@$handle', style: t.titleMedium),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  'A friend points their phone camera at it to add you. '
                  'It holds only your handle.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
                const SizedBox(height: FitSpacing.md),
                OutlinedButton.icon(
                  key: const ValueKey('community.qr.share'),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share the link'),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: 'Add me on FITOS: $link',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

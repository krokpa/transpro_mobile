import 'package:flutter/material.dart';

const _kAssets = <String, String>{
  'WAVE':         'assets/images/payments/wave.png',
  'ORANGE_MONEY': 'assets/images/payments/orange.jpeg',
  'MTN_MOMO':     'assets/images/payments/mtn.jpg',
  'VISA':         'assets/images/payments/visa.png',
  'MASTERCARD':   'assets/images/payments/mastercard.png',
  // Canaux Genius Pay (lowercase renvoyé par l'API)
  'wave':         'assets/images/payments/wave.png',
  'orange_money': 'assets/images/payments/orange.jpeg',
  'orange':       'assets/images/payments/orange.jpeg',
  'mtn_momo':     'assets/images/payments/mtn.jpg',
  'mtn':          'assets/images/payments/mtn.jpg',
  'moov':         'assets/images/payments/moov.png',
  'moov_money':   'assets/images/payments/moov.png',
  'MOOV':         'assets/images/payments/moov.png',
  'visa':         'assets/images/payments/visa.png',
  'mastercard':   'assets/images/payments/mastercard.png',
};

/// Affiche le logo d'un moyen de paiement.
/// [method] : valeur de l'enum PaymentMethod (ex: 'WAVE') ou canal Genius Pay
/// lowercase (ex: 'orange_money'). Pour CASH, affiche une icône espèces.
class PaymentLogo extends StatelessWidget {
  final String method;
  final double size;

  const PaymentLogo({super.key, required this.method, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final asset = _kAssets[method];
    if (asset != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: EdgeInsets.all(size * 0.08),
        child: Image.asset(asset, fit: BoxFit.contain),
      );
    }
    // CASH ou méthode inconnue → icône neutre
    return Icon(
      method == 'CASH' ? Icons.payments_outlined : Icons.credit_card_outlined,
      size: size * 0.75,
      color: method == 'CASH' ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PinDot extends StatelessWidget {
  final bool filled;
  const PinDot({super.key, required this.filled});

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? brandOrange : Colors.transparent,
      border: Border.all(
        color: filled ? brandOrange : const Color(0xFFCBD5E1),
        width: 2,
      ),
    ),
  );
}

class PinKeypad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  const PinKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        _buildRow(['4', '5', '6']),
        _buildRow(['7', '8', '9']),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            onBiometric != null
                ? _KeyButton(
                    onTap: onBiometric!,
                    child: const Icon(Icons.fingerprint, color: brandOrange, size: 32),
                  )
                : const SizedBox(width: 80, height: 80),
            _DigitKey(digit: '0', onTap: onKey),
            _KeyButton(
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined, color: brandDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: digits.map((d) => _DigitKey(digit: d, onTap: onKey)).toList(),
  );
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final void Function(String) onTap;

  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    height: 80,
    child: TextButton(
      onPressed: () => onTap(digit),
      style: TextButton.styleFrom(
        shape: const CircleBorder(),
        foregroundColor: brandDark,
      ),
      child: Text(digit, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
    ),
  );
}

class _KeyButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeyButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    height: 80,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(shape: const CircleBorder()),
      child: child,
    ),
  );
}

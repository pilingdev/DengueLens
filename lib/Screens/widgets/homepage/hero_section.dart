import 'package:flutter/material.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
            children: [
              TextSpan(text: 'Identify Mosquito &\n'),
              TextSpan(
                text: 'Assess Risk',
                style: TextStyle(color: Color(0xFF2ECC71)), // Vibrant Green
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Protect your family with instant analysis.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final String result; // "positive" or "negative"
  final double confidence; // 0.0 to 1.0
  final String sampleType; // e.g., "Blood Sample"
  final String mosquitoType; // e.g., "Aedes aegypti"
  final DateTime testDate;
  final File? imagePath; // User uploaded image

  const ResultScreen({
    super.key,
    this.result = "negative",
    this.confidence = 0.85,
    this.sampleType = "Blood Sample",
    required this.mosquitoType,
    required this.testDate,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedResult = result.toLowerCase();
    final isPositive = normalizedResult == "positive";
    final isUncertain = normalizedResult == "uncertain";
    final resultColor = isPositive
        ? Colors.red
        : isUncertain
        ? Colors.orange
        : Colors.green;
    final resultIcon = isPositive
        ? Icons.warning_rounded
        : isUncertain
        ? Icons.help_outline_rounded
        : Icons.check_circle_rounded;
    final resultMessage = isPositive
        ? "Known dengue species carrying the virus"
        : isUncertain
        ? "Low confidence — try another photo"
        : "No Dengue Detected";
    final confidencePercentage = (confidence * 100).toStringAsFixed(1);

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Uploaded Image Display
              if (imagePath != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      imagePath!,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              // Header with status
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      resultColor.withOpacity(0.1),
                      resultColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    // Large icon
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resultColor.withOpacity(0.2),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Icon(resultIcon, size: 80, color: resultColor),
                    ),
                    const SizedBox(height: 24),
                    // Result status
                    Text(
                      resultMessage,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Confidence score
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: resultColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: resultColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Confidence: $confidencePercentage%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: resultColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Details section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Result Details Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Details',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _DetailRow(label: 'Sample Type', value: sampleType),
                            const Divider(),
                            _DetailRow(
                              label: 'Mosquito Type',
                              value: mosquitoType,
                            ),
                            const Divider(),
                            _DetailRow(
                              label: 'Test Date',
                              value:
                                  '${testDate.day}/${testDate.month}/${testDate.year}',
                            ),
                            const Divider(),
                            _DetailRow(
                              label: 'Result',
                              value: resultMessage,
                              valueColor: resultColor,
                            ),
                            const Divider(),
                            _DetailRow(
                              label: 'Accuracy',
                              value: '$confidencePercentage%',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Recommendation Card
                    Card(
                      color: isPositive
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.health_and_safety
                                      : Icons.info,
                                  color: resultColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recommendation',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: resultColor,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isPositive
                                  ? 'Please consult with a healthcare professional immediately. '
                                        'Dengue requires medical attention and proper care.'
                                  : 'No dengue detected. However, if symptoms persist, '
                                        'please consult with a healthcare professional.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('Back to Home'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2ECC71),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Share functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Result shared successfully!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share Result'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

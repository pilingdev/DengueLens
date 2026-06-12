import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../models/scan_record.dart';

class SymptomResultScreen extends StatelessWidget {
  final int symptomCount;
  final int totalSymptoms;
  final List<String> selectedSymptoms;
  final String mosquitoType;

  const SymptomResultScreen({
    super.key,
    required this.symptomCount,
    required this.totalSymptoms,
    required this.selectedSymptoms,
    required this.mosquitoType,
  });

  static const Color _accentGreen = Color(0xFF2ECC71);

  String get _riskLevel {
    if (symptomCount == 0) return 'Low';
    if (symptomCount <= 2) return 'Moderate';
    if (symptomCount <= 4) return 'High';
    return 'Critical';
  }

  Color get _riskColor {
    switch (_riskLevel) {
      case 'Low':
        return _accentGreen;
      case 'Moderate':
        return const Color(0xFFF39C12);
      case 'High':
        return const Color(0xFFE67E22);
      case 'Critical':
        return const Color(0xFFE74C3C);
      default:
        return Colors.grey;
    }
  }

  String get _summaryText {
    switch (_riskLevel) {
      case 'Low':
        return 'It is better to observe your health and remain cautious. Continue monitoring your health '
            'and take precautions to avoid further mosquito bites.';
      case 'Moderate':
        return 'Your current assessment indicates a '
            'Moderate Risk level. Some dengue symptoms detected. This status requires monitoring and adherence to '
            'the home care protocols outlined above. Please schedule a consultation with a healthcare provider.';
      case 'High':
        return 'Your current assessment indicates a '
            'High Risk level with multiple dengue symptoms. This status requires prompt medical evaluation and adherence to '
            'clinical recommendations. Immediate consultation is advised.';
      case 'Critical':
        return 'Your current assessment indicates a '
            'Critical Risk level. This status requires immediate emergency medical attention. '
            'Please proceed to the nearest healthcare facility without delay.';
      default:
        return '';
    }
  }

  List<Map<String, dynamic>> get _homeCareTips {
    switch (_riskLevel) {
      case 'Low':
        return [
          {
            'title': 'Monitor Health',
            'subtitle': 'Watch for any symptom development',
            'icon': Icons.visibility_outlined,
          },
          {
            'title': 'Use Protection',
            'subtitle': 'Mosquito repellent and protective clothing',
            'icon': Icons.shield_outlined,
          },
        ];
      case 'Moderate':
        return [
          {
            'title': 'Prioritize Rest',
            'subtitle':
                'Limit physical exertion to allow your body\'s immune system to function optimally during recovery',
            'icon': Icons.hotel_outlined,
          },
          {
            'title': 'Continuous Hydration',
            'subtitle': 'Electrolytes and consistent intake',
            'icon': Icons.local_drink_outlined,
          },
          {
            'title': 'Active Observation',
            'subtitle': 'Monitor for any worsening symptoms',
            'icon': Icons.visibility_outlined,
          },
        ];
      case 'High':
        return [
          {
            'title': 'Seek Medical Care',
            'subtitle': 'Visit healthcare facility today',
            'icon': Icons.local_hospital_outlined,
          },
          {
            'title': 'Blood Test',
            'subtitle': 'Confirm dengue diagnosis',
            'icon': Icons.science_outlined,
          },
          {
            'title': 'Avoid NSAIDs',
            'subtitle': 'No aspirin or ibuprofen',
            'icon': Icons.dangerous_outlined,
          },
        ];
      case 'Critical':
        return [
          {
            'title': 'Emergency care',
            'subtitle': 'Go to the nearest ER or call emergency services',
            'icon': Icons.local_hospital_outlined,
          },
        ];
      default:
        return [];
    }
  }

  double get _scoreProgress {
    if (totalSymptoms <= 0) return 0;
    return (symptomCount / totalSymptoms).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Risk Assessment',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This tool is for education and early awareness only. It does not replace '
                        'professional medical diagnosis. If you feel unwell or your symptoms worsen, '
                        'contact a healthcare provider.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: _scoreProgress,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: _riskColor.withValues(alpha: 0.18),
                        color: _riskColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SCORE',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$symptomCount',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: _riskColor,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/ $totalSymptoms',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _riskColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_riskLevel.toUpperCase()} RISK',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _riskColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Home Care Protocol',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _accentGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: _riskLevel == 'Low'
                                  ? _accentGreen
                                  : _riskColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _homeCareTips.length == 1 ? 1 : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: _homeCareTips.length == 1 ? 124 : 132,
                      ),
                      itemCount: _homeCareTips.length,
                      itemBuilder: (context, index) {
                        return _CareTipCard(
                          tip: _homeCareTips[index],
                          accent: _riskLevel == 'Low'
                              ? _accentGreen
                              : _riskColor,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ASSESSMENT SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _summaryText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final service = HistoryService();
                      service.addRecord(
                        ScanRecord(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          mosquitoType: mosquitoType,
                          result: _riskLevel,
                          confidence: totalSymptoms > 0
                              ? symptomCount / totalSymptoms
                              : 0,
                          date: DateTime.now(),
                          symptoms: selectedSymptoms,
                          riskScore: symptomCount,
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Symptom assessment logged'),
                          backgroundColor: _accentGreen,
                        ),
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Back to Home',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareTipCard extends StatelessWidget {
  final Map<String, dynamic> tip;
  final Color accent;

  const _CareTipCard({required this.tip, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.14),
              ),
              child: Icon(tip['icon'] as IconData, size: 22, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              tip['title'] as String,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                tip['subtitle'] as String,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

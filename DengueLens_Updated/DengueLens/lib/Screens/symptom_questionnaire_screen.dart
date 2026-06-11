import 'package:flutter/material.dart';
import 'symptom_result_screen.dart';

/// Symptom questionnaire screen — refactored for clarity.
class SymptomQuestionnaireScreen extends StatefulWidget {
  final String mosquitoType;
  final bool skipBittenQuestion;

  const SymptomQuestionnaireScreen({
    super.key,
    required this.mosquitoType,
    this.skipBittenQuestion = false,
  });

  @override
  State<SymptomQuestionnaireScreen> createState() =>
      _SymptomQuestionnaireScreenState();
}

class _SymptomQuestionnaireScreenState
    extends State<SymptomQuestionnaireScreen> {
  // If true, show the checklist. Otherwise ask the bitten question.
  late bool _showChecklist;

  static const List<_Symptom> _symptoms = [
    _Symptom(
      title: 'High fever',
      subtitle: 'Sudden onset above 38.5°C',
      icon: Icons.thermostat,
    ),
    _Symptom(
      title: 'Severe headache',
      subtitle: 'Intense pain across forehead',
      icon: Icons.psychology_alt,
    ),
    _Symptom(
      title: 'Eye pain',
      subtitle: 'Pain behind the eyes',
      icon: Icons.visibility,
    ),
    _Symptom(
      title: 'Joint/muscle pain',
      subtitle: 'Severe "bone-breaking" pain',
      icon: Icons.fitness_center,
    ),
    _Symptom(
      title: 'Skin rash',
      subtitle: 'Red spots on torso or limbs',
      icon: Icons.grain,
    ),
    _Symptom(
      title: 'Nausea',
      subtitle: 'Persistent vomiting or queasiness',
      icon: Icons.mood_bad,
    ),
    _Symptom(
      title: 'Swollen glands',
      subtitle: 'Enlarged lymph nodes in neck',
      icon: Icons.account_circle,
    ),
    _Symptom(
      title: 'Fatigue',
      subtitle: 'Extreme weakness or exhaustion',
      icon: Icons.battery_1_bar,
    ),
  ];

  late final List<bool> _selected;
  bool _noSymptoms = false;

  @override
  void initState() {
    super.initState();
    _showChecklist = widget.skipBittenQuestion;
    _selected = List<bool>.filled(_symptoms.length, false);
  }

  int get _selectedCount => _selected.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Symptom Check'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showChecklist
            ? _SymptomChecklistView(
                symptoms: _symptoms,
                selected: _selected,
                noSymptoms: _noSymptoms,
                onToggleNoSymptoms: _toggleNoSymptoms,
                onToggleSymptom: _toggleSymptom,
                onSubmit: _submitSymptoms,
              )
            : _BittenQuestionView(
                onYes: () => setState(() => _showChecklist = true),
                onNo: () => Navigator.of(context).pop(),
              ),
      ),
    );
  }

  void _toggleNoSymptoms() {
    setState(() {
      _noSymptoms = !_noSymptoms;
      if (_noSymptoms) {
        for (var i = 0; i < _selected.length; i++) {
          _selected[i] = false;
        }
      }
    });
  }

  void _toggleSymptom(int index) {
    setState(() {
      _noSymptoms = false;
      _selected[index] = !_selected[index];
    });
  }

  void _submitSymptoms() {
    final selected = <String>[];
    for (var i = 0; i < _symptoms.length; i++) {
      if (_selected[i]) {
        selected.add(_symptoms[i].title);
      }
    }

    if (selected.isEmpty && !_noSymptoms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one option'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SymptomResultScreen(
          symptomCount: _noSymptoms ? 0 : _selectedCount,
          totalSymptoms: _symptoms.length,
          selectedSymptoms: selected,
          mosquitoType: widget.mosquitoType,
        ),
      ),
    );
  }
}

// Small presentational widgets below

class _BittenQuestionView extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _BittenQuestionView({
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.shade50,
              ),
              child: Icon(
                Icons.pest_control,
                size: 56,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Would you like to do an early dengue symptom assessment?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Symptoms can be mild or severe, with warning signs of severe cases appearing 24-48 hours after the fever subsides.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onYes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Start Assessment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onNo,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Not Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SymptomChecklistView extends StatelessWidget {
  final List<_Symptom> symptoms;
  final List<bool> selected;
  final bool noSymptoms;
  final VoidCallback onToggleNoSymptoms;
  final void Function(int) onToggleSymptom;
  final VoidCallback onSubmit;

  const _SymptomChecklistView({
    required this.symptoms,
    required this.selected,
    required this.noSymptoms,
    required this.onToggleNoSymptoms,
    required this.onToggleSymptom,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interactive Assessment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select all symptoms you have experienced in the last 24-48 hours.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: symptoms.length + 1,
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  return _NoSymptomsTile(
                    isSelected: noSymptoms,
                    onTap: onToggleNoSymptoms,
                  );
                }
                final i = idx - 1;
                return _SymptomCard(
                  symptom: symptoms[i],
                  isSelected: selected[i],
                  onTap: () => onToggleSymptom(i),
                );
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Submit Assessment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoSymptomsTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _NoSymptomsTile({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 46,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2ECC71)
                        : Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "I don't experience any of these symptoms",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No dengue-related symptoms detected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF2ECC71)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2ECC71)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Symptom {
  final String title;
  final String subtitle;
  final IconData icon;

  const _Symptom({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SymptomCard extends StatelessWidget {
  final _Symptom symptom;
  final bool isSelected;
  final VoidCallback onTap;

  const _SymptomCard({
    required this.symptom,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade100, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 46,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2ECC71)
                        : Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        symptom.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        symptom.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF2ECC71)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2ECC71)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

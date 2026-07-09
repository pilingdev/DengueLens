import 'package:hive/hive.dart';

/// Manages the onboarding tutorial state using Hive for persistence.
///
/// Tracks whether the user has completed the initial tutorial walkthrough
/// and provides methods to mark it as seen or reset it for replay.
class TutorialService {
  static const String _boxName = 'tutorial_prefs';
  static const String _hasSeenKey = 'has_seen_tutorial';

  // Singleton pattern
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  late Box _box;

  /// Opens the Hive box for tutorial preferences.
  /// Must be called after [Hive.initFlutter()].
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Whether the user has already seen the onboarding tutorial.
  bool get hasSeenTutorial => _box.get(_hasSeenKey, defaultValue: false);

  /// Marks the tutorial as completed so it won't auto-show again.
  Future<void> markTutorialSeen() async {
    await _box.put(_hasSeenKey, true);
  }

  /// Resets the flag so the tutorial can be replayed.
  Future<void> resetTutorial() async {
    await _box.put(_hasSeenKey, false);
  }
}

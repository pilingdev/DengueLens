import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_record.dart';
import '../services/history_service.dart';

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Wraps [HistoryService] so widgets can reactively rebuild when history changes
/// without relying on raw `setState` calls scattered across screens.
class HistoryNotifier extends StateNotifier<List<ScanRecord>> {
  HistoryNotifier() : super(HistoryService().records);

  /// Adds a [record] via the service and refreshes observable state.
  Future<void> addRecord(ScanRecord record) async {
    await HistoryService().addRecord(record);
    state = List.unmodifiable(HistoryService().records);
  }

  /// Clears all records and refreshes observable state.
  Future<void> clearHistory() async {
    await HistoryService().clearHistory();
    state = const [];
  }

  /// Call after [HistoryService.init()] to load persisted records on startup.
  void refresh() {
    state = List.unmodifiable(HistoryService().records);
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Global provider – exposes the current list of [ScanRecord]s reactively.
final historyProvider = StateNotifierProvider<HistoryNotifier, List<ScanRecord>>(
  (ref) => HistoryNotifier(),
);

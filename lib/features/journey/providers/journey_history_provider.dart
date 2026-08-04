import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/backend_service.dart';

class JourneyHistoryNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  JourneyHistoryNotifier() : super(const AsyncValue.loading()) {
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    state = const AsyncValue.loading();
    try {
      final data = await BackendService.getJourneys();
      final List<Map<String, dynamic>> journeys = data.cast<Map<String, dynamic>>();
      state = AsyncValue.data(journeys);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final journeyHistoryProvider = StateNotifierProvider<JourneyHistoryNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return JourneyHistoryNotifier();
});

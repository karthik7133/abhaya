import 'dart:convert';
import 'cache_manager.dart';

class OfflineQueueService {
  static const String _queueKey = 'offline_sync_queue';
  final CacheManager _cache;

  OfflineQueueService(this._cache);

  /// Adds a task to the offline queue
  Future<void> enqueueTask({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final task = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final queue = getQueue();
    queue.add(task);
    await _saveQueue(queue);
  }

  /// Retrieves the current queue of offline tasks
  List<Map<String, dynamic>> getQueue() {
    final str = _cache.getString(_queueKey);
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Removes a task from the queue by its ID
  Future<void> dequeueTask(String taskId) async {
    final queue = getQueue();
    queue.removeWhere((t) => t['id'] == taskId);
    await _saveQueue(queue);
  }

  /// Clears the entire queue
  Future<void> clearQueue() async {
    await _cache.remove(_queueKey);
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _cache.setString(_queueKey, jsonEncode(queue));
  }
}

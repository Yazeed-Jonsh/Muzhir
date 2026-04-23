import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/models/scan_history_item.dart';

/// Full scan history for the signed-in user (API max limit).
///
/// [HistoryPage] and [FarmerHomePage] watch this so totals stay consistent
/// and invalidation after a delete updates both immediately.
final scanHistoryProvider = FutureProvider<List<ScanHistoryItem>>((ref) async {
  return ApiService().getScanHistory(limit: 100);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/models/scan_history_item.dart';

/// Scan history for the signed-in user.
///
/// [HistoryPage] and [FarmerHomePage] watch this so totals stay consistent
/// and invalidation after a delete updates both immediately.
/// keepAlive prevents a re-fetch on every tab switch.
final scanHistoryProvider = FutureProvider.autoDispose<List<ScanHistoryItem>>((ref) async {
  ref.keepAlive();
  return ApiService().getScanHistory(limit: 20);
});

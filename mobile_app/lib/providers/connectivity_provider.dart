import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _connectivityListIsOffline(List<ConnectivityResult> results) {
  if (results.isEmpty) return true;
  final hasTransport = results.any(
    (r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn ||
        r == ConnectivityResult.other,
  );
  return !hasTransport;
}

/// Whether the device appears to have no usable network (UI / best-effort).
///
/// Firestore may still sync over other paths; pair with
/// [UserProfileSnapshot.isFromCache] when showing cache state.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _connectivityListIsOffline(await connectivity.checkConnectivity());
  await for (final list in connectivity.onConnectivityChanged) {
    yield _connectivityListIsOffline(list);
  }
});

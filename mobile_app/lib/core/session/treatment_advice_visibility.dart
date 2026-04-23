/// Remembers which scans had treatment advice expanded this session (History / Detail / Diagnose).
class TreatmentAdviceVisibility {
  TreatmentAdviceVisibility._();

  static final Set<String> _expandedScanIds = <String>{};

  static bool isExpanded(String scanId) {
    final id = scanId.trim();
    if (id.isEmpty) return false;
    return _expandedScanIds.contains(id);
  }

  static void setExpanded(String scanId, bool expanded) {
    final id = scanId.trim();
    if (id.isEmpty) return;
    if (expanded) {
      _expandedScanIds.add(id);
    } else {
      _expandedScanIds.remove(id);
    }
  }
}

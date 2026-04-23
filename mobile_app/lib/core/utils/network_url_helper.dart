class NetworkUrlHelper {
  NetworkUrlHelper._();

  /// Normalizes remote image URLs for iOS/web renderers.
  ///
  /// - Converts protocol-relative URLs (`//...`) to `https://...`.
  /// - Upgrades Cloudinary and OpenStreetMap hosts from `http` to `https`.
  /// - Adds `https://` when Cloudinary/OpenStreetMap URLs come without scheme.
  static String normalizeRemoteUrl(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';

    if (value.startsWith('//')) {
      return 'https:$value';
    }

    final Uri? parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      if (parsed.scheme == 'http') {
        return parsed.replace(scheme: 'https').toString();
      }
      return value;
    }

    final lower = value.toLowerCase();
    if (lower.startsWith('res.cloudinary.com/') ||
        lower.startsWith('media.cloudinary.com/') ||
        lower.startsWith('openstreetmap.org/') ||
        lower.startsWith('tile.openstreetmap.org/')) {
      return 'https://$value';
    }

    return value;
  }
}

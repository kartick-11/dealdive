import 'package:url_launcher/url_launcher.dart';

class MapsLauncher {
  static Future<void> openDirections({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final encodedLabel = Uri.encodeComponent(label ?? 'Destination');

    // Google Maps directions URL
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$lat,$lng'
        '&destination_place_id='
        '&travelmode=driving'
        '&dir_action=navigate'
        '&query=$encodedLabel';

    final uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      // Launch Google Maps app if available
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to browser map only
      final fallback = Uri.parse('https://maps.google.com/?q=$lat,$lng');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }
}

import 'package:flutter/material.dart';
import '../models/deal.dart';
import '../theme/app_theme.dart';
import '../utils/maps_launcher.dart';

Color _onColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

class DealDetailScreen extends StatefulWidget {
  final Deal deal;
  final bool isSaved;
  final void Function(Deal) onToggleSaved;
  final void Function(Deal) onViewOnMap;

  /// Optional distance label like "1.2 km away"
  final String? distanceText;

  const DealDetailScreen({
    super.key,
    required this.deal,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onViewOnMap,
    this.distanceText,
  });

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  // Tracked locally because this screen is pushed as its own route — the
  // parent's saved-set updating doesn't automatically rebuild an
  // already-open route, so the bookmark icon needs its own state to
  // actually flip the moment it's tapped.
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  void _handleToggleSaved() {
    setState(() => _isSaved = !_isSaved);
    widget.onToggleSaved(widget.deal);
  }

  Deal get deal => widget.deal;
  String? get distanceText => widget.distanceText;

  bool get _isHappyHour => deal.category == 'Happy Hour';

  /// The scraper joins individual specials with " • " into one description
  /// string. Split it back out so each special can render as its own line
  /// instead of one dense paragraph.
  List<String> get _specials {
    if (deal.description == null || deal.description!.isEmpty) return [];
    return deal.description!
        .split(' • ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final specials = _specials;
    final categoryColor = AppColors.forCategory(deal.category);
    final onCategoryColor = _onColor(categoryColor);
    final subtleColor = scheme.onSurface.withValues(alpha: 0.6);

    // Happy Hour's title repeats storeName ("{venue} — {Day} Happy Hour"
    // vs "{venue}") and was overflowing off the top of this screen. Lead
    // with the venue name; the day shows in its own chip below already.
    final headline = _isHappyHour ? deal.storeName : deal.title;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deal details'),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
            ),
            onPressed: _handleToggleSaved,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional image
            if (deal.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    deal.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    _isHappyHour
                        ? Icons.local_bar_outlined
                        : Icons.local_offer_outlined,
                    size: 48,
                    color: categoryColor,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Title
            Text(
              headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Store name (skipped for Happy Hour — it's already the headline)
            if (!_isHappyHour) ...[
              Text(
                deal.storeName,
                style: theme.textTheme.bodyMedium?.copyWith(color: subtleColor),
              ),
              const SizedBox(height: 8),
            ],

            // Category + optional distance
            Row(
              children: [
                Text(
                  deal.category,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (distanceText != null) ...[
                  const SizedBox(width: 8),
                  Text('·', style: TextStyle(fontSize: 12, color: subtleColor)),
                  const SizedBox(width: 4),
                  Text(
                    distanceText!,
                    style: theme.textTheme.labelMedium?.copyWith(color: subtleColor),
                  ),
                ],
              ],
            ),

            // Day / neighbourhood chips — Happy Hour deals only
            if (_isHappyHour && (deal.day != null || deal.neighbourhood != null)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (deal.day != null)
                    Chip(
                      avatar: Icon(Icons.calendar_today, size: 16, color: onCategoryColor),
                      label: Text(deal.day!, style: TextStyle(color: onCategoryColor, fontWeight: FontWeight.w600)),
                      backgroundColor: categoryColor,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (deal.neighbourhood != null)
                    Chip(
                      avatar: Icon(Icons.place_outlined, size: 16, color: scheme.onSurface),
                      label: Text(deal.neighbourhood!, style: TextStyle(color: scheme.onSurface)),
                      backgroundColor: scheme.surface,
                      side: BorderSide(color: theme.dividerColor, width: 1.5),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Price
            if (deal.price > 0)
              Text(
                _isHappyHour
                    ? 'From \$${deal.price.toStringAsFixed(2)}'
                    : '\$${deal.price.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                'See offer details below',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),

            const SizedBox(height: 16),

            // Specials list (Happy Hour) or plain description (everything else)
            if (_isHappyHour && specials.isNotEmpty) ...[
              Text(
                'Specials',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...specials.map((special) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: Icon(Icons.circle, size: 6),
                        ),
                        Expanded(
                          child: Text(
                            special,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
            ] else if (deal.description != null && deal.description!.isNotEmpty)
              Text(
                deal.description!,
                style: theme.textTheme.bodyMedium,
              )
            else
              Text(
                'Great local deal near you. Tap "View on map" or "Directions" to see how to get there.',
                style: theme.textTheme.bodyMedium,
              ),

            const SizedBox(height: 24),

            // Buttons row: View on map + Directions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onViewOnMap(deal);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on map'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      MapsLauncher.openDirections(
                        lat: deal.latitude,
                        lng: deal.longitude,
                        label: '${deal.storeName} - ${deal.title}',
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
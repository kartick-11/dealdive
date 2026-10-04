import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/deal.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import '../services/location_service.dart';
import '../utils/distance_utils.dart';

/// Picks black or white text for best contrast against [color].
Color _onColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

class HomeScreen extends StatefulWidget {
  final String selectedCategory;
  final String searchQuery;
  final Set<String> savedDealIds;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final void Function(Deal) onViewOnMap;
  final void Function(Deal) onToggleSaved;

  const HomeScreen({
    super.key,
    required this.selectedCategory,
    required this.searchQuery,
    required this.savedDealIds,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onViewOnMap,
    required this.onToggleSaved,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final List<String> _categories = [
    'All',
    'Food',
    'Fast Food',
    'Grocery',
    'Retail',
    'Electronics',
    'Gas',
    'Student',
    'Black Friday',
    'Happy Hour',
  ];

  // Malls covered by the Black Friday category. Shown as a second row of
  // chips only when that category is active.
  final List<String> _malls = [
    'All Malls',
    'McArthurGlen Vancouver',
    'Tsawwassen Mills',
    'Metropolis at Metrotown',
  ];
  String _selectedMall = 'All Malls';

  // Day filter — appears only for Happy Hour, since that's the only
  // category with a "day" field on its deals.
  final List<String> _days = [
    'All Days',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String _selectedDay = 'All Days';

  // Supermarket filter — appears only for Grocery, mirroring the day
  // selector for Happy Hour. Names match grocery_scraper.py's merchant
  // search list (app/scrapers/grocery_scraper.py: MERCHANT_QUERIES).
  final List<String> _supermarkets = [
    'All Supermarkets',
    'Save-On-Foods',
    'Safeway',
    'No Frills',
    'Real Canadian Superstore',
    'Walmart',
    'T&T Supermarket',
    'Costco',
    'Whole Foods',
    'Sobeys',
    'FreshCo',
  ];
  String _selectedSupermarket = 'All Supermarkets';

  // City filter — applies across every category, not just malls. Deals
  // with no city tag (e.g. national app promos) always show regardless
  // of which city is selected.
  final List<String> _cities = [
    'All Cities',
    'Vancouver',
    'Burnaby',
    'New Westminster',
    'Richmond',
    'Surrey',
    'Delta',
    'Langley',
    'Abbotsford',
  ];
  String _selectedCity = 'All Cities';

  Position? _userPosition;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    final pos = await LocationService.getCurrentPosition();

    setState(() {
      _userPosition = pos;
      _isLoadingLocation = false;
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
    // Reset the mall filter whenever the category changes away from or
    // back into Black Friday, so it doesn't silently carry over.
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _selectedMall = 'All Malls';
      _selectedDay = 'All Days';
      _selectedSupermarket = 'All Supermarkets';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double? _distanceForDeal(Deal deal) {
    if (_userPosition == null) return null;
    return calculateDistanceKm(
      userLat: _userPosition!.latitude,
      userLng: _userPosition!.longitude,
      dealLat: deal.latitude,
      dealLng: deal.longitude,
    );
  }

  // Only Black Friday carries per-mall tenant listings now — the
  // old day-to-day mall directory under Retail was its own separate
  // "Mall Directory" category and never real priced deals, so it no
  // longer needs this selector mixed into Retail.
  bool get _showsMallSelector => widget.selectedCategory == 'Black Friday';

  bool get _showsDaySelector => widget.selectedCategory == 'Happy Hour';

  bool get _showsSupermarketSelector => widget.selectedCategory == 'Grocery';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilters(),
        _buildCitySelector(),
        if (_showsMallSelector) _buildMallSelector(),
        if (_showsDaySelector) _buildDaySelector(),
        if (_showsSupermarketSelector) _buildSupermarketSelector(),
        if (_isLoadingLocation)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('deals')
                .orderBy('price')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading deals',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No deals yet.\nUse the seed tool or add deals in Firestore.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final allDeals = docs
                  .map((doc) => Deal.fromFirestore(doc.id, doc.data()))
                  .where((deal) {
                final matchesCategory = widget.selectedCategory == 'All' ||
                    deal.category.toLowerCase() ==
                        widget.selectedCategory.toLowerCase();

                final matchesMall = !_showsMallSelector ||
                    _selectedMall == 'All Malls' ||
                    deal.mall == _selectedMall;

                final matchesCity = _selectedCity == 'All Cities' ||
                    deal.city == null ||
                    deal.city == _selectedCity;

                final matchesDay = !_showsDaySelector ||
                    _selectedDay == 'All Days' ||
                    deal.day == _selectedDay;

                // Matched loosely (contains, either direction) rather than
                // an exact string match — Flipp's own merchant_name casing
                // ("T&T" vs "T&T Supermarket", etc.) doesn't always match
                // our curated chip labels exactly.
                final matchesSupermarket = !_showsSupermarketSelector ||
                    _selectedSupermarket == 'All Supermarkets' ||
                    deal.storeName
                        .toLowerCase()
                        .contains(_selectedSupermarket.toLowerCase()) ||
                    _selectedSupermarket
                        .toLowerCase()
                        .contains(deal.storeName.toLowerCase());

                final q = widget.searchQuery.trim().toLowerCase();
                final matchesSearch = q.isEmpty ||
                    deal.title.toLowerCase().contains(q) ||
                    deal.storeName.toLowerCase().contains(q);
                return matchesCategory &&
                    matchesMall &&
                    matchesCity &&
                    matchesDay &&
                    matchesSupermarket &&
                    matchesSearch;
              }).toList();

              if (allDeals.isEmpty) {
                return const Center(
                  child: Text(
                    'No deals match your filters.\nTry changing category or search.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              // --- Build "Top deals near you" ---
              List<Deal> topDeals = List.of(allDeals);

              if (_userPosition != null) {
                topDeals.sort((a, b) {
                  final da = _distanceForDeal(a) ?? double.infinity;
                  final db = _distanceForDeal(b) ?? double.infinity;
                  return da.compareTo(db);
                });
              } else {
                // No location: prefer isHot flag
                topDeals.sort((a, b) {
                  if (a.isHot && !b.isHot) return -1;
                  if (!a.isHot && b.isHot) return 1;
                  return a.price.compareTo(b.price);
                });
              }

              topDeals = topDeals
                  .where((d) => d.isHot)
                  .take(5)
                  .toList();

              final topIds = topDeals.map((d) => d.id).toSet();
              final remainingDeals =
                  allDeals.where((d) => !topIds.contains(d.id)).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (topDeals.isNotEmpty)
                    _TopDealsStrip(
                      deals: topDeals,
                      userPosition: _userPosition,
                      savedDealIds: widget.savedDealIds,
                      onTapDeal: _openDealDetail,
                      onToggleSaved: widget.onToggleSaved,
                    ),
                  if (topDeals.isNotEmpty)
                    const SizedBox(height: 16),
                  ...remainingDeals.map((deal) {
                    final isSaved = widget.savedDealIds.contains(deal.id);
                    final distanceKm = _distanceForDeal(deal);
                    final distanceText = distanceKm == null
                        ? null
                        : '${distanceKm.toStringAsFixed(1)} km away';
                    return _DealCard(
                      deal: deal,
                      isSaved: isSaved,
                      distanceText: distanceText,
                      onTap: () => _openDealDetail(deal),
                      onViewOnMap: () => widget.onViewOnMap(deal),
                      onToggleSaved: () => widget.onToggleSaved(deal),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDealDetail(Deal deal) {
    final isSaved = widget.savedDealIds.contains(deal.id);
    final distanceKm = _distanceForDeal(deal);
    final distanceText =
        distanceKm == null ? null : '${distanceKm.toStringAsFixed(1)} km away';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DealDetailScreen(
          deal: deal,
          isSaved: isSaved,
          onToggleSaved: widget.onToggleSaved,
          onViewOnMap: widget.onViewOnMap,
          distanceText: distanceText,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search for pizza, milk, gas...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == widget.selectedCategory;

                return _FilterChip(
                  label: cat,
                  isSelected: isSelected,
                  onSelected: () => widget.onCategoryChanged(cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _cities.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final city = _cities[index];
            final isSelected = city == _selectedCity;

            return _FilterChip(
              label: city,
              isSelected: isSelected,
              compact: true,
              onSelected: () => setState(() => _selectedCity = city),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _days.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final day = _days[index];
            final isSelected = day == _selectedDay;

            return _FilterChip(
              label: day,
              isSelected: isSelected,
              compact: true,
              onSelected: () => setState(() => _selectedDay = day),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSupermarketSelector() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _supermarkets.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final supermarket = _supermarkets[index];
            final isSelected = supermarket == _selectedSupermarket;

            return _FilterChip(
              label: supermarket,
              isSelected: isSelected,
              compact: true,
              onSelected: () => setState(() => _selectedSupermarket = supermarket),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMallSelector() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _malls.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final mall = _malls[index];
            final isSelected = mall == _selectedMall;

            return _FilterChip(
              label: mall,
              isSelected: isSelected,
              compact: true,
              onSelected: () => setState(() => _selectedMall = mall),
            );
          },
        ),
      ),
    );
  }
}

/// A single themed filter pill, shared by every selector row on this screen
/// so category/city/day/mall chips all read as one consistent system
/// instead of each row inventing its own ad hoc color.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final bool compact;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label, style: compact ? const TextStyle(fontSize: 12) : null),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      visualDensity: compact ? VisualDensity.compact : null,
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      side: BorderSide(
        color: isSelected ? scheme.primary : theme.dividerColor,
        width: 1.5,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: isSelected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _TopDealsStrip extends StatelessWidget {
  final List<Deal> deals;
  final Position? userPosition;
  final Set<String> savedDealIds;
  final void Function(Deal) onTapDeal;
  final void Function(Deal) onToggleSaved;

  const _TopDealsStrip({
    required this.deals,
    required this.userPosition,
    required this.savedDealIds,
    required this.onTapDeal,
    required this.onToggleSaved,
  });

  double? _distanceForDeal(Deal deal) {
    if (userPosition == null) return null;
    return calculateDistanceKm(
      userLat: userPosition!.latitude,
      userLng: userPosition!.longitude,
      dealLat: deal.latitude,
      dealLng: deal.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔥 Top deals near you',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: deals.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final deal = deals[index];
              final isSaved = savedDealIds.contains(deal.id);
              final distanceKm = _distanceForDeal(deal);
              final distanceText = distanceKm == null
                  ? null
                  : '${distanceKm.toStringAsFixed(1)} km';

              final theme = Theme.of(context);
              final scheme = theme.colorScheme;
              final subtleColor = scheme.onSurface.withValues(alpha: 0.6);
              final categoryColor = AppColors.forCategory(deal.category);

              // Happy Hour's title is "{venue} — {Day} Happy Hour" and
              // storeName is just "{venue}" — showing both stacked repeats
              // the venue name twice. Lead with the venue, and use the day
              // as the subtitle instead of repeating it.
              final subtitle = deal.day != null
                  ? '${deal.day} Happy Hour'
                  : deal.category;

              return GestureDetector(
                onTap: () => onTapDeal(deal),
                child: Container(
                  width: 220,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      categoryColor.withValues(alpha: 0.12),
                      theme.cardTheme.color ?? scheme.surface,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              deal.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isSaved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border_outlined,
                              size: 18,
                              color: isSaved ? scheme.primary : subtleColor,
                            ),
                            onPressed: () => onToggleSaved(deal),
                          )
                        ],
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: subtleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deal.price > 0
                            ? '\$${deal.price.toStringAsFixed(2)}'
                            : 'Offers',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                      if (distanceText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          distanceText,
                          style: TextStyle(fontSize: 11, color: subtleColor),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  final Deal deal;
  final bool isSaved;
  final String? distanceText;
  final VoidCallback onTap;
  final VoidCallback onViewOnMap;
  final VoidCallback onToggleSaved;

  const _DealCard({
    required this.deal,
    required this.isSaved,
    required this.distanceText,
    required this.onTap,
    required this.onViewOnMap,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtleColor = scheme.onSurface.withValues(alpha: 0.6);
    final categoryColor = AppColors.forCategory(deal.category);
    final onCategoryColor = _onColor(categoryColor);

    // Happy Hour's title repeats storeName ("{venue} — {Day} Happy Hour"
    // vs "{venue}") — lead with the venue and show the day separately
    // instead of printing the venue name twice.
    final headline = deal.day != null ? deal.storeName : deal.title;
    final subline = deal.day != null ? '${deal.day} Happy Hour' : deal.storeName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Color.alphaBlend(
        categoryColor.withValues(alpha: 0.08),
        theme.cardTheme.color ?? scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: categoryColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price bubble — some deals (Black Friday, mall listings)
              // don't have one meaningful price, so show a neutral label
              // instead of a misleading $0.00. Tinted per-category so a
              // scrolling list of cards reads as varied, not one flat color
              // repeated for every deal regardless of type.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: deal.price > 0
                    ? Text(
                        '\$${deal.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: onCategoryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(
                        'Offers',
                        style: TextStyle(
                          color: onCategoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Main text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subline,
                      style: TextStyle(fontSize: 14, color: subtleColor),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          deal.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: categoryColor,
                          ),
                        ),
                        if (distanceText != null) ...[
                          const SizedBox(width: 8),
                          Text('·', style: TextStyle(fontSize: 12, color: subtleColor)),
                          const SizedBox(width: 4),
                          Text(
                            distanceText!,
                            style: TextStyle(fontSize: 12, color: subtleColor),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onViewOnMap,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('View on map'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onToggleSaved,
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark
                                : Icons.bookmark_border_outlined,
                            color: isSaved ? scheme.primary : subtleColor,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
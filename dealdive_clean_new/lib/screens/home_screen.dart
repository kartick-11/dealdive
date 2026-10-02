import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/deal.dart';
import 'deal_detail_screen.dart';
import '../services/location_service.dart';
import '../utils/distance_utils.dart';

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

  bool get _showsMallSelector =>
      widget.selectedCategory == 'Black Friday' ||
      widget.selectedCategory == 'Retail';

  bool get _showsDaySelector => widget.selectedCategory == 'Happy Hour';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilters(),
        _buildCitySelector(),
        if (_showsMallSelector) _buildMallSelector(),
        if (_showsDaySelector) _buildDaySelector(),
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

                final q = widget.searchQuery.trim().toLowerCase();
                final matchesSearch = q.isEmpty ||
                    deal.title.toLowerCase().contains(q) ||
                    deal.storeName.toLowerCase().contains(q);
                return matchesCategory && matchesMall && matchesCity && matchesDay && matchesSearch;
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search for pizza, milk, gas...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF4F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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

                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => widget.onCategoryChanged(cat),
                  selectedColor: const Color(0xFF00C4E6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: Colors.white,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _cities.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final city = _cities[index];
            final isSelected = city == _selectedCity;

            return ChoiceChip(
              label: Text(city, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCity = city),
              selectedColor: const Color(0xFF00897B),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: Colors.white,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _days.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final day = _days[index];
            final isSelected = day == _selectedDay;

            return ChoiceChip(
              label: Text(day, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDay = day),
              selectedColor: const Color(0xFFEF6C00),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMallSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: Colors.white,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _malls.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final mall = _malls[index];
            final isSelected = mall == _selectedMall;

            return ChoiceChip(
              label: Text(mall, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedMall = mall),
              selectedColor: const Color(0xFF00C4E6).withValues(alpha: 0.8),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            );
          },
        ),
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

              return GestureDetector(
                onTap: () => onTapDeal(deal),
                child: Container(
                  width: 220,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 4,
                        color: Colors.black12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              deal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
                              color: isSaved
                                  ? const Color(0xFF00C4E6)
                                  : Colors.grey,
                            ),
                            onPressed: () => onToggleSaved(deal),
                          )
                        ],
                      ),
                      Text(
                        deal.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deal.price > 0
                            ? '\$${deal.price.toStringAsFixed(2)} • ${deal.category}'
                            : 'Offers • ${deal.category}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (distanceText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price bubble — some deals (Black Friday, mall listings)
              // don't have one meaningful price, so show a neutral label
              // instead of a misleading $0.00.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C4E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: deal.price > 0
                    ? Text(
                        '\$${deal.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Text(
                        'Offers',
                        style: TextStyle(
                          color: Colors.white,
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
                      deal.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deal.storeName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          deal.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (distanceText != null) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '·',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceText!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
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
                            color:
                                isSaved ? const Color(0xFF00C4E6) : Colors.grey,
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
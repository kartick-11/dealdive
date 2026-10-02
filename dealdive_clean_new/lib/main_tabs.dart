import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/deal.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/saved_screen.dart';
import 'services/saved_deals_service.dart';
import 'profile_screen.dart';

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _selectedIndex = 0;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  Deal? _focusDeal;
  Set<String> _savedDealIds = {};
  bool _loadingSaved = false;
  SavedDealsService? _savedDealsService;
  StreamSubscription<Set<String>>? _savedDealsSub;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _savedDealsService = SavedDealsService(userId: user.uid);
    _loadingSaved = true;
    _savedDealsSub = _savedDealsService!.savedDealIdsStream().listen(
      (ids) {
        if (!mounted) return;
        setState(() {
          _savedDealIds = ids;
          _loadingSaved = false;
        });
      },
      onError: (e) {
        debugPrint('Error streaming saved deals: $e');
        if (!mounted) return;
        setState(() => _loadingSaved = false);
      },
    );
  }

  @override
  void dispose() {
    _savedDealsSub?.cancel();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onViewOnMap(Deal deal) {
    setState(() {
      _focusDeal = deal;
      _selectedIndex = 1;
    });
  }

  Future<void> _onToggleSaved(Deal deal) async {
    if (_savedDealsService == null) return;
    final currentlySaved = _savedDealIds.contains(deal.id);
    final newSaved = !currentlySaved;

    setState(() {
      if (newSaved) {
        _savedDealIds.add(deal.id);
      } else {
        _savedDealIds.remove(deal.id);
      }
    });

    try {
      await _savedDealsService!.setSaved(deal.id, newSaved);
    } catch (e) {
      debugPrint('Error updating saved deal: $e');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        selectedCategory: _selectedCategory,
        searchQuery: _searchQuery,
        savedDealIds: _savedDealIds,
        onCategoryChanged: _onCategoryChanged,
        onSearchChanged: _onSearchChanged,
        onViewOnMap: _onViewOnMap,
        onToggleSaved: _onToggleSaved,
      ),
      MapScreen(
        selectedCategory: _selectedCategory,
        focusDeal: _focusDeal,
        savedDealIds: _savedDealIds,
        onToggleSaved: _onToggleSaved,
      ),
      SavedScreen(
        savedDealIds: _savedDealIds,
        onViewOnMap: _onViewOnMap,
        onToggleSaved: _onToggleSaved,
      ),
      const ProfileScreen(),
    ];

    final titles = ['Deals', 'Map', 'Saved', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Stack(
        children: [
          screens[_selectedIndex],
          if (_loadingSaved)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading saved deals...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00C4E6),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_outlined),
            label: 'Deals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
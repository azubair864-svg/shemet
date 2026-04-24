import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/search_service.dart';

class AdvancedSearchScreen extends StatefulWidget {
  final String currentUserId;
  final UserModel? currentUser;

  const AdvancedSearchScreen({
    super.key,
    required this.currentUserId,
    this.currentUser,
  });

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen>
    with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;

  // Search state
  List<UserModel> _searchResults = [];
  List<UserModel> _suggestedUsers = [];
  List<UserModel> _nearbyUsers = [];
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _lastUserId;
  String? _error;

  // Filter state
  SearchFilters _filters = SearchFilters();
  bool _showFilters = false;

  // Filter controllers
  String? _selectedGender;
  RangeValues _ageRange = const RangeValues(18, 50);
  String? _selectedCountry;
  String? _selectedLanguage;
  List<String> _selectedInterests = [];
  bool _onlineOnly = false;
  bool _verifiedOnly = false;
  bool _vipOnly = false;
  bool _hostsOnly = false;
  double _maxDistance = 100;
  SortBy _sortBy = SortBy.lastActive;

  // Available options
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _countryOptions = [
    'United States',
    'United Kingdom',
    'India',
    'Philippines',
    'Indonesia',
    'Thailand',
    'Vietnam',
    'Japan',
    'Korea',
    'China',
    'Brazil',
    'Mexico',
    'Other'
  ];
  final List<String> _languageOptions = [
    'English',
    'Hindi',
    'Spanish',
    'Chinese',
    'Arabic',
    'Japanese',
    'Korean',
    'Thai',
    'Vietnamese',
    'Indonesian'
  ];
  final List<String> _interestOptions = [
    'Music',
    'Gaming',
    'Movies',
    'Travel',
    'Food',
    'Sports',
    'Photography',
    'Art',
    'Fashion',
    'Technology',
    'Reading',
    'Fitness',
    'Dancing',
    'Cooking',
    'Nature'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadInitialData();
    
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    
    _loadTabData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _tabController.index == 0) {
        _loadMoreResults();
      }
    }
  }

  Future<void> _loadInitialData() async {
    
    await Future.wait([
      _loadRecentSearches(),
      _loadSuggestedUsers(),
      _loadNearbyUsers(),
    ]);
  }

  Future<void> _loadTabData() async {
    switch (_tabController.index) {
      case 1:
        if (_suggestedUsers.isEmpty) await _loadSuggestedUsers();
        break;
      case 2:
        if (_nearbyUsers.isEmpty) await _loadNearbyUsers();
        break;
    }
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _searchService.getRecentSearches(widget.currentUserId);
    if (mounted) {
      setState(() {
        _recentSearches = searches;
      });
    }
    
  }

  Future<void> _loadSuggestedUsers() async {
    if (widget.currentUser == null) {
      
      return;
    }

    setState(() => _isLoading = true);

    try {
      final users = await _searchService.getSuggestedUsers(
        currentUserId: widget.currentUserId,
        currentUser: widget.currentUser!,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _suggestedUsers = users;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _error = 'Failed to load suggestions';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNearbyUsers() async {
    // Use mock location or get from current user
    final double lat = widget.currentUser?.latitude ?? 0;
    final double lng = widget.currentUser?.longitude ?? 0;

    if (lat == 0 && lng == 0) {
      
      return;
    }

    setState(() => _isLoading = true);

    try {
      final users = await _searchService.getNearbyUsers(
        latitude: lat,
        longitude: lng,
        radiusKm: _maxDistance,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _nearbyUsers = users;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _error = 'Failed to load nearby users';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty && !_hasActiveFilters()) {
      
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _lastUserId = null;
      _hasMore = true;
      _error = null;
    });

    try {
      // Save recent search
      if (query.isNotEmpty) {
        await _searchService.saveRecentSearch(
          userId: widget.currentUserId,
          searchQuery: query,
        );
        await _loadRecentSearches();
      }

      // Build filters
      _filters = SearchFilters(
        gender: _selectedGender,
        minAge: _ageRange.start.toInt(),
        maxAge: _ageRange.end.toInt(),
        country: _selectedCountry,
        language: _selectedLanguage,
        interests: _selectedInterests.isNotEmpty ? _selectedInterests : null,
        onlineOnly: _onlineOnly ? true : null,
        verifiedOnly: _verifiedOnly ? true : null,
        vipOnly: _vipOnly ? true : null,
        hostsOnly: _hostsOnly ? true : null,
        maxDistanceKm: _maxDistance < 100 ? _maxDistance : null,
        userLocation: widget.currentUser != null &&
                widget.currentUser!.latitude != null &&
                widget.currentUser!.longitude != null
            ? GeoPoint(
                widget.currentUser!.latitude!,
                widget.currentUser!.longitude!,
              )
            : null,
        sortBy: _sortBy,
      );

      SearchResult result;

      if (query.isNotEmpty && !_hasActiveFilters()) {
        // Quick search by name only
        final users = await _searchService.quickSearch(query, limit: 20);
        result = SearchResult(
          users: users,
          hasMore: users.length >= 20,
        );
      } else {
        // Advanced search with filters
        result = await _searchService.searchUsers(
          filters: _filters,
          limit: 20,
        );
      }

      if (mounted) {
        setState(() {
          _searchResults = result.users;
          _hasMore = result.hasMore;
          _lastUserId = result.users.isNotEmpty ? result.users.last.uid : null;
          _isLoading = false;
        });
      }

      
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _error = 'Search failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await _searchService.searchUsers(
        filters: _filters,
        lastUserId: _lastUserId,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults.addAll(result.users);
          _hasMore = result.hasMore;
          _lastUserId = result.users.isNotEmpty ? result.users.last.uid : null;
          _isLoadingMore = false;
        });
      }

      
    } catch (e) {
      
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  bool _hasActiveFilters() {
    return _selectedGender != null ||
        _ageRange.start != 18 ||
        _ageRange.end != 50 ||
        _selectedCountry != null ||
        _selectedLanguage != null ||
        _selectedInterests.isNotEmpty ||
        _onlineOnly ||
        _verifiedOnly ||
        _vipOnly ||
        _hostsOnly ||
        _maxDistance < 100;
  }

  void _clearFilters() {
    setState(() {
      _selectedGender = null;
      _ageRange = const RangeValues(18, 50);
      _selectedCountry = null;
      _selectedLanguage = null;
      _selectedInterests = [];
      _onlineOnly = false;
      _verifiedOnly = false;
      _vipOnly = false;
      _hostsOnly = false;
      _maxDistance = 100;
      _sortBy = SortBy.lastActive;
    });
    
  }

  void _onUserTap(UserModel user) {
    
    Navigator.pushNamed(
      context,
      '/profile',
      arguments: {'userId': user.uid},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_showFilters) _buildFiltersPanel(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(),
                _buildSuggestedTab(),
                _buildNearbyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF16213E),
      elevation: 0,
      title: const Text(
        'Discover',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: _hasActiveFilters(),
            child: const Icon(Icons.tune),
          ),
          onPressed: () {
            setState(() => _showFilters = !_showFilters);
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withAlpha(25),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(128),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withAlpha(128),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.white.withAlpha(128),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE94057), Color(0xFFF27121)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _performSearch,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.search, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Color(0xFFE94057)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gender filter
          _buildFilterSection(
            'Gender',
            Wrap(
              spacing: 8,
              children: _genderOptions.map((gender) {
                final isSelected = _selectedGender == gender;
                return ChoiceChip(
                  label: Text(gender),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE94057),
                  backgroundColor: const Color(0xFF1A1A2E),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedGender = selected ? gender : null;
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // Age range
          _buildFilterSection(
            'Age Range: ${_ageRange.start.toInt()} - ${_ageRange.end.toInt()}',
            RangeSlider(
              values: _ageRange,
              min: 18,
              max: 70,
              divisions: 52,
              activeColor: const Color(0xFFE94057),
              inactiveColor: Colors.white24,
              labels: RangeLabels(
                _ageRange.start.toInt().toString(),
                _ageRange.end.toInt().toString(),
              ),
              onChanged: (values) {
                setState(() => _ageRange = values);
              },
            ),
          ),

          // Country dropdown
          _buildFilterSection(
            'Country',
            _buildDropdown(
              value: _selectedCountry,
              hint: 'Select Country',
              items: _countryOptions,
              onChanged: (value) => setState(() => _selectedCountry = value),
            ),
          ),

          // Language dropdown
          _buildFilterSection(
            'Language',
            _buildDropdown(
              value: _selectedLanguage,
              hint: 'Select Language',
              items: _languageOptions,
              onChanged: (value) => setState(() => _selectedLanguage = value),
            ),
          ),

          // Interests
          _buildFilterSection(
            'Interests',
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      selectedColor: const Color(0xFFE94057),
                      backgroundColor: const Color(0xFF1A1A2E),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Toggle filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToggleChip('Online', _onlineOnly, (v) {
                setState(() => _onlineOnly = v);
              }),
              _buildToggleChip('Verified', _verifiedOnly, (v) {
                setState(() => _verifiedOnly = v);
              }),
              _buildToggleChip('VIP', _vipOnly, (v) {
                setState(() => _vipOnly = v);
              }),
              _buildToggleChip('Hosts', _hostsOnly, (v) {
                setState(() => _hostsOnly = v);
              }),
            ],
          ),

          const SizedBox(height: 12),

          // Distance slider
          _buildFilterSection(
            'Max Distance: ${_maxDistance.toInt()} km',
            Slider(
              value: _maxDistance,
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: const Color(0xFFE94057),
              inactiveColor: Colors.white24,
              label: '${_maxDistance.toInt()} km',
              onChanged: (value) {
                setState(() => _maxDistance = value);
              },
            ),
          ),

          // Sort by
          _buildFilterSection(
            'Sort By',
            _buildSortDropdown(),
          ),

          const SizedBox(height: 12),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _showFilters = false);
                _performSearch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94057),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withAlpha(178),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: Colors.white.withAlpha(128)),
          ),
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Any',
                style: TextStyle(color: Colors.white.withAlpha(128)),
              ),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortBy>(
          value: _sortBy,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          items: SortBy.values.map((sortBy) {
            return DropdownMenuItem<SortBy>(
              value: sortBy,
              child: Text(_getSortByLabel(sortBy)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _sortBy = value);
            }
          },
        ),
      ),
    );
  }

  String _getSortByLabel(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.newest:
        return 'Newest First';
      case SortBy.popular:
        return 'Most Popular';
      case SortBy.level:
        return 'Highest Level';
      case SortBy.lastActive:
        return 'Recently Active';
      case SortBy.distance:
        return 'Nearest First';
    }
  }

  Widget _buildToggleChip(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFE94057),
      backgroundColor: const Color(0xFF1A1A2E),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontSize: 12,
      ),
      onSelected: onChanged,
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF16213E),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFE94057),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(text: 'Search', icon: Icon(Icons.search, size: 20)),
          Tab(text: 'For You', icon: Icon(Icons.favorite, size: 20)),
          Tab(text: 'Nearby', icon: Icon(Icons.location_on, size: 20)),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState(_error!);
    }

    if (_searchResults.isEmpty) {
      if (_searchController.text.isEmpty && !_hasActiveFilters()) {
        return _buildRecentSearches();
      }
      return _buildEmptyState('No users found matching your criteria');
    }

    return _buildUserGrid(_searchResults, showLoadMore: true);
  }

  Widget _buildSuggestedTab() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_suggestedUsers.isEmpty) {
      return _buildEmptyState('No suggestions available yet');
    }

    return _buildUserGrid(_suggestedUsers);
  }

  Widget _buildNearbyTab() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (widget.currentUser?.latitude == null) {
      return _buildEmptyState('Enable location to see nearby users');
    }

    if (_nearbyUsers.isEmpty) {
      return _buildEmptyState('No users found nearby');
    }

    return _buildUserGrid(_nearbyUsers);
  }

  Widget _buildRecentSearches() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _searchService.clearRecentSearches(widget.currentUserId);
                    await _loadRecentSearches();
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Color(0xFFE94057)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                final query = search['searchQuery'] as String? ?? '';
                return ActionChip(
                  label: Text(query),
                  backgroundColor: const Color(0xFF16213E),
                  labelStyle: const TextStyle(color: Colors.white70),
                  avatar: const Icon(
                    Icons.history,
                    color: Colors.white54,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.text = query;
                    _performSearch();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          const Text(
            'Quick Filters',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickFilterGrid(),
        ],
      ),
    );
  }

  Widget _buildQuickFilterGrid() {
    final quickFilters = [
      {'label': 'Online Now', 'icon': Icons.circle, 'color': Colors.green},
      {'label': 'Verified', 'icon': Icons.verified, 'color': Colors.blue},
      {'label': 'VIP Members', 'icon': Icons.star, 'color': Colors.amber},
      {'label': 'Near Me', 'icon': Icons.location_on, 'color': Colors.red},
      {'label': 'New Users', 'icon': Icons.person_add, 'color': Colors.purple},
      {'label': 'Top Hosts', 'icon': Icons.live_tv, 'color': Colors.pink},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: quickFilters.length,
      itemBuilder: (context, index) {
        final filter = quickFilters[index];
        return InkWell(
          onTap: () {
            _applyQuickFilter(filter['label'] as String);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter['icon'] as IconData,
                  color: filter['color'] as Color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  filter['label'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyQuickFilter(String filterName) {
    _clearFilters();

    switch (filterName) {
      case 'Online Now':
        _onlineOnly = true;
        break;
      case 'Verified':
        _verifiedOnly = true;
        break;
      case 'VIP Members':
        _vipOnly = true;
        break;
      case 'Near Me':
        _maxDistance = 25;
        _sortBy = SortBy.distance;
        break;
      case 'New Users':
        _sortBy = SortBy.newest;
        break;
      case 'Top Hosts':
        _hostsOnly = true;
        _sortBy = SortBy.popular;
        break;
    }

    setState(() {});
    _performSearch();
  }

  Widget _buildUserGrid(List<UserModel> users, {bool showLoadMore = false}) {
    return RefreshIndicator(
      onRefresh: () async {
        await _performSearch();
      },
      color: const Color(0xFFE94057),
      child: GridView.builder(
        controller: showLoadMore ? _scrollController : null,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: users.length + (showLoadMore && _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == users.length) {
            return _buildLoadMoreIndicator();
          }
          return _buildUserCard(users[index]);
        },
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return GestureDetector(
      onTap: () => _onUserTap(user),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: user.photoURL != null && user.photoURL!.isNotEmpty
                ? NetworkImage(user.photoURL!)
                : const AssetImage('assets/images/default_avatar.png')
                    as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(204),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Online indicator
              if (user.isOnline)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),

              // Verified badge
              if (user.isVerified && user.gender?.toLowerCase() == 'male')
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),

              // VIP badge
              if (user.isVip == true)
                Positioned(
                  top: (user.isVerified && user.gender?.toLowerCase() == 'male') ? 44 : 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // User info
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.age != null)
                          Text(
                            ', ${user.age}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (user.country != null) ...[
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withAlpha(178),
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              user.country!,
                              style: TextStyle(
                                color: Colors.white.withAlpha(178),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE94057).withAlpha(204),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Lv.${user.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFE94057),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withAlpha(76),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withAlpha(128),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(
              color: Colors.white.withAlpha(128),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94057),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingMore
            ? const CircularProgressIndicator(
                color: Color(0xFFE94057),
                strokeWidth: 2,
              )
            : const SizedBox(),
      ),
    );
  }
}

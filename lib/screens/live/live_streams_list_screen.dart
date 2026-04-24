import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/live_stream_service.dart';
import '../../models/live_stream_model.dart';
import 'live_stream_view_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY LIVE STREAMS DISCOVERY SCREEN ⭐⭐⭐
/// Browse and join active live streams
/// Features: Real-time updates, categories, search, thumbnails
class LiveStreamsListScreen extends StatefulWidget {
  const LiveStreamsListScreen({super.key});

  @override
  State<LiveStreamsListScreen> createState() => _LiveStreamsListScreenState();
}

class _LiveStreamsListScreenState extends State<LiveStreamsListScreen>
    with SingleTickerProviderStateMixin {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  final List<String> _categories = ['All', 'Music', 'Gaming', 'Chatting', 'Dance', 'Talent'];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    final newCategory = _categories[_tabController.index];
    
    
    
    

    setState(() {
      _selectedCategory = newCategory;
    });
  }

  @override
  void dispose() {
    
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 🔍 Filter streams based on category and search
  List<LiveStreamModel> _filterStreams(List<LiveStreamModel> streams) {
    var filtered = streams;

    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((stream) {
        return stream.tags.any((tag) =>
          tag.toLowerCase() == _selectedCategory.toLowerCase());
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((stream) {
        final query = _searchQuery.toLowerCase();
        return stream.title.toLowerCase().contains(query) ||
               stream.hostName.toLowerCase().contains(query) ||
               stream.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    
    return filtered;
  }

  /// 🚀 Navigate to broadcaster screen
  void _startBroadcasting() async {
    

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to start broadcasting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show stream setup dialog
    _showStreamSetupDialog();
  }

  /// 📝 Show stream setup dialog
  void _showStreamSetupDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    List<String> selectedTags = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start Live Stream'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Stream Title*',
                    hintText: 'Enter stream title',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Tell viewers what your stream is about',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // Tags/Categories
                const Text(
                  'Select Categories:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Music', 'Gaming', 'Chatting', 'Dance', 'Talent', 'Other'].map((tag) {
                    final isSelected = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                      selectedColor: const Color(0xFFFF1493).withOpacity(0.3),
                      checkmarkColor: const Color(0xFFFF1493),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a stream title'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                
                
                
                
                

                Navigator.pop(context);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                // 1. Create the stream record
                final streamId = await _liveStreamService.createLiveStream(
                  title: title,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                  tags: selectedTags,
                );

                if (!mounted) return;
                Navigator.pop(context); // Remove loading

                if (streamId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create stream')),
                  );
                  return;
                }

                // 2. Navigate to unified live screen as broadcaster
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveStreamViewScreen(
                      streamId: streamId,
                      isBroadcaster: true,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF1493),
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Broadcasting'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A1A1A),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Title & Go Live Button
                  Row(
                    children: [
                      const Text(
                        'Live Streams',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _startBroadcasting,
                        icon: const Icon(Icons.broadcast_on_home, size: 20),
                        label: const Text('Go Live'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF1493),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search live streams...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Category Tabs
            Container(
              color: const Color(0xFF1A1A1A),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFFF1493),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF1493),
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: _categories.map((category) => Tab(text: category)).toList(),
              ),
            ),

            // Live Streams Grid
            Expanded(
              child: StreamBuilder<List<LiveStreamModel>>(
                stream: _liveStreamService.streamActiveLiveStreams(limit: 50),
                builder: (context, snapshot) {
                  
                  
                  
                  

                  if (snapshot.hasError) {
                    
                    
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    
                    
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF1493),
                      ),
                    );
                  }

                  final allStreams = snapshot.data!;
                  final filteredStreams = _filterStreams(allStreams);

                  
                  
                  

                  if (filteredStreams.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            size: 80,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No streams found matching "$_searchQuery"'
                                : 'No live streams at the moment',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _startBroadcasting,
                            icon: const Icon(Icons.broadcast_on_home),
                            label: const Text('Be the first to go live!'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF1493),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredStreams.length,
                    itemBuilder: (context, index) {
                      final stream = filteredStreams[index];
                      return _buildStreamCard(stream);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamCard(LiveStreamModel stream) {
    return GestureDetector(
      onTap: () {
        
        
        
        
        
        

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveStreamViewScreen(
              streamId: stream.streamId,
              isBroadcaster: false,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Preview
            Expanded(
              child: Stack(
                children: [
                  // Thumbnail Image
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF1493).withOpacity(0.3),
                          const Color(0xFF9B6FD7).withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: stream.thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              stream.thumbnailUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildDefaultThumbnail(),
                            ),
                          )
                        : _buildDefaultThumbnail(),
                  ),

                  // LIVE Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Viewer Count
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stream.viewerCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stream Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: stream.hostPhoto.isNotEmpty
                            ? NetworkImage(stream.hostPhoto)
                            : null,
                        backgroundColor: const Color(0xFFFF1493),
                        child: stream.hostPhoto.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stream.hostName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stream Title
                  Text(
                    stream.title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Tags
                  if (stream.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: stream.tags.take(2).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1493).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Color(0xFFFF1493),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF1493).withOpacity(0.5),
            const Color(0xFF9B6FD7).withOpacity(0.5),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }
}

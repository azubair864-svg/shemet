import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sticker_provider.dart';
import '../../core/constants/app_colors.dart';

class StickerPanel extends StatelessWidget {
  const StickerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                Icon(Icons.emoji_emotions_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Stickers & Effects',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10),

          // Grid
          Expanded(
            child: Consumer<StickerProvider>(
              builder: (context, provider, child) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: provider.stickers.length + 1, // +1 for "None" option
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildNoneOption(context, provider);
                    }
                    final sticker = provider.stickers[index - 1];
                    return _buildStickerItem(context, sticker, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoneOption(BuildContext context, StickerProvider provider) {
    final isSelected = provider.activeSticker == null;
    return GestureDetector(
      onTap: () => provider.setActiveSticker(null),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null,
            ),
            child: const Icon(Icons.not_interested, color: Colors.white54, size: 30),
          ),
          const SizedBox(height: 8),
          const Text(
            'None',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerItem(BuildContext context, Sticker sticker, StickerProvider provider) {
    final isLocked = sticker.requiredLevel > provider.currentUserLevel;
    final isSelected = provider.activeSticker?.id == sticker.id;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _showLockedContentDialog(context, sticker.requiredLevel, provider.currentUserLevel);
        } else {
          provider.setActiveSticker(sticker);
        }
      },
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Thumbnail Container
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                  border: isSelected 
                      ? Border.all(color: AppColors.primary, width: 3) 
                      : Border.all(color: Colors.white10, width: 1),
                  image: DecorationImage(
                    image: AssetImage(sticker.thumbnailAsset),
                    fit: BoxFit.cover,
                    opacity: isLocked ? 0.4 : 1.0,
                    onError: (e, s) {
                       // Fallback incase asset missing
                    }
                  ),
                ),
                // Text Fallback if image fails (for dev)
                child: sticker.thumbnailAsset.contains('assets') ? null : Center(child: Text(sticker.name[0], style: const TextStyle(color: Colors.white))),
              ),

              // Lock Overlay
              if (isLocked)
                Container(
                  height: 64,
                  width: 64,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.lock, color: Colors.white70, size: 24),
                  ),
                ),
                
              // Download Indicator (Mock)
              if (!sticker.isDownloaded && !isLocked)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.arrow_downward, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 4),

          // Label / Level Badge
          if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Lv.${sticker.requiredLevel}',
                style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            )
          else
            Text(
              sticker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white70, 
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
            ),
        ],
      ),
    );
  }

  void _showLockedContentDialog(BuildContext context, int required, int current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Locked Content', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'This sticker requires Level $required.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: current / required,
              backgroundColor: Colors.white10,
              color: Colors.amber,
            ),
            const SizedBox(height: 8),
            Text(
              'You are current Level $current',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Navigate to Level Up screen or Shop
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('How to Level Up', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

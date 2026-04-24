import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/beauty_settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/agora_service.dart';

class BeautyEffectsPanel extends StatefulWidget {
  const BeautyEffectsPanel({super.key});

  @override
  State<BeautyEffectsPanel> createState() => _BeautyEffectsPanelState();
}

class _BeautyEffectsPanelState extends State<BeautyEffectsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _facialCategoryIndex = 0; // 0: Face, 1: Eyes, 2: Nose, 3: Mouth
  final AgoraService _agoraService = AgoraService();
  Timer? _debounceTimer;

  void _applyToAgora(BeautySettingsProvider provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        _performAgoraUpdate(provider);
      }
    });
  }

  void _performAgoraUpdate(BeautySettingsProvider provider) {
    _agoraService.updateAdvancedBeautyEffects(
      // Beauty
      smooth: provider.smooth,
      whiten: provider.whiten,
      sharpen: provider.sharpen,
      clarity: provider.clarity,
      // Color
      temp: provider.colorTemp,
      tone: provider.colorTone,
      saturation: provider.saturation,
      brightness: provider.brightness,
      contrast: provider.contrast,
      // Facial - Face
      faceSlim: provider.faceSlim,
      faceSmall: provider.faceSmall,
      faceNarrow: provider.faceNarrow,
      vFace: provider.vFace,
      headSmall: provider.headSmall,
      cheekbones: provider.cheekbones,
      lowerJaw: provider.lowerJaw,
      chin: provider.chin,
      nasolabial: provider.nasolabial,
      hairline: provider.hairline,
      // Facial - Eyes
      eyeSize: provider.eyeSize,
      eyePupil: provider.eyePupil,
      eyeSpacing: provider.eyeSpacing,
      eyeLightening: provider.eyeLightening,
      darkCircles: provider.darkCircles,
      // Facial - Nose
      noseSize: provider.noseSize,
      noseBridge: provider.noseBridge,
      noseRoot: provider.noseRoot,
      noseWings: provider.noseWings,
      // Facial - Mouth
      lipSize: provider.lipSize,
      mouthWidth: provider.mouthWidth,
      teethWhiten: provider.teethWhiten,
      // Filters
      filterName: provider.activeFilter.name,
      filterIntensity: provider.filterIntensity,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.35, // Reduced to 35%
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35), // Even more transparent
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white10.withOpacity(0.05), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Increased blur
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Stack(
                children: [
                   _buildTabBar(),
                   Positioned(
                     right: 8,
                     top: 0,
                     bottom: 0,
                     child: IconButton(
                       icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                       onPressed: () {
                         final provider = context.read<BeautySettingsProvider>();
                         provider.resetToDefaults();
                         _applyToAgora(provider);
                       },
                     ),
                   ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBeautyTab(),
                    _buildFacialTab(),
                    _buildFiltersTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      tabs: const [
        Tab(text: 'Beauty'),
        Tab(text: 'Facial'),
        Tab(text: 'Filters'),
      ],
    );
  }

  // State for Beauty Tab UI
  String _selectedBeautyParam = 'Smooth';

  Widget _buildBeautyTab() {
    return Consumer<BeautySettingsProvider>(
      builder: (context, provider, child) {
        // Map current selection to value and update function
        double currentValue = 0.0;
        Function(double) updateFunc = (v) {};
        
        switch (_selectedBeautyParam) {
          case 'Smooth': 
            currentValue = provider.smooth;
            updateFunc = provider.updateSmooth; 
            break;
          case 'Whiten': 
            currentValue = provider.whiten;
            updateFunc = provider.updateWhiten; 
            break;
          case 'Sharpen': 
            currentValue = provider.sharpen;
            updateFunc = provider.updateSharpen; 
            break;
          case 'Clarity': 
            currentValue = provider.clarity;
            updateFunc = provider.updateClarity; 
            break;
          case 'Color Temp': 
            currentValue = provider.colorTemp;
            updateFunc = provider.updateColorTemp; 
            break;
          case 'Color Tone': 
            currentValue = provider.colorTone;
            updateFunc = provider.updateColorTone; 
            break;
          case 'Saturation': 
            currentValue = provider.saturation;
            updateFunc = provider.updateSaturation; 
            break;
          case 'Brightness': 
            currentValue = provider.brightness;
            updateFunc = provider.updateBrightness; 
            break;
          case 'Contrast': 
            currentValue = provider.contrast;
            updateFunc = provider.updateContrast; 
            break;
        }

        return Column(
          children: [
             const SizedBox(height: 20),
             
             // 1. Value Indicator & Slider
             Text(
               currentValue.toInt().toString(),
               style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
             ),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20),
               child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFF9C27B0), // Purple from screenshot
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  trackHeight: 4.0,
                  overlayColor: const Color(0xFF9C27B0).withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: currentValue,
                  min: 0,
                  max: 100,
                  onChanged: (val) {
                    updateFunc(val);
                    _applyToAgora(provider);
                  },
                ),
              ),
             ),
             
             const Spacer(),
             
             // 2. Horizontal Scrollable Icons
             SizedBox(
               height: 100,
               child: ListView(
                 scrollDirection: Axis.horizontal,
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 children: [
                   _buildBeautyIcon('Smooth', Icons.blur_on, _selectedBeautyParam == 'Smooth'),
                   _buildBeautyIcon('Whiten', Icons.face, _selectedBeautyParam == 'Whiten'),
                   _buildBeautyIcon('Sharpen', Icons.change_history, _selectedBeautyParam == 'Sharpen'),
                   _buildBeautyIcon('Clarity', Icons.blur_linear, _selectedBeautyParam == 'Clarity'),
                   _buildBeautyIcon('Color Temp', Icons.thermostat, _selectedBeautyParam == 'Color Temp'), // Shortened name
                   _buildBeautyIcon('Color Tone', Icons.invert_colors, _selectedBeautyParam == 'Color Tone'),
                   _buildBeautyIcon('Saturation', Icons.gradient, _selectedBeautyParam == 'Saturation'),
                   _buildBeautyIcon('Brightness', Icons.wb_sunny, _selectedBeautyParam == 'Brightness'),
                   _buildBeautyIcon('Contrast', Icons.contrast, _selectedBeautyParam == 'Contrast'),
                 ],
               ),
             ),
             const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildBeautyIcon(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedBeautyParam = label),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF9C27B0) : Colors.white10,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF9C27B0) : Colors.white60, 
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacialTab() {
    return Consumer<BeautySettingsProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Sub-categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  _buildSubCategoryItem('FACE', 0),
                  _buildSubCategoryItem('EYES', 1),
                  _buildSubCategoryItem('NOSE', 2),
                  _buildSubCategoryItem('MOUTH', 3),
                ],
              ),
            ),
            Expanded(
              child: _buildFacialCategoryContent(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubCategoryItem(String title, int index) {
    final isSelected = _facialCategoryIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _facialCategoryIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white12,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFacialCategoryContent(BeautySettingsProvider provider) {
    final List<Widget> items = [];

    switch (_facialCategoryIndex) {
      case 0: // FACE
        items.addAll([
          _buildSlider('Slim', provider.faceSlim, (v) => provider.updateFaceSlim(v)),
          _buildSlider('Small face', provider.faceSmall, (v) => provider.updateFaceSmall(v)),
          _buildSlider('Narrow', provider.faceNarrow, (v) => provider.updateFaceNarrow(v)),
          _buildSlider('V face', provider.vFace, (v) => provider.updateVFace(v)),
          _buildSlider('Small head', provider.headSmall, (v) => provider.updateHeadSmall(v)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Advanced', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ),
          _buildSlider('Cheekbones', provider.cheekbones, (v) => provider.updateCheekbones(v)),
          _buildSlider('Lower jaw', provider.lowerJaw, (v) => provider.updateLowerJaw(v)),
          _buildSlider('Chin', provider.chin, (v) => provider.updateChin(v)),
          _buildSlider('Nasolabial', provider.nasolabial, (v) => provider.updateNasolabial(v)),
          _buildSlider('Hairline', provider.hairline, (v) => provider.updateHairline(v)),
        ]);
        break;
      case 1: // EYES
        items.addAll([
          _buildSlider('Eye size', provider.eyeSize, (v) => provider.updateEyeSize(v)),
          _buildSlider('Pupil', provider.eyePupil, (v) => provider.updateEyePupil(v)),
          _buildSlider('Eye spacing', provider.eyeSpacing, (v) => provider.updateEyeSpacing(v)),
          _buildSlider('Eye lightening', provider.eyeLightening, (v) => provider.updateEyeLightening(v)),
          _buildSlider('Dark circles', provider.darkCircles, (v) => provider.updateDarkCircles(v)),
        ]);
        break;
      case 2: // NOSE
        items.addAll([
          _buildSlider('Nose size', provider.noseSize, (v) => provider.updateNoseSize(v)),
          _buildSlider('Nasal bridge', provider.noseBridge, (v) => provider.updateNoseBridge(v)),
          _buildSlider('Nasal root', provider.noseRoot, (v) => provider.updateNoseRoot(v)),
          _buildSlider('Nasal wings', provider.noseWings, (v) => provider.updateNoseWings(v)),
        ]);
        break;
      case 3: // MOUTH
        items.addAll([
          _buildSlider('Lip size', provider.lipSize, (v) => provider.updateLipSize(v)),
          _buildSlider('Mouth width', provider.mouthWidth, (v) => provider.updateMouthWidth(v)),
          _buildSlider('Whiten teeth', provider.teethWhiten, (v) => provider.updateTeethWhiten(v)),
        ]);
        break;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: items,
    );
  }

  Widget _buildFiltersTab() {
    return Consumer<BeautySettingsProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            const SizedBox(height: 16),
            _buildSlider('Intensity', provider.filterIntensity, (v) => provider.updateFilterIntensity(v)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: BeautyFilter.values.length,
                itemBuilder: (context, index) {
                  final filter = BeautyFilter.values[index];
                  final isSelected = provider.activeFilter == filter;
                  
                  // Icon Mapping for each filter
                  final Map<BeautyFilter, IconData> iconMap = {
                    BeautyFilter.normal: Icons.block,
                    BeautyFilter.sunny: Icons.face_retouching_natural,
                    BeautyFilter.gray: Icons.sentiment_neutral, // Neon Horns
                    BeautyFilter.warm: Icons.local_fire_department, // Fire
                    BeautyFilter.blue: Icons.theater_comedy, // Mask
                    BeautyFilter.bright: Icons.light_mode,
                    BeautyFilter.cool: Icons.sports_motorsports, // Helmet
                    BeautyFilter.sweet: Icons.local_florist, // Flower
                    BeautyFilter.pure: Icons.favorite, // Hearts
                    BeautyFilter.tender: Icons.flip, // Split view
                    BeautyFilter.galaxy: Icons.nightlight_round,
                    BeautyFilter.mask: Icons.masks,
                    BeautyFilter.emotion: Icons.emoji_emotions,
                    BeautyFilter.humanoid: Icons.face,
                    BeautyFilter.snail: Icons.bug_report,
                    BeautyFilter.pingpong: Icons.sports_tennis,
                    BeautyFilter.fire: Icons.whatshot,
                    BeautyFilter.elephant: Icons.pets,
                    BeautyFilter.exaggerator: Icons.report_problem,
                  };

                  return GestureDetector(
                    onTap: () {
                      provider.updateFilter(filter);
                      _applyToAgora(provider);
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                iconMap[filter] ?? Icons.filter_vintage,
                                color: isSelected ? AppColors.primary : Colors.white70,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          filter.name[0].toUpperCase() + filter.name.substring(1),
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.white70,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                value.toInt().toString(),
                style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              trackHeight: 2.5,
              overlayColor: AppColors.primary.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: (val) {
                onChanged(val);
                _applyToAgora(context.read<BeautySettingsProvider>());
              },
            ),
          ),
        ],
      ),
    );
  }
}

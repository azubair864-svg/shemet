import 'package:flutter/material.dart';

enum BeautyFilter {
  normal,
  sunny,
  gray,
  warm,
  blue,
  bright,
  cool,
  sweet,
  pure,
  tender,
  galaxy,
  mask,
  emotion,
  humanoid,
  snail,
  pingpong,
  fire,
  elephant,
  exaggerator
}

class BeautySettingsProvider with ChangeNotifier {
  // --- TAB 1: BEAUTY ---
  double _smooth = 80.0;
  double _whiten = 0.0;
  double _sharpen = 0.0;
  double _clarity = 0.0;
  
  double _colorTemp = 50.0; // 0-100, 50 is neutral
  double _colorTone = 50.0;
  double _saturation = 50.0;
  double _brightness = 50.0;
  double _contrast = 50.0;

  // --- TAB 2: FACIAL ---
  // FACE
  double _faceSlim = 0.0;
  double _faceSmall = 0.0;
  double _faceNarrow = 0.0;
  double _vFace = 0.0;
  double _headSmall = 0.0;
  double _cheekbones = 0.0;
  double _lowerJaw = 0.0;
  double _chin = 0.0;
  double _nasolabial = 0.0;
  double _hairline = 0.0;

  // EYES
  double _eyeSize = 0.0;
  double _eyePupil = 0.0;
  double _eyeSpacing = 0.0;
  double _eyeLightening = 0.0;
  double _darkCircles = 0.0;

  // NOSE
  double _noseSize = 0.0;
  double _noseBridge = 0.0;
  double _noseRoot = 0.0;
  double _noseWings = 0.0;

  // MOUTH
  double _lipSize = 0.0;
  double _mouthWidth = 0.0;
  double _teethWhiten = 0.0;

  // --- TAB 3: FILTERS ---
  BeautyFilter _activeFilter = BeautyFilter.normal;
  double _filterIntensity = 30.0;

  // Getters Beauty
  double get smooth => _smooth;
  double get whiten => _whiten;
  double get sharpen => _sharpen;
  double get clarity => _clarity;
  double get colorTemp => _colorTemp;
  double get colorTone => _colorTone;
  double get saturation => _saturation;
  double get brightness => _brightness;
  double get contrast => _contrast;

  // Getters Facial - Face
  double get faceSlim => _faceSlim;
  double get faceSmall => _faceSmall;
  double get faceNarrow => _faceNarrow;
  double get vFace => _vFace;
  double get headSmall => _headSmall;
  double get cheekbones => _cheekbones;
  double get lowerJaw => _lowerJaw;
  double get chin => _chin;
  double get nasolabial => _nasolabial;
  double get hairline => _hairline;

  // Getters Facial - Eyes
  double get eyeSize => _eyeSize;
  double get eyePupil => _eyePupil;
  double get eyeSpacing => _eyeSpacing;
  double get eyeLightening => _eyeLightening;
  double get darkCircles => _darkCircles;

  // Getters Facial - Nose
  double get noseSize => _noseSize;
  double get noseBridge => _noseBridge;
  double get noseRoot => _noseRoot;
  double get noseWings => _noseWings;

  // Getters Facial - Mouth
  double get lipSize => _lipSize;
  double get mouthWidth => _mouthWidth;
  double get teethWhiten => _teethWhiten;

  // Getters Filters
  BeautyFilter get activeFilter => _activeFilter;
  double get filterIntensity => _filterIntensity;

  // Setters
  void updateSmooth(double val) { _smooth = val; notifyListeners(); }
  void updateWhiten(double val) { _whiten = val; notifyListeners(); }
  void updateSharpen(double val) { _sharpen = val; notifyListeners(); }
  void updateClarity(double val) { _clarity = val; notifyListeners(); }
  void updateColorTemp(double val) { _colorTemp = val; notifyListeners(); }
  void updateColorTone(double val) { _colorTone = val; notifyListeners(); }
  void updateSaturation(double val) { _saturation = val; notifyListeners(); }
  void updateBrightness(double val) { _brightness = val; notifyListeners(); }
  void updateContrast(double val) { _contrast = val; notifyListeners(); }

  void updateFaceSlim(double val) { _faceSlim = val; notifyListeners(); }
  void updateFaceSmall(double val) { _faceSmall = val; notifyListeners(); }
  void updateFaceNarrow(double val) { _faceNarrow = val; notifyListeners(); }
  void updateVFace(double val) { _vFace = val; notifyListeners(); }
  void updateHeadSmall(double val) { _headSmall = val; notifyListeners(); }
  void updateCheekbones(double val) { _cheekbones = val; notifyListeners(); }
  void updateLowerJaw(double val) { _lowerJaw = val; notifyListeners(); }
  void updateChin(double val) { _chin = val; notifyListeners(); }
  void updateNasolabial(double val) { _nasolabial = val; notifyListeners(); }
  void updateHairline(double val) { _hairline = val; notifyListeners(); }

  void updateEyeSize(double val) { _eyeSize = val; notifyListeners(); }
  void updateEyePupil(double val) { _eyePupil = val; notifyListeners(); }
  void updateEyeSpacing(double val) { _eyeSpacing = val; notifyListeners(); }
  void updateEyeLightening(double val) { _eyeLightening = val; notifyListeners(); }
  void updateDarkCircles(double val) { _darkCircles = val; notifyListeners(); }

  void updateNoseSize(double val) { _noseSize = val; notifyListeners(); }
  void updateNoseBridge(double val) { _noseBridge = val; notifyListeners(); }
  void updateNoseRoot(double val) { _noseRoot = val; notifyListeners(); }
  void updateNoseWings(double val) { _noseWings = val; notifyListeners(); }

  void updateLipSize(double val) { _lipSize = val; notifyListeners(); }
  void updateMouthWidth(double val) { _mouthWidth = val; notifyListeners(); }
  void updateTeethWhiten(double val) { _teethWhiten = val; notifyListeners(); }

  void updateFilter(BeautyFilter filter) { _activeFilter = filter; notifyListeners(); }
  void updateFilterIntensity(double val) { _filterIntensity = val; notifyListeners(); }

  // Global Actions
  void resetToDefaults() {
    _smooth = 80.0;
    _whiten = 0.0;
    _sharpen = 0.0;
    _clarity = 0.0;
    _colorTemp = 50.0;
    _colorTone = 50.0;
    _saturation = 50.0;
    _brightness = 50.0;
    _contrast = 50.0;

    _faceSlim = 0.0;
    _faceSmall = 0.0;
    _faceNarrow = 0.0;
    _vFace = 0.0;
    _headSmall = 0.0;
    _cheekbones = 0.0;
    _lowerJaw = 0.0;
    _chin = 0.0;
    _nasolabial = 0.0;
    _hairline = 0.0;

    _eyeSize = 0.0;
    _eyePupil = 0.0;
    _eyeSpacing = 0.0;
    _eyeLightening = 0.0;
    _darkCircles = 0.0;

    _noseSize = 0.0;
    _noseBridge = 0.0;
    _noseRoot = 0.0;
    _noseWings = 0.0;

    _lipSize = 0.0;
    _mouthWidth = 0.0;
    _teethWhiten = 0.0;

    _activeFilter = BeautyFilter.normal;
    _filterIntensity = 30.0;
    
    notifyListeners();
  }
}

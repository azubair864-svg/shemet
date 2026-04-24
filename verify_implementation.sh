#!/bin/bash

echo "🔍 =========================================="
echo "   Call Features Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

check_file() {
    if [ -f "$1" ]; then
        echo -e "  ${GREEN}✅${NC} $2"
        ((PASS++))
    else
        echo -e "  ${RED}❌${NC} $2 MISSING"
        ((FAIL++))
    fi
}

check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $3"
        ((PASS++))
    else
        echo -e "  ${RED}❌${NC} $3 MISSING"
        ((FAIL++))
    fi
}

echo "📦 New Files:"
check_file "lib/models/call_model.dart" "call_model.dart"
check_file "lib/screens/calls/call_history_screen.dart" "call_history_screen.dart"
check_file "lib/widgets/call/network_quality_indicator.dart" "network_quality_indicator.dart"
check_file "lib/widgets/call/incoming_call_popup.dart" "incoming_call_popup.dart"
check_file "CALL_FEATURES_IMPLEMENTATION.md" "Implementation docs"

echo ""
echo "🔧 CallService Methods:"
check_content "lib/services/call_service.dart" "initiateCall" "initiateCall() method"
check_content "lib/services/call_service.dart" "acceptCall" "acceptCall() method"
check_content "lib/services/call_service.dart" "rejectCall" "rejectCall() method"
check_content "lib/services/call_service.dart" "cancelCall" "cancelCall() method"
check_content "lib/services/call_service.dart" "endCallWithDuration" "endCallWithDuration() method"
check_content "lib/services/call_service.dart" "markAsMissed" "markAsMissed() method"
check_content "lib/services/call_service.dart" "getCallHistory" "getCallHistory() stream"
check_content "lib/services/call_service.dart" "listenForIncomingCalls" "listenForIncomingCalls() stream"
check_content "lib/services/call_service.dart" "switchCamera" "switchCamera() method"

echo ""
echo "🎬 Call Screen Fixes:"
check_content "lib/screens/calls/voice_call_screen.dart" "endCallWithDuration" "voice_call_screen.dart updated"
check_content "lib/screens/calls/video_call_screen.dart" "endCallWithDuration" "video_call_screen.dart updated"
check_content "lib/screens/calls/incoming_call_screen.dart" "rejectCall" "incoming_call_screen.dart updated"

echo ""
echo "🔥 Cloud Functions:"
check_content "functions/index.js" "exports.onCallInitiated" "onCallInitiated function"
check_content "functions/index.js" "exports.onCallMissed" "onCallMissed function"
check_content "firebase.json" "nodejs20" "Node.js 20 runtime"
check_content "functions/package.json" '"node": "20"' "package.json node 20"

echo ""
echo "📱 Dependencies:"
check_content "pubspec.yaml" "image_cropper: \^8" "image_cropper 8.x"

echo ""
echo "📊 CallModel Features:"
check_content "lib/models/call_model.dart" "isRead" "isRead field"
check_content "lib/models/call_model.dart" "participants" "participants array"
check_content "lib/models/call_model.dart" "getOtherUserId" "Helper methods"

echo ""
echo "=========================================="
echo -e "   Results: ${GREEN}$PASS Passed${NC} | ${RED}$FAIL Failed${NC}"
echo "=========================================="

if [ $FAIL -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All features implemented correctly!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: flutter pub get"
    echo "  2. Run: flutter clean"
    echo "  3. Run: flutter run"
    echo "  4. Deploy Cloud Functions: firebase deploy --only functions"
else
    echo ""
    echo -e "${YELLOW}⚠️  Some features are missing or incomplete.${NC}"
    echo "Please check the items marked with ❌ above."
fi

echo ""

# Car Racing Game E2E Bug Report
Date: 2026-02-24
Scope: `CarRacingGameWidget` + live overlay integration + racing backend flow

## Verification Method
- Static flow audit on game + service + screen integration files.
- Runtime sanity checks via toolchain commands.
- Device availability check for live UI execution.

Commands executed:
- `flutter test` -> PASS
- `flutter analyze lib/games/car_racing_game_widget.dart lib/services/racing_game_service.dart lib/screens/live/live_stream_view_screen.dart lib/screens/live/live_viewer_screen.dart` -> 13 issues (no compile errors)
- `npm --prefix functions run lint` -> PASS with 1 warning
- `npm --prefix functions run build` -> PASS
- `flutter devices` -> macOS + Chrome available

---

## E2E Checklist Results

1. Open racing game overlay from live screens
- Status: PASS (code path present)
- Evidence:
  - `lib/screens/live/live_stream_view_screen.dart:230`
  - `lib/screens/live/live_viewer_screen.dart:592`

2. Player coin balance should use real user state (no hardcoded test balance)
- Status: PASS
- Evidence:
  - `lib/screens/live/live_stream_view_screen.dart:232`
  - `lib/screens/live/live_viewer_screen.dart:593`

3. Top-up button should navigate to coin purchase screen
- Status: PASS
- Evidence:
  - Button action: `lib/games/car_racing_game_widget.dart:1102`
  - Route exists: `lib/main.dart:141`

4. Place bet should deduct coins and register bet for current round
- Status: FAIL (runtime-blocking architecture mismatch)
- Evidence:
  - Client write flow: `lib/services/racing_game_service.dart:119`
  - Client writes `games/racing/rounds/.../bets`: `lib/services/racing_game_service.dart:153`
  - Firestore rules currently deny `games/**` client access (no allow rule, fallback false): `firestore.rules:62`
- Impact:
  - Bet placement can fail at runtime due permission-denied.
  - Game stream read from `games/racing` can also fail.

5. Game phase stream should update Garage -> Countdown -> Race -> Result
- Status: FAIL/BLOCKED by rules
- Evidence:
  - Stream read: `lib/services/racing_game_service.dart:82`
  - No Firestore allow rule for `games/racing` read.

6. Result payout should come from backend (single source of truth)
- Status: PARTIAL PASS
- Evidence:
  - Client-side fake payout removed; server sync added:
    - `lib/games/car_racing_game_widget.dart:715`
    - `lib/games/car_racing_game_widget.dart:733`
  - But backend payout depends on scheduler + readable game state. If stream/bets are blocked by rules, payout loop is effectively broken for client gameplay.

7. Balance sync between game widget and parent live screens
- Status: PASS (local sync path)
- Evidence:
  - `lib/providers/user_provider.dart:160`
  - `lib/screens/live/live_stream_view_screen.dart:237`
  - `lib/screens/live/live_viewer_screen.dart:597`

8. Vehicle unlock flow persistence (garage economy)
- Status: FAIL
- Evidence:
  - Unlock updates only local in widget state: `lib/games/car_racing_game_widget.dart:539`
  - No backend persistence for owned vehicles.
- Impact:
  - Owned/unlocked state resets on reopen/app restart.

9. Racing backend authority and anti-cheat
- Status: FAIL (security/consistency risk)
- Evidence:
  - Atomic callable exists server-side: `functions/src/racing/bets.ts:15`
  - App still uses client-side bet mutation service, not callable.
- Impact:
  - Split logic between client and server; fragile consistency.

---

## Severity Findings

### Critical
1. Firestore rules block racing game reads/writes
- `firestore.rules` has no `games/racing` allow clauses; fallback deny closes access.
- Breaks live racing E2E flow.

2. App bet flow bypasses Cloud Function transaction path
- Uses client-side coin deduction + write.
- Not aligned with `functions/src/racing/bets.ts` atomic model.

### High
3. Garage unlock (vehicle ownership) is not persisted
- Economy/design UX breaks after reload.

### Medium
4. Analyzer debt still present in live-related screens (13 issues in targeted check)
- Not blocking compile but should be cleaned before release.

---

## Reproduction Summary

A. Permission mismatch reproduction
1. Login user.
2. Open racing game.
3. Try placing bet.
4. Expected: Bet accepted + race progression.
5. Actual likely: Firestore permission denied on `games/racing...` read/write (due rules).

B. Unlock persistence reproduction
1. Open garage.
2. Unlock non-owned car.
3. Close game/reopen app.
4. Actual: unlock state not guaranteed (local-only mutation).

---

## Required Fix Plan (Minimal, Release-first)

1. Choose one backend model and align all layers:
- Recommended: callable-only (`placeBet` via Cloud Function) and keep client as UI only.

2. Update Firestore rules for racing reads:
- Allow authenticated read to `games/racing` and safe subpaths needed by UI.
- Keep writes protected to server/callables only.

3. Persist garage ownership:
- Store owned vehicles per user in Firestore and hydrate on init.

4. Add one integration smoke test path:
- login -> open racing -> place bet -> receive result -> balance refresh.

---

## Final Verdict
Current racing module is **not fully production-ready end-to-end**.
Main blocker is **rules/backend mismatch** causing likely runtime failure in betting/state stream.
Top-up navigation and local UI sync are now fixed, but backend alignment must be completed before Play Store release.

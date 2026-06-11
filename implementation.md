# DengueLens — Gap Analysis & Implementation Plan

Based on a full codebase review against your research objectives. Items are ordered by priority.

---

## What's Already Working ✅

| Feature | Status | Files |
|---|---|---|
| Two-stage ML pipeline (YOLOv8n + MobileNetV3) | ✅ Done | `tflite_service.dart` |
| Camera capture + gallery upload | ✅ Done | `dengue_lens_home.dart` |
| Bounding-box detection overlay | ✅ Done | `result_screen.dart` |
| 3-class severity classification (High/Moderate/Non-vector) | ✅ Done | `prediction_result.dart` |
| Symptom questionnaire (8 WHO symptoms) | ✅ Done | `symptom_questionnaire_screen.dart` |
| Symptom risk scoring (Low/Moderate/High/Critical) | ✅ Done | `symptom_result_screen.dart` |
| WHO-aligned home-care guidance per risk tier | ✅ Done | `symptom_result_screen.dart` |
| Scan history persistence (Hive) | ✅ Done | `history_service.dart` |
| History screen with scan cards | ✅ Done | `dengue_lens_history.dart` |
| Point-map sighting screen (flutter_map) | ✅ Done | `point_map_screen.dart` |

---

## Bugs to Fix First 🔴

### BUG-1 — History view shows "0 Mosquitoes Detected"
**Root cause:** When opening a scan from history, `ResultScreen` receives `mosquitoType` as a string but `detections` is `null`. The count badge falls back to 0.

**Fix:** The fallback logic was partially added (`_hasNamedMosquito`) but the history screen still passes no `detections`. The correct fix is to **also store and restore the detection count** (`detectionCount: int`) in `ScanRecord` so history view can show the real number.

- [ ] Add `detectionCount` field to `ScanRecord` model + `toJson`/`fromJson`
- [ ] Populate `detectionCount` when calling `_recordResult()` in `result_screen.dart`
- [ ] Pass `detectionCount` when opening from history and use it as the fallback count

### BUG-2 — Point map uses hardcoded mock data
The map shows 5 hardcoded sightings in Kuala Lumpur. It is not connected to actual scan history.

- [ ] Connect real scan records (aegypti/albopictus) from `HistoryService` to the map
- [ ] Use a placeholder/device location instead of a hardcoded lat/lng

### BUG-3 — "Read More" on Health Tips card does nothing
`HealthTipCard` has `onReadMore: () {}` (TODO stub).

- [ ] Implement a simple bottom sheet or modal with expanded health tip content

### BUG-4 — Navigation bar index mismatch in history screen
`DengueLensHistory` nav bar has 5 destinations but index 2 navigates to `PointMapScreen` while the home screen maps index 2 to `PointMapScreen` too. The nav bar `selectedIndex` is hardcoded to 1 and `index == 2` in history goes to `PointMapScreen` (correct) but `index == 3` goes to Risk Assessment — these are consistent. However the FAB `onPressed: () {}` in history is a stub.

- [ ] Wire up the FAB in history to open camera for a new scan

---

## Objective 1.1 — Two-stage Pipeline (Partially Complete) 🟡

The pipeline itself is solid. Gaps are in how results are surfaced to the user:

### TASK-1.1.A — "Non-Vector" class should still show the detected species name
Currently if Culex is detected, the banner says "Not a Dengue Vector" but the **species name (Culex sp.) is not prominently shown** in the main banner — only in the detection card below. Users are confused (as you reported).

- [ ] Add the detected species name as a subtitle under the "Not a Dengue Vector" banner headline
- [ ] Make it clear: "Culex sp. detected — Not a dengue vector"

### TASK-1.1.B — Anopheles is classified but its risk label is missing context
`Detection.riskLevel` returns `'none'` for Anopheles and Culex, but Anopheles is the malaria vector. The UI treats it identically to Culex.

- [ ] Add an informational note for Anopheles: "Malaria vector — not a dengue risk"

---

## Objective 1.2 — Symptom Assessment Module 🟡

Core flow is implemented. Missing items:

### TASK-1.2.A — Disclaimer is only shown on demand (info button)
The disclaimer "This tool is for education only" is hidden behind an info icon. WHO guidelines recommend it be **always visible**.

- [x] Move the disclaimer to a small persistent banner at the top of the result screen

### TASK-1.2.B — Symptom assessment is not linked back to scan records properly
When triggered from a dengue vector scan result (`ResultScreen → bottom sheet → SymptomQuestionnaireScreen`), the symptom result is saved as a **separate** record in history with no link to the original scan.

- [ ] Pass the original `scanRecordId` (or `mosquitoType` + `imagePath`) through the questionnaire flow
- [ ] In history, if a record has `symptoms` populated, show a small symptoms badge on the scan card

### TASK-1.2.C — "No symptoms" path saves a record with 0/8 which looks misleading
When a user selects "I don't experience any symptoms" it saves `totalSymptoms: 1` (hardcoded), making the history confidence show 0/1 = 0%.

- [x] Fix: when `_noSymptoms` is true, save `symptomCount: 0, totalSymptoms: 8`

---

## Objective 1.3 — Geospatial Map + Privacy + Educational Library 🔴

This objective is mostly **not yet implemented**:

### TASK-1.3.A — Real GPS location for the map (Opt-in)
The map uses a hardcoded coordinate (`LatLng(3.1390, 101.6869)` — KL). There is no actual device GPS integration.

- [ ] Add `geolocator` package to `pubspec.yaml`
- [ ] Create a `LocationService` that requests permission and returns the current position
- [ ] Show an opt-in permission dialog before accessing GPS
- [ ] Use real position as the map center; fall back to a default if denied

### TASK-1.3.B — Obfuscated location sharing (privacy architecture)
The research objective requires **location obfuscation** (fuzzing coordinates to ~100m radius) before any sharing.

- [ ] Implement coordinate fuzzing: add random offset ±0.001° (~100m) before storing location
- [ ] Add a privacy notice explaining what is and isn't stored

### TASK-1.3.C — Offline-first / No registration / Encrypted local storage
Currently Hive is used without encryption.

- [ ] Add `hive` encryption key using `flutter_secure_storage`
- [ ] Confirm no network calls are made (currently satisfied — app is fully offline)
- [ ] Add a one-time onboarding privacy notice screen on first launch

### TASK-1.3.D — Connect real scan sightings to the map
Map shows hardcoded mock sightings only.

- [ ] When a scan records a dengue vector (aegypti or albopictus) with location, add it as a `Sighting` to the map
- [ ] `ScanRecord` already has a `location: String?` field — parse it to `LatLng` for display

### TASK-1.3.E — Educational Library
The `Info` screen only shows one tile (Sighting heatmap) and an "About" blurb. There is **no educational library** about dengue, mosquito species, or prevention.

- [x] Build an `EducationalLibraryScreen` with sections:
  - Mosquito species guide (Aedes aegypti, Aedes albopictus, Culex, Anopheles)
  - Dengue fever overview (symptoms, severity stages)
  - Prevention guidelines (WHO-aligned)
- [x] Add it as a second tile in the Info screen

---

## Objective 2 — Model Performance Metrics Display 🟡

The research requires documenting Accuracy, Precision, Recall, F1-Score of the YOLOv8 model. These are offline metrics but the app could surface them for transparency.

### TASK-2.A — Model performance info card
- [ ] Add a "Model Information" section in the Info screen showing:
  - Model: YOLOv8 Nano (detector) + MobileNetV3 Small (classifier)
  - Classes: Aedes aegypti, Aedes albopictus, Culex, Anopheles, Non-mosquito
  - Input size: 640×640 (detector), 224×224 (classifier)
  - Placeholder accuracy metrics (fill in once you have your test results)

---

## Objective 3 — ISO/IEC 25010 Quality (Non-functional) 🟡

### TASK-3.A — Functional Suitability: Loading indicator during inference
There is no loading state while the model runs inference. The UI freezes silently.

- [ ] Add a `CircularProgressIndicator` / loading overlay during camera/gallery inference in `dengue_lens_home.dart`

### TASK-3.B — Performance Efficiency: Inference on background isolate
Currently `TfliteService.predict()` runs on the main thread, which can cause jank.

- [ ] Move inference to a `compute()` isolate or `Isolate.run()` call

### TASK-3.C — Interaction Capability: Accessibility
- [ ] Add `Semantics` labels to all icon buttons
- [ ] Ensure sufficient color contrast ratios (the `#00FF00` green fails WCAG AA)
- [ ] Replace `Color(0xFF00FF00)` with `Color(0xFF2ECC71)` everywhere in history screen

### TASK-3.D — Reliability: Error handling for missing/deleted image files
When a scan record's image file is deleted (e.g., user cleared storage), the history card crashes with a broken image. `result_screen.dart` already handles this with `errorBuilder` but history card's `Image.file` also needs it (it has one — ✅ confirmed).

- [ ] Verify that the `ResultScreen` opened from history gracefully handles a missing `imagePath`

---

## Recommended Implementation Order

```
Phase 1 — Bug Fixes (do these now, they affect demo quality)
  BUG-1  → History shows 0 mosquitoes
  BUG-2  → Map uses mock data
  BUG-3  → Read More stub
  TASK-1.1.A → Show species name in non-vector banner
  TASK-3.A → Add loading indicator

Phase 2 — Core Missing Features
  TASK-1.3.A → Real GPS (opt-in)
  TASK-1.3.B → Coordinate obfuscation
  TASK-1.3.C → Encrypted storage + privacy onboarding
  TASK-1.3.D → Connect scans to map
  TASK-1.2.B → Link symptom results to scan records

Phase 3 — Educational & Polish
  TASK-1.3.E → Educational Library screen
  TASK-2.A → Model info card
  TASK-1.2.A → Persistent disclaimer
  TASK-3.B → Inference on background isolate
  TASK-3.C → Accessibility / color contrast fix
```

---

> [!IMPORTANT]
> The most critical missing objective for your thesis defense is **Objective 1.3 (geospatial + privacy)**. The map currently uses hardcoded Malaysian coordinates and mock sightings — this needs to be replaced with real opt-in GPS before the system can be evaluated.

> [!WARNING]
> The `#00FF00` (pure lime green) used in the History screen FAB and filter chip fails WCAG AA contrast. Replace with `#2ECC71` for consistency and accessibility compliance.

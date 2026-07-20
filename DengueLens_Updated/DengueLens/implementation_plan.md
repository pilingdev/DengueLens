# Study and Debugging Plan for DengueLens

## Goal Description
Provide a structured, step‑by‑step guide for the team to **learn the codebase**, understand each component's responsibilities, and acquire the skills needed to **debug efficiently**.

---

## User Review Required
> [!NOTE]
> This document is informational only; no code changes are required. Review the plan and let the team know if any sections need adjustment (e.g., additional focus on UI layers or testing).

---

## Open Questions
> [!WARNING]
> - Are there any specific modules (e.g., analytics, platform integration) that the team needs deeper coverage?
> - Do you prefer a workshop style (live walkthrough) or an asynchronous study guide?

---

## Proposed Study Steps
### 1. Project Overview
1. Open the repository root `e:\UI\DengueLens_Updated\DengueLens`.
2. Identify the main Flutter entry point (`lib/main.dart`).
3. Map the high‑level architecture:
   - **UI Layer** (`lib/widgets/`, `lib/screens/`)
   - **Service Layer** (`lib/services/`)
   - **Model Layer** (`lib/models/`)
   - **Utilities & Helpers** (`lib/utils/`)
4. Review `pubspec.yaml` to understand dependencies and platform targets.

### 2. Service Layer Deep Dive
Focus on the three services you already have open:
- **connectivity_service.dart** – monitors network status.
- **sighting_feed_service.dart** – fetches dengue sighting data from the backend.
- **sighting_upload_service.dart** – uploads user‑generated sightings.

For each service:
1. Read the class definition and constructor.
2. List all public methods and their responsibilities.
3. Trace each method’s flow:
   - Identify external calls (e.g., HTTP requests via `http` package).
   - Note any stream or `Future` usage.
   - Highlight error handling and logging statements.
4. Locate corresponding unit tests in `test/services/` (if they exist) and run them (`flutter test`).
5. Document **key invariants** (e.g., "Connectivity must be `online` before a feed fetch proceeds").

### 3. Model Layer Inspection
1. Open `lib/models/` directory. Identify data classes like `Sighting`, `Location`, `UserProfile`.
2. For each model:
   - Review `fromJson` / `toJson` implementations.
   - Check for `Equatable` or `copyWith` usage.
   - Verify that nullable fields are correctly handled.
3. Create a small snippet (in a DartPad or a temporary `main.dart`) that **instantiates each model** and prints JSON round‑trip results – this validates serialization logic.

### 4. UI Layer Context
1. Locate the main screens (`HomeScreen`, `SightingDetailScreen`).
2. Identify where services are injected (e.g., via `Provider`, `GetIt`, or `Riverpod`).
3. Map UI actions to service calls:
   - Pull‑to‑refresh → `SightingFeedService.getFeed()`.
   - Submit button → `SightingUploadService.upload()`.
4. Run the app on an emulator (`flutter run`) and use **Flutter DevTools** to monitor network calls and widget rebuilds.

### 5. Debugging Toolkit Setup
- **IDE configuration**: Ensure each teammate has the Flutter plugin for VS Code / Android Studio.
- **Breakpoints**: Place breakpoints in each service method and in the UI that calls them.
- **Logging**: Verify that `log()` statements are present; if not, add temporary `print()` statements.
- **Network inspection**: Use the **Flutter DevTools Network tab** or a proxy (e.g., Charles) to view request/response payloads.
- **Unit/Integration tests**: Run `flutter test` and `flutter drive` to reproduce bugs automatically.

### 6. Common Debug Scenarios & Checklist
| Scenario | Steps to Reproduce | Debug Checklist |
|----------|-------------------|-----------------|
| No internet connectivity | Turn off Wi‑Fi / enable airplane mode | 1️⃣ Verify `ConnectivityService.isOnline` flag. 2️⃣ Ensure UI shows offline banner. |
| API returns error 500 | Mock server to return 500 using `http_mock_adapter` | 1️⃣ Check `try/catch` in service. 2️⃣ Confirm error is propagated to UI. |
| JSON parsing crash | Provide malformed JSON payload | 1️⃣ Validate `fromJson` null checks. 2️⃣ Add unit test for malformed data. |
| UI freeze on pull‑to‑refresh | Slow network simulation | 1️⃣ Profile UI thread in DevTools. 2️⃣ Ensure `await` is used correctly. |

### 7. Knowledge Transfer Session
1. Schedule a **30‑minute walkthrough** where each teammate presents one of the three services.
2. Use a shared Google Doc to capture Q&A and edge‑case notes.
3. Record the session (screen capture) and store it in the project `docs/` folder for future reference.

---

## Verification Plan
- **Self‑assessment**: Each teammate writes a short summary (max 200 words) of what they learned and lists at least two potential bugs they can now locate.
- **Peer review**: Pair‑program a simple bug (e.g., force a network error) and confirm they can step through the code and fix it.
- **Documentation**: Commit the study guide (`docs/study_guide.md`) to the repository for onboarding new members.

---

*End of plan.*

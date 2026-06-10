# Integration Plan: Online Geolocation Dengue Vector Map

## Goal Description
Integrate an online, real-time geolocation map where users can view Dengue vectors (e.g., Aedes aegypti, Aedes albopictus) scanned and uploaded by other users. This requires transitioning from local-only storage to a cloud-based database capable of geospatial queries.

## Recommended Database & Tools
For a Flutter application requiring geospatial queries (finding points near a user's location on a map), here are the top two recommendations:

### Option A: Firebase Cloud Firestore + GeoFlutterFire (Recommended for Speed & Ease)
- **Database:** Firebase Cloud Firestore (NoSQL cloud database).
- **Geospatial Tool:** `geoflutterfire_plus` package (uses Geohashes to quickly query locations within a specific radius).
- **Pros:** Extremely easy to integrate with Flutter, built-in offline support (caches data when connection is lost and syncs when back online), real-time listeners (the map updates automatically when a new scan is added anywhere in the world).
- **Cons:** Complex queries (e.g., filtering by date AND radius AND vector type simultaneously) can be tricky due to NoSQL limitations.

### Option B: Supabase (PostgreSQL) + PostGIS (Recommended for Powerful Queries)
- **Database:** Supabase (Open-source Firebase alternative powered by PostgreSQL).
- **Geospatial Tool:** PostGIS extension for PostgreSQL.
- **Pros:** Incredibly powerful spatial queries (using standard SQL like `ST_DWithin`), highly scalable relational data model.
- **Cons:** Slightly steeper learning curve if you are unfamiliar with SQL/PostgreSQL.

*We will base the proposed changes below on **Option A (Firebase)** due to its seamless Flutter integration and real-time syncing, which is perfect for live maps. However, the architecture applies similarly if you choose Supabase.*

## User Review Required

> [!IMPORTANT]
> **Database Choice:** Please confirm if you want to proceed with **Firebase** or **Supabase**. 
> **Privacy:** Do we need to anonymize user data? (e.g., showing the vector location on the map without showing *who* scanned it).
> **Permissions:** We will need to request high-accuracy location permissions from the user when they make a scan.

## Open Questions

> [!WARNING]
> 1. Do you already have a Firebase or Supabase project created, or do you need me to provide instructions to set one up?
> 2. Should local scans be kept private by default, with an "upload to public map" opt-in button, or should all vector detections automatically upload to the public map?

---

## Proposed Changes

### 1. Project Configuration
Add necessary dependencies to `pubspec.yaml` for database and location services.
- `firebase_core`, `cloud_firestore` (or `supabase_flutter`)
- `geolocator` (for getting the user's current GPS coordinates)
- `geoflutterfire_plus` (for spatial queries)

### 2. Update Data Models
We need to update our local models so they can serialize to cloud documents effectively.

#### [MODIFY] `lib/models/scan_record.dart`
- Add `latitude` and `longitude` fields.
- Add a `geohash` field (required for fast Firebase spatial queries).
- Update `toJson` and `fromJson` to handle cloud timestamp formats and GeoPoints.

### 3. Cloud Services layer
Create a new service dedicated to interacting with the remote database.

#### [NEW] `lib/services/cloud_service.dart`
- **`uploadSighting(ScanRecord record)`**: Saves a new vector scan to the cloud database, generating the geohash automatically based on the user's coordinates.
- **`streamSightings(double lat, double lng, double radiusInKm)`**: Returns a real-time stream of sightings within the specified radius. 

### 4. UI: Map Integration
Update the existing map screen to stream data from the cloud instead of just local dummy data.

#### [MODIFY] `lib/Screens/point_map_screen.dart`
- Call `cloud_service.streamSightings(...)` around the user's current location.
- Listen to the stream and dynamically add/remove map markers.
- Implement clustering or custom markers (e.g., red marker for high-risk vectors, yellow for moderate).

## Verification Plan

### Automated Tests
- N/A (UI and Cloud-heavy integration is best verified manually).

### Manual Verification
1. Open the app on Device A and perform a scan of a vector. 
2. Ensure location permissions are granted, and verify the scan successfully uploads to the cloud database with correct coordinates.
3. Open the app on Device B. Navigate to the Map Screen.
4. Verify Device B immediately sees the marker from Device A's scan if they are within the queried radius.

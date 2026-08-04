import time
import math
import random
import tracemalloc
from typing import List, Tuple, Dict

# --- 1. MOCK DATA & ENTITIES ---
class Sighting:
    def __init__(self, id: int, lat: float, lng: float):
        self.id = id
        self.lat = lat
        self.lng = lng

def generate_synthetic_data(num_points: int, bounds: Tuple[float, float, float, float]) -> List[Sighting]:
    """Generates synthetic sightings within (min_lat, max_lat, min_lng, max_lng)."""
    min_lat, max_lat, min_lng, max_lng = bounds
    return [
        Sighting(
            i, 
            random.uniform(min_lat, max_lat), 
            random.uniform(min_lng, max_lng)
        )
        for i in range(num_points)
    ]

# --- 2. UTILS ---
def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great circle distance in meters between two points."""
    R = 6371000 # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2.0)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

# --- 3. ALGORITHMS ---

class BaseGeoAlgorithm:
    def name(self) -> str:
        raise NotImplementedError
        
    def setup(self, data: List[Sighting]):
        """Index or prepare the dataset (simulating backend DB injection)."""
        pass
        
    def query(self, center_lat: float, center_lng: float, radius_m: float) -> Tuple[List[Sighting], int]:
        """Returns filtered sightings and the number of bytes 'transferred' (simulated)."""
        raise NotImplementedError

class CurrentBoundingBoxAlgo(BaseGeoAlgorithm):
    def name(self): return "Current (Bounding Box + Haversine)"
    
    def setup(self, data: List[Sighting]):
        # Simulate database index sorted by latitude
        self.db_table = sorted(data, key=lambda s: s.lat)

    def query(self, center_lat: float, center_lng: float, radius_m: float):
        # 1. DB Layer (Bounding Box approximation)
        lat_delta = radius_m / 111320.0
        min_lat, max_lat = center_lat - lat_delta, center_lat + lat_delta
        
        # Simulating Firestore latitude range query
        fetched_points = [s for s in self.db_table if min_lat <= s.lat <= max_lat]
        payload_bytes = len(fetched_points) * 128 # Assume 128 bytes per Sighting JSON
        
        # 2. Client Layer (Longitude filter + Haversine)
        valid_points = []
        lng_delta = radius_m / (111320.0 * math.cos(math.radians(center_lat)))
        min_lng, max_lng = center_lng - lng_delta, center_lng + lng_delta
        
        for s in fetched_points:
            if min_lng <= s.lng <= max_lng:
                dist = haversine(center_lat, center_lng, s.lat, s.lng)
                if dist <= radius_m:
                    valid_points.append(s)
                    
        return valid_points, payload_bytes

class GeohashAlgo(BaseGeoAlgorithm):
    def name(self): return "Alternative (Geohash Indexing)"
    def setup(self, data: List[Sighting]):
        # TODO: Implement python-geohash encoding for self.db_table
        self.db_table = data
        
    def query(self, center_lat: float, center_lng: float, radius_m: float):
        # TODO: Implement geohash bounding box queries and client-side pruning
        # For boilerplate, falling back to brute force for accurate results comparison
        valid_points = [s for s in self.db_table if haversine(center_lat, center_lng, s.lat, s.lng) <= radius_m]
        payload_bytes = len(valid_points) * 128 # Ideal scenario payload
        return valid_points, payload_bytes

# --- 4. BENCHMARKING ENGINE ---

def run_benchmarks():
    dataset_size = 50000
    bounds = (1.2, 1.5, 103.6, 104.0) # Approx Singapore bounds for Dengue sightings
    print(f"Generating {dataset_size} synthetic points...")
    dataset = generate_synthetic_data(dataset_size, bounds)
    
    test_queries = [
        {"center": (1.35, 103.8), "radius": 100},   # 100m radius
        {"center": (1.35, 103.8), "radius": 1000},  # 1km radius
    ]
    
    algorithms = [CurrentBoundingBoxAlgo(), GeohashAlgo()]
    
    print("\n--- Starting Benchmarks ---\n")
    for algo in algorithms:
        print(f"Algorithm: {algo.name()}")
        # Setup (Indexing)
        algo.setup(dataset)
        
        for q in test_queries:
            lat, lng = q['center']
            radius = q['radius']
            
            # Start profilings
            tracemalloc.start()
            start_time = time.perf_counter()
            
            results, payload_size = algo.query(lat, lng, radius)
            
            # End profiling
            exec_time_ms = (time.perf_counter() - start_time) * 1000
            current_mem, peak_mem = tracemalloc.get_traced_memory()
            tracemalloc.stop()
            
            print(f"  Radius {radius}m -> "
                  f"Found: {len(results)} points | "
                  f"Time: {exec_time_ms:.2f} ms | "
                  f"Payload: {payload_size / 1024:.2f} KB | "
                  f"Peak Mem: {peak_mem / 1024 / 1024:.3f} MB")
        print("-" * 40)

if __name__ == "__main__":
    run_benchmarks()


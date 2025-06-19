import ray
import time
import numpy as np
from ray.util.metrics import Counter, Histogram

# Initialize Ray
ray.init(address="auto")

# Define metrics
task_counter = Counter("sample_app_tasks_completed", "Number of tasks completed")
task_latency = Histogram("sample_app_task_latency", "Task execution time in seconds")

@ray.remote
def process_data(data_chunk):
    """Process a chunk of data with simulated work."""
    start_time = time.time()
    
    # Simulate some computation
    result = np.mean(data_chunk) * np.std(data_chunk)
    time.sleep(0.1)  # Simulate work
    
    # Record metrics
    task_counter.inc()
    task_latency.observe(time.time() - start_time)
    
    return result

def main():
    # Generate sample data
    data = np.random.rand(1000, 1000)
    chunk_size = 100
    chunks = [data[i:i + chunk_size] for i in range(0, len(data), chunk_size)]
    
    # Process chunks in parallel
    print(f"Processing {len(chunks)} chunks of data...")
    start_time = time.time()
    
    # Submit tasks
    futures = [process_data.remote(chunk) for chunk in chunks]
    
    # Get results
    results = ray.get(futures)
    
    total_time = time.time() - start_time
    print(f"Processing completed in {total_time:.2f} seconds")
    print(f"Average result: {np.mean(results):.4f}")

if __name__ == "__main__":
    main() 
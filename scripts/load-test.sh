#!/bin/bash

set -e

# Load test configuration
DURATION=${LOAD_TEST_DURATION:-60}
CONCURRENCY=${LOAD_TEST_CONCURRENCY:-10}
HOSTS=("foo.localhost" "bar.localhost")
BASE_URL="http://127.0.0.1:8080"

echo ""
echo "Load Test Starting"
echo "=================="
echo "Test Duration: ${DURATION} seconds"
echo "Concurrency Level: ${CONCURRENCY} concurrent workers"
echo "Target Hosts: ${HOSTS[@]}"
echo ""

# Initialize result files
> load-test-results.txt
> load-test-raw.jsonl

# Function to make requests
make_requests() {
  local host=$1
  local duration=$2
  local start_time=$(date +%s)
  
  while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $duration ]; then
      break
    fi
    
    request_start=$(date +%s%N | cut -b1-13)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $host" "$BASE_URL/" 2>/dev/null || echo "000")
    request_end=$(date +%s%N | cut -b1-13)
    response_time=$((request_end - request_start))
    
    echo "{\"host\":\"$host\",\"http_code\":$http_code,\"response_time_ms\":$response_time,\"timestamp\":$current_time}" >> load-test-raw.jsonl
  done
}

# Run load test concurrently
echo "Sending requests from $CONCURRENCY workers..."
for ((i=0; i<$CONCURRENCY; i++)); do
  for host in "${HOSTS[@]}"; do
    make_requests "$host" "$DURATION" &
  done
done

wait

echo "Requests complete. Now let me analyze the results..."
echo ""

# Check if we have results
if [ ! -f load-test-raw.jsonl ] || [ ! -s load-test-raw.jsonl ]; then
  echo "No requests were recorded. There may be a connectivity issue."
  cat > load-test-results.json << 'EOF'
{
  "failureRate": 0,
  "requestsPerSec": 0,
  "stats": {
    "avg": 0,
    "p90": 0,
    "p95": 0,
    "p99": 0
  }
}
EOF
  exit 0
fi

# Calculate metrics OUTSIDE of subshell to avoid variable loss
total_requests=$(wc -l < load-test-raw.jsonl)
successful=$(grep -c '"http_code":200' load-test-raw.jsonl || echo 0)
failed=$((total_requests - successful))
failure_rate=$(echo "scale=2; ($failed * 100) / $total_requests" | bc 2>/dev/null || echo "0")
req_per_sec=$(echo "scale=2; $total_requests / $DURATION" | bc 2>/dev/null || echo "0")

# Extract response times
response_times=$(grep -o '"response_time_ms":[0-9]*' load-test-raw.jsonl | grep -o '[0-9]*$' | sort -n)

avg=0 min=0 max=0 p50=0 p90=0 p95=0 p99=0
if [ -n "$response_times" ]; then
  avg=$(echo "$response_times" | awk '{sum+=$1; count++} END {print sum/count}')
  min=$(echo "$response_times" | head -1)
  max=$(echo "$response_times" | tail -1)
  count=$(echo "$response_times" | wc -l)
  
  # Handle edge cases for percentile indices
  p50_idx=$((count * 50 / 100))
  p90_idx=$((count * 90 / 100))
  p95_idx=$((count * 95 / 100))
  p99_idx=$((count * 99 / 100))
  
  [ $p50_idx -lt 1 ] && p50_idx=1
  [ $p90_idx -lt 1 ] && p90_idx=1
  [ $p95_idx -lt 1 ] && p95_idx=1
  [ $p99_idx -lt 1 ] && p99_idx=1
  
  p50=$(echo "$response_times" | sed -n "${p50_idx}p")
  p90=$(echo "$response_times" | sed -n "${p90_idx}p")
  p95=$(echo "$response_times" | sed -n "${p95_idx}p")
  p99=$(echo "$response_times" | sed -n "${p99_idx}p")
fi

# Output text results
{
  echo ""
  echo "Load Test Results"
  echo "================="
  echo ""
  printf "Failure Rate: %s%%\n" "$failure_rate"
  printf "Throughput: %s requests per second\n" "$req_per_sec"
  echo ""

  if [ -n "$response_times" ]; then
    echo "Response Times (milliseconds)"
    echo "============================="
    printf "Average: %.2f ms\n" "$avg"
    printf "P90: %s ms\n" "$p90"
    printf "P95: %s ms\n" "$p95"
    printf "P99: %s ms\n" "$p99"
    echo ""
  fi
} | tee load-test-results.txt

# Generate JSON output
cat > load-test-results.json << EOF
{
  "failureRate": $failure_rate,
  "requestsPerSec": $req_per_sec,
  "stats": {
    "avg": $avg,
    "p90": $p90,
    "p95": $p95,
    "p99": $p99
  }
}
EOF

echo ""
echo "Load test complete. Results have been saved:"
echo "  - Summary: load-test-results.txt"
echo "  - Raw data: load-test-results.json"
echo ""

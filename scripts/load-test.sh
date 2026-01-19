#!/bin/bash
set -e

# Load test configuration
DURATION=${LOAD_TEST_DURATION:-60}
CONCURRENCY=${LOAD_TEST_CONCURRENCY:-10}
HOSTS=("foo.localhost" "bar.localhost")
BASE_URL="http://127.0.0.1:8080"

echo "Starting load test..."
echo "Duration: ${DURATION}s"
echo "Concurrency: ${CONCURRENCY}"
echo "Hosts: ${HOSTS[@]}"
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
for ((i=0; i<$CONCURRENCY; i++)); do
  for host in "${HOSTS[@]}"; do
    make_requests "$host" "$DURATION" &
  done
done

wait

echo "Load test completed. Processing results..."

# Process results using a simple awk/bash approach
{
  echo "Load Test Results"
  echo "================="
  echo ""
  
  total_requests=$(wc -l < load-test-raw.jsonl)
  successful=$(grep -c '"http_code":200' load-test-raw.jsonl || echo 0)
  failed=$((total_requests - successful))
  failure_rate=$(echo "scale=2; ($failed * 100) / $total_requests" | bc)
  req_per_sec=$(echo "scale=2; $total_requests / $DURATION" | bc)
  
  echo "Total Requests: $total_requests"
  echo "Successful: $successful"
  echo "Failed: $failed"
  echo "Failure Rate: ${failure_rate}%"
  echo "Requests/sec: ${req_per_sec}"
  echo ""
  
  # Extract response times
  response_times=$(grep -o '"response_time_ms":[0-9]*' load-test-raw.jsonl | grep -o '[0-9]*$' | sort -n)
  
  if [ -n "$response_times" ]; then
    avg=$(echo "$response_times" | awk '{sum+=$1; count++} END {print sum/count}')
    min=$(echo "$response_times" | head -1)
    max=$(echo "$response_times" | tail -1)
    
    # Calculate percentiles
    count=$(echo "$response_times" | wc -l)
    p50_idx=$((count * 50 / 100))
    p90_idx=$((count * 90 / 100))
    p95_idx=$((count * 95 / 100))
    p99_idx=$((count * 99 / 100))
    
    p50=$(echo "$response_times" | sed -n "${p50_idx}p")
    p90=$(echo "$response_times" | sed -n "${p90_idx}p")
    p95=$(echo "$response_times" | sed -n "${p95_idx}p")
    p99=$(echo "$response_times" | sed -n "${p99_idx}p")
    
    echo "Response Time Statistics (ms)"
    echo "=============================="
    printf "Average: %.2f\n" "$avg"
    echo "Min: $min"
    echo "Max: $max"
    echo "P50: $p50"
    echo "P90: $p90"
    echo "P95: $p95"
    echo "P99: $p99"
    echo ""
  fi
  
  # Per-host breakdown
  echo "Per-Host Breakdown"
  echo "=================="
  for host in "${HOSTS[@]}"; do
    host_count=$(grep -c "\"host\":\"$host\"" load-test-raw.jsonl || echo 0)
    host_success=$(grep -c "\"host\":\"$host\".*\"http_code\":200" load-test-raw.jsonl || echo 0)
    host_fail=$((host_count - host_success))
    host_times=$(grep "\"host\":\"$host\"" load-test-raw.jsonl | grep -o '"response_time_ms":[0-9]*' | grep -o '[0-9]*$' | sort -n)
    
    if [ -n "$host_times" ]; then
      host_avg=$(echo "$host_times" | awk '{sum+=$1; count++} END {print sum/count}')
      printf "  %s: %d requests, %d passed, %d failed (avg: %.2fms)\n" "$host" "$host_count" "$host_success" "$host_fail" "$host_avg"
    fi
  done
  
} | tee load-test-results.txt

# Generate JSON output for GitHub comment
{
  echo "{"
  echo "  \"totalRequests\": $total_requests,"
  echo "  \"successfulRequests\": $successful,"
  echo "  \"failedRequests\": $failed,"
  echo "  \"failureRate\": $failure_rate,"
  echo "  \"requestsPerSec\": $req_per_sec,"
  echo "  \"stats\": {"
  echo "    \"avg\": $(echo "$response_times" | awk '{sum+=$1; count++} END {print sum/count}'),"
  echo "    \"min\": $(echo "$response_times" | head -1),"
  echo "    \"max\": $(echo "$response_times" | tail -1),"
  echo "    \"p50\": $p50,"
  echo "    \"p90\": $p90,"
  echo "    \"p95\": $p95,"
  echo "    \"p99\": $p99"
  echo "  },"
  echo "  \"endpoints\": ["
  
  first=true
  for host in "${HOSTS[@]}"; do
    host_count=$(grep -c "\"host\":\"$host\"" load-test-raw.jsonl || echo 0)
    host_success=$(grep -c "\"host\":\"$host\".*\"http_code\":200" load-test-raw.jsonl || echo 0)
    host_fail=$((host_count - host_success))
    host_times=$(grep "\"host\":\"$host\"" load-test-raw.jsonl | grep -o '"response_time_ms":[0-9]*' | grep -o '[0-9]*$' | sort -n)
    host_avg=$(echo "$host_times" | awk '{sum+=$1; count++} END {print sum/count}')
    
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    echo "    {"
    echo "      \"host\": \"$host\","
    echo "      \"successCount\": $host_success,"
    echo "      \"failureCount\": $host_fail,"
    echo "      \"avgResponseTime\": $host_avg"
    echo "    }" | tr -d '\n'
  done
  
  echo ""
  echo "  ]"
  echo "}"
} > results.json

echo ""
echo "✅ Load test complete. Results saved to results.json and load-test-results.txt"

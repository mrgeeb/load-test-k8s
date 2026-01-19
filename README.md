# Kubernetes Load Testing CI/CD Pipeline

This project sets up a comprehensive CI/CD pipeline that automatically runs load tests on a Kubernetes cluster for every pull request to the default branch.

## Architecture

### GitHub Actions Workflow
- **Trigger**: Pull requests to `main`, `master`, or `develop` branches
- **Runner**: Ubuntu latest
- **Duration**: Approximately 2-3 minutes per run

### Kubernetes Setup
- **Cluster**: KinD (Kubernetes in Docker)
- **Nodes**: 1 control-plane + 2 worker nodes
- **Ingress Controller**: NGINX Ingress Controller
- **Services**: 
  - `foo` service (returns "foo")
  - `bar` service (returns "bar")

### Load Testing
- **Duration**: Configurable (default 60 seconds)
- **Concurrency**: Configurable (default 10 concurrent requests)
- **Endpoints**: 
  - `http://foo.localhost`
  - `http://bar.localhost`

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-load-test.yml          # GitHub Actions workflow
├── k8s/
│   ├── kind-config.yaml              # KinD cluster configuration
│   ├── namespace.yaml                # Kubernetes namespace
│   ├── foo-deployment.yaml           # Foo service deployment & service
│   ├── bar-deployment.yaml           # Bar service deployment & service
│   └── ingress.yaml                  # Ingress configuration
└── scripts/
    ├── health-check.sh               # Pre-load test health checks
    └── load-test.sh                  # Load test script
```

## What the Workflow Does

1. **Setup**: Checkout code and create a KinD cluster with 3 nodes
2. **Install Ingress**: Deploy NGINX Ingress Controller
3. **Deploy Services**: Deploy foo and bar HTTP echo services
4. **Health Checks**: Verify all deployments are healthy
5. **Port Forwarding**: Setup local port forwarding for the Ingress
6. **Load Test**: Run concurrent HTTP requests to both endpoints
7. **Post Results**: Comment on the PR with comprehensive load test statistics

## Load Test Metrics

The workflow captures and reports:
- **Total Requests**: Number of requests sent
- **Success Rate**: Percentage of successful (HTTP 200) responses
- **Failure Rate**: Percentage of failed responses
- **Requests/sec**: Throughput (requests per second)
- **Response Time Statistics**:
  - Average (avg)
  - Minimum (min)
  - Maximum (max)
  - Percentiles: P50, P90, P95, P99
- **Per-Endpoint Breakdown**: Individual metrics for foo and bar services

## Configuration

You can customize the load test parameters in the workflow file:

```yaml
env:
  LOAD_TEST_DURATION: 60      # Test duration in seconds
  LOAD_TEST_CONCURRENCY: 10   # Number of concurrent requests
```

## Running Locally

To test the setup locally:

1. Install KinD and kubectl
2. Create the cluster: `kind create cluster --config k8s/kind-config.yaml --name load-test-cluster`
3. Install Ingress: `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml`
4. Deploy services: `kubectl apply -f k8s/`
5. Run health checks: `bash scripts/health-check.sh`
6. Port forward: `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80`
7. Update hosts: Add `127.0.0.1 foo.localhost` and `127.0.0.1 bar.localhost` to `/etc/hosts`
8. Run load test: `LOAD_TEST_DURATION=60 LOAD_TEST_CONCURRENCY=10 bash scripts/load-test.sh`

## GitHub Actions Output

The workflow posts a detailed comment on every PR containing:
- Summary statistics (total requests, success rate, throughput)
- Response time percentiles
- Per-endpoint performance breakdown
- Timestamp of the test run

This allows developers to see the performance impact of their changes immediately.

## Requirements

- GitHub repository with Actions enabled
- Docker available in the CI runner (standard on Ubuntu)
- `curl`, `kubectl`, and `bash` (pre-installed on Ubuntu runners)

## Troubleshooting

### Ingress not accessible
- Verify port forwarding is running: `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80`
- Check Ingress controller is healthy: `kubectl get pods -n ingress-nginx`

### Services not responding
- Check pod status: `kubectl get pods -n app`
- View pod logs: `kubectl logs -n app <pod-name>`

### Load test producing no results
- Verify connectivity: `curl -H "Host: foo.localhost" http://127.0.0.1:8080/`
- Check Ingress routing: `kubectl get ingress -n app`

## Performance Considerations

- KinD provides a lightweight Kubernetes environment suitable for CI
- Response times will be higher than production due to container overhead
- Adjust concurrency and duration based on CI runner resources
- Results are specific to the test environment and may not reflect production performance

## Security Notes

- This pipeline only runs on internal pull requests
- Results are posted publicly in PR comments (consider privacy implications)
- No credentials are stored or exposed in the workflow

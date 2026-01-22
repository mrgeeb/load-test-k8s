# Kubernetes Load Testing CI/CD Pipeline

Automated load testing on Kubernetes for every pull request.

## Overview

- **Trigger**: Pull requests to `main`
- **Environment**: KinD cluster with NGINX Ingress
- **Services**: foo and bar HTTP services
- **Tests**: Concurrent HTTP load testing

## Project Structure

```
.
├── .github/workflows/ci-load-test.yml
├── k8s/
│   ├── kind-config.yaml
│   ├── namespace.yaml
│   ├── foo-deployment.yaml
│   ├── bar-deployment.yaml
│   ├── ingress-nginx-controller.yaml
│   └── ingress.yaml
└── scripts/
    ├── health-check.sh
    └── load-test.sh
```

## Workflow Steps

1. Create KinD cluster
2. Deploy foo and bar services
3. Install NGINX Ingress Controller
4. Run health checks
5. Execute load test
6. Post results to PR

## Configuration

```yaml
env:
  LOAD_TEST_DURATION: 60
  LOAD_TEST_CONCURRENCY: 10
```

## Load Test Results

The PR comment includes:
- Response times: avg, P90, P95, P99 (ms)
- Failure rate: %
- Throughput: requests/second

## Running Locally

```bash
kind create cluster --config k8s/kind-config.yaml --name load-test-cluster
kubectl apply -f k8s/ingress-nginx-controller.yaml
kubectl apply -f k8s/
bash scripts/health-check.sh
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &
LOAD_TEST_DURATION=60 LOAD_TEST_CONCURRENCY=10 bash scripts/load-test.sh
```

## Time Taken  
60 minutes for Kind exploration (since I never use Kind)
30 minutes for creating deployment.yaml
30 minutes for make sure ingress is running
60 minutes for creating load test
60 minutes for creating github action
60 minutes for create load test
180 minutes for debugging

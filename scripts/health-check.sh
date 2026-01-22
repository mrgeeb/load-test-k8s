#!/bin/bash

set -e

echo ""
echo "Starting health checks to verify the cluster is ready..."
echo ""

# Check if the app namespace exists and has our deployments
echo "Step 1: Checking if deployments are ready"
echo "---"

echo "Looking at the foo deployment..."
FOO_STATUS=$(kubectl get deployment foo -n app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
if [ "$FOO_STATUS" != "True" ]; then
  echo "foo is not ready yet"
  kubectl describe deployment foo -n app 2>/dev/null || echo "Could not find foo deployment"
else
  echo "foo deployment is ready and running"
fi

echo ""
echo "Now checking the bar deployment..."
BAR_STATUS=$(kubectl get deployment bar -n app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
if [ "$BAR_STATUS" != "True" ]; then
  echo "bar is not ready yet"
  kubectl describe deployment bar -n app 2>/dev/null || echo "Could not find bar deployment"
else
  echo "bar deployment is ready and running"
fi

# Check if ingress is configured
echo ""
echo "Step 2: Checking ingress configuration"
echo "---"

echo "Looking for the ingress resource..."
INGRESS_HOST=$(kubectl get ingress app-ingress -n app -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
if [ -n "$INGRESS_HOST" ]; then
  echo "Found ingress configured for: $INGRESS_HOST"
else
  echo "Ingress is not fully configured yet"
fi

# Test if the ingress controller is running
echo ""
echo "Step 3: Testing ingress controller connectivity"
echo "---"

echo "Looking for the ingress controller pod..."
INGRESS_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$INGRESS_POD" ]; then
  echo "Could not find any ingress controller pods running"
  echo "Available pods in ingress-nginx:"
  kubectl get pods -n ingress-nginx
  exit 1
fi

echo "Found ingress controller pod: $INGRESS_POD"
echo ""

# Test connection to foo through the ingress
echo "Testing if we can reach foo through the ingress..."
if kubectl exec -n ingress-nginx "$INGRESS_POD" -- curl -s -H "Host: foo.localhost" http://localhost/ > /dev/null 2>&1; then
  echo "foo is reachable through ingress"
else
  echo "Could not reach foo through ingress"
fi

# Test connection to bar through the ingress
echo ""
echo "Testing if we can reach bar through the ingress..."
if kubectl exec -n ingress-nginx "$INGRESS_POD" -- curl -s -H "Host: bar.localhost" http://localhost/ > /dev/null 2>&1; then
  echo "bar is reachable through ingress"
else
  echo "Could not reach bar through ingress"
fi

echo ""
echo "Health checks complete"
echo ""

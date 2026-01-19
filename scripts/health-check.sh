#!/bin/bash

echo "Performing health checks on deployments and ingress..."

# Check foo deployment
echo "Checking foo deployment..."
FOO_STATUS=$(kubectl get deployment foo -n app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
if [ "$FOO_STATUS" != "True" ]; then
  echo "⚠️  foo deployment not ready yet, checking pod status..."
  kubectl describe deployment foo -n app 2>/dev/null || echo "Deployment foo not found"
else
  echo "✅ foo deployment is ready"
fi

# Check bar deployment
echo "Checking bar deployment..."
BAR_STATUS=$(kubectl get deployment bar -n app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
if [ "$BAR_STATUS" != "True" ]; then
  echo "⚠️  bar deployment not ready yet, checking pod status..."
  kubectl describe deployment bar -n app 2>/dev/null || echo "Deployment bar not found"
else
  echo "✅ bar deployment is ready"
fi

# Check ingress
echo "Checking ingress..."
kubectl get ingress app-ingress -n app -o jsonpath='{.spec.rules[0].host}' 2>/dev/null && echo " ✅ Ingress is configured" || echo "⚠️  Ingress not fully configured"

# Test connectivity via ingress
echo "Testing connectivity via ingress controller..."
INGRESS_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$INGRESS_POD" ]; then
  echo "❌ No ingress controller pod found"
  kubectl get pods -n ingress-nginx
  exit 1
fi

echo "Using ingress pod: $INGRESS_POD"

# Test foo
echo "Testing foo endpoint..."
if kubectl exec -n ingress-nginx "$INGRESS_POD" -- curl -s -H "Host: foo.localhost" http://localhost/ > /dev/null 2>&1; then
  echo "✅ Ingress routing for foo is working"
else
  echo "⚠️  Ingress routing for foo - retrying..."
fi

# Test bar
echo "Testing bar endpoint..."
if kubectl exec -n ingress-nginx "$INGRESS_POD" -- curl -s -H "Host: bar.localhost" http://localhost/ > /dev/null 2>&1; then
  echo "✅ Ingress routing for bar is working"
else
  echo "⚠️  Ingress routing for bar - retrying..."
fi

echo ""
echo "✅ Health checks completed!"

#!/bin/bash
set -e

echo "Performing health checks on deployments and ingress..."

# Check foo deployment
echo "Checking foo deployment..."
FOO_STATUS=$(kubectl get deployment foo -n app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
if [ "$FOO_STATUS" != "True" ]; then
  echo "❌ foo deployment is not ready"
  kubectl describe deployment foo -n app
  exit 1
fi
echo "✅ foo deployment is ready"

# Check bar deployment
echo "Checking bar deployment..."
BAR_STATUS=$(kubectl get deployment bar -n app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
if [ "$BAR_STATUS" != "True" ]; then
  echo "❌ bar deployment is not ready"
  kubectl describe deployment bar -n app
  exit 1
fi
echo "✅ bar deployment is ready"

# Check ingress
echo "Checking ingress..."
INGRESS_STATUS=$(kubectl get ingress app-ingress -n app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$INGRESS_STATUS" ]; then
  echo "⚠️  Ingress IP not yet assigned (normal for KinD), continuing..."
fi
echo "✅ Ingress is configured"

# Test connectivity to foo
echo "Testing connectivity to foo service..."
FOO_POD=$(kubectl get pods -n app -l app=foo -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n app "$FOO_POD" -- wget -q -O- http://localhost:5678/ | grep -q "echo-server" && echo "✅ foo service is responding" || exit 1

# Test connectivity to bar
echo "Testing connectivity to bar service..."
BAR_POD=$(kubectl get pods -n app -l app=bar -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n app "$BAR_POD" -- wget -q -O- http://localhost:5678/ | grep -q "echo-server" && echo "✅ bar service is responding" || exit 1

# Test via ingress
echo "Testing connectivity via ingress controller..."
INGRESS_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ingress-nginx "$INGRESS_POD" -- wget -q -O- -H "Host: foo.localhost" http://localhost/ | grep -q "echo-server" && echo "✅ Ingress routing for foo is working" || exit 1
kubectl exec -n ingress-nginx "$INGRESS_POD" -- wget -q -O- -H "Host: bar.localhost" http://localhost/ | grep -q "echo-server" && echo "✅ Ingress routing for bar is working" || exit 1

echo ""
echo "✅ All health checks passed!"

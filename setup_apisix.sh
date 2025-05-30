#!/bin/bash

# Wait for APISIX admin API to be ready
echo "Waiting for APISIX admin API (http://apisix:9180)..."
until curl -s -o /dev/null -w "%{http_code}" http://apisix:9180/apisix/admin/routes -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' | grep -q "200"; do
  echo -n "."
  sleep 5
done
echo "APISIX admin API is ready."

# API Key
API_KEY="edd1c9f034335f136f87ad84b625c8f1"
ADMIN_API_BASE_URL="http://apisix:9180/apisix/admin"

# 1. Create/Update Dummy Upstream
echo "Setting up dummy-upstream..."
curl -s -X PUT "${ADMIN_API_BASE_URL}/upstreams/dummy-upstream" \
-H "X-API-KEY: ${API_KEY}" \
-H "Content-Type: application/json" \
-d '{
    "name": "Dummy Upstream",
    "type": "roundrobin",
    "nodes": {
        "httpbin.org:80": 1
    }
}'
echo -e "\nDummy upstream setup complete."

# 2. Create/Update Test Upstream Route
echo "Setting up test-upstream-route..."
curl -s -X PUT "${ADMIN_API_BASE_URL}/routes/test-upstream-route" \
-H "X-API-KEY: ${API_KEY}" \
-H "Content-Type: application/json" \
-d '{
    "name": "Test Upstream Route",
    "uri": "/test-upstream/*",
    "upstream_id": "dummy-upstream",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/test-upstream/(.*)", "/anything/$1"],
            "scheme": "http"
        }
    }
}'
echo -e "\nTest upstream route setup complete."

echo "APISIX configuration applied."

# Test the route
echo "Testing the route http://apisix:9080/test-upstream/get..."
# Wait a couple of seconds for changes to propagate
sleep 3
curl -s -i http://apisix:9080/test-upstream/get
echo -e "\nTest complete. Check the output above. You should see a response from httpbin.org."

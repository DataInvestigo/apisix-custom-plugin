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

# 3. Create/Update File Proxy Route
echo "Setting up file-proxy-route..."
curl -s -X PUT "${ADMIN_API_BASE_URL}/routes/file-proxy-route" \
-H "X-API-KEY: ${API_KEY}" \
-H "Content-Type: application/json" \
-d '{
    "name": "File Proxy Route",
    "uri": "/serve-file",
    "plugins": {
        "file-proxy": {
            "path": "/usr/local/apisix/static_content/test_file.txt"
        }
    }
}'
echo -e "\nFile proxy route setup complete."


# Test the upstream route
echo "Testing the upstream route http://apisix:9080/test-upstream/get..."
# Wait a couple of seconds for changes to propagate
sleep 3
curl -s -i http://apisix:9080/test-upstream/get # Ensure this uses apisix
echo -e "\nUpstream test complete. Check the output above. You should see a response from httpbin.org."

# Test the file-proxy route
echo "Testing the file-proxy route http://apisix:9080/serve-file..."
sleep 1 # Allow a moment for the new route to be active
FILE_CONTENT_TEST=$(curl -s http://apisix:9080/serve-file) # Ensure this uses apisix

# Hardcode the expected content to avoid issues with cat and volume mounts
EXPECTED_CONTENT="Hello from the file-proxy plugin!
This is a test file."

echo "Response from /serve-file:"
echo "${FILE_CONTENT_TEST}"

# Trim trailing newline from FILE_CONTENT_TEST for robust comparison if curl adds one and file doesn't have it
# However, the test file *does* have a trailing newline.
# Let's ensure EXPECTED_CONTENT also has one if the file does.
# The file content is:
# Hello from the file-proxy plugin!
# This is a test file.
# (newline here)
# So the string should be (matching command substitution behavior, which strips the final newline):
EXPECTED_CONTENT="Hello from the file-proxy plugin!
This is a test file." # NO trailing newline here in the string value

if [ "${FILE_CONTENT_TEST}" = "${EXPECTED_CONTENT}" ]; then
    echo -e "\nFile-proxy plugin test: SUCCESS - Content matches."
else
    echo -e "\nFile-proxy plugin test: FAILED - Content does NOT match."
    echo "Expected:"
    echo "${EXPECTED_CONTENT}"
fi
echo -e "\nAll tests complete."

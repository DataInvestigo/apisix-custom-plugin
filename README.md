# Apache APISIX with Custom File-Proxy Plugin and Upstream Demo

This document guides you through setting up and testing Apache APISIX with a custom Lua plugin (`file-proxy`) and demonstrates configuring a route with an upstream service (`httpbin.org`).

## Overview

This demo showcases:
1.  Running Apache APISIX and etcd using Docker Compose.
2.  Using a custom Lua plugin (`file-proxy`) to serve a static YAML file.
3.  Enabling built-in APISIX plugins (e.g., `proxy-rewrite`).
4.  Configuring an upstream service.
5.  Creating and testing a route that proxies requests to the upstream service with URL rewriting.

## Prerequisites

-   [Docker](https://docs.docker.com/get-docker/) and Docker Compose installed.
-   [curl](https://curl.se/) installed for sending HTTP requests.
-   Basic understanding of Apache APISIX concepts (routes, upstreams, plugins).

## Setup Instructions

### 1. Start APISIX and etcd

Clone or download this project. From the project root folder, start the services:

```bash
docker compose up -d
```
This command starts APISIX and its configuration store, etcd.

### 2. Configure and Test the `file-proxy` Custom Plugin

The `file-proxy` plugin allows serving local files via APISIX. We'll configure it to serve the `openapi.yaml` file located at `/usr/local/apisix/conf/openapi.yaml` inside the APISIX container.

**Create a route for `openapi.yaml`:**

```bash
curl "http://127.0.0.1:9180/apisix/admin/routes/open-api-definition" -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
{
   "name":"OpenAPI Definition",
   "desc":"Route for OpenAPI Definition file",
   "uri":"/openapi.yaml",
   "plugins":{
      "file-proxy":{
         "path":"/usr/local/apisix/conf/openapi.yaml"
      }
   }
}'
```

**Test the `file-proxy` route:**

Send a request to `http://127.0.0.1:9080/openapi.yaml`.

```bash
curl -i http://127.0.0.1:9080/openapi.yaml
```

You should receive a `200 OK` response with the content of `openapi.yaml`.

### 3. Enable the `proxy-rewrite` Plugin

To demonstrate routing to an external service with URL modification, we need the `proxy-rewrite` plugin.

**Edit `apisix_conf/config.yaml`:**

Ensure the `plugins` section includes `proxy-rewrite`:

```yaml
# ... other configurations ...

plugins:
  - file-proxy
  - proxy-rewrite # Add this line if not present

# ... other configurations ...
```

**Restart APISIX to apply changes:**

```bash
docker compose restart apisix
```

### 4. Configure a Dummy Upstream

We'll create an upstream service that points to `httpbin.org`, a useful service for testing HTTP requests.

**Create the `dummy-upstream`:**

```bash
curl "http://127.0.0.1:9180/apisix/admin/upstreams/dummy-upstream" -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
{
    "name": "Dummy Upstream",
    "type": "roundrobin",
    "nodes": {
        "httpbin.org:80": 1
    }
}'
```

### 5. Configure and Test a Route with Upstream and `proxy-rewrite`

Now, create a route that uses the `dummy-upstream` and the `proxy-rewrite` plugin to forward requests from `/test-upstream/*` to `httpbin.org/anything/*`.

**Create the `test-upstream-route`:**

```bash
curl "http://127.0.0.1:9180/apisix/admin/routes/test-upstream-route" -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
{
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
```

**Test the `test-upstream-route`:**

Send a request to `http://127.0.0.1:9080/test-upstream/get?param=value`.

```bash
curl -i "http://127.0.0.1:9080/test-upstream/get?param=value&show_env=1"
```

You should receive a `200 OK` response from `httpbin.org`. The body of the response will be a JSON object detailing the request received by `httpbin.org`, including the rewritten URL (`http://127.0.0.1/anything/get?param=value&show_env=1`) and your request headers.

This confirms that APISIX correctly routed the request to the `dummy-upstream` and the `proxy-rewrite` plugin modified the path as configured.

## Summary

This demo covered:
-   Setting up APISIX with Docker.
-   Using the custom `file-proxy` plugin.
-   Enabling and using the built-in `proxy-rewrite` plugin.
-   Configuring an upstream and a route to proxy requests to an external service.

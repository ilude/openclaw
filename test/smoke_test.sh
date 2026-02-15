#!/bin/bash
# Smoke tests for OpenClaw deployment
# Usage: ./test/smoke_test.sh [base_url]
# Default: https://openclaw.ilude.com

set -euo pipefail

BASE_URL="${1:-https://openclaw.ilude.com}"
PASS=0
FAIL=0
TOTAL=0

# Check HTTP status code
check_status() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    TOTAL=$((TOTAL + 1))

    actual_status=$(curl -s -o /dev/null -w "%{http_code}" -k --max-time 10 "$url" 2>/dev/null || echo "000")

    if [ "$actual_status" = "$expected_status" ]; then
        echo "  PASS  $name (HTTP $actual_status)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $name (expected HTTP $expected_status, got $actual_status)"
        FAIL=$((FAIL + 1))
    fi
}

# Check response body contains expected string
check_content() {
    local name="$1"
    local url="$2"
    local expected_content="$3"
    TOTAL=$((TOTAL + 1))

    body=$(curl -s -k --max-time 10 "$url" 2>/dev/null || echo "")

    if echo "$body" | grep -q "$expected_content"; then
        echo "  PASS  $name (contains '$expected_content')"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $name (missing '$expected_content')"
        FAIL=$((FAIL + 1))
    fi
}

# Check response header contains expected value
check_header() {
    local name="$1"
    local url="$2"
    local expected_header="$3"
    TOTAL=$((TOTAL + 1))

    headers=$(curl -s -k -I --max-time 10 "$url" 2>/dev/null || echo "")

    if echo "$headers" | grep -qi "$expected_header"; then
        echo "  PASS  $name (header: $expected_header)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $name (missing header: $expected_header)"
        FAIL=$((FAIL + 1))
    fi
}

echo "OpenClaw Smoke Tests"
echo "Target: $BASE_URL"
echo "---"

# Fetch dashboard HTML once for content and asset checks
DASHBOARD_HTML=$(curl -s -k --max-time 10 "$BASE_URL/" 2>/dev/null || echo "")

# 1. Dashboard responds with 200
check_status "Dashboard root returns 200" "$BASE_URL/"

# 2. Dashboard serves the OpenClaw Control UI SPA
check_content "Dashboard contains OpenClaw title" "$BASE_URL/" "OpenClaw Control"

# 3. Dashboard contains the web component
check_content "Dashboard contains app component" "$BASE_URL/" "<openclaw-app>"

# 4. JS bundle loads (extract path from HTML)
JS_PATH=$(echo "$DASHBOARD_HTML" | sed -n 's/.*src="\.\(\/assets\/[^"]*\.js\)".*/\1/p' | head -1)
if [ -n "$JS_PATH" ]; then
    check_status "JS bundle loads" "$BASE_URL$JS_PATH"
else
    TOTAL=$((TOTAL + 1))
    echo "  FAIL  JS bundle loads (no script src found in HTML)"
    FAIL=$((FAIL + 1))
fi

# 5. CSS bundle loads (extract path from HTML)
CSS_PATH=$(echo "$DASHBOARD_HTML" | sed -n 's/.*href="\.\(\/assets\/[^"]*\.css\)".*/\1/p' | head -1)
if [ -n "$CSS_PATH" ]; then
    check_status "CSS bundle loads" "$BASE_URL$CSS_PATH"
else
    TOTAL=$((TOTAL + 1))
    echo "  FAIL  CSS bundle loads (no stylesheet href found in HTML)"
    FAIL=$((FAIL + 1))
fi

# 6. Favicon loads
check_status "Favicon SVG loads" "$BASE_URL/favicon.svg"

# 7. Security headers present
check_header "X-Frame-Options header set" "$BASE_URL/" "X-Frame-Options"
check_header "Content-Security-Policy header set" "$BASE_URL/" "Content-Security-Policy"
check_header "X-Content-Type-Options header set" "$BASE_URL/" "X-Content-Type-Options"

echo "---"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

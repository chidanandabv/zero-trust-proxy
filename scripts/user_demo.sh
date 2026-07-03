#!/bin/sh

echo "================================================"
echo "  Zero-Trust Proxy - Real User Simulation"
echo "================================================"
echo ""

KEYCLOAK="http://keycloak:8080"
PROXY="https://proxy:9090"
CERT="/app/certs/client.crt"
KEY="/app/certs/client.key"

echo "[1] User logging in to Identity Server (Keycloak)..."
TOKEN=$(curl -s -X POST $KEYCLOAK/realms/company/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=zero-trust-proxy&username=chida&password=mypassword123" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not get token from Keycloak"
  exit 1
fi

echo "Login successful. JWT token received."
echo ""

echo "[2] Listing all files through proxy..."
curl -sk --cert $CERT --key $KEY \
  -H "Authorization: Bearer $TOKEN" \
  $PROXY/files | python3 -m json.tool 2>/dev/null || \
curl -sk --cert $CERT --key $KEY \
  -H "Authorization: Bearer $TOKEN" \
  $PROXY/files
echo ""

echo "[3] Accessing public file (handbook.txt)..."
curl -sk --cert $CERT --key $KEY \
  -H "Authorization: Bearer $TOKEN" \
  $PROXY/files/handbook.txt
echo ""

echo "[4] Attempting to access confidential file (salary.txt)..."
echo "    (Regular user should be DENIED)"
curl -sk --cert $CERT --key $KEY \
  -H "Authorization: Bearer $TOKEN" \
  $PROXY/files/salary.txt
echo ""

echo "[5] Attempting access WITHOUT certificate (should FAIL)..."
curl -sk \
  -H "Authorization: Bearer $TOKEN" \
  $PROXY/files 2>&1 | head -3
echo ""

echo "[6] Attempting access WITHOUT token (should FAIL)..."
curl -sk --cert $CERT --key $KEY \
  $PROXY/files 2>&1
echo ""

echo "================================================"
echo "  Simulation Complete"
echo "================================================"
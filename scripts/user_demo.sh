#!/bin/sh

echo "================================================"
echo "  Zero-Trust Proxy - Real User Simulation"
echo "================================================"
echo ""

KEYCLOAK="http://keycloak:8080"
PROXY="https://proxy:9090"
CERT="/app/certs/client.crt"
KEY="/app/certs/client.key"

# Wait for Keycloak to fully boot
echo "Waiting for Keycloak to be ready..."
MAX_WAIT=120
WAITED=0
until curl -sf "$KEYCLOAK/realms/master" > /dev/null 2>&1; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo "ERROR: Keycloak did not start in time"
    exit 1
  fi
  echo "  Not ready yet... waiting 5 seconds (${WAITED}s elapsed)"
  sleep 5
  WAITED=$((WAITED + 5))
done
echo "Keycloak is ready after ${WAITED} seconds."
echo ""

# Setup realm, client and user via API
echo "Setting up Keycloak realm, client and user..."

ADMIN_TOKEN=$(curl -s -X POST $KEYCLOAK/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin123" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

curl -s -X POST $KEYCLOAK/admin/realms \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm":"company","enabled":true}' > /dev/null

curl -s -X POST $KEYCLOAK/admin/realms/company/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId":"zero-trust-proxy",
    "enabled":true,
    "publicClient":true,
    "directAccessGrantsEnabled":true,
    "redirectUris":["http://localhost:9090/*"]
  }' > /dev/null

curl -s -X POST $KEYCLOAK/admin/realms/company/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username":"chida",
    "firstName":"Chida",
    "lastName":"User",
    "email":"chida@company.com",
    "enabled":true,
    "emailVerified":true,
    "requiredActions":[],
    "credentials":[{
      "type":"password",
      "value":"mypassword123",
      "temporary":false
    }]
  }' > /dev/null

echo "Keycloak setup complete."
echo ""

# Wait for proxy to be ready
echo "Waiting for proxy..."
sleep 5

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
  $PROXY/files
echo ""
echo ""

echo "[3] Accessing public file (handbook.txt)..."
curl -sk --cert $CERT --key $KEY \
  -H "Authorization: Bearer $TOKEN" \
  $PROXY/files/handbook.txt
echo ""

echo "[4] Attempting to access confidential file (salary.txt)..."
echo "    Regular user should be DENIED"
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
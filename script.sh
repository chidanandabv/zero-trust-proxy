#!/bin/bash

BASE="http://localhost:8080"

echo "Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST $BASE/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin123" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

echo "Creating realm..."
curl -s -X POST $BASE/admin/realms \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "company",
    "enabled": true,
    "registrationAllowed": false
  }'

echo "Creating client..."
curl -s -X POST $BASE/admin/realms/company/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "zero-trust-proxy",
    "enabled": true,
    "publicClient": true,
    "directAccessGrantsEnabled": true,
    "standardFlowEnabled": true,
    "redirectUris": ["http://localhost:9090/*"]
  }'

echo "Creating user..."
curl -s -X POST $BASE/admin/realms/company/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "chida",
    "enabled": true,
    "emailVerified": true,
    "requiredActions": [],
    "credentials": [{
      "type": "password",
      "value": "mypassword123",
      "temporary": false
    }]
  }'

echo "Done! Testing token..."
curl -s -X POST $BASE/realms/company/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=zero-trust-proxy&username=chida&password=mypassword123"

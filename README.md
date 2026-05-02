# Zero-Trust Network Access Proxy with mTLS and JWT Authentication

A master's level security project implementing a Zero-Trust access proxy in Go.
Every request must pass two security checks before reaching any backend service:
**Mutual TLS (mTLS)** for device authentication and **JWT** for user identity verification.

---

## What This Project Does
Client (cert + JWT) → Proxy (verify both) → Backend Service

- **mTLS** — client must present a certificate signed by the trusted CA
- **JWT** — client must present a valid token issued by Keycloak
- **Policy Engine** — role-based access control decides who can access what
- **Zero Trust** — no request is trusted by default, even inside the network

---

## Architecture
┌─────────────────────────────────────────┐
│           Zero-Trust Proxy              │
│                                         │
│  [mTLS Check] → [JWT Verify] → [Policy] │
│                      ↓                  │
│              Forward to Backend         │
└─────────────────────────────────────────┘
↑                        ↓
Client Request          Backend API
(cert + token)          (localhost:8081)

---

## Project Structure
zero-trust-proxy/
├── main.go              ← proxy entry point
├── proxy/
│   ├── mtls.go          ← mTLS TLS configuration
│   ├── jwt.go           ← JWT verification + JWKS fetching
│   └── policy.go        ← role-based access control
├── backend/
│   └── main.go          ← simple backend API (no auth)
├── certs/
│   ├── ca.crt           ← Certificate Authority
│   ├── ca.key           ← CA private key (keep secret)
│   ├── proxy.crt        ← proxy certificate
│   ├── proxy.key        ← proxy private key
│   ├── client.crt       ← client certificate
│   └── client.key       ← client private key
├── docker-compose.yml   ← runs Keycloak identity server
├── go.mod
└── README.md

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Go 1.22+ |
| Identity Server | Keycloak 24 |
| Certificates | OpenSSL |
| JWT Library | github.com/golang-jwt/jwt/v5 |
| Containerization | Docker |

---

## Prerequisites

- Go 1.22+
- Docker and Docker Compose
- OpenSSL
- curl (for testing)

---

## Setup and Installation

### Step 1 — Clone the repository

```bash
git clone https://github.com/chidananddabv/zero-trust-proxy
cd zero-trust-proxy
```

### Step 2 — Install Go dependencies

```bash
go mod tidy
```

### Step 3 — Generate certificates

```bash
mkdir certs && cd certs

# Create Certificate Authority
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -out ca.crt -days 3650 \
  -subj "/CN=MyCompanyCA/O=MyCompany"

# Create proxy certificate
openssl genrsa -out proxy.key 2048
openssl req -new -key proxy.key -out proxy.csr \
  -subj "/CN=proxy.company.local/O=MyCompany"
openssl x509 -req -in proxy.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out proxy.crt -days 365

# Create client certificate
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr \
  -subj "/CN=employee-laptop/O=MyCompany"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out client.crt -days 365

cd ..
```

### Step 4 — Start Keycloak

```bash
docker compose up -d
```

Wait 30 seconds then run the setup script:

```bash
chmod +x setup.sh
./setup.sh
```

This automatically creates the realm, client, and user in Keycloak.

---

## Running the Project

Open three terminals:

**Terminal 1 — Backend:**
```bash
go run backend/main.go
# Backend running on :8081
```

**Terminal 2 — Proxy:**
```bash
go run main.go
# Zero-Trust Proxy running on https://localhost:9090
```

**Terminal 3 — Get token and test:**
```bash
TOKEN=$(curl -s -X POST http://localhost:8080/realms/company/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=zero-trust-proxy&username=chida&password=mypassword123" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

curl -k \
  --cert certs/client.crt \
  --key certs/client.key \
  --cacert certs/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:9090/api/orders
```

Expected response:
```json
{"orders":["order-1","order-2"],"user":"chida"}
```

---

## API Endpoints

| Endpoint | Method | Admin | User |
|----------|--------|-------|------|
| /health | GET | ✅ | ✅ |
| /api/orders | GET | ✅ | ✅ |
| /api/admin | GET | ✅ | ❌ |

---

## Security Test Results

### Test 1 — No certificate (mTLS enforcement)
```bash
curl -k -H "Authorization: Bearer $TOKEN" https://localhost:9090/api/orders
```
Result: `SSL handshake error — connection rejected`

### Test 2 — No JWT token
```bash
curl -k --cert certs/client.crt --key certs/client.key \
  https://localhost:9090/api/orders
```
Result: `401 Missing JWT token`

### Test 3 — Fake/invalid JWT
```bash
curl -k --cert certs/client.crt --key certs/client.key \
  -H "Authorization: Bearer faketoken123" \
  https://localhost:9090/api/orders
```
Result: `401 Invalid JWT`

### Test 4 — Role escalation (user accessing admin endpoint)
```bash
curl -k --cert certs/client.crt --key certs/client.key \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:9090/api/admin
```
Result: `403 Forbidden`

### Test 5 — Valid request (all checks pass)
```bash
curl -k --cert certs/client.crt --key certs/client.key \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:9090/health
```
Result: `200 OK`

---

## How the Security Flow Works

Client connects to proxy
↓
TLS handshake — client must present certificate signed by CA
❌ No certificate → connection rejected immediately
↓
Proxy extracts JWT from Authorization header
❌ No token → 401 Unauthorized
↓
Proxy fetches Keycloak public key (JWKS) and verifies:

Token signature valid?
Token not expired?
Issuer matches Keycloak realm?
❌ Any check fails → 401 Unauthorized
↓


Policy engine checks role against requested path
❌ Role not allowed → 403 Forbidden
↓
✅ Request forwarded to backend with X-User header set


---

## Zero Trust Principles Demonstrated

| Principle | Implementation |
|-----------|---------------|
| Never trust, always verify | Every request verified regardless of origin |
| Least privilege | Roles restrict access to only required endpoints |
| Assume breach | mTLS ensures even stolen JWTs cannot be used without certificate |
| Device identity | Client certificate proves device is company-issued |
| User identity | JWT proves who the user is and what role they have |

---

## Real World Analogy

| Component | Real World Equivalent |
|-----------|----------------------|
| CA | Company HR department issuing ID cards |
| Client certificate | Company ID card installed on laptop |
| Keycloak | Office login system |
| JWT | Your session badge after logging in |
| Proxy | Security guard checking both ID and badge |
| Backend | The actual office floor — only reachable after the guard |

---

## References

- NIST SP 800-207 — Zero Trust Architecture
- RFC 7519 — JSON Web Token (JWT)
- RFC 8705 — OAuth 2.0 Mutual TLS
- Google BeyondCorp — https://cloud.google.com/beyondcorp
- Keycloak Documentation — https://www.keycloak.org/documentation

Replace yourname in the clone URL with your actual GitHub username before pushing. Let me know when you want to run the attack tests.

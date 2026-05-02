package proxy

import "strings"

var policies = map[string][]string{
	"admin":                 {"/api/orders", "/api/admin", "/health"},
	"default-roles-company": {"/api/orders", "/health"},
	"uma_authorization":     {"/api/orders", "/health"},
}

func IsAllowed(claims *Claims, method, path string) bool {
	for _, role := range claims.RealmAccess.Roles {
		allowed, ok := policies[role]
		if !ok {
			continue
		}
		for _, p := range allowed {
			if strings.HasPrefix(path, p) {
				return true
			}
		}
	}
	return false
}

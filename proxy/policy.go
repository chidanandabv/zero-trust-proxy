package proxy

import "strings"

var policies = map[string][]string{
	"admin": {
		"/files",
		"/api/orders",
		"/api/admin",
		"/health",
	},
	"default-roles-company": {
		"/files/handbook.txt",
		"/api/orders",
		"/health",
	},
	"offline_access": {
		"/files/handbook.txt",
		"/api/orders",
		"/health",
	},
	"uma_authorization": {
		"/files/handbook.txt",
		"/api/orders",
		"/health",
	},
}

func IsAllowed(claims *Claims, method, path string) bool {
	for _, role := range claims.RealmAccess.Roles {
		allowed, ok := policies[role]
		if !ok {
			continue
		}
		for _, p := range allowed {
			if path == p || strings.HasPrefix(path, p+"/") {
				return true
			}
		}
	}
	return false
}

package proxy

import "strings"

var policies = map[string][]string{
	"admin": {
		"/files",
		"/files/",
		"/api/orders",
		"/api/admin",
		"/health",
	},
	"default-roles-company": {
		"/files",
		"/files/handbook.txt",
		"/api/orders",
		"/health",
	},
	"uma_authorization": {
		"/files",
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
			if strings.HasPrefix(path, p) {
				return true
			}
		}
	}
	return false
}

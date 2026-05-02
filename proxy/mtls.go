package proxy

import (
	"crypto/tls"
	"crypto/x509"
	"os"
)

func BuildTLSConfig() (*tls.Config, error) {
	caCert, err := os.ReadFile("certs/ca.crt")
	if err != nil {
		return nil, err
	}
	caPool := x509.NewCertPool()
	caPool.AppendCertsFromPEM(caCert)

	proxyCert, err := tls.LoadX509KeyPair("certs/proxy.crt", "certs/proxy.key")
	if err != nil {
		return nil, err
	}

	return &tls.Config{
		Certificates: []tls.Certificate{proxyCert},
		ClientCAs:    caPool,
		ClientAuth:   tls.RequireAndVerifyClientCert,
		MinVersion:   tls.VersionTLS13,
	}, nil
}

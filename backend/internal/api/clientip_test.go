package api

import (
	"net"
	"testing"
)

func TestProxyTrust(t *testing.T) {
	pt := newProxyTrust([]string{"private", "203.0.113.7", "198.51.100.0/24", "bogus"})
	for ip, want := range map[string]bool{
		"127.0.0.1": true, "10.1.2.3": true, "172.18.0.5": true, "203.0.113.7": true,
		"198.51.100.42": true, "8.8.8.8": false, "203.0.113.8": false,
	} {
		if got := pt.trusted(net.ParseIP(ip)); got != want {
			t.Errorf("trusted(%s) = %v, want %v", ip, got, want)
		}
	}
}

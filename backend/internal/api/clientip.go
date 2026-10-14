package api

import (
	"net"
	"strings"

	"github.com/gofiber/fiber/v3"
)

// proxyTrust decides which hops in front of the API are our own proxies (Caddy, the web server).
type proxyTrust struct {
	private bool
	nets    []*net.IPNet
}

func newProxyTrust(entries []string) *proxyTrust {
	t := &proxyTrust{}
	for _, e := range entries {
		switch e = strings.TrimSpace(e); {
		case e == "":
		case e == "private":
			t.private = true
		case strings.Contains(e, "/"):
			if _, n, err := net.ParseCIDR(e); err == nil {
				t.nets = append(t.nets, n)
			}
		default:
			if ip := net.ParseIP(e); ip != nil {
				bits := 8 * len(ip.To16())
				if ip.To4() != nil {
					ip, bits = ip.To4(), 32
				}
				t.nets = append(t.nets, &net.IPNet{IP: ip, Mask: net.CIDRMask(bits, bits)})
			}
		}
	}
	return t
}

func (t *proxyTrust) trusted(ip net.IP) bool {
	if t.private && (ip.IsLoopback() || ip.IsPrivate()) {
		return true
	}
	for _, n := range t.nets {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

// clientIP returns the nearest untrusted address: X-Forwarded-For is read from the
// right and only while the hops are our own proxies, so a client cannot choose its
// rate-limit key by sending a made-up header (which would sit on the left).
func (t *proxyTrust) clientIP(c fiber.Ctx) string {
	ip := c.RequestCtx().RemoteIP()
	if !t.trusted(ip) {
		return ip.String()
	}
	hops := strings.Split(c.Get(fiber.HeaderXForwardedFor), ",")
	for i := len(hops) - 1; i >= 0; i-- {
		hop := net.ParseIP(strings.TrimSpace(hops[i]))
		if hop == nil {
			break
		}
		ip = hop
		if !t.trusted(hop) {
			break
		}
	}
	return ip.String()
}

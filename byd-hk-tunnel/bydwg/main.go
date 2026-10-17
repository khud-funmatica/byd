// bydwg is a minimal userspace WireGuard client for the BYD DiLink head unit,
// whose kernel has no WireGuard. It creates a TUN interface, applies a config in
// WireGuard UAPI "set" format (hex keys) and periodically dumps device state.
//
//	bydwg -i wg0 -c /data/adb/byd_hk/wg.uapi -s /data/adb/byd_hk/wg.status
//
// Addresses, routes and firewall rules are set up by the calling shell script.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.zx2c4.com/wireguard/conn"
	"golang.zx2c4.com/wireguard/device"
	"golang.zx2c4.com/wireguard/tun"
)

func main() {
	iface := flag.String("i", "wg0", "interface name")
	confPath := flag.String("c", "", "config file in UAPI set format")
	statusPath := flag.String("s", "", "file to write UAPI get output to every 30s")
	mtu := flag.Int("mtu", 1380, "interface MTU")
	verbose := flag.Bool("v", false, "verbose logging")
	flag.Parse()

	cfg, err := os.ReadFile(*confPath)
	if err != nil {
		fatal("read config: %v", err)
	}

	t, err := tun.CreateTUN(*iface, *mtu)
	if err != nil {
		fatal("create tun %s: %v", *iface, err)
	}

	level := device.LogLevelError
	if *verbose {
		level = device.LogLevelVerbose
	}
	dev := device.NewDevice(t, conn.NewDefaultBind(), device.NewLogger(level, "("+*iface+") "))
	if err := dev.IpcSet(string(cfg)); err != nil {
		fatal("apply config: %v", err)
	}
	if err := dev.Up(); err != nil {
		fatal("device up: %v", err)
	}
	fmt.Fprintf(os.Stderr, "bydwg: %s up\n", *iface)

	if *statusPath != "" {
		go func() {
			for {
				if s, err := dev.IpcGet(); err == nil {
					_ = os.WriteFile(*statusPath, []byte(s), 0600)
				}
				time.Sleep(30 * time.Second)
			}
		}()
	}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-sig:
	case <-dev.Wait():
	}
	dev.Close()
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "bydwg: "+format+"\n", args...)
	os.Exit(1)
}

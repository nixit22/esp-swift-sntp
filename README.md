# SwiftSNTP

Swift wrapper for ESP-IDF's SNTP (Simple Network Time Protocol) client, built on `esp_netif_sntp`. Re-exports the raw C API through a single `import SNTP`, plus `SNTP`, a small typed-throws wrapper that owns a time-sync session against one NTP server. Swift module name: **`SNTP`**.

Depends on: `SwiftPlatform`, `SwiftSupport`, `esp_netif`, `esp_event`, `lwip` (pulled in transitively).

## Usage

```swift
import SNTP
import Platform

// One-time app bring-up (a network interface must also be up by the time
// SNTP is created — e.g. Wi-Fi station connected):
try esp_netif_init().throwEspError()
try esp_event_loop_create_default().throwEspError()

let sntp = try SNTP(server: "pool.ntp.org")
try sntp.waitForSync(timeoutMs: 10_000)
// No explicit cleanup — deinit calls esp_netif_sntp_deinit().
```

With a sync callback and explicit start:

```swift
let sntp = try SNTP(server: "pool.ntp.org", start: false) { tv in
    print("synced: \(tv.tv_sec)")
}
try sntp.start()
```

See [`CLAUDE.md`](CLAUDE.md) for full API details and non-obvious patterns.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

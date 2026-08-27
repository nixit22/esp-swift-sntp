# SwiftSNTP

Swift wrapper for ESP-IDF's `esp_netif_sntp` (SNTP time sync). Swift module name: **`SNTP`**.

Depends on: `SwiftPlatform`, `SwiftSupport`, `esp_netif`, `esp_event`, `lwip`

## Files

| File | Role |
|---|---|
| `src/SNTP.swift` | `@_exported import ESP_SNTP` re-exports the raw C API; also defines `SNTP`, a typed-throws wrapper over one `esp_netif_sntp` session |
| `src/sntp.c` / `src/sntp.h` | C wrapper — `esp_sntp_config_create` (exposed to Swift as `esp_sntp_config_t(server:)`) builds a single-server config via the `ESP_NETIF_SNTP_DEFAULT_CONFIG` macro |
| `module.modulemap` | Clang module `ESP_SNTP` — umbrella over `src/sntp.h`, which pulls in `esp_netif_sntp.h` (init/start/wait), `esp_sntp.h` (status/mode queries, aliased `esp_sntp_*` names), and `esp_netif.h`/`esp_event.h` (for the one-time `esp_netif_init()`/`esp_event_loop_create_default()` bring-up every caller needs first) |

## Public API

```swift
import SNTP
import Platform  // for .throwEspError() below

// One-time app bring-up (raw re-exported API — not wrapped, same as
// esp-swift-nvs leaving nvs_flash_init() to the caller):
try esp_netif_init().throwEspError()
try esp_event_loop_create_default().throwEspError()

let sntp = try SNTP(server: "pool.ntp.org")
try sntp.waitForSync(timeoutMs: 10_000)   // throws .espError(ESP_ERR_TIMEOUT) if it doesn't sync in time
// time_t/gettimeofday now reflect the synced clock — read via Foundation's Date or libc directly.
// No explicit cleanup — deinit calls esp_netif_sntp_deinit().

// Optional sync-event callback and explicit start:
let sntp2 = try SNTP(server: "pool.ntp.org", start: false) { tv in
    log.i("synced: \(tv.tv_sec)s")
}
try sntp2.start()

// Raw re-exported API for status polling instead of blocking wait:
let status = esp_sntp_get_sync_status()   // SNTP_SYNC_STATUS_RESET / _COMPLETED / _IN_PROGRESS
```

Requires `esp_netif_init()` and `esp_event_loop_create_default()` to have been called first (once, at app startup) — `esp_netif_sntp_init` runs its setup on the lwIP TCP/IP thread via `esp_netif_tcpip_exec`, which needs that thread already running.

## Non-obvious patterns

**`esp_sntp_config_t(server:)`** — `ESP_NETIF_SNTP_DEFAULT_CONFIG(server)` is a function-like C macro; the Clang importer doesn't expose macros like this to Swift at all. Its expansion also assigns into a fixed-size `servers[CONFIG_LWIP_SNTP_MAX_SERVERS]` C array — imported into Swift as a same-size tuple, which has no ergonomic construction syntax for an arbitrary element count. `sntp.c`'s `esp_sntp_config_create` builds this struct in C and returns it by value; `sntp.h` gives it a constructor-shaped Swift name via `SWIFT_NAME("esp_sntp_config_t(server:)")` — same pattern as `esp-swift-gpio`'s `gpio_config_t(pin_bit_mask:...)`. Only single-server configs are wrapped; multi-server / DHCP-provided-server / server-renewal-on-new-IP support was dropped rather than kept as unused, untested plumbing (same reasoning as NVS's "default partition only").

**The `server` pointer must outlive the session — lwIP stores it, not a copy.** Confirmed by reading `lwip/src/apps/sntp/sntp.c`'s `sntp_setservername`: `sntp_servers[idx].name = server;` — a raw pointer assignment. `SNTP.init` copies the Swift `String` into a `strdup`'d C string held in `self.server` for exactly this reason (a `withCString`-scoped buffer would go out of scope before the pointer's last use); `deinit` frees it *after* `esp_netif_sntp_deinit()` runs (which calls `sntp_stop()`, ending lwIP's use of the pointer).

**`sync_cb` has no user-data/context parameter** (`typedef void (*esp_sntp_time_cb_t)(struct timeval *tv)`), unlike `Platform.IsrHandler`/`Task`'s C callbacks, which smuggle `self` through a `void*` via `Unmanaged`. There's nowhere to hang per-instance state, so `SNTP` stores the Swift closure in a `private static var syncHandler`, and `config.sync_cb` is assigned a non-capturing closure literal (Swift converts a closure with zero captures directly to a `@convention(c)` function pointer — same mechanism `Platform.Task.run()` uses passing a closure literal straight to `xTaskCreate`) that reads `SNTP.syncHandler` and forwards `tv.pointee`. Because storage is static, only one `SNTP` instance's callback can be live at a time — consistent with `esp_netif_sntp`'s own single-active-session model enforced by `esp_netif_sntp_init`.

**`@_exported import ESP_SNTP`** re-exports both headers, so callers get `esp_netif_sntp_init/start/deinit/sync_wait`, `esp_sntp_get_sync_status`, `esp_sntp_set_sync_mode`, `SNTP_SYNC_STATUS_*`, etc. with a single `import SNTP` — most callers only need the `SNTP` type itself plus occasional status polling via the raw API.

**No calibration-scheme-style SoC conditionals here** — SNTP is a pure networking/lwIP feature, not SoC-specific hardware, so (unlike `esp-swift-adc`) there's nothing to branch on across `esp32c6`/`esp32h2`.

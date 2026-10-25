// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import ESP_SNTP
import Platform

private let log = Logger(tag: "SNTP")

/// An active `esp_netif` SNTP session against a single time server.
///
/// `~Copyable` — owns the session; torn down automatically in `deinit`. Only one `SNTP`
/// instance can be alive at a time (`esp_netif_sntp_init` itself enforces this and fails
/// with `ESP_ERR_INVALID_STATE` on a second call).
public struct SNTP: ~Copyable {
    private let server: UnsafeMutablePointer<CChar>
    private static var syncHandler: ((timeval) -> Void)?

    /// Initializes and (by default) starts an SNTP session against `server`.
    ///
    /// - Parameters:
    ///   - server: NTP server hostname or IP literal, e.g. `"pool.ntp.org"`.
    ///   - smoothSync: Gradually adjust the clock via `adjtime` instead of stepping it, when
    ///     `true`. Default `false` (step immediately).
    ///   - waitForSync: Allocates the semaphore `waitForSync(timeoutMs:)` blocks on. Default
    ///     `true`; pass `false` only if the caller will never call `waitForSync(timeoutMs:)`.
    ///   - start: Starts the service immediately when `true` (the default). Pass `false` to
    ///     configure now and call `start()` later.
    ///   - onSync: Called on every time-sync event, once per `SNTP` instance (registering a
    ///     new instance replaces any previous callback — see "Non-obvious patterns").
    /// - Throws: `PlatformError` if the session can't be initialized (including when another
    ///   `SNTP` instance is already active).
    public init(
        server: String,
        smoothSync: Bool = false,
        waitForSync: Bool = true,
        start: Bool = true,
        onSync: ((timeval) -> Void)? = nil
    ) throws(PlatformError) {
        guard let serverCopy = strdup(server) else {
            throw .espError(ESP_ERR_NO_MEM)
        }

        var config = esp_sntp_config_t(server: serverCopy)
        config.smooth_sync = smoothSync
        config.wait_for_sync = waitForSync
        config.start = start
        if onSync != nil {
            config.sync_cb = { tv in
                if let tv { SNTP.syncHandler?(tv.pointee) }
            }
        }

        do {
            try esp_netif_sntp_init(&config).throwEspError {
                log.w("esp_netif_sntp_init(\(server)) failed: \($0.name)")
            }
        } catch {
            free(serverCopy)
            throw error
        }
        // `self.server` and the trampoline are only wired up once init succeeded: assigning
        // either earlier would let a throw (e.g. because a prior instance is still active)
        // run `deinit` on a partially-initialized `self` — double-freeing `serverCopy` and
        // tearing down that still-live prior instance's session and handler.
        self.server = serverCopy
        Self.syncHandler = onSync
    }

    deinit {
        esp_netif_sntp_deinit()
        // esp_netif_sntp_deinit() stops SNTP but leaves lwIP's server-name pointer set —
        // clear it before freeing so a stray esp_sntp_getservername(0) can't read freed memory.
        esp_sntp_setservername(0, nil)
        Self.syncHandler = nil
        free(server)
    }

    /// Starts the SNTP service, or restarts it if already running.
    public func start() throws(PlatformError) {
        try esp_netif_sntp_start().throwEspError { log.w("esp_netif_sntp_start failed: \($0.name)") }
    }

    /// Blocks until the first time sync completes, or `timeoutMs` elapses (`nil` waits forever).
    ///
    /// - Throws: `PlatformError` wrapping `ESP_ERR_INVALID_STATE` if this instance was created
    ///   with `waitForSync: false`; `ESP_ERR_TIMEOUT` if `timeoutMs` elapses first;
    ///   `ESP_ERR_NOT_FINISHED` if a smooth sync is still in progress (call again, or poll
    ///   `esp_sntp_get_sync_status()` from the re-exported raw API).
    public func waitForSync(timeoutMs: UInt32? = nil) throws(PlatformError) {
        try esp_netif_sntp_sync_wait(TickType_t(ms: timeoutMs)).throwEspError {
            log.w("esp_netif_sntp_sync_wait failed: \($0.name)")
        }
    }
}

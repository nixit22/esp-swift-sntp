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

import Platform
import SNTP

// This test-app has no Wi-Fi credentials to connect with, so it never actually reaches an
// NTP server — it exercises the wrapper's API surface (init/start/wait/deinit, config
// construction, the sync callback plumbing) and confirms `waitForSync` times out cleanly
// rather than hanging or crashing when no sync ever arrives.
func testSNTP(logger: Logger) {
    do {
        try esp_netif_init().throwEspError { logger.e("esp_netif_init failed: \($0.name)") }
        try esp_event_loop_create_default().throwEspError {
            logger.e("esp_event_loop_create_default failed: \($0.name)")
        }
    } catch {
        logger.e("SNTP: netif/event bring-up failed: \(error.name)")
        return
    }

    do {
        let sntp = try SNTP(server: "pool.ntp.org", start: false)
        try sntp.start()
        logger.i("SNTP: session started against pool.ntp.org")

        do {
            try sntp.waitForSync(timeoutMs: 2000)
            logger.i("SNTP: synced (unexpected without a live network, but not an error)")
        } catch {
            if case .espError(ESP_ERR_TIMEOUT) = error {
                logger.i("SNTP: waitForSync timed out as expected (no network in this test app)")
            } else {
                logger.e("SNTP: waitForSync failed unexpectedly: \(error.name)")
            }
        }
        // sntp's deinit runs here, releasing the session.
    } catch {
        logger.e("SNTP: test failed: \(error.name)")
        return
    }

    do {
        let sntp = try SNTP(server: "time.google.com", waitForSync: false) { tv in
            logger.i("SNTP: sync callback fired, tv_sec=\(tv.tv_sec)")
        }
        logger.i("SNTP: second session (with sync callback) created and torn down cleanly")
        _ = sntp
    } catch {
        logger.e("SNTP: sync-callback test failed: \(error.name)")
    }
}

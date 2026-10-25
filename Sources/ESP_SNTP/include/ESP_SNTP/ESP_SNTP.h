
/*
 * Copyright (c) 2026 Nicolas Christe
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <esp_event.h>
#include <esp_netif.h>
#include <esp_netif_sntp.h>
#include <esp_sntp.h>
#include <swift_support.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Builds a single-server `esp_sntp_config_t`, matching the `ESP_NETIF_SNTP_DEFAULT_CONFIG`
/// macro (not itself visible to Swift — it's a function-like macro, and its expansion assigns
/// through a fixed-size `servers[CONFIG_LWIP_SNTP_MAX_SERVERS]` C array, which the Clang
/// importer exposes to Swift as a same-size tuple with no ergonomic way to construct one for
/// an arbitrary count). Exposed to Swift as `esp_sntp_config_t(server:)` via `SWIFT_NAME`.
///
/// @param server NTP server hostname or IP literal, e.g. "pool.ntp.org". The pointer is stored
///   as-is by lwIP (not copied) — it must stay valid for as long as the SNTP session is active.
/// @return A populated `esp_sntp_config_t` for a single server.
SWIFT_NAME("esp_sntp_config_t(server:)")
esp_sntp_config_t esp_sntp_config_create(const char *server);

#ifdef __cplusplus
}
#endif

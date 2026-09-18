(function () {
  "use strict";

  // QuickStart's closed backend returns an empty temperature result on the
  // Qualcomm RE-SS-01 thermal-zone layout. Fill only a missing value and keep
  // the upstream response untouched when it already contains a temperature.
  var fallbackPath = "/cgi-bin/luci/admin/status/re_ss_01_cpu_temperature";
  var quickstartPaths = /\/cgi-bin\/luci\/istore\/system\/(?:status|cpu\/temperature)\/?$/;
  var originalFetch = window.fetch;

  if (typeof originalFetch !== "function" || window.__reSs01TemperatureAdapter) {
    return;
  }
  window.__reSs01TemperatureAdapter = true;

  function readFallbackTemperature() {
    return originalFetch.call(window, fallbackPath, {
      credentials: "same-origin",
      cache: "no-store"
    }).then(function (response) {
      if (!response.ok) {
        return null;
      }
      return response.json();
    }).then(function (body) {
      var value = body && body.result && Number(body.result.cpuTemperature);
      return value > 0 ? value : null;
    });
  }

  window.fetch = function (input, init) {
    var requestUrl = typeof input === "string" ? input : input && input.url;
    var pathname;

    try {
      pathname = new URL(requestUrl, window.location.href).pathname;
    } catch (error) {
      return originalFetch.call(this, input, init);
    }

    return originalFetch.call(this, input, init).then(function (response) {
      if (!quickstartPaths.test(pathname)) {
        return response;
      }

      return response.clone().json().then(function (body) {
        var current = body && body.result && Number(body.result.cpuTemperature);
        if (current > 0) {
          return response;
        }

        return readFallbackTemperature().then(function (fallback) {
          if (!fallback) {
            return response;
          }
          var merged = body || {};
          merged.result = merged.result || {};
          merged.result.cpuTemperature = fallback;
          return new Response(JSON.stringify(merged), {
            status: response.status,
            statusText: response.statusText,
            headers: response.headers
          });
        }).catch(function () {
          return response;
        });
      }).catch(function () {
        return response;
      });
    });
  };
}());

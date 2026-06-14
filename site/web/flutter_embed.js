// Boots the embedded katex_flutter engine ONCE in multi-view mode and exposes
// a small bridge (`window.__katexFlutter`) the Jaspr site uses to attach one
// Flutter view per comparison row (T-024).
//
// Mechanism: fetch the generated `flutter/flutter_bootstrap.js` (which both
// defines the Flutter loader AND sets `_flutter.buildConfig` — pinned to the
// SDK + this build's `engineRevision`), but strip its trailing auto
// `_flutter.loader.load(...)` call so we can drive the loader ourselves in
// MULTI-VIEW mode. Then `initializeEngine({multiViewEnabled:true})` -> runApp(),
// and expose:
//   __katexFlutter.add(hostEl, {tex, displayMode, fontSize}) -> Promise<viewId>
//   __katexFlutter.remove(viewId)
// Calls made before the engine is ready are queued and flushed on ready.
//
// Fetching the generated bootstrap (rather than hardcoding buildConfig) keeps
// this robust across `flutter build web` rebuilds — the engineRevision and
// build descriptor always come from the freshly-built bundle.
(function () {
  "use strict";

  // The running app handle (set once the engine + app are ready).
  var app = null;
  // Registrations queued before `app` exists: {hostEl, data, resolve}.
  var pending = [];

  function doAdd(hostEl, data) {
    // Flutter 3.44: app.addView({hostElement, initialData}) -> viewId (number).
    return app.addView({ hostElement: hostEl, initialData: data });
  }

  // Public bridge. `add` always returns a Promise<viewId> so callers needn't
  // care whether the engine was ready yet.
  window.__katexFlutter = {
    ready: false,
    add: function (hostEl, data) {
      if (app) {
        return Promise.resolve(doAdd(hostEl, data));
      }
      return new Promise(function (resolve) {
        pending.push({ hostEl: hostEl, data: data, resolve: resolve });
      });
    },
    remove: function (viewId) {
      if (app && viewId != null) {
        app.removeView(viewId);
      }
    },
  };

  function flush() {
    var queued = pending;
    pending = [];
    queued.forEach(function (item) {
      item.resolve(doAdd(item.hostEl, item.data));
    });
  }

  function startLoad() {
    window._flutter.loader.load({
      // Resolve engine assets under /flutter/. The Jaspr page is served at /,
      // so without assetBase the engine fetches assets/FontManifest.json + the
      // bundled KaTeX_* fonts from the page root (/assets/...) and 404s — the
      // Math widgets then fall back to a non-KaTeX font and misalign. assetBase
      // points runtime asset loads (FontManifest, fonts, AssetManifest) at
      // flutter/assets/.
      config: {
        assetBase: "flutter/",
        entrypointBaseUrl: "flutter/",
        canvasKitBaseUrl: "flutter/canvaskit/",
      },
      onEntrypointLoaded: function (engineInitializer) {
        engineInitializer
          .initializeEngine({ multiViewEnabled: true })
          .then(function (appRunner) {
            return appRunner.runApp();
          })
          .then(function (runningApp) {
            app = runningApp;
            window.__katexFlutter.ready = true;
            flush();
          })
          .catch(function (err) {
            // Surface init failures in the console for debugging.
            console.error("[katex_flutter] engine init failed:", err);
          });
      },
    });
  }

  // Fetch the generated bootstrap, strip its trailing auto-load call, eval the
  // rest (defines the loader + sets buildConfig), then drive load() ourselves.
  fetch("flutter/flutter_bootstrap.js")
    .then(function (r) {
      return r.text();
    })
    .then(function (src) {
      // Remove the trailing `_flutter.loader.load(...)` auto-run so the engine
      // does not boot in single-view mode before we configure multi-view. The
      // call is the last statement in the generated bootstrap, so truncate at
      // its start.
      var marker = "_flutter.loader.load(";
      var idx = src.lastIndexOf(marker);
      var stripped = idx >= 0 ? src.slice(0, idx) : src;
      // eslint-disable-next-line no-eval
      (0, eval)(stripped);
      if (window._flutter && window._flutter.loader && window._flutter.buildConfig) {
        startLoad();
      } else {
        console.error("[katex_flutter] bootstrap parse did not set loader/buildConfig");
      }
    })
    .catch(function (err) {
      console.error("[katex_flutter] failed to load flutter bootstrap:", err);
    });
})();

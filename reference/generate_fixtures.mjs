// generate_fixtures.mjs
//
// Reference oracle for the "Port KaTeX to Dart" project (ticket T-002).
//
// For every entry in gallery.json this script produces, using ORIGINAL KaTeX
// (pinned in pin.json) as the ground truth:
//
//   1. fixtures/png/<id>.png      — KaTeX rendered in a headless browser and
//                                   screenshotted at a fixed devicePixelRatio (2).
//   2. fixtures/metrics/<id>.json — KaTeX's own internal box-tree height/depth/width
//                                   (in em units) for the root and key sub-boxes,
//                                   plus the rendered pixel bounding box of `.katex`.
//
// METRICS EXTRACTION APPROACH
// ---------------------------
// KaTeX exposes an internal `katex.__renderToDomTree(tex, settings)` which returns a
// tree of domTree `Span`/`Anchor`/`SymbolNode`/... objects. Each node carries
// `.height` / `.depth` / `.width` in em units (the same numbers KaTeX uses to lay
// boxes out). These are the numbers the Dart box tree must reproduce, font-free.
//
// We therefore use `__renderToDomTree` as the PRIMARY metrics source. We deliberately
// walk only the `.katex-html` subtree (the visual box tree); the parallel
// `.katex-mathml` subtree is MathML and carries no usable height/depth/width, so it is
// skipped. `width` is frequently `undefined` in KaTeX's domTree (KaTeX advances most
// horizontal lists via CSS, not explicit widths) — we record it as `null` when absent.
//
// As a complementary signal (and the documented fallback path, should
// `__renderToDomTree` ever be unavailable), we ALSO capture the rendered `.katex`
// element's pixel bounding box from the live DOM via getBoundingClientRect(). That
// pixel box is recorded under `pixelBox`; if `__renderToDomTree` is missing the script
// still emits a metrics file containing `pixelBox` plus a `fallback: true` marker.
//
// DETERMINISM
// -----------
// - Object keys in every emitted JSON are sorted recursively before serialization.
// - Fixed viewport + devicePixelRatio (2), animations/transitions/caret disabled.
// - Numbers are rounded to a fixed precision so floating-point tails don't churn bytes.
// - The gallery is processed in file order.
// Running this script twice produces byte-identical metrics JSON.

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import katex from "katex";
import puppeteer from "puppeteer";

const __dirname = dirname(fileURLToPath(import.meta.url));

const DPR = 2;                 // fixed devicePixelRatio for screenshots
const VIEWPORT = { width: 1200, height: 800 };
const METRIC_PRECISION = 5;    // decimal places for em-unit metrics
const PIXEL_PRECISION = 3;     // decimal places for pixel bounding boxes

const KATEX_DIST = join(__dirname, "node_modules", "katex", "dist");
const CSS_PATH = join(KATEX_DIST, "katex.min.css");
const FONTS_DIR = join(KATEX_DIST, "fonts");

const PNG_DIR = join(__dirname, "fixtures", "png");
const METRICS_DIR = join(__dirname, "fixtures", "metrics");

function round(n, places) {
  if (typeof n !== "number" || !Number.isFinite(n)) return null;
  const f = 10 ** places;
  // Normalize -0 to 0 for stable output.
  return (Math.round(n * f) / f) + 0;
}

// Recursively sort object keys so JSON serialization is byte-stable.
function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === "object") {
    const out = {};
    for (const key of Object.keys(value).sort()) out[key] = sortKeys(value[key]);
    return out;
  }
  return value;
}

function stableStringify(obj) {
  return JSON.stringify(sortKeys(obj), null, 2) + "\n";
}

// Walk a KaTeX domTree node, emitting metrics for nodes that carry layout
// dimensions. We descend only the visual subtree and skip the MathML branch.
function walkBox(node, path, out) {
  if (!node || typeof node !== "object") return;

  const classes = Array.isArray(node.classes) ? node.classes : [];

  // Skip the MathML accessibility branch entirely — it carries no box metrics.
  if (classes.includes("katex-mathml")) return;

  const type = node.constructor ? node.constructor.name : "Unknown";
  const hasMetrics =
    typeof node.height === "number" ||
    typeof node.depth === "number" ||
    typeof node.width === "number";

  if (hasMetrics) {
    out.push({
      path,
      type,
      classes,
      height: round(node.height, METRIC_PRECISION),
      depth: round(node.depth, METRIC_PRECISION),
      width: round(node.width, METRIC_PRECISION),
    });
  }

  const children = Array.isArray(node.children) ? node.children : [];
  children.forEach((child, i) => {
    const childClasses = (child && Array.isArray(child.classes)) ? child.classes : [];
    const label = childClasses.length ? childClasses.join(".") : (child && child.constructor ? child.constructor.name : "node");
    walkBox(child, `${path}/${i}:${label}`, out);
  });
}

function extractMetrics(tex, displayMode) {
  const settings = { displayMode, throwOnError: true };

  if (typeof katex.__renderToDomTree !== "function") {
    // Documented fallback: internals unavailable. The caller fills in pixelBox.
    return { fallback: true, boxes: [], note: "__renderToDomTree unavailable; metrics limited to pixelBox" };
  }

  const tree = katex.__renderToDomTree(tex, settings);
  const boxes = [];
  walkBox(tree, "root", boxes);

  return {
    fallback: false,
    root: {
      type: tree.constructor ? tree.constructor.name : "Unknown",
      classes: Array.isArray(tree.classes) ? tree.classes : [],
      height: round(tree.height, METRIC_PRECISION),
      depth: round(tree.depth, METRIC_PRECISION),
      width: round(tree.width, METRIC_PRECISION),
    },
    boxCount: boxes.length,
    boxes,
  };
}

// Load KaTeX's CSS once and rewrite its relative @font-face URLs to absolute
// file:// paths pointing at the local dist/fonts dir. We INLINE the CSS into a
// <style> tag rather than referencing it via <link href="file://...">: in headless
// Chromium a file:// stylesheet link reports as loaded but its rules silently fail
// to apply (the .katex-mathml hide rule never takes effect, leaking MathML text into
// the screenshot). Inlining applies all rules reliably and lets fonts load offline.
async function loadKatexCss() {
  let css = await readFile(CSS_PATH, "utf8");
  // KaTeX font URLs look like: url(fonts/KaTeX_Main-Regular.woff2)
  const fontsBase = `file://${FONTS_DIR}/`;
  css = css.replace(/url\(\s*(['"]?)fonts\//g, (_m, q) => `url(${q}${fontsBase}`);
  return css;
}

function pageHtml(katexCss, renderedKatexHtml) {
  // Minimal page: inline KaTeX CSS (fonts pointed at local dist/fonts), render markup.
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>${katexCss}</style>
<style>
  /* Determinism: kill animations/transitions/caret. */
  *, *::before, *::after {
    animation: none !important;
    transition: none !important;
    caret-color: transparent !important;
  }
  html, body { margin: 0; padding: 0; background: #ffffff; }
  #host { display: inline-block; padding: 8px; background: #ffffff; }
</style>
</head>
<body>
  <div id="host">${renderedKatexHtml}</div>
</body>
</html>`;
}

async function ensureDirs() {
  await mkdir(PNG_DIR, { recursive: true });
  await mkdir(METRICS_DIR, { recursive: true });
}

async function main() {
  if (!existsSync(CSS_PATH)) {
    throw new Error(`KaTeX CSS not found at ${CSS_PATH} — run \`npm install\` in reference/ first.`);
  }
  if (!existsSync(FONTS_DIR)) {
    throw new Error(`KaTeX fonts dir not found at ${FONTS_DIR}.`);
  }

  await ensureDirs();

  const katexCss = await loadKatexCss();
  const gallery = JSON.parse(await readFile(join(__dirname, "gallery.json"), "utf8"));

  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox", "--disable-lcd-text", "--force-color-profile=srgb"],
  });

  let ok = 0;
  try {
    for (const entry of gallery) {
      const { id, tex, displayMode } = entry;

      // 1. Render KaTeX HTML (ground truth markup).
      const html = katex.renderToString(tex, { displayMode, throwOnError: true });

      // 2. Extract internal box-tree metrics (primary signal).
      const metrics = extractMetrics(tex, displayMode);

      // 3. Screenshot the .katex element in a headless browser.
      const page = await browser.newPage();
      await page.setViewport({ ...VIEWPORT, deviceScaleFactor: DPR });
      await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
      await page.setContent(pageHtml(katexCss, html), { waitUntil: "load" });
      // Ensure fonts are fully loaded before measuring/screenshotting.
      await page.evaluate(async () => { await document.fonts.ready; });

      // Capture the live-DOM pixel bounding box of the .katex element
      // (complementary signal + fallback path).
      const pixelBox = await page.evaluate(() => {
        const el = document.querySelector(".katex");
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return { width: r.width, height: r.height };
      });
      if (pixelBox) {
        metrics.pixelBox = {
          width: round(pixelBox.width, PIXEL_PRECISION),
          height: round(pixelBox.height, PIXEL_PRECISION),
        };
      }
      metrics.dpr = DPR;

      const target = await page.$(".katex");
      if (!target) throw new Error(`No .katex element rendered for id=${id}`);
      await target.screenshot({ path: join(PNG_DIR, `${id}.png`), omitBackground: false });
      await page.close();

      // 4. Write deterministic metrics JSON.
      const metricsDoc = {
        id,
        tex,
        displayMode,
        katexVersion: katex.version,
        ...metrics,
      };
      await writeFile(join(METRICS_DIR, `${id}.json`), stableStringify(metricsDoc), "utf8");

      ok++;
      console.log(`  [${ok}/${gallery.length}] ${id}`);
    }
  } finally {
    await browser.close();
  }

  console.log(`\nDone: ${ok}/${gallery.length} fixtures written to fixtures/png and fixtures/metrics.`);
  console.log(`KaTeX version: ${katex.version}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

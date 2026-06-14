// pngdiff.mjs — pixelmatch-style diff for the SVG golden test (ticket T-014).
//
// Usage:
//   node pngdiff.mjs <a.png> <b.png> <out-diff.png> [threshold]
//
// Compares two PNGs of (possibly) different sizes by compositing each onto a
// common white canvas sized to the MAX of the two (top-left aligned), then runs
// pixelmatch. Prints a single line of JSON to stdout:
//   {"width":W,"height":H,"diffPixels":N,"totalPixels":T,"ratio":R}
// and writes the diff image to <out-diff.png>.
//
// NOTE ON ALIGNMENT: top-left compositing is deliberately simple. Exact visual
// alignment between our resvg/rsvg-rasterized SVG and KaTeX's browser-rendered
// PNG is not achievable in the MVP (different rasterizers, font hinting, and
// line-box padding). The ratio this prints is therefore a coarse upper-bound
// signal, reported honestly by the Dart test rather than asserted tightly.

import { readFileSync, writeFileSync } from "node:fs";
import { PNG } from "pngjs";
import pixelmatch from "pixelmatch";

const [, , aPath, bPath, outPath, thrArg] = process.argv;
const threshold = thrArg ? Number(thrArg) : 0.1;

function load(path) {
  return PNG.sync.read(readFileSync(path));
}

// Composite `src` onto a white canvas of (w,h), top-left aligned.
function onWhite(src, w, h) {
  const out = new PNG({ width: w, height: h });
  // Fill white.
  for (let i = 0; i < out.data.length; i += 4) {
    out.data[i] = 255;
    out.data[i + 1] = 255;
    out.data[i + 2] = 255;
    out.data[i + 3] = 255;
  }
  for (let y = 0; y < src.height && y < h; y++) {
    for (let x = 0; x < src.width && x < w; x++) {
      const si = (src.width * y + x) << 2;
      const di = (w * y + x) << 2;
      const a = src.data[si + 3] / 255;
      // Alpha-composite over white.
      out.data[di] = Math.round(src.data[si] * a + 255 * (1 - a));
      out.data[di + 1] = Math.round(src.data[si + 1] * a + 255 * (1 - a));
      out.data[di + 2] = Math.round(src.data[si + 2] * a + 255 * (1 - a));
      out.data[di + 3] = 255;
    }
  }
  return out;
}

const a = load(aPath);
const b = load(bPath);
const w = Math.max(a.width, b.width);
const h = Math.max(a.height, b.height);

const ca = onWhite(a, w, h);
const cb = onWhite(b, w, h);
const diff = new PNG({ width: w, height: h });

const diffPixels = pixelmatch(ca.data, cb.data, diff.data, w, h, {
  threshold,
  includeAA: false,
});

writeFileSync(outPath, PNG.sync.write(diff));

const totalPixels = w * h;
process.stdout.write(
  JSON.stringify({
    width: w,
    height: h,
    diffPixels,
    totalPixels,
    ratio: diffPixels / totalPixels,
  })
);

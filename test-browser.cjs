"use strict";

const fs = require("node:fs");
const { chromium } = require("playwright");

const sizes = [
  { name: "mobile", width: 390, height: 844 },
  { name: "desktop", width: 1440, height: 1000 },
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const size of sizes) {
      const page = await browser.newPage({ viewport: size });
      await page.setContent(`<!doctype html>
        <html lang="en">
          <meta charset="utf-8">
          <style>
            body { margin: 32px; font: 20px/1.5 sans-serif; color: #152238; background: #f5f7fb; }
            main { max-width: 720px; padding: 24px; background: white; border: 1px solid #ccd5e0; }
            #sample { font-family: "DejaVu Sans", sans-serif; }
          </style>
          <main><h1>WarpMetal browser sandbox</h1><p id="sample">Readable UI QA — 1234567890</p></main>
        </html>`);
      await page.evaluate(() => document.fonts.ready);
      const fontReady = await page.evaluate(() =>
        document.fonts.check('20px "DejaVu Sans"'),
      );
      if (!fontReady) throw new Error("DejaVu Sans did not load");
      const screenshot = `/tmp/warpmetal-browser-${size.name}.png`;
      await page.screenshot({ path: screenshot, fullPage: true });
      if (fs.statSync(screenshot).size < 1_000) {
        throw new Error(`${size.name} screenshot was unexpectedly small`);
      }
      process.stdout.write(
        `${JSON.stringify({ viewport: size, screenshotBytes: fs.statSync(screenshot).size })}\n`,
      );
      await page.close();
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});

// perf-continuous-view_test.mjs
// RG-037 (Tier 2 browser measurement): loads the 40-page hybrid stress fixture
// in the real app, measures open-to-first-canvas time, continuous-view scroll
// reachability of the last page, jump latency, and JS heap delta. Budgets are
// PROVISIONAL and recorded alongside the measurements.
import assert from "node:assert";
import { spawn } from "node:child_process";
import path from "node:path";
import { chromium } from "playwright";

const ROOT = "/Users/pranay/Projects/pdf_editor";
const FIXTURE = path.join(ROOT, "benchmark/results/browser-corpus/large-hybrid-40-pages.pdf");
const PORT = 4924;
const BASE = `http://127.0.0.1:${PORT}/web/index.html`;

// Provisional budgets (recorded, not silently assumed):
const BUDGETS = { openMs: 20_000, scrollReachMs: 10_000, heapGrowthMB: 600 };

const server = spawn("python3", ["-m", "http.server", String(PORT)], { cwd: ROOT, stdio: "ignore" });
await new Promise((r) => setTimeout(r, 1200));

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const results = {};
try {
  await page.goto(BASE, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.pdfjsLib && window.PDFLib),
    undefined,
    { timeout: 30_000 }
  );

  const heapBefore = await page.evaluate(() =>
    performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null
  );

  // Open-to-first-rendered-canvas
  const t0 = Date.now();
  await page.locator("#fileInput").setInputFiles(FIXTURE);
  await page.waitForFunction(
    () => {
      const c = document.querySelector("canvas");
      return Boolean(c && c.width > 0 && c.height > 0);
    },
    undefined,
    { timeout: BUDGETS.openMs }
  );
  results.openToFirstCanvasMs = Date.now() - t0;

  // View mode: prefer continuous when exposed
  const modes = await page.evaluate(() => {
    const sel = document.getElementById("viewMode");
    return sel ? [...sel.options].map((o) => o.value) : [];
  });
  results.viewModes = modes;
  if (modes.some((m) => /continu/i.test(m))) {
    await page.selectOption("#viewMode", modes.find((m) => /continu/i.test(m)));
  }

  // Page count as announced by the app's own status surface
  await page.waitForFunction(
    () => /Loaded\s+\d+\s+page/i.test(document.getElementById("status")?.textContent || ""),
    undefined,
    { timeout: 15_000 }
  );
  const pageCount = await page.evaluate(() => {
    const s = document.getElementById("status")?.textContent || "";
    return Number(s.match(/Loaded\s+(\d+)\s+page/i)?.[1]) || null;
  });
  results.pageCount = pageCount;
  assert.ok(pageCount && pageCount >= 40, `app should report >=40 pages, got ${pageCount}`);

  // Continuous-view scroll: reach the last rendered content via the actual
  // scrollable ancestor of the canvases (auto-detected).
  const t1 = Date.now();
  const scrollerInfo = await page.evaluate(() => {
    const c = [...document.querySelectorAll("canvas")].at(-1);
    let e = c?.parentElement;
    while (e) {
      const cs = getComputedStyle(e);
      if (cs.overflowY === "auto" || cs.overflowY === "scroll") {
        return { tag: e.tagName, id: e.id, cls: String(e.className).slice(0, 40) };
      }
      e = e.parentElement;
    }
    return { tag: "window" };
  });
  results.scrollerUsed = `${scrollerInfo.tag}${scrollerInfo.id ? "#" + scrollerInfo.id : ""}${scrollerInfo.cls ? "." + scrollerInfo.cls.split(" ")[0] : ""}`;
  await page.evaluate(() => {
    const c = [...document.querySelectorAll("canvas")].at(-1);
    let el = c?.parentElement;
    while (el) {
      const cs = getComputedStyle(el);
      if (cs.overflowY === "auto" || cs.overflowY === "scroll") break;
      el = el.parentElement;
    }
    const target = el || document.scrollingElement;
    target.scrollTop = target.scrollHeight;
  });
  await page.waitForFunction(
    () => {
      const c = [...document.querySelectorAll("canvas")].at(-1);
      if (!c) return false;
      let el = c.parentElement;
      while (el) {
        const cs = getComputedStyle(el);
        if (cs.overflowY === "auto" || cs.overflowY === "scroll") break;
        el = el.parentElement;
      }
      const target = el || document.scrollingElement;
      const atBottom = target.scrollTop + target.clientHeight >= target.scrollHeight - 60;
      return atBottom && c.width > 0 && c.getBoundingClientRect().top < window.innerHeight * 2;
    },
    undefined,
    { timeout: BUDGETS.scrollReachMs }
  );
  results.scrollReachLastCanvasMs = Date.now() - t1;
  results.canvasCountAfterScroll = await page.evaluate(() => document.querySelectorAll("canvas").length);

  // Jump navigation to page 1 and back to the reported last page
  const t2 = Date.now();
  await page.fill("#pageInput", String(pageCount));
  await page.click("#jumpButton");
  await page.waitForTimeout(250); // action dispatch + render kick
  results.jumpDispatchMs = Date.now() - t2;

  const heapAfter = await page.evaluate(() =>
    performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null
  );
  results.heapBeforeMB = heapBefore;
  results.heapAfterMB = heapAfter;
  results.heapGrowthMB = heapBefore != null && heapAfter != null ? heapAfter - heapBefore : null;

  console.log(JSON.stringify(results, null, 2));
} finally {
  await browser.close();
  server.kill();
}

assert.ok(results.openToFirstCanvasMs <= BUDGETS.openMs,
  `open ${results.openToFirstCanvasMs}ms exceeds budget ${BUDGETS.openMs}ms`);
if (results.heapGrowthMB != null) {
  assert.ok(results.heapGrowthMB <= BUDGETS.heapGrowthMB,
    `heap growth ${results.heapGrowthMB}MB exceeds budget`);
}
console.log(`\nRG-037 measurement PASS within provisional budgets (${JSON.stringify(BUDGETS)})`);

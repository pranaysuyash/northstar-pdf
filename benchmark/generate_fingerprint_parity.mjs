import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  FINGERPRINT_PARITY_CONTRACT,
  fingerprintReportForBundles
} from "../web/pdf-fingerprint-parity.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const resultRoot = path.resolve(
  projectRoot,
  process.env.PDF_FINGERPRINT_RESULT_ROOT || "benchmark/results/semantic-parity/2026-08-25"
);
const nativeRoot = path.join(resultRoot, "native");
const browserRoot = path.join(resultRoot, "web");
const fixturePath = path.join(
  projectRoot,
  process.env.PDF_FINGERPRINT_FIXTURE_PATH || "Tests/fixtures/pdf_fingerprint_parity_fixture.json"
);
const reportPath = path.join(resultRoot, "fingerprint-parity-report.json");

function readBundles(directory) {
  return fs.readdirSync(directory)
    .filter((file) => file.endsWith(".json") && file !== "summary.json")
    .map((file) => JSON.parse(fs.readFileSync(path.join(directory, file), "utf8")));
}

function populationFor(sourcePath) {
  if (sourcePath.includes("rotated-form6") || sourcePath.includes("form6-run")) return "static-form6-candidates";
  if (sourcePath.includes("browser-corpus/scanned")) return "scanned-raster";
  if (sourcePath.includes("browser-corpus/rotated")) return "rotated-hybrid-form";
  if (sourcePath.includes("browser-corpus/encrypted")) return "encrypted-hybrid-form";
  if (sourcePath.includes("browser-corpus/malformed") || sourcePath.includes("truncated")) return "malformed-input";
  if (sourcePath.includes("large-hybrid")) return "large-hybrid-resource-stress";
  if (sourcePath.includes("governed-corpus/handwritten")) return "handwriting-like-raster";
  if (sourcePath.includes("navigation")) return "navigation-metadata";
  if (sourcePath.includes("ocr-corpus")) return "printed-scan";
  if (sourcePath.includes("public-sample") || sourcePath.includes("public-acroform")) return "native-acroform";
  if (sourcePath.includes("pdfkit-widgets") || sourcePath.includes("rotated-widget")) return "widget-form";
  if (sourcePath.includes("repeated-20")) return "repeated-widget-form";
  return "other";
}

const nativeBundles = readBundles(nativeRoot);
const browserBundles = Object.fromEntries(readBundles(browserRoot).map((bundle) => [bundle.sourcePath, bundle]));
const cases = nativeBundles
  .map((nativeBundle, index) => {
    const sourcePath = nativeBundle.sourcePath;
    const browserBundle = browserBundles[sourcePath];
    if (!browserBundle) throw new Error(`Browser bundle missing for ${sourcePath}`);
    const report = fingerprintReportForBundles({ sourcePath, nativeBundle, browserBundle });
    return {
      id: `FINGERPRINT-${String(index + 1).padStart(3, "0")}`,
      sourcePath,
      population: populationFor(sourcePath),
      sourceDigest: report.sourceDigest,
      expectedFailure: report.expectedFailure,
      native: report.native,
      browser: report.browser,
      comparison: report.comparison
    };
  });

const clusterMap = new Map();
for (const entry of cases) {
  for (const feature of entry.comparison.features) {
    if (feature.status === "agree") continue;
    const key = `${feature.id}:${feature.status}`;
    const cluster = clusterMap.get(key) || {
      featureID: feature.id,
      status: feature.status,
      fixtureCount: 0,
      fixtures: [],
      populations: {}
    };
    cluster.fixtureCount += 1;
    cluster.fixtures.push(entry.sourcePath);
    cluster.populations[entry.population] = (cluster.populations[entry.population] || 0) + 1;
    clusterMap.set(key, cluster);
  }
}

const featureDivergenceClusters = [...clusterMap.values()]
  .map((cluster) => ({
    ...cluster,
    populations: Object.fromEntries(Object.entries(cluster.populations).sort(([left], [right]) => left.localeCompare(right)))
  }))
  .sort((left, right) => right.fixtureCount - left.fixtureCount || left.featureID.localeCompare(right.featureID));

const aggregate = {
  fixtureCount: cases.length,
  equalCount: cases.filter((entry) => entry.comparison.status === "equal").length,
  representationDifferenceOnlyCount: cases.filter((entry) => entry.comparison.status === "representation-difference").length,
  semanticDivergenceCount: cases.filter((entry) => entry.comparison.status === "semantic-divergence").length,
  mixedDivergenceCount: cases.filter((entry) => entry.comparison.status === "mixed-divergence").length,
  divergentFeatureCounts: featureDivergenceClusters.reduce((counts, cluster) => {
    counts[cluster.featureID] = (counts[cluster.featureID] || 0) + cluster.fixtureCount;
    return counts;
  }, {})
};

const fixture = {
  harness: "pdf-editor-native-web-structural-fingerprint-parity",
  contract: FINGERPRINT_PARITY_CONTRACT,
  generatedFrom: {
    nativeDirectory: path.relative(projectRoot, nativeRoot),
    browserDirectory: path.relative(projectRoot, browserRoot),
    sourceBundlesOnly: true,
    rawLabelsRetained: false,
    providerIDsRetained: false,
    timestampsRetained: false,
    outputDigestsRetained: false
  },
  cases
};

const report = {
  harness: "pdf-editor-native-web-structural-fingerprint-parity",
  contract: FINGERPRINT_PARITY_CONTRACT,
  corpusRoot: path.relative(projectRoot, resultRoot),
  aggregate,
  featureDivergenceClusters,
  cases: cases.map((entry) => ({
    id: entry.id,
    sourcePath: entry.sourcePath,
    population: entry.population,
    sourceDigest: entry.sourceDigest,
    expectedFailure: entry.expectedFailure,
    status: entry.comparison.status,
    divergentFeatureIDs: entry.comparison.divergentFeatureIDs,
    semanticDivergenceFeatureIDs: entry.comparison.semanticDivergenceFeatureIDs,
    representationDifferenceFeatureIDs: entry.comparison.representationDifferenceFeatureIDs
  }))
};

for (const outputPath of [fixturePath, reportPath]) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
}
fs.writeFileSync(fixturePath, `${JSON.stringify(fixture, null, 2)}\n`);
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
process.stdout.write(`${JSON.stringify({ fixturePath: path.relative(projectRoot, fixturePath), reportPath: path.relative(projectRoot, reportPath), aggregate }, null, 2)}\n`);

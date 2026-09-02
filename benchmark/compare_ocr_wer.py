#!/usr/bin/env python3
"""
Cross-provider OCR Word Error Rate (WER) benchmark.

Providers:
  1. Tesseract 5.5.0 (via pytesseract)
  2. PaddleOCR PP-OCRv6 (via paddleocr)
  3. Marker / Surya (via marker_wrapper.py)
  4. Apple Vision framework (via pdf-vision-ocr Swift CLI)

Usage:
  .venv/bin/python benchmark/compare_ocr_wer.py            # benchmark run
  .venv/bin/python benchmark/compare_ocr_wer.py --gate     # CI gate vs baseline

Ground truth fixtures live in benchmark/results/ocr-corpus/*.pdf
with matching *.gt.txt files.
"""

import os
import re
import sys
import time
import subprocess
import json
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ---------------------------------------------------------------------------
# CI gate configuration (RG-136)
# ---------------------------------------------------------------------------

# Per-provider maximum tolerated average WER. A provider missing from this
# map is not gated (provenance is still recorded in the artifact).
GATE_WER_THRESHOLDS = {
    "Tesseract 5.5.0": 0.10,     # clean-print baseline: measured 0.0-0.019
    "Apple Vision": 0.10,        # measured 0.0 on all ground-truth fixtures
}

# PaddleOCR's multi-column reading-order confusion (WER 0.73 measured on
# multi-column) makes its corpus average dominated by layout, not engine
# quality. These per-fixture targets are recorded in the gate report as
# ADVISORY provenance (not enforced); enforcement lands together with
# reading-order post-processing, otherwise the gate would block on a known,
# documented layout limitation rather than a regression.
GATE_WER_THRESHOLDS_PER_FIXTURE = {
    "PaddleOCR PP-OCRv6": {
        "clean-english": 0.10,
        "printed-scan": 0.20,
    }
}

# Absolute WER regression (in points) vs baseline tolerated before failing,
# to absorb renderer/anti-aliasing nondeterminism between runs.
GATE_REGRESSION_TOLERANCE = 0.05

# Minimum number of gate-thresholded providers that must actually run in a
# session for the gate verdict to count. Below this, the gate is 'skipped'.
GATE_MIN_PROVIDERS = 1

BASELINE_ARTIFACT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "results", "ocr-corpus", "ocr-wer-baseline.json",
)
GATE_REPORT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "results", "ocr-corpus", "ocr-wer-gate-report.json",
)

# ---------------------------------------------------------------------------
# Levenshtein distance for WER/CER
# ---------------------------------------------------------------------------

def levenshtein(a: List[str], b: List[str]) -> int:
    """Standard dynamic-programming Levenshtein distance."""
    n, m = len(a), len(b)
    dp = list(range(m + 1))
    for i in range(1, n + 1):
        prev = dp[0]
        dp[0] = i
        for j in range(1, m + 1):
            temp = dp[j]
            if a[i - 1] == b[j - 1]:
                dp[j] = prev
            else:
                dp[j] = 1 + min(prev, dp[j], dp[j - 1])
            prev = temp
    return dp[m]


def word_error_rate(reference: str, hypothesis: str) -> float:
    ref_words = reference.split()
    hyp_words = hypothesis.split()
    if len(ref_words) == 0:
        return 1.0 if len(hyp_words) > 0 else 0.0
    return levenshtein(ref_words, hyp_words) / len(ref_words)


def char_error_rate(reference: str, hypothesis: str) -> float:
    ref_chars = list(reference.replace(" ", ""))
    hyp_chars = list(hypothesis.replace(" ", ""))
    if len(ref_chars) == 0:
        return 1.0 if len(hyp_chars) > 0 else 0.0
    return levenshtein(ref_chars, hyp_chars) / len(ref_chars)


def normalize(text: str) -> str:
    """Normalize OCR output for fair comparison."""
    text = text.lower().strip()
    text = re.sub(r'\s+', ' ', text)
    return text


# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

class TesseractProvider:
    name = "Tesseract 5.5.0"
    
    def extract_from_pdf(self, pdf_path: str) -> Tuple[str, float]:
        """Extract text from PDF via pdftotext + tesseract on images."""
        import pytesseract
        from PIL import Image
        import subprocess
        
        # Convert PDF pages to images, then OCR each
        tmp_dir = f"/tmp/ocr-bench-tess-{os.getpid()}"
        os.makedirs(tmp_dir, exist_ok=True)
        
        # Use pdftoppm to convert PDF to images
        prefix = os.path.join(tmp_dir, "page")
        subprocess.run(
            ["pdftoppm", "-png", "-r", "300", pdf_path, prefix],
            capture_output=True, timeout=30
        )
        
        all_text = []
        total_conf = 0.0
        total_words = 0
        
        for img_file in sorted(Path(tmp_dir).glob("page-*.png")):
            img = Image.open(img_file)
            result = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
            words = []
            confs = []
            for i, conf in enumerate(result['conf']):
                if int(conf) > 0 and result['text'][i].strip():
                    words.append(result['text'][i])
                    confs.append(float(conf))
            all_text.append(' '.join(words))
            if confs:
                avg_conf = sum(confs) / len(confs)
                total_conf += avg_conf * len(confs)
                total_words += len(confs)
        
        text = '\n'.join(all_text)
        confidence = total_conf / total_words if total_words > 0 else 0.0
        
        # Cleanup
        import shutil
        shutil.rmtree(tmp_dir, ignore_errors=True)
        
        return text, confidence
    
    def extract_from_image(self, image_path: str) -> Tuple[str, float]:
        import pytesseract
        from PIL import Image
        img = Image.open(image_path)
        result = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
        words = []
        confs = []
        for i, conf in enumerate(result['conf']):
            if int(conf) > 0 and result['text'][i].strip():
                words.append(result['text'][i])
                confs.append(float(conf))
        text = ' '.join(words)
        confidence = sum(confs) / len(confs) if confs else 0.0
        return text, confidence


class PaddleOCRProvider:
    name = "PaddleOCR PP-OCRv6"
    
    def __init__(self):
        self._ocr = None
    
    def _get_ocr(self):
        if self._ocr is None:
            os.environ['PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK'] = 'True'
            from paddleocr import PaddleOCR
            self._ocr = PaddleOCR(use_textline_orientation=True, lang='en')
        return self._ocr
    
    def extract_from_pdf(self, pdf_path: str) -> Tuple[str, float]:
        import subprocess
        import shutil
        
        # Convert PDF to images first
        tmp_dir = f"/tmp/ocr-bench-paddle-{os.getpid()}"
        os.makedirs(tmp_dir, exist_ok=True)
        prefix = os.path.join(tmp_dir, "page")
        subprocess.run(
            ["pdftoppm", "-png", "-r", "300", pdf_path, prefix],
            capture_output=True, timeout=30
        )
        
        ocr = self._get_ocr()
        all_text = []
        total_conf = 0.0
        total_count = 0
        
        for img_file in sorted(Path(tmp_dir).glob("page-*.png")):
            result = ocr.predict(str(img_file))
            if result and len(result) > 0:
                for page_result in result:
                    texts = page_result.get('rec_texts', []) if isinstance(page_result, dict) else getattr(page_result, 'rec_texts', [])
                    scores = page_result.get('rec_scores', []) if isinstance(page_result, dict) else getattr(page_result, 'rec_scores', [])
                    for txt, conf in zip(texts, scores):
                        all_text.append(txt)
                        total_conf += conf
                        total_count += 1
        
        text = '\n'.join(all_text)
        confidence = (total_conf / total_count * 100) if total_count > 0 else 0.0
        
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return text, confidence
    
    def extract_from_image(self, image_path: str) -> Tuple[str, float]:
        ocr = self._get_ocr()
        result = ocr.predict(image_path)
        all_text = []
        total_conf = 0.0
        total_count = 0
        
        if result and len(result) > 0:
            for page_result in result:
                texts = page_result.get('rec_texts', []) if isinstance(page_result, dict) else getattr(page_result, 'rec_texts', [])
                scores = page_result.get('rec_scores', []) if isinstance(page_result, dict) else getattr(page_result, 'rec_scores', [])
                for txt, conf in zip(texts, scores):
                    all_text.append(txt)
                    total_conf += conf
                    total_count += 1
        
        text = '\n'.join(all_text)
        confidence = (total_conf / total_count * 100) if total_count > 0 else 0.0
        return text, confidence


class MarkerProvider:
    """Marker PDF→Markdown converter with Surya OCR backbone."""
    name = "Marker (Surya)"

    def _find_wrapper(self) -> Optional[str]:
        """Find the marker_wrapper.py script."""
        candidates = [
            os.path.join(os.path.dirname(__file__), "marker_wrapper.py"),
            "benchmark/marker_wrapper.py",
        ]
        for p in candidates:
            if os.path.exists(p):
                return p
        return None

    def extract_from_pdf(self, pdf_path: str) -> Tuple[str, float]:
        wrapper = self._find_wrapper()
        if wrapper is None:
            return "", 0.0
        venv_python = os.path.join(
            os.path.dirname(__file__), "datasets", ".venv", "bin", "python3"
        )
        python_bin = venv_python if os.path.exists(venv_python) else sys.executable
        try:
            result = subprocess.run(
                [python_bin, wrapper, pdf_path],
                capture_output=True, text=True, timeout=120
            )
            text = result.stdout.strip()
            # Marker produces Markdown; confidence is not provider-reported
            # so we estimate from text length vs empty
            confidence = 95.0 if text else 0.0
            return text, confidence
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return "", 0.0

    def extract_from_image(self, image_path: str) -> Tuple[str, float]:
        # Marker works on PDFs, not raw images; skip
        return "", 0.0


class VisionProvider:
    """Apple Vision framework via the pdf-vision-ocr Swift CLI."""
    name = "Apple Vision"
    
    def _find_cli(self) -> Optional[str]:
        """Find the pdf-vision-ocr binary (SwiftPM product/target names)."""
        candidates = [
            "/tmp/pdf-vision-ocr",
            ".build/debug/PDFVisionOCRCLI",
            ".build/release/PDFVisionOCRCLI",
            ".build/debug/pdf-vision-ocr",
            ".build/release/pdf-vision-ocr",
        ]
        for p in candidates:
            if os.path.exists(p) and os.access(p, os.X_OK):
                return p
        return None
    
    def extract_from_pdf(self, pdf_path: str) -> Tuple[str, float]:
        cli = self._find_cli()
        if cli is None:
            return "", 0.0
        
        try:
            result = subprocess.run(
                [cli, pdf_path],
                capture_output=True, text=True, timeout=60
            )
            lines = result.stdout.strip().split('\n') if result.stdout.strip() else []
            texts = []
            confs = []
            for line in lines:
                try:
                    entry = json.loads(line)
                    texts.append(entry.get('text', ''))
                    confs.append(entry.get('confidence', 0) * 100)
                except json.JSONDecodeError:
                    continue
            text = '\n'.join(texts)
            confidence = sum(confs) / len(confs) if confs else 0.0
            return text, confidence
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return "", 0.0
    
    def extract_from_image(self, image_path: str) -> Tuple[str, float]:
        cli = self._find_cli()
        if cli is None:
            return "", 0.0
        try:
            result = subprocess.run(
                [cli, image_path],
                capture_output=True, text=True, timeout=30
            )
            lines = result.stdout.strip().split('\n') if result.stdout.strip() else []
            texts = []
            confs = []
            for line in lines:
                try:
                    entry = json.loads(line)
                    texts.append(entry.get('text', ''))
                    confs.append(entry.get('confidence', 0) * 100)
                except json.JSONDecodeError:
                    continue
            text = '\n'.join(texts)
            confidence = sum(confs) / len(confs) if confs else 0.0
            return text, confidence
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return "", 0.0


# ---------------------------------------------------------------------------
# Main benchmark
# ---------------------------------------------------------------------------

def find_fixtures(corpus_dir: str) -> List[Tuple[str, str, str]]:
    """Find all fixture PDFs with matching ground truth files."""
    fixtures = []
    pdf_files = sorted(Path(corpus_dir).glob("*.pdf"))
    for pdf_path in pdf_files:
        gt_path = pdf_path.with_suffix('.gt.txt')
        if gt_path.exists():
            fixture_id = pdf_path.stem
            ground_truth = gt_path.read_text().strip()
            fixtures.append((fixture_id, str(pdf_path), ground_truth))
    return fixtures


def run_benchmark(corpus_dir: str, provider_filter: Optional[str] = None):
    """Run the full cross-provider OCR benchmark.

    provider_filter: optional substring match on provider names (e.g.
    'Tesseract,Vision') to limit the run — used for fast baseline updates
    when heavy providers are not needed.
    """
    """Run the full cross-provider OCR benchmark."""
    fixtures = find_fixtures(corpus_dir)
    if not fixtures:
        print(f"No fixtures found in {corpus_dir}")
        sys.exit(1)
    
    print(f"Found {len(fixtures)} fixtures with ground truth\n")
    
    # Initialize providers
    providers = []
    
    # Tesseract (always available)
    try:
        import pytesseract
        providers.append(TesseractProvider())
        print("✅ Tesseract provider ready")
    except ImportError:
        print("⚠️  pytesseract not installed, skipping Tesseract")
    
    # PaddleOCR
    try:
        paddle = PaddleOCRProvider()
        providers.append(paddle)
        print("✅ PaddleOCR provider ready")
    except ImportError:
        print("⚠️  paddleocr not installed, skipping PaddleOCR")
    
    # Marker (optional — requires venv with marker-pdf)
    marker = MarkerProvider()
    if marker._find_wrapper():
        providers.append(marker)
        print("✅ Marker (Surya) provider ready")
    else:
        print("⚠️  marker_wrapper.py not found, skipping Marker")
    
    # Apple Vision (optional)
    vision = VisionProvider()
    if vision._find_cli():
        providers.append(vision)
        print("✅ Apple Vision provider ready")
    else:
        print("⚠️  PDFOCRBenchmark CLI not found, skipping Vision")
    
    if not providers:
        print("No providers available!")
        sys.exit(1)

    if provider_filter:
        needles = [n.strip().lower() for n in provider_filter.split(",") if n.strip()]
        providers = [p for p in providers if any(n in p.name.lower() for n in needles)]
        if not providers:
            print(f"No providers match filter: {provider_filter}")
            sys.exit(1)

    print(f"\nRunning {len(providers)} providers × {len(fixtures)} fixtures...\n")
    
    # Run benchmark
    results = []
    
    for provider in providers:
        print(f"\n{'='*60}")
        print(f"Provider: {provider.name}")
        print(f"{'='*60}")
        
        for fixture_id, pdf_path, ground_truth in fixtures:
            gt_norm = normalize(ground_truth)
            
            start = time.time()
            try:
                text, confidence = provider.extract_from_pdf(pdf_path)
                latency_ms = (time.time() - start) * 1000
                text_norm = normalize(text)
                wer = word_error_rate(gt_norm, text_norm)
                cer = char_error_rate(gt_norm, text_norm)
                status = "OK"
            except Exception as e:
                latency_ms = (time.time() - start) * 1000
                text = ""
                confidence = 0.0
                wer = 1.0
                cer = 1.0
                status = f"ERROR: {e}"
            
            result = {
                "provider": provider.name,
                "fixture": fixture_id,
                "wer": wer,
                "cer": cer,
                "confidence": confidence,
                "latency_ms": latency_ms,
                "status": status,
                "text_length": len(text),
                "gt_length": len(ground_truth),
            }
            results.append(result)
            
            wer_str = f"{wer*100:.1f}%"
            cer_str = f"{cer*100:.1f}%"
            lat_str = f"{latency_ms:.0f}ms"
            conf_str = f"{confidence:.1f}"
            
            indicator = "✅" if wer < 0.05 else ("⚠️" if wer < 0.20 else "❌")
            print(f"  {indicator} {fixture_id:25s}  WER={wer_str:6s}  CER={cer_str:6s}  "
                  f"conf={conf_str:5s}  lat={lat_str:8s}  {status}")
    
    # Summary table
    print(f"\n\n{'='*80}")
    print("SUMMARY: Average WER by Provider")
    print(f"{'='*80}")
    
    provider_stats = {}
    for r in results:
        pname = r["provider"]
        if pname not in provider_stats:
            provider_stats[pname] = {"wer": [], "cer": [], "conf": [], "lat": []}
        provider_stats[pname]["wer"].append(r["wer"])
        provider_stats[pname]["cer"].append(r["cer"])
        provider_stats[pname]["conf"].append(r["confidence"])
        provider_stats[pname]["lat"].append(r["latency_ms"])
    
    print(f"{'Provider':<25s} {'Avg WER':>10s} {'Avg CER':>10s} {'Avg Conf':>10s} {'Avg Lat':>10s}")
    print("-" * 65)
    
    for pname, stats in provider_stats.items():
        avg_wer = sum(stats["wer"]) / len(stats["wer"]) * 100
        avg_cer = sum(stats["cer"]) / len(stats["cer"]) * 100
        avg_conf = sum(stats["conf"]) / len(stats["conf"])
        avg_lat = sum(stats["lat"]) / len(stats["lat"])
        print(f"{pname:<25s} {avg_wer:>9.1f}% {avg_cer:>9.1f}% {avg_conf:>9.1f} {avg_lat:>8.0f}ms")
    
    # Per-fixture comparison
    print(f"\n\n{'='*80}")
    print("PER-FIXTURE COMPARISON")
    print(f"{'='*80}")
    
    fixture_ids = sorted(set(r["fixture"] for r in results))
    provider_names = [p.name for p in providers]
    
    header = f"{'Fixture':<25s}"
    for pname in provider_names:
        header += f" {pname:>12s}"
    print(header)
    print("-" * (25 + 14 * len(provider_names)))
    
    for fid in fixture_ids:
        row = f"{fid:<25s}"
        for pname in provider_names:
            matching = [r for r in results if r["fixture"] == fid and r["provider"] == pname]
            if matching:
                r = matching[0]
                row += f" {r['wer']*100:>11.1f}%"
            else:
                row += f" {'N/A':>12s}"
        print(row)
    
    # Save results
    output_path = os.path.join(corpus_dir, "cross-provider-wer-report.json")
    with open(output_path, 'w') as f:
        json.dump({
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "providers": provider_names,
            "fixture_count": len(fixtures),
            "results": results,
            "summary": {
                pname: {
                    "avg_wer": sum(s["wer"]) / len(s["wer"]),
                    "avg_cer": sum(s["cer"]) / len(s["cer"]),
                    "avg_confidence": sum(s["conf"]) / len(s["conf"]),
                    "avg_latency_ms": sum(s["lat"]) / len(s["lat"]),
                }
                for pname, s in provider_stats.items()
            }
        }, f, indent=2)
    
    print(f"\nResults saved to {output_path}")
    
    return results


# ---------------------------------------------------------------------------
# RG-136 CI gate: fail on WER regression vs persisted baseline
# ---------------------------------------------------------------------------

def write_baseline(results: List[dict], fixture_count: int, corpus_dir: str) -> None:
    """Persist the current run as the gate baseline (explicit, auditable act)."""
    baseline = {
        "schema": "pdf-editor.ocr-wer-baseline",
        "version": "1.0",
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "fixture_count": fixture_count,
        "results": results,
        "summary": _summary_for(results),
    }
    with open(BASELINE_ARTIFACT, "w") as f:
        json.dump(baseline, f, indent=2, sort_keys=True)
    print(f"Baseline written to {BASELINE_ARTIFACT}")


def _summary_for(results: List[dict]) -> dict:
    stats = {}
    for r in results:
        stats.setdefault(r["provider"], []).append(r["wer"])
    return {
        pname: {"avg_wer": sum(w) / len(w)}
        for pname, w in stats.items()
    }


def evaluate_gate(
    current: List[dict],
    baseline: Optional[dict],
    ran_providers: List[str],
) -> dict:
    """Compare the current run against the baseline and per-provider thresholds.

    Gate outcomes per provider:
      - 'regression' — avg WER worse than baseline by more than tolerance, or
        worse than its absolute threshold
      - 'error' — a gated provider produced only ERROR rows (engine broken)
      - 'pass' — within baseline tolerance and absolute threshold
      - 'not_ran' — provider configured but absent from this session (skipped)

    Overall verdict: 'fail' if any gated provider regressed or errored and at
    least one gated provider ran; 'skipped' if no gated provider ran; else
    'pass'. Missing (skipped) providers never fail the gate — they'd make CI
    hostage to optional heavy deps — but they are recorded as provenance.
    """
    gated = sorted(GATE_WER_THRESHOLDS.keys())
    checks = []
    for pname in gated:
        threshold = GATE_WER_THRESHOLDS[pname]
        cur_rows = [r for r in current if r["provider"] == pname]
        if not cur_rows:
            checks.append({"provider": pname, "outcome": "not_ran", "threshold": threshold})
            continue
        if all(r["status"].startswith("ERROR") for r in cur_rows):
            checks.append({
                "provider": pname, "outcome": "error", "threshold": threshold,
                "detail": cur_rows[0]["status"][:120],
            })
            continue
        cur_avg = sum(r["wer"] for r in cur_rows) / len(cur_rows)
        base_avg = None
        if baseline:
            base_rows = [r for r in baseline.get("results", []) if r["provider"] == pname]
            if base_rows:
                base_avg = sum(r["wer"] for r in base_rows) / len(base_rows)
        regressed_vs_baseline = (
            base_avg is not None
            and cur_avg > base_avg + GATE_REGRESSION_TOLERANCE
        )
        over_threshold = cur_avg > threshold
        checks.append({
            "provider": pname,
            "outcome": "regression" if (regressed_vs_baseline or over_threshold) else "pass",
            "threshold": threshold,
            "avg_wer": cur_avg,
            "baseline_avg_wer": base_avg,
            "regression_tolerance": GATE_REGRESSION_TOLERANCE,
            "regressed_vs_baseline": regressed_vs_baseline,
            "over_absolute_threshold": over_threshold,
            "fixture_count": len(cur_rows),
        })

    gated_ran = [c for c in checks if c["outcome"] not in ("not_ran",)]
    if not gated_ran:
        verdict = "skipped"
    elif any(c["outcome"] in ("regression", "error") for c in gated_ran):
        verdict = "fail"
    else:
        verdict = "pass"

    return {
        "schema": "pdf-editor.ocr-wer-gate",
        "version": "1.0",
        "verdict": verdict,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "baseline_present": baseline is not None,
        "ran_providers": ran_providers,
        "gated_providers": gated,
        "checks": checks,
        "regression_tolerance": GATE_REGRESSION_TOLERANCE,
        "per_fixture_thresholds": GATE_WER_THRESHOLDS_PER_FIXTURE,
    }


def run_gate(corpus_dir: str, update_baseline: bool = False, provider_filter: Optional[str] = None) -> int:
    """Run the benchmark, evaluate the gate, persist the report, return exit code."""
    baseline = None
    if os.path.exists(BASELINE_ARTIFACT):
        with open(BASELINE_ARTIFACT) as f:
            baseline = json.load(f)

    results = run_benchmark(corpus_dir, provider_filter=provider_filter)
    ran_providers = sorted(set(r["provider"] for r in results))

    if update_baseline:
        write_baseline(results, len(find_fixtures(corpus_dir)), corpus_dir)
        baseline = json.load(open(BASELINE_ARTIFACT))

    report = evaluate_gate(results, baseline, ran_providers)
    with open(GATE_REPORT, "w") as f:
        json.dump(report, f, indent=2, sort_keys=True)

    print(f"\n{'=' * 80}")
    print(f"RG-136 OCR WER GATE: {report['verdict'].upper()}")
    for c in report["checks"]:
        if c["outcome"] == "pass":
            print(f"  ✅ {c['provider']}: avg WER {c['avg_wer']:.3f} (threshold {c['threshold']:.2f})")
        elif c["outcome"] == "regression":
            print(f"  ❌ {c['provider']}: avg WER {c['avg_wer']:.3f} vs baseline "
                  f"{c['baseline_avg_wer'] if c['baseline_avg_wer'] is not None else 'n/a'} "
                  f"(threshold {c['threshold']:.2f})")
        elif c["outcome"] == "error":
            print(f"  ❌ {c['provider']}: engine error — {c.get('detail', '')}")
        else:
            print(f"  ⏭️  {c['provider']}: not ran (skipped) — provenance recorded")
    print(f"Gate report: {GATE_REPORT}")

    if report["verdict"] == "fail":
        print("::error::RG-136 OCR WER gate failed — WER regression detected")
        return 1
    if report["verdict"] == "skipped":
        print("::warning::RG-136 gate skipped — no gated provider ran")
        return 0
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Cross-provider OCR WER benchmark + CI gate")
    parser.add_argument("--gate", action="store_true", help="evaluate against baseline and exit nonzero on regression")
    parser.add_argument("--update-baseline", action="store_true", help="(with --gate) persist current run as the new baseline")
    parser.add_argument("--corpus-dir", default=os.path.join(os.path.dirname(__file__), "results", "ocr-corpus"))
    parser.add_argument("--providers", default="", help="comma-separated provider name filter (substring match)")
    args = parser.parse_args()

    corpus_dir = args.corpus_dir
    if args.gate:
        return run_gate(corpus_dir, update_baseline=args.update_baseline, provider_filter=args.providers or None)
    run_benchmark(corpus_dir, provider_filter=args.providers or None)
    return 0


if __name__ == "__main__":
    sys.exit(main())

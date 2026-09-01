#!/usr/bin/env python3
"""
Download DocLayNet v1.1 layout segmentation dataset.
License: CDLA-Permissive
HuggingFace: docling-project/DocLayNet-v1.1

Parquet columns: image, bboxes, category_id, segmentation, area, pdf_cells, metadata
"""

import json
import sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parent
EVAL_DIR = ROOT / "doclaynet" / "eval"
DATA_DIR = ROOT / "doclaynet" / "data"
EVAL_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

# DocLayNet category_id → name mapping (0-indexed from COCO)
CATEGORY_MAP = {
    1: "Caption", 2: "Footnote", 3: "Formula", 4: "List-item",
    5: "Page-footer", 6: "Page-header", 7: "Picture", 8: "Section-header",
    9: "Table", 10: "Text", 11: "Title",
}

def download():
    from huggingface_hub import hf_hub_download, list_repo_files
    import pyarrow.parquet as pq

    repo = "docling-project/DocLayNet-v1.1"
    files = list_repo_files(repo, repo_type="dataset")

    all_records = []

    # Download test shards
    test_files = sorted(f for f in files if f.startswith("data/test-"))
    for tf in test_files:
        print(f"[doclaynet] Downloading {tf}...")
        path = hf_hub_download(repo_id=repo, filename=tf, repo_type="dataset")
        table = pq.read_table(path)
        for i in range(len(table)):
            row = table.slice(i, 1).to_pydict()
            record = convert_row(row, index=len(all_records), split="test")
            all_records.append(record)

    # Download 1 train shard (200 pages max)
    train_files = sorted(f for f in files if f.startswith("data/train-"))
    if train_files:
        print(f"[doclaynet] Downloading train shard...")
        path = hf_hub_download(repo_id=repo, filename=train_files[0], repo_type="dataset")
        table = pq.read_table(path)
        for i in range(min(200, len(table))):
            row = table.slice(i, 1).to_pydict()
            record = convert_row(row, index=len(all_records), split="train_sample")
            all_records.append(record)

    # Save
    test_records = [r for r in all_records if r["split"] == "test"]
    train_records = [r for r in all_records if r["split"] == "train_sample"]

    with open(DATA_DIR / "test.json", "w") as f:
        json.dump(test_records, f, indent=2)
    with open(DATA_DIR / "train_sample.json", "w") as f:
        json.dump(train_records, f, indent=2)

    print(f"[doclaynet] Test: {len(test_records)} pages")
    print(f"[doclaynet] Train sample: {len(train_records)} pages")
    return test_records, train_records

def convert_row(row, index, split):
    def get(key, default=None):
        val = row.get(key, [default])
        return val[0] if val else default

    bboxes = get("bboxes", [])
    cat_ids = get("category_id", [])
    metadata = get("metadata", {})
    pdf_cells = get("pdf_cells", [])

    width = metadata.get("coco_width", 0) if isinstance(metadata, dict) else 0
    height = metadata.get("coco_height", 0) if isinstance(metadata, dict) else 0
    doc_cat = metadata.get("doc_category", "") if isinstance(metadata, dict) else ""

    # Map category IDs to names
    regions = []
    class_dist = {name: 0 for name in CATEGORY_MAP.values()}
    if isinstance(bboxes, list) and isinstance(cat_ids, list):
        for bbox, cat_id in zip(bboxes, cat_ids):
            cat_name = CATEGORY_MAP.get(cat_id, f"unknown-{cat_id}")
            regions.append({"box": bbox, "category": cat_name})
            class_dist[cat_name] = class_dist.get(cat_name, 0) + 1

    # Extract text from pdf_cells
    texts = []
    if isinstance(pdf_cells, list):
        for cell in pdf_cells:
            if isinstance(cell, dict) and "text" in cell:
                texts.append(cell["text"])

    return {
        "id": f"doclaynet-{split}-{index:05d}",
        "dataset": "doclaynet",
        "split": split,
        "index": index,
        "documentCategory": doc_cat,
        "pageIndex": 0,
        "width": width,
        "height": height,
        "regionCount": len(regions),
        "regions": regions[:50],  # Cap for size
        "classDistribution": class_dist,
        "extractedText": " ".join(texts)[:500],  # First 500 chars
    }

def generate_eval(test_records, train_records):
    manifest = {
        "dataset": "doclaynet",
        "version": "v1.1",
        "license": "CDLA-Permissive",
        "source": "https://github.com/DS4SD/DocLayNet",
        "huggingface": "docling-project/DocLayNet-v1.1",
        "downloadedAt": datetime.now().isoformat(),
        "classes": list(CATEGORY_MAP.values()),
        "splits": {
            "test": {"count": len(test_records)},
            "train_sample": {"count": len(train_records)},
        },
        "evalMetrics": ["layout_detection_mAP", "class_precision_recall", "bounding_box_iou"],
    }
    with open(EVAL_DIR / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"[doclaynet] Eval manifest written")

if __name__ == "__main__":
    try:
        test, train = download()
        generate_eval(test, train)
        print("[doclaynet] Done!")
    except Exception as e:
        print(f"[doclaynet] Error: {e}", file=sys.stderr)
        import traceback; traceback.print_exc()
        sys.exit(1)

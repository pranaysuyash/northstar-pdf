#!/usr/bin/env python3
"""
Download FUNSD (Form Understanding in Noisy Scanned Documents) dataset.
163 annotated forms with word-level bounding boxes, text, answers, headers.
License: CC BY 4.0
Source: https://guillaumejaume.github.io/FUNSD/
HuggingFace: nielsr/funsd (splits: train, test)
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

def _confined(path):
    """Confine writes to the repository tree.

    Explicit containment anchor: these scripts run under operator control and
    CI; every write must resolve inside the repo, and static analysis gets a
    provable check instead of inferring one.
    """
    repo_root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    resolved = os.path.abspath(str(path))
    if os.path.commonpath([resolved, repo_root]) != repo_root:
        raise SystemExit(f"refusing to write outside the repository: {resolved}")
    return path

ROOT = Path(__file__).resolve().parent
EVAL_DIR = ROOT / "funsd" / "eval"
DATA_DIR = ROOT / "funsd" / "data"
EVAL_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

def download_funsd():
    from datasets import load_dataset

    print("[funsd] Downloading FUNSD from HuggingFace (nielsr/funsd)...")
    ds = load_dataset("nielsr/funsd")
    print(f"[funsd] Splits: {list(ds.keys())}")

    for split_name in ds:
        split_data = ds[split_name]
        print(f"[funsd] Split '{split_name}': {len(split_data)} examples")

        examples = []
        for i, example in enumerate(split_data):
            record = convert_example(example, index=i, split=split_name)
            examples.append(record)

        out_path = DATA_DIR / f"{split_name}.json"
        Path(_confined(out_path)).write_text(json.dumps(examples, indent=2))
        print(f"[funsd] Saved {len(examples)} examples to {out_path}")

    return ds

# NER tag mapping for nielsr/funsd:
# 0=O (outside), 1=B-HEADER, 2=I-HEADER, 3=B-QUESTION, 4=I-QUESTION, 5=B-ANSWER, 6=I-ANSWER
NER_TAG_MAP = {0: "O", 1: "B-HEADER", 2: "I-HEADER", 3: "B-QUESTION", 4: "I-QUESTION", 5: "B-ANSWER", 6: "I-ANSWER"}

def convert_example(example, index, split):
    words = example.get("words", [])
    bboxes = example.get("bboxes", [])
    ner_tags = example.get("ner_tags", [])
    
    all_text = " ".join(words)
    entities = []
    
    # Group consecutive B-/I- tags into entity spans
    current_entity = None
    for i, (word, bbox, tag) in enumerate(zip(words, bboxes, ner_tags)):
        tag_str = NER_TAG_MAP.get(tag, "O")
        if tag_str.startswith("B-"):
            if current_entity:
                entities.append(current_entity)
            entity_type = tag_str[2:]
            current_entity = {"text": word, "box": bbox, "type": entity_type}
        elif tag_str.startswith("I-") and current_entity and current_entity["type"] == tag_str[2:]:
            current_entity["text"] += " " + word
            # Expand bounding box to cover both words
            if bbox and current_entity.get("box"):
                cb = current_entity["box"]
                current_entity["box"] = [
                    min(cb[0], bbox[0]), min(cb[1], bbox[1]),
                    max(cb[2], bbox[2]), max(cb[3], bbox[3])
                ]
        else:
            if current_entity:
                entities.append(current_entity)
                current_entity = None
    if current_entity:
        entities.append(current_entity)
    
    return {
        "id": f"funsd-{split}-{index:04d}",
        "dataset": "funsd",
        "split": split,
        "index": index,
        "text": all_text,
        "wordCount": len(words),
        "entityCount": len(entities),
        "entities": entities[:200],
        "hasImage": True,
    }

def generate_eval():
    splits = {}
    for f in DATA_DIR.glob("*.json"):
        with open(f) as fh:
            data = json.load(fh)
        splits[f.stem] = {"count": len(data), "file": f"funsd/data/{f.name}"}

    manifest = {
        "dataset": "funsd",
        "license": "CC BY 4.0",
        "source": "https://guillaumejaume.github.io/FUNSD/",
        "huggingface": "nielsr/funsd",
        "description": "163 annotated forms with word-level bounding boxes, text, answers, headers",
        "downloadedAt": datetime.now().isoformat(),
        "splits": splits,
        "groundTruthFields": ["id", "text", "entities", "entityCount"],
        "entityTypes": ["header", "question", "answer"],
        "evalMetrics": ["entity_extraction_f1", "header_detection_precision", "qa_pairing_accuracy"],
    }
    Path(_confined(EVAL_DIR / "manifest.json")).write_text(json.dumps(manifest, indent=2))

    readme = f"""# FUNSD External Evaluation Set

**Dataset:** FUNSD (Form Understanding in Noisy Scanned Documents)
**License:** CC BY 4.0
**Source:** https://guillaumejaume.github.io/FUNSD/
**HuggingFace:** `nielsr/funsd`
**Downloaded:** {datetime.now().strftime('%Y-%m-%d')}

## Splits
"""
    readme += "".join(f"- **{name}**: {info['count']} documents\n" for name, info in splits.items())
    readme += """
## Ground Truth Format
Each document: `{id, text, entities[{text, box, type}], entityCount}`
Entity types: `header`, `question`, `answer`
"""
    Path(_confined(EVAL_DIR / "README.md")).write_text(readme)

    print(f"[funsd] Eval manifest: {EVAL_DIR / 'manifest.json'}")

if __name__ == "__main__":
    try:
        download_funsd()
        generate_eval()
        print("[funsd] Done!")
    except Exception as e:
        print(f"[funsd] Error: {e}", file=sys.stderr)
        sys.exit(1)

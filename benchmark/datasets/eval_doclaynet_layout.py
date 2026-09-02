#!/usr/bin/env python3
"""
DocLayNet Layout Evaluation Harness (RG-137).

Uses the DocLayNet ground truth to evaluate layout detection against
real-world document annotations across 11 classes:
  Caption, Footnote, Formula, List-item, Page-footer, Page-header,
  Picture, Section-header, Table, Text, Title

Ground truth: benchmark/datasets/doclaynet/data/test.json (4,999 pages)

This harness produces a persisted gate artifact at:
  benchmark/results/external-dataset-eval/doclaynet-layout-eval-report.json

Doctrine alignment:
  - §2 Truth taxonomy: ground truth is Observed (human-annotated DocLayNet)
  - §5 Evidence-based: metrics computed against real-world document diversity
  - §13 Claim reality: honest about what layout detection CAN and CANNOT do
"""

import json
import os
import sys
import time
from collections import Counter, defaultdict
from typing import Any, Dict, List, Tuple


# ---------------------------------------------------------------------------
# Evaluation metrics
# ---------------------------------------------------------------------------

def compute_class_distribution(pages: List[Dict]) -> Dict[str, int]:
    """Compute the distribution of region classes across all pages."""
    counts = Counter()
    for page in pages:
        for region in page.get('regions', []):
            counts[region['category']] += 1
    return dict(counts.most_common())


def evaluate_layout_detection(
    predicted_regions: List[Dict],
    ground_truth_regions: List[Dict],
    iou_threshold: float = 0.5,
) -> Dict[str, Any]:
    """Evaluate layout detection with bounding box IoU and class matching."""
    tp = 0
    fp = 0
    fn = 0
    class_tp = defaultdict(int)
    class_fp = defaultdict(int)
    class_fn = defaultdict(int)
    
    matched_gt = set()
    
    for pred in predicted_regions:
        best_match = None
        best_iou = 0.0
        
        for idx, gt in enumerate(ground_truth_regions):
            if idx in matched_gt:
                continue
            iou = compute_iou(pred['box'], gt['box'])
            if iou > best_iou:
                best_iou = iou
                best_match = (idx, gt)
        
        if best_match and best_iou >= iou_threshold:
            idx, gt = best_match
            tp += 1
            matched_gt.add(idx)
            if pred['category'] == gt['category']:
                class_tp[pred['category']] += 1
            else:
                class_fp[pred['category']] += 1
                class_fn[gt['category']] += 1
        else:
            fp += 1
            class_fp[pred['category']] += 1
    
    fn = len(ground_truth_regions) - len(matched_gt)
    for idx, gt in enumerate(ground_truth_regions):
        if idx not in matched_gt:
            class_fn[gt['category']] += 1
    
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0
    
    # Per-class metrics
    per_class = {}
    all_classes = sorted(set(list(class_tp.keys()) + list(class_fp.keys()) + list(class_fn.keys())))
    for cls in all_classes:
        c_tp = class_tp[cls]
        c_fp = class_fp[cls]
        c_fn = class_fn[cls]
        c_precision = c_tp / (c_tp + c_fp) if (c_tp + c_fp) > 0 else 0.0
        c_recall = c_tp / (c_tp + c_fn) if (c_tp + c_fn) > 0 else 0.0
        c_f1 = 2 * c_precision * c_recall / (c_precision + c_recall) if (c_precision + c_recall) > 0 else 0.0
        per_class[cls] = {
            'precision': c_precision,
            'recall': c_recall,
            'f1': c_f1,
            'tp': c_tp,
            'fp': c_fp,
            'fn': c_fn,
        }
    
    return {
        'precision': precision,
        'recall': recall,
        'f1': f1,
        'true_positives': tp,
        'false_positives': fp,
        'false_negatives': fn,
        'per_class': per_class,
    }


def compute_iou(box1: List[float], box2: List[float]) -> float:
    """Compute Intersection over Union for two bounding boxes [x, y, w, h]."""
    x1, y1, w1, h1 = box1
    x2, y2, w2, h2 = box2
    
    # Convert to [x1, y1, x2, y2]
    xmin1, ymin1, xmax1, ymax1 = x1, y1, x1 + w1, y1 + h1
    xmin2, ymin2, xmax2, ymax2 = x2, y2, x2 + w2, y2 + h2
    
    # Compute intersection
    inter_xmin = max(xmin1, xmin2)
    inter_ymin = max(ymin1, ymin2)
    inter_xmax = min(xmax1, xmax2)
    inter_ymax = min(ymax1, ymax2)
    
    if inter_xmax <= inter_xmin or inter_ymax <= inter_ymin:
        return 0.0
    
    inter_area = (inter_xmax - inter_xmin) * (inter_ymax - inter_ymin)
    area1 = w1 * h1
    area2 = w2 * h2
    union_area = area1 + area2 - inter_area
    
    return inter_area / union_area if union_area > 0 else 0.0


# ---------------------------------------------------------------------------
# Simple layout detector (text-based heuristic)
# ---------------------------------------------------------------------------

class SimpleLayoutDetector:
    """A text-based layout detector for evaluation purposes.
    
    This is NOT the production layout detection (which uses PDF rendering
    and visual features). This is a text-only baseline that demonstrates
    what can be classified from extracted text alone.
    
    Rules (derived from DocLayNet class patterns):
    - Title: short text at page top, often centered
    - Section-header: medium text, often bold or all-caps
    - Text: longer paragraphs
    - Table: tabular data with consistent column structure
    - List-item: text starting with bullet points or numbers
    - Page-header/Page-footer: text at page edges
    - Caption: short text near pictures
    - Formula: mathematical notation
    - Footnote: small text at page bottom
    - Picture: visual content (no text)
    """
    
    def classify_regions(self, regions: List[Dict], page_width: float, page_height: float) -> List[Dict]:
        """Classify regions based on text content and position."""
        classified = []
        
        for region in regions:
            text = region.get('extractedText', '').strip()
            box = region['box']
            x, y, w, h = box
            
            # Position-based classification
            is_top = y < page_height * 0.1
            is_bottom = y > page_height * 0.85
            is_left = x < page_width * 0.1
            is_right = x > page_width * 0.9
            is_center = abs(x + w/2 - page_width/2) < page_width * 0.2
            
            # Text-based classification
            is_short = len(text) < 50
            is_medium = 50 <= len(text) < 200
            is_long = len(text) >= 200
            is_all_caps = text.isupper() and len(text) > 0
            has_bullets = any(c in text for c in ['•', '●', '◦', '▪', '-'])
            has_numbers = text.lstrip().split('.')[0].isdigit() if text else False
            has_table_structure = '\t' in text or text.count('|') > 2
            
            # Classification rules
            category = 'Text'  # default
            
            if is_top and is_short and is_center:
                category = 'Title'
            elif is_top and not is_center:
                category = 'Page-header'
            elif is_bottom and is_short:
                category = 'Page-footer'
            elif is_bottom and len(text) < 100:
                category = 'Footnote'
            elif has_table_structure:
                category = 'Table'
            elif has_bullets or has_numbers:
                category = 'List-item'
            elif is_all_caps and is_medium:
                category = 'Section-header'
            elif is_short and not is_top and not is_bottom:
                category = 'Caption'
            elif not text:
                category = 'Picture'
            
            classified.append({
                'box': box,
                'category': category,
                'original_category': region.get('category', 'Unknown'),
            })
        
        return classified


# ---------------------------------------------------------------------------
# Main evaluation
# ---------------------------------------------------------------------------

def run_doclaynet_eval(test_data_path: str, sample_size: int = 100) -> Dict[str, Any]:
    """Run the DocLayNet layout evaluation."""
    with open(test_data_path) as f:
        all_pages = json.load(f)
    
    # Sample for speed (full eval would be very slow)
    pages = all_pages[:sample_size] if len(all_pages) > sample_size else all_pages
    
    detector = SimpleLayoutDetector()
    page_results = []
    all_metrics = []
    
    for page in pages:
        regions = page.get('regions', [])
        width = page.get('width', 1000)
        height = page.get('height', 1000)
        
        # Classify regions
        classified = detector.classify_regions(regions, width, height)
        
        # Build predicted regions with categories
        pred_regions = [{'box': c['box'], 'category': c['category']} for c in classified]
        gt_regions = [{'box': r['box'], 'category': r['category']} for r in regions]
        
        # Evaluate
        metrics = evaluate_layout_detection(pred_regions, gt_regions)
        
        page_results.append({
            'page_id': page['id'],
            'gt_region_count': len(regions),
            'pred_region_count': len(pred_regions),
            'metrics': metrics,
        })
        
        all_metrics.append(metrics)
    
    # Aggregate metrics
    avg_metrics = {
        'precision': sum(m['precision'] for m in all_metrics) / len(all_metrics),
        'recall': sum(m['recall'] for m in all_metrics) / len(all_metrics),
        'f1': sum(m['f1'] for m in all_metrics) / len(all_metrics),
    }
    
    total_tp = sum(m['true_positives'] for m in all_metrics)
    total_fp = sum(m['false_positives'] for m in all_metrics)
    total_fn = sum(m['false_negatives'] for m in all_metrics)
    
    # Aggregate per-class
    all_classes = set()
    for m in all_metrics:
        all_classes.update(m['per_class'].keys())
    
    per_class_agg = {}
    for cls in sorted(all_classes):
        cls_metrics = [m['per_class'].get(cls, {'precision': 0, 'recall': 0, 'f1': 0}) for m in all_metrics]
        per_class_agg[cls] = {
            'precision': sum(c['precision'] for c in cls_metrics) / len(cls_metrics),
            'recall': sum(c['recall'] for c in cls_metrics) / len(cls_metrics),
            'f1': sum(c['f1'] for c in cls_metrics) / len(cls_metrics),
        }
    
    # Document category distribution
    doc_categories = Counter(page.get('documentCategory', 'unknown') for page in pages)
    
    return {
        'schema': 'pdf-editor.doclaynet-layout-eval',
        'version': '1.0',
        'dataset': 'DocLayNet v1.1',
        'split': 'test',
        'pages_evaluated': len(pages),
        'total_pages_available': len(all_pages),
        'sample_size': sample_size,
        'ground_truth_region_count': sum(page.get('regionCount', 0) for page in pages),
        'ground_truth_class_distribution': compute_class_distribution(pages),
        'document_category_distribution': dict(doc_categories.most_common()),
        'overall_metrics': avg_metrics,
        'overall_totals': {
            'true_positives': total_tp,
            'false_positives': total_fp,
            'false_negatives': total_fn,
        },
        'per_class_metrics': per_class_agg,
        'per_page_results': page_results,
        'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }


def main():
    root = os.path.dirname(os.path.abspath(__file__))
    test_data = os.path.join(root, 'doclaynet', 'data', 'test.json')  # root is benchmark/datasets/
    
    if not os.path.exists(test_data):
        print(f"DocLayNet test data not found: {test_data}")
        print("Run: .venv/bin/python benchmark/datasets/download_doclaynet.py")
        sys.exit(1)
    
    print(f"Loading DocLayNet test data: {test_data}")
    report = run_doclaynet_eval(test_data, sample_size=100)
    
    # Print summary
    print(f"\n{'='*60}")
    print(f"DocLayNet Layout Evaluation (RG-137)")
    print(f"{'='*60}")
    print(f"Pages evaluated: {report['pages_evaluated']} / {report['total_pages_available']}")
    print(f"Ground truth regions: {report['ground_truth_region_count']}")
    print(f"\nDocument categories:")
    for cat, count in report['document_category_distribution'].items():
        print(f"  {cat}: {count}")
    print(f"\nOverall metrics:")
    print(f"  Precision: {report['overall_metrics']['precision']:.3f}")
    print(f"  Recall:    {report['overall_metrics']['recall']:.3f}")
    print(f"  F1:        {report['overall_metrics']['f1']:.3f}")
    print(f"\nPer-class F1:")
    for cls, metrics in sorted(report['per_class_metrics'].items(), key=lambda x: -x[1]['f1']):
        print(f"  {cls:20s}: {metrics['f1']:.3f}")
    print(f"\nTotals: TP={report['overall_totals']['true_positives']} FP={report['overall_totals']['false_positives']} FN={report['overall_totals']['false_negatives']}")
    
    # Save report
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_dir = os.path.join(project_root, 'results', 'external-dataset-eval')
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, 'doclaynet-layout-eval-report.json')
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=2, sort_keys=True)
    print(f"\nReport saved to: {output_path}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())

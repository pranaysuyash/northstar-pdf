#!/usr/bin/env python3
"""PaddleOCR wrapper for the benchmark harness.

Usage: python3 paddleocr_wrapper.py <image_path>
Output: recognized text to stdout, one line per detected text region.

Requires: pip install paddleocr
"""
import sys
import os

def main():
    if len(sys.argv) < 2:
        print("Usage: paddleocr_wrapper.py <image_path>", file=sys.stderr)
        sys.exit(1)
    
    image_path = sys.argv[1]
    if not os.path.exists(image_path):
        print(f"Error: file not found: {image_path}", file=sys.stderr)
        sys.exit(1)
    
    os.environ['PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK'] = 'True'
    
    try:
        from paddleocr import PaddleOCR
        ocr = PaddleOCR(use_textline_orientation=True, lang='en')
        result = ocr.predict(image_path)
        
        lines = []
        if result:
            for page_result in result:
                texts = page_result.get('rec_texts', []) if isinstance(page_result, dict) else getattr(page_result, 'rec_texts', [])
                lines.extend(texts)
        
        print('\n'.join(lines))
    except ImportError:
        print("Error: paddleocr not installed. Run: pip install paddleocr", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

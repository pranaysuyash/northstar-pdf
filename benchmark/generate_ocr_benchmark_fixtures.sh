#!/bin/bash
set -euo pipefail
ROOT="/Users/pranay/Projects/pdf_editor"
OUT="$ROOT/benchmark/results/ocr-corpus"
FONT="/System/Library/Fonts/Supplemental/Verdana.ttf"
MAGICK="magick"

mkdir -p "$OUT"

# 1. Clean printed scan (English paragraph)
$MAGICK -size 1600x700 xc:white \
  -font "$FONT" -pointsize 28 -fill black \
  -annotate +100+100 "The quick brown fox jumps over the lazy dog." \
  -annotate +100+150 "Pack my box with five dozen liquor jugs." \
  -annotate +100+200 "How vexingly quick daft zebras jump." \
  "$OUT/clean-english.png"
$MAGICK "$OUT/clean-english.png" "$OUT/clean-english.pdf"
cat > "$OUT/clean-english.gt.txt" << 'EOF'
The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump.
EOF
echo "clean-english: OK"

# 2. Noisy scan (added Gaussian noise)
$MAGICK -size 1600x700 xc:white \
  -font "$FONT" -pointsize 28 -fill black \
  -annotate +100+100 "Invoice Number: 2024-0831" \
  -annotate +100+150 "Amount Due: 1,234.56 dollars" \
  -annotate +100+200 "Date: August 31, 2026" \
  -attenuate 0.3 +noise Gaussian \
  "$OUT/noisy-invoice.png"
$MAGICK "$OUT/noisy-invoice.png" "$OUT/noisy-invoice.pdf"
cat > "$OUT/noisy-invoice.gt.txt" << 'EOF'
Invoice Number: 2024-0831
Amount Due: 1,234.56 dollars
Date: August 31, 2026
EOF
echo "noisy-invoice: OK"

# 3. Rotated 90 degrees
$MAGICK -size 700x1600 xc:white \
  -font "$FONT" -pointsize 24 -fill black -rotate -90 \
  -annotate +100+100 "Certificate of Achievement" \
  -annotate +100+150 "Awarded to: Dr. Alan Turing" \
  -annotate +100+200 "For Excellence in Computer Science" \
  "$OUT/rotated-certificate.png"
$MAGICK "$OUT/rotated-certificate.png" "$OUT/rotated-certificate.pdf"
cat > "$OUT/rotated-certificate.gt.txt" << 'EOF'
Certificate of Achievement
Awarded to: Dr. Alan Turing
For Excellence in Computer Science
EOF
echo "rotated-certificate: OK"

# 4. Low contrast (gray text on light gray)
$MAGICK -size 1600x700 xc:'#F0F0F0' \
  -font "$FONT" -pointsize 26 -fill '#999999' \
  -annotate +100+100 "Terms and Conditions apply to all purchases." \
  -annotate +100+150 "Please read carefully before signing." \
  -annotate +100+200 "Returns accepted within 30 days of purchase." \
  "$OUT/low-contrast.png"
$MAGICK "$OUT/low-contrast.png" "$OUT/low-contrast.pdf"
cat > "$OUT/low-contrast.gt.txt" << 'EOF'
Terms and Conditions apply to all purchases.
Please read carefully before signing.
Returns accepted within 30 days of purchase.
EOF
echo "low-contrast: OK"

# 5. Dense multi-line paragraph
$MAGICK -size 1600x900 xc:white \
  -font "$FONT" -pointsize 22 -fill black \
  -annotate +80+80  "Lorem ipsum dolor sit amet, consectetur adipiscing elit." \
  -annotate +80+120 "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua." \
  -annotate +80+160 "Ut enim ad minim veniam, quis nostrud exercitation ullamco" \
  -annotate +80+200 "laboris nisi ut aliquip ex ea commodo consequat." \
  -annotate +80+240 "Duis aute irure dolor in reprehenderit in voluptate velit" \
  -annotate +80+280 "esse cillum dolore eu fugiat nulla pariatur." \
  "$OUT/dense-paragraph.png"
$MAGICK "$OUT/dense-paragraph.png" "$OUT/dense-paragraph.pdf"
cat > "$OUT/dense-paragraph.gt.txt" << 'EOF'
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
EOF
echo "dense-paragraph: OK"

# 6. Small font (12pt - stress test)
$MAGICK -size 1600x400 xc:white \
  -font "$FONT" -pointsize 12 -fill black \
  -annotate +100+100 "Small font text tests the limits of OCR recognition accuracy at reduced sizes." \
  -annotate +100+130 "This line is also at 12pt to verify consistent OCR behavior." \
  -annotate +100+160 "Third line for statistical confidence in the measurement." \
  "$OUT/small-font.png"
$MAGICK "$OUT/small-font.png" "$OUT/small-font.pdf"
cat > "$OUT/small-font.gt.txt" << 'EOF'
Small font text tests the limits of OCR recognition accuracy at reduced sizes.
This line is also at 12pt to verify consistent OCR behavior.
Third line for statistical confidence in the measurement.
EOF
echo "small-font: OK"

# 7. Mixed case and punctuation
$MAGICK -size 1600x500 xc:white \
  -font "$FONT" -pointsize 26 -fill black \
  -annotate +100+100 "Email: user@example.com | Phone: 555-123-4567" \
  -annotate +100+150 "Fax: 1-800-555-0199" \
  -annotate +100+200 "Order 12345-ABC. Total: 42.50 EUR (VAT included)" \
  "$OUT/mixed-punctuation.png"
$MAGICK "$OUT/mixed-punctuation.png" "$OUT/mixed-punctuation.pdf"
cat > "$OUT/mixed-punctuation.gt.txt" << 'EOF'
Email: user@example.com | Phone: 555-123-4567
Fax: 1-800-555-0199
Order 12345-ABC. Total: 42.50 EUR (VAT included)
EOF
echo "mixed-punctuation: OK"

# 8. Multi-column layout
$MAGICK -size 1600x700 xc:white \
  -font "$FONT" -pointsize 22 -fill black \
  -annotate +80+80   "Column One" \
  -annotate +80+120  "First paragraph of the left" \
  -annotate +80+160  "column discusses the importance" \
  -annotate +80+200  "of structured document layout" \
  -annotate +80+240  "for optical character recognition." \
  -annotate +800+80  "Column Two" \
  -annotate +800+120 "Second paragraph covers the" \
  -annotate +800+160 "technical challenges of OCR" \
  -annotate +800+200 "including noise, rotation, and" \
  -annotate +800+240 "low contrast text regions." \
  "$OUT/multi-column.png"
$MAGICK "$OUT/multi-column.png" "$OUT/multi-column.pdf"
cat > "$OUT/multi-column.gt.txt" << 'EOF'
Column One
First paragraph of the left
column discusses the importance
of structured document layout
for optical character recognition.
Column Two
Second paragraph covers the
technical challenges of OCR
including noise, rotation, and
low contrast text regions.
EOF
echo "multi-column: OK"

echo ""
echo "Generated 8 new fixtures in $OUT"
ls -la "$OUT"/*.png "$OUT"/*.pdf "$OUT"/*.gt.txt 2>/dev/null | wc -l
echo "total files"

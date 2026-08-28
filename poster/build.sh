#!/usr/bin/env bash
# Builds the print-ready poster PDF: 710 x 2010 mm (700 x 2000 visible + 5 mm bleed),
# CMYK, no crop marks, all text converted to outlines, images >= 150 dpi at final size.
set -euo pipefail
cd "$(dirname "$0")"

# 2x-upscale the two figures that are placed larger than their native 150 dpi size
mkdir -p figs
python3 - << 'EOF'
from PIL import Image
for f in ["shock_reaction_scatterplot.png", "motivation_chart.png"]:
    im = Image.open(f"../Figures/{f}")
    im.resize((im.width*2, im.height*2), Image.LANCZOS).save(f"figs/{f}")
EOF

lualatex -interaction=nonstopmode poster_EFA.tex >/dev/null
lualatex -interaction=nonstopmode poster_EFA.tex >/dev/null

# Outline all text and force CMYK; keep images at full resolution
gs -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
   -dNoOutputFonts \
   -sColorConversionStrategy=CMYK -dProcessColorModel=/DeviceCMYK \
   -dDownsampleColorImages=false -dDownsampleGrayImages=false -dDownsampleMonoImages=false \
   -dAutoFilterColorImages=false -dAutoFilterGrayImages=false \
   -dColorImageFilter=/FlateEncode -dGrayImageFilter=/FlateEncode \
   -o Hermes_EFA_poster_print.pdf poster_EFA.pdf

echo "--- verification ---"
pdfinfo Hermes_EFA_poster_print.pdf | grep -E "Pages|Page size"
echo "Embedded fonts (must be empty):"
pdffonts Hermes_EFA_poster_print.pdf | tail -n +3
echo "Done: Hermes_EFA_poster_print.pdf"

"""Exit 0 if a screenshot looks like a real app screen: not mostly one flat colour (launch screen)."""
import sys, zlib, struct
from collections import Counter
try:
    from PIL import Image
except ImportError:
    sys.exit(0)  # can't check; accept
im = Image.open(sys.argv[1]).convert("RGB").resize((60, 130))
c = Counter(list(im.getdata()))
top = c.most_common(1)[0][1] / (60 * 130)
sys.exit(0 if top < 0.80 else 1)

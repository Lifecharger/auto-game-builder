"""
Check PixelLab account balance.

Usage:
    python "C:/General Tools/pixellab_balance.py"
"""
import sys
sys.path.insert(0, r"C:\General Tools")
from pixellab_client import get_balance

result = get_balance()
print(result)

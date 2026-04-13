"""
Meshy AI — Check credit balance

Usage:
  python meshy_balance.py
"""

from meshy_client import get

result = get("/openapi/v1/balance")
print(f"Meshy credits: {result.get('balance', 'unknown')}")

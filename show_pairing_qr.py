#!/usr/bin/env python3
"""Print the AGB pairing QR code directly in the terminal."""

import json
import base64
import os
import qrcode

settings_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server", "config", "settings.json")

with open(settings_path, "r", encoding="utf-8") as f:
    s = json.load(f)

api_key = s.get("security", {}).get("api_key", "")
worker_url = s.get("cloudflare", {}).get("worker_url", "")

payload = json.dumps({"api_key": api_key, "worker_url": worker_url})
encoded = base64.b64encode(payload.encode()).decode()

print("\n" + "="*50)
print(" AUTO GAME BUILDER PAIRING")
print("="*50)
print(f"Worker URL : {worker_url}")
print(f"API Key    : {api_key[:6]}...{api_key[-6:]}")
print("="*50)
print("\nScan this QR code from the AGB phone app:\n")

qr = qrcode.QRCode(border=1)
qr.add_data(encoded)
qr.make(fit=True)
qr.print_ascii(invert=True)

print("="*50)
print("Pairing string (if typing/pasting manually):")
print(encoded)
print("="*50 + "\n")

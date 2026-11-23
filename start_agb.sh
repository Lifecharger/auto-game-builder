#!/bin/bash
# Auto Game Builder macOS Launcher

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Check if already running
if curl -s -o /dev/null --max-time 2 http://127.0.0.1:8000/api/health; then
    echo "AGB is already running at http://127.0.0.1:8000"
    exit 0
fi

echo "=========================================="
echo " Starting Auto Game Builder (macOS)       "
echo "=========================================="

source "$DIR/.venv/bin/activate"
python "$DIR/server/main.py"

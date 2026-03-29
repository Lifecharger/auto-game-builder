"""Start the Auto Game Builder server."""

import os
import sys

# Add server to path and run
server_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server")
sys.path.insert(0, server_dir)
os.chdir(server_dir)

from main import main

main()

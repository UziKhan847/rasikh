#!/usr/bin/env python3
"""Serves the web build (build/web) on this computer, to try it in a browser:

    flutter build web --wasm --release
    python3 tool/web/serve.py            # then open http://localhost:8080

It sends the two headers the WebAssembly renderer (skwasm, multi-threaded)
needs; without them the browser falls back to the slower JavaScript one.
Local only (127.0.0.1); for checking, not for hosting.
"""
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'web')


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.wasm': 'application/wasm',
        '.mjs': 'text/javascript',
        '.js': 'text/javascript',
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


if not os.path.isfile(os.path.join(ROOT, 'index.html')):
    sys.exit('No build/web: run  flutter build web --wasm --release  first.')
print(f'Serving {os.path.normpath(ROOT)} at http://localhost:{PORT} (Ctrl+C stops)')
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()

# local_repo_server.py

import http.server
import socketserver
from pathlib import Path
import os

class RepoRequestHandler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        """将 URL 映射到本地 ./repo 目录下"""
        root = Path(__file__).resolve().parent / "repo"
        # 去掉前导 /
        path = path.lstrip("/")
        return str(root / path)

    def log_message(self, format, *args):
        print(f"[HTTP] {self.address_string()} - {format % args}")

def run_server(port=8080):
    print(f"SPM 本地软件源服务器启动于 http://localhost:{port}/")
    print("将 ./repo 目录作为根目录，按 repo/main/index.json 的结构组织")
    print("警告: 不考虑安全性，若你在一个实际上的服务器搭建，请务必修改代码，修复潜在的安全隐患")
    with socketserver.TCPServer(("", port), RepoRequestHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
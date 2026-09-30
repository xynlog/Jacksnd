from __future__ import annotations

import argparse
import atexit
import json
import os
import subprocess
import sys
import threading
import urllib.request
import webbrowser
from pathlib import Path

from studio import __version__


def choose(mode):
    import tkinter as tk
    from tkinter import filedialog
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    path = filedialog.askopenfilename(title="选择文件") if mode == "file" else filedialog.askdirectory(title="选择存储文件夹")
    root.destroy()
    sys.stdout.buffer.write(path.encode("utf-8"))


def open_app(url):
    if os.name == "nt":
        for folder in (os.environ.get("PROGRAMFILES(X86)", ""), os.environ.get("PROGRAMFILES", ""), os.environ.get("LOCALAPPDATA", "")):
            for relative in ("Microsoft/Edge/Application/msedge.exe", "Google/Chrome/Application/chrome.exe"):
                candidate = Path(folder) / relative
                if candidate.is_file():
                    subprocess.Popen([str(candidate), "--app=" + url, "--window-size=1500,950"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return
    webbrowser.open(url)


def main():
    parser = argparse.ArgumentParser(description="视频重创工作台 · 本机应用")
    parser.add_argument("--data-dir")
    parser.add_argument("--config-dir")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--pick", choices=["directory", "file"])
    args = parser.parse_args()
    if args.pick:
        choose(args.pick)
        return
    from studio.server import LocalServer
    from studio.service import Service
    from studio.util import local_config_dir, atomic_json
    cfg = Path(args.config_dir) if args.config_dir else local_config_dir()
    cfg.mkdir(parents=True, exist_ok=True)
    lock_path = cfg / "app.lock"
    lock_file = lock_path.open("a+b")
    try:
        if os.name == "nt":
            import msvcrt
            lock_file.seek(0)
            if lock_file.read(1) == b"":
                lock_file.write(b"0")
                lock_file.flush()
            lock_file.seek(0)
            msvcrt.locking(lock_file.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (OSError, BlockingIOError):
        info = json.loads((cfg / "instance.json").read_text(encoding="utf-8"))
        if not args.no_browser:
            open_app(info["url"])
        print("工作台已在运行，已打开现有窗口。", flush=True)
        return
    service = Service(cfg, args.data_dir)
    server = LocalServer(service, args.port)
    url = f"http://127.0.0.1:{server.server_port}/#token={server.token}"
    atomic_json(cfg / "instance.json", {"url": url, "pid": os.getpid()})
    print(f"视频重创工作台 v{__version__} 已启动。\n本机地址：http://127.0.0.1:{server.server_port}\n作品存储：{service.store.root}\n请保持此启动窗口运行；按 Ctrl+C 退出。", flush=True)
    if not args.no_browser:
        open_app(url)
    try:
        server.serve_forever(poll_interval=.5)
    except KeyboardInterrupt:
        print("正在保存状态并等待当前提交返回…", flush=True)
    finally:
        server.server_close()
        service.close()
        (cfg / "instance.json").unlink(missing_ok=True)
        lock_file.close()


if __name__ == "__main__":
    main()

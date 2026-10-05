"""Send Python to the installed Blender MCP add-on (no headless fallback)."""
import argparse
import json
from pathlib import Path
import socket


def execute(code, timeout=600):
    request = {"type": "execute", "code": code, "strict_json": True}
    with socket.create_connection(("localhost", 9876), timeout=5) as connection:
        connection.settimeout(timeout)
        connection.sendall(json.dumps(request).encode("utf-8") + b"\0")
        response = bytearray()
        while b"\0" not in response:
            chunk = connection.recv(65536)
            if not chunk:
                raise RuntimeError("Blender MCP closed before returning a complete response")
            response.extend(chunk)
    result = json.loads(response.split(b"\0", 1)[0])
    print(json.dumps(result, ensure_ascii=True, indent=2))
    if result.get("status") != "ok":
        raise RuntimeError("Blender MCP execution failed; see response above")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("script", nargs="?")
    parser.add_argument("--code")
    args = parser.parse_args()
    execute(args.code if args.code else Path(args.script).read_text(encoding="utf-8"))

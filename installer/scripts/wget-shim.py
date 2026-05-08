#!/usr/bin/env python3
"""Minimal wget shim — used only during Entware bootstrap.

Bootstrap installs this as /opt/bin/wget on the printer when no real wget
exists yet. opkg uses wget internally to fetch packages, so opkg can't
bootstrap itself without one. This shim mimics enough of wget(1) to let
opkg install the real wget package, which then overwrites this file.

If the real-wget install fails (transient opkg issue, network glitch),
the shim can stick around indefinitely as /opt/bin/wget. Without a
socket timeout, every subsequent invocation would hang forever on a
stalled TCP connection. Hence the explicit timeouts below — fail loudly
within ~30s instead of hanging silently.

Supported invocations:
  wget URL                fetch URL, write to stdout
  wget -O FILE URL        fetch URL, write to FILE
  wget -O- URL            fetch URL, write to stdout
  wget -qO- URL           same; combined flag form
  wget -OFILE URL         combined; FILE has no leading separator
Other flags (-q, -nv, -c, --no-check-certificate, etc.) are accepted
silently and ignored — opkg passes a few but doesn't depend on their
behavior beyond presence.

Exit codes mirror real wget's high-level contract:
  0   success
  1   anything else (no URL, timeout, HTTP/network error, etc.)
"""

import socket
import sys
import urllib.request

# 30s connect timeout, applied globally to all socket connections made by
# urllib. Stalled connections raise socket.timeout instead of hanging.
socket.setdefaulttimeout(30)

args = sys.argv[1:]
url = None
out = None
while args:
    a = args.pop(0)
    if a == "-O":
        out = args.pop(0) if args else None
    elif a == "-qO-" or a == "-O-":
        out = "-"
    elif a.startswith("-O"):
        # Combined form like -Ofoo (no space) — value is in same arg
        out = a[2:]
    elif a.startswith("-"):
        # Other flags (-q, -nv, -c, etc.) — ignore quietly
        pass
    else:
        url = a

if not url:
    print("wget-shim: no URL given", file=sys.stderr)
    sys.exit(1)

try:
    if out and out != "-":
        urllib.request.urlretrieve(url, out)
    else:
        sys.stdout.buffer.write(urllib.request.urlopen(url, timeout=30).read())
except socket.timeout:
    print(f"wget-shim: timeout connecting to {url}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"wget-shim error: {e}", file=sys.stderr)
    sys.exit(1)

#!/usr/bin/env python3
"""Build ReaPack index.xml for ReaFL (no reapack-index/ruby needed).

usage: python3 tools/build_index.py [BASE_URL] [OUT]
  BASE_URL defaults to https://raw.githubusercontent.com/Aced107/ReaFL/main/
  (use file:///path/to/repo/ for local testing)
Bump VERSION / CHANGELOG / TIME below for each release.
"""
import sys, datetime
from urllib.parse import quote
from xml.sax.saxutils import escape, quoteattr

VERSION = "0.1.0"
TIME = "2026-10-29T20:00:00Z"
AUTHOR = "Armaan"
CHANGELOG = """Initial release: tool modes with shortcuts (1 = Default, T = Mute) and a ReaFL toolbar.
Mute tool: left click toggles an item's mute (selection untouched), right click deletes it."""
CATEGORY = "ReaFL"
FILES = [  # (path inside category folder, register as Main action?)
    ("ReaFL - Default tool.lua", True),
    ("ReaFL - Mute tool.lua", True),
    ("ReaFL - Setup (run once after install).lua", True),
    ("ReaFL - Uninstall setup.lua", True),
    ("lib/reafl_core.lua", False),
    ("lib/reafl_engine.lua", False),
    ("lib/reafl_setup_common.lua", False),
    ("lib/reafl_startup.lua", False),
]
ABOUT_RTF = (r"{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Helvetica;}}\f0\fs20"
    r"{\b\fs28 ReaFL}\par FL Studio-style tools for REAPER's arrange view.\par\par"
    r"{\b Setup:} after installing, run {\i ReaFL - Setup (run once after install)} from the Actions list, then restart REAPER.\par\par"
    r"{\b Tools:}\par"
    r"\bullet  Default (key 1): normal REAPER mouse behaviour.\par"
    r"\bullet  Mute (key T): left click an item toggles its mute, right click deletes it.\par\par"
    r"{\b Requirements:} REAPER 7.03+; js_ReaScriptAPI (needed for the Mute tool's clicks; install it from the ReaTeam Extensions repository, which ReaPack includes by default); SWS recommended.\par"
    r" Undo setup with {\i ReaFL - Uninstall setup}.\par}")

def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "https://raw.githubusercontent.com/Aced107/ReaFL/main/"
    out = sys.argv[2] if len(sys.argv) > 2 else "index.xml"
    if not base.endswith("/"): base += "/"
    src = []
    for f, main in FILES:
        url = base + quote(f"{CATEGORY}/{f}")
        attr = ' main="main"' if main else ""
        src.append(f'        <source{attr} file={quoteattr(f)}>{escape(url)}</source>')
    xml = f'''<?xml version="1.0" encoding="utf-8"?>
<index version="1" name="ReaFL">
  <category name="{CATEGORY}">
    <reapack name="ReaFL.lua" type="script" desc="ReaFL: FL Studio-style tools for REAPER">
      <metadata>
        <description><![CDATA[{ABOUT_RTF}]]></description>
        <link rel="website">https://github.com/Aced107/ReaFL</link>
      </metadata>
      <version name="{VERSION}" author="{AUTHOR}" time="{TIME}">
        <changelog><![CDATA[{CHANGELOG}]]></changelog>
{chr(10).join(src)}
      </version>
    </reapack>
  </category>
  <metadata>
    <description><![CDATA[{ABOUT_RTF}]]></description>
    <link rel="website">https://github.com/Aced107/ReaFL</link>
  </metadata>
</index>
'''
    open(out, "w", newline="\n").write(xml)
    print("wrote", out)

if __name__ == "__main__":
    main()

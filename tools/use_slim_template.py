#!/usr/bin/env python3
"""Points one export preset at a custom (slim) engine template, for a CI build:
    tools/use_slim_template.py <preset number> <template file>
It sets custom_template/release in that preset's options only, in export_presets.cfg here, and
nowhere else; the committed file keeps the official templates, so exporting by hand needs no setup.
"""
import os
import re
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    number, template = sys.argv[1], os.path.abspath(os.path.expanduser(sys.argv[2]))
    if not os.path.isfile(template):
        print("No template at %s" % template)
        return 1
    path = "export_presets.cfg"
    text = open(path, encoding="utf-8").read()
    header = "[preset.%s.options]" % number
    start = text.find(header)
    if start < 0:
        print("export_presets.cfg has no %s" % header)
        return 1
    following = re.search(r"^\[preset\.\d+\]", text[start:], re.M)
    end = start + following.start() if following else len(text)
    section = text[start:end]
    changed = section.replace('custom_template/release=""', 'custom_template/release="%s"' % template)
    if changed == section:
        print("%s has no empty custom_template/release line" % header)
        return 1
    open(path, "w", encoding="utf-8").write(text[:start] + changed + text[end:])
    print("%s now uses %s" % (header, template))
    return 0


if __name__ == "__main__":
    sys.exit(main())

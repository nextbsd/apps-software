#!/usr/bin/env python3
# Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause
#
# Fetches the icon of every app in Software/Resources/Catalog.plist from
# its repository (the path make-catalog.py took from icon-sources.json)
# into Software/Resources/CatalogIcons, and writes CatalogIcons/CREDITS:
# each icon's project, source path and the project's license, read from
# the LICENSE or COPYING file in the app's folder or at the top of its
# repository.
#
# Icons are kept as their projects drew them. One larger than 128 pixels
# is scaled down to 128, and an .icns is converted to PNG; both with
# sips(1) on macOS or ImageMagick elsewhere. Needs the network:
#
#   python3 catalog/fetch-icons.py
#
# GITHUB_TOKEN, if set, is sent to the GitHub API to raise its rate limit.

import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RESOURCES = os.path.join(HERE, "..", "Software", "Resources")
ICONS = os.path.join(RESOURCES, "CatalogIcons")
SIZE = 128


def fetch(url, api=False):
    request = urllib.request.Request(url)
    if api:
        request.add_header("Accept", "application/vnd.github+json")
        if os.environ.get("GITHUB_TOKEN"):
            request.add_header("Authorization",
                               "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def raw_url(repo, path):
    return "https://raw.githubusercontent.com/%s/HEAD/%s" % (
        repo, urllib.parse.quote(path))


def pixel_size(path):
    if shutil.which("sips"):
        out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight",
                              path], capture_output=True, text=True).stdout
        values = [int(line.split()[-1]) for line in out.splitlines()
                  if line.strip().startswith("pixel")]
        return max(values) if values else 0
    out = subprocess.run(["magick", "identify", "-format", "%w %h\n", path],
                         capture_output=True, text=True).stdout.split()
    return max(int(v) for v in out) if out else 0


def convert(source, dest, scale):
    """Writes source to dest in dest's format, no larger than SIZE."""
    fmt = "tiff" if dest.endswith(".tiff") else "png"
    if shutil.which("sips"):
        cmd = ["sips", "-s", "format", fmt]
        if scale:
            cmd += ["-Z", str(SIZE)]
        cmd += [source, "--out", dest]
    else:
        cmd = ["magick", source + "[0]"]
        if scale:
            cmd += ["-resize", "%dx%d>" % (SIZE, SIZE)]
        cmd += [dest]
    subprocess.run(cmd, check=True, capture_output=True)


def identify(text):
    """A license's SPDX id from its text, for the licenses these projects
    use; None for any other."""
    head = " ".join(text[:4000].split())
    if "GNU LESSER GENERAL PUBLIC LICENSE" in head:
        return "LGPL-3.0" if "Version 3" in head else "LGPL-2.1"
    if "GNU LIBRARY GENERAL PUBLIC LICENSE" in head:
        return "LGPL-2.0"
    if "GNU GENERAL PUBLIC LICENSE" in head:
        if "Version 3" in head:
            return "GPL-3.0"
        return "GPL-2.0" if "Version 2" in head else "GPL"
    if "Apache License" in head and "Version 2.0" in head:
        return "Apache-2.0"
    if "Permission is hereby granted, free of charge" in head:
        return "MIT"
    if "Redistribution and use in source and binary forms" in head:
        if "endorse or promote" in head:
            return "BSD-3-Clause"
        return "BSD-2-Clause"
    return None


def license_files(repo, path):
    try:
        listing = json.loads(fetch("https://api.github.com/repos/%s/contents/%s"
                                   % (repo, urllib.parse.quote(path)), api=True))
    except urllib.error.HTTPError:
        return []
    return [item["path"] for item in listing
            if item["type"] == "file"
            and item["name"].upper().startswith(("LICENSE", "LICENCE", "COPYING"))]


def license_of(repo, path):
    """The license covering path in repo, and the file it's from: a
    LICENSE or COPYING file in the app's own folder, else the
    repository's top-level one."""
    files = (license_files(repo, path) if path else []) or license_files(repo, "")
    if not files:
        return ("no LICENSE or COPYING file found", "")
    for file in sorted(files, key=len):
        text = fetch(raw_url(repo, file)).decode("utf-8", "replace")
        spdx = identify(text)
        if spdx:
            return (spdx, file)
    return ("see file", files[0])


def main():
    with open(os.path.join(RESOURCES, "Catalog.plist"), "rb") as f:
        catalog = plistlib.load(f)
    os.makedirs(ICONS, exist_ok=True)
    licenses = {}
    credits = []
    tmp = tempfile.mkdtemp()
    failed = False
    for app in catalog["Apps"]:
        repo, source, name = app["Repository"], app["IconSource"], app["Icon"]
        dest = os.path.join(ICONS, name)
        try:
            data = fetch(raw_url(repo, source))
        except urllib.error.URLError as e:
            print("%s: %s: %s" % (app["Name"], source, e), file=sys.stderr)
            failed = True
            continue
        original = os.path.join(tmp, os.path.basename(source))
        with open(original, "wb") as f:
            f.write(data)
        same_format = os.path.splitext(source)[1].lower() in \
            ((".tif", ".tiff") if name.endswith(".tiff") else (".png",))
        large = pixel_size(original) > SIZE
        if same_format and not large:
            shutil.copyfile(original, dest)
        else:
            convert(original, dest, large)
        key = (repo, app.get("RepositoryPath", ""))
        if key not in licenses:
            licenses[key] = license_of(*key)
        spdx, file = licenses[key]
        credits.append((name, app["Name"], repo, source, spdx, file))
        print("%-24s %s" % (name, spdx))
    shutil.rmtree(tmp)

    with open(os.path.join(ICONS, "CREDITS"), "w", encoding="utf-8") as f:
        f.write("Software.app catalog icons\n"
                "==========================\n\n"
                "Each icon in this folder is the app icon of the project named\n"
                "below, taken from that project's repository on GitHub. Icons\n"
                "larger than %d pixels were scaled down to %d; an .icns was\n"
                "converted to PNG. Each belongs to its project. License is\n"
                "what the LICENSE or COPYING file in the app's folder, or at\n"
                "the top of its repository, says. Software's own license\n"
                "(LICENSE at the top of this repository) covers Software's\n"
                "code, not these.\n"
                "\n"
                "Made by catalog/fetch-icons.py.\n" % (SIZE, SIZE))
        for name, title, repo, source, spdx, file in credits:
            f.write("\n%s\n" % name)
            f.write("  App:      %s\n" % title)
            f.write("  Project:  https://github.com/%s\n" % repo)
            f.write("  Source:   %s\n" % source)
            if spdx == "see file":
                f.write("  License:  see %s\n" % file)
            elif file:
                f.write("  License:  %s (%s)\n" % (spdx, file))
            else:
                f.write("  License:  %s\n" % spdx)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

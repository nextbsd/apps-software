#!/usr/bin/env python3
# Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause
#
# Makes Software/Resources/Catalog.plist, the catalog bundled in
# Software.app, from:
#   - apps.json: every app and library collected from the three sources,
#     with its category (from the mockup);
#   - icon-sources.json: where each app's icon is in its repository;
#   - build-catalog.plist: Gershwin Build.app's Resources/Catalog.plist
#     (gershwin-components dev, f9e6712), for each app's make arguments.
# It applies the listing rules (README.md, "Not listed") and prints what
# it left out and why. Ycode is listed although NextBSD ships it in
# /System/Applications: it's NextBSD's own fork (nextbsd/libs-xcode), and
# a user can install a newer one for themselves. Libraries an app
# requires are built and installed first, into the same domain as the
# app; they come from NextBSD's fork where it has one. Run it from anywhere after changing any of them:
#
#   python3 catalog/make-catalog.py
#
# The icons themselves are fetched by fetch-icons.py.

import json
import os
import plistlib
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Software", "Resources", "Catalog.plist")

# The order the store shows them in.
CATEGORIES = ["Games", "Productivity", "Graphics", "Internet", "Music & Video",
              "Education", "Science", "Utilities", "Developer Tools", "System"]

# The desktop's own parts: users don't install these.
DESKTOP = {"menu", "dock", "gworkspace", "workspaces", "topbar", "loginpanel"}

# Gershwin components that copy files into /System themselves, whatever
# the installation domain (wiki: Building and Installing).
WRITES_SYSTEM = {
    "bootenvironments",  # its bundle into $(GNUSTEP_SYSTEM_LIBRARY)/Bundles
    "sharing",           # a bundle and sharing-helper into the SYSTEM library
    "icnsimagerep",      # itself into /System/Library/Bundles
    "assistants",        # AssistantFramework into the SYSTEM library, and
                         # BackupAssistant into $(GNUSTEP_SYSTEM_APPS)
    "packagemanager",    # its framework into $(GNUSTEP_SYSTEM_LIBRARY)
}


# Apps that don't build from their repository as it stands; listed again
# once they do.
DOES_NOT_BUILD = {
    "manopen",  # no GNUmakefile, only an Xcode project
    "resound",  # no GNUmakefile
    "vic20",    # only an Xcode project
    "build",    # links PackageManager.framework from /System, which
                # Software can't install (it copies into /System itself)
}

# What NextBSD ships: the NextBSD-desktop package's apps in
# /System/Applications, and its system UI in /System/Library/CoreServices
# (Workspace, the Dock, loginwindow, ScreenCaptureAgent, and NextBSD-gnustep's
# GSSpeechServer), which nextbsd-gnustep-apps also installs in ~/Applications
# for now. An app that builds one of these names isn't listed, since it would
# take NextBSD's app's place; and Software doesn't take a bundle of one of
# these names for a catalog app it didn't install itself.
NEXTBSD_APPS = ["Bluetooth", "Date & Time", "Displays", "Dock", "Energy",
                "GSSpeechServer", "InnerSpace", "Installer", "Keyboard",
                "Language & Region", "loginwindow", "Mouse", "Network",
                "Printers", "ScreenCaptureAgent", "Software", "Sound",
                "Terminal", "Trackpad", "Update", "Users & Login", "Webcam",
                "Workspace", "XLibre"]


def left_out(app, icons):
    if app.get("shipsWithNextBSD"):
        return "ships in /System/Applications"
    if app["id"] in DESKTOP:
        return "part of the desktop"
    if app.get("kind") == "preference pane" or app["id"] == "systempreferences":
        return "preference pane (NextBSD's settings apps cover it)"
    if app["id"] in WRITES_SYSTEM:
        return "copies files into /System itself"
    if app["id"] in DOES_NOT_BUILD:
        return "doesn't build from its repository"
    if app.get("appName", app["name"]) in NEXTBSD_APPS:
        return "builds %s.app, which NextBSD ships" % app.get("appName",
                                                              app["name"])
    if icons.get(app["id"], {}).get("status") != "ok":
        return "no app icon in its repository"
    return None


def origin(repo):
    if repo.startswith("nu-gap/"):
        return "nu-gap"
    if repo.startswith("nextbsd/"):
        return "NextBSD"
    return "Gershwin"


def icon_file(app_id, source_path):
    """The icon's name in Resources/CatalogIcons: the app's id and its own
    format. An .icns is converted to PNG, which GNUstep reads unaided."""
    ext = os.path.splitext(source_path)[1].lower()
    if ext in (".tif", ".tiff"):
        ext = ".tiff"
    elif ext != ".png":
        ext = ".png"
    return app_id + ext


def main():
    with open(os.path.join(HERE, "apps.json"), encoding="utf-8") as f:
        data = json.load(f)
    with open(os.path.join(HERE, "icon-sources.json"), encoding="utf-8") as f:
        icons = json.load(f)
    with open(os.path.join(HERE, "build-catalog.plist"), "rb") as f:
        build = {}
        for entry in plistlib.load(f):
            url = entry["GitURL"].rstrip("/")
            if url.endswith(".git"):
                url = url[:-4]
            build[(entry["Name"], url)] = entry

    apps = []
    for app in data["apps"]:
        why = left_out(app, icons)
        if why:
            print("left out: %-24s %s" % (app["name"], why))
            continue
        repo = app["repo"]
        url = "https://github.com/" + repo
        entry = {
            "Identifier": app["id"],
            "Name": app["name"],
            "AppName": app.get("appName", app["name"]),
            "Description": app["description"],
            "Category": app["category"],
            "Origin": origin(repo),
            "ListedIn": app["listedIn"],
            "Repository": repo,
            "GitURL": url,
        }
        if app.get("path"):
            entry["RepositoryPath"] = app["path"]
            entry["MakefilePath"] = app["path"] + "/GNUmakefile"
        # Build.app's make arguments, where it builds the same repository.
        b = build.get((app["name"], url))
        if b:
            for key in ("MakefilePath", "MakeArgs", "Submodules"):
                if key in b:
                    entry[key] = b[key]
        alternatives = list(app.get("alternatives", []))
        for (name, burl), b in sorted(build.items()):
            if name == app["name"] and burl != url:
                alt = burl.replace("https://github.com/", "")
                if "MakefilePath" in b:
                    alt += "/" + os.path.dirname(b["MakefilePath"])
                alternatives.append(alt)
        if alternatives:
            entry["Alternatives"] = alternatives
        if app.get("requires"):
            entry["Requires"] = app["requires"]
        source = icons[app["id"]]["path"]
        entry["Icon"] = icon_file(app["id"], source)
        entry["IconSource"] = source
        apps.append(entry)

    for app in apps:
        if app["Category"] not in CATEGORIES:
            sys.exit("%s: unknown category %s" % (app["Name"], app["Category"]))

    libraries = [{"Identifier": lib["id"], "Name": lib["name"],
                  "Description": lib["description"],
                  "Repository": lib["repo"],
                  "GitURL": "https://github.com/" + lib["repo"]}
                 for lib in data["libraries"]]

    catalog = {"Categories": CATEGORIES, "Apps": apps, "Libraries": libraries,
               "NextBSDApps": NEXTBSD_APPS}
    with open(OUT, "wb") as f:
        plistlib.dump(catalog, f, sort_keys=False)
    print("%d apps, %d libraries -> %s" % (len(apps), len(libraries),
                                           os.path.normpath(OUT)))


if __name__ == "__main__":
    main()

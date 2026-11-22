# Software

Software is NextBSD's app store: one place to find, install, update and
remove GNUstep apps. It brings together three sources:

- **Build.app's catalog** from Gershwin
  ([Catalog.plist](https://github.com/gershwin-desktop/gershwin-components/blob/dev/Build/Resources/Catalog.plist)).
- **[gershwin-components](https://github.com/gershwin-desktop/gershwin-components)**
  itself: its apps, such as Processes, Console, DiskUtility and Stickies.
- **[nu-gap](https://github.com/nu-gap)**: the GAP apps and libraries carried
  forward.

Software is planned in
[nextbsd/nextbsd#655](https://github.com/nextbsd/nextbsd/issues/655) (epic
E43), with design notes in the [wiki](https://github.com/nextbsd/apps-software/wiki).
The first version of the app is in [`Software/`](Software).

## Building

```sh
gmake ADDITIONAL_LIB_DIRS="-L/Developer/Link -L/usr/X11/lib"
gmake install    # Software.app in ~/Applications
```

Software.app shows the bundled catalog: Featured, Categories, a sortable app
list with each app's details, Installed, Updates and the libraries, and
Software → Preferences… for where new apps go. **Install** builds the app
from source for the user, as Gershwin's Build.app does: a shallow `git
clone`, the libraries it needs, `configure` where there is one, then `gmake`
and `gmake install` with the catalog's make arguments and
`GNUSTEP_INSTALLATION_DOMAIN=USER` on the command line, so it lands in
`~/Applications` even for gershwin-components. The build runs on a thread of
its own, with progress and a log (also in `~/Library/Logs/Software`). This
computer and Network are shown but wait for the privileged helper
([#4](https://github.com/nextbsd/apps-software/issues/4)); Updates waits for
[#6](https://github.com/nextbsd/apps-software/issues/6).

Installed apps are found in `~/Applications`, `/Local/Applications` and
`/Network/Applications`. Software doesn't install an app that would take
the place of one NextBSD ships (Terminal.app, say).

## Mockup

[`mockups/software.html`](mockups/software.html) is an interactive HTML
prototype in the NextBSD theme. Download it and open it in a browser; it's a
single file with the app icons built in. Ratings, sizes, versions and
download counts in it are made up, and administrator authentication is
simulated.

## Rules

- **Where apps go:** the user picks, per app and as a default:
  - **User**: `~/Applications`, just for them, no password.
  - **This computer**: `/Local/Applications`, for all users; needs an
    administrator.
  - **Network**: `/Network/Applications`, shared over the network; needs an
    administrator.

  Removing an app from the last two needs an administrator too.
- **Never /System.** Software never installs into or changes anything under
  `/System`, which belongs to NextBSD. gershwin-components builds into the
  SYSTEM domain by default; Software builds it for the domain the user chose
  instead, and leaves out components that copy files into `/System`
  themselves.
- **Not listed:** apps NextBSD already ships in `/System/Applications`; the
  desktop's own parts (Menu, Dock, file managers, virtual desktops, login
  panels, window managers); preference panes, which NextBSD's settings apps
  cover; and apps without an app icon.
- **Every app shows its origin** (nu-gap or Gershwin) after its category.
- **The catalog ships with Software.** The catalog and every listed app's icon
  are bundled in Software.app, so the store opens instantly and offline.
  Adding an app is a PR to this repository; users get it with the next
  Software package through `pkg upgrade`.

## Catalog data

- [`catalog/software-data.json`](catalog/software-data.json): the three
  sources as collected for the mockup (`buildCatalog`, `gershwinComponents`,
  `nuGap`).
- [`catalog/apps.json`](catalog/apps.json): every app and library from
  them, with its category, as the mockup has them, plus Ycode from
  NextBSD's fork of libs-xcode. Adding an app starts here.
- [`catalog/icon-sources.json`](catalog/icon-sources.json): where each app's
  icon was found in its repository, or why none was.
- [`catalog/build-catalog.plist`](catalog/build-catalog.plist): Build.app's
  `Resources/Catalog.plist` (gershwin-components `dev`, f9e6712), for the
  make arguments.
- [`catalog/make-catalog.py`](catalog/make-catalog.py) makes
  `Software/Resources/Catalog.plist` from them, applying the rules above;
  [`catalog/fetch-icons.py`](catalog/fetch-icons.py) fetches the listed
  apps' icons into `Software/Resources/CatalogIcons` and writes its
  `CREDITS`.

## License

BSD 2-Clause. See [LICENSE](LICENSE). This covers Software's own code.

The app icons in the mockup, and the catalog icons Software will ship, belong
to their projects. [`catalog/icon-sources.json`](catalog/icon-sources.json)
lists where each one comes from.

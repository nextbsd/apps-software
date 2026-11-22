# Software

Software is NextBSD's app store: one place to find, install, update and
remove GNUstep apps. It brings together three sources:

- **Build.app's catalog** from Gershwin
  ([Catalog.plist](https://github.com/gershwin-desktop/gershwin-components/blob/dev/Build/Resources/Catalog.plist)).
- **[gershwin-components](https://github.com/gershwin-desktop/gershwin-components)**
  itself: its apps, such as Processes, Console, DiskUtility and Stickies.
- **[nu-gap](https://github.com/nu-gap)**: the GAP apps and libraries carried
  forward.

Software is at the design stage. It's planned in
[nextbsd/nextbsd#655](https://github.com/nextbsd/nextbsd/issues/655) (epic
E43), with design notes in the [wiki](https://github.com/nextbsd/apps-software/wiki).

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

## Catalog data

- [`catalog/software-data.json`](catalog/software-data.json): the three
  sources as collected for the mockup (`buildCatalog`, `gershwinComponents`,
  `nuGap`).
- [`catalog/icon-sources.json`](catalog/icon-sources.json): where each app's
  icon was found in its repository, or why none was.

## License

BSD 2-Clause. See [LICENSE](LICENSE).

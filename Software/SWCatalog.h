/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * SWCatalog: the catalog bundled in Software.app (Resources/Catalog.plist,
 * made by catalog/make-catalog.py) and its icons (Resources/CatalogIcons),
 * and where each app is installed.
 *
 * An app is a dictionary as in Catalog.plist: Identifier, Name, AppName
 * (the .app it builds), Description, Category, Origin (nu-gap, Gershwin
 * or NextBSD), ListedIn, Repository, GitURL, and where present
 * RepositoryPath, MakefilePath, MakeArgs, Submodules, Alternatives,
 * Requires (library identifiers), Icon and IconSource.
 *
 * Installed apps are found by name in the three domains Software installs
 * to: ~/Applications, /Local/Applications and /Network/Applications. A
 * name NextBSD's own apps use (the catalog's NextBSDApps, such as the
 * Terminal in ~/Applications), or one several catalog apps build (Clock),
 * counts only for the app Software installed there, as recorded in its
 * SWInstalledApps default; so does a bundle whose CFBundleIdentifier is
 * org.nextbsd.*.
 */

#import <AppKit/AppKit.h>

typedef enum
{
  SWLocationUser = 0,		/* ~/Applications */
  SWLocationLocal = 1,		/* /Local/Applications */
  SWLocationNetwork = 2		/* /Network/Applications */
} SWLocation;

#define SWLocationCount 3

/* "User", "This computer", "Network". */
NSString *SWLocationName (SWLocation location);
/* The folder, as shown: "~/Applications" for the user's. */
NSString *SWLocationDisplayPath (SWLocation location);
/* The folder, expanded. */
NSString *SWLocationPath (SWLocation location);
/* This computer and Network need an administrator. */
BOOL SWLocationNeedsAdmin (SWLocation location);

@interface SWCatalog : NSObject
{
  NSArray *categories;
  NSArray *apps;
  NSArray *libraries;
  NSDictionary *byIdentifier;
  NSMutableDictionary *icons;
  NSArray *nextbsdApps;		/* bundle names NextBSD uses */
  NSDictionary *installed;	/* identifier -> NSDictionary (Path, Location, Version) */
}

- (id)initWithBundle:(NSBundle *)bundle;

- (NSArray *)categories;
- (NSArray *)apps;
- (NSArray *)appsInCategory:(NSString *)category;
- (NSArray *)appsMatching:(NSString *)text;
- (NSDictionary *)appWithIdentifier:(NSString *)identifier;
- (NSArray *)libraries;
- (NSDictionary *)libraryWithIdentifier:(NSString *)identifier;
- (NSArray *)appsRequiringLibrary:(NSString *)identifier;

/* The app's icon from CatalogIcons, or the installed app's own. */
- (NSImage *)iconForApp:(NSDictionary *)app;

/* Looks in the three domains again. */
- (void)rescanInstalled;
- (BOOL)isInstalled:(NSDictionary *)app;
/* Path, Location (NSNumber, an SWLocation) and Version, or nil. */
- (NSDictionary *)installInfoForApp:(NSDictionary *)app;
- (NSUInteger)installedCount;
/* NextBSD's own app has this bundle name. */
- (BOOL)isNextBSDAppName:(NSString *)name;
/* Remembers that Software installed app at path. */
- (void)recordInstall:(NSDictionary *)app atPath:(NSString *)path;

@end

/* "Games · nu-gap". */
NSString *SWCategoryLine (NSDictionary *app);

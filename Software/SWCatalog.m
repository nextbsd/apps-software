/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "SWCatalog.h"
#import <GNUstepBase/GNUstep.h>

NSString *
SWLocationName (SWLocation location)
{
  switch (location)
    {
    case SWLocationLocal: return @"This computer";
    case SWLocationNetwork: return @"Network";
    default: return @"User";
    }
}

NSString *
SWLocationDisplayPath (SWLocation location)
{
  switch (location)
    {
    case SWLocationLocal: return @"/Local/Applications";
    case SWLocationNetwork: return @"/Network/Applications";
    default: return @"~/Applications";
    }
}

NSString *
SWLocationPath (SWLocation location)
{
  if (location == SWLocationUser)
    return [NSHomeDirectory () stringByAppendingPathComponent:@"Applications"];
  return SWLocationDisplayPath (location);
}

BOOL
SWLocationNeedsAdmin (SWLocation location)
{
  return location != SWLocationUser;
}

NSString *
SWCategoryLine (NSDictionary *app)
{
  return [NSString stringWithFormat:@"%@ · %@",
                   [app objectForKey:@"Category"],
                   [app objectForKey:@"Origin"]];
}

/* The version an installed bundle says it is. */
static NSString *
SWBundleVersion (NSDictionary *info)
{
  NSArray *keys = [NSArray arrayWithObjects:@"CFBundleShortVersionString",
                           @"ApplicationRelease", @"CFBundleVersion",
                           @"NSAppVersion", nil];
  NSUInteger i;

  for (i = 0; i < [keys count]; i++)
    {
      id value = [info objectForKey:[keys objectAtIndex:i]];

      if ([value isKindOfClass:[NSString class]] && [value length] > 0)
        return value;
    }
  return nil;
}

@implementation SWCatalog

- (id)initWithBundle:(NSBundle *)bundle
{
  if ((self = [super init]) != nil)
    {
      NSString *path = [bundle pathForResource:@"Catalog" ofType:@"plist"];
      NSDictionary *catalog = path != nil
        ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
      NSMutableDictionary *index = [NSMutableDictionary dictionary];
      NSSortDescriptor *byName;
      NSUInteger i;

      if (catalog == nil)
        NSLog (@"Software: no catalog at %@", path);
      byName = AUTORELEASE ([[NSSortDescriptor alloc]
                              initWithKey:@"Name" ascending:YES
                                 selector:@selector (caseInsensitiveCompare:)]);
      categories = RETAIN ([catalog objectForKey:@"Categories"]);
      apps = RETAIN ([[catalog objectForKey:@"Apps"]
                       sortedArrayUsingDescriptors:
                         [NSArray arrayWithObject:byName]]);
      libraries = RETAIN ([catalog objectForKey:@"Libraries"]);
      nextbsdApps = RETAIN ([catalog objectForKey:@"NextBSDApps"]);
      if (categories == nil)
        categories = [[NSArray alloc] init];
      if (apps == nil)
        apps = [[NSArray alloc] init];
      if (libraries == nil)
        libraries = [[NSArray alloc] init];
      for (i = 0; i < [apps count]; i++)
        {
          NSDictionary *app = [apps objectAtIndex:i];

          [index setObject:app forKey:[app objectForKey:@"Identifier"]];
        }
      byIdentifier = [index copy];
      icons = [[NSMutableDictionary alloc] init];
      [self rescanInstalled];
    }
  return self;
}

- (void)dealloc
{
  RELEASE (categories);
  RELEASE (apps);
  RELEASE (libraries);
  RELEASE (nextbsdApps);
  RELEASE (byIdentifier);
  RELEASE (icons);
  RELEASE (installed);
  [super dealloc];
}

- (NSArray *)categories
{
  return categories;
}

- (NSArray *)apps
{
  return apps;
}

- (NSArray *)appsInCategory:(NSString *)category
{
  NSMutableArray *list = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [apps count]; i++)
    {
      NSDictionary *app = [apps objectAtIndex:i];

      if ([[app objectForKey:@"Category"] isEqual:category])
        [list addObject:app];
    }
  return list;
}

/* Every word must be in the name, description, category, origin or
   repository, as the mockup's search. */
- (NSArray *)appsMatching:(NSString *)text
{
  NSArray *words = [[text lowercaseString]
                     componentsSeparatedByCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
  NSMutableArray *list = [NSMutableArray array];
  NSUInteger i, j;

  for (i = 0; i < [apps count]; i++)
    {
      NSDictionary *app = [apps objectAtIndex:i];
      NSString *haystack = [[NSString stringWithFormat:@"%@ %@ %@ %@ %@",
                                      [app objectForKey:@"Name"],
                                      [app objectForKey:@"Description"],
                                      [app objectForKey:@"Category"],
                                      [app objectForKey:@"Origin"],
                                      [app objectForKey:@"Repository"]]
                             lowercaseString];
      BOOL match = YES;

      for (j = 0; j < [words count] && match; j++)
        {
          NSString *word = [words objectAtIndex:j];

          if ([word length] > 0
              && [haystack rangeOfString:word].location == NSNotFound)
            match = NO;
        }
      if (match)
        [list addObject:app];
    }
  return list;
}

- (NSDictionary *)appWithIdentifier:(NSString *)identifier
{
  return identifier != nil ? [byIdentifier objectForKey:identifier] : nil;
}

- (NSArray *)libraries
{
  return libraries;
}

- (NSDictionary *)libraryWithIdentifier:(NSString *)identifier
{
  NSUInteger i;

  for (i = 0; i < [libraries count]; i++)
    {
      NSDictionary *library = [libraries objectAtIndex:i];

      if ([[library objectForKey:@"Identifier"] isEqual:identifier])
        return library;
    }
  return nil;
}

- (NSArray *)appsRequiringLibrary:(NSString *)identifier
{
  NSMutableArray *list = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [apps count]; i++)
    {
      NSDictionary *app = [apps objectAtIndex:i];

      if ([[app objectForKey:@"Requires"] containsObject:identifier])
        [list addObject:app];
    }
  return list;
}

- (NSImage *)iconForApp:(NSDictionary *)app
{
  NSString *identifier = [app objectForKey:@"Identifier"];
  NSImage *icon = [icons objectForKey:identifier];

  if (icon == nil)
    {
      NSString *name = [app objectForKey:@"Icon"];
      NSString *path = [[NSBundle mainBundle]
                         pathForResource:[name stringByDeletingPathExtension]
                                  ofType:[name pathExtension]
                             inDirectory:@"CatalogIcons"];

      if (path != nil)
        icon = AUTORELEASE ([[NSImage alloc] initWithContentsOfFile:path]);
      if (icon == nil)
        icon = [NSImage imageNamed:@"NSApplicationIcon"];
      if (icon != nil)
        [icons setObject:icon forKey:identifier];
    }
  return icon;
}

#define SWInstalledAppsKey @"SWInstalledApps"

- (void)rescanInstalled
{
  NSMutableDictionary *found = [NSMutableDictionary dictionary];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *receipts = [[NSUserDefaults standardUserDefaults]
                             dictionaryForKey:SWInstalledAppsKey];
  NSCountedSet *names = [NSCountedSet set];
  NSUInteger i;
  int location;

  for (i = 0; i < [apps count]; i++)
    [names addObject:[[apps objectAtIndex:i] objectForKey:@"AppName"]];
  for (i = 0; i < [apps count]; i++)
    {
      NSDictionary *app = [apps objectAtIndex:i];
      NSString *identifier = [app objectForKey:@"Identifier"];
      NSString *appName = [app objectForKey:@"AppName"];
      NSString *bundleName = [appName stringByAppendingPathExtension:@"app"];
      BOOL ambiguous = [names countForObject:appName] > 1
        || [nextbsdApps containsObject:appName];

      for (location = 0; location < SWLocationCount; location++)
        {
          NSString *path = [SWLocationPath ((SWLocation) location)
                             stringByAppendingPathComponent:bundleName];
          NSDictionary *info;
          NSString *version;
          BOOL isDir;

          if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir)
            continue;
          if (ambiguous && ![[receipts objectForKey:identifier] isEqual:path])
            continue;
          info = [[NSBundle bundleWithPath:path] infoDictionary];
          if ([[info objectForKey:@"CFBundleIdentifier"]
                hasPrefix:@"org.nextbsd."]
              && ![[receipts objectForKey:identifier] isEqual:path])
            continue;
          version = SWBundleVersion (info);
          [found setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                           path, @"Path",
                                         [NSNumber numberWithInt:location],
                                         @"Location",
                                         version, @"Version", nil]
                    forKey:identifier];
          break;
        }
    }
  ASSIGN (installed, found);
}

- (BOOL)isNextBSDAppName:(NSString *)name
{
  return [nextbsdApps containsObject:name];
}

- (void)recordInstall:(NSDictionary *)app atPath:(NSString *)path
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *receipts = [NSMutableDictionary dictionaryWithDictionary:
                                     [defaults dictionaryForKey:
                                                 SWInstalledAppsKey]];
  NSEnumerator *e = [[receipts allKeys] objectEnumerator];
  NSString *key;

  /* One app per bundle: another that built the same name is gone. */
  while ((key = [e nextObject]) != nil)
    if ([[receipts objectForKey:key] isEqual:path])
      [receipts removeObjectForKey:key];
  [receipts setObject:path forKey:[app objectForKey:@"Identifier"]];
  [defaults setObject:receipts forKey:SWInstalledAppsKey];
  [defaults synchronize];
}

- (BOOL)isInstalled:(NSDictionary *)app
{
  return [self installInfoForApp:app] != nil;
}

- (NSDictionary *)installInfoForApp:(NSDictionary *)app
{
  return [installed objectForKey:[app objectForKey:@"Identifier"]];
}

- (NSUInteger)installedCount
{
  return [installed count];
}

@end

/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "SWController.h"
#import "SWViews.h"
#import <GNUstepBase/GNUstep.h>

/* Layout, in points, from the mockup. */
#define SWWindowWidth 1120.0
#define SWWindowHeight 760.0
#define SWToolbarHeight 36.0
#define SWStatusHeight 22.0
#define SWSourceWidth 200.0
#define SWPad 20.0
#define SWCardWidth 112.0
#define SWCardHeight 122.0
#define SWTileWidth 170.0
#define SWTileHeight 52.0
#define SWSideWidth 140.0

/* Where new apps go unless the Install pop-up says otherwise. */
#define SWDefaultLocationKey @"SWDefaultLocation"

/* The mockup's picks for Featured; any not in the catalog are skipped. */
#define SWHeroApps @"colloquy", @"graphos", @"gschess"
#define SWNewApps @"markdownviewer", @"world-clock", @"the-unarchiver", \
  @"scoremaker", @"mandelbrot", @"stickies", @"camera", @"whisper", \
  @"flexisheet", @"laternamagica", @"talksoup", @"gomoku"
#define SWFeaturedCount 7

/* A row in the source list. */
@interface SWSourceItem : NSObject
{
@public
  NSString *key;		/* "featured", "category:Games", ... */
  NSString *title;
  NSImage *icon;
  NSArray *children;
  BOOL heading;
}
+ (SWSourceItem *)itemWithKey:(NSString *)key title:(NSString *)title
                         icon:(NSImage *)icon;
@end

@implementation SWSourceItem

+ (SWSourceItem *)itemWithKey:(NSString *)aKey title:(NSString *)aTitle
                         icon:(NSImage *)anIcon
{
  SWSourceItem *item = AUTORELEASE ([[self alloc] init]);

  item->key = [aKey copy];
  item->title = [aTitle copy];
  item->icon = RETAIN (anIcon);
  item->heading = anIcon == nil;
  return item;
}

- (void)dealloc
{
  RELEASE (key);
  RELEASE (title);
  RELEASE (icon);
  RELEASE (children);
  [super dealloc];
}

@end

static NSDictionary *
SWRoute (NSString *view, NSString *key, id value)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:view, @"View",
                       value, key, nil];
}

/* Where the catalog entry came from, in words. */
static NSString *
SWListedInText (NSString *listedIn)
{
  if ([listedIn isEqual:@"Build.app"])
    return @"Gershwin Build.app's catalog";
  return listedIn;
}

static NSArray *
SWArray (NSString *first, ...)
{
  NSMutableArray *list = [NSMutableArray array];
  va_list ap;
  NSString *s;

  va_start (ap, first);
  for (s = first; s != nil; s = va_arg (ap, NSString *))
    [list addObject:s];
  va_end (ap);
  return list;
}

static NSScrollView *
SWScroll (NSRect frame)
{
  NSScrollView *scroll = AUTORELEASE ([[NSScrollView alloc] initWithFrame:frame]);

  [scroll setHasVerticalScroller:YES];
  [scroll setHasHorizontalScroller:NO];
  [scroll setBorderType:NSNoBorder];
  [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [scroll setDrawsBackground:YES];
  [scroll setBackgroundColor:SWBackgroundColor ()];
  return scroll;
}

/* A table in a scroll view; columns are {identifier, title, width}. */
static NSTableView *
SWTable (NSScrollView *scroll, NSArray *columns, id owner)
{
  NSTableView *table = AUTORELEASE ([[NSTableView alloc]
                                      initWithFrame:[[scroll contentView]
                                                      bounds]]);
  NSUInteger i;

  for (i = 0; i + 2 < [columns count]; i += 3)
    {
      NSTableColumn *column = AUTORELEASE ([[NSTableColumn alloc]
          initWithIdentifier:[columns objectAtIndex:i]]);

      [[column headerCell] setStringValue:[columns objectAtIndex:i + 1]];
      [column setWidth:[[columns objectAtIndex:i + 2] floatValue]];
      [column setEditable:NO];
      [[column dataCell] setEditable:NO];
      [[column dataCell] setLineBreakMode:NSLineBreakByTruncatingTail];
      [column setResizingMask:NSTableColumnUserResizingMask
                              | NSTableColumnAutoresizingMask];
      [table addTableColumn:column];
    }
  [table setRowHeight:24];
  [table setGridStyleMask:NSTableViewGridNone];
  [table setAllowsEmptySelection:YES];
  [table setAllowsMultipleSelection:NO];
  [table setAllowsColumnReordering:NO];
  [table setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
  [table setAutoresizingMask:NSViewWidthSizable];
  [table setDataSource:owner];
  [table setDelegate:owner];
  [table setTarget:owner];
  [scroll setDocumentView:table];
  [scroll setBorderType:NSBezelBorder];
  return table;
}

@interface SWController (Private)
- (void)buildMenu;
- (void)buildWindow;
- (void)buildSourceItems;
- (NSButton *)toolButton:(NSString *)title glyph:(NSString *)glyph
                       x:(CGFloat)x width:(CGFloat)width action:(SEL)action
                      in:(NSView *)bar;

- (void)go:(NSDictionary *)newRoute;
- (void)replaceRoute:(NSDictionary *)newRoute;
- (void)show;
- (NSString *)sourceKeyForRoute:(NSDictionary *)r;
- (void)syncChrome;
- (void)setStatus:(NSString *)text;
- (void)hostResized:(NSNotification *)note;
- (void)reshow:(id)unused;

- (NSView *)featuredView:(NSRect)frame;
- (NSView *)categoriesView:(NSRect)frame;
- (CGFloat)addTilesTo:(NSView *)view y:(CGFloat)y width:(CGFloat)width;
- (CGFloat)addCards:(NSArray *)apps to:(NSView *)view y:(CGFloat)y
              width:(CGFloat)width;
- (NSView *)listView:(NSRect)frame;
- (NSArray *)appsForRoute:(NSDictionary *)r;
- (NSString *)titleForRoute:(NSDictionary *)r;
- (void)sortList;
- (void)showDetail;
- (NSView *)detailFor:(NSDictionary *)app width:(CGFloat)width;
- (CGFloat)addActionsFor:(NSDictionary *)app to:(NSView *)view y:(CGFloat)y;
- (NSView *)installedView:(NSRect)frame;
- (NSView *)updatesView:(NSRect)frame;
- (NSView *)librariesView:(NSRect)frame;
- (NSView *)titledView:(NSRect)frame title:(NSString *)title
              subtitle:(NSString *)subtitle body:(NSView **)body;

- (SWLocation)defaultLocation;
- (SWLocation)locationFor:(NSDictionary *)app;
- (NSDictionary *)selectedApp;
- (void)openApp:(NSDictionary *)app;
- (void)showLogFor:(NSDictionary *)app;
@end

@implementation SWController

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  RELEASE (catalog);
  RELEASE (window);
  RELEASE (toolButtons);
  RELEASE (sourceItems);
  RELEASE (route);
  RELEASE (history);
  RELEASE (listApps);
  RELEASE (sortKey);
  RELEASE (installedApps);
  RELEASE (installers);
  RELEASE (logs);
  RELEASE (locationChoices);
  RELEASE (prefsPanel);
  RELEASE (logPanel);
  RELEASE (logShown);
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
  NSImage *icon = [NSImage imageNamed:@"Software.png"];

  if (icon != nil)
    [NSApp setApplicationIconImage:icon];
  catalog = [[SWCatalog alloc] initWithBundle:[NSBundle mainBundle]];
  history = [[NSMutableArray alloc] init];
  historyIndex = -1;
  sortKey = @"Name";
  sortAscending = YES;
  installers = [[NSMutableDictionary alloc] init];
  logs = [[NSMutableDictionary alloc] init];
  locationChoices = [[NSMutableDictionary alloc] init];
  [self buildMenu];
  [self buildSourceItems];
  [self buildWindow];
  [self go:SWRoute (@"Featured", nil, nil)];
  [window makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
  return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
  NSEnumerator *e = [installers objectEnumerator];
  SWInstaller *installer;
  BOOL busy = NO;

  while ((installer = [e nextObject]) != nil)
    busy = busy || [installer isRunning];
  if (busy
      && NSRunAlertPanel (@"Quit Software?",
                          @"An app is still being installed. Quitting stops "
                          @"its build.",
                          @"Keep Installing", @"Quit", nil)
         == NSAlertDefaultReturn)
    return NSTerminateCancel;
  e = [installers objectEnumerator];
  while ((installer = [e nextObject]) != nil)
    [installer cancel];
  return NSTerminateNow;
}

/* ---- actions ---- */

- (void)back:(id)sender
{
  if (historyIndex > 0)
    {
      historyIndex--;
      ASSIGN (route, [history objectAtIndex:historyIndex]);
      [self show];
    }
}

- (void)forward:(id)sender
{
  if (historyIndex + 1 < (NSInteger) [history count])
    {
      historyIndex++;
      ASSIGN (route, [history objectAtIndex:historyIndex]);
      [self show];
    }
}

- (void)showFeatured:(id)sender
{
  [self go:SWRoute (@"Featured", nil, nil)];
}

- (void)showCategories:(id)sender
{
  [self go:SWRoute (@"Categories", nil, nil)];
}

- (void)showInstalled:(id)sender
{
  [self go:SWRoute (@"Installed", nil, nil)];
}

- (void)showUpdates:(id)sender
{
  [self go:SWRoute (@"Updates", nil, nil)];
}

- (void)showAllApps:(id)sender
{
  [self go:SWRoute (@"List", nil, nil)];
}

- (void)showGames:(id)sender
{
  [self go:SWRoute (@"List", @"Category", @"Games")];
}

- (void)findApps:(id)sender
{
  [window makeFirstResponder:searchField];
}

- (void)search:(id)sender
{
  NSString *text = [[searchField stringValue]
                     stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];

  if ([text length] == 0)
    {
      if ([route objectForKey:@"Search"] != nil)
        [self back:nil];
      return;
    }
  /* Typing refines the search; it doesn't add a step to go back to. */
  if ([route objectForKey:@"Search"] != nil)
    [self replaceRoute:SWRoute (@"List", @"Search", text)];
  else
    [self go:SWRoute (@"List", @"Search", text)];
}

/* A card or tile: an app's identifier or "category:Name". */
- (void)cardClicked:(id)sender
{
  NSString *what = [sender representedObject];

  if ([what hasPrefix:@"category:"])
    [self go:SWRoute (@"List", @"Category", [what substringFromIndex:9])];
  else
    [self go:SWRoute (@"List", @"App", what)];
}

- (void)heroDetails:(id)sender
{
  [self go:SWRoute (@"List", @"App", [[sender cell] representedObject])];
}

- (void)heroDot:(id)sender
{
  heroIndex = [sender tag];
  [self show];
}

- (void)sourceClicked:(id)sender
{
  SWSourceItem *item = [sourceList itemAtRow:[sourceList selectedRow]];
  NSString *key;

  if (selectingSource || item == nil || item->heading)
    return;
  key = item->key;
  if ([key hasPrefix:@"category:"])
    [self go:SWRoute (@"List", @"Category", [key substringFromIndex:9])];
  else if ([key isEqual:@"all"])
    [self go:SWRoute (@"List", nil, nil)];
  else
    [self go:SWRoute ([key capitalizedString], nil, nil)];
}

- (void)install:(id)sender
{
  NSDictionary *app = [catalog appWithIdentifier:[[sender cell] representedObject]];
  NSString *identifier = [app objectForKey:@"Identifier"];
  NSMutableArray *libraries = [NSMutableArray array];
  NSArray *requires = [app objectForKey:@"Requires"];
  SWLocation location = [self locationFor:app];
  SWInstaller *installer;
  NSString *bundle;
  NSUInteger i;

  if (app == nil || [[installers objectForKey:identifier] isRunning])
    return;
  if (location != SWLocationUser)
    {
      NSRunAlertPanel (@"Needs an Administrator",
                       [NSString stringWithFormat:
                                   @"Installing for %@ (%@) needs Software's "
                                 @"privileged helper, which isn't available "
                                 @"yet. Choose User to install %@ in your "
                                 @"own Applications folder.",
                                 SWLocationName (location),
                                 SWLocationDisplayPath (location),
                                 [app objectForKey:@"Name"]],
                       @"OK", nil, nil);
      return;
    }
  /* Installing puts AppName.app in ~/Applications, over whatever is
     there: never over NextBSD's own app, and only over another app when
     the user says so. */
  bundle = [[SWLocationPath (SWLocationUser)
              stringByAppendingPathComponent:[app objectForKey:@"AppName"]]
             stringByAppendingPathExtension:@"app"];
  if ([catalog isNextBSDAppName:[app objectForKey:@"AppName"]]
      && ![catalog isInstalled:app])
    {
      NSRunAlertPanel (@"Can't Install",
                       [NSString stringWithFormat:
                                   @"%@ builds %@.app, the name of an app "
                                 @"NextBSD comes with. Installing it would "
                                 @"take that app's place, so Software "
                                 @"doesn't.",
                                 [app objectForKey:@"Name"],
                                 [app objectForKey:@"AppName"]],
                       @"OK", nil, nil);
      return;
    }
  if ([[NSFileManager defaultManager] fileExistsAtPath:bundle]
      && ![catalog isInstalled:app]
      && NSRunAlertPanel (@"Replace It?",
                          [NSString stringWithFormat:
                                      @"There's already a %@.app in "
                                    @"~/Applications that Software didn't "
                                    @"install for %@. Installing %@ "
                                    @"replaces it.",
                                    [app objectForKey:@"AppName"],
                                    [app objectForKey:@"Name"],
                                    [app objectForKey:@"Name"]],
                          @"Cancel", @"Replace", nil)
         == NSAlertDefaultReturn)
    return;
  for (i = 0; i < [requires count]; i++)
    {
      NSDictionary *library = [catalog libraryWithIdentifier:
                                         [requires objectAtIndex:i]];

      if (library != nil)
        [libraries addObject:library];
    }
  installer = AUTORELEASE ([[SWInstaller alloc] initWithApp:app
                                                  libraries:libraries
                                                   delegate:self]);
  [installers setObject:installer forKey:identifier];
  [logs setObject:[NSMutableString string] forKey:identifier];
  [installer start];
  [self setStatus:[NSString stringWithFormat:@"Installing %@ for you…",
                            [app objectForKey:@"Name"]]];
  /* The Install button is in the detail: not from inside its action. */
  [self performSelector:@selector (showDetail) withObject:nil afterDelay:0];
}

- (void)cancelInstall:(id)sender
{
  [[installers objectForKey:[[sender cell] representedObject]] cancel];
}

- (void)locationChanged:(id)sender
{
  NSString *identifier = [[sender cell] representedObject];

  [locationChoices setObject:[NSNumber numberWithInteger:
                                         [sender indexOfSelectedItem]]
                      forKey:identifier];
  /* Not while the pop-up is still in its action: it's in the detail. */
  [self performSelector:@selector (showDetail) withObject:nil afterDelay:0];
}

- (void)open:(id)sender
{
  [self openApp:[catalog appWithIdentifier:[[sender cell] representedObject]]];
}

- (void)openInstalled:(id)sender
{
  NSInteger row = [installedTable selectedRow];

  if (row >= 0 && row < (NSInteger) [installedApps count])
    [self openApp:[installedApps objectAtIndex:row]];
}

- (void)showInstalledInStore:(id)sender
{
  NSInteger row = [installedTable selectedRow];

  if (row >= 0 && row < (NSInteger) [installedApps count])
    [self go:SWRoute (@"List", @"App", [[installedApps objectAtIndex:row]
                                          objectForKey:@"Identifier"])];
}

- (void)showLog:(id)sender
{
  [self showLogFor:[catalog appWithIdentifier:[[sender cell] representedObject]]];
}

- (void)showPreferences:(id)sender
{
  if (prefsPanel == nil)
    {
      NSView *content;
      NSBox *box;
      NSButtonCell *prototype;
      NSString *note;
      int i;

      prefsPanel = [[NSPanel alloc]
          initWithContentRect:NSMakeRect (240, 300, 480, 236)
                    styleMask:NSTitledWindowMask | NSClosableWindowMask
                      backing:NSBackingStoreBuffered
                        defer:YES];
      [prefsPanel setTitle:@"Software Preferences"];
      [prefsPanel setReleasedWhenClosed:NO];
      content = [prefsPanel contentView];
      box = AUTORELEASE ([[NSBox alloc]
                           initWithFrame:NSMakeRect (16, 74, 448, 150)]);
      [box setTitle:@"Install new apps for"];
      [content addSubview:box];
      prototype = AUTORELEASE ([[NSButtonCell alloc] init]);
      [prototype setButtonType:NSRadioButton];
      prefsMatrix = AUTORELEASE ([[NSMatrix alloc]
                                   initWithFrame:NSMakeRect (8, 8, 130, 102)
                                            mode:NSRadioModeMatrix
                                       prototype:prototype
                                    numberOfRows:SWLocationCount
                                 numberOfColumns:1]);
      [prefsMatrix setCellSize:NSMakeSize (130, 34)];
      for (i = 0; i < SWLocationCount; i++)
        {
          NSString *who = i == SWLocationUser ? @"just you"
            : (i == SWLocationLocal ? @"every user of this computer"
               : @"every computer that shares it");
          NSString *detail = [NSString stringWithFormat:@"%@ · %@%@",
                                       SWLocationDisplayPath ((SWLocation) i),
                                       who,
                                       SWLocationNeedsAdmin ((SWLocation) i)
                                         ? @"\nNeeds an administrator" : @""];

          [[prefsMatrix cellAtRow:i column:0]
            setTitle:SWLocationName ((SWLocation) i)];
          [[box contentView]
            addSubview:SWLabel (NSMakeRect (140, 110 - (i + 1) * 34 + 2, 290,
                                            30),
                                detail, SWFont (11), SWSecondaryTextColor ())];
          [[[[[box contentView] subviews] lastObject] cell] setWraps:YES];
        }
      [prefsMatrix setTarget:self];
      [prefsMatrix setAction:@selector (defaultLocationChanged:)];
      [[box contentView] addSubview:prefsMatrix];
      note = @"You can still choose a different place on each app's "
        @"Install pop-up. This computer and Network wait for Software's "
        @"privileged helper; until it's there, apps install for User.";
      [content addSubview:SWWrappingLabel (NSMakeRect (18, 16, 444, 52), note,
                                           SWSmallFont (),
                                           SWSecondaryTextColor ())];
    }
  [prefsMatrix selectCellAtRow:[self defaultLocation] column:0];
  [prefsPanel makeKeyAndOrderFront:self];
}

- (void)defaultLocationChanged:(id)sender
{
  [[NSUserDefaults standardUserDefaults]
    setInteger:[prefsMatrix selectedRow] forKey:SWDefaultLocationKey];
  [self showDetail];
}

/* ---- the installer ---- */

- (void)installer:(SWInstaller *)installer logged:(NSString *)text
{
  NSString *identifier = [[installer app] objectForKey:@"Identifier"];

  [[logs objectForKey:identifier] appendString:text];
  if (logPanel != nil && [logShown isEqual:identifier]
      && [logPanel isVisible])
    {
      NSTextStorage *storage = [logView textStorage];
      NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                            SWMonoFont (11), NSFontAttributeName,
                                          SWTextColor (),
                                          NSForegroundColorAttributeName, nil];
      NSAttributedString *line = [[NSAttributedString alloc]
                                   initWithString:text attributes:attrs];

      [storage appendAttributedString:line];
      RELEASE (line);
      [logView scrollRangeToVisible:NSMakeRange ([storage length], 0)];
    }
}

- (void)installerChanged:(SWInstaller *)installer
{
  if ([self selectedApp] != [installer app] || detailProgress == nil)
    return;
  [detailProgress setDoubleValue:[installer progress] * 100.0];
  [detailStep setStringValue:[installer step]];
}

- (void)installerFinished:(SWInstaller *)installer
{
  NSString *name = [[installer app] objectForKey:@"Name"];

  if ([installer succeeded])
    [catalog recordInstall:[installer app] atPath:[installer installedPath]];
  [catalog rescanInstalled];
  if ([installer succeeded])
    [self setStatus:[NSString stringWithFormat:@"%@ is installed. %@", name,
                              [installer result]]];
  else
    [self setStatus:[NSString stringWithFormat:@"%@: %@", name,
                              [installer result]]];
  [sourceList reloadData];
  if ([[route objectForKey:@"View"] isEqual:@"List"])
    {
      [appTable reloadData];
      [self showDetail];
    }
  else if (![[route objectForKey:@"View"] isEqual:@"Featured"])
    [self show];
}

/* ---- tables ---- */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
  if (table == appTable)
    return (NSInteger) [listApps count];
  if (table == installedTable)
    return (NSInteger) [installedApps count];
  if (table == libraryTable)
    return (NSInteger) [[catalog libraries] count];
  return 0;
}

- (id)tableView:(NSTableView *)table
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)row
{
  NSString *key = [column identifier];
  NSDictionary *item;

  if (table == libraryTable)
    {
      NSArray *users;
      NSMutableArray *names = [NSMutableArray array];
      NSUInteger i;

      item = [[catalog libraries] objectAtIndex:row];
      if (![key isEqual:@"UsedBy"])
        return [item objectForKey:key];
      users = [catalog appsRequiringLibrary:[item objectForKey:@"Identifier"]];
      for (i = 0; i < [users count]; i++)
        [names addObject:[[users objectAtIndex:i] objectForKey:@"Name"]];
      return [names count] > 0 ? [names componentsJoinedByString:@", "]
        : @"No catalog app yet";
    }
  item = (table == appTable ? listApps : installedApps) != nil
    ? [(table == appTable ? listApps : installedApps) objectAtIndex:row] : nil;
  if (item == nil)
    return nil;
  if ([key isEqual:@"Name"])
    return [catalog isInstalled:item] && table == appTable
      ? [NSString stringWithFormat:@"%@  ✓", [item objectForKey:@"Name"]]
      : [item objectForKey:@"Name"];
  if ([key isEqual:@"Category"])
    return SWCategoryLine (item);
  if ([key isEqual:@"Version"])
    {
      NSString *version = [[catalog installInfoForApp:item]
                            objectForKey:@"Version"];

      return version != nil ? version : @"—";
    }
  if ([key isEqual:@"Location"])
    {
      NSDictionary *info = [catalog installInfoForApp:item];

      return [NSString stringWithFormat:@"%@   %@",
                       SWLocationName ([[info objectForKey:@"Location"]
                                         intValue]),
                       [[info objectForKey:@"Path"]
                         stringByAbbreviatingWithTildeInPath]];
    }
  return [item objectForKey:key];
}

- (void)tableView:(NSTableView *)table
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)column
              row:(NSInteger)row
{
  NSArray *list = table == appTable ? listApps
    : (table == installedTable ? installedApps : nil);

  if ([cell isKindOfClass:[SWIconTextCell class]] && list != nil
      && row < (NSInteger) [list count])
    [cell setIcon:[catalog iconForApp:[list objectAtIndex:row]]];
  if ([cell respondsToSelector:@selector (setTextColor:)])
    [cell setTextColor:([[column identifier] isEqual:@"Name"]
                        || [table isRowSelected:row])
                       ? SWTextColor () : SWSecondaryTextColor ()];
}

- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)c
              row:(NSInteger)row
{
  return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSInteger row;
  NSString *identifier = nil;
  NSMutableDictionary *r;

  if ([note object] != appTable)
    return;
  row = [appTable selectedRow];
  if (row >= 0 && row < (NSInteger) [listApps count])
    identifier = [[listApps objectAtIndex:row] objectForKey:@"Identifier"];
  if ((identifier == nil && [route objectForKey:@"App"] == nil)
      || [identifier isEqual:[route objectForKey:@"App"]])
    return;
  /* Choosing an app in the list keeps the step; Back leaves the list. */
  r = AUTORELEASE ([route mutableCopy]);
  if (identifier != nil)
    [r setObject:identifier forKey:@"App"];
  else
    [r removeObjectForKey:@"App"];
  ASSIGN (route, r);
  [history replaceObjectAtIndex:historyIndex withObject:route];
  [self showDetail];
}

- (void)tableView:(NSTableView *)table
    didClickTableColumn:(NSTableColumn *)column
{
  if (table != appTable)
    return;
  if ([sortKey isEqual:[column identifier]])
    sortAscending = !sortAscending;
  else
    {
      ASSIGN (sortKey, [column identifier]);
      sortAscending = YES;
    }
  [self sortList];
}

/* ---- the source list ---- */

- (NSInteger)outlineView:(NSOutlineView *)view numberOfChildrenOfItem:(id)item
{
  return (NSInteger) [(item == nil ? sourceItems
                       : ((SWSourceItem *) item)->children) count];
}

- (id)outlineView:(NSOutlineView *)view child:(NSInteger)index ofItem:(id)item
{
  return [(item == nil ? sourceItems : ((SWSourceItem *) item)->children)
           objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)view isItemExpandable:(id)item
{
  return [((SWSourceItem *) item)->children count] > 0;
}

- (id)outlineView:(NSOutlineView *)view
    objectValueForTableColumn:(NSTableColumn *)column
                       byItem:(id)item
{
  return ((SWSourceItem *) item)->title;
}

- (BOOL)outlineView:(NSOutlineView *)view shouldSelectItem:(id)item
{
  return !((SWSourceItem *) item)->heading;
}

- (BOOL)outlineView:(NSOutlineView *)view
    shouldEditTableColumn:(NSTableColumn *)column
                     item:(id)item
{
  return NO;
}

- (void)outlineView:(NSOutlineView *)view
    willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn *)column
               item:(id)anItem
{
  SWSourceItem *item = anItem;
  NSString *key = item->key;
  NSUInteger count = 0;
  BOOL counted = YES;

  [cell setHeading:item->heading];
  [cell setIcon:item->icon];
  if ([key isEqual:@"all"])
    count = [[catalog apps] count];
  else if ([key hasPrefix:@"category:"])
    count = [[catalog appsInCategory:[key substringFromIndex:9]] count];
  else if ([key isEqual:@"installed"])
    count = [catalog installedCount];
  else if ([key isEqual:@"libraries"])
    count = [[catalog libraries] count];
  else
    counted = NO;
  [cell setBadge:counted ? [NSString stringWithFormat:@"%lu",
                                     (unsigned long) count] : nil];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)note
{
  [self sourceClicked:sourceList];
}

/* ---- menus ---- */

- (BOOL)validateMenuItem:(id<NSMenuItem>)item
{
  if ([item action] == @selector (back:))
    return historyIndex > 0;
  if ([item action] == @selector (forward:))
    return historyIndex + 1 < (NSInteger) [history count];
  return YES;
}

@end

@implementation SWController (Private)

- (void)buildMenu
{
  NSMenu *menu = AUTORELEASE ([[NSMenu alloc] initWithTitle:@"Software"]);
  NSMenu *edit = AUTORELEASE ([[NSMenu alloc] initWithTitle:@"Edit"]);
  NSMenu *store = AUTORELEASE ([[NSMenu alloc] initWithTitle:@"Store"]);
  NSMenu *windows = AUTORELEASE ([[NSMenu alloc] initWithTitle:@"Window"]);
  id<NSMenuItem> item;

  [menu addItemWithTitle:@"About Software"
                  action:@selector (orderFrontStandardAboutPanel:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Preferences…"
                  action:@selector (showPreferences:)
           keyEquivalent:@","];

  item = [menu addItemWithTitle:@"Edit" action:NULL keyEquivalent:@""];
  [edit addItemWithTitle:@"Cut" action:@selector (cut:) keyEquivalent:@"x"];
  [edit addItemWithTitle:@"Copy" action:@selector (copy:) keyEquivalent:@"c"];
  [edit addItemWithTitle:@"Paste" action:@selector (paste:) keyEquivalent:@"v"];
  [edit addItemWithTitle:@"Select All" action:@selector (selectAll:)
           keyEquivalent:@"a"];
  [menu setSubmenu:edit forItem:item];

  item = [menu addItemWithTitle:@"Store" action:NULL keyEquivalent:@""];
  [store addItemWithTitle:@"Featured" action:@selector (showFeatured:)
            keyEquivalent:@"1"];
  [store addItemWithTitle:@"Categories" action:@selector (showCategories:)
            keyEquivalent:@"2"];
  [store addItemWithTitle:@"Installed" action:@selector (showInstalled:)
            keyEquivalent:@"3"];
  [store addItemWithTitle:@"Updates" action:@selector (showUpdates:)
            keyEquivalent:@"4"];
  [store addItemWithTitle:@"Back" action:@selector (back:) keyEquivalent:@"["];
  [store addItemWithTitle:@"Forward" action:@selector (forward:)
            keyEquivalent:@"]"];
  [store addItemWithTitle:@"Search" action:@selector (findApps:)
            keyEquivalent:@"f"];
  [menu setSubmenu:store forItem:item];

  item = [menu addItemWithTitle:@"Window" action:NULL keyEquivalent:@""];
  [windows addItemWithTitle:@"Minimize"
                     action:@selector (performMiniaturize:)
              keyEquivalent:@"m"];
  [windows addItemWithTitle:@"Close"
                     action:@selector (performClose:)
              keyEquivalent:@"w"];
  [menu setSubmenu:windows forItem:item];
  [NSApp setWindowsMenu:windows];
  [menu addItemWithTitle:@"Hide" action:@selector (hide:) keyEquivalent:@"h"];
  [menu addItemWithTitle:@"Quit" action:@selector (terminate:) keyEquivalent:@"q"];
  [NSApp setMainMenu:menu];
}

- (void)buildSourceItems
{
  NSMutableArray *items = [NSMutableArray array];
  NSMutableArray *categories = [NSMutableArray array];
  NSArray *names = [catalog categories];
  SWSourceItem *item;
  NSUInteger i;

  [items addObject:[SWSourceItem itemWithKey:@"store" title:@"Store" icon:nil]];
  [items addObject:[SWSourceItem itemWithKey:@"featured" title:@"Featured"
                                        icon:SWGlyph (@"star", 16, nil)]];
  [items addObject:[SWSourceItem itemWithKey:@"all" title:@"All Apps"
                                        icon:SWGlyph (@"all", 16, nil)]];
  item = [SWSourceItem itemWithKey:@"categories" title:@"Categories"
                              icon:SWGlyph (@"grid", 16, nil)];
  for (i = 0; i < [names count]; i++)
    {
      NSString *name = [names objectAtIndex:i];

      [categories addObject:
                    [SWSourceItem itemWithKey:[@"category:"
                                                stringByAppendingString:name]
                                        title:name
                                         icon:SWCategoryIcon (name, 16)]];
    }
  item->children = [categories copy];
  categoriesItem = item;
  [items addObject:item];
  [items addObject:[SWSourceItem itemWithKey:@"computer" title:@"This Computer"
                                        icon:nil]];
  [items addObject:[SWSourceItem itemWithKey:@"installed" title:@"Installed"
                                        icon:SWGlyph (@"disk", 16, nil)]];
  [items addObject:[SWSourceItem itemWithKey:@"updates" title:@"Updates"
                                        icon:SWGlyph (@"update", 16, nil)]];
  [items addObject:[SWSourceItem itemWithKey:@"catalog" title:@"Catalog"
                                        icon:nil]];
  [items addObject:[SWSourceItem itemWithKey:@"libraries" title:@"Libraries"
                                        icon:SWGlyph (@"books", 16, nil)]];
  sourceItems = [items copy];
}

- (NSButton *)toolButton:(NSString *)title glyph:(NSString *)glyph
                       x:(CGFloat)x width:(CGFloat)width action:(SEL)action
                      in:(NSView *)bar
{
  NSButton *button = SWButton (NSMakeRect (x, 6, width, 24), title, self,
                               action);

  [button setButtonType:(title != nil ? NSPushOnPushOffButton
                         : NSMomentaryPushInButton)];
  [button setImage:SWGlyph (glyph, title != nil ? 16 : 10, nil)];
  [button setImagePosition:(title != nil ? NSImageLeft : NSImageOnly)];
  [button setFont:SWFont (12)];
  [button setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
  [bar addSubview:button];
  return button;
}

- (void)buildWindow
{
  NSView *content, *bar;
  NSScrollView *sourceScroll;
  NSTableColumn *column;
  SWSourceCell *cell;
  NSSize size;
  CGFloat x, bodyY, bodyH;

  window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect (120, 80, SWWindowWidth, SWWindowHeight)
                styleMask:NSTitledWindowMask | NSClosableWindowMask
                          | NSMiniaturizableWindowMask | NSResizableWindowMask
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setTitle:@"Software"];
  [window setReleasedWhenClosed:NO];
  [window setMinSize:NSMakeSize (760, 520)];
  [window setFrameAutosaveName:@"Software"];
  content = [window contentView];
  size = [content bounds].size;

  /* The toolbar, across the top. */
  bar = AUTORELEASE ([[NSView alloc]
                       initWithFrame:NSMakeRect (0, size.height
                                                 - SWToolbarHeight,
                                                 size.width,
                                                 SWToolbarHeight)]);
  [bar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [content addSubview:bar];
  backButton = [self toolButton:nil glyph:@"back" x:10 width:28
                         action:@selector (back:) in:bar];
  [backButton setToolTip:@"Back"];
  forwardButton = [self toolButton:nil glyph:@"forward" x:38 width:28
                            action:@selector (forward:) in:bar];
  [forwardButton setToolTip:@"Forward"];
  x = 82;
  toolButtons = RETAIN (([NSDictionary dictionaryWithObjectsAndKeys:
    [self toolButton:@"Featured" glyph:@"star" x:x width:96
              action:@selector (showFeatured:) in:bar], @"Featured",
    [self toolButton:@"Categories" glyph:@"grid" x:x + 102 width:108
              action:@selector (showCategories:) in:bar], @"Categories",
    [self toolButton:@"Installed" glyph:@"disk" x:x + 216 width:96
              action:@selector (showInstalled:) in:bar], @"Installed",
    [self toolButton:@"Updates" glyph:@"update" x:x + 318 width:92
              action:@selector (showUpdates:) in:bar], @"Updates",
    nil]));
  searchField = AUTORELEASE ([[NSSearchField alloc]
                               initWithFrame:NSMakeRect (size.width - 230, 6,
                                                         220, 24)]);
  [[searchField cell] setPlaceholderString:@"Search apps"];
  [[searchField cell] setSendsWholeSearchString:NO];
  [searchField setTarget:self];
  [searchField setAction:@selector (search:)];
  [searchField setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [bar addSubview:searchField];

  /* The source list at the left, the content at the right, the status
     line under them. */
  bodyY = SWStatusHeight;
  bodyH = size.height - SWToolbarHeight - SWStatusHeight;
  sourceScroll = SWScroll (NSMakeRect (0, bodyY, SWSourceWidth, bodyH));
  [sourceScroll setAutoresizingMask:NSViewHeightSizable];
  [sourceScroll setBorderType:NSBezelBorder];
  [sourceScroll setAutohidesScrollers:YES];
  sourceList = AUTORELEASE ([[NSOutlineView alloc]
                              initWithFrame:[[sourceScroll contentView]
                                              bounds]]);
  column = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier:@"source"]);
  [column setWidth:SWSourceWidth - 6];
  cell = AUTORELEASE ([[SWSourceCell alloc] initTextCell:@""]);
  [cell setEditable:NO];
  [column setDataCell:cell];
  [column setEditable:NO];
  [sourceList addTableColumn:column];
  [sourceList setOutlineTableColumn:column];
  [sourceList setHeaderView:nil];
  [sourceList setCornerView:nil];
  [sourceList setRowHeight:24];
  [sourceList setIndentationPerLevel:14];
  [sourceList setGridStyleMask:NSTableViewGridNone];
  [sourceList setBackgroundColor:SWBackgroundColor ()];
  [sourceList setAllowsEmptySelection:YES];
  [sourceList setDataSource:self];
  [sourceList setDelegate:self];
  [sourceScroll setDocumentView:sourceList];
  [content addSubview:sourceScroll];
  [sourceList reloadData];
  [sourceList expandItem:categoriesItem];

  host = AUTORELEASE ([[NSView alloc]
                        initWithFrame:NSMakeRect (SWSourceWidth, bodyY,
                                                  size.width - SWSourceWidth,
                                                  bodyH)]);
  [host setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [host setPostsFrameChangedNotifications:YES];
  [[NSNotificationCenter defaultCenter]
    addObserver:self selector:@selector (hostResized:)
           name:NSViewFrameDidChangeNotification object:host];
  [content addSubview:host];

  statusField = SWLabel (NSMakeRect (10, 3, size.width * 0.6, 16), @"",
                         SWBoldFont (11), SWTextColor ());
  [statusField setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [content addSubview:statusField];
  countField = SWLabel (NSMakeRect (size.width * 0.6 + 20, 3,
                                    size.width * 0.4 - 30, 16), @"",
                        SWFont (11), SWSecondaryTextColor ());
  [countField setAlignment:NSRightTextAlignment];
  [countField setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
  [content addSubview:countField];
}

/* ---- routes ---- */

- (void)go:(NSDictionary *)newRoute
{
  if ([newRoute isEqual:route])
    {
      [self show];
      return;
    }
  while ((NSInteger) [history count] > historyIndex + 1)
    [history removeLastObject];
  [history addObject:newRoute];
  historyIndex = [history count] - 1;
  ASSIGN (route, newRoute);
  [self show];
}

- (void)replaceRoute:(NSDictionary *)newRoute
{
  ASSIGN (route, newRoute);
  if (historyIndex >= 0)
    [history replaceObjectAtIndex:historyIndex withObject:route];
  [self show];
}

- (NSString *)sourceKeyForRoute:(NSDictionary *)r
{
  NSString *view = [r objectForKey:@"View"];

  if ([r objectForKey:@"Search"] != nil)
    return nil;
  if ([view isEqual:@"List"])
    return [r objectForKey:@"Category"] != nil
      ? [@"category:" stringByAppendingString:[r objectForKey:@"Category"]]
      : @"all";
  return [view lowercaseString];
}

/* The toolbar, source list and search field follow the route. */
- (void)syncChrome
{
  NSString *view = [route objectForKey:@"View"];
  NSString *key = [self sourceKeyForRoute:route];
  NSEnumerator *e = [toolButtons keyEnumerator];
  NSString *name;
  NSInteger row, i;

  while ((name = [e nextObject]) != nil)
    [[toolButtons objectForKey:name]
      setState:([name isEqual:view]
                || ([name isEqual:@"Categories"]
                    && [route objectForKey:@"Category"] != nil))
               ? NSOnState : NSOffState];
  [backButton setEnabled:historyIndex > 0];
  [forwardButton setEnabled:historyIndex + 1 < (NSInteger) [history count]];
  if ([route objectForKey:@"Search"] == nil)
    [searchField setStringValue:@""];
  else if (![[searchField stringValue]
              isEqual:[route objectForKey:@"Search"]])
    [searchField setStringValue:[route objectForKey:@"Search"]];

  selectingSource = YES;
  [sourceList reloadData];
  row = -1;
  for (i = 0; key != nil && i < [sourceList numberOfRows]; i++)
    if ([((SWSourceItem *) [sourceList itemAtRow:i])->key isEqual:key])
      row = i;
  if (row >= 0)
    [sourceList selectRow:row byExtendingSelection:NO];
  else
    [sourceList deselectAll:nil];
  selectingSource = NO;
}

- (void)show
{
  NSString *view = [route objectForKey:@"View"];
  NSRect frame = [host bounds];
  NSView *shown;
  NSString *count;
  NSUInteger n = [[catalog apps] count];

  [self syncChrome];
  appTable = nil;
  detailScroll = nil;
  detailProgress = nil;
  detailStep = nil;
  installedTable = nil;
  libraryTable = nil;
  [AUTORELEASE ([[host subviews] copy]) makeObjectsPerformSelector:
                            @selector (removeFromSuperview)];
  if ([view isEqual:@"List"])
    {
      shown = [self listView:frame];
      count = [NSString stringWithFormat:@"%lu %@",
                        (unsigned long) [listApps count],
                        [route objectForKey:@"Search"] != nil
                          ? @"matches" : @"apps"];
    }
  else if ([view isEqual:@"Categories"])
    {
      shown = [self categoriesView:frame];
      count = [NSString stringWithFormat:@"%lu categories",
                        (unsigned long) [[catalog categories] count]];
    }
  else if ([view isEqual:@"Installed"])
    {
      shown = [self installedView:frame];
      count = [NSString stringWithFormat:@"%lu installed",
                        (unsigned long) [catalog installedCount]];
    }
  else if ([view isEqual:@"Updates"])
    {
      shown = [self updatesView:frame];
      count = @"";
    }
  else if ([view isEqual:@"Libraries"])
    {
      shown = [self librariesView:frame];
      count = [NSString stringWithFormat:@"%lu libraries",
                        (unsigned long) [[catalog libraries] count]];
    }
  else
    {
      shown = [self featuredView:frame];
      count = [NSString stringWithFormat:@"%lu apps in the catalog",
                        (unsigned long) n];
    }
  [shown setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [host addSubview:shown];
  shownWidth = NSWidth (frame);
  [countField setStringValue:count];
  if ([view isEqual:@"List"])
    [self showDetail];
}

- (void)setStatus:(NSString *)text
{
  [statusField setStringValue:text != nil ? text : @""];
}

/* The cards and the detail are laid out for a width: lay them out again
   once a resize settles. */
- (void)hostResized:(NSNotification *)note
{
  if (fabs (NSWidth ([host bounds]) - shownWidth) < 1)
    return;
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector (reshow:)
                                             object:nil];
  [self performSelector:@selector (reshow:) withObject:nil afterDelay:0.2];
}

- (void)reshow:(id)unused
{
  NSString *view = [route objectForKey:@"View"];

  if ([view isEqual:@"Featured"] || [view isEqual:@"Categories"])
    [self show];
  else if ([view isEqual:@"List"])
    {
      shownWidth = NSWidth ([host bounds]);
      [self showDetail];
    }
}

/* ---- Featured and Categories ---- */

- (CGFloat)addCards:(NSArray *)apps to:(NSView *)view y:(CGFloat)y
              width:(CGFloat)width
{
  NSUInteger columns = MAX (1, (NSUInteger) ((width - 20) / (SWCardWidth + 4)));
  CGFloat cardW = floor ((width - 20 - 4 * (columns - 1)) / columns);
  NSUInteger i;

  for (i = 0; i < [apps count]; i++)
    {
      NSDictionary *app = [apps objectAtIndex:i];
      SWCardView *card = AUTORELEASE ([[SWCardView alloc]
          initWithFrame:NSMakeRect (10 + (i % columns) * (cardW + 4),
                                    y + (i / columns) * (SWCardHeight + 4),
                                    cardW, SWCardHeight)
                  style:SWCardApp]);

      [card setImage:[catalog iconForApp:app]];
      [card setTitle:[app objectForKey:@"Name"]];
      [card setSubtitle:SWCategoryLine (app)];
      [card setNote:[catalog isInstalled:app] ? @"✓ Installed" : nil];
      [card setRepresentedObject:[app objectForKey:@"Identifier"]];
      [card setToolTip:[app objectForKey:@"Description"]];
      [card setTarget:self];
      [card setAction:@selector (cardClicked:)];
      [view addSubview:card];
    }
  return y + ((([apps count] + columns - 1) / columns)
              * (SWCardHeight + 4)) + 6;
}

- (CGFloat)addTilesTo:(NSView *)view y:(CGFloat)y width:(CGFloat)width
{
  NSArray *categories = [catalog categories];
  NSUInteger columns = MAX (1, (NSUInteger) ((width - 20 + 8)
                                             / (SWTileWidth + 8)));
  CGFloat tileW = floor ((width - 20 - 8 * (columns - 1)) / columns);
  NSUInteger i;

  for (i = 0; i < [categories count]; i++)
    {
      NSString *name = [categories objectAtIndex:i];
      SWCardView *tile = AUTORELEASE ([[SWCardView alloc]
          initWithFrame:NSMakeRect (10 + (i % columns) * (tileW + 8),
                                    y + (i / columns) * (SWTileHeight + 8),
                                    tileW, SWTileHeight)
                  style:SWCardCategory]);

      [tile setImage:SWCategoryIcon (name, 36)];
      [tile setTitle:name];
      [tile setSubtitle:[NSString stringWithFormat:@"%lu apps",
                                  (unsigned long) [[catalog appsInCategory:name]
                                                    count]]];
      [tile setRepresentedObject:[@"category:" stringByAppendingString:name]];
      [tile setTarget:self];
      [tile setAction:@selector (cardClicked:)];
      [view addSubview:tile];
    }
  return y + (([categories count] + columns - 1) / columns)
    * (SWTileHeight + 8) + 2;
}

/* A box with its heading and, at the right of it, a link-like button. */
static SWBoxView *
SWAddBox (NSView *view, CGFloat y, CGFloat width, NSString *title,
          NSString *link, id target, SEL action)
{
  SWBoxView *box = AUTORELEASE ([[SWBoxView alloc]
                                  initWithFrame:NSMakeRect (SWPad, y, width, 100)
                                          title:title]);

  if (link != nil)
    {
      NSButton *button = SWButton (NSMakeRect (width - 130, 3, 124, 20), link,
                                   target, action);

      [button setBordered:NO];
      [button setFont:SWFont (11)];
      [button setAlignment:NSRightTextAlignment];
      [box addSubview:button];
    }
  [view addSubview:box];
  return box;
}

static void
SWFitBox (SWBoxView *box, CGFloat height)
{
  NSRect frame = [box frame];

  frame.size.height = height;
  [box setFrame:frame];
}

- (NSView *)featuredView:(NSRect)frame
{
  NSScrollView *scroll = SWScroll (frame);
  CGFloat width = NSWidth (frame) - [NSScroller scrollerWidth];
  CGFloat inner = width - 2 * SWPad, y = 18, h, heroH;
  SWFlippedView *doc = AUTORELEASE ([[SWFlippedView alloc]
                                      initWithFrame:NSMakeRect (0, 0, width,
                                                                1000)]);
  NSMutableArray *heroes = [NSMutableArray array];
  NSMutableArray *picks = [NSMutableArray array];
  NSMutableArray *games = [NSMutableArray array];
  NSArray *ids;
  NSDictionary *hero;
  SWBevelView *panel;
  SWBoxView *box;
  NSImageView *iconView;
  NSTextField *label;
  NSButton *button;
  NSUInteger i;

  ids = SWArray (SWHeroApps, nil);
  for (i = 0; i < [ids count]; i++)
    if ([catalog appWithIdentifier:[ids objectAtIndex:i]] != nil)
      [heroes addObject:[catalog appWithIdentifier:[ids objectAtIndex:i]]];
  ids = SWArray (SWNewApps, nil);
  for (i = 0; i < [ids count] && [picks count] < SWFeaturedCount; i++)
    if ([catalog appWithIdentifier:[ids objectAtIndex:i]] != nil)
      [picks addObject:[catalog appWithIdentifier:[ids objectAtIndex:i]]];
  ids = [catalog appsInCategory:@"Games"];
  for (i = 0; i < [ids count] && [games count] < SWFeaturedCount; i++)
    if (![picks containsObject:[ids objectAtIndex:i]]
        && ![heroes containsObject:[ids objectAtIndex:i]])
      [games addObject:[ids objectAtIndex:i]];

  /* The featured app, with a dot for each. */
  if ([heroes count] > 0)
    {
      hero = [heroes objectAtIndex:heroIndex % [heroes count]];
      panel = AUTORELEASE ([[SWBevelView alloc]
                             initWithFrame:NSMakeRect (SWPad, y, inner, 142)]);
      iconView = AUTORELEASE ([[NSImageView alloc]
                                initWithFrame:NSMakeRect (26, 23, 96, 96)]);
      [iconView setImage:[catalog iconForApp:hero]];
      [iconView setImageScaling:NSScaleProportionally];
      [iconView setEditable:NO];
      [panel addSubview:iconView];
      [panel addSubview:SWLabel (NSMakeRect (146, 20, inner - 170, 14),
                                 [[NSString stringWithFormat:@"Featured · %@",
                                            [hero objectForKey:@"Category"]]
                                   uppercaseString],
                                 SWBoldFont (10), SWSecondaryTextColor ())];
      [panel addSubview:SWLabel (NSMakeRect (146, 34, inner - 170, 34),
                                 [hero objectForKey:@"Name"], SWBoldFont (26),
                                 SWTextColor ())];
      label = SWWrappingLabel (NSMakeRect (146, 70, MIN (inner - 190, 420), 18),
                               [hero objectForKey:@"Description"],
                               SWFont (13), SWTextColor ());
      [panel addSubview:label];
      heroH = MAX (142, NSMaxY ([label frame]) + 10 + 24 + 20);
      button = SWButton (NSMakeRect (146, NSMaxY ([label frame]) + 10, 110, 24),
                         @"See Details", self, @selector (heroDetails:));
      [[button cell] setRepresentedObject:[hero objectForKey:@"Identifier"]];
      [panel addSubview:button];
      for (i = 0; [heroes count] > 1 && i < [heroes count]; i++)
        {
          NSButton *dot = AUTORELEASE ([[NSButton alloc]
              initWithFrame:NSMakeRect (inner - 14 - 16 * ([heroes count] - i),
                                        heroH - 22, 11, 11)]);

          [dot setTitle:@""];
          [dot setButtonType:NSOnOffButton];
          [dot setState:(i == heroIndex % [heroes count]) ? NSOnState
                                                         : NSOffState];
          [dot setTag:(NSInteger) i];
          [dot setToolTip:[NSString stringWithFormat:@"Show %@",
                                    [[heroes objectAtIndex:i]
                                      objectForKey:@"Name"]]];
          [dot setTarget:self];
          [dot setAction:@selector (heroDot:)];
          [panel addSubview:dot];
        }
      [panel setFrame:NSMakeRect (SWPad, y, inner, heroH)];
      [doc addSubview:panel];
      y += heroH + 20;
    }

  box = SWAddBox (doc, y, inner, @"New & Noteworthy", @"See All Apps",
                  self, @selector (showAllApps:));
  h = [self addCards:picks to:box y:SWBoxHeading + 10 width:inner];
  SWFitBox (box, h);
  y += h + 18;

  box = SWAddBox (doc, y, inner, @"Games", @"See All Games", self,
                  @selector (showGames:));
  h = [self addCards:games to:box y:SWBoxHeading + 10 width:inner];
  SWFitBox (box, h);
  y += h + 18;

  box = SWAddBox (doc, y, inner, @"Browse by Category", nil, nil, NULL);
  h = [self addTilesTo:box y:SWBoxHeading + 10 width:inner];
  SWFitBox (box, h + 8);
  y += h + 8 + 24;

  [doc setFrame:NSMakeRect (0, 0, width, MAX (y, NSHeight (frame)))];
  [scroll setDocumentView:doc];
  return scroll;
}

- (NSView *)categoriesView:(NSRect)frame
{
  NSScrollView *scroll = SWScroll (frame);
  CGFloat width = NSWidth (frame) - [NSScroller scrollerWidth];
  CGFloat inner = width - 2 * SWPad, h;
  SWFlippedView *doc = AUTORELEASE ([[SWFlippedView alloc]
                                      initWithFrame:NSMakeRect (0, 0, width,
                                                                1000)]);
  SWBoxView *box;

  [doc addSubview:SWLabel (NSMakeRect (SWPad, 16, 200, 24), @"Categories",
                           SWBoldFont (18), SWTextColor ())];
  [doc addSubview:SWLabel (NSMakeRect (SWPad + 130, 22, inner - 130, 16),
                           @"Each app's category, from the catalog",
                           SWFont (12), SWSecondaryTextColor ())];
  box = SWAddBox (doc, 52, inner, @"Browse by Category", nil, nil, NULL);
  h = [self addTilesTo:box y:SWBoxHeading + 10 width:inner];
  SWFitBox (box, h + 8);
  [doc setFrame:NSMakeRect (0, 0, width, MAX (52 + h + 32, NSHeight (frame)))];
  [scroll setDocumentView:doc];
  return scroll;
}

/* ---- the app list and the detail ---- */

- (NSArray *)appsForRoute:(NSDictionary *)r
{
  if ([r objectForKey:@"Search"] != nil)
    return [catalog appsMatching:[r objectForKey:@"Search"]];
  if ([r objectForKey:@"Category"] != nil)
    return [catalog appsInCategory:[r objectForKey:@"Category"]];
  return [catalog apps];
}

- (NSString *)titleForRoute:(NSDictionary *)r
{
  if ([r objectForKey:@"Search"] != nil)
    return [NSString stringWithFormat:@"Results for “%@”",
                     [r objectForKey:@"Search"]];
  if ([r objectForKey:@"Category"] != nil)
    return [r objectForKey:@"Category"];
  return @"All Apps";
}

- (NSView *)listView:(NSRect)frame
{
  NSSplitView *split = AUTORELEASE ([[NSSplitView alloc] initWithFrame:frame]);
  CGFloat listH = floor (NSHeight (frame) * 0.48);
  CGFloat width = NSWidth (frame);
  NSScrollView *top = SWScroll (NSMakeRect (0, 0, width, listH));
  NSTableColumn *name;
  SWIconTextCell *cell;

  [split setVertical:NO];
  appTable = SWTable (top, [NSArray arrayWithObjects:
                                      @"Name", @"Name",
                                    [NSNumber numberWithFloat:width * 0.36],
                                    @"Category", @"Category",
                                    [NSNumber numberWithFloat:width * 0.26],
                                    @"Repository", @"Source",
                                    [NSNumber numberWithFloat:width * 0.34],
                                    nil],
                      self);
  name = [appTable tableColumnWithIdentifier:@"Name"];
  cell = AUTORELEASE ([[SWIconTextCell alloc] initTextCell:@""]);
  [cell setEditable:NO];
  [cell setLineBreakMode:NSLineBreakByTruncatingTail];
  [name setDataCell:cell];
  [split addSubview:top];
  detailScroll = SWScroll (NSMakeRect (0, listH + 8, width,
                                       NSHeight (frame) - listH - 8));
  [split addSubview:detailScroll];
  [split adjustSubviews];
  [top setFrame:NSMakeRect (0, 0, width, listH)];
  [detailScroll setFrame:NSMakeRect (0, listH + [split dividerThickness],
                                     width, NSHeight (frame) - listH
                                     - [split dividerThickness])];

  ASSIGN (listApps, [self appsForRoute:route]);
  [self sortList];
  return split;
}

/* Sorts the list by sortKey, marks the column heading and keeps the
   selected app selected. */
- (void)sortList
{
  NSArray *columns = [appTable tableColumns];
  NSString *selected = [route objectForKey:@"App"];
  NSArray *titles = [NSArray arrayWithObjects:@"Name", @"Category",
                             @"Source", nil];
  NSMutableArray *descriptors = [NSMutableArray array];
  NSUInteger i, row;

  [descriptors addObject:AUTORELEASE ([[NSSortDescriptor alloc]
                                        initWithKey:sortKey
                                          ascending:sortAscending
                                           selector:@selector (caseInsensitiveCompare:)])];
  if ([sortKey isEqual:@"Category"])
    [descriptors addObject:AUTORELEASE ([[NSSortDescriptor alloc]
                                          initWithKey:@"Origin"
                                            ascending:sortAscending
                                             selector:@selector (caseInsensitiveCompare:)])];
  [descriptors addObject:AUTORELEASE ([[NSSortDescriptor alloc]
                                        initWithKey:@"Name"
                                          ascending:YES
                                           selector:@selector (caseInsensitiveCompare:)])];
  ASSIGN (listApps, [listApps sortedArrayUsingDescriptors:descriptors]);
  for (i = 0; i < [columns count] && i < [titles count]; i++)
    {
      NSTableColumn *column = [columns objectAtIndex:i];
      NSString *title = [titles objectAtIndex:i];

      if ([[column identifier] isEqual:sortKey])
        title = [title stringByAppendingString:sortAscending ? @"  ▲" : @"  ▼"];
      [[column headerCell] setStringValue:title];
    }
  [[appTable headerView] setNeedsDisplay:YES];
  [appTable reloadData];
  row = NSNotFound;
  for (i = 0; selected != nil && i < [listApps count]; i++)
    if ([[[listApps objectAtIndex:i] objectForKey:@"Identifier"]
          isEqual:selected])
      row = i;
  if (row != NSNotFound)
    {
      [appTable selectRow:(NSInteger) row byExtendingSelection:NO];
      [appTable scrollRowToVisible:(NSInteger) row];
    }
}

- (void)showDetail
{
  NSDictionary *app = [self selectedApp];
  CGFloat width;
  NSView *doc;

  if (detailScroll == nil)
    return;
  detailProgress = nil;
  detailStep = nil;
  width = [detailScroll contentSize].width;
  if (app != nil)
    doc = [self detailFor:app width:width];
  else
    {
      NSSize size = [detailScroll contentSize];
      NSImageView *glyph;
      NSString *text;

      doc = AUTORELEASE ([[SWFlippedView alloc]
                           initWithFrame:NSMakeRect (0, 0, size.width,
                                                     size.height)]);
      glyph = AUTORELEASE ([[NSImageView alloc]
                             initWithFrame:NSMakeRect (size.width / 2 - 20,
                                                       size.height / 2 - 50,
                                                       40, 40)]);
      [glyph setImage:SWGlyph (@"grid", 40, SWLineColor ())];
      [glyph setEditable:NO];
      [doc addSubview:glyph];
      text = [NSString stringWithFormat:@"%@ · %lu apps\n"
                       @"Select an app to see its details.",
                       [self titleForRoute:route],
                       (unsigned long) [listApps count]];
      if ([listApps count] == 0)
        text = [NSString stringWithFormat:@"No apps match “%@”.\nTry a "
                         @"shorter word, or a category like “games”.",
                         [route objectForKey:@"Search"]];
      [doc addSubview:SWWrappingLabel (NSMakeRect (20, size.height / 2,
                                                   size.width - 40, 34),
                                       text, SWFont (12.5),
                                       SWSecondaryTextColor ())];
      [[[[doc subviews] lastObject] cell] setAlignment:NSCenterTextAlignment];
    }
  [detailScroll setDocumentView:doc];
}

/* One row of the facts: a label at the right of its column, the value
   after it. */
static CGFloat
SWAddFact (NSView *view, CGFloat y, CGFloat width, NSString *label,
           NSString *value, NSFont *font)
{
  NSTextField *field;

  [view addSubview:SWLabel (NSMakeRect (10, y, 76, 16), label, SWFont (12),
                            SWSecondaryTextColor ())];
  [[[[view subviews] lastObject] cell] setAlignment:NSRightTextAlignment];
  field = SWWrappingLabel (NSMakeRect (94, y, width - 104, 16), value,
                           font != nil ? font : SWFont (12), SWTextColor ());
  [field setSelectable:YES];
  [view addSubview:field];
  return y + NSHeight ([field frame]) + 4;
}

- (NSView *)detailFor:(NSDictionary *)app width:(CGFloat)width
{
  SWFlippedView *doc = AUTORELEASE ([[SWFlippedView alloc]
                                      initWithFrame:NSMakeRect (0, 0, width,
                                                                400)]);
  NSDictionary *info = [catalog installInfoForApp:app];
  NSArray *requires = [app objectForKey:@"Requires"];
  NSMutableArray *names = [NSMutableArray array];
  NSImageView *iconView;
  NSTextField *field;
  SWBevelView *facts;
  NSString *source;
  CGFloat x = SWPad + SWSideWidth + 22;
  CGFloat mainW = MAX (300, width - x - SWPad);
  CGFloat factsW = MIN (580, mainW), y, sideBottom, fy;
  NSUInteger i;

  iconView = AUTORELEASE ([[NSImageView alloc]
                            initWithFrame:NSMakeRect (SWPad + 22, 18, 96, 96)]);
  [iconView setImage:[catalog iconForApp:app]];
  [iconView setImageScaling:NSScaleProportionally];
  [iconView setEditable:NO];
  [doc addSubview:iconView];
  sideBottom = [self addActionsFor:app to:doc y:126];

  [doc addSubview:SWLabel (NSMakeRect (x, 16, mainW, 26),
                           [app objectForKey:@"Name"], SWBoldFont (20),
                           SWTextColor ())];
  [doc addSubview:SWLabel (NSMakeRect (x, 44, mainW, 16),
                           [NSString stringWithFormat:@"%@ · Application",
                                     SWCategoryLine (app)],
                           SWFont (13), SWSecondaryTextColor ())];
  field = SWWrappingLabel (NSMakeRect (x, 68, MIN (mainW, 480), 16),
                           [app objectForKey:@"Description"], SWFont (13),
                           SWTextColor ());
  [doc addSubview:field];
  y = NSMaxY ([field frame]) + 14;

  facts = AUTORELEASE ([[SWBevelView alloc]
                         initWithFrame:NSMakeRect (x, y, factsW, 100)]);
  [facts setSunken:YES];
  fy = 10;
  source = [app objectForKey:@"Repository"];
  if ([app objectForKey:@"RepositoryPath"] != nil)
    source = [NSString stringWithFormat:@"%@ / %@", source,
                       [app objectForKey:@"RepositoryPath"]];
  fy = SWAddFact (facts, fy, factsW, @"Source", source, SWMonoFont (11.5));
  if ([[app objectForKey:@"Alternatives"] count] > 0)
    fy = SWAddFact (facts, fy, factsW, @"Also at",
                    [[app objectForKey:@"Alternatives"]
                      componentsJoinedByString:@", "], SWMonoFont (11.5));
  fy = SWAddFact (facts, fy, factsW, @"Catalog",
                  SWListedInText ([app objectForKey:@"ListedIn"]), nil);
  if ([info objectForKey:@"Version"] != nil)
    fy = SWAddFact (facts, fy, factsW, @"Version",
                    [NSString stringWithFormat:@"%@ installed; installing "
                              @"builds the latest source",
                              [info objectForKey:@"Version"]], nil);
  else
    fy = SWAddFact (facts, fy, factsW, @"Version",
                    @"Built from the latest source when installed", nil);
  if (info != nil)
    fy = SWAddFact (facts, fy, factsW, @"Location",
                    [NSString stringWithFormat:@"%@   %@",
                              SWLocationName ([[info objectForKey:@"Location"]
                                                intValue]),
                              [[info objectForKey:@"Path"]
                                stringByAbbreviatingWithTildeInPath]], nil);
  for (i = 0; i < [requires count]; i++)
    {
      NSDictionary *library = [catalog libraryWithIdentifier:
                                         [requires objectAtIndex:i]];

      [names addObject:library != nil ? [library objectForKey:@"Name"]
                                      : [requires objectAtIndex:i]];
    }
  if ([names count] > 0)
    fy = SWAddFact (facts, fy, factsW, @"Requires",
                    [NSString stringWithFormat:@"%@ (built and installed "
                              @"with it)",
                              [names componentsJoinedByString:@", "]], nil);
  if ([[app objectForKey:@"MakeArgs"] count] > 0)
    fy = SWAddFact (facts, fy, factsW, @"Builds with",
                    [NSString stringWithFormat:@"gmake %@",
                              [[app objectForKey:@"MakeArgs"]
                                componentsJoinedByString:@" "]],
                    SWMonoFont (11.5));
  fy = SWAddFact (facts, fy, factsW, @"Icon",
                  [NSString stringWithFormat:@"From the repository: %@",
                            [app objectForKey:@"IconSource"]], nil);
  [facts setFrame:NSMakeRect (x, y, factsW, fy + 6)];
  [doc addSubview:facts];
  y += fy + 6;

  [doc setFrame:NSMakeRect (0, 0, width,
                            MAX (MAX (y, sideBottom) + SWPad,
                                 [detailScroll contentSize].height))];
  return doc;
}

/* Under the icon: Install and where, its progress, or Open. Returns the
   bottom. */
- (CGFloat)addActionsFor:(NSDictionary *)app to:(NSView *)view y:(CGFloat)y
{
  NSString *identifier = [app objectForKey:@"Identifier"];
  SWInstaller *installer = [installers objectForKey:identifier];
  NSDictionary *info = [catalog installInfoForApp:app];
  CGFloat x = SWPad, w = SWSideWidth;
  NSButton *button;
  NSTextField *label;

  if ([installer isRunning])
    {
      detailProgress = AUTORELEASE ([[NSProgressIndicator alloc]
                                      initWithFrame:NSMakeRect (x + 10, y + 4,
                                                                w - 20, 14)]);
      [detailProgress setIndeterminate:NO];
      [detailProgress setMinValue:0];
      [detailProgress setMaxValue:100];
      [detailProgress setDoubleValue:[installer progress] * 100.0];
      [view addSubview:detailProgress];
      detailStep = SWWrappingLabel (NSMakeRect (x, y + 24, w, 30),
                                    [installer step], SWFont (11),
                                    SWSecondaryTextColor ());
      [detailStep setAlignment:NSCenterTextAlignment];
      [view addSubview:detailStep];
      y += 60;
      button = SWButton (NSMakeRect (x + 20, y, w - 40, 24), @"Show Log",
                         self, @selector (showLog:));
      [[button cell] setRepresentedObject:identifier];
      [view addSubview:button];
      button = SWButton (NSMakeRect (x + 20, y + 30, w - 40, 24), @"Cancel",
                         self, @selector (cancelInstall:));
      [[button cell] setRepresentedObject:identifier];
      [view addSubview:button];
      return y + 54;
    }

  if (info != nil)
    {
      SWLocation where = [[info objectForKey:@"Location"] intValue];

      button = SWButton (NSMakeRect (x + 15, y, w - 30, 26), @"Open", self,
                         @selector (open:));
      [button setKeyEquivalent:@"\r"];
      [[button cell] setRepresentedObject:identifier];
      [view addSubview:button];
      y += 32;
      label = SWLabel (NSMakeRect (x, y, w, 16), SWLocationName (where),
                       SWFont (11), SWSecondaryTextColor ());
      [label setAlignment:NSCenterTextAlignment];
      [view addSubview:label];
      label = SWWrappingLabel (NSMakeRect (x, y + 15, w, 16),
                               SWLocationDisplayPath (where), SWMonoFont (10.5),
                               SWSecondaryTextColor ());
      [label setAlignment:NSCenterTextAlignment];
      [view addSubview:label];
      y += 15 + NSHeight ([label frame]) + 6;
    }
  else
    {
      SWLocation location = [self locationFor:app];
      NSPopUpButton *popup;
      int i;

      button = SWButton (NSMakeRect (x + 15, y, w - 30, 26), @"Install", self,
                         @selector (install:));
      [button setKeyEquivalent:@"\r"];
      [button setEnabled:!SWLocationNeedsAdmin (location)];
      [[button cell] setRepresentedObject:identifier];
      [view addSubview:button];
      y += 32;
      label = SWLabel (NSMakeRect (x, y, w, 16), @"Install for:", SWFont (11.5),
                       SWSecondaryTextColor ());
      [label setAlignment:NSCenterTextAlignment];
      [view addSubview:label];
      y += 17;
      popup = AUTORELEASE ([[NSPopUpButton alloc]
                             initWithFrame:NSMakeRect (x + 15, y, w - 30, 22)
                                 pullsDown:NO]);
      for (i = 0; i < SWLocationCount; i++)
        [popup addItemWithTitle:SWLocationName ((SWLocation) i)];
      [popup selectItemAtIndex:location];
      [[popup cell] setRepresentedObject:identifier];
      [popup setTarget:self];
      [popup setAction:@selector (locationChanged:)];
      [popup setFont:SWFont (12)];
      [view addSubview:popup];
      y += 26;
      label = SWLabel (NSMakeRect (x, y, w, 16), SWLocationDisplayPath (location),
                       SWMonoFont (10.5), SWSecondaryTextColor ());
      [label setAlignment:NSCenterTextAlignment];
      [view addSubview:label];
      y += 18;
      if (SWLocationNeedsAdmin (location))
        {
          label = SWWrappingLabel (NSMakeRect (x, y, w, 16),
                                   @"Needs an administrator, through "
                                   @"Software's privileged helper, which "
                                   @"isn't available yet.",
                                   SWFont (11), SWWarningColor ());
          [label setAlignment:NSCenterTextAlignment];
          [view addSubview:label];
          y += NSHeight ([label frame]) + 4;
        }
    }

  /* The last install's outcome if it didn't work, and its log. */
  if (installer != nil && ![installer succeeded])
    {
      label = SWWrappingLabel (NSMakeRect (x, y + 4, w, 16), [installer result],
                               SWFont (11), SWWarningColor ());
      [label setAlignment:NSCenterTextAlignment];
      [view addSubview:label];
      y += NSHeight ([label frame]) + 8;
    }
  if (installer != nil)
    {
      button = SWButton (NSMakeRect (x + 20, y, w - 40, 24), @"Show Log",
                         self, @selector (showLog:));
      [[button cell] setRepresentedObject:identifier];
      [view addSubview:button];
      y += 28;
    }
  return y;
}

/* ---- Installed, Updates, Libraries ---- */

/* A heading and a line under it, over a body that fills the rest. */
- (NSView *)titledView:(NSRect)frame title:(NSString *)title
              subtitle:(NSString *)subtitle body:(NSView **)body
{
  NSView *view = AUTORELEASE ([[NSView alloc] initWithFrame:frame]);
  CGFloat w = NSWidth (frame), h = NSHeight (frame);
  NSTextField *label;
  NSSize titleSize;

  label = SWLabel (NSMakeRect (SWPad, h - 42, w / 2, 24), title,
                   SWBoldFont (18), SWTextColor ());
  [label setAutoresizingMask:NSViewMinYMargin];
  [view addSubview:label];
  titleSize = [[label cell] cellSize];
  label = SWLabel (NSMakeRect (SWPad + titleSize.width + 10, h - 38,
                               w - titleSize.width - 2 * SWPad - 10, 16),
                   subtitle, SWFont (12), SWSecondaryTextColor ());
  [label setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
  [view addSubview:label];
  *body = AUTORELEASE ([[NSView alloc]
                         initWithFrame:NSMakeRect (SWPad, 14, w - 2 * SWPad,
                                                   h - 56 - 14)]);
  [*body setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [view addSubview:*body];
  return view;
}

- (NSView *)installedView:(NSRect)frame
{
  NSView *body, *view;
  NSScrollView *scroll;
  NSTableColumn *name;
  SWIconTextCell *cell;
  NSButton *button;
  NSRect b;
  NSMutableArray *list = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [[catalog apps] count]; i++)
    if ([catalog isInstalled:[[catalog apps] objectAtIndex:i]])
      [list addObject:[[catalog apps] objectAtIndex:i]];
  ASSIGN (installedApps, list);
  view = [self titledView:frame title:@"Installed"
                 subtitle:[NSString stringWithFormat:
                                      @"%lu catalog apps in your, this "
                                    @"computer's and the network's "
                                    @"Applications folders",
                                    (unsigned long) [list count]]
                     body:&body];
  b = [body bounds];
  if ([list count] == 0)
    {
      NSTextField *label = SWLabel (NSMakeRect (0, NSHeight (b) - 30,
                                                NSWidth (b), 18),
                                    @"Nothing from the catalog is installed "
                                    @"yet.", SWFont (13),
                                    SWSecondaryTextColor ());

      [label setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
      [body addSubview:label];
      button = SWButton (NSMakeRect (0, NSHeight (b) - 62, 140, 24),
                         @"Browse Featured", self, @selector (showFeatured:));
      [button setAutoresizingMask:NSViewMinYMargin];
      [body addSubview:button];
      return view;
    }
  scroll = SWScroll (NSMakeRect (0, 34, NSWidth (b), NSHeight (b) - 34));
  installedTable = SWTable (scroll, [NSArray arrayWithObjects:
                                               @"Name", @"Name",
                                             [NSNumber numberWithFloat:
                                                         NSWidth (b) * 0.34],
                                             @"Version", @"Version",
                                             [NSNumber numberWithFloat:90],
                                             @"Location", @"Location",
                                             [NSNumber numberWithFloat:
                                                         NSWidth (b) * 0.5],
                                             nil],
                            self);
  [installedTable setRowHeight:30];
  [installedTable reloadData];
  [installedTable setDoubleAction:@selector (openInstalled:)];
  name = [installedTable tableColumnWithIdentifier:@"Name"];
  cell = AUTORELEASE ([[SWIconTextCell alloc] initTextCell:@""]);
  [cell setEditable:NO];
  [name setDataCell:cell];
  [body addSubview:scroll];
  button = SWButton (NSMakeRect (NSWidth (b) - 100, 0, 100, 24), @"Open",
                     self, @selector (openInstalled:));
  [button setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
  [body addSubview:button];
  button = SWButton (NSMakeRect (NSWidth (b) - 236, 0, 128, 24),
                     @"Show in Store", self, @selector (showInstalledInStore:));
  [button setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
  [body addSubview:button];
  [body addSubview:SWLabel (NSMakeRect (0, 4, NSWidth (b) - 250, 16),
                            @"Removing apps comes with updates and removal "
                            @"(nextbsd/apps-software#6).", SWFont (11),
                            SWSecondaryTextColor ())];
  return view;
}

- (NSView *)updatesView:(NSRect)frame
{
  NSView *view = AUTORELEASE ([[NSView alloc] initWithFrame:frame]);
  CGFloat cx = NSWidth (frame) / 2, cy = NSHeight (frame) * 0.62;
  NSImageView *glyph;
  NSTextField *label;
  NSUInteger mask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin
    | NSViewMaxYMargin;

  glyph = AUTORELEASE ([[NSImageView alloc]
                         initWithFrame:NSMakeRect (cx - 28, cy, 56, 56)]);
  [glyph setImage:SWGlyph (@"update", 56, SWSecondaryTextColor ())];
  [glyph setEditable:NO];
  [glyph setAutoresizingMask:mask];
  [view addSubview:glyph];
  label = SWLabel (NSMakeRect (cx - 250, cy - 34, 500, 22),
                   @"Software doesn't check for updates yet.", SWBoldFont (16),
                   SWTextColor ());
  [label setAlignment:NSCenterTextAlignment];
  [label setAutoresizingMask:mask];
  [view addSubview:label];
  label = SWWrappingLabel (NSMakeRect (cx - 250, cy - 80, 500, 40),
                           [NSString stringWithFormat:
                                       @"Comparing installed apps with their "
                                     @"repositories comes with "
                                     @"nextbsd/apps-software#6. %lu catalog "
                                     @"apps are installed now; installing "
                                     @"one again builds its latest source.",
                                     (unsigned long) [catalog installedCount]],
                           SWFont (12), SWSecondaryTextColor ());
  [label setAlignment:NSCenterTextAlignment];
  [label setAutoresizingMask:mask];
  [view addSubview:label];
  return view;
}

- (NSView *)librariesView:(NSRect)frame
{
  NSView *body, *view;
  NSScrollView *scroll;
  NSRect b;

  view = [self titledView:frame title:@"Libraries"
                 subtitle:@"Built and installed with the apps that need "
                          @"them, in the same place"
                     body:&body];
  b = [body bounds];
  scroll = SWScroll (b);
  libraryTable = SWTable (scroll, [NSArray arrayWithObjects:
                                             @"Name", @"Library",
                                           [NSNumber numberWithFloat:110],
                                           @"Description", @"Description",
                                           [NSNumber numberWithFloat:
                                                       NSWidth (b) * 0.42],
                                           @"Repository", @"Source",
                                           [NSNumber numberWithFloat:170],
                                           @"UsedBy", @"Used by",
                                           [NSNumber numberWithFloat:
                                                       NSWidth (b) * 0.2],
                                           nil],
                          self);
  [libraryTable reloadData];
  [body addSubview:scroll];
  return view;
}

/* ---- helpers ---- */

- (SWLocation)defaultLocation
{
  NSInteger value = [[NSUserDefaults standardUserDefaults]
                      integerForKey:SWDefaultLocationKey];

  return value >= 0 && value < SWLocationCount ? (SWLocation) value
                                               : SWLocationUser;
}

- (SWLocation)locationFor:(NSDictionary *)app
{
  NSNumber *choice = [locationChoices objectForKey:
                                        [app objectForKey:@"Identifier"]];

  return choice != nil ? (SWLocation) [choice intValue]
                       : [self defaultLocation];
}

- (NSDictionary *)selectedApp
{
  if (![[route objectForKey:@"View"] isEqual:@"List"])
    return nil;
  return [catalog appWithIdentifier:[route objectForKey:@"App"]];
}

/* As Workspace's launcher: a running app is asked over Distributed
   Objects to come forward; otherwise its binary is started. NSWorkspace
   would ask the workspace manager, which NextBSD's Workspace isn't. */
- (void)openApp:(NSDictionary *)app
{
  NSString *path = [[catalog installInfoForApp:app] objectForKey:@"Path"];
  NSString *binary = path != nil
    ? [[NSWorkspace sharedWorkspace] locateApplicationBinary:path] : nil;
  NSString *port = [[path lastPathComponent] stringByDeletingPathExtension];
  BOOL opened = NO;

  if (binary == nil)
    {
      NSRunAlertPanel (@"Software",
                       [NSString stringWithFormat:@"Couldn't find %@'s "
                                 @"program in %@.", [app objectForKey:@"Name"],
                                 [path stringByAbbreviatingWithTildeInPath]],
                       @"OK", nil, nil);
      return;
    }
  NS_DURING
    {
      NSConnection *connection = [NSConnection
                                   connectionWithRegisteredName:port host:@""];
      id running;

      [connection setRequestTimeout:5];
      [connection setReplyTimeout:5];
      running = [connection rootProxy];
      if (running != nil)
        {
          [running activateIgnoringOtherApps:YES];
          opened = YES;
        }
    }
  NS_HANDLER
    {
      opened = NO;
    }
  NS_ENDHANDLER
  if (opened)
    return;
  NS_DURING
    {
      NSTask *task = AUTORELEASE ([[NSTask alloc] init]);

      [task setLaunchPath:binary];
      [task setCurrentDirectoryPath:NSHomeDirectory ()];
      [task launch];
    }
  NS_HANDLER
    {
      NSRunAlertPanel (@"Software",
                       [NSString stringWithFormat:@"Couldn't open %@: %@",
                                 [app objectForKey:@"Name"],
                                 [localException reason]],
                       @"OK", nil, nil);
    }
  NS_ENDHANDLER
}

- (void)showLogFor:(NSDictionary *)app
{
  NSString *identifier = [app objectForKey:@"Identifier"];
  NSString *text = [logs objectForKey:identifier];

  if (logPanel == nil)
    {
      NSScrollView *scroll;

      logPanel = [[NSPanel alloc]
          initWithContentRect:NSMakeRect (260, 200, 680, 420)
                    styleMask:NSTitledWindowMask | NSClosableWindowMask
                              | NSResizableWindowMask
                      backing:NSBackingStoreBuffered
                        defer:YES];
      [logPanel setReleasedWhenClosed:NO];
      [logPanel setFrameAutosaveName:@"Install Log"];
      scroll = AUTORELEASE ([[NSScrollView alloc]
                              initWithFrame:[[logPanel contentView] bounds]]);
      [scroll setHasVerticalScroller:YES];
      [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
      logView = AUTORELEASE ([[NSTextView alloc]
                               initWithFrame:[[scroll contentView] bounds]]);
      [logView setEditable:NO];
      [logView setRichText:NO];
      [logView setFont:SWMonoFont (11)];
      [logView setAutoresizingMask:NSViewWidthSizable];
      [scroll setDocumentView:logView];
      [[logPanel contentView] addSubview:scroll];
    }
  ASSIGN (logShown, identifier);
  [logPanel setTitle:[NSString stringWithFormat:@"Install Log — %@",
                               [app objectForKey:@"Name"]]];
  [logView setString:text != nil ? text : @""];
  [logView setFont:SWMonoFont (11)];
  [logView scrollRangeToVisible:NSMakeRange ([[logView string] length], 0)];
  [logPanel makeKeyAndOrderFront:self];
}

@end

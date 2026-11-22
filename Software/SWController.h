/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * SWController: Software's app delegate and its window, as the mockup
 * (mockups/software.html):
 *   - the toolbar: Back and Forward, Featured, Categories, Installed,
 *     Updates, and the search field;
 *   - the source list: Store (Featured, All Apps, Categories and each
 *     category), This Computer (Installed, Updates) and Catalog
 *     (Libraries), with counts;
 *   - the content: Featured, Categories, an app list sortable by its
 *     column headings over the selected app's details and Install, the
 *     Installed and Updates views and the libraries;
 *   - Software → Preferences…: where new apps are installed by default.
 *
 * Everything shown comes from the bundled catalog (SWCatalog) and what's
 * installed; there are no ratings, download counts, sizes or made-up
 * versions. Installing builds the app from source for the user
 * (SWInstaller); This computer and Network are shown, but wait for the
 * privileged helper (nextbsd/apps-software#4). Updates aren't checked
 * yet (#6).
 *
 * Where the window is (route) is a dictionary: View (Featured,
 * Categories, List, Installed, Updates, Libraries), and for the list a
 * Category or Search and the selected App's identifier. Back and Forward
 * walk the routes visited.
 */

#import <AppKit/AppKit.h>
#import "SWCatalog.h"
#import "SWInstaller.h"

@interface SWController : NSObject <SWInstallerDelegate>
{
  SWCatalog *catalog;
  NSWindow *window;

  /* The toolbar. */
  NSButton *backButton;
  NSButton *forwardButton;
  NSDictionary *toolButtons;	/* view name -> NSButton */
  NSSearchField *searchField;

  /* The source list: SWSourceItem rows. */
  NSOutlineView *sourceList;
  NSArray *sourceItems;
  id categoriesItem;
  BOOL selectingSource;		/* selection changes are ours */

  NSView *host;			/* holds the current view */
  NSTextField *statusField;
  NSTextField *countField;
  CGFloat shownWidth;

  NSDictionary *route;
  NSMutableArray *history;
  NSInteger historyIndex;

  /* The app list. */
  NSTableView *appTable;
  NSScrollView *detailScroll;
  NSArray *listApps;
  NSString *sortKey;
  BOOL sortAscending;
  NSProgressIndicator *detailProgress;
  NSTextField *detailStep;
  NSInteger heroIndex;

  /* Installed and Libraries. */
  NSTableView *installedTable;
  NSArray *installedApps;
  NSTableView *libraryTable;

  NSMutableDictionary *installers;	/* identifier -> SWInstaller */
  NSMutableDictionary *logs;		/* identifier -> NSMutableString */
  NSMutableDictionary *locationChoices;	/* identifier -> NSNumber */

  NSPanel *prefsPanel;
  NSMatrix *prefsMatrix;
  NSPanel *logPanel;
  NSTextView *logView;
  NSString *logShown;		/* whose log the panel shows */
}
@end

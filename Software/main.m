/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Software.app: NextBSD's app store. Finds, builds and installs GNUstep
 * apps from the catalog bundled with it.
 */

#import <AppKit/AppKit.h>
#import "SWController.h"

int
main (int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  [NSApplication sharedApplication];
  SWController *controller = [[SWController alloc] init];
  [NSApp setDelegate:controller];
  [NSApp run];
  RELEASE (controller);
  RELEASE (pool);
  return 0;
}

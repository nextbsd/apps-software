/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * SWInstaller: builds one catalog app from source and installs it for the
 * user, as Gershwin's Build.app builds its catalog apps, on a thread of
 * its own:
 *   1. git clone --depth=1 (--recurse-submodules where the catalog says
 *      Submodules) into a new folder under NSTemporaryDirectory();
 *   2. each library the app requires: cloned the same way (or taken from
 *      the app's own clone when it's the same repository), built and
 *      installed into the same domain first;
 *   3. configure, where the app's folder has one and no GNUmakefile yet
 *      (or a GNUmakefile.in);
 *   4. gmake with the catalog's MakeArgs, then gmake install.
 *
 * Every make runs with GNUSTEP_INSTALLATION_DOMAIN=USER on its command
 * line, which overrides a makefile's own value (gershwin-components set
 * SYSTEM), so the app lands in ~/Applications; and with NextBSD's library
 * folders (ADDITIONAL_LIB_DIRS). Nothing runs as root and nothing is
 * written under /System. This computer and Network need the privileged
 * helper (nextbsd/apps-software#4) to copy the built app into place, so
 * only USER is offered for now.
 *
 * The tools run through GNUstep.sh, so gmake and gnustep-config are found
 * whatever the session's PATH. Progress is a share for each step, and in
 * the build step the compiled files against the sources in the folder.
 * The delegate hears everything on the main thread.
 */

#import <Foundation/Foundation.h>

@class SWInstaller;

@protocol SWInstallerDelegate
- (void)installer:(SWInstaller *)installer logged:(NSString *)text;
- (void)installerChanged:(SWInstaller *)installer;
- (void)installerFinished:(SWInstaller *)installer;
@end

@interface SWInstaller : NSObject
{
  NSDictionary *app;
  NSArray *libraries;		/* catalog library dictionaries, in order */
  id<SWInstallerDelegate> delegate;	/* not retained */
  NSString *workDir;
  NSString *logPath;
  NSFileHandle *logFile;

  /* Shared with the thread, under lock. */
  NSLock *lock;
  NSTask *task;
  BOOL cancelled;
  double progress;
  NSString *step;

  BOOL trackCompiles;		/* the app's own build: count its files */
  BOOL running;
  BOOL succeeded;
  NSString *result;		/* the last line shown when it's done */
  NSString *installedPath;
}

- (id)initWithApp:(NSDictionary *)app
        libraries:(NSArray *)libraries
         delegate:(id<SWInstallerDelegate>)delegate;

- (void)start;
- (void)cancel;

- (NSDictionary *)app;
- (BOOL)isRunning;
- (BOOL)succeeded;
- (double)progress;		/* 0 to 1 */
- (NSString *)step;		/* "Building GMines…" */
- (NSString *)result;
- (NSString *)logPath;		/* ~/Library/Logs/Software/<Identifier>.log */
- (NSString *)installedPath;

@end

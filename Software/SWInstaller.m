/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "SWInstaller.h"
#import <GNUstepBase/GNUstep.h>

#include <stdlib.h>
#include <string.h>

/* The domain Software builds for until the helper can copy into
   /Local/Applications and /Network/Applications. */
#define SWDomainArgument @"GNUSTEP_INSTALLATION_DOMAIN=USER"

/* Where NextBSD keeps the libraries apps link besides GNUstep's own
   (libBlocksRuntime and friends, and X11's). In the environment, not on
   the command line, so a makefile's own += still adds to it. */
#define SWLibraryDirs @"-L/Developer/Link -L/usr/X11/lib"

/* Each step's share of the progress bar. */
#define SWCloneDone 0.08
#define SWLibrariesDone 0.30
#define SWBuildDone 0.92

static NSString *
SWGNUstepScript (void)
{
  NSString *makefiles = [[[NSProcessInfo processInfo] environment]
                          objectForKey:@"GNUSTEP_MAKEFILES"];

  if ([makefiles length] == 0)
    makefiles = @"/System/Library/Makefiles";
  return [makefiles stringByAppendingPathComponent:@"GNUstep.sh"];
}

@interface SWInstaller (Thread)
- (void)run:(id)unused;
- (BOOL)work;
- (void)setStep:(NSString *)text progress:(double)value;
- (void)setProgress:(double)value;
- (void)log:(NSString *)text;
- (int)runTool:(NSArray *)arguments inDirectory:(NSString *)directory;
- (BOOL)clone:(NSDictionary *)entry into:(NSString *)directory;
- (BOOL)make:(NSArray *)targets
          in:(NSString *)directory
       entry:(NSDictionary *)entry;
- (BOOL)configureIfNeeded:(NSString *)directory;
- (NSUInteger)countSourcesIn:(NSString *)directory;
- (void)fail:(NSString *)reason;
- (void)mainLogged:(NSString *)text;
- (void)mainChanged:(id)unused;
- (void)mainFinished:(id)unused;
@end

@implementation SWInstaller

- (id)initWithApp:(NSDictionary *)anApp
        libraries:(NSArray *)theLibraries
         delegate:(id<SWInstallerDelegate>)aDelegate
{
  if ((self = [super init]) != nil)
    {
      app = RETAIN (anApp);
      libraries = RETAIN (theLibraries);
      delegate = aDelegate;
      lock = [[NSLock alloc] init];
      step = @"";
      result = @"";
    }
  return self;
}

- (void)dealloc
{
  RELEASE (app);
  RELEASE (libraries);
  RELEASE (workDir);
  RELEASE (logPath);
  RELEASE (logFile);
  RELEASE (lock);
  RELEASE (task);
  RELEASE (step);
  RELEASE (result);
  RELEASE (installedPath);
  [super dealloc];
}

- (void)start
{
  NSString *logs = [[NSHomeDirectory ()
                      stringByAppendingPathComponent:@"Library/Logs"]
                     stringByAppendingPathComponent:@"Software"];

  if (running)
    return;
  running = YES;
  succeeded = NO;
  cancelled = NO;
  [[NSFileManager defaultManager] createDirectoryAtPath:logs
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
  ASSIGN (logPath, [logs stringByAppendingPathComponent:
                           [[app objectForKey:@"Identifier"]
                             stringByAppendingPathExtension:@"log"]]);
  [[NSFileManager defaultManager] createFileAtPath:logPath
                                          contents:[NSData data]
                                        attributes:nil];
  ASSIGN (logFile, [NSFileHandle fileHandleForWritingAtPath:logPath]);
  [self setStep:[NSString stringWithFormat:@"Preparing to build %@…",
                          [app objectForKey:@"Name"]]
       progress:0.0];
  /* The thread retains self until it's done. */
  [NSThread detachNewThreadSelector:@selector (run:) toTarget:self
                         withObject:nil];
}

- (void)cancel
{
  [lock lock];
  cancelled = YES;
  if (task != nil && [task isRunning])
    [task terminate];
  [lock unlock];
}

- (NSDictionary *)app
{
  return app;
}

- (BOOL)isRunning
{
  return running;
}

- (BOOL)succeeded
{
  return succeeded;
}

- (double)progress
{
  double value;

  [lock lock];
  value = progress;
  [lock unlock];
  return value;
}

- (NSString *)step
{
  NSString *value;

  [lock lock];
  value = AUTORELEASE (RETAIN (step));
  [lock unlock];
  return value;
}

- (NSString *)result
{
  return result;
}

- (NSString *)logPath
{
  return logPath;
}

- (NSString *)installedPath
{
  return installedPath;
}

@end

@implementation SWInstaller (Thread)

- (void)run:(id)unused
{
  CREATE_AUTORELEASE_POOL (pool);
  BOOL ok;

  RETAIN (self);
  ok = [self work];
  [lock lock];
  if (cancelled)
    ok = NO;
  [lock unlock];
  succeeded = ok;
  /* A failed build's folder stays for a look; the log says where. */
  if (ok && workDir != nil)
    [[NSFileManager defaultManager] removeItemAtPath:workDir error:NULL];
  [self performSelectorOnMainThread:@selector (mainFinished:)
                         withObject:nil
                      waitUntilDone:NO];
  RELEASE (pool);
  RELEASE (self);
}

- (BOOL)work
{
  NSString *name = [app objectForKey:@"Name"];
  NSString *appName = [app objectForKey:@"AppName"];
  NSString *home = NSHomeDirectory ();
  NSString *source, *directory, *makefile, *product;
  char *path;
  NSUInteger i;

  /* USER puts it in the home folder; never let that be /System. */
  if ([home length] < 2 || [home hasPrefix:@"/System"])
    {
      [self fail:[NSString stringWithFormat:
                             @"Won't install into %@: it isn't a home folder "
                           @"Software may write to.", home]];
      return NO;
    }

  path = strdup ([[NSTemporaryDirectory ()
                    stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"Software-%@-XXXXXX",
                                [app objectForKey:@"Identifier"]]]
                   fileSystemRepresentation]);
  if (path == NULL || mkdtemp (path) == NULL)
    {
      free (path);
      [self fail:@"Couldn't make a folder to build in."];
      return NO;
    }
  ASSIGN (workDir, [[NSFileManager defaultManager]
                     stringWithFileSystemRepresentation:path
                                                 length:strlen (path)]);
  free (path);
  [self log:[NSString stringWithFormat:@"Building %@ (%@) in %@\n", name,
                      [app objectForKey:@"GitURL"], workDir]];

  [self setStep:[NSString stringWithFormat:@"Downloading %@…", name]
       progress:0.02];
  source = [workDir stringByAppendingPathComponent:@"source"];
  if (![self clone:app into:source])
    {
      [self fail:[NSString stringWithFormat:
                             @"Couldn't download %@ from %@.", name,
                           [app objectForKey:@"Repository"]]];
      return NO;
    }
  [self setProgress:SWCloneDone];

  for (i = 0; i < [libraries count]; i++)
    {
      NSDictionary *library = [libraries objectAtIndex:i];
      NSString *libName = [library objectForKey:@"Name"];
      NSString *libDir;
      double share = (SWLibrariesDone - SWCloneDone) / [libraries count];

      [self setStep:[NSString stringWithFormat:@"Building %@, which %@ needs…",
                              libName, name]
           progress:SWCloneDone + share * i];
      if ([[library objectForKey:@"GitURL"]
            isEqual:[app objectForKey:@"GitURL"]])
        libDir = source;
      else
        {
          libDir = [workDir stringByAppendingPathComponent:
                              [library objectForKey:@"Identifier"]];
          if (![self clone:library into:libDir])
            {
              [self fail:[NSString stringWithFormat:
                                     @"Couldn't download %@, which %@ needs.",
                                   libName, name]];
              return NO;
            }
        }
      if (![self configureIfNeeded:libDir]
          || ![self make:[NSArray arrayWithObject:@"all"] in:libDir
                   entry:library]
          || ![self make:[NSArray arrayWithObject:@"install"] in:libDir
                   entry:library])
        {
          [self fail:[NSString stringWithFormat:
                                 @"Couldn't build %@, which %@ needs. "
                               @"The log has the details.", libName, name]];
          return NO;
        }
    }

  directory = source;
  makefile = [app objectForKey:@"MakefilePath"];
  if ([makefile length] > 0)
    directory = [source stringByAppendingPathComponent:
                          [makefile stringByDeletingLastPathComponent]];
  if (![self configureIfNeeded:directory])
    {
      [self fail:[NSString stringWithFormat:
                             @"%@'s configure script failed. The log has "
                           @"the details.", name]];
      return NO;
    }

  [self setStep:[NSString stringWithFormat:@"Building %@…", name]
       progress:([libraries count] > 0 ? SWLibrariesDone : SWCloneDone)];
  trackCompiles = YES;
  if (![self make:[NSArray arrayWithObject:@"all"] in:directory entry:app])
    {
      [self fail:[NSString stringWithFormat:
                             @"%@ didn't build. The log has the details.",
                           name]];
      return NO;
    }

  trackCompiles = NO;
  [self setStep:[NSString stringWithFormat:@"Installing %@…", name]
       progress:SWBuildDone];
  if (![self make:[NSArray arrayWithObject:@"install"] in:directory
            entry:app])
    {
      [self fail:[NSString stringWithFormat:
                             @"%@ built, but didn't install. The log has "
                           @"the details.", name]];
      return NO;
    }

  product = [[home stringByAppendingPathComponent:@"Applications"]
              stringByAppendingPathComponent:
                [appName stringByAppendingPathExtension:@"app"]];
  if (![[NSFileManager defaultManager] fileExistsAtPath:product])
    {
      [self fail:[NSString stringWithFormat:
                             @"%@ installed, but there's no %@.app in "
                           @"~/Applications. The log says where it went.",
                           name, appName]];
      return NO;
    }
  ASSIGN (installedPath, product);
  ASSIGN (result, ([NSString stringWithFormat:@"Installed in %@.",
                             [product stringByAbbreviatingWithTildeInPath]]));
  [self log:[NSString stringWithFormat:@"\n%@\n", result]];
  [self setStep:result progress:1.0];
  return YES;
}

- (void)setStep:(NSString *)text progress:(double)value
{
  [lock lock];
  ASSIGN (step, text);
  progress = value;
  [lock unlock];
  [self performSelectorOnMainThread:@selector (mainChanged:)
                         withObject:nil
                      waitUntilDone:NO];
}

- (void)setProgress:(double)value
{
  [lock lock];
  progress = value;
  [lock unlock];
  [self performSelectorOnMainThread:@selector (mainChanged:)
                         withObject:nil
                      waitUntilDone:NO];
}

- (void)log:(NSString *)text
{
  NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding
                    allowLossyConversion:YES];

  [logFile writeData:data];
  [self performSelectorOnMainThread:@selector (mainLogged:)
                         withObject:text
                      waitUntilDone:NO];
}

/* Runs a tool with GNUstep.sh's environment, logging what it prints. In
   the build step, each "Compiling file" moves the bar on. Returns its
   exit status, or -1 when it couldn't start or was cancelled. */
- (int)runTool:(NSArray *)arguments inDirectory:(NSString *)directory
{
  NSTask *t;
  NSPipe *pipe = [NSPipe pipe];
  NSMutableArray *argv = [NSMutableArray arrayWithObjects:
                                           @"-c",
                                         @". \"$0\" >/dev/null 2>&1; exec \"$@\"",
                                         SWGNUstepScript (), nil];
  NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:
                                [[NSProcessInfo processInfo] environment]];
  NSFileHandle *output;
  NSMutableData *pending = [NSMutableData data];
  NSData *data;
  BOOL building = trackCompiles && [arguments containsObject:@"all"];
  NSUInteger sources = building ? [self countSourcesIn:directory] : 0;
  NSUInteger compiled = 0;
  double base = [self progress];
  double span = SWBuildDone - base;
  int status;

  [argv addObjectsFromArray:arguments];
  [env setObject:@"0" forKey:@"GIT_TERMINAL_PROMPT"];
  [env setObject:SWLibraryDirs forKey:@"ADDITIONAL_LIB_DIRS"];
  t = AUTORELEASE ([[NSTask alloc] init]);
  [t setLaunchPath:@"/bin/sh"];
  [t setArguments:argv];
  [t setCurrentDirectoryPath:directory];
  [t setEnvironment:env];
  [t setStandardOutput:pipe];
  [t setStandardError:pipe];
  [t setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
  [self log:[NSString stringWithFormat:@"\n$ cd %@\n$ %@\n", directory,
                      [arguments componentsJoinedByString:@" "]]];

  [lock lock];
  if (cancelled)
    {
      [lock unlock];
      return -1;
    }
  ASSIGN (task, t);
  [lock unlock];
  NS_DURING
    [t launch];
  NS_HANDLER
    {
      [self log:[NSString stringWithFormat:@"Couldn't run it: %@\n",
                          [localException reason]]];
      [lock lock];
      DESTROY (task);
      [lock unlock];
      return -1;
    }
  NS_ENDHANDLER

  output = [pipe fileHandleForReading];
  while ((data = [output availableData]) != nil && [data length] > 0)
    {
      const char *bytes;
      NSUInteger length, start = 0, i;

      [pending appendData:data];
      bytes = [pending bytes];
      length = [pending length];
      for (i = 0; i < length; i++)
        {
          NSString *line;

          if (bytes[i] != '\n')
            continue;
          line = AUTORELEASE ([[NSString alloc]
                                initWithBytes:bytes + start
                                       length:i + 1 - start
                                     encoding:NSUTF8StringEncoding]);
          if (line == nil)
            line = AUTORELEASE ([[NSString alloc]
                                  initWithBytes:bytes + start
                                         length:i + 1 - start
                                       encoding:NSISOLatin1StringEncoding]);
          [self log:line];
          if (building && sources > 0
              && [line rangeOfString:@"Compiling file"].location != NSNotFound)
            {
              compiled++;
              [self setProgress:base + span * MIN (1.0, (double) compiled
                                                   / (double) sources)];
            }
          start = i + 1;
        }
      [pending replaceBytesInRange:NSMakeRange (0, start) withBytes:NULL
                            length:0];
    }
  if ([pending length] > 0)
    [self log:AUTORELEASE ([[NSString alloc]
                             initWithData:pending
                                 encoding:NSISOLatin1StringEncoding])];
  [t waitUntilExit];
  status = [t terminationStatus];
  [lock lock];
  DESTROY (task);
  if (cancelled)
    status = -1;
  [lock unlock];
  if (status != 0)
    [self log:[NSString stringWithFormat:@"(exit status %d)\n", status]];
  return status;
}

- (BOOL)clone:(NSDictionary *)entry into:(NSString *)directory
{
  NSMutableArray *args = [NSMutableArray arrayWithObjects:
                                           @"git", @"clone", @"--depth=1",
                                         nil];

  if ([[entry objectForKey:@"Submodules"] boolValue])
    [args addObject:@"--recurse-submodules"];
  [args addObject:[entry objectForKey:@"GitURL"]];
  [args addObject:directory];
  return [self runTool:args inDirectory:workDir] == 0;
}

- (BOOL)make:(NSArray *)targets
          in:(NSString *)directory
       entry:(NSDictionary *)entry
{
  NSMutableArray *args = [NSMutableArray arrayWithObject:@"gmake"];
  NSArray *extra = [entry objectForKey:@"MakeArgs"];

  if ([extra isKindOfClass:[NSArray class]])
    [args addObjectsFromArray:extra];
  [args addObject:SWDomainArgument];
  [args addObjectsFromArray:targets];
  return [self runTool:args inDirectory:directory] == 0;
}

/* As Build.app: configure when there's a GNUmakefile.in, or a configure
   script and no GNUmakefile yet. */
- (BOOL)configureIfNeeded:(NSString *)directory
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *configure = [directory stringByAppendingPathComponent:@"configure"];

  if (![fm fileExistsAtPath:configure])
    return YES;
  if (![fm fileExistsAtPath:[directory stringByAppendingPathComponent:
                                         @"GNUmakefile.in"]]
      && [fm fileExistsAtPath:[directory stringByAppendingPathComponent:
                                           @"GNUmakefile"]])
    return YES;
  return [self runTool:[NSArray arrayWithObjects:@"/bin/sh", @"./configure",
                                nil]
           inDirectory:directory] == 0;
}

- (NSUInteger)countSourcesIn:(NSString *)directory
{
  NSDirectoryEnumerator *e = [[NSFileManager defaultManager]
                               enumeratorAtPath:directory];
  NSSet *kinds = [NSSet setWithObjects:@"m", @"c", @"mm", @"cc", @"cpp", nil];
  NSString *file;
  NSUInteger count = 0;

  while ((file = [e nextObject]) != nil)
    {
      if ([[file lastPathComponent] isEqual:@".git"])
        [e skipDescendents];
      else if ([kinds containsObject:[file pathExtension]])
        count++;
    }
  return count;
}

- (void)fail:(NSString *)reason
{
  BOOL wasCancelled;

  [lock lock];
  wasCancelled = cancelled;
  [lock unlock];
  if (wasCancelled)
    reason = @"Cancelled.";
  ASSIGN (result, reason);
  [self log:[NSString stringWithFormat:@"\n%@\n", reason]];
  if (workDir != nil && !wasCancelled)
    [self log:[NSString stringWithFormat:@"The build folder is kept at %@.\n",
                        workDir]];
  [self setStep:reason progress:[self progress]];
}

- (void)mainLogged:(NSString *)text
{
  [delegate installer:self logged:text];
}

- (void)mainChanged:(id)unused
{
  [delegate installerChanged:self];
}

- (void)mainFinished:(id)unused
{
  running = NO;
  [logFile closeFile];
  DESTROY (logFile);
  [delegate installerFinished:self];
}

@end

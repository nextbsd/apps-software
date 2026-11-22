/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * The pieces Software's window is made of, as the mockup
 * (mockups/software.html) draws them in the NextBSD theme: bevelled
 * panels, boxes with a heading strip, app and category cards, the source
 * list's rows and the small glyphs in the toolbar and source list. Colours
 * come from the theme's system colours, so another theme gets its own.
 */

#import <AppKit/AppKit.h>

/* Colours, from the theme. */
NSColor *SWTextColor (void);
NSColor *SWSecondaryTextColor (void);	/* the mockup's --text-2 */
NSColor *SWLineColor (void);		/* --raised: a thin rule */
NSColor *SWPanelColor (void);		/* --control: a panel's face */
NSColor *SWBackgroundColor (void);	/* --plane */
NSColor *SWInstalledColor (void);	/* "✓ Installed" */
NSColor *SWWarningColor (void);

NSFont *SWFont (CGFloat size);
NSFont *SWBoldFont (CGFloat size);
NSFont *SWSmallFont (void);
NSFont *SWMonoFont (CGFloat size);

/* A label: not editable, no border, no background. */
NSTextField *SWLabel (NSRect frame, NSString *text, NSFont *font,
                      NSColor *color);
/* A label that wraps; its frame grows to fit the text at its width. */
NSTextField *SWWrappingLabel (NSRect frame, NSString *text, NSFont *font,
                              NSColor *color);
/* A push button; the default one shows the theme's default ring. */
NSButton *SWButton (NSRect frame, NSString *title, id target, SEL action);

/* The toolbar's and source list's glyphs, drawn in the text colour:
   "star", "grid", "all", "disk", "update", "books", "back", "forward",
   "search". */
NSImage *SWGlyph (NSString *name, CGFloat size, NSColor *color);
/* A category's tile: a rounded square in its colour with its initial. */
NSImage *SWCategoryIcon (NSString *category, CGFloat size);

/* Laid out from the top down. */
@interface SWFlippedView : NSView
@end

/* A raised (or sunken) panel with bevelled edges, as the mockup's .bevel
   and .sunken. */
@interface SWBevelView : SWFlippedView
{
  BOOL sunken;
  NSColor *face;
}
- (void)setSunken:(BOOL)flag;
- (void)setFaceColor:(NSColor *)color;
@end

/* A box with a heading strip: "NEW & NOTEWORTHY". Its content goes below
   SWBoxHeading points. */
#define SWBoxHeading 26.0
@interface SWBoxView : SWFlippedView
{
  NSString *title;
}
- (id)initWithFrame:(NSRect)frame title:(NSString *)title;
@end

typedef enum
{
  SWCardApp,			/* icon above, name, category line */
  SWCardCategory		/* tile at the left, name, "12 apps" */
} SWCardStyle;

/* A clickable card for an app or a category. Sends its action with
   itself as the sender; -representedObject says which. */
@interface SWCardView : NSControl
{
  SWCardStyle style;
  NSImage *image;
  NSString *title;
  NSString *subtitle;
  NSString *note;
  id representedObject;
  id cardTarget;
  SEL cardAction;
  BOOL pressed;
}
- (id)initWithFrame:(NSRect)frame style:(SWCardStyle)style;
- (void)setImage:(NSImage *)image;
- (void)setTitle:(NSString *)title;
- (void)setSubtitle:(NSString *)subtitle;
- (void)setNote:(NSString *)note;
- (void)setRepresentedObject:(id)object;
- (id)representedObject;
@end

/* A source list row: an icon, the label, and a count at the right; or a
   section heading in small capitals. */
@interface SWSourceCell : NSTextFieldCell
{
  NSImage *icon;
  NSString *badge;
  BOOL heading;
}
- (void)setIcon:(NSImage *)icon;
- (void)setBadge:(NSString *)badge;
- (void)setHeading:(BOOL)flag;
@end

/* A table cell with a small icon before its text. */
@interface SWIconTextCell : NSTextFieldCell
{
  NSImage *icon;
}
- (void)setIcon:(NSImage *)icon;
@end

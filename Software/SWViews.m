/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "SWViews.h"
#import <GNUstepBase/GNUstep.h>

/* ---- colours and fonts ---- */

NSColor *
SWTextColor (void)
{
  return [NSColor controlTextColor];
}

NSColor *
SWSecondaryTextColor (void)
{
  return [[NSColor controlTextColor]
           blendedColorWithFraction:0.32
                            ofColor:[NSColor windowBackgroundColor]];
}

NSColor *
SWLineColor (void)
{
  return [[NSColor windowBackgroundColor]
           blendedColorWithFraction:0.14
                            ofColor:[NSColor controlTextColor]];
}

NSColor *
SWPanelColor (void)
{
  return [[NSColor windowBackgroundColor]
           blendedColorWithFraction:0.07
                            ofColor:[NSColor controlTextColor]];
}

NSColor *
SWBackgroundColor (void)
{
  return [NSColor windowBackgroundColor];
}

/* The mockup's --ok and the warning orange; the theme has neither. */
NSColor *
SWInstalledColor (void)
{
  return [NSColor colorWithCalibratedRed:0.435 green:0.827 blue:0.541
                                   alpha:1.0];
}

NSColor *
SWWarningColor (void)
{
  return [NSColor colorWithCalibratedRed:1.0 green:0.706 blue:0.329
                                   alpha:1.0];
}

NSFont *
SWFont (CGFloat size)
{
  return [NSFont systemFontOfSize:size];
}

NSFont *
SWBoldFont (CGFloat size)
{
  return [NSFont boldSystemFontOfSize:size];
}

NSFont *
SWSmallFont (void)
{
  return [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
}

NSFont *
SWMonoFont (CGFloat size)
{
  return [NSFont userFixedPitchFontOfSize:size];
}

NSTextField *
SWLabel (NSRect frame, NSString *text, NSFont *font, NSColor *color)
{
  NSTextField *label = AUTORELEASE ([[NSTextField alloc] initWithFrame:frame]);

  [label setStringValue:(text != nil ? text : @"")];
  [label setEditable:NO];
  [label setSelectable:NO];
  [label setBordered:NO];
  [label setBezeled:NO];
  [label setDrawsBackground:NO];
  [[label cell] setLineBreakMode:NSLineBreakByTruncatingTail];
  if (font != nil)
    [label setFont:font];
  if (color != nil)
    [label setTextColor:color];
  return label;
}

/* How many lines text takes at width, broken between words. The cell's
   own -cellSizeForBounds: doesn't wrap. */
static NSUInteger
SWLineCount (NSString *text, NSFont *font, CGFloat width)
{
  NSDictionary *attrs = [NSDictionary dictionaryWithObject:font
                                                    forKey:NSFontAttributeName];
  NSArray *paragraphs = [text componentsSeparatedByString:@"\n"];
  CGFloat space = [@" " sizeWithAttributes:attrs].width;
  NSUInteger lines = 0, p, w;

  for (p = 0; p < [paragraphs count]; p++)
    {
      NSArray *words = [[paragraphs objectAtIndex:p]
                         componentsSeparatedByString:@" "];
      CGFloat x = 0;

      lines++;
      for (w = 0; w < [words count]; w++)
        {
          CGFloat ww = [[words objectAtIndex:w] sizeWithAttributes:attrs].width;

          if (x > 0 && x + space + ww > width)
            {
              lines++;
              x = ww;
            }
          else
            x += (x > 0 ? space : 0) + ww;
        }
    }
  return MAX (lines, 1);
}

NSTextField *
SWWrappingLabel (NSRect frame, NSString *text, NSFont *font, NSColor *color)
{
  NSTextField *label = SWLabel (frame, text, font, color);
  NSFont *f = [label font];
  NSUInteger lines;

  [[label cell] setWraps:YES];
  [[label cell] setLineBreakMode:NSLineBreakByWordWrapping];
  /* The cell keeps a couple of points each side. */
  lines = SWLineCount (text != nil ? text : @"", f, NSWidth (frame) - 6);
  frame.size.height = MAX (NSHeight (frame),
                           ceil (lines * ([f defaultLineHeightForFont] + 1))
                           + 4);
  [label setFrame:frame];
  return label;
}

NSButton *
SWButton (NSRect frame, NSString *title, id target, SEL action)
{
  NSButton *button = AUTORELEASE ([[NSButton alloc] initWithFrame:frame]);

  [button setTitle:title];
  [button setButtonType:NSMomentaryPushInButton];
  [button setBezelStyle:NSRoundedBezelStyle];
  [button setTarget:target];
  [button setAction:action];
  return button;
}

/* ---- glyphs ---- */

/* The mockup's glyphs are SVG paths on a 24-unit grid, y down; these
   draw the same shapes in that grid. */
static void
SWMoveLine (NSBezierPath *path, const CGFloat *points, int count, BOOL close)
{
  int i;

  [path moveToPoint:NSMakePoint (points[0], points[1])];
  for (i = 1; i < count; i++)
    [path lineToPoint:NSMakePoint (points[2 * i], points[2 * i + 1])];
  if (close)
    [path closePath];
}

static void
SWDrawGlyph (NSString *name)
{
  NSBezierPath *stroke = [NSBezierPath bezierPath];
  NSBezierPath *fill = [NSBezierPath bezierPath];

  if ([name isEqual:@"star"])
    {
      static const CGFloat p[] = {12, 3.2, 14.7, 8.8, 20.8, 9.6, 16.3, 13.8,
                                  17.4, 19.8, 12, 16.8, 6.6, 19.8, 7.7, 13.8,
                                  3.2, 9.6, 9.3, 8.8};
      SWMoveLine (stroke, p, 10, YES);
    }
  else if ([name isEqual:@"grid"])
    {
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (4, 4, 6.5, 6.5)
                                      xRadius:1.2 yRadius:1.2];
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (13.5, 4, 6.5, 6.5)
                                      xRadius:1.2 yRadius:1.2];
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (4, 13.5, 6.5, 6.5)
                                      xRadius:1.2 yRadius:1.2];
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (13.5, 13.5, 6.5, 6.5)
                                      xRadius:1.2 yRadius:1.2];
    }
  else if ([name isEqual:@"all"])
    {
      [stroke appendBezierPathWithOvalInRect:NSMakeRect (4.6, 4.6, 4.8, 4.8)];
      [stroke appendBezierPathWithOvalInRect:NSMakeRect (14.6, 4.6, 4.8, 4.8)];
      [stroke appendBezierPathWithOvalInRect:NSMakeRect (4.6, 14.6, 4.8, 4.8)];
      [stroke appendBezierPathWithOvalInRect:NSMakeRect (14.6, 14.6, 4.8, 4.8)];
    }
  else if ([name isEqual:@"disk"])
    {
      static const CGFloat p[] = {6.5, 13.5, 12.5, 13.5};
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (3.5, 7, 17, 10)
                                      xRadius:2 yRadius:2];
      SWMoveLine (stroke, p, 2, NO);
      [fill appendBezierPathWithOvalInRect:NSMakeRect (15.9, 12.4, 2.2, 2.2)];
    }
  else if ([name isEqual:@"update"])
    {
      static const CGFloat p[] = {17.5, 3.5, 17.5, 7.5, 13.5, 7.5};
      [stroke appendBezierPathWithArcWithCenter:NSMakePoint (12, 12)
                                         radius:7
                                     startAngle:0
                                       endAngle:315
                                      clockwise:NO];
      SWMoveLine (stroke, p, 3, NO);
    }
  else if ([name isEqual:@"books"])
    {
      static const CGFloat p[] = {15.5, 6.2, 19.1, 5.2, 22.1, 18.4, 18.5, 19.4};
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (4, 5, 4, 14)
                                      xRadius:1 yRadius:1];
      [stroke appendBezierPathWithRoundedRect:NSMakeRect (9.5, 5, 4, 14)
                                      xRadius:1 yRadius:1];
      SWMoveLine (stroke, p, 4, YES);
    }
  else if ([name isEqual:@"back"])
    {
      static const CGFloat p[] = {17, 3, 17, 21, 5, 12};
      SWMoveLine (fill, p, 3, YES);
    }
  else if ([name isEqual:@"forward"])
    {
      static const CGFloat p[] = {7, 3, 7, 21, 19, 12};
      SWMoveLine (fill, p, 3, YES);
    }
  else if ([name isEqual:@"search"])
    {
      static const CGFloat p[] = {15.2, 15.2, 21.2, 21.2};
      [stroke appendBezierPathWithOvalInRect:NSMakeRect (2.8, 2.8, 14.4, 14.4)];
      SWMoveLine (stroke, p, 2, NO);
    }
  [stroke setLineWidth:1.8];
  [stroke setLineCapStyle:NSRoundLineCapStyle];
  [stroke setLineJoinStyle:NSRoundLineJoinStyle];
  [stroke stroke];
  [fill fill];
}

NSImage *
SWGlyph (NSString *name, CGFloat size, NSColor *color)
{
  static NSMutableDictionary *cache = nil;
  NSString *key;
  NSImage *image;
  NSAffineTransform *t;

  if (color == nil)
    color = SWTextColor ();
  key = [NSString stringWithFormat:@"%@-%g-%@", name, size, color];
  if (cache == nil)
    cache = [[NSMutableDictionary alloc] init];
  if ((image = [cache objectForKey:key]) != nil)
    return image;
  image = AUTORELEASE ([[NSImage alloc] initWithSize:NSMakeSize (size, size)]);
  [image lockFocus];
  t = [NSAffineTransform transform];
  [t translateXBy:0 yBy:size];
  [t scaleXBy:size / 24.0 yBy:-size / 24.0];
  [t concat];
  [color set];
  SWDrawGlyph (name);
  [image unlockFocus];
  [cache setObject:image forKey:key];
  return image;
}

static NSColor *
SWHSL (CGFloat h, CGFloat s, CGFloat l)
{
  CGFloat c = (1 - fabs (2 * l - 1)) * s;
  CGFloat x = c * (1 - fabs (fmod (h / 60.0, 2) - 1));
  CGFloat m = l - c / 2, r = 0, g = 0, b = 0;

  if (h < 60) { r = c; g = x; }
  else if (h < 120) { r = x; g = c; }
  else if (h < 180) { g = c; b = x; }
  else if (h < 240) { g = x; b = c; }
  else if (h < 300) { r = x; b = c; }
  else { r = c; b = x; }
  return [NSColor colorWithCalibratedRed:r + m green:g + m blue:b + m
                                   alpha:1.0];
}

NSImage *
SWCategoryIcon (NSString *category, CGFloat size)
{
  /* The mockup's hue and saturation for each category. */
  static NSDictionary *hues = nil;
  static NSMutableDictionary *cache = nil;
  NSString *key = [NSString stringWithFormat:@"%@-%g", category, size];
  NSImage *image;
  NSArray *hs;
  NSBezierPath *tile;
  NSString *initial;
  NSDictionary *attrs;
  NSSize textSize;
  CGFloat h = 220, s = 0.2, inset = MAX (1, size / 32);

  if (hues == nil)
    {
      hues = [[NSDictionary alloc] initWithObjectsAndKeys:
                @"356 42", @"Games", @"32 48", @"Productivity",
                @"285 30", @"Graphics", @"200 45", @"Internet",
                @"325 34", @"Music & Video", @"130 30", @"Education",
                @"170 34", @"Science", @"214 26", @"Utilities",
                @"24 28", @"Developer Tools", @"230 8", @"System", nil];
      cache = [[NSMutableDictionary alloc] init];
    }
  if ((image = [cache objectForKey:key]) != nil)
    return image;
  hs = [[hues objectForKey:category] componentsSeparatedByString:@" "];
  if ([hs count] == 2)
    {
      h = [[hs objectAtIndex:0] doubleValue];
      s = [[hs objectAtIndex:1] doubleValue] / 100.0;
    }
  image = AUTORELEASE ([[NSImage alloc] initWithSize:NSMakeSize (size, size)]);
  [image lockFocus];
  tile = [NSBezierPath bezierPathWithRoundedRect:
                         NSMakeRect (inset, inset, size - 2 * inset,
                                     size - 2 * inset)
                                         xRadius:size * 0.2
                                         yRadius:size * 0.2];
  [SWHSL (h, s, 0.30) set];
  [tile fill];
  [SWHSL (h, s, 0.42) set];
  [tile setLineWidth:MAX (1, size / 40)];
  [tile stroke];
  initial = [[category substringToIndex:1] uppercaseString];
  attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                          SWBoldFont (size * 0.5), NSFontAttributeName,
                        [NSColor colorWithCalibratedWhite:0.96 alpha:1.0],
                        NSForegroundColorAttributeName, nil];
  textSize = [initial sizeWithAttributes:attrs];
  [initial drawAtPoint:NSMakePoint ((size - textSize.width) / 2,
                                    (size - textSize.height) / 2)
        withAttributes:attrs];
  [image unlockFocus];
  [cache setObject:image forKey:key];
  return image;
}

static void
SWDrawText (NSString *text, NSRect rect, NSFont *font, NSColor *color,
            NSTextAlignment alignment)
{
  NSMutableParagraphStyle *style;

  if ([text length] == 0)
    return;
  style = AUTORELEASE ([[NSParagraphStyle defaultParagraphStyle] mutableCopy]);
  [style setAlignment:alignment];
  [style setLineBreakMode:NSLineBreakByTruncatingTail];
  [text drawInRect:rect
    withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                   font, NSFontAttributeName,
                                 color, NSForegroundColorAttributeName,
                                 style, NSParagraphStyleAttributeName, nil]];
}

static void
SWDrawImage (NSImage *image, NSRect rect)
{
  [image drawInRect:rect
           fromRect:NSZeroRect
          operation:NSCompositeSourceOver
           fraction:1.0
     respectFlipped:YES
              hints:nil];
}

/* The edges of a raised panel: light at the top and left, dark at the
   bottom and right; the other way round for a sunken one. */
static void
SWDrawBevel (NSRect r, BOOL sunken, NSColor *face)
{
  NSColor *light = [face blendedColorWithFraction:0.22
                                          ofColor:[NSColor whiteColor]];
  NSColor *dark = [NSColor colorWithCalibratedWhite:0.04 alpha:1.0];
  NSColor *topLeft = sunken ? dark : light;
  NSColor *bottomRight = sunken ? light : dark;

  [topLeft set];
  NSRectFill (NSMakeRect (NSMinX (r), NSMinY (r), NSWidth (r), 1));
  NSRectFill (NSMakeRect (NSMinX (r), NSMinY (r), 1, NSHeight (r)));
  [bottomRight set];
  NSRectFill (NSMakeRect (NSMinX (r), NSMaxY (r) - 1, NSWidth (r), 1));
  NSRectFill (NSMakeRect (NSMaxX (r) - 1, NSMinY (r), 1, NSHeight (r)));
}

/* ---- views ---- */

@implementation SWFlippedView
- (BOOL)isFlipped
{
  return YES;
}
@end

@implementation SWBevelView

- (void)dealloc
{
  RELEASE (face);
  [super dealloc];
}

- (void)setSunken:(BOOL)flag
{
  sunken = flag;
  [self setNeedsDisplay:YES];
}

- (void)setFaceColor:(NSColor *)color
{
  ASSIGN (face, color);
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  NSColor *color = face != nil ? face : SWPanelColor ();

  [color set];
  NSRectFill ([self bounds]);
  SWDrawBevel ([self bounds], sunken, color);
}

@end

@implementation SWBoxView

- (id)initWithFrame:(NSRect)frame title:(NSString *)aTitle
{
  if ((self = [super initWithFrame:frame]) != nil)
    title = [[aTitle uppercaseString] copy];
  return self;
}

- (void)dealloc
{
  RELEASE (title);
  [super dealloc];
}

- (void)drawRect:(NSRect)rect
{
  NSRect b = [self bounds];

  [SWBackgroundColor () set];
  NSRectFill (b);
  [SWPanelColor () set];
  NSRectFill (NSMakeRect (0, 0, NSWidth (b), SWBoxHeading));
  [SWLineColor () set];
  NSFrameRect (b);
  NSRectFill (NSMakeRect (0, SWBoxHeading - 1, NSWidth (b), 1));
  SWDrawText (title, NSMakeRect (12, 7, NSWidth (b) - 140, 14),
              SWBoldFont (10), SWSecondaryTextColor (), NSLeftTextAlignment);
}

@end

@implementation SWCardView

- (id)initWithFrame:(NSRect)frame style:(SWCardStyle)aStyle
{
  if ((self = [super initWithFrame:frame]) != nil)
    style = aStyle;
  return self;
}

- (void)dealloc
{
  RELEASE (image);
  RELEASE (title);
  RELEASE (subtitle);
  RELEASE (note);
  RELEASE (representedObject);
  [super dealloc];
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)setImage:(NSImage *)anImage
{
  ASSIGN (image, anImage);
  [self setNeedsDisplay:YES];
}

- (void)setTitle:(NSString *)aTitle
{
  ASSIGNCOPY (title, aTitle);
  [self setNeedsDisplay:YES];
}

- (void)setSubtitle:(NSString *)aSubtitle
{
  ASSIGNCOPY (subtitle, aSubtitle);
  [self setNeedsDisplay:YES];
}

- (void)setNote:(NSString *)aNote
{
  ASSIGNCOPY (note, aNote);
  [self setNeedsDisplay:YES];
}

- (void)setRepresentedObject:(id)object
{
  ASSIGN (representedObject, object);
}

- (id)representedObject
{
  return representedObject;
}

- (void)setTarget:(id)target
{
  cardTarget = target;
}

- (id)target
{
  return cardTarget;
}

- (void)setAction:(SEL)action
{
  cardAction = action;
}

- (SEL)action
{
  return cardAction;
}

- (void)drawRect:(NSRect)rect
{
  NSRect b = [self bounds];
  CGFloat w = NSWidth (b);

  if (style == SWCardCategory)
    {
      NSColor *face = pressed ? [SWPanelColor () blendedColorWithFraction:0.1
                                                                  ofColor:SWTextColor ()]
        : SWPanelColor ();
      CGFloat side = 36, y = (NSHeight (b) - side) / 2;

      [face set];
      NSRectFill (b);
      SWDrawBevel (b, pressed, face);
      SWDrawImage (image, NSMakeRect (8, y, side, side));
      SWDrawText (title, NSMakeRect (8 + side + 10, NSHeight (b) / 2 - 16,
                                     w - side - 26, 16),
                  SWBoldFont (12.5), SWTextColor (), NSLeftTextAlignment);
      SWDrawText (subtitle, NSMakeRect (8 + side + 10, NSHeight (b) / 2 + 1,
                                        w - side - 26, 14),
                  SWFont (11), SWSecondaryTextColor (), NSLeftTextAlignment);
      return;
    }
  if (pressed)
    {
      [SWPanelColor () set];
      NSRectFill (b);
    }
  SWDrawImage (image, NSMakeRect ((w - 56) / 2, 10, 56, 56));
  SWDrawText (title, NSMakeRect (4, 72, w - 8, 16), SWBoldFont (12.5),
              SWTextColor (), NSCenterTextAlignment);
  SWDrawText (subtitle, NSMakeRect (4, 89, w - 8, 14), SWFont (11),
              SWSecondaryTextColor (), NSCenterTextAlignment);
  SWDrawText (note, NSMakeRect (4, 104, w - 8, 14), SWBoldFont (10.5),
              SWInstalledColor (), NSCenterTextAlignment);
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  return YES;
}

- (void)mouseDown:(NSEvent *)event
{
  NSWindow *window = [self window];
  BOOL inside = YES;

  pressed = YES;
  [self setNeedsDisplay:YES];
  while (1)
    {
      NSEvent *e = [window nextEventMatchingMask:NSLeftMouseUpMask
                                                 | NSLeftMouseDraggedMask];
      NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil];

      inside = NSPointInRect (p, [self bounds]);
      if (inside != pressed)
        {
          pressed = inside;
          [self setNeedsDisplay:YES];
        }
      if ([e type] == NSLeftMouseUp)
        break;
    }
  pressed = NO;
  [self setNeedsDisplay:YES];
  if (inside && cardAction != NULL)
    [NSApp sendAction:cardAction to:cardTarget from:self];
}

@end

@implementation SWSourceCell

- (void)dealloc
{
  RELEASE (icon);
  RELEASE (badge);
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
  SWSourceCell *copy = [super copyWithZone:zone];

  copy->icon = RETAIN (icon);
  copy->badge = [badge copyWithZone:zone];
  return copy;
}

- (void)setIcon:(NSImage *)anIcon
{
  ASSIGN (icon, anIcon);
}

- (void)setBadge:(NSString *)aBadge
{
  ASSIGNCOPY (badge, aBadge);
}

- (void)setHeading:(BOOL)flag
{
  heading = flag;
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
  NSColor *text = [self isHighlighted] ? [NSColor selectedControlTextColor]
    : SWTextColor ();
  CGFloat x = NSMinX (frame) + 4, badgeW = 0;

  if (heading)
    {
      SWDrawText ([[self stringValue] uppercaseString],
                  NSMakeRect (NSMinX (frame) + 4, NSMaxY (frame) - 16,
                              NSWidth (frame) - 8, 14),
                  SWBoldFont (10), SWSecondaryTextColor (),
                  NSLeftTextAlignment);
      return;
    }
  if (icon != nil)
    {
      SWDrawImage (icon, NSMakeRect (x, NSMidY (frame) - 8, 16, 16));
      x += 22;
    }
  if ([badge length] > 0)
    {
      badgeW = 26;
      SWDrawText (badge, NSMakeRect (NSMaxX (frame) - badgeW - 4,
                                     NSMidY (frame) - 7, badgeW, 14),
                  SWMonoFont (10.5),
                  [self isHighlighted] ? text : SWSecondaryTextColor (),
                  NSRightTextAlignment);
    }
  SWDrawText ([self stringValue],
              NSMakeRect (x, NSMidY (frame) - 8, NSMaxX (frame) - x - badgeW - 6,
                          16),
              SWFont (12.5), text, NSLeftTextAlignment);
}

@end

@implementation SWIconTextCell

- (void)dealloc
{
  RELEASE (icon);
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
  SWIconTextCell *copy = [super copyWithZone:zone];

  copy->icon = RETAIN (icon);
  return copy;
}

- (void)setIcon:(NSImage *)anIcon
{
  ASSIGN (icon, anIcon);
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
  NSRect rest = frame;
  CGFloat side = MIN (NSHeight (frame) - 4, 24);

  if (icon != nil)
    {
      SWDrawImage (icon, NSMakeRect (NSMinX (frame) + 2,
                                     NSMidY (frame) - side / 2, side, side));
      rest.origin.x += side + 7;
      rest.size.width -= side + 7;
    }
  [super drawInteriorWithFrame:rest inView:view];
}

@end

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

static NSString * const PetScaleKey = @"pet.scale";
static NSString * const PetOriginXKey = @"pet.origin.x";
static NSString * const PetOriginYKey = @"pet.origin.y";
static NSString * const PetAlwaysOnTopKey = @"pet.alwaysOnTop";
static NSString * const PetOpacityKey = @"pet.opacity";
static NSString * const PetClickThroughKey = @"pet.clickThrough";
static NSString * const PetRandomMovementKey = @"pet.randomMovement";
static NSString * const PetBehaviorModeKey = @"pet.behaviorMode";
static NSString * const PetMoodKey = @"pet.mood";
static NSString * const PetIntimacyKey = @"pet.intimacy";
static NSString * const PetFatigueKey = @"pet.fatigue";
static NSString * const PetActiveSecondsKey = @"pet.activeSeconds";
static NSString * const PetOpenSettingsNotificationName = @"DesktopCatPetOpenSettings";
static BOOL PetUITestMode = NO;
static NSString *PetUITestStatePath = nil;
static NSString *PetUITestCommandPath = nil;
static NSRect PetUITestInitialFrame = { .origin = { 160, 160 }, .size = { 220, 220 } };

static double PetMaxDouble(double a, double b) {
    return a > b ? a : b;
}

static CGFloat PetMinCGFloat(CGFloat a, CGFloat b) {
    return a < b ? a : b;
}

static CGFloat PetMaxCGFloat(CGFloat a, CGFloat b) {
    return a > b ? a : b;
}

typedef NS_ENUM(NSInteger, PetMode) {
    PetModeIdle,
    PetModeWalking,
    PetModeSleeping,
    PetModeUserControlled,
    PetModeDockSitting,
    PetModeEdgeWalking,
    PetModeFollowingMouse,
    PetModeLookingAtMouse
};

typedef NS_ENUM(NSInteger, PetBodyPart) {
    PetBodyPartHead,
    PetBodyPartBody,
    PetBodyPartPaws
};

static NSString *PetModeName(PetMode mode) {
    switch (mode) {
        case PetModeIdle: return @"idle";
        case PetModeWalking: return @"walking";
        case PetModeSleeping: return @"sleeping";
        case PetModeUserControlled: return @"userControlled";
        case PetModeDockSitting: return @"dockSitting";
        case PetModeEdgeWalking: return @"edgeWalking";
        case PetModeFollowingMouse: return @"followingMouse";
        case PetModeLookingAtMouse: return @"lookingAtMouse";
    }
}

@interface SpriteAtlas : NSObject
@property (nonatomic, strong, readonly) NSImage *image;
@property (nonatomic, strong, readonly) NSDictionary *atlas;
@property (nonatomic, assign, readonly) CGFloat atlasHeight;
- (instancetype)initWithResourcesPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)animationNamed:(NSString *)name;
@end

@implementation SpriteAtlas

- (instancetype)initWithResourcesPath:(NSString *)path error:(NSError **)error {
    self = [super init];
    if (!self) { return nil; }

    NSString *jsonPath = [path stringByAppendingPathComponent:@"cat_desktop_pet_sprite_sheet.json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath options:0 error:error];
    if (!jsonData) { return nil; }

    NSDictionary *decoded = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (![decoded isKindOfClass:[NSDictionary class]]) { return nil; }
    _atlas = decoded;

    NSString *imagePath = [path stringByAppendingPathComponent:@"cat_desktop_pet_sprite_sheet.png"];
    _image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    if (!_image) { return nil; }

    NSDictionary *atlasSize = _atlas[@"atlasSize"];
    _atlasHeight = [atlasSize[@"height"] doubleValue];
    return self;
}

- (NSDictionary *)animationNamed:(NSString *)name {
    NSDictionary *animations = self.atlas[@"animations"];
    NSDictionary *animation = animations[name];
    return animation ? animation : animations[@"idle_front"];
}

@end

@class PetView;
@class SettingsWindowController;

@interface PetController : NSObject
@property (nonatomic, strong, readonly) NSPanel *panel;
- (instancetype)initWithResourcesPath:(NSString *)path error:(NSError **)error;
- (void)show;
- (void)toggleVisibility;
- (void)setScale:(CGFloat)scale;
- (void)setAlwaysOnTop:(BOOL)enabled;
- (void)setOpacity:(CGFloat)opacity;
- (void)setClickThrough:(BOOL)enabled;
- (void)setRandomMovementEnabled:(BOOL)enabled;
- (void)setLaunchAtLoginEnabled:(BOOL)enabled;
- (void)setBehaviorMode:(NSString *)behaviorMode;
- (void)resetPosition;
- (CGFloat)currentScale;
- (CGFloat)currentOpacity;
- (CGFloat)mood;
- (CGFloat)intimacy;
- (CGFloat)fatigue;
- (NSTimeInterval)activeSeconds;
- (BOOL)alwaysOnTopEnabled;
- (BOOL)clickThroughEnabled;
- (BOOL)randomMovementEnabled;
- (BOOL)launchAtLoginEnabled;
- (NSString *)behaviorMode;
- (void)enterSleep;
- (void)wakeUp;
- (void)sitOnDock;
- (void)startEdgeWalking;
- (void)startFollowingMouse;
- (void)startLookingAtMouse;
- (void)showStatusBubble;
- (void)savePosition;
- (void)petWasClicked;
- (void)petWasClickedAtBodyPart:(PetBodyPart)bodyPart;
- (void)petDragStarted;
- (void)petDragEnded;
- (void)showContextMenuForView:(NSView *)view event:(NSEvent *)event;
- (void)writeUITestState;
+ (NSRect)combinedVisibleFrame;
@end

@interface PetView : NSView
@property (nonatomic, weak) PetController *controller;
@property (nonatomic, copy, readonly) NSString *animationName;
- (instancetype)initWithAtlas:(SpriteAtlas *)atlas;
- (void)setAnimationName:(NSString *)name completion:(void (^)(void))completion;
- (void)tick;
@end

@implementation PetView {
    SpriteAtlas *_spriteAtlas;
    NSString *_animationName;
    NSInteger _frameIndex;
    NSTimeInterval _frameAccumulator;
    NSDate *_lastTick;
    void (^_completion)(void);
    BOOL _isDragging;
    BOOL _isLongPressArmed;
    NSPoint _mouseDownScreenPoint;
    NSPoint _dragStartWindowOrigin;
    NSTimer *_longPressTimer;
}

@synthesize animationName = _animationName;

- (instancetype)initWithAtlas:(SpriteAtlas *)atlas {
    self = [super initWithFrame:NSMakeRect(0, 0, 220, 220)];
    if (!self) { return nil; }

    _spriteAtlas = atlas;
    _animationName = @"idle_front";
    _frameIndex = 0;
    _lastTick = [NSDate date];
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.clearColor.CGColor;
    return self;
}

- (BOOL)isOpaque {
    return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

- (void)setAnimationName:(NSString *)name completion:(void (^)(void))completion {
    NSDictionary *currentAnimation = [_spriteAtlas animationNamed:_animationName];
    if ([_animationName isEqualToString:name] && [currentAnimation[@"loop"] boolValue]) {
        return;
    }

    _animationName = [name copy];
    _frameIndex = 0;
    _frameAccumulator = 0;
    _lastTick = [NSDate date];
    _completion = [completion copy];
    self.needsDisplay = YES;
    [self.controller writeUITestState];
}

- (void)tick {
    NSDate *now = [NSDate date];
    NSTimeInterval delta = [now timeIntervalSinceDate:_lastTick];
    _lastTick = now;

    NSDictionary *animation = [_spriteAtlas animationNamed:_animationName];
    NSArray *frames = animation[@"frames"];
    if (frames.count == 0) { return; }

    double fps = PetMaxDouble([animation[@"fps"] doubleValue], 1.0);
    double frameDuration = 1.0 / fps;
    _frameAccumulator += delta;

    while (_frameAccumulator >= frameDuration) {
        _frameAccumulator -= frameDuration;
        _frameIndex += 1;

        if (_frameIndex >= (NSInteger)frames.count) {
            if ([animation[@"loop"] boolValue]) {
                _frameIndex = 0;
            } else {
                NSInteger lastFrameIndex = (NSInteger)frames.count - 1;
                _frameIndex = lastFrameIndex > 0 ? lastFrameIndex : 0;
                void (^finished)(void) = _completion;
                _completion = nil;
                if (finished) { finished(); }
                break;
            }
        }
    }

    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [NSColor.clearColor setFill];
    NSRectFill(dirtyRect);

    NSDictionary *animation = [_spriteAtlas animationNamed:_animationName];
    NSArray *frames = animation[@"frames"];
    if (frames.count == 0) { return; }

    NSInteger safeFrameIndex = _frameIndex < (NSInteger)frames.count - 1 ? _frameIndex : (NSInteger)frames.count - 1;
    NSDictionary *frame = frames[safeFrameIndex];
    CGFloat x = [frame[@"x"] doubleValue];
    CGFloat y = [frame[@"y"] doubleValue];
    CGFloat w = [frame[@"w"] doubleValue];
    CGFloat h = [frame[@"h"] doubleValue];
    CGFloat sourceY = _spriteAtlas.atlasHeight - y - h;
    NSRect sourceRect = NSMakeRect(x, sourceY, w, h);

    [_spriteAtlas.image drawInRect:self.bounds
                          fromRect:sourceRect
                         operation:NSCompositingOperationSourceOver
                          fraction:1.0
                    respectFlipped:NO
                             hints:@{ NSImageHintInterpolation: @(NSImageInterpolationHigh) }];
}

- (void)mouseDown:(NSEvent *)event {
    _isDragging = NO;
    _isLongPressArmed = NO;
    _mouseDownScreenPoint = NSEvent.mouseLocation;
    _dragStartWindowOrigin = self.window.frame.origin;
    [_longPressTimer invalidate];
    __weak PetView *weakSelf = self;
    _longPressTimer = [NSTimer scheduledTimerWithTimeInterval:0.35 repeats:NO block:^(NSTimer *timer) {
        (void)timer;
        PetView *strongSelf = weakSelf;
        if (!strongSelf) { return; }
        strongSelf->_isLongPressArmed = YES;
        [strongSelf.controller petDragStarted];
    }];
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint current = NSEvent.mouseLocation;
    CGFloat dx = current.x - _mouseDownScreenPoint.x;
    CGFloat dy = current.y - _mouseDownScreenPoint.y;

    if (!_isDragging && (hypot(dx, dy) > 3.0 || _isLongPressArmed)) {
        _isDragging = YES;
        if (!_isLongPressArmed) {
            [_longPressTimer invalidate];
            _longPressTimer = nil;
            [self.controller petDragStarted];
        }
    }

    if (!_isDragging) { return; }
    [self.window setFrameOrigin:NSMakePoint(_dragStartWindowOrigin.x + dx, _dragStartWindowOrigin.y + dy)];
}

- (void)mouseUp:(NSEvent *)event {
    [_longPressTimer invalidate];
    _longPressTimer = nil;

    if (_isDragging) {
        _isDragging = NO;
        [self.controller petDragEnded];
    } else {
        [self.controller petWasClickedAtBodyPart:[self bodyPartAtPoint:event.locationInWindow]];
    }
}

- (PetBodyPart)bodyPartAtPoint:(NSPoint)point {
    CGFloat normalizedY = point.y / PetMaxCGFloat(self.bounds.size.height, 1.0);
    if (normalizedY >= 0.58) { return PetBodyPartHead; }
    if (normalizedY >= 0.28) { return PetBodyPartBody; }
    return PetBodyPartPaws;
}

- (void)rightMouseDown:(NSEvent *)event {
    [self.controller showContextMenuForView:self event:event];
}

@end

@interface BubbleController : NSObject
- (void)showMessage:(NSString *)message nearFrame:(NSRect)frame;
- (void)hide;
@end

@implementation BubbleController {
    NSPanel *_bubblePanel;
    NSTextField *_label;
    NSTimer *_hideTimer;
}

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    _bubblePanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 260, 64)
                                              styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    _bubblePanel.opaque = NO;
    _bubblePanel.backgroundColor = NSColor.clearColor;
    _bubblePanel.hasShadow = YES;
    _bubblePanel.hidesOnDeactivate = NO;
    _bubblePanel.ignoresMouseEvents = YES;
    _bubblePanel.level = NSFloatingWindowLevel;
    _bubblePanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;

    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 260, 64)];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.08 alpha:0.88].CGColor;
    contentView.layer.cornerRadius = 8.0;
    contentView.layer.borderWidth = 1.0;
    contentView.layer.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.18].CGColor;

    _label = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 10, 232, 44)];
    _label.editable = NO;
    _label.bezeled = NO;
    _label.drawsBackground = NO;
    _label.textColor = NSColor.whiteColor;
    _label.font = [NSFont systemFontOfSize:13.0];
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    [contentView addSubview:_label];
    _bubblePanel.contentView = contentView;

    return self;
}

- (void)showMessage:(NSString *)message nearFrame:(NSRect)frame {
    [_hideTimer invalidate];
    _label.stringValue = message;

    NSRect bubbleFrame = _bubblePanel.frame;
    bubbleFrame.origin.x = NSMidX(frame) - NSWidth(bubbleFrame) / 2.0;
    bubbleFrame.origin.y = NSMaxY(frame) + 8.0;

    NSRect bounds = [PetController combinedVisibleFrame];
    if (NSMaxX(bubbleFrame) > NSMaxX(bounds)) { bubbleFrame.origin.x = NSMaxX(bounds) - NSWidth(bubbleFrame); }
    if (NSMinX(bubbleFrame) < NSMinX(bounds)) { bubbleFrame.origin.x = NSMinX(bounds); }
    if (NSMaxY(bubbleFrame) > NSMaxY(bounds)) { bubbleFrame.origin.y = NSMinY(frame) - NSHeight(bubbleFrame) - 8.0; }

    [_bubblePanel setFrame:bubbleFrame display:YES];
    [_bubblePanel orderFrontRegardless];
    _hideTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:NO block:^(NSTimer *timer) {
        (void)timer;
        [self hide];
    }];
}

- (void)hide {
    [_hideTimer invalidate];
    _hideTimer = nil;
    [_bubblePanel orderOut:nil];
}

@end

@implementation PetController {
    SpriteAtlas *_spriteAtlas;
    PetView *_petView;
    BubbleController *_bubbleController;
    NSTimer *_animationTimer;
    NSTimer *_movementTimer;
    NSTimer *_behaviorTimer;
    NSTimer *_wellbeingTimer;
    PetMode _mode;
    CGFloat _walkDirection;
    CGFloat _lastLookDirection;
    NSDate *_modeUntil;
    NSDate *_lastMovementTick;
    NSDate *_lastPositionSave;
    NSDate *_lastWellbeingTick;
    NSDate *_lastGreetingAt;
    NSTimer *_uiTestCommandTimer;
    NSDate *_lastCommandModifiedAt;
}

- (instancetype)initWithResourcesPath:(NSString *)path error:(NSError **)error {
    self = [super init];
    if (!self) { return nil; }

    _spriteAtlas = [[SpriteAtlas alloc] initWithResourcesPath:path error:error];
    if (!_spriteAtlas) { return nil; }

    CGFloat scale = PetUITestMode ? (PetUITestInitialFrame.size.width / 512.0) : [self currentScale];
    _petView = [[PetView alloc] initWithAtlas:_spriteAtlas];
    _petView.controller = self;
    _bubbleController = [[BubbleController alloc] init];

    _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(240, 240, 512 * scale, 512 * scale)
                                        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
    _panel.contentView = _petView;
    _panel.opaque = NO;
    _panel.backgroundColor = NSColor.clearColor;
    _panel.hasShadow = NO;
    _panel.title = @"DesktopCatPet";
    _panel.hidesOnDeactivate = NO;
    _panel.movableByWindowBackground = NO;
    _panel.ignoresMouseEvents = [self clickThroughEnabled];
    _panel.alphaValue = [self currentOpacity];
    _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorStationary;
    _panel.level = [self alwaysOnTopEnabled] ? NSScreenSaverWindowLevel : NSFloatingWindowLevel;

    _mode = PetModeIdle;
    _walkDirection = 1;
    _lastLookDirection = 0;
    _lastMovementTick = [NSDate date];
    _lastPositionSave = [NSDate distantPast];
    _lastWellbeingTick = [NSDate date];
    _lastGreetingAt = [NSDate distantPast];
    [self ensureWellbeingDefaults];
    if (PetUITestMode) {
        [_panel setFrame:PetUITestInitialFrame display:NO];
    } else {
        [self restorePosition];
    }
    return self;
}

- (void)show {
    [_panel orderFrontRegardless];
    [self startTimers];
    [self writeUITestState];
}

- (void)toggleVisibility {
    if (_panel.visible) {
        [_panel orderOut:nil];
    } else {
        [self show];
    }
    [self writeUITestState];
}

- (void)setScale:(CGFloat)scale {
    if (scale < 0.2) { scale = 0.2; }
    if (scale > 1.2) { scale = 1.2; }
    [NSUserDefaults.standardUserDefaults setDouble:scale forKey:PetScaleKey];
    NSRect frame = _panel.frame;
    frame.size = NSMakeSize(512 * scale, 512 * scale);
    [_panel setFrame:frame display:YES];
    [self writeUITestState];
}

- (void)setAlwaysOnTop:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:PetAlwaysOnTopKey];
    _panel.level = enabled ? NSScreenSaverWindowLevel : NSFloatingWindowLevel;
    [self writeUITestState];
}

- (void)setOpacity:(CGFloat)opacity {
    if (opacity < 0.2) { opacity = 0.2; }
    if (opacity > 1.0) { opacity = 1.0; }
    [NSUserDefaults.standardUserDefaults setDouble:opacity forKey:PetOpacityKey];
    _panel.alphaValue = opacity;
    [self writeUITestState];
}

- (void)setClickThrough:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:PetClickThroughKey];
    _panel.ignoresMouseEvents = enabled;
    [self writeUITestState];
}

- (void)setRandomMovementEnabled:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:PetRandomMovementKey];
    if (!enabled && _mode == PetModeWalking) {
        [self wakeUp];
    }
    [self writeUITestState];
}

- (void)setLaunchAtLoginEnabled:(BOOL)enabled {
    if (@available(macOS 13.0, *)) {
        NSError *error = nil;
        BOOL success = enabled ? [SMAppService.mainAppService registerAndReturnError:&error] : [SMAppService.mainAppService unregisterAndReturnError:&error];
        if (!success) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = enabled ? @"无法开启开机启动" : @"无法关闭开机启动";
            NSString *errorDescription = error.localizedDescription;
            alert.informativeText = errorDescription ? errorDescription : @"macOS 没有接受这次登录项设置变更。";
            [alert runModal];
        }
    }
    [self writeUITestState];
}

- (void)resetPosition {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:PetOriginXKey];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:PetOriginYKey];
    [self restorePosition];
    [self savePosition];
}

- (void)ensureWellbeingDefaults {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults objectForKey:PetMoodKey]) { [defaults setDouble:72.0 forKey:PetMoodKey]; }
    if (![defaults objectForKey:PetIntimacyKey]) { [defaults setDouble:20.0 forKey:PetIntimacyKey]; }
    if (![defaults objectForKey:PetFatigueKey]) { [defaults setDouble:18.0 forKey:PetFatigueKey]; }
    if (![defaults objectForKey:PetActiveSecondsKey]) { [defaults setDouble:0.0 forKey:PetActiveSecondsKey]; }
    if (![defaults objectForKey:PetBehaviorModeKey]) { [defaults setObject:@"auto" forKey:PetBehaviorModeKey]; }
}

- (CGFloat)clampedMetric:(CGFloat)value {
    return PetMaxCGFloat(0.0, PetMinCGFloat(value, 100.0));
}

- (void)addMood:(CGFloat)delta intimacy:(CGFloat)intimacyDelta fatigue:(CGFloat)fatigueDelta {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:[self clampedMetric:self.mood + delta] forKey:PetMoodKey];
    [defaults setDouble:[self clampedMetric:self.intimacy + intimacyDelta] forKey:PetIntimacyKey];
    [defaults setDouble:[self clampedMetric:self.fatigue + fatigueDelta] forKey:PetFatigueKey];
    [self writeUITestState];
}

- (void)setBehaviorMode:(NSString *)behaviorMode {
    NSSet<NSString *> *allowedModes = [NSSet setWithArray:@[@"auto", @"dock", @"edge", @"follow", @"look"]];
    NSString *mode = [allowedModes containsObject:behaviorMode] ? behaviorMode : @"auto";
    [NSUserDefaults.standardUserDefaults setObject:mode forKey:PetBehaviorModeKey];

    if ([mode isEqualToString:@"dock"]) {
        [self sitOnDock];
    } else if ([mode isEqualToString:@"edge"]) {
        [self startEdgeWalking];
    } else if ([mode isEqualToString:@"follow"]) {
        [self startFollowingMouse];
    } else if ([mode isEqualToString:@"look"]) {
        [self startLookingAtMouse];
    } else {
        [self wakeUp];
        [self showBubble:@"我自己活动一会儿。"];
    }
    [self writeUITestState];
}

- (void)enterSleep {
    _mode = PetModeSleeping;
    _modeUntil = [NSDate dateWithTimeIntervalSinceNow:12.0];
    [_petView setAnimationName:@"sleep" completion:nil];
    [self addMood:1.0 intimacy:0.0 fatigue:-8.0];
    [self showBubble:@"我先睡一小会儿。"];
    [self writeUITestState];
}

- (void)wakeUp {
    _mode = PetModeIdle;
    _modeUntil = nil;
    [_petView setAnimationName:@"idle_front" completion:nil];
    [self writeUITestState];
}

- (void)savePosition {
    [NSUserDefaults.standardUserDefaults setDouble:_panel.frame.origin.x forKey:PetOriginXKey];
    [NSUserDefaults.standardUserDefaults setDouble:_panel.frame.origin.y forKey:PetOriginYKey];
    [self writeUITestState];
}

- (void)petWasClicked {
    [self petWasClickedAtBodyPart:PetBodyPartBody];
}

- (void)petWasClickedAtBodyPart:(PetBodyPart)bodyPart {
    _mode = PetModeUserControlled;
    __weak PetController *weakSelf = self;
    [_petView setAnimationName:@"clicked_happy" completion:^{
        [weakSelf wakeUp];
    }];

    if (bodyPart == PetBodyPartHead) {
        [self addMood:7.0 intimacy:4.0 fatigue:0.0];
        [self showBubble:@"摸头舒服。亲密度增加了。"];
    } else if (bodyPart == PetBodyPartBody) {
        [self addMood:4.0 intimacy:2.0 fatigue:0.0];
        [self showBubble:@"我听见你啦。"];
    } else {
        [self addMood:1.0 intimacy:1.0 fatigue:2.0];
        [self showBubble:@"爪子有点敏感。"];
    }
    [self writeUITestState];
}

- (void)petDragStarted {
    _mode = PetModeUserControlled;
    [_petView setAnimationName:@"dragged" completion:nil];
    [self addMood:2.0 intimacy:1.0 fatigue:1.0];
    [self showBubble:@"抱起来了。"];
    [self writeUITestState];
}

- (void)petDragEnded {
    [self savePosition];
    [self wakeUp];
    [self showBubble:@"落地。"];
}

- (void)showBubble:(NSString *)message {
    [_bubbleController showMessage:message nearFrame:_panel.frame];
}

- (void)showStatusBubble {
    NSInteger minutes = (NSInteger)llround(self.activeSeconds / 60.0);
    NSString *message = [NSString stringWithFormat:@"心情 %.0f  亲密 %.0f  疲劳 %.0f\n今天陪伴 %ld 分钟", self.mood, self.intimacy, self.fatigue, (long)minutes];
    [self showBubble:message];
}

- (CGFloat)currentScale {
    double savedScale = [NSUserDefaults.standardUserDefaults doubleForKey:PetScaleKey];
    return savedScale > 0 ? savedScale : 0.43;
}

- (CGFloat)currentOpacity {
    id savedOpacity = [NSUserDefaults.standardUserDefaults objectForKey:PetOpacityKey];
    if (!savedOpacity) { return 1.0; }
    return PetMaxCGFloat(0.2, PetMinCGFloat([savedOpacity doubleValue], 1.0));
}

- (CGFloat)mood {
    return [NSUserDefaults.standardUserDefaults doubleForKey:PetMoodKey];
}

- (CGFloat)intimacy {
    return [NSUserDefaults.standardUserDefaults doubleForKey:PetIntimacyKey];
}

- (CGFloat)fatigue {
    return [NSUserDefaults.standardUserDefaults doubleForKey:PetFatigueKey];
}

- (NSTimeInterval)activeSeconds {
    return [NSUserDefaults.standardUserDefaults doubleForKey:PetActiveSecondsKey];
}

- (BOOL)alwaysOnTopEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:PetAlwaysOnTopKey];
}

- (BOOL)clickThroughEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:PetClickThroughKey];
}

- (BOOL)randomMovementEnabled {
    id saved = [NSUserDefaults.standardUserDefaults objectForKey:PetRandomMovementKey];
    return saved ? [saved boolValue] : YES;
}

- (BOOL)launchAtLoginEnabled {
    if (@available(macOS 13.0, *)) {
        return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
    }
    return NO;
}

- (NSString *)behaviorMode {
    NSString *mode = [NSUserDefaults.standardUserDefaults stringForKey:PetBehaviorModeKey];
    return mode ? mode : @"auto";
}

- (void)restorePosition {
    id savedX = [NSUserDefaults.standardUserDefaults objectForKey:PetOriginXKey];
    id savedY = [NSUserDefaults.standardUserDefaults objectForKey:PetOriginYKey];
    if (savedX && savedY) {
        [_panel setFrameOrigin:NSMakePoint([savedX doubleValue], [savedY doubleValue])];
        return;
    }

    NSScreen *screen = NSScreen.mainScreen;
    if (!screen) { return; }
    NSRect visible = screen.visibleFrame;
    NSRect frame = _panel.frame;
    [_panel setFrameOrigin:NSMakePoint(NSMidX(visible) - frame.size.width / 2.0, NSMinY(visible) + 48.0)];
}

- (void)startTimers {
    if (_animationTimer) { return; }

    __weak PetController *weakSelf = self;
    _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        PetController *strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [strongSelf->_petView tick];
    }];
    _movementTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf moveIfNeeded];
    }];
    _wellbeingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf updateWellbeing];
    }];
    if (!PetUITestMode) {
        _behaviorTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer *timer) {
            (void)timer;
            [weakSelf chooseNextBehavior];
        }];
    } else {
        _uiTestCommandTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 repeats:YES block:^(NSTimer *timer) {
            (void)timer;
            [weakSelf pollUITestCommand];
        }];
    }
}

- (void)chooseNextBehavior {
    if (![self randomMovementEnabled]) {
        if (_mode == PetModeWalking) { [self wakeUp]; }
        return;
    }

    NSString *behaviorMode = self.behaviorMode;
    if ([behaviorMode isEqualToString:@"dock"] || [behaviorMode isEqualToString:@"edge"] || [behaviorMode isEqualToString:@"follow"] || [behaviorMode isEqualToString:@"look"]) {
        BOOL alreadyInMode = ([behaviorMode isEqualToString:@"dock"] && _mode == PetModeDockSitting) ||
            ([behaviorMode isEqualToString:@"edge"] && _mode == PetModeEdgeWalking) ||
            ([behaviorMode isEqualToString:@"follow"] && _mode == PetModeFollowingMouse) ||
            ([behaviorMode isEqualToString:@"look"] && _mode == PetModeLookingAtMouse);
        if (!alreadyInMode) {
            [self setBehaviorMode:behaviorMode];
        }
        return;
    }

    NSDate *now = [NSDate date];
    if (_mode == PetModeUserControlled) { return; }
    if ((_mode == PetModeWalking || _mode == PetModeSleeping) && _modeUntil && [now compare:_modeUntil] == NSOrderedAscending) {
        return;
    }

    NSInteger roll = arc4random_uniform(100);
    if (roll < 18) {
        [self enterSleep];
    } else if (roll < 66) {
        _mode = PetModeWalking;
        _walkDirection = arc4random_uniform(2) == 0 ? -1.0 : 1.0;
        _modeUntil = [NSDate dateWithTimeIntervalSinceNow:3.0 + ((double)arc4random_uniform(36) / 10.0)];
        [_petView setAnimationName:_walkDirection > 0 ? @"walk_right" : @"walk_left" completion:nil];
    } else {
        [self wakeUp];
    }
}

- (void)updateWellbeing {
    NSDate *now = [NSDate date];
    NSTimeInterval delta = [now timeIntervalSinceDate:_lastWellbeingTick];
    _lastWellbeingTick = now;
    if (delta <= 0 || delta > 10) { return; }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (_panel.visible) {
        [defaults setDouble:self.activeSeconds + delta forKey:PetActiveSecondsKey];
    }

    CGFloat fatigueDelta = (_mode == PetModeSleeping || _mode == PetModeDockSitting) ? -0.8 * delta : 0.08 * delta;
    CGFloat moodDelta = self.fatigue > 82.0 ? -0.06 * delta : 0.015 * delta;
    [self addMood:moodDelta intimacy:0.0 fatigue:fatigueDelta];

    if (!PetUITestMode && self.fatigue > 86.0 && [now timeIntervalSinceDate:_lastGreetingAt] > 60.0) {
        _lastGreetingAt = now;
        [self showBubble:@"有点困了，想休息一下。"];
    } else if (!PetUITestMode && self.activeSeconds > 0 && ((NSInteger)self.activeSeconds % 1800) < 2 && [now timeIntervalSinceDate:_lastGreetingAt] > 300.0) {
        _lastGreetingAt = now;
        [self showBubble:@"我陪你很久啦，记得活动一下。"];
    }
}

- (void)sitOnDock {
    _mode = PetModeDockSitting;
    _modeUntil = nil;
    NSRect frame = _panel.frame;
    NSScreen *screen = [self screenForFrame:frame];
    NSRect screenFrame = screen ? screen.frame : [self.class combinedVisibleFrame];
    NSRect visibleFrame = screen ? screen.visibleFrame : [self.class combinedVisibleFrame];

    if (NSMinY(visibleFrame) > NSMinY(screenFrame) + 4.0) {
        frame.origin.x = NSMidX(visibleFrame) - NSWidth(frame) / 2.0;
        frame.origin.y = NSMinY(visibleFrame);
    } else if (NSMinX(visibleFrame) > NSMinX(screenFrame) + 4.0) {
        frame.origin.x = NSMinX(visibleFrame);
        frame.origin.y = NSMidY(visibleFrame) - NSHeight(frame) / 2.0;
    } else if (NSMaxX(visibleFrame) < NSMaxX(screenFrame) - 4.0) {
        frame.origin.x = NSMaxX(visibleFrame) - NSWidth(frame);
        frame.origin.y = NSMidY(visibleFrame) - NSHeight(frame) / 2.0;
    } else {
        frame.origin.x = NSMidX(visibleFrame) - NSWidth(frame) / 2.0;
        frame.origin.y = NSMinY(visibleFrame);
    }
    frame.origin.x = PetMaxCGFloat(NSMinX(visibleFrame), PetMinCGFloat(frame.origin.x, NSMaxX(visibleFrame) - NSWidth(frame)));
    frame.origin.y = PetMaxCGFloat(NSMinY(visibleFrame), PetMinCGFloat(frame.origin.y, NSMaxY(visibleFrame) - NSHeight(frame)));
    [_panel setFrameOrigin:frame.origin];
    [_petView setAnimationName:@"idle_front" completion:nil];
    [self savePosition];
    [self showBubble:@"我坐在 Dock 边休息。"];
}

- (void)startEdgeWalking {
    _mode = PetModeEdgeWalking;
    _modeUntil = nil;
    _walkDirection = _walkDirection == 0 ? 1.0 : _walkDirection;
    [_petView setAnimationName:_walkDirection > 0 ? @"walk_right" : @"walk_left" completion:nil];
    [self showBubble:@"沿着边边走。"];
    [self writeUITestState];
}

- (void)startFollowingMouse {
    _mode = PetModeFollowingMouse;
    _modeUntil = nil;
    [self showBubble:@"我跟着鼠标走。"];
    [self writeUITestState];
}

- (void)startLookingAtMouse {
    _mode = PetModeLookingAtMouse;
    _modeUntil = nil;
    [self showBubble:@"我会看着鼠标。"];
    [self writeUITestState];
}

- (void)moveIfNeeded {
    NSDate *now = [NSDate date];
    NSTimeInterval delta = [now timeIntervalSinceDate:_lastMovementTick];
    _lastMovementTick = now;

    if ((_mode == PetModeWalking || _mode == PetModeEdgeWalking) && ![self randomMovementEnabled]) { return; }
    if (!(_mode == PetModeWalking || _mode == PetModeEdgeWalking || _mode == PetModeFollowingMouse || _mode == PetModeLookingAtMouse)) { return; }

    NSRect frame = _panel.frame;
    NSRect bounds = [self visibleFrameForFrame:frame];

    if (_mode == PetModeFollowingMouse) {
        NSPoint mouse = NSEvent.mouseLocation;
        bounds = [self visibleFrameForPoint:mouse fallbackFrame:frame];
        CGFloat targetX = mouse.x - NSWidth(frame) / 2.0;
        CGFloat targetY = mouse.y - NSHeight(frame) * 0.35;
        CGFloat maxStep = 180.0 * delta;
        CGFloat dx = targetX - frame.origin.x;
        CGFloat dy = targetY - frame.origin.y;
        CGFloat distance = hypot(dx, dy);
        if (distance > 4.0) {
            CGFloat step = PetMinCGFloat(maxStep, distance);
            frame.origin.x += dx / distance * step;
            frame.origin.y += dy / distance * step;
            _walkDirection = dx >= 0 ? 1.0 : -1.0;
            [_petView setAnimationName:_walkDirection > 0 ? @"walk_right" : @"walk_left" completion:nil];
        } else {
            [_petView setAnimationName:@"idle_front" completion:nil];
        }
    } else if (_mode == PetModeLookingAtMouse) {
        NSPoint mouse = NSEvent.mouseLocation;
        CGFloat direction = mouse.x >= NSMidX(frame) ? 1.0 : -1.0;
        if (direction != _lastLookDirection) {
            _lastLookDirection = direction;
            [_petView setAnimationName:direction > 0 ? @"walk_right" : @"walk_left" completion:nil];
        }
    } else {
        frame.origin.x += _walkDirection * 58.0 * delta;

        if (_mode == PetModeEdgeWalking) {
            frame.origin.y = NSMinY(bounds);
        }

        if (NSMinX(frame) < NSMinX(bounds)) {
            frame.origin.x = NSMinX(bounds);
            _walkDirection = 1.0;
            _modeUntil = [NSDate dateWithTimeIntervalSinceNow:4.0];
            [_petView setAnimationName:@"walk_right" completion:nil];
        } else if (NSMaxX(frame) > NSMaxX(bounds)) {
            frame.origin.x = NSMaxX(bounds) - NSWidth(frame);
            _walkDirection = -1.0;
            _modeUntil = [NSDate dateWithTimeIntervalSinceNow:4.0];
            [_petView setAnimationName:@"walk_left" completion:nil];
        }
    }

    frame.origin.y = PetMaxCGFloat(NSMinY(bounds), PetMinCGFloat(frame.origin.y, NSMaxY(bounds) - NSHeight(frame)));
    [_panel setFrameOrigin:frame.origin];
    [self savePositionIfDue];
}

- (void)pollUITestCommand {
    if (!PetUITestCommandPath) { return; }

    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:PetUITestCommandPath error:nil];
    NSDate *modifiedAt = attributes[NSFileModificationDate];
    if (!modifiedAt || [_lastCommandModifiedAt isEqualToDate:modifiedAt]) { return; }
    _lastCommandModifiedAt = modifiedAt;

    NSString *command = [NSString stringWithContentsOfFile:PetUITestCommandPath encoding:NSUTF8StringEncoding error:nil];
    command = [command stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if ([command isEqualToString:@"sleep"]) {
        [self enterSleep];
    } else if ([command isEqualToString:@"wake"]) {
        [self wakeUp];
    } else if ([command isEqualToString:@"walk_right"]) {
        _mode = PetModeUserControlled;
        [_petView setAnimationName:@"walk_right" completion:nil];
        [self writeUITestState];
    } else if ([command isEqualToString:@"walk_left"]) {
        _mode = PetModeUserControlled;
        [_petView setAnimationName:@"walk_left" completion:nil];
        [self writeUITestState];
    } else if ([command isEqualToString:@"hide"]) {
        [_panel orderOut:nil];
        [self writeUITestState];
    } else if ([command isEqualToString:@"show"]) {
        [_panel orderFrontRegardless];
        [self writeUITestState];
    } else if ([command hasPrefix:@"scale "]) {
        double scale = [[command substringFromIndex:6] doubleValue];
        if (scale > 0) { [self setScale:scale]; }
    } else if ([command hasPrefix:@"opacity "]) {
        double opacity = [[command substringFromIndex:8] doubleValue];
        [self setOpacity:opacity];
    } else if ([command isEqualToString:@"click_through_on"]) {
        [self setClickThrough:YES];
    } else if ([command isEqualToString:@"click_through_off"]) {
        [self setClickThrough:NO];
    } else if ([command isEqualToString:@"random_on"]) {
        [self setRandomMovementEnabled:YES];
    } else if ([command isEqualToString:@"random_off"]) {
        [self setRandomMovementEnabled:NO];
    } else if ([command hasPrefix:@"behavior "]) {
        [self setBehaviorMode:[command substringFromIndex:9]];
    } else if ([command hasPrefix:@"click_part "]) {
        NSString *part = [command substringFromIndex:11];
        if ([part isEqualToString:@"head"]) {
            [self petWasClickedAtBodyPart:PetBodyPartHead];
        } else if ([part isEqualToString:@"paws"]) {
            [self petWasClickedAtBodyPart:PetBodyPartPaws];
        } else {
            [self petWasClickedAtBodyPart:PetBodyPartBody];
        }
    } else if ([command isEqualToString:@"quit"]) {
        [NSApp terminate:nil];
    }
}

- (void)writeUITestState {
    if (!PetUITestMode || !PetUITestStatePath) { return; }

    NSRect frame = _panel.frame;
    NSString *animationName = _petView.animationName;
    NSDictionary *state = @{
        @"pid": @(NSProcessInfo.processInfo.processIdentifier),
        @"animation": animationName ? animationName : @"",
        @"mode": PetModeName(_mode),
        @"behaviorMode": self.behaviorMode,
        @"mood": @(self.mood),
        @"intimacy": @(self.intimacy),
        @"fatigue": @(self.fatigue),
        @"activeSeconds": @(self.activeSeconds),
        @"visible": @(_panel.visible),
        @"opacity": @(_panel.alphaValue),
        @"clickThrough": @(_panel.ignoresMouseEvents),
        @"randomMovement": @([self randomMovementEnabled]),
        @"alwaysOnTop": @([self alwaysOnTopEnabled]),
        @"frame": @{
            @"x": @(frame.origin.x),
            @"y": @(frame.origin.y),
            @"w": @(frame.size.width),
            @"h": @(frame.size.height)
        }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) { return; }
    [data writeToFile:PetUITestStatePath atomically:YES];
}

- (void)showContextMenuForView:(NSView *)view event:(NSEvent *)event {
    NSMenu *menu = [[NSMenu alloc] init];
    NSArray<NSMenuItem *> *items = @[
        [[NSMenuItem alloc] initWithTitle:@"睡觉" action:@selector(contextSleep:) keyEquivalent:@""],
        [[NSMenuItem alloc] initWithTitle:@"醒来" action:@selector(contextWake:) keyEquivalent:@""],
        [[NSMenuItem alloc] initWithTitle:@"状态" action:@selector(contextStatus:) keyEquivalent:@""],
        NSMenuItem.separatorItem,
        [[NSMenuItem alloc] initWithTitle:@"坐在 Dock 上" action:@selector(contextDock:) keyEquivalent:@""],
        [[NSMenuItem alloc] initWithTitle:@"贴边走" action:@selector(contextEdge:) keyEquivalent:@""],
        [[NSMenuItem alloc] initWithTitle:@"跟随鼠标" action:@selector(contextFollow:) keyEquivalent:@""],
        [[NSMenuItem alloc] initWithTitle:@"看向鼠标" action:@selector(contextLook:) keyEquivalent:@""],
        NSMenuItem.separatorItem,
        [[NSMenuItem alloc] initWithTitle:@"设置..." action:@selector(contextSettings:) keyEquivalent:@""],
        [[NSMenuItem alloc] initWithTitle:@"隐藏" action:@selector(contextHide:) keyEquivalent:@""],
        NSMenuItem.separatorItem,
        [[NSMenuItem alloc] initWithTitle:@"退出" action:@selector(contextQuit:) keyEquivalent:@""]
    ];

    for (NSMenuItem *item in items) {
        item.target = [item isSeparatorItem] ? nil : self;
        [menu addItem:item];
    }
    [NSMenu popUpContextMenu:menu withEvent:event forView:view];
}

- (void)contextSleep:(id)sender {
    (void)sender;
    [self enterSleep];
}

- (void)contextWake:(id)sender {
    (void)sender;
    [self wakeUp];
}

- (void)contextStatus:(id)sender {
    (void)sender;
    [self showStatusBubble];
}

- (void)contextDock:(id)sender {
    (void)sender;
    [self setBehaviorMode:@"dock"];
}

- (void)contextEdge:(id)sender {
    (void)sender;
    [self setBehaviorMode:@"edge"];
}

- (void)contextFollow:(id)sender {
    (void)sender;
    [self setBehaviorMode:@"follow"];
}

- (void)contextLook:(id)sender {
    (void)sender;
    [self setBehaviorMode:@"look"];
}

- (void)contextSettings:(id)sender {
    (void)sender;
    [NSNotificationCenter.defaultCenter postNotificationName:PetOpenSettingsNotificationName object:self];
}

- (void)contextHide:(id)sender {
    (void)sender;
    [self toggleVisibility];
}

- (void)contextQuit:(id)sender {
    (void)sender;
    [self savePosition];
    [NSApp terminate:nil];
}

- (void)savePositionIfDue {
    NSDate *now = [NSDate date];
    if ([now timeIntervalSinceDate:_lastPositionSave] < 1.0) { return; }
    _lastPositionSave = now;
    [self savePosition];
}

- (NSRect)visibleFrameForFrame:(NSRect)frame {
    NSScreen *screen = [self screenForFrame:frame];
    return screen ? screen.visibleFrame : [self.class combinedVisibleFrame];
}

- (NSScreen *)screenForFrame:(NSRect)frame {
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    NSScreen *bestScreen = NSScreen.mainScreen;
    CGFloat bestScore = -1.0;

    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(center, screen.frame)) { return screen; }
        NSRect intersection = NSIntersectionRect(frame, screen.frame);
        CGFloat score = NSWidth(intersection) * NSHeight(intersection);
        if (score > bestScore) {
            bestScore = score;
            bestScreen = screen;
        }
    }
    return bestScreen;
}

- (NSRect)visibleFrameForPoint:(NSPoint)point fallbackFrame:(NSRect)frame {
    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(point, screen.frame)) {
            return screen.visibleFrame;
        }
    }
    return [self visibleFrameForFrame:frame];
}

- (NSRect)dockAdjacentVisibleFrameForFrame:(NSRect)frame {
    NSScreen *screen = [self screenForFrame:frame];
    return screen ? screen.visibleFrame : [self.class combinedVisibleFrame];
}

+ (NSRect)combinedVisibleFrame {
    NSArray<NSScreen *> *screens = NSScreen.screens;
    if (screens.count == 0) { return NSMakeRect(0, 0, 1440, 900); }

    NSRect combined = screens.firstObject.visibleFrame;
    for (NSScreen *screen in screens) {
        combined = NSUnionRect(combined, screen.visibleFrame);
    }
    return combined;
}

@end

@interface SettingsWindowController : NSWindowController
- (instancetype)initWithPetController:(PetController *)petController;
- (void)refreshFromController;
@end

@implementation SettingsWindowController {
    PetController *_petController;
    NSSlider *_scaleSlider;
    NSTextField *_scaleValueLabel;
    NSSlider *_opacitySlider;
    NSTextField *_opacityValueLabel;
    NSButton *_alwaysOnTopButton;
    NSButton *_clickThroughButton;
    NSButton *_randomMovementButton;
    NSButton *_launchAtLoginButton;
}

- (instancetype)initWithPetController:(PetController *)petController {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 360)
                                                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"DesktopCatPet 设置";
    window.releasedWhenClosed = NO;

    self = [super initWithWindow:window];
    if (!self) { return nil; }

    _petController = petController;
    [self buildContent];
    [self refreshFromController];
    return self;
}

- (NSTextField *)labelWithText:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.font = [NSFont systemFontOfSize:13.0];
    return label;
}

- (void)buildContent {
    NSView *contentView = self.window.contentView;

    NSTextField *title = [self labelWithText:@"桌宠偏好设置" frame:NSMakeRect(24, 316, 220, 24)];
    title.font = [NSFont boldSystemFontOfSize:16.0];
    [contentView addSubview:title];

    [contentView addSubview:[self labelWithText:@"大小" frame:NSMakeRect(24, 268, 80, 22)]];
    _scaleSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(108, 266, 220, 24)];
    _scaleSlider.minValue = 0.2;
    _scaleSlider.maxValue = 1.2;
    _scaleSlider.target = self;
    _scaleSlider.action = @selector(scaleChanged:);
    [contentView addSubview:_scaleSlider];
    _scaleValueLabel = [self labelWithText:@"" frame:NSMakeRect(338, 268, 58, 22)];
    _scaleValueLabel.alignment = NSTextAlignmentRight;
    [contentView addSubview:_scaleValueLabel];

    [contentView addSubview:[self labelWithText:@"透明度" frame:NSMakeRect(24, 226, 80, 22)]];
    _opacitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(108, 224, 220, 24)];
    _opacitySlider.minValue = 0.2;
    _opacitySlider.maxValue = 1.0;
    _opacitySlider.target = self;
    _opacitySlider.action = @selector(opacityChanged:);
    [contentView addSubview:_opacitySlider];
    _opacityValueLabel = [self labelWithText:@"" frame:NSMakeRect(338, 226, 58, 22)];
    _opacityValueLabel.alignment = NSTextAlignmentRight;
    [contentView addSubview:_opacityValueLabel];

    _alwaysOnTopButton = [self checkboxWithTitle:@"始终置顶" frame:NSMakeRect(24, 180, 180, 22) action:@selector(alwaysOnTopChanged:)];
    _clickThroughButton = [self checkboxWithTitle:@"鼠标穿透" frame:NSMakeRect(224, 180, 180, 22) action:@selector(clickThroughChanged:)];
    _randomMovementButton = [self checkboxWithTitle:@"自动散步和睡觉" frame:NSMakeRect(24, 144, 180, 22) action:@selector(randomMovementChanged:)];
    _launchAtLoginButton = [self checkboxWithTitle:@"开机启动" frame:NSMakeRect(224, 144, 180, 22) action:@selector(launchAtLoginChanged:)];

    [contentView addSubview:_alwaysOnTopButton];
    [contentView addSubview:_clickThroughButton];
    [contentView addSubview:_randomMovementButton];
    [contentView addSubview:_launchAtLoginButton];

    NSTextField *hint = [self labelWithText:@"开启鼠标穿透后，桌宠本体不再响应点击；可从菜单栏 Cat 关闭。" frame:NSMakeRect(24, 104, 372, 36)];
    hint.textColor = NSColor.secondaryLabelColor;
    hint.font = [NSFont systemFontOfSize:12.0];
    hint.lineBreakMode = NSLineBreakByWordWrapping;
    [contentView addSubview:hint];

    NSButton *resetButton = [[NSButton alloc] initWithFrame:NSMakeRect(24, 42, 110, 30)];
    resetButton.title = @"重置位置";
    resetButton.bezelStyle = NSBezelStyleRounded;
    resetButton.target = self;
    resetButton.action = @selector(resetPosition:);
    [contentView addSubview:resetButton];

    NSButton *sleepButton = [[NSButton alloc] initWithFrame:NSMakeRect(148, 42, 80, 30)];
    sleepButton.title = @"睡觉";
    sleepButton.bezelStyle = NSBezelStyleRounded;
    sleepButton.target = self;
    sleepButton.action = @selector(sleep:);
    [contentView addSubview:sleepButton];

    NSButton *wakeButton = [[NSButton alloc] initWithFrame:NSMakeRect(238, 42, 80, 30)];
    wakeButton.title = @"醒来";
    wakeButton.bezelStyle = NSBezelStyleRounded;
    wakeButton.target = self;
    wakeButton.action = @selector(wake:);
    [contentView addSubview:wakeButton];
}

- (NSButton *)checkboxWithTitle:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.title = title;
    button.buttonType = NSButtonTypeSwitch;
    button.target = self;
    button.action = action;
    return button;
}

- (void)refreshFromController {
    _scaleSlider.doubleValue = _petController.currentScale;
    _scaleValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", _petController.currentScale * 100.0];
    _opacitySlider.doubleValue = _petController.currentOpacity;
    _opacityValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", _petController.currentOpacity * 100.0];
    _alwaysOnTopButton.state = _petController.alwaysOnTopEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _clickThroughButton.state = _petController.clickThroughEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _randomMovementButton.state = _petController.randomMovementEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _launchAtLoginButton.state = _petController.launchAtLoginEnabled ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)scaleChanged:(id)sender {
    (void)sender;
    [_petController setScale:_scaleSlider.doubleValue];
    _scaleValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", _scaleSlider.doubleValue * 100.0];
}

- (void)opacityChanged:(id)sender {
    (void)sender;
    [_petController setOpacity:_opacitySlider.doubleValue];
    _opacityValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", _opacitySlider.doubleValue * 100.0];
}

- (void)alwaysOnTopChanged:(NSButton *)sender {
    [_petController setAlwaysOnTop:sender.state == NSControlStateValueOn];
}

- (void)clickThroughChanged:(NSButton *)sender {
    [_petController setClickThrough:sender.state == NSControlStateValueOn];
}

- (void)randomMovementChanged:(NSButton *)sender {
    [_petController setRandomMovementEnabled:sender.state == NSControlStateValueOn];
}

- (void)launchAtLoginChanged:(NSButton *)sender {
    [_petController setLaunchAtLoginEnabled:sender.state == NSControlStateValueOn];
    sender.state = _petController.launchAtLoginEnabled ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)resetPosition:(id)sender {
    (void)sender;
    [_petController resetPosition];
}

- (void)sleep:(id)sender {
    (void)sender;
    [_petController enterSleep];
}

- (void)wake:(id)sender {
    (void)sender;
    [_petController wakeUp];
}

@end

@interface MenuBarController : NSObject <NSMenuDelegate>
- (instancetype)initWithPetController:(PetController *)petController;
@end

@implementation MenuBarController {
    NSStatusItem *_statusItem;
    PetController *_petController;
    SettingsWindowController *_settingsWindowController;
    NSMenuItem *_topItem;
    NSMenuItem *_clickThroughItem;
    NSMenuItem *_randomMovementItem;
    NSMenuItem *_launchAtLoginItem;
    NSArray<NSMenuItem *> *_behaviorItems;
}

- (instancetype)initWithPetController:(PetController *)petController {
    self = [super init];
    if (!self) { return nil; }

    _petController = petController;
    _settingsWindowController = [[SettingsWindowController alloc] initWithPetController:petController];
    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.title = @"Cat";
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(openSettings:) name:PetOpenSettingsNotificationName object:nil];
    [self configureMenu];
    return self;
}

- (void)configureMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"显示 / 隐藏" action:@selector(toggleVisibility:) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"睡觉" action:@selector(sleep:) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"醒来" action:@selector(wake:) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"状态" action:@selector(showStatus:) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"设置..." action:@selector(openSettings:) keyEquivalent:@","]];
    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *scaleRoot = [[NSMenuItem alloc] initWithTitle:@"大小" action:nil keyEquivalent:@""];
    NSMenu *scaleMenu = [[NSMenu alloc] init];
    NSArray *scales = @[
        @{@"title": @"小", @"value": @0.32},
        @{@"title": @"中", @"value": @0.43},
        @{@"title": @"大", @"value": @0.56},
        @{@"title": @"超大", @"value": @0.72}
    ];
    for (NSDictionary *item in scales) {
        NSMenuItem *scaleItem = [[NSMenuItem alloc] initWithTitle:item[@"title"] action:@selector(scale:) keyEquivalent:@""];
        scaleItem.representedObject = item[@"value"];
        scaleItem.target = self;
        [scaleMenu addItem:scaleItem];
    }
    [menu setSubmenu:scaleMenu forItem:scaleRoot];
    [menu addItem:scaleRoot];

    NSMenuItem *opacityRoot = [[NSMenuItem alloc] initWithTitle:@"透明度" action:nil keyEquivalent:@""];
    NSMenu *opacityMenu = [[NSMenu alloc] init];
    NSArray *opacities = @[
        @{@"title": @"100%", @"value": @1.0},
        @{@"title": @"85%", @"value": @0.85},
        @{@"title": @"70%", @"value": @0.70},
        @{@"title": @"50%", @"value": @0.50}
    ];
    for (NSDictionary *item in opacities) {
        NSMenuItem *opacityItem = [[NSMenuItem alloc] initWithTitle:item[@"title"] action:@selector(opacity:) keyEquivalent:@""];
        opacityItem.representedObject = item[@"value"];
        opacityItem.target = self;
        [opacityMenu addItem:opacityItem];
    }
    [menu setSubmenu:opacityMenu forItem:opacityRoot];
    [menu addItem:opacityRoot];

    NSMenuItem *behaviorRoot = [[NSMenuItem alloc] initWithTitle:@"行为模式" action:nil keyEquivalent:@""];
    NSMenu *behaviorMenu = [[NSMenu alloc] init];
    NSArray *behaviors = @[
        @{@"title": @"自动", @"value": @"auto"},
        @{@"title": @"坐在 Dock 上", @"value": @"dock"},
        @{@"title": @"贴边走", @"value": @"edge"},
        @{@"title": @"跟随鼠标", @"value": @"follow"},
        @{@"title": @"看向鼠标", @"value": @"look"}
    ];
    NSMutableArray<NSMenuItem *> *behaviorItems = [NSMutableArray array];
    for (NSDictionary *item in behaviors) {
        NSMenuItem *behaviorItem = [[NSMenuItem alloc] initWithTitle:item[@"title"] action:@selector(behavior:) keyEquivalent:@""];
        behaviorItem.representedObject = item[@"value"];
        behaviorItem.target = self;
        [behaviorMenu addItem:behaviorItem];
        [behaviorItems addObject:behaviorItem];
    }
    _behaviorItems = behaviorItems;
    [menu setSubmenu:behaviorMenu forItem:behaviorRoot];
    [menu addItem:behaviorRoot];

    _topItem = [[NSMenuItem alloc] initWithTitle:@"始终置顶" action:@selector(toggleAlwaysOnTop:) keyEquivalent:@""];
    [menu addItem:_topItem];
    _clickThroughItem = [[NSMenuItem alloc] initWithTitle:@"鼠标穿透" action:@selector(toggleClickThrough:) keyEquivalent:@""];
    [menu addItem:_clickThroughItem];
    _randomMovementItem = [[NSMenuItem alloc] initWithTitle:@"自动散步和睡觉" action:@selector(toggleRandomMovement:) keyEquivalent:@""];
    [menu addItem:_randomMovementItem];
    _launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"开机启动" action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
    [menu addItem:_launchAtLoginItem];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"重置位置" action:@selector(resetPosition:) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"退出" action:@selector(quit:) keyEquivalent:@"q"]];

    for (NSMenuItem *item in menu.itemArray) {
        item.target = self;
    }
    _statusItem.menu = menu;
}

- (void)menuWillOpen:(NSMenu *)menu {
    (void)menu;
    [self refreshMenuState];
}

- (void)refreshMenuState {
    _topItem.state = _petController.alwaysOnTopEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _clickThroughItem.state = _petController.clickThroughEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _randomMovementItem.state = _petController.randomMovementEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _launchAtLoginItem.state = _petController.launchAtLoginEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    NSString *behaviorMode = _petController.behaviorMode;
    for (NSMenuItem *item in _behaviorItems) {
        item.state = [item.representedObject isEqualToString:behaviorMode] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    [_settingsWindowController refreshFromController];
}

- (void)toggleVisibility:(id)sender {
    [_petController toggleVisibility];
}

- (void)sleep:(id)sender {
    [_petController enterSleep];
}

- (void)wake:(id)sender {
    [_petController wakeUp];
}

- (void)showStatus:(id)sender {
    (void)sender;
    [_petController showStatusBubble];
}

- (void)scale:(NSMenuItem *)sender {
    [_petController setScale:[sender.representedObject doubleValue]];
    [self refreshMenuState];
}

- (void)opacity:(NSMenuItem *)sender {
    [_petController setOpacity:[sender.representedObject doubleValue]];
    [self refreshMenuState];
}

- (void)behavior:(NSMenuItem *)sender {
    [_petController setBehaviorMode:sender.representedObject];
    [self refreshMenuState];
}

- (void)toggleAlwaysOnTop:(NSMenuItem *)sender {
    BOOL enabled = sender.state != NSControlStateValueOn;
    sender.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    [_petController setAlwaysOnTop:enabled];
    [self refreshMenuState];
}

- (void)toggleClickThrough:(NSMenuItem *)sender {
    BOOL enabled = sender.state != NSControlStateValueOn;
    [_petController setClickThrough:enabled];
    [self refreshMenuState];
}

- (void)toggleRandomMovement:(NSMenuItem *)sender {
    BOOL enabled = sender.state != NSControlStateValueOn;
    [_petController setRandomMovementEnabled:enabled];
    [self refreshMenuState];
}

- (void)toggleLaunchAtLogin:(NSMenuItem *)sender {
    BOOL enabled = sender.state != NSControlStateValueOn;
    [_petController setLaunchAtLoginEnabled:enabled];
    [self refreshMenuState];
}

- (void)resetPosition:(id)sender {
    (void)sender;
    [_petController resetPosition];
}

- (void)openSettings:(id)sender {
    (void)sender;
    [_settingsWindowController refreshFromController];
    [_settingsWindowController showWindow:nil];
    [_settingsWindowController.window center];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)quit:(id)sender {
    [_petController savePosition];
    [NSApp terminate:nil];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate {
    PetController *_petController;
    MenuBarController *_menuBarController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    NSError *error = nil;
    NSString *resourcesPath = NSBundle.mainBundle.resourcePath;
    _petController = [[PetController alloc] initWithResourcesPath:resourcesPath error:&error];
    if (!_petController) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"桌宠启动失败";
        NSString *errorDescription = error.localizedDescription;
        alert.informativeText = errorDescription ? errorDescription : @"无法读取桌宠资源。";
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }

    _menuBarController = [[MenuBarController alloc] initWithPetController:_petController];
    [_petController show];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [_petController savePosition];
}

@end

int main(int argc, const char * argv[]) {
    for (int index = 1; index < argc; index += 1) {
        NSString *argument = [NSString stringWithUTF8String:argv[index]];
        if ([argument isEqualToString:@"--ui-test"]) {
            PetUITestMode = YES;
        } else if ([argument isEqualToString:@"--state-file"] && index + 1 < argc) {
            PetUITestStatePath = [NSString stringWithUTF8String:argv[++index]];
        } else if ([argument isEqualToString:@"--command-file"] && index + 1 < argc) {
            PetUITestCommandPath = [NSString stringWithUTF8String:argv[++index]];
        } else if ([argument isEqualToString:@"--initial-frame"] && index + 4 < argc) {
            CGFloat x = atof(argv[++index]);
            CGFloat y = atof(argv[++index]);
            CGFloat w = atof(argv[++index]);
            CGFloat h = atof(argv[++index]);
            PetUITestInitialFrame = NSMakeRect(x, y, w, h);
        }
    }

    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}

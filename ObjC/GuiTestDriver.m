#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

static CGPoint EventPointFromAppKitPoint(CGFloat x, CGFloat y) {
    NSRect screenFrame = NSScreen.mainScreen.frame;
    return CGPointMake(x, NSMaxY(screenFrame) - y);
}

static void MoveMouse(CGFloat x, CGFloat y) {
    CGPoint point = EventPointFromAppKitPoint(x, y);
    CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, point, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

static void MouseButton(CGEventType type, CGFloat x, CGFloat y) {
    CGPoint point = EventPointFromAppKitPoint(x, y);
    CGEventRef event = CGEventCreateMouseEvent(NULL, type, point, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

static void Click(CGFloat x, CGFloat y) {
    MoveMouse(x, y);
    usleep(120000);
    MouseButton(kCGEventLeftMouseDown, x, y);
    usleep(120000);
    MouseButton(kCGEventLeftMouseUp, x, y);
}

static void Drag(CGFloat fromX, CGFloat fromY, CGFloat toX, CGFloat toY) {
    MoveMouse(fromX, fromY);
    usleep(120000);
    MouseButton(kCGEventLeftMouseDown, fromX, fromY);
    usleep(120000);

    int steps = 24;
    for (int index = 1; index <= steps; index += 1) {
        CGFloat progress = (CGFloat)index / (CGFloat)steps;
        CGFloat x = fromX + (toX - fromX) * progress;
        CGFloat y = fromY + (toY - fromY) * progress;
        CGPoint point = EventPointFromAppKitPoint(x, y);
        CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDragged, point, kCGMouseButtonLeft);
        CGEventPost(kCGHIDEventTap, event);
        CFRelease(event);
        usleep(18000);
    }

    MouseButton(kCGEventLeftMouseUp, toX, toY);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: GuiTestDriver click x y | drag fromX fromY toX toY\n");
            return 2;
        }

        NSString *command = [NSString stringWithUTF8String:argv[1]];
        if ([command isEqualToString:@"click"] && argc == 4) {
            Click(atof(argv[2]), atof(argv[3]));
            return 0;
        }

        if ([command isEqualToString:@"drag"] && argc == 6) {
            Drag(atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]));
            return 0;
        }

        fprintf(stderr, "invalid arguments\n");
        return 2;
    }
}

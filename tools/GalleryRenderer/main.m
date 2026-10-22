// Visor temporal: carga las capas CAML del wallpaper con Core Animation y recorre los estados.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@interface CAPackage : NSObject
+ (instancetype)packageWithContentsOfURL:(NSURL *)url type:(NSString *)type options:(NSDictionary *)opts error:(NSError **)err;
@property (readonly) CALayer *rootLayer;
@property (readonly, getter=isGeometryFlipped) BOOL geometryFlipped;
@end
@interface CAStateController : NSObject
- (instancetype)initWithLayer:(CALayer *)layer;
- (void)setState:(id)state ofLayer:(CALayer *)layer transitionSpeed:(float)speed;
@end
@interface CALayer (PrivateStates)
- (id)stateWithName:(NSString *)name;
@end

@interface VC : UIViewController
@property NSString *wallpaperDirectory, *outputPath, *outputVideo;
@property NSMutableArray *roots, *controllers;
@property UILabel *clock, *date, *stateLabel;
@property UIView *dim;
@property AVAssetWriter *writer;
@property AVAssetWriterInput *videoInput;
@property AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property NSTimer *captureTimer;
@property UIGraphicsImageRenderer *frameRenderer;
@property CFTimeInterval firstTimestamp;
@property NSString *videoPath;
@property NSInteger frameNumber;
@property CGSize exportSize;
@property NSMutableArray<NSNumber *> *pausedTimes;
@property BOOL review;
@property CADisplayLink *reviewLink;
@property CFTimeInterval reviewStart;
@property NSInteger reviewStepIndex;
@property CGAffineTransform clockStretch;
@end

@implementation VC
- (CALayer *)load:(NSString *)suffix {
    NSString *dir = self.wallpaperDirectory ?: NSProcessInfo.processInfo.environment[@"WALL_DIR"];
    for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil]) {
        if ([f hasSuffix:suffix]) {
            NSError *err = nil;
            CAPackage *p = [CAPackage packageWithContentsOfURL:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:f]]
                                                          type:@"com.apple.coreanimation-bundle" options:@{} error:&err];
            if (!p) NSLog(@"WALL error %@ %@", f, err);
            // UIKit is top-left. Honor the package coordinate convention instead
            // of silently interpreting every package as UIKit coordinates.
            p.rootLayer.geometryFlipped = p.geometryFlipped;
            NSLog(@"WALL coordinate metadata geometryFlipped=%d", p.geometryFlipped);
            return p.rootLayer;
        }
    }
    return nil;
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.roots = [NSMutableArray new]; self.controllers = [NSMutableArray new];
    CGSize s = self.view.bounds.size;
    CGFloat k = s.width / 390.0;
    CALayer *bg = [self load:@"_Background-390w-844h@3x~iphone.ca"];
    if (!bg) bg = [self load:@"wallpaper.ca"];
    CALayer *fg = [self load:@"_Foreground-390w-844h@3x~iphone.ca"];
    CALayer *fl = [self load:@"_Floating-390w-844h@3x~iphone.ca"];
    NSLog(@"WALL loaded bg=%@ fl=%@", bg, fl);
    UIView *host = [[UIView alloc] initWithFrame:self.view.bounds]; [self.view addSubview:host];
    for (CALayer *l in @[bg ?: [CALayer layer]]) { l.position = CGPointMake(s.width / 2, s.height / 2); l.transform = CATransform3DMakeScale(k, k, 1); [host.layer addSublayer:l]; }
    if (fg) { fg.position = CGPointMake(s.width / 2, s.height / 2); fg.transform = CATransform3DMakeScale(k, k, 1); [host.layer addSublayer:fg]; }
    self.date = [[UILabel alloc] initWithFrame:CGRectMake(0, 70 * k, s.width, 26)];
    self.date.text = @"viernes, 16 de octubre"; self.date.textAlignment = NSTextAlignmentCenter;
    self.date.font = [UIFont systemFontOfSize:21 weight:UIFontWeightSemibold]; self.date.textColor = [UIColor colorWithWhite:1 alpha:0.9];
    self.clock = [[UILabel alloc] initWithFrame:CGRectMake(0, 92 * k, s.width, 110)];
    self.clock.text = @"9:41"; self.clock.textAlignment = NSTextAlignmentCenter;
    UIFontDescriptor *d = [[UIFont systemFontOfSize:104 weight:UIFontWeightBold].fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    self.clock.font = [UIFont fontWithDescriptor:d size:104]; self.clock.textColor = UIColor.whiteColor;
    [host addSubview:self.date]; [host addSubview:self.clock];
    UIView *top = [[UIView alloc] initWithFrame:self.view.bounds]; top.userInteractionEnabled = NO; [host addSubview:top];
    if (fl) { fl.position = CGPointMake(s.width / 2, s.height / 2); fl.transform = CATransform3DMakeScale(k, k, 1); [top.layer addSublayer:fl]; }
    self.dim = [[UIView alloc] initWithFrame:self.view.bounds]; self.dim.backgroundColor = UIColor.blackColor; self.dim.alpha = 0; self.dim.userInteractionEnabled = NO;
    [host addSubview:self.dim];
    self.stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, s.height - 44, s.width - 24, 24)];
    self.stateLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium]; self.stateLabel.textColor = UIColor.whiteColor;
    self.stateLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45]; [self.view addSubview:self.stateLabel];
    for (id candidate in @[bg ?: NSNull.null, fg ?: NSNull.null, fl ?: NSNull.null]) {
        if (candidate == NSNull.null) continue;
        CALayer *r = candidate;
        [self.roots addObject:r]; [self.controllers addObject:[[CAStateController alloc] initWithLayer:r]];
    }
    [self go:@"Locked" animated:NO];
    if ([NSProcessInfo.processInfo.environment[@"WALL_CLEAN"] isEqualToString:@"1"]) {
        self.clock.hidden = YES; self.date.hidden = YES; self.stateLabel.hidden = YES;
        NSString *output = self.outputPath ?: NSProcessInfo.processInfo.environment[@"WALL_OUTPUT"];
        if (output) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:self.view.bounds];
            UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];
            }];
            [UIImageJPEGRepresentation(image, 0.94) writeToFile:output atomically:YES];
            if ([NSProcessInfo.processInfo.environment[@"WALL_STILLS_ONLY"] isEqualToString:@"1"]) {
                [@"complete" writeToFile:[output stringByAppendingString:@".done"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ [NSNotificationCenter.defaultCenter postNotificationName:@"CoconutRenderComplete" object:nil]; });
                return;
            }
            NSString *video = self.outputVideo ?: NSProcessInfo.processInfo.environment[@"WALL_VIDEO"];
            if (video) [self beginVideo:video];
        });
    }
    if ([NSProcessInfo.processInfo.environment[@"WALL_REVIEW"] isEqualToString:@"1"]) {
        // Review preview: what the wallpaper does on a real lock screen, exported on an exact
        // timeline (frame by frame), so a busy Mac or simulator can never make it stutter.
        self.review = YES;
        self.stateLabel.hidden = YES;
        [self styleClock26:s scale:k];
        if ([NSProcessInfo.processInfo.environment[@"WALL_REVIEW_LIVE"] isEqualToString:@"1"]) {
            // Live: the same timeline in real time, for a screen recording on an idle Mac (much faster than the exact export).
            self.reviewStart = CACurrentMediaTime() + 1.0;
            self.reviewLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(reviewTick)];
            [self.reviewLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
            return;
        }
        NSString *video = self.outputVideo ?: NSProcessInfo.processInfo.environment[@"WALL_VIDEO"];
        if (video) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self beginVideo:video]; });
        return;
    }
    if ([NSProcessInfo.processInfo.environment[@"WALL_STATIC"] isEqualToString:@"1"]) return;
    NSArray *script = @[@[@1.5, @"Sleep"], @[@4.0, @"Locked"], @[@8.0, @"Unlock"], @[@11.5, @"Locked"], @[@15.0, @"Sleep"], @[@17.5, @"Locked"]];
    for (NSArray *step in script) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([step[0] doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self go:step[1] animated:YES]; });
    }
}
/// iOS 26 lock screen clock: tall SF numerals (the stretched "adaptive" style) with a soft glass gradient.
- (void)styleClock26:(CGSize)s scale:(CGFloat)k {
    self.date.text = @"Wednesday, October 21";
    self.date.frame = CGRectMake(0, 62 * k, s.width, 26 * k);
    self.date.font = [UIFont systemFontOfSize:19 * k weight:UIFontWeightSemibold];
    self.date.textColor = [UIColor colorWithWhite:1 alpha:0.86];
    self.clock.font = [UIFont systemFontOfSize:96 * k weight:UIFontWeightSemibold];
    self.clock.frame = CGRectMake(0, 84 * k, s.width, 112 * k);
    UIGraphicsImageRenderer *g = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(4, 112 * k * 1.75)];
    UIImage *glass = [g imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(id)[UIColor colorWithWhite:1 alpha:0.97].CGColor, (id)[UIColor colorWithWhite:0.93 alpha:0.86].CGColor, (id)[UIColor colorWithWhite:1 alpha:0.78].CGColor];
        CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
        CGContextDrawLinearGradient(ctx.CGContext, gradient, CGPointZero, CGPointMake(0, 112 * k * 1.75), 0);
        CGGradientRelease(gradient); CGColorSpaceRelease(space);
    }];
    self.clock.textColor = [UIColor colorWithPatternImage:glass];
    self.clock.layer.shadowColor = UIColor.blackColor.CGColor;
    self.clock.layer.shadowOpacity = 0.18; self.clock.layer.shadowRadius = 10 * k; self.clock.layer.shadowOffset = CGSizeMake(0, 2 * k);
    self.clock.layer.anchorPoint = CGPointMake(0.5, 0);
    self.clock.layer.position = CGPointMake(s.width / 2, 84 * k);
    self.clockStretch = CGAffineTransformMakeScale(1, 1.75);
    self.clock.transform = self.clockStretch;
}
- (void)reviewTick {
    double t = CACurrentMediaTime() - self.reviewStart;
    if (t < 0) return;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    [self reviewAt:t];
    [CATransaction commit];
}
/// Review timeline: locked, unlock to home, lock again, unlock again, lock (24 s).
- (void)reviewAt:(double)t {
    NSArray *script = @[@[@5.0, @"Unlock"], @[@11.0, @"Locked"], @[@16.0, @"Unlock"], @[@21.0, @"Locked"]];
    while (self.reviewStepIndex < (NSInteger)script.count && t >= [script[self.reviewStepIndex][0] doubleValue]) {
        [self go:script[self.reviewStepIndex][1] animated:YES];
        self.reviewStepIndex += 1;
    }
    // Clock follows the same timeline: fades and lifts on unlock, returns on lock (0.5 s ease).
    double hidden = 0;
    for (NSArray *step in script) {
        double at = [step[0] doubleValue], p = MIN(1, MAX(0, (t - at) / 0.5));
        p = p * p * (3 - 2 * p);
        if (t >= at) hidden = [step[1] isEqualToString:@"Unlock"] ? p : 1 - p;
    }
    self.clock.alpha = 1 - hidden; self.date.alpha = 1 - hidden;
    self.clock.transform = CGAffineTransformConcat(self.clockStretch, CGAffineTransformMakeTranslation(0, -60 * hidden));
    self.date.transform = CGAffineTransformMakeTranslation(0, -60 * hidden);
}
- (void)beginVideo:(NSString *)path {
    self.videoPath = path;
    CGFloat exportWidth = [NSProcessInfo.processInfo.environment[@"WALL_EXPORT_WIDTH"] doubleValue];
    if (exportWidth < 390) exportWidth = 780;
    CGSize size = CGSizeMake(exportWidth, 2 * round(exportWidth * self.view.bounds.size.height / self.view.bounds.size.width / 2));
    self.exportSize = size;
    NSError *error = nil;
    self.writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path] fileType:AVFileTypeMPEG4 error:&error];
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:@{
        AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @(size.width), AVVideoHeightKey: @(size.height),
        AVVideoCompressionPropertiesKey: @{AVVideoAverageBitRateKey: @(3500000 * pow(exportWidth / 780.0, 2)), AVVideoMaxKeyFrameIntervalKey: @30, AVVideoExpectedSourceFrameRateKey: @30}
    }];
    self.videoInput.expectsMediaDataInRealTime = NO;
    self.adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:@{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (NSString *)kCVPixelBufferWidthKey: @(size.width), (NSString *)kCVPixelBufferHeightKey: @(size.height),
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES, (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    }];
    [self.writer addInput:self.videoInput];
    if (![self.writer startWriting]) { NSLog(@"Clean video writer failed %@", self.writer.error); return; }
    [self.writer startSessionAtSourceTime:kCMTimeZero];
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1; format.opaque = YES;
    self.frameRenderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    self.pausedTimes = [NSMutableArray new];
    for (CALayer *root in self.roots) {
        CFTimeInterval localTime = [root convertTime:CACurrentMediaTime() fromLayer:nil];
        root.speed = 0; root.timeOffset = localTime;
        [self.pausedTimes addObject:@(localTime)];
    }
    // Export uses an explicit timeline; do not throttle to an occluded simulator's display refresh.
    __weak VC *weakSelf = self;
    self.captureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelf captureFrame];
    }];
}
- (void)captureFrame {
    double elapsed = self.frameNumber / 30.0;
    double duration = [NSProcessInfo.processInfo.environment[@"WALL_SECONDS"] doubleValue];
    if (duration <= 0) duration = 4;
    if (elapsed >= duration) {
        [self.captureTimer invalidate]; self.captureTimer = nil;
        [self.writer endSessionAtSourceTime:CMTimeMake(self.frameNumber, 30)];
        [self.videoInput markAsFinished];
        [self.writer finishWritingWithCompletionHandler:^{
            if (self.writer.status == AVAssetWriterStatusCompleted) {
                [@"complete" writeToFile:[self.videoPath stringByAppendingString:@".done"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ [NSNotificationCenter.defaultCenter postNotificationName:@"CoconutRenderComplete" object:nil]; });
            } else NSLog(@"Clean video export failed %@", self.writer.error);
        }];
        return;
    }
    if (!self.videoInput.readyForMoreMediaData) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (self.review) [self reviewAt:elapsed];
    for (NSUInteger i = 0; i < self.roots.count; i++) {
        ((CALayer *)self.roots[i]).timeOffset = self.pausedTimes[i].doubleValue + elapsed;
    }
    [CATransaction commit];
    [CATransaction flush];
    CGSize size = self.exportSize;
    // UIKit's snapshot contains only our layered artwork. Hardware and system UI
    // are never part of this surface, unlike a simulator screen recording.
    UIImage *image = [self.frameRenderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextScaleCTM(ctx.CGContext, size.width / self.view.bounds.size.width, size.height / self.view.bounds.size.height);
        if ([NSProcessInfo.processInfo.environment[@"WALL_FAST"] isEqualToString:@"1"]) {
            [(self.view.layer.presentationLayer ?: self.view.layer) renderInContext:ctx.CGContext];
        } else {
            [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:NO];
        }
    }];
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferPoolCreatePixelBuffer(NULL, self.adaptor.pixelBufferPool, &buffer) != kCVReturnSuccess) return;
    CVPixelBufferLockBaseAddress(buffer, 0);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(buffer), CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 8, CVPixelBufferGetBytesPerRow(buffer), colorSpace, kCGImageAlphaNoneSkipFirst);
    CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), image.CGImage);
    [self.adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(self.frameNumber, 30)];
    CGContextRelease(ctx); CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(buffer, 0); CVPixelBufferRelease(buffer);
    self.frameNumber += 1;
}
- (void)go:(NSString *)name animated:(BOOL)animated {
    for (NSUInteger i = 0; i < self.roots.count; i++) {
        CALayer *r = self.roots[i];
        [self.controllers[i] setState:[r stateWithName:name] ofLayer:r transitionSpeed:animated ? 1.0 : 1000.0];
    }
    BOOL sleep = [name isEqualToString:@"Sleep"], unlock = [name isEqualToString:@"Unlock"];
    if (self.review) { NSLog(@"WALL state %@", name); return; }   // review: clock is driven by the exact timeline
    [UIView animateWithDuration:animated ? 0.6 : 0 animations:^{
        self.dim.alpha = sleep ? 0.55 : 0;
        self.clock.alpha = unlock ? 0 : 1; self.date.alpha = unlock ? 0 : 1;
        self.clock.transform = unlock ? CGAffineTransformMakeTranslation(0, -60) : CGAffineTransformIdentity;
        self.date.transform = self.clock.transform;
    }];
    self.stateLabel.text = [NSString stringWithFormat:@" estado: %@", name];
    NSLog(@"WALL state %@", name);
}
@end

@interface AD : UIResponder <UIApplicationDelegate>
@property UIWindow *window;
@property NSArray<NSDictionary *> *batch;
@property NSUInteger batchIndex;
@end
@implementation AD
- (void)nextRender {
    if (self.batchIndex >= self.batch.count) { self.window.rootViewController = [UIViewController new]; return; }
    NSDictionary *entry = self.batch[self.batchIndex++];
    VC *vc = [VC new];
    vc.wallpaperDirectory = entry[@"wallpaper"];
    vc.outputPath = entry[@"image"];
    vc.outputVideo = entry[@"video"];
    self.window.rootViewController = vc;
}
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    NSString *batchPath = NSProcessInfo.processInfo.environment[@"WALL_BATCH_JSON"];
    if (batchPath) {
        self.batch = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:batchPath] options:0 error:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(nextRender) name:@"CoconutRenderComplete" object:nil];
        [self nextRender];
    } else { self.window.rootViewController = [VC new]; }
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc, char *argv[]) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AD.class)); } }

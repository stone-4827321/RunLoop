////
////  FPSViewController.m
////  RunLoopApply
////
////  Created by stone on 2021/1/13.
////
//
//#import "FPSViewController.h"
//
//@interface FPSViewController ()
//{
//    CADisplayLink *_displayLink;
//}
//
//@end
//
//@implementation FPSViewController
//
//- (void)viewDidLoad {
//    [super viewDidLoad];
//    self.view.backgroundColor = [UIColor whiteColor];
////    [self setupDisplayLink];
//    [self registerObserver];
//}
//
//
//- (void)registerObserver {
//    CFRunLoopObserverRef _observer;  // 观察者
//    //__block CFRunLoopActivity _activity1;     // 状态
//    __block NSTimeInterval _afterWaitingTime;
//    __block NSTimeInterval _beforeWaitingTime;
//
//    _observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(),
//                                                  kCFRunLoopAllActivities,
//                                                  YES,
//                                                  0,
//                                                  ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
//       NSLog(@"activity %ld", activity);
//       if (activity == kCFRunLoopAfterWaiting) {
//           _afterWaitingTime = [[NSProcessInfo processInfo] systemUptime];
//       }
//       if (activity == kCFRunLoopBeforeWaiting) {
//           _beforeWaitingTime = [[NSProcessInfo processInfo] systemUptime];
//           NSLog(@"%f", _beforeWaitingTime - _afterWaitingTime);
//       }
//       //dispatch_semaphore_signal(_semaphore);
//   });
//    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
//}
//
//- (void)setupDisplayLink {
//    //创建CADisplayLink，并添加到当前run loop的NSRunLoopCommonModes
//    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(linkTicks:)];
//    _displayLink.preferredFramesPerSecond = 100;
//    NSLog(@"%ld", (long)_displayLink.preferredFramesPerSecond);
//
//    // 每当屏幕需要刷新的时候，runloop就会调用CADisplayLink绑定的target上的selector
//    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
//}
//
//CFTimeInterval _timestamp;
//CGFloat _scheduleTimes = 0;
//- (void)linkTicks:(CADisplayLink *)link {
//    // 屏幕刷新次数
//    _scheduleTimes ++;
//    if(_timestamp == 0) {
//        // 上一次就按屏幕刷新的时间
//        _timestamp = link.timestamp;
//    }
//    // 这一次屏幕刷新的时间和上一次屏幕刷新的时间差
//    CFTimeInterval timePassed = link.timestamp - _timestamp;
//    //NSLog(@"%f", timePassed);
//    if(timePassed >= 1.f) {
//        //fps
//        CGFloat fps = _scheduleTimes / timePassed;
//        NSLog(@"fps:%.1f, timePassed:%f\n", fps, timePassed);
//
//        //重置
//        _timestamp = link.timestamp;
//        _scheduleTimes = 0;
//    }
//}
//
//@end


//
//  WBMonitor.m
//  CrashProject
//
//  Created by mac on 2019/7/13.
//  Copyright © 2019年 Delpan. All rights reserved.
//

#import "FPSViewController.h"

#import <mach/mach.h>

static CFRunLoopActivity _MainRunLoopActivity = 0;
static u_int64_t _MainRunLoopFrameMark = 0;
static float _MainRunLoopMillisecondPerSecond = 1000.0;
static double _MainRunLoopBlanceMillisecondPerFrame = 16.666666;

static mach_timebase_info_data_t _MainRunLoopFrameTimeBase(void) {
    static mach_timebase_info_data_t *timebase = 0;
    if (!timebase) {
        timebase = malloc(sizeof(mach_timebase_info_data_t));
        mach_timebase_info(timebase);
    }
    return *timebase;
}


static void _MainRunLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    _MainRunLoopActivity = activity;
//    NSLog(@"activity = %ld", activity);
    
    if (_MainRunLoopActivity == kCFRunLoopBeforeWaiting ||
        _MainRunLoopActivity == kCFRunLoopAfterWaiting) {
        if ((activity == kCFRunLoopAfterWaiting) || (_MainRunLoopFrameMark == 0)){
            _MainRunLoopFrameMark = mach_absolute_time();
        }
        else {
            mach_timebase_info_data_t timebase = _MainRunLoopFrameTimeBase();
            u_int64_t check = mach_absolute_time();
                        
            u_int64_t sum = (check - _MainRunLoopFrameMark) * (double)timebase.numer / (double)timebase.denom / 1e6;
            _MainRunLoopFrameMark = check;
            if (sum > _MainRunLoopBlanceMillisecondPerFrame) {
                NSInteger blanceFramePerSecond = (NSInteger)(_MainRunLoopMillisecondPerSecond - sum);
                _MainRunLoopMillisecondPerSecond = MAX(blanceFramePerSecond, 0);
                NSLog(@"sum: %lld", sum);
                NSLog(@"_MainRunLoopMillisecondPerSecond = %ld", (long)_MainRunLoopMillisecondPerSecond);
            }
        }
    }
}

@interface WBMonitor () {
    NSRunLoop *_monitorRunLoop;
    NSInteger _count;
    BOOL _checked;
    NSInteger _frameCount;
    NSString *_dumpCatonString;
    dispatch_source_t _gcdTimer;
    NSTimer *_monitorTimer;
}

@end

@implementation WBMonitor

#pragma mark -------------------------- Public Methods

- (void)startMonitor {
    if (!_monitorRunLoop) {
        CFRunLoopObserverContext context = { 0, nil, NULL, NULL };
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                                kCFRunLoopAllActivities,
                                                                YES,
                                                                0,
                                                                &_MainRunLoopObserverCallBack,
                                                                &context);
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
        CFRelease(observer);
        [self startFpsTimer];
        [NSThread detachNewThreadSelector:@selector(monitorThreadStart) toTarget:self withObject:nil];
    }
}

- (void)stopMonitor {
    [self stopFpsTimer];
    [self stopMonitorTimer];
    CFRunLoopStop(_monitorRunLoop.getCFRunLoop);
    _monitorRunLoop = nil;
}




#pragma mark -------------------------- Response Event
- (void)timerAction:(NSTimer *)timer {
    if (_MainRunLoopActivity != kCFRunLoopBeforeWaiting) {
        if (!_checked){
            _checked = YES;
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
                self->_checked = NO;
                self->_count = 0;
            });
        }
        else {
            ++_count;
            
            if (_count == 4) {
                //_dumpCatonString = [BSBacktraceLogger bs_backtraceOfMainThread];
            }
            
            if (_count > 5) {
                _count = 0;
                NSLog(@"卡住啦");
            }
        }
    }
    else{
        _count = 0;
    }
}


#pragma mark -------------------------- Private Methods

- (void)monitorThreadStart {
    _monitorTimer = [NSTimer timerWithTimeInterval:1 / 10.f
                                             target:self
                                           selector:@selector(timerAction:)
                                           userInfo:nil
                                            repeats:YES];
    
    _monitorRunLoop = [NSRunLoop currentRunLoop];
    [_monitorRunLoop addTimer:_monitorTimer forMode:NSRunLoopCommonModes];
    
    CFRunLoopRun();
}

- (void)startFpsTimer {
    
    _gcdTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    
    dispatch_source_set_timer(_gcdTimer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(_gcdTimer, ^{
        NSInteger fps = (NSInteger)(_MainRunLoopMillisecondPerSecond/_MainRunLoopBlanceMillisecondPerFrame);
        NSLog(@"~~~~~~~~~~~%ld", fps);
        if (self.fpsBlock) {
            self.fpsBlock(fps);
        }
        _MainRunLoopMillisecondPerSecond = 1000.0;
    });
    dispatch_resume(_gcdTimer);
}


- (void)stopFpsTimer {
    if (_gcdTimer) {
        dispatch_cancel(_gcdTimer);
        _gcdTimer = nil;
    }
}

- (void)stopMonitorTimer {
    if (_monitorTimer) {
        [_monitorTimer invalidate];
        _monitorTimer = nil;
    }
}
@end

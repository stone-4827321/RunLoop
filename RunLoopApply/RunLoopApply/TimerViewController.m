//
//  TimerViewController.m
//  RunLoopApply
//
//  Created by stone on 2021/1/12.
//

#import "TimerViewController.h"

@interface STTimer : NSTimer

@end

@implementation STTimer


@end

@interface TimerViewController () {
    NSTimer *_timer1;
    NSTimer *_timer2;
}

@end

@implementation TimerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIScrollView *view = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    view.backgroundColor = [UIColor whiteColor];
    view.contentSize = CGSizeMake(CGRectGetWidth(self.view.bounds) * 2, CGRectGetHeight(self.view.bounds) * 2);
    [self.view addSubview:view];
    
    NSTimer *timer1 = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(timerAction1) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer1 forMode:NSDefaultRunLoopMode];
    _timer1 = timer1;
    
    NSTimer *timer2 = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(timerAction2) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer2 forMode:NSRunLoopCommonModes];
    _timer2 = timer2;

}

- (void)timerAction1 {
    //NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSLog(@"timer1 call");
}

- (void)timerAction2 {
    //NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSLog(@"timer2 call");
}

@end

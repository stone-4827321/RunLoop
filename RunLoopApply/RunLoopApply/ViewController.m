//
//  ViewController.m
//  RunLoopApply
//
//  Created by stone on 2021/1/12.
//

#import "ViewController.h"
#import "KeepLiveThreadViewController.h"
#import "TimerViewController.h"
#import "WatchdogViewController.h"
#import "FPSViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
}

// 线程保活
- (IBAction)keepLiveThread:(id)sender {
    KeepLiveThreadViewController *vc = [[KeepLiveThreadViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

// NSTimer
- (IBAction)timer:(id)sender {
    TimerViewController *vc = [[TimerViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

// 卡顿监控
- (IBAction)watchdog:(id)sender {
    WatchdogViewController *vc = [[WatchdogViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

WBMonitor *o;
- (IBAction)fps:(id)sender {
    //FPSViewController *vc = [[FPSViewController alloc] init];
    //[self presentViewController:vc animated:YES completion:nil];
    
    o = [[WBMonitor alloc] init];
    [o startMonitor];
}

@end

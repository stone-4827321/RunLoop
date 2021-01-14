//
//  WatchdogViewController.m
//  RunLoopApply
//
//  Created by stone on 2021/1/12.
//

#import "WatchdogViewController.h"

@interface WatchdogViewController () <UITableViewDelegate, UITableViewDataSource>
{
    NSTimer *_timer;
    CADisplayLink *_displayLink;
}

@end

@implementation WatchdogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self registerObserver];

    CGRect rect = self.view.bounds;
    rect.size.height = 100;
    UITableView *tableView = [[UITableView alloc] initWithFrame:rect];
    [self.view addSubview:tableView];
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    tableView.delegate = self;
    tableView.dataSource = self;
    
    rect.size = CGSizeMake(100, 50);
    rect.origin.x = CGRectGetWidth(self.view.bounds) / 2.0 - 50;
    rect.origin.y = 200;
    UIButton *button1 = [UIButton buttonWithType:UIButtonTypeSystem];
    [button1 addTarget:self action:@selector(timer) forControlEvents:UIControlEventTouchUpInside];
    button1.frame = rect;
    [button1 setTitle:@"timer" forState:UIControlStateNormal];
    [self.view addSubview:button1];
    
    rect.origin.y = 300;
    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeSystem];
    [button2 addTarget:self action:@selector(displayLink) forControlEvents:UIControlEventTouchUpInside];
    button2.frame = rect;
    [button2 setTitle:@"displayLink" forState:UIControlStateNormal];
    [self.view addSubview:button2];
    
    rect.origin.y = 400;
    UIButton *button3 = [UIButton buttonWithType:UIButtonTypeSystem];
    [button3 addTarget:self action:@selector(dispatch) forControlEvents:UIControlEventTouchUpInside];
    button3.frame = rect;
    [button3 setTitle:@"dispatch" forState:UIControlStateNormal];
    [self.view addSubview:button3];
    
    rect.origin.y = 500;
    UIButton *button4 = [UIButton buttonWithType:UIButtonTypeSystem];
    [button4 addTarget:self action:@selector(calculate) forControlEvents:UIControlEventTouchUpInside];
    button4.frame = rect;
    [button4 setTitle:@"calculate" forState:UIControlStateNormal];
    [self.view addSubview:button4];
}

#pragma mark - 事件

- (void)timer {
    NSTimer *timer = [NSTimer timerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        NSLog(@"timer call");
        sleep(1);
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    _timer = timer;
}

- (void)timerAction {
    NSLog(@"timer call");
    sleep(1);
}

- (void)displayLink {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(linkTicks:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)linkTicks:(CADisplayLink *)link {
    NSLog(@"displayLink call");
    sleep(1);
}



- (void)dispatch {
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (ino64_t)(2 * NSEC_PER_SEC));
    dispatch_after(time, dispatch_get_main_queue(), ^{
        NSLog(@"gcd");
        sleep(1);
    });
}

- (void)calculate {
    int a = 8;
    NSLog(@"调试：大量计算");
    for (long i = 0; i < 999999999; i++) {
        a = a + 1;
    }
    NSLog(@"调试：大量计算结束");
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = @"cell";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"点击");
    sleep(1);
}



- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"点击");
    sleep(1);
}

#pragma mark - Monitor

CFRunLoopObserverRef _observer;  // 观察者
dispatch_semaphore_t _semaphore; // 信号量
CFRunLoopActivity _activity;     // 状态
int _countTime = 0;

- (void)registerObserver {
   _observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(),
                                                  kCFRunLoopAllActivities,
                                                  YES,
                                                  0,
                                                  ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
       _activity = activity;
       NSLog(@"activity %ld", _activity);
       dispatch_semaphore_signal(_semaphore);
   });
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    
    _semaphore = dispatch_semaphore_create(0);
        
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES) {
            // 返回值：如果线程是唤醒的，则返回非0，否则返回0
            long semaphoreWait = dispatch_semaphore_wait(_semaphore, dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC));
            //NSLog(@"semaphoreWait %ld %lu", semaphoreWait, _activity);
            //信号量超时了 - 即 runloop 的状态长时间没有发生变更,长期处于某一个状态下
            if (semaphoreWait != 0) {
                // 如果 RunLoop 的线程，进入睡眠前方法的执行时间过长而导致无法进入睡眠(kCFRunLoopBeforeSources)，或者线程唤醒后接收消息时间过长(kCFRunLoopAfterWaiting)而无法进入下一步的话，就可以认为是线程受阻。
                //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够监测到是否卡顿
                if (_activity == kCFRunLoopBeforeSources || _activity == kCFRunLoopAfterWaiting) {
                    _countTime ++;
                    NSLog(@"!!!%d %lu",_countTime, _activity);
                    
//                    if (_countTime < 3){
//                        //NSLog(@"!!!%d %lu",_countTime, _activity);
//                        continue;
//                    }
//                    NSLog(@"卡顿了");
                }
            }
            _countTime = 0;
        }
    });
}




@end

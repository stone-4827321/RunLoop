//
//  KeepLiveThreadViewController.m
//  RunLoopApply
//
//  Created by stone on 2021/1/12.
//

#import "KeepLiveThreadViewController.h"

@interface KeepLiveThreadViewController ()
{
    NSThread *_thread1;
    NSThread *_thread2;
}
@end

@implementation KeepLiveThreadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    //[self noRunLoop];
    //[self addRunLoop];
    
    //[self runloop];
}

- (void)show1 {
    NSLog(@"noRunLoop show");
}

- (void)show2 {
    NSLog(@"addRunLoop show");
}

- (void)noRunLoop {
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(show1) object:nil];
    [thread start];
    _thread1 = thread;
}

- (void)addRunLoop {
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(runloop) object:nil];
    _thread2 = thread;
    [thread start];
}

- (void)runloop {
    NSLog(@"addRunLoop");
    @autoreleasepool {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop performBlock:^{
            NSLog(@"后执行 %@", [NSThread currentThread]);
        }];
        NSLog(@"先执行");
        [runLoop run];
    }
    NSLog(@"RunLoop 退出");
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self performSelector:@selector(show1) onThread:_thread1 withObject:nil waitUntilDone:NO];
    [self performSelector:@selector(show2) onThread:_thread2 withObject:nil waitUntilDone:NO];
}

@end

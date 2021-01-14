# 线程

- 一个线程一次只能执行一次任务，当任务执行完毕后，该线程就退出并被销毁。

  ```objective-c
  - (void)noRunLoop {
      NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(show) object:nil];
      [thread start];
      // 保存线程，防止函数执行完毕后线程被销毁
      _thread = thread;
  }
  
  - (void)show {
      NSLog(@"show");
  }
  
  - (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  	  // 不会触发show方法
      [self performSelector:@selector(show) onThread:_thread withObject:nil waitUntilDone:NO];
  }
  ```

- 如果让线程能随时处理事件但并不退出，通常的代码逻辑就是 **Event Loop** 模型：

  ```c++
  function loop() {
      initialize();
      do {
          message = get_next_message();
          process_message(message);
      } while (message != quit);
  }
  ```

- **RunLoop 就是一个事件处理的循环，用来不停地调度工作以及处理输入事件**：RunLoop 管理需要处理的事件和消息，并提供了一个入口函数来执行 Event Loop 模型的逻辑。线程执行了这个函数后，就会一直处于这个函数内部 "接收消息->处理->等待" 的循环中（**线程的任务一直没有执行完，所以线程一直不会销毁**），直到这个循环结束（比如传入 quit 的消息），函数返回。

  事件主要分为两大类： 

  - Input Source：异步事件，包括

    - Port：系统底层的 Port 事件，在应用层基本用不到；

    - Custom：用户手动创建的 Source；

    - performSelector： Cocoa 提供的 `performSelector` 系列方法；
  - Timer Source：同步事件，指定时器事件。

  ![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmltouhe9aj30dg071t91.jpg)

- **RunLoop 的机制保证线程持续运行，从而可以不断接收并处理外部传入的各种消息，同时，让线程在没有处理消息时休眠以避免资源占用，在有消息到来时立刻被唤醒。**

  > 程序启动后就会开启一个主线程，主线程对应的 RunLoop 会运行起来，从而保证主线程不会被销毁掉，也就保证了程序的持续运行，可以随时处理触发事件等，同时没有又不长期占用 CPU 资源。
  >
  > 如果使用简单的 while 循环，CPU 是一直在使用的。
  >
  > RunLoop 的核心就是一个 mach_msg() ，RunLoop 调用这个函数去接收消息，如果没有别人发送 port 消息过来，内核会将线程置于等待状态。

- **线程保活**：

  ```objective-c
  - (void)addRunLoop {
      // 创建时的selector参数进行执行RunLoop方法
      NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(runloop) object:nil];
      [thread start];
      _thread = thread;
  }
  
  - (void)runloop {
      NSLog(@"add RunLoop");
      @autoreleasepool {
          NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
          // 必须加点东西才能保证RunLoop跑起来
          [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
          [runLoop performBlock:^{
              NSLog(@"后执行");
          }];
          NSLog(@"先执行");
          [runLoop run];
      }
      NSLog(@"RunLoop 退出");
  }
  
  - (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  	  // 可以持续触发show方法
      [self performSelector:@selector(show) onThread:_thread withObject:nil waitUntilDone:NO];
  }
  ```

- **线程和 RunLoop 之间是一一对应的**，其关系是保存在一个全局的字典里。主线程的 RunLoop 会在应用启动的时候完成启动，其他线程的 RunLoop 是懒加载的，默认并不会创建，其创建是发生在第一次获取时，销毁是发生在线程结束时。

  > RunLoop 不允许主动创建，而是在获取时系统内部创建的。

# CFRunLoop 类

- 在 `CoreFoundation` 框架里关于 RunLoop 有5个类，它们之间的关系为：**一个 RunLoop 包含若干个 Mode，每个 Mode 又包含若干个 Source / Timer / Observer**。

  ![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmltpb2240j306u059dg8.jpg)

- `CFRunLoopRef`：RunLoop 对象。

- `CFRunLoopModeRef`：运行模式，一系列 Input Source、Timer Source 以及 Observer 的集合；系统默认注册以下五种模式：

  1. **`NSDefaultRunLoopMode`**：App 的默认 Mode，通常主线程是在这个 Mode 下运行；

  2. **`UITrackingRunLoopMode`** ：界面跟踪 Mode，用于追踪触摸滑动，保证界面滑动时不受其他 Mode 影响；

  3. `UIInitializationRunLoopMode`：在刚启动 App 时第进入的第一个 Mode，启动完成后就不再使用；

  4. `GSEventReceiveRunLoopMode`：接受系统事件的内部 Mode，通常用不到；

  5. `NSRunLoopCommonModes`：占位 Mode，并不是一种真正 Mode。

  每次 RunLoop 启动时，只能指定其中一个 Mode，这个 Mode 被称作 CurrentMode，如果需要切换 Mode，只能退出 Loop，再重新指定一个 Mode 进入，这样做主要是为了分隔开不同组的 Source/Timer/Observer，让其互不影响。

  只有存在于 CurrentMode 的 Item（Source/Timer/Observer） 才能被执行。每当 RunLoop 的内容发生变化时，加入到 `NSRunLoopCommonModes` 模式的 Item 会被同步到标记为 Common 的 Mode 中（ `NSDefaultRunLoopMode` 和 `UITrackingRunLoopMode` 具有 Common 标记）。所以，当 CurrentMode 为 Common  Mode 时，这些 Item也会被执行。

  > 以 `+scheduledTimerWithTimeInterval:` 的方式触发的timer，在滑动页面上的列表时，timer 会暂停回调， 为什么？
  >
  > 滑动 scrollView 时，主线程的 RunLoop 会切换到 `UITrackingRunLoopMode` ，只执行这个 Mode 下的任务，而 timer 是添加在 `NSDefaultRunLoopMode` 下的，所以不会执行。只有当 `UITrackingRunLoopMode `的任务执行完毕，RunLoop 切换到 `NSDefaultRunLoopMode `后，才会继续执行 timer。
  >
  > 将 timer 放到 `NSRunLoopCommonModes ` 中执行即可解决这一问题。
  >
  > `[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];`

- `CFRunLoopSourceRef`：对应 Input Source 异步事件。

    - Source0： 非基于Port的，用于用户主动触发的事件（点击按钮或屏幕）；
    - Source1： 基于Port的，通过内核和其他线程相互发送消息（与内核相关）。

    ```objective-c
    // 上下文
    CFRunLoopSourceContext source_context = {0,
                                             (__bridge void *)(self), //回调传递参数
                                             NULL, NULL, NULL, NULL, NULL,
                                             &runLoopSourceScheduleCallBack, //添加回调
                                             &runLoopSourceCancelCallBack, //移除回调
                                             &runLoopSourcePerformCallBack //触发回调
                                             };
    // 创建
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(
      CFAllocatorGetDefault(), //分配存储空间方式																							
      0, //优先级  																		
      &source_context);                                                
    
    // 添加到RunLoop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);
    CFRunLoopRun();
    
    // 可以用于线程保活
    ```

- `CFRunLoopTimerRef`：对应 Timer Source 同步事件。

    ```objective-c
    // 创建
    CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(
      CFAllocatorGetDefault(), //分配存储空间方式
      CFAbsoluteTimeGetCurrent(), //第一次触发时间
      kCFAbsoluteTimeIntervalSince1904, //重复触发间隔时间
      0, 0, //优先级
      ^(CFRunLoopTimerRef timer) { NSLog(@"Timer被触发回调"); });
    
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
    CFRelease(timer);
    CFRunLoopRun();
    
    // 可以用于线程保活
    ```

- `CFRunLoopObserverRef`：观察者，监听 RunLoop 在六个状态之间的改变：

    - `kCFRunLoopEntry = (1UL << 0)1`：即将进入 RunLoop；
    - `kCFRunLoopBeforeTimers = (1UL << 1)2` ：即将处理 Timer；
    - `kCFRunLoopBeforeSources = (1UL << 2)4`：即将处理 Source；
    - `kCFRunLoopBeforeWaiting = (1UL << 5)32`：即将进入休眠；
    - `kCFRunLoopAfterWaiting = (1UL << 6)64`：刚从休眠中唤醒；
    - `kCFRunLoopExit = (1UL << 7)128`：即将退出 RunLoop。

    ```objective-c
    // 参数1：分配存储空间方式，一般使用CFAllocatorGetDefault()
    // 参数2：需要监听的状态类型，kCFRunLoopAllActivities监听所有状态
    // 参数3：是否每次都需要监听
    // 参数4：优先级，一般传0，表示最先执行回调
    // 参数5：监听到状态改变之后的回调
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(),                                                                         kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) { NSLog(@"Observer被触发回调"); });
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    CFRelease(observer);
    CFRunLoopRun();
    
    // 不能用于线程保活
    ```

## 运行流程

- 根据苹果在文档里的说明，RunLoop 开启后就会进入一个循环： 



![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmm6xqe3zpj30v90u0gu7.jpg)

## 启动和退出

- 启动方式：

  - `- (void)run;` 
  - `- (void)runUntilDate:(NSDate *)limitDate;`  
  - `- (void)acceptInputForMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate;`
  - `- (void)runMode:(NSString *)mode beforeDate:(NSDate *)limitDate;`
  - `void CFRunLoopRun(void);`

- 退出方式：

  - 移除 source 或者 timer；

  - 设置超时时间；

  - `void CFRunLoopStop(CFRunLoopRef rl);`

- 总结

    - 使用 `run`  方法启动的 RunLoop 和 使用 `runUntilDate` 方法启动的 RunLoop 在超时时间到达之前，会通过重复调用 `runMode：beforeDate：` 来在 `NSDefaultRunLoopMode ` 模式中运行 RunLoop。退出方式一和三并不能有效的保证 RunLoop 退出，系统可以根据需要安装和删除其他输入源，以处理针对接收者线程的请求，而这些源可能会阻止运行循环退出。

    - 使用 `acceptInputForMode:beforeDate:` 启动的 RunLoop，只要接收到 source 并被处理或在超时时间到达之后，RunLoop 就会退出。在此之前使用退出方式一和三并不能有效的保证 RunLoop 退出。

      使用 `runMode:beforeDate:` 方法启动的 RunLoop 在超时时间到达之前，可以通过方式一移除 source 和方式三退出；此外，只要接收到 source 并被处理，RunLoop 也会退出。

    - 使用 `CFRunLoopRun()` 方式启动的 RunLoop 只能通过 `CFRunLoopStop()` 方式关闭；

- 当需要比较好地控制 RunLoop 的启动和退出时，建议使用 `runMode:beforeDate:` 方式启动，可以通过是否重复调用 `runMode:beforeDate:` 以达到自由控制 RunLoop 的关闭。

    ```objective-c
    static BOOL shouldKeepRunning = NO;
    
    // 启动RunLoop
    - (IBAction)customStart:(id)sender {
        shouldKeepRunning = YES;
        self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(customStart) object:nil] ;
        [self.thread start];
    }
    
    - (void)customStart {
        @autoreleasepool {
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    				
    				// 只要shouldKeepRunning为真，就不断重复调用
            while (shouldKeepRunning) {
                [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }
        }
        NSLog(@"退出");
    }
    
    // 退出RunLoop
    - (IBAction)customStop:(id)sender {
    		// 使不再循环
    		shouldKeepRunning = NO;
    		// 调用后立即退出RunLoop
        [self performSelector:@selector(customStop) onThread:self.thread withObject:nil waitUntilDone:NO];
    }
    
    - (void)customStop {
    		// 可以做一些退出处理
    }
    ```

# 应用

## autoreleasepool

- 在 MRC 环境下，需要手动管理内存，即对需要释放的对象调用 `release` 、`autorelease ` 等内存释放方法。在 ARC 环境中，为了替代开发人员手动管理内存，**自动释放池就是一种自动内存回收管理的机制：加入自动释放池的对象会被编译器在适当的位置插入 `release`、`autorelease` 等内存释放操作**。

  - 自动释放池以栈的形式实现：创建一个新的自动释放池时，它将被添加到栈顶。当一个对象收到 `autorelease` 消息时，它被添加到当前线程中处于栈顶的自动释放池，当自动释放池被回收时，它们从栈中被删除，并且会给池子里面所有的对象都会做一次 `release` 操作。
  - `release` 表示立即释放，`autorelease` 表示在下一轮的 RunLoop 中才被释放。

- **RunLoop 内部有一个自动释放池！RunLoop 开启时会自动创建一个自动释放池，RunLoop 休眠时会释放掉自动释放池中的东西，然后重新创建一个新的空的自动释放池。当 RunLoop 被唤醒重新开始跑圈时，Timer 和 Source 等新的事件就会放到新的自动释放池中，当 RunLoop 退出的时候也会被释放。**

- 应用启动后，主线程 RunLoop 会注册了两个 Observer：

  - 第一个 Observer 监听*即将进入*事件，其回调内调用 `_objc_autoreleasePoolPush()` 创建自动释放池。优先级最高，保证创建释放池发生在其他所有回调之前。

  - 第二个 Observer 监听两个事件， *即将进入休眠*会调用 `_objc_autoreleasePoolPop()` 和 ` _objc_autoreleasePoolPush() ` 释放旧的池并创建新池；*即将退出*调用 `_objc_autoreleasePoolPop()` 来释放自动释放池。其优先级最低，保证其释放发生在其他所有回调之后。

- 子线程的 RunLoop 不会自动启动，意味着不会自动创建自动释放池，子线程里面的对象也就没有池子可存放，在后面也无法自动释放，造成内存泄露。在多线程开发时，需要在线程调度方法中手动添加自动释放池。

- ```objective-c
  // 手动添加到释放池
  @autoreleasepool {
  }
  ```


- 使用容器的 block 版本的枚举器时，内部会自动添加一个 AutoreleasePool：

  ```objective-c
  [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      // 这里被一个局部@autoreleasepool包围着
  }];
  ```

> 黑幕背后的Autorelease https://blog.sunnyxx.com/2014/10/15/behind-autorelease

## NSTimer

- `NSTimer` 是` CFRunLoopTimerRef` 的上层实现，其触发正是基于 RunLoop 运行的，所以使用 `NSTimer` 之前必须注册到 RunLoop。

  ```objective-c
  //方式一：默认添加到NSDefaultRunLoopMode，只能主线程使用
  NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
  
  //方式二：需要主动添加RunLoop
  NSTimer *timer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
  // 主线程无需调用此句，如果是非主线程使用，必须显示启动RunLoop。
  [[NSRunLoop currentRunLoop] run]
  ```

- 当 `NSTimer` 注册到 RunLoop 后，RunLoop 会为其重复的时间点注册好事件。例如 10:00, 10:10, 10:20 这几个时间点。RunLoop 为了节省资源，并不会在非常准确的时间点回调。如果某个时间点被错过了，例如执行了一个很长的任务，则那个时间点的回调也会跳过去，不会延后执行。

- 循环引用问题：

  - 原因：
    - 当 `NSTimer` 注册到 RunLoop 后，`NSTimer` 就被 RunLoop 强引用 —> 链接1
    - 可以重复调用的 `NSTimer` 在创建方法中会强引用 Target 参数 —> 链接2
    - `NSTimer` 被强引用（一般就是 Target 参数），方便后续使用（此步不是必须设置，但后续为了操作 `NSTimer`，需要有一个强引起 ）—> 链接3

  ![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmltqhxwz7j315g0d20ug.jpg)

  ![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmltqsrs6sj314y0ektat.jpg)

  - 解决：
    - `[timer invalidate]` 将 timer 从 RunLoop 中移除，断开链接1和链接2。
    - `timer = nil` 主要为了安全起见，防止使用不在 RunLoop 中的 timer 出现问题。

  ![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmltr1xekdj317w0ccdh0.jpg)

  ![](https://tva1.sinaimg.cn/large/008eGmZEgy1gmltr9f7rpj31580asjsb.jpg)

- 当调用 `performSelector:onThread:xxx` 时，实际上其内部会创建一个 Timer 并添加到当前线程的 RunLoop 中，所以如果当前线程没有 RunLoop，则这个方法会失效。

- `CADisplayLink` 的使用：

  ```objective-c
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(linkTicks:)];
  [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  
  // 每当屏幕需要刷新的时候，RunLoop 就会调用 selector
  - (void)linkTicks:(CADisplayLink *)link {
  }
  ```

## 滑动与图片刷新

- 程序在子线程请求数据的同时滑动浏览当前页面，如果数据请求成功要切回主线程更新 UI，那么就会影响当前正在滑动的体验。

- 可以将更新 UI 事件放在主线程的 NSDefaultRunLoopMode 上执行即可，这样就会等用户不再滑动页面，主线程 RunLoop 由 UITrackingRunLoopMode 切换到 NSDefaultRunLoopMode 时再去更新 UI。

  ```objective-c
  [self performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
  ```

## 卡顿监控

- RunLoop 的处理方法主要是在 `kCFRunLoopBeforeSources` 和 `kCFRunLoopBeforeWaiting` 之间，以及`kCFRunLoopAfterWaiting` 之后。如果处理方法耗时太长，RunLoop 的状态就会一直保持为 `kCFRunLoopBeforeSources` 或 `kCFRunLoopAfterWaiting`。

- 开启一个线程实时计算这两个状态区域之间的耗时是否到达某个阀值，就可以判定出此时主线程卡顿。

  ```objective-c
  CFRunLoopObserverRef _observer;  // 观察者
  CFRunLoopActivity _activity;     // 状态
  dispatch_semaphore_t _semaphore; // 信号量
  
  // 观察状态变化
  _observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
      _activity = activity;
      dispatch_semaphore_signal(_semaphore);
  });
  CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
      
  _semaphore = dispatch_semaphore_create(0);
  
  // 开启子线程监控
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
      while (YES) {
          // 返回值：如果线程是唤醒的，则返回非0，否则返回0
          long semaphoreWait = dispatch_semaphore_wait(_semaphore, dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC)); // 80毫秒为卡顿阈值
              if (semaphoreWait != 0) {
                  if (_activity == kCFRunLoopBeforeSources || _activity == kCFRunLoopAfterWaiting) {
                      NSLog(@"卡顿了");
                  }
              }
      }
  });
  ```

  > 方案的缺陷和进一步优化：<https://blog.csdn.net/sinat_35969632/article/details/111351356>

 
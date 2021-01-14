//
//  FPSViewController.h
//  RunLoopApply
//
//  Created by stone on 2021/1/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

//@interface FPSViewController : UIViewController
//
//@end

typedef void (^WBMonitorBlock) (NSInteger fps);

@interface WBMonitor : NSObject

// fpsBlock
@property (nonatomic, copy) WBMonitorBlock fpsBlock;


/**
 开始 监听
 */
- (void)startMonitor;


/**
 停止 监听
 */
- (void)stopMonitor;
@end


NS_ASSUME_NONNULL_END

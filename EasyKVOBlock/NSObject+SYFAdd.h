//
//  NSObject+SYFAdd.h
//  EasyKVOBlock
//
//  Created by lemo on 2018/4/23.
//  Copyright © 2018年 孙亚锋. All rights reserved.
//

//typedef void(^resultBlock)(id _Nullable object,id _Nullable oldValue,id _Nullable newValue);



#import <Foundation/Foundation.h>
/**
如果需要每个属性或每个方法都去指定nonnull和nullable，是一件非常繁琐的事。苹果为了减轻我们的工作量，专门提供了两个宏：NS_ASSUME_NONNULL_BEGIN， NS_ASSUME_NONNULL_END。在这两个宏之间的代码，所有简单指针对象都被假定为nonnull，因此我们只需要去指定那些nullable的指针。
 */
NS_ASSUME_NONNULL_BEGIN
typedef void(^KVOBlock)(id object,id oldValue,id newValue);
typedef void(^NotificationBlock)(NSNotification *notification);
@interface NSObject (SYFAdd)
#pragma mark - KVO
/**
 * 通过Block方式注册一个KVO，通过该方式注册的KVO无需手动移除,其会在被监听对象销毁的时候自动移除。（下面的两个移除方法一般无需使用）
 *  @param keyPath 监听路径
 *  @param block   KVO回调block，obj为监听对象，oldVal为旧值，newVal为新值
 */
- (void)syf_addObserverBlockForKeyPath:(NSString *)keyPath block:(KVOBlock)block;
/**
 * 提前移除指定KeyPath下的BlockKVO(一般无需使用，如果需要提前注销KVO才需要)
 *
 *  @param keyPath 移除路径
 */
- (void)syf_removeObserverBlockForKeyPath:(NSString *)keyPath;
/**
 * 提前移除所有的KVOBlock(一般无需使用)
 */
- (void)syf_removeAllObserverBlocks;

#pragma mark - Notification
/**
 * 通过block方式注册通知，通过该方式注册的通知无需手动移除，同样会自动移除

 * @param name  通知名
 * @param block 通知的回调Block,notification为回调的通知对象
 */
- (void)syf_addNotificationForName:(NSString *)name block:(NotificationBlock)block;
/**
 * 提前移除某一个name的通知
 *
 * @param name 需要移除的通知名
 */
- (void)syf_removeNotificationForName:(NSString *)name;

/**
 * 提前移除所以通知
 */
- (void)syf_removeAllNotification;


/**
 * 发布一个通知
 * @param name 通知名
 * @param userInfo 数据字典  __nullable 表示对象可以是 NULL 或 nil
 */
- (void)syf_postNotificationWithName:(NSString *)name userInfo:(nullable NSDictionary *)userInfo;





@end

NS_ASSUME_NONNULL_END

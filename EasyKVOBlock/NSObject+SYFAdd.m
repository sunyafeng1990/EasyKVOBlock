//
//  NSObject+SYFAdd.m
//  EasyKVOBlock
//
//  Created by lemo on 2018/4/23.
//  Copyright © 2018年 孙亚锋. All rights reserved.
//

#import "NSObject+SYFAdd.h"
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 私有实现KVO的真实target类，每一个target对应了一个keyPath和监听该keyPath的所有block，当其KVO方法调用时，需要回调所有的block
@interface SYFBlockTarget:NSObject
/**添加一个KVOBlock*/
- (void)syf_addBlock:(void(^)(__weak id obj,id oldValue,id newValue))block;
- (void)syf_addNotificationBlock:(void(^)(NSNotification *notification))block;
- (void)syf_doNotification:(NSNotification *)notification;

@end

@implementation SYFBlockTarget
{
    //保存所有的block
    NSMutableSet *_kvoBlockSet;
    NSMutableSet *_notificationBlockSet;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _kvoBlockSet = [NSMutableSet new];
        _notificationBlockSet = [NSMutableSet set];
        
    }
    return self;
}
- (void)syf_addBlock:(void (^)(__weak id, id, id))block
{
    [_kvoBlockSet addObject:[block copy]];
}

-(void)syf_addNotificationBlock:(void (^)(NSNotification *))block
{
    [_notificationBlockSet addObject:[block copy]];
}
 - (void)syf_doNotification:(NSNotification *)notification
{
    if (!_notificationBlockSet.count)return;
    [_notificationBlockSet enumerateObjectsUsingBlock:^(void (^block)(NSNotification *notification), BOOL * _Nonnull stop) {
        block(notification);
    }];
        
    
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if(!_kvoBlockSet.count)return;
    
    BOOL prior = [[change objectForKey:NSKeyValueChangeNotificationIsPriorKey]boolValue];
    
    if(prior)return;//只接受值改变时的消息
    
    NSKeyValueChange changeKind = [[change objectForKey:NSKeyValueChangeKindKey]integerValue];
    
    if(changeKind != NSKeyValueChangeSetting)return;
    
    id oldVal = [change objectForKey:NSKeyValueChangeOldKey];
    if (oldVal == [NSNull null]) {
        oldVal = nil;
    }
    id newVal = [change objectForKey:NSKeyValueChangeNewKey];
    if (newVal == [NSNull null]) {
        newVal = nil;
    }
    //执行该target下的所有block
    [_kvoBlockSet enumerateObjectsUsingBlock:^(void(^block)(__weak id obj,id oldVal,id newVal), BOOL * _Nonnull stop) {
        
        block(object,oldVal,newVal);
        
    }];
    
    
}
@end

@implementation NSObject (SYFAdd)

#pragma mark - - ############KVO
static void *const KVOBlockKey = "KVOBlockKey";
static void *const KVOSemaphoreKey = "KVOSemaphoreKey";

- (void)syf_addObserverBlockForKeyPath:(NSString *)keyPath block:(KVOBlock)block{
    
    if (!keyPath || !block) {
        return;
    }
    
    dispatch_semaphore_t kvoSemaphore = [self syf_getSemaphoreWithKey:KVOSemaphoreKey];
    dispatch_semaphore_wait(kvoSemaphore, DISPATCH_TIME_FOREVER);
    //取出存有所有KVOTarget的字典
    NSMutableDictionary *allTargets = objc_getAssociatedObject(self, KVOBlockKey);
    if (!allTargets) {
        //没有则创建
        allTargets = [NSMutableDictionary new];
        //绑定在该对象中
        objc_setAssociatedObject(self, KVOBlockKey, allTargets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    //获取对应keyPath中的所以Target
    SYFBlockTarget *targetForKeyPath = allTargets[keyPath];
    if (!targetForKeyPath) {
        // 没有则创建
        targetForKeyPath = [SYFBlockTarget new];
        //保存
        allTargets[keyPath] = targetForKeyPath;
        //如果第一次，则注册对KeyPath的KVO监听
        [self addObserver:targetForKeyPath forKeyPath:keyPath options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:NULL];
    }
    
    [targetForKeyPath syf_addBlock:block];
    
}
- (void)syf_removeObserverBlockForKeyPath:(NSString *)keyPath
{
    if (!keyPath.length) {
        return;
    }
    NSMutableDictionary *allTargets =objc_getAssociatedObject(self, KVOBlockKey);
    if (!allTargets) {
        return;
    }
    SYFBlockTarget *target = allTargets[keyPath];
    if (!target) {
        return;
    }
    dispatch_semaphore_t kvoSemphore = [self syf_getSemaphoreWithKey:KVOSemaphoreKey];
    dispatch_semaphore_wait(kvoSemphore, DISPATCH_TIME_FOREVER);
    [self removeObserver:target forKeyPath:keyPath];
    [allTargets removeObjectForKey:keyPath];
    dispatch_semaphore_signal(kvoSemphore);
}
- (void)syf_removeAllObserverBlocks
{
    NSMutableDictionary *allTargets = objc_getAssociatedObject(self, KVOBlockKey);
    if(!allTargets)return;
    dispatch_semaphore_t kvoSemapore = [self syf_getSemaphoreWithKey:KVOSemaphoreKey];
    dispatch_semaphore_wait(kvoSemapore, DISPATCH_TIME_FOREVER);
    [allTargets enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, SYFBlockTarget *target, BOOL * _Nonnull stop) {
        [self removeObserver:target forKeyPath:key];
    }];
    [allTargets removeAllObjects];
    dispatch_semaphore_signal(kvoSemapore);
}
#pragma mark - - ############Notification
static void *const SYFNotificationBlockKey = "SYFNotificationBlockKey";
static void *const SYFNotificationSemaphoreKey = "SYFNotificationSemaphoreKey";
 - (void)syf_addNotificationForName:(NSString *)name block:(NotificationBlock)block
{
    if (!name || !block)return;
    dispatch_semaphore_t notificationSemaphore = [self syf_getSemaphoreWithKey:SYFNotificationSemaphoreKey];
    dispatch_semaphore_wait(notificationSemaphore, DISPATCH_TIME_FOREVER);
    NSMutableDictionary *allTargets = objc_getAssociatedObject(self, SYFNotificationBlockKey);
    if (!allTargets) {
        allTargets =@{}.mutableCopy;
        objc_setAssociatedObject(self, SYFNotificationBlockKey, allTargets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    SYFBlockTarget *target = allTargets[name];
    if (!target) {
        target = [SYFBlockTarget new];
        allTargets[name] = target;
        [[NSNotificationCenter defaultCenter]addObserver:target selector:@selector(syf_doNotification:) name:name object:nil];
    }
    [target syf_addNotificationBlock:block];
    [self syf_swizzleDealloc];
    dispatch_semaphore_signal(notificationSemaphore);
    
}
- (void)syf_removeNotificationForName:(NSString *)name
{
    if (!name)return;
    NSMutableDictionary *allTargets =objc_getAssociatedObject(self, SYFNotificationBlockKey);
    if (!allTargets.count)return;
    SYFBlockTarget *target = allTargets[name];
    if (!target)return;
    dispatch_semaphore_t notificationSemaphore = [self syf_getSemaphoreWithKey:SYFNotificationSemaphoreKey];
    dispatch_semaphore_wait(notificationSemaphore, DISPATCH_TIME_FOREVER);
    [[NSNotificationCenter defaultCenter]removeObserver:target];
    [allTargets removeAllObjects];
    dispatch_semaphore_signal(notificationSemaphore);
}
- (void)syf_removeAllNotification
{
    NSMutableDictionary *allTargets = objc_getAssociatedObject(self, SYFNotificationBlockKey);
    if (!allTargets.count) {
        return;
    }
    dispatch_semaphore_t notificationSemaphore = [self syf_getSemaphoreWithKey:SYFNotificationSemaphoreKey];
    dispatch_semaphore_wait(notificationSemaphore, DISPATCH_TIME_FOREVER);
    [allTargets enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, SYFBlockTarget *target, BOOL * _Nonnull stop) {
        [[NSNotificationCenter defaultCenter]removeObserver:target];
    }];
    [allTargets removeAllObjects];
    dispatch_semaphore_signal(notificationSemaphore);
    
}
- (void)syf_postNotificationWithName:(NSString *)name userInfo:(nullable NSDictionary *)userInfo
{
    [[NSNotificationCenter defaultCenter]postNotificationName:name object:nil userInfo:userInfo];
}


static void * deallocHasSwizzledKey = "deallocHasSwizzledKey";

/**
 * 调剂dealloc方法，由于无法直接使用运行时的swizzle方法对dealloc方法进行调剂，所以稍微麻烦一些
 */
- (void)syf_swizzleDealloc
{
        //我们给每个类绑定上一个值来判断dealloc方法是否被调剂过，如果调剂过了就无需再次调剂了
    BOOL swizzled = [objc_getAssociatedObject(self.class, deallocHasSwizzledKey) boolValue];
        //如果调剂过则直接返回
    if (swizzled)return;
        //开始调剂
    Class swizzleClass = self.class;
    @synchronized(swizzleClass){
            //获取原有的dealloc方法
        SEL deallocSelector = sel_registerName("dealloc");
            //初始化一个函数指针用于保存原有的dealloc方法
        __block void(*originalDealloc)(__unsafe_unretained id ,SEL) = NULL;
            //实现我们自己的dealloc方法，通过block的方式
        id newDealloc = ^(__unsafe_unretained id objSelf){
            [objSelf syf_removeAllNotification];
            [objSelf syf_removeAllObserverBlocks];
            if (originalDealloc == NULL) {
                    //如果不存在，说明本类没有实现dealloc方法，则需要向父类发 dealloc消息(objc_msgSendSuper)
                    //构造objc_msgSendSuper所需要的参数，.receiver为方法的实际调用者，即为类本身，.super_class指向其父类
                struct objc_super superInfo = {
                    .receiver  = objSelf,
                    .super_class = class_getSuperclass(swizzleClass)
                };
                    //构建objc_msgSendSuper函数
                void(*msgSend)(struct objc_super *,SEL) =(__typeof(msgSend))objc_msgSendSuper;
                    //向super发送dealloc消息
                msgSend(&superInfo,deallocSelector);
                
            }else{//如果存在，表明该类实现了dealloc方法，则直接调用即可
                  //调用原有的dealloc方法
                originalDealloc(objSelf,deallocSelector);
                
            }
        };
        //根据block构建新的dealloc实现IMP
        IMP newDeallocIMP = imp_implementationWithBlock(newDealloc);
         //尝试添加新的dealloc方法，如果该类已经复写的dealloc方法则不能添加成功，反之则能够添加成功
        if (!class_addMethod(swizzleClass, deallocSelector, newDeallocIMP, "v@:")) {
            Method deallocMethod =class_getInstanceMethod(swizzleClass, deallocSelector);
            originalDealloc = (void(*)(__unsafe_unretained id ,SEL))method_getImplementation(deallocMethod);
            originalDealloc = (void(*)(__unsafe_unretained id,SEL))method_setImplementation(deallocMethod, newDeallocIMP);
            
        }
        //标记该类已经调剂过了
        objc_setAssociatedObject(self.class, deallocHasSwizzledKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
}
#pragma mark - - ############信号量的定义
/*
信号量：
 就是一种可用来控制访问资源的数量的标识，设定了一个信号量，在线程访问之前，加上信号量的处理，则可告知系统按照我们指定的信号量数量来执行多个线程。其实，这有点类似锁机制了，只不过信号量都是系统帮助我们处理了，我们只需要在执行线程之前，设定一个信号量值，并且在使用时，加上信号量处理方法就行了。
 */
//const void * _Nonnull key
- (dispatch_semaphore_t)syf_getSemaphoreWithKey:(void *)key
{
    dispatch_semaphore_t semaphore = objc_getAssociatedObject(self, key);
    if (!semaphore) {
        //创建信号量，参数：信号量的初值，如果小于0则会返回NULL
         //crate的value表示，最多几个资源可访问
        semaphore = dispatch_semaphore_create(1);
        objc_setAssociatedObject(semaphore, key, semaphore, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    }
    return semaphore;
}

@end

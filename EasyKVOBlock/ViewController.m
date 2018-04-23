//
//  ViewController.m
//  EasyKVOBlock
//
//  Created by lemo on 2018/4/23.
//  Copyright © 2018年 孙亚锋. All rights reserved.
//
/**
  实际项目运用中，在每个cell中都需要绑定一个KVO监听对象,然后再释放的时候并不能释放而导致程序闪退。
  NSObject+SYFAdd.h  完美解决了 释放问题。
 */

#import "ViewController.h"
#import "NSObject+SYFAdd.h"
#import "SYFTestObject.h"
@interface ViewController ()

@property(nonatomic,strong)SYFTestObject *objectA;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _objectA = [SYFTestObject new];
    [_objectA syf_addObserverBlockForKeyPath:@"name" block:^(id  _Nonnull object, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"kvo,修改name为%@",newValue);
    }];
    [self syf_addNotificationForName:@"TestNotification" block:^(NSNotification * _Nonnull notification) {
        NSLog(@"收到通知1：%@",notification.userInfo);
    }];
    
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"TestNotification" object:nil userInfo:@{@"test":@"1"}];
    static BOOL flag = NO;
    if (!flag) {
        _objectA.name = @"sunYaFeng";
        flag = YES;
    }else{
        //objA 销毁的时候其绑定的KVO会自己移除
        _objectA = nil;
    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

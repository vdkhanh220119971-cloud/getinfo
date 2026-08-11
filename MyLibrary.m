#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MyLibrary : NSObject
+ (instancetype)sharedManager;
- (void)postNewOrderEvent:(NSDictionary *)orderInfo;
- (void)listenForOrdersInViewController:(UIViewController *)viewController;
@end

@implementation MyLibrary

+ (instancetype)sharedManager {
    static MyLibrary *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MyLibrary alloc] init];
    });
    return shared;
}

// Phát sự kiện khi có dữ liệu mới trong ứng dụng
- (void)postNewOrderEvent:(NSDictionary *)orderInfo {
    if (!orderInfo) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AppDidReceiveNewOrderNotification"
                                                            object:nil
                                                          userInfo:orderInfo];
    });
}

// Lắng nghe sự kiện và hiển thị thông báo lên giao diện
- (void)listenForOrdersInViewController:(UIViewController *)viewController {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"AppDidReceiveNewOrderNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSDictionary *orderData = note.userInfo;
        NSString *message = [NSString stringWithFormat:@"Đã nhận đơn hàng: %@", orderData[@"id"] ?: @"Mới"];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thông Báo"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        [viewController presentViewController:alert animated:YES completion:nil];
    }];
}

@end

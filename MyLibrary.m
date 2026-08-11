#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============================================================================
// CONFIGURATION: Thay đổi các hằng số này theo class & method thực tế của App
// ============================================================================
static NSString * const TARGET_CLASS_NAME  = @"OrderViewController"; // Hoặc OrderModel
static NSString * const TARGET_METHOD_NAME = @"didReceiveNewOrder:"; // Hoặc updateOrderInfo:

// ============================================================================
// HELPER FUNCTIONS: Trích xuất toàn bộ dữ liệu của một Object
// ============================================================================

// Hàm chuyển đổi một Object bất kỳ thành Dictionary dựa trên toàn bộ Property
NSDictionary* DumpObjectToDictionary(id object) {
    if (!object) return nil;
    
    // Nếu đối tượng vốn đã là NSDictionary
    if ([object isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)object;
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    Class currentClass = [object class];
    
    // Duyệt qua class và các superclass (cho đến NSObject)
    while (currentClass && currentClass != [NSObject class]) {
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(currentClass, &count);
        
        for (unsigned int i = 0; i < count; i++) {
            const char *propertyName = property_getName(properties[i]);
            NSString *key = [NSString stringWithUTF8String:propertyName];
            
            @try {
                id value = [object valueForKey:key];
                if (value) {
                    // Xử lý đệ quy nếu giá trị lại là một custom model object
                    if ([value isKindOfClass:[NSString class]] || 
                        [value isKindOfClass:[NSNumber class]] || 
                        [value isKindOfClass:[NSDate class]]) {
                        dict[key] = value;
                    } else if ([value isKindOfClass:[NSDictionary class]]) {
                        dict[key] = value;
                    } else if ([value isKindOfClass:[NSArray class]]) {
                        NSMutableArray *arr = [NSMutableArray array];
                        for (id item in (NSArray *)value) {
                            NSDictionary *subDict = DumpObjectToDictionary(item);
                            [arr addObject:subDict ? subDict : [item description]];
                        }
                        dict[key] = arr;
                    } else {
                        // Custom object khác
                        NSDictionary *subDict = DumpObjectToDictionary(value);
                        dict[key] = subDict ? subDict : [value description];
                    }
                } else {
                    dict[key] = [NSNull null];
                }
            } @catch (NSException *exception) {
                // Bỏ qua nếu thuộc tính không thể truy cập qua KVC
                dict[key] = @"<Unreadable>";
            }
        }
        free(properties);
        currentClass = class_getSuperclass(currentClass);
    }
    
    return [dict copy];
}

// Chuyển Dictionary thành Chuỗi JSON đẹp để in ra Log
NSString* DictionaryToJSONString(NSDictionary *dict) {
    if (!dict) return @"{}";
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    if (error || !jsonData) {
        return [dict description];
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

// ============================================================================
// METHOD SWIZZLING CORE
// ============================================================================

void SwizzleInstanceMethod(Class targetClass, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSelector);
    
    if (!originalMethod || !swizzledMethod) {
        NSLog(@"[OrderHook] ❌ Error: Original or Swizzled method not found.");
        return;
    }
    
    BOOL didAddMethod = class_addMethod(targetClass,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(targetClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

// ============================================================================
// HOOK IMPLEMENTATION
// ============================================================================

@interface OrderHookInjector : NSObject
@end

@implementation OrderHookInjector

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[OrderHook] 🚀 Dylib Injection loaded successfully!");
        
        Class targetClass = NSClassFromString(TARGET_CLASS_NAME);
        if (!targetClass) {
            NSLog(@"[OrderHook] ⚠️ Warning: Class '%@' not found during +load.", TARGET_CLASS_NAME);
            return;
        }
        
        SEL originalSel = NSSelectorFromString(TARGET_METHOD_NAME);
        SEL swizzledSel = @selector(custom_didReceiveNewOrder:);
        
        // Thêm phương thức hook mới vào targetClass
        Method swizzledMethod = class_getInstanceMethod([self class], swizzledSel);
        IMP swizzledIMP = method_getImplementation(swizzledMethod);
        const char *types = method_getTypeEncoding(swizzledMethod);
        
        class_addMethod(targetClass, swizzledSel, swizzledIMP, types);
        
        // Tiến hành Swizzle
        SwizzleInstanceMethod(targetClass, originalSel, swizzledSel);
        NSLog(@"[OrderHook] ✅ Swizzled %@ -> %@", TARGET_CLASS_NAME, TARGET_METHOD_NAME);
    });
}

// Hàm replacement sẽ được gọi khi app thực thi phương thức target
- (void)custom_didReceiveNewOrder:(id)orderData {
    NSLog(@"[OrderHook] ===================== NEW ORDER DETECTED =====================");
    
    if (orderData) {
        // Trích xuất toàn bộ dữ liệu
        NSDictionary *extractedData = DumpObjectToDictionary(orderData);
        NSString *jsonString = DictionaryToJSONString(extractedData);
        
        NSLog(@"[OrderHook] RAW DATA EXTRACTED:\n%@", jsonString);
        
        // --- BẠN CÓ THỂ THÊM XỬ LÝ RIÊNG Ở ĐÂY ---
        // 1. Gửi về Webhook / Server của bạn qua NSURLSession
        // 2. Lưu thông tin vào File Local / Documents
        // 3. Hiển thị Alert trên UI
    } else {
        NSLog(@"[OrderHook] Received nil orderData");
    }
    
    NSLog(@"[OrderHook] ==============================================================");
    
    // Gọi lại phương thức gốc để App tiếp tục hoạt động bình thường
    [self custom_didReceiveNewOrder:orderData];
}

@end

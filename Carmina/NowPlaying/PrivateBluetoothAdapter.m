//
//  PrivateBluetoothAdapter.m
//  Carmina
//
//  Created by waru on 8/10/26.
//

#import "PrivateBluetoothAdapter.h"

#import <TargetConditionals.h>
#import <dlfcn.h>
#import <objc/message.h>

static NSNotificationName CMTelephonyRoutesDidChangeNotification =
    @"AVSystemController_PickableAndDisabledRoutesDidChangeNotification";

#if TARGET_OS_IOS && !TARGET_OS_SIMULATOR && !TARGET_OS_MACCATALYST
static id CMTUAudioSystemController;
static Class CMTUAudioRouteClass;
static Class CMProductInfoClass;

static BOOL CMResponds(id object, SEL selector) {
    return object != nil && [object respondsToSelector:selector];
}

static id _Nullable CMObjectMessage(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return nil;
    }

    @try {
        return ((id (*)(id, SEL))(void *)objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id _Nullable CMObjectMessageWithObject(id object, NSString *selectorName,
                                              id argument) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return nil;
    }

    @try {
        return ((id (*)(id, SEL, id))(void *)objc_msgSend)(object, selector,
                                                           argument);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id _Nullable CMObjectMessageWithUInt32(id object, NSString *selectorName,
                                              uint32_t argument) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return nil;
    }

    @try {
        return ((id (*)(id, SEL, uint32_t))(void *)objc_msgSend)(
            object, selector, argument);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id _Nullable CMObjectMessageWithInt64(id object, NSString *selectorName,
                                             int64_t argument) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return nil;
    }

    @try {
        return ((id (*)(id, SEL, int64_t))(void *)objc_msgSend)(
            object, selector, argument);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL CMBoolMessage(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return NO;
    }

    @try {
        return ((BOOL (*)(id, SEL))(void *)objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static uint32_t CMUInt32Message(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return 0;
    }

    @try {
        return ((uint32_t (*)(id, SEL))(void *)objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return 0;
    }
}

static int64_t CMInt64Message(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!CMResponds(object, selector)) {
        return 0;
    }

    @try {
        return ((int64_t (*)(id, SEL))(void *)objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return 0;
    }
}

static NSString *_Nullable CMStringMessage(id object, NSString *selectorName) {
    id value = CMObjectMessage(object, selectorName);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static void CMPrepareTelephonyRouteResolver(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      dlopen("/System/Library/PrivateFrameworks/"
             "TelephonyUtilities.framework/TelephonyUtilities",
             RTLD_LAZY | RTLD_LOCAL);
      dlopen("/System/Library/PrivateFrameworks/"
             "TelephonyUI.framework/TelephonyUI",
             RTLD_LAZY | RTLD_LOCAL);
      dlopen("/System/Library/Frameworks/"
             "CoreBluetooth.framework/CoreBluetooth",
             RTLD_LAZY | RTLD_LOCAL);

      Class controllerClass = NSClassFromString(@"TUAudioSystemController");
      CMTUAudioSystemController =
          CMObjectMessage(controllerClass, @"sharedAudioSystemController");
      CMTUAudioRouteClass = NSClassFromString(@"TUAudioRoute");
      CMProductInfoClass = NSClassFromString(@"CBProductInfo");

      NSString *__unsafe_unretained *notificationNamePointer =
          (NSString * __unsafe_unretained *)dlsym(
              RTLD_DEFAULT, "AVSystemController_"
                            "PickableAndDisabledRoutesDidChangeNotification");
      if (notificationNamePointer != NULL &&
          (*notificationNamePointer).length > 0) {
          CMTelephonyRoutesDidChangeNotification = *notificationNamePointer;
      }
    });
}

static id _Nullable CMTelephonyRouteFromDictionary(id value) {
    if (![value isKindOfClass:NSDictionary.class] ||
        CMTUAudioRouteClass == Nil) {
        return nil;
    }

    id route = CMObjectMessage(CMTUAudioRouteClass, @"alloc");
    return CMObjectMessageWithObject(route, @"initWithDictionary:", value);
}

static id _Nullable CMPickedBluetoothRoute(void) {
    id route = CMTelephonyRouteFromDictionary(
        CMObjectMessage(CMTUAudioSystemController, @"pickedRouteAttribute"));
    if (CMBoolMessage(route, @"isBluetooth") &&
        CMBoolMessage(route, @"isCurrentlyPicked")) {
        return route;
    }

    id value = CMObjectMessage(CMTUAudioSystemController,
                               @"bestGuessPickableRoutesForAnyCall");
    if (![value isKindOfClass:NSArray.class]) {
        return nil;
    }

    id match = nil;
    for (id candidate in (NSArray *)value) {
        if (!CMBoolMessage(candidate, @"isBluetooth") ||
            !CMBoolMessage(candidate, @"isCurrentlyPicked")) {
            continue;
        }
        if (match != nil) {
            return nil;
        }
        match = candidate;
    }
    return match;
}

static BOOL CMRouteIdentifierMatches(NSString *routeIdentifier,
                                     NSString *expectedIdentifier) {
    return routeIdentifier.length > 0 && expectedIdentifier.length > 0 &&
           [routeIdentifier caseInsensitiveCompare:expectedIdentifier] ==
               NSOrderedSame;
}
#endif

@implementation CMPrivateBluetoothAdapter

+ (NSNotificationName)telephonyRoutesDidChangeNotification {
#if TARGET_OS_IOS && !TARGET_OS_SIMULATOR && !TARGET_OS_MACCATALYST
    CMPrepareTelephonyRouteResolver();
#endif
    return CMTelephonyRoutesDidChangeNotification;
}

+ (NSString *)symbolNameForRouteUID:(NSString *)routeUID {
#if TARGET_OS_IOS && !TARGET_OS_SIMULATOR && !TARGET_OS_MACCATALYST
    CMPrepareTelephonyRouteResolver();
    id route = CMPickedBluetoothRoute();
    if (!CMRouteIdentifierMatches(CMStringMessage(route, @"uniqueIdentifier"),
                                  routeUID)) {
        return nil;
    }

    id imageClass = NSClassFromString(@"UIImage");
    id mappedSymbol = CMObjectMessageWithInt64(
        imageClass,
        @"systemImageNameForDeviceType:", CMInt64Message(route, @"deviceType"));
    if ([mappedSymbol isKindOfClass:NSString.class] &&
        ((NSString *)mappedSymbol).length > 0) {
        return mappedSymbol;
    }

    uint32_t productID =
        CMUInt32Message(route, @"bluetoothProductIdentifierAsUInt32");
    id productInfo = CMObjectMessageWithUInt32(
        CMProductInfoClass, @"productInfoWithProductID:", productID);
    NSString *productSymbol = CMStringMessage(productInfo, @"sfSymbolNameMain");
    return productSymbol.length > 0 ? productSymbol : nil;
#else
    return nil;
#endif
}

@end

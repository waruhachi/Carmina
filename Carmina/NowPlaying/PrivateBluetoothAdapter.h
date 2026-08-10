//
//  PrivateBluetoothAdapter.h
//  Carmina
//
//  Created by waru on 8/10/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolves the currently picked Bluetooth route through TelephonyUtilities.
/// TelephonyUI and CBProductInfo provide product-specific AirPods and Beats
/// symbols. Private framework objects remain contained inside this adapter.
@interface CMPrivateBluetoothAdapter : NSObject

@property(class, nonatomic, readonly)
    NSNotificationName telephonyRoutesDidChangeNotification;

+ (nullable NSString *)symbolNameForRouteUID:(NSString *)routeUID
    NS_SWIFT_NAME(symbolName(forRouteUID:));

@end

NS_ASSUME_NONNULL_END

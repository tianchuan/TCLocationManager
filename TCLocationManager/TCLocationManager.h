//
//  TCLocationManager.h
//  吃豆养车
//
//  Created by apple on 2020/4/2.
//  Copyright © 2020 hsy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BMKLocationKit/BMKLocationManager.h>

typedef void (^GeocoderCompletionHandler) (BMKAddressComponent *BMKAddress);
typedef void (^CoordinatesCompletionHandler) (double longitude,double latitude);

@interface TCLocationManager : NSObject

@property (nonatomic, strong) CLLocation *userLocation;

+ (TCLocationManager *)shareLocationManager;

//开始定位
- (void)findCurrentLocation;
//打开“设置” 为app 打开定位服务
- (BOOL)showLocationAlert;
//获取app 是否有位置权限
- (BOOL)getLocationPermissions;

//根据经纬度获取相关信息  location：为空，就用当前的 currentLocation
- (void)getCity:(CLLocation *)location completionHandler:(GeocoderCompletionHandler)geocoderCompletionHandler;

//根据城市获取相关信息  strCity：为空，就用当前的 currentLocation
- (void)getCoordinates:(NSString *)strCity completionHandler:(CoordinatesCompletionHandler)coordinatesCompletionHandler;

//计算这location与我的距离（单位米）
- (double)getDistanceWithLocation:(CLLocation *)location;

//调用地图app导航
- (void)navigationActionWithCoordinate:(NSDictionary *)locationDic WithENDName:(NSString *)name tager:(UIViewController *)tager;

@end

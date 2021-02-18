//
//  TCLocationManager.m
//  吃豆养车
//
//  Created by apple on 2020/4/2.
//  Copyright © 2020 hsy. All rights reserved.
//

#import "TCLocationManager.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@interface TCLocationManager ()<BMKGeoCodeSearchDelegate,BMKLocationManagerDelegate>{
    CLLocation *geoLocation;
    BMKGeoCodeSearch *geoCodeSearch;
    BMKLocationManager *locationService;
    BOOL resetLocation;
}
@property (nonatomic, strong) CLGeocoder *geocoder;
@property (nonatomic, copy) GeocoderCompletionHandler geocoderBlock;

@end

@implementation TCLocationManager
+ (TCLocationManager *)shareLocationManager {
    static TCLocationManager *_instance;
    static dispatch_once_t token;
    
    dispatch_once(&token, ^{
        _instance = [[self alloc] init];
    });
    
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        if(!(APP_In_Review)){
            locationService=[[BMKLocationManager alloc] init];
            //设置BMKLocationService的代理
            locationService.delegate = self;
            //设定定位坐标系类型，默认为 BMKLocationCoordinateTypeGCJ02
            locationService.coordinateType = BMKLocationCoordinateTypeBMK09LL;
            //设定定位精度，默认为 kCLLocationAccuracyBest
            locationService.desiredAccuracy = kCLLocationAccuracyBest;
            //设定定位类型，默认为 CLActivityTypeAutomotiveNavigation
            locationService.activityType = CLActivityTypeAutomotiveNavigation;
            //指定定位是否会被系统自动暂停，默认为NO
            locationService.pausesLocationUpdatesAutomatically = NO;
            /**
             是否允许后台定位，默认为NO。只在iOS 9.0及之后起作用。
             设置为YES的时候必须保证 Background Modes 中的 Location updates 处于选中状态，否则会抛出异常。
             由于iOS系统限制，需要在定位未开始之前或定位停止之后，修改该属性的值才会有效果。
             */
            locationService.allowsBackgroundLocationUpdates = NO;
            /**
             指定单次定位超时时间,默认为10s，最小值是2s。注意单次定位请求前设置。
             注意: 单次定位超时时间从确定了定位权限(非kCLAuthorizationStatusNotDetermined状态)
             后开始计算。
             */
            locationService.locationTimeout = 10;
        }
        
        self.geocoder = [[CLGeocoder alloc] init];
    }
    return self;
}

//开始定位
- (void)findCurrentLocation {
    SLog(@"定位集成===开始定位");
    if(!(APP_In_Review)){
        [locationService startUpdatingLocation];
    }
}

#pragma mark - BMKLocationManagerDelegate
- (void)BMKLocationManager:(BMKLocationManager * _Nonnull)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    if (resetLocation && status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        SLog(@"定位集成===授权成功");//0
        resetLocation = NO;
        [self findCurrentLocation];//重新定位
    }
}
/**
 *用户位置更新后，会调用此函数
 *@param location 用户新的位置
 */
- (void)BMKLocationManager:(BMKLocationManager * _Nonnull)manager didUpdateLocation:(BMKLocation * _Nullable)location orError:(NSError * _Nullable)error {
    [locationService stopUpdatingLocation];//停止百度定位
    self.userLocation = location.location;
    
    NSString *lat = [NSString stringWithFormat:@"%f",self.userLocation.coordinate.latitude];
    NSString *lng = [NSString stringWithFormat:@"%f",self.userLocation.coordinate.longitude];
    
    //保存用户经纬度
    [[TCUserDefaults shareUserDefaults] setObject:lat forKey:MY_KEY_LAT];
    [[TCUserDefaults shareUserDefaults] setObject:lng forKey:MY_KEY_LNG];
    
    //定位成功通知
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_UPDATELOCATION object:nil];
    SLog(@"定位集成===定位成功");
}

/**
 *定位失败后，会调用此函数
 *@param error 错误号
 */
- (void)BMKLocationManager:(BMKLocationManager * _Nonnull)manager didFailWithError:(NSError * _Nullable)error {
    //询问用户是否开启定位权限
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        SLog(@"定位集成===询问开启定位权限");
        resetLocation = YES;
    }
    else {//已询问过权限，但定位已失败
        SLog(@"定位集成===定位失败");
        [locationService stopUpdatingLocation];//停止百度定位
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_FAILURELOCATION object:nil];
        
        switch(error.code) {
            case kCLErrorDenied://未打开定位时
            case kCLErrorNetwork:
                [self showLocationAlert];//提示打开定位
                break;
                
            case kCLErrorLocationUnknown://未连接网络
                [CustomMsgView showAlertWithMessage:@"请检查定位网络连接!"];
                break;
                
            default:
                break;
        }
    }
}
//打开“设置” 为app 打开定位服务
- (BOOL)showLocationAlert {
    //用户未开启定位
    if (![self getLocationPermissions]) {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        NSString *msg = [NSString stringWithFormat:@"请到设置->【%@】->位置开启定位服务。",app_Name];
        
        UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"开启定位" message:msg preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *configAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil];
        [alertView addAction:cancelAction];
        [alertView addAction:configAction];
        [[UIApplication sharedApplication].delegate.window.rootViewController presentViewController:alertView animated:YES completion:nil];
        return NO;//未开启
    }
    return YES;//已开启
}
//获取app 是否有位置权限
- (BOOL)getLocationPermissions {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    //定位权限受限制 || 用户明确禁止
    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        return NO;
    }
    
    return YES;//已开启定位
}
#pragma mark - 根据经纬度获取相关信息  location：为空，就用当前的 currentLocation
- (void)getCity:(CLLocation*)location completionHandler:(GeocoderCompletionHandler)geocoderCompletionHandler {
    geoLocation = location;
    _geocoderBlock = geocoderCompletionHandler;
    //根据经纬度获取
    if (location == nil) {
        if ([[TCUserDefaults shareUserDefaults] objectForKey:MY_KEY_LAT]){
            NSString *latStr = [[TCUserDefaults shareUserDefaults] objectForKey:MY_KEY_LAT];
            NSString *lngStr = [[TCUserDefaults shareUserDefaults] objectForKey:MY_KEY_LNG];
            geoLocation = [[CLLocation alloc] initWithLatitude:[latStr doubleValue] longitude:[lngStr doubleValue]];
        }
        else {
            _geocoderBlock(nil);
            return;
        }
    }
    
    CLLocationCoordinate2D locationCoord=geoLocation.coordinate;
    if (!geoCodeSearch) {
        geoCodeSearch=[[BMKGeoCodeSearch alloc] init];
    }
    
    geoCodeSearch.delegate=self;
    BMKReverseGeoCodeSearchOption *reverse=[[BMKReverseGeoCodeSearchOption alloc] init];
    reverse.location = locationCoord;
    BOOL flag=[geoCodeSearch reverseGeoCode:reverse];//成功返回YES，否则返回NO
    if (!flag) {
        geoCodeSearch.delegate=nil;
        [self systemGetReverseGeoCode];//失败就使用系统的
    }
}
//使用系统的
-(void)systemGetReverseGeoCode {
    __weak typeof(self) weakSelf = self;
    [self.geocoder cancelGeocode];
    [self.geocoder reverseGeocodeLocation:geoLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        
        if (error == nil && [placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            
            BMKAddressComponent *component=[[BMKAddressComponent alloc] init];
            //市、县、辖区
            NSString *str_city=placemark.locality;
            component.city=str_city;
            
            NSString *str_province=placemark.administrativeArea;
            component.province=str_province;
            NSString *addressStr = [[placemark.addressDictionary objectForKey:@"FormattedAddressLines"] firstObject];
            if (addressStr && addressStr.length > 2) {
                addressStr = [addressStr substringFromIndex:2];
            }
            
            component.district=placemark.subLocality;
            component.streetName=placemark.thoroughfare;
            component.streetNumber=placemark.subThoroughfare;
            
            weakSelf.geocoderBlock(component);
        }
        else {
            weakSelf.geocoderBlock(nil);
        }
    }];
}
#pragma mark - BMKGeoCodeSearchDelegate
/**
 *返回反地理编码搜索结果
 *@param searcher 搜索对象
 *@param result 搜索结果
 *@param error 错误号，@see BMKSearchErrorCode
 */
- (void)onGetReverseGeoCodeResult:(BMKGeoCodeSearch *)searcher result:(BMKReverseGeoCodeSearchResult *)result errorCode:(BMKSearchErrorCode)error {
    if (error == BMK_SEARCH_NO_ERROR) {
        //市、县、辖区
        NSString *str_city=result.addressDetail.city;
        result.addressDetail.city=str_city;
        
        NSString *str_province=result.addressDetail.province;
        result.addressDetail.province=str_province;
        
        _geocoderBlock(result.addressDetail);
    }
    else if (error == BMK_SEARCH_NETWOKR_ERROR || error == BMK_SEARCH_NETWOKR_TIMEOUT) {
        [CustomMsgView showAlertWithMessage:@"请检查您的网络"];
        _geocoderBlock(nil);
    }
    else{
        [self systemGetReverseGeoCode];//使用系统的
    }
    geoCodeSearch.delegate=nil;
}

#pragma mark - 根据城市获取相关信息  strCity：为空，就用当前的 currentLocation
- (void)getCoordinates:(NSString *)strCity completionHandler:(CoordinatesCompletionHandler)coordinatesCompletionHandler {
    //根据经纬度获取
    if (strCity.length==0||strCity==nil) {
        if ([[TCUserDefaults shareUserDefaults] objectForKey:MY_KEY_LAT]){
            
            NSString *latStr = [[TCUserDefaults shareUserDefaults] objectForKey:MY_KEY_LAT];
            NSString *lngStr = [[TCUserDefaults shareUserDefaults] objectForKey:MY_KEY_LNG];
            coordinatesCompletionHandler(lngStr.doubleValue,latStr.doubleValue);
        }
        coordinatesCompletionHandler(0.0,0.0);
    }
    
    [self.geocoder geocodeAddressString:strCity completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error == nil && [placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            //经纬度
            CLLocation *cllocation=placemark.location;
            coordinatesCompletionHandler(cllocation.coordinate.longitude,cllocation.coordinate.latitude);
        }
        else {
            coordinatesCompletionHandler(0.0,0.0);
        }
    }];
}

#pragma mark 计算这location与我的距离（单位米）
//计算这location与我的距离（单位米）
- (double)getDistanceWithLocation:(CLLocation *)location {
    if (self.userLocation == nil || location.coordinate.latitude == 0 || location.coordinate.longitude == 0) {
        return 0.0;
    }
    
    return [self.userLocation distanceFromLocation:location];
}
#pragma mark - 调用地图app导航
/**
 调用三方导航
 @param locationDic 经纬度
 @param name 地图上显示的名字
 @param tager 当前控制器
 */
- (void)navigationActionWithCoordinate:(NSDictionary *)locationDic WithENDName:(NSString *)name tager:(UIViewController *)tager{
    //默认经纬度
    CLLocationCoordinate2D coordinateGaoDe = CLLocationCoordinate2DMake([locationDic[@"lat"] floatValue],[locationDic[@"lng"] floatValue]);
    if (locationDic[@"gd_lat"] && locationDic[@"gd_lng"]) {//高德地图位置
        coordinateGaoDe = CLLocationCoordinate2DMake([locationDic[@"gd_lat"] floatValue],[locationDic[@"gd_lng"] floatValue]);
    }
    else if (locationDic[@"gdlat"] && locationDic[@"gdlng"]) {//高德地图位置
        coordinateGaoDe = CLLocationCoordinate2DMake([locationDic[@"gdlat"] floatValue],[locationDic[@"gdlng"] floatValue]);
    }
    
    __weak typeof(self) weakSelf = self;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"苹果自带地图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf appleNavigationWithCoordinate:coordinateGaoDe andWithMapTitle:name];
    }]];
    
    // 判断是否安装了高德地图，如果安装了高德地图，则使用高德地图导航
    if ( [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"iosamap://"]]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"高德地图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf gaoDeNavigationWithCoordinate:coordinateGaoDe andWithMapTitle:name];
        }]];
    }
    
    //判断是否安装了百度地图，如果安装了百度地图，则使用百度地图导航
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"baidumap://"]]) {
        CLLocationCoordinate2D coordinateBaidu = CLLocationCoordinate2DMake([locationDic[@"lat"] floatValue],[locationDic[@"lng"] floatValue]);
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"百度地图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf baiduNavigationWithCoordinate:coordinateBaidu andWithMapTitle:name];
        }]];
    }
    
    //添加取消选项
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    //显示alertController
    [tager presentViewController:alertController animated:YES completion:nil];
}
//苹果导航
- (void)appleNavigationWithCoordinate:(CLLocationCoordinate2D)coordinate andWithMapTitle:(NSString *)map_title{
    MKMapItem *currentLocation = [MKMapItem mapItemForCurrentLocation];
    MKMapItem *tolocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil]];
    tolocation.name = map_title;
    [MKMapItem openMapsWithItems:@[currentLocation,tolocation] launchOptions:@{MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving,
                                                                               MKLaunchOptionsShowsTrafficKey:[NSNumber numberWithBool:YES]}];
}
//高德导航
- (void)gaoDeNavigationWithCoordinate:(CLLocationCoordinate2D)coordinate andWithMapTitle:(NSString *)map_title{
    NSString *urlsting =[[NSString stringWithFormat:@"iosamap://navi?sourceApplication=applicationName&poiname=%@&poiid=BGVIS&lat=%f&lon=%f&dev=0&style=2",map_title,coordinate.latitude,coordinate.longitude] chineseTranscoding];
    
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlsting] options:@{} completionHandler:^(BOOL success) {
            SLog(@"调用高德地图导航: %d",success);
        }];
    }
    else { //iOS10以前,使用旧API
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlsting] options:@{} completionHandler:nil];
    }
}
//百度导航
- (void)baiduNavigationWithCoordinate:(CLLocationCoordinate2D)coordinate andWithMapTitle:(NSString *)map_title{
    NSString *urlSting =[[NSString stringWithFormat:@"baidumap://map/direction?origin={{我的位置}}&destination=latlng:%f,%f|name=目的地&mode=driving&coord_type=bd09ll",coordinate.latitude,coordinate.longitude] chineseTranscoding];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlSting] options:@{} completionHandler:nil];
}
@end

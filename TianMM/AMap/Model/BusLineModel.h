//
//  BusLineModel.h
//  TianMM
//
//  Created by cocoa on 15/11/10.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BusLineModel : NSObject
@property (nonatomic, strong)   NSString* busId;
@property (nonatomic, strong)  NSString *name;
@property (nonatomic, strong)  NSString *departureStop;
@property (nonatomic, strong)  NSString *arrivalStop;
@property (nonatomic)          long duration;
@property (nonatomic)          float distance;
@property (nonatomic)          long walk_distance;
@property (nonatomic)          float totalPrice;
@property (nonatomic, strong) AMapGeoPoint *departurelocation ; //!< 起程站
@property (nonatomic, strong) AMapGeoPoint *arrivallocation; //!< 下车站
@property (nonatomic)          long viaBusStopCount;
@property (nonatomic, strong) NSMutableArray *viaBusStops ; //!< 起程站

-(id)initBusLine:(AMapBusLine * )busLine cost:(CGFloat)cost;
@end

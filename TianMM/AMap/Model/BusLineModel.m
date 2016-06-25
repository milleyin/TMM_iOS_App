//
//  BusLineModel.m
//  TianMM
//
//  Created by cocoa on 15/11/10.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import "BusLineModel.h"

@implementation BusLineModel
-(id)initBusLine:(AMapBusLine * )busLine cost:(CGFloat)cost
{
    self = [super init];
    if (self) {
        self.busId = [[NSString alloc]initWithString:busLine.uid];
        self.name  = [[NSString alloc]initWithString:busLine.name];
        self.departureStop  = [[NSString alloc]initWithString:busLine.departureStop.name];
        self.arrivalStop  = [[NSString alloc]initWithString:busLine.arrivalStop.name];
        self.duration = busLine.duration;
        self.distance = busLine.distance;
        self.totalPrice = cost;
        self.departurelocation = busLine.departureStop.location;
        self.arrivallocation = busLine.arrivalStop.location;
        self.viaBusStopCount = [busLine.viaBusStops count];
        self.viaBusStops = [[NSMutableArray alloc]initWithArray:busLine.viaBusStops];
    }
    return self;
}
@end
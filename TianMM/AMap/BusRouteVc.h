//
//  BusRouteVc.h
//  TianMM
//
//  Created by cocoa on 15/11/9.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AMapNaviKit/MAMapKit.h>
#import <AMapNaviKit/AMapNaviKit.h>
#import "UIView+Geometry.h"
#import "BusLineModel.h"

@interface BusRouteVc : UIViewController <MAMapViewDelegate>
- (id)initWithBus:(NSArray *)walkArr busline:(NSArray *)busline  mapView:(MAMapView *)mapView endAnnotation:(MAPointAnnotation*)endAnnotation;
@end

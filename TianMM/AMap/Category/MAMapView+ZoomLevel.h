//
//  MAMapView+ZoomLevel.h
//  TianMM
//
//  Created by cocoa on 15/11/17.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import <AMapNaviKit/AMapNaviKit.h>

@interface MAMapView (ZoomLevel)
- (NSUInteger)getZoomLevel;

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                  zoomLevel:(NSUInteger)zoomLevel
                   animated:(BOOL)animated;

- (void)zoomToFitMapAnnotations;
@end

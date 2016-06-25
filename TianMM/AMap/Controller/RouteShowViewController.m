//
//  MARouteShowViewController.m
//  officialDemoNavi
//
//  Created by LiuX on 14-9-2.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import "RouteShowViewController.h"
#define kBottomPaneHeight 50.0

@interface RouteShowViewController ()

@property (nonatomic, strong) AMapNaviManager *actNaviManager;
@property (nonatomic, strong) AMapNaviViewController *naviViewController;
@property (nonatomic, weak) MAMapView *mapView;
@property (nonatomic, strong) NSArray *annotations;

@end

@implementation RouteShowViewController

- (id)initWithNavManager:(AMapNaviManager *)manager
          naviController:(AMapNaviViewController *)naviController mapView:(MAMapView *)mapView
{
    self = [super init];
    if (self)
    {
        self.actNaviManager     = manager;
        self.naviViewController = naviController;
        self.mapView            = mapView;
        self.annotations        = mapView.annotations;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    [self configMapView];
    [self configViewPanel];
}

#pragma mark - Utils

- (void)configViewPanel
{
    UIView *topView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreen_Width, kTopViewHeight)];
    [self.view addSubview:topView];
    
    UIButton *returnBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [returnBtn setImage:[UIImage imageNamed:@"return"] forState:UIControlStateNormal];
    [topView addSubview:returnBtn];
    returnBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self clearMapView];
        [self dismissViewControllerAnimated:YES completion:nil];
        return [RACSignal empty];
    }];
    
    UILabel *titleLable = [[UILabel alloc]initWithFrame:CGRectMake(0, 10, 100, 30)];
    [titleLable setText:@"路径导航"];
    [titleLable setTextColor: [UIColor blackColor]];
    [titleLable setFont:[UIFont systemFontOfSize:20.0]];
    [titleLable setTextAlignment:NSTextAlignmentCenter];
    [topView addSubview:titleLable];
    
    UIView *bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, kScreen_Height - kButtomViewHeight, kScreen_Width, kButtomViewHeight)];
    [self.view addSubview:bottomView];
    
    UILabel *distanceLabel = [[UILabel alloc ] initWithFrame:CGRectMake(0, 0, kScreen_Width, 20)];
    distanceLabel.font = [UIFont boldSystemFontOfSize: 16.0];
    distanceLabel.textColor = [UIColor blackColor];
    distanceLabel.lineBreakMode = NSLineBreakByWordWrapping;
    distanceLabel.numberOfLines = 0;
    [distanceLabel setText:[NSString stringWithFormat: @"全程 %@      需时 %@",[self distanceFormatted:_actNaviManager.naviRoute.routeLength],[self timeFormatted:_actNaviManager.naviRoute.routeTime]]];
    [bottomView addSubview:distanceLabel];
    
    UIButton *routeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [routeBtn setTitle:@"开始导航" forState:UIControlStateNormal];
    [routeBtn setBackgroundColor:[UIColor colorWithRed:13/255.0f green:95/255.0f blue:255/255.f alpha:1]];
    [routeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    routeBtn.titleLabel.font = [UIFont boldSystemFontOfSize: 18.0];
    [routeBtn setFrame:CGRectMake(0, 5, kScreen_Width, 40)];
    [bottomView addSubview:routeBtn];
    routeBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self.actNaviManager presentNaviViewController:self.naviViewController animated:YES];
        return [RACSignal empty];
    }];
    
    __weak UIView* superView = self.view;
    
    [titleLable mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(topView.mas_centerX);
        make.centerY.mas_equalTo(topView.mas_centerY).offset(8);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width, 50));
    }];
    
    [returnBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(topView.mas_centerY).offset(8);
        make.left.mas_equalTo(superView.mas_left).offset(16);
    }];
    
    [distanceLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(bottomView.top).with.offset(10);
        make.left.mas_equalTo(bottomView.top).with.offset(10);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width, 40));
    }];
    
    [routeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(bottomView.mas_bottom);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width,60));
    }];
}

- (void)configMapView
{
    [self.mapView setFrame:CGRectMake(0, kTopViewHeight,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - kTopViewHeight - kButtomViewHeight)];
    [self.view insertSubview:self.mapView atIndex:0];
    
    [self.mapView setShowsUserLocation:YES];
    [self.mapView addAnnotations:_annotations];
    [self showRouteWithNaviRoute:_actNaviManager.naviRoute];
}

- (void)showRouteWithNaviRoute:(AMapNaviRoute *)naviRoute
{
    if (naviRoute == nil)
    {
        return;
    }
    
    [self.mapView removeOverlays:self.mapView.overlays];
    
    NSUInteger coordianteCount = [naviRoute.routeCoordinates count];
    CLLocationCoordinate2D coordinates[coordianteCount];
    for (int i = 0; i < coordianteCount; i++)
    {
        AMapNaviPoint *aCoordinate = [naviRoute.routeCoordinates objectAtIndex:i];
        coordinates[i] = CLLocationCoordinate2DMake(aCoordinate.latitude, aCoordinate.longitude);
    }
    
    MAPolyline *polyline = [MAPolyline polylineWithCoordinates:coordinates count:coordianteCount];
    [self.mapView addOverlay:polyline];
    
//    [self.mapView setVisibleMapRect:[CommonUtility minMapRectForAnnotations:self.mapView.annotations] animated:YES];
    [self.mapView setVisibleMapRect:[CommonUtility minMapRectForAnnotations:self.mapView.annotations]
                        edgePadding:UIEdgeInsetsMake(RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge)
                           animated:YES];
}

#pragma mark - Utility

- (void)clearMapView
{
//    self.mapView.showsUserLocation = NO;
    
//    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    
//    self.mapView.delegate = nil;
}

#pragma mark - Handle Action

- (void)returnAction
{
    [self clearMapView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)timeFormatted:(long)totalSeconds
{
    //    long seconds = totalSeconds % 60;
    long minutes = (totalSeconds / 60) % 60;
    long hours = totalSeconds / 3600;
    if (hours == 0) {
        return [NSString stringWithFormat:@"%02ld分钟", minutes];
    }else{
        if (hours <= 9) {
            return [NSString stringWithFormat:@"%01ld小时%02ld分钟",hours, minutes];
        }
        return [NSString stringWithFormat:@"%02ld小时%02ld分钟",hours, minutes];

    }
    return @"";
}

- (NSString *)distanceFormatted:(float)totalMeters
{
    if (totalMeters < 1000) {
        return [NSString stringWithFormat:@"%0.2f米", totalMeters];
    }else{
        float km = totalMeters / 1000;
        return [NSString stringWithFormat:@"%0.2f公里",km];
    }
    return @"";
}

@end

//
//  MARouteShowViewController.m
//  officialDemoNavi
//
//  Created by LiuX on 14-9-2.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import "RouteShowViewController.h"

#define kBottomPaneHeight 60.0

@interface RouteShowViewController ()

@property (nonatomic, strong) AMapNaviManager *actNaviManager;
@property (nonatomic, strong) AMapNaviViewController *naviViewController;

@property (nonatomic, weak) MAMapView *mapView;
@property (nonatomic, strong) UIView *bottomPanel;

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
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self configBottomPanel];
}

#pragma mark - Utils

- (void)configBottomPanel
{
    [_bottomPanel removeFromSuperview];
    
    _bottomPanel = [[UIView alloc] initWithFrame:
                    CGRectMake(0, self.view.height - kBottomPaneHeight, self.view.width, kBottomPaneHeight)];
    [self.view addSubview:_bottomPanel];

    
    UILabel *titlabel = [self createTitleLabel:[NSString stringWithFormat: @"全程：%@ / %@",
                                                [self distanceFormatted:_actNaviManager.naviRoute.routeLength], [self timeFormatted:_actNaviManager.naviRoute.routeTime]]];
    titlabel.frame = CGRectMake(20, 25, titlabel.width, titlabel.height);
    [_bottomPanel addSubview:titlabel];
    
    UIButton *routeBtn = [self createToolButton];
    [routeBtn setTitle:@"开始导航" forState:UIControlStateNormal];
    [routeBtn setFrame:CGRectMake(kScreen_Width-120, 5, 100, 50)];
    [_bottomPanel addSubview:routeBtn];
    routeBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self.actNaviManager presentNaviViewController:self.naviViewController animated:YES];
        return [RACSignal empty];
    }];
    
    UIButton *returnBtn = [self createToolButton];
    [returnBtn setBackgroundColor:[UIColor whiteColor]];
    returnBtn.titleLabel.font = [UIFont systemFontOfSize: 16.0];
    [returnBtn setTitle:@"返回" forState:UIControlStateNormal];
    [returnBtn setFrame:CGRectMake(10, 50, 80, 40)];
    [self.view addSubview:returnBtn];
    returnBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self clearMapView];
        [self dismissViewControllerAnimated:YES completion:nil];
        return [RACSignal empty];
    }];
}

- (void)configMapView
{
    [self.mapView setFrame:CGRectMake(0, 0, self.view.width, self.view.height - kBottomPaneHeight)];
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
    [self.mapView setVisibleMapRect:[polyline boundingMapRect] animated:NO];
//    [self.mapView setCenterCoordinate:userLocation.coordinate];

    if (_actNaviManager.naviRoute.routeLength < 1000 *20) {
        [self.mapView setZoomLevel:13 animated:YES];
    }else if (_actNaviManager.naviRoute.routeLength < 1000 *50) {
        [self.mapView setZoomLevel:12 animated:YES];
    }else if (_actNaviManager.naviRoute.routeLength < 1000 *100) {
        [self.mapView setZoomLevel:11 animated:YES];
    }else if (_actNaviManager.naviRoute.routeLength < 1000 *300) {
        [self.mapView setZoomLevel:9 animated:YES];
    }else if (_actNaviManager.naviRoute.routeLength < 1000 *1000) {
        [self.mapView setZoomLevel:7 animated:YES];
    }else if (_actNaviManager.naviRoute.routeLength < 1000 *2000) {
        [self.mapView setZoomLevel:6 animated:YES];
    }
    else if (_actNaviManager.naviRoute.routeLength < 1000 *3000) {
        [self.mapView setZoomLevel:5 animated:YES];
    }else if (_actNaviManager.naviRoute.routeLength < 1000 *5000) {
        [self.mapView setZoomLevel:4 animated:YES];
    }else{
        [self.mapView setZoomLevel:[self.mapView minZoomLevel] animated:YES];
    }
}

#pragma mark - Utils

- (UILabel *)createTitleLabel:(NSString *)title
{
    UILabel *titleLabel = [[UILabel alloc] init];
    
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.font = [UIFont systemFontOfSize:14];
    titleLabel.text = title;
    [titleLabel sizeToFit];
    
    return titleLabel;
}

- (UIButton *)createToolButton
{
    UIButton *toolBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    
    toolBtn.layer.borderColor  = [UIColor lightGrayColor].CGColor;
    toolBtn.layer.borderWidth  = 0.5;
    toolBtn.layer.cornerRadius = 5;
    
    [toolBtn setBounds:CGRectMake(0, 0, 70, 30)];
    [toolBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    toolBtn.titleLabel.font = [UIFont systemFontOfSize: 14.0];
    
    return toolBtn;
}

#pragma mark - Utility

- (void)clearMapView
{
//    self.mapView.showsUserLocation = NO;
    
    [self.mapView removeAnnotations:self.mapView.annotations];
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

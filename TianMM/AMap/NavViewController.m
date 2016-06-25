//
//  ZongheShowViewController.m
//  officialDemoNavi
//
//  Created by LiuX on 14-9-1.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import "NavViewController.h"
#import "NavPointAnnotation.h"
#import "RouteShowViewController.h"
#import "MoreMenuView.h"
#import "GeocodeAnnotation.h"
#import "CustomPolyline.h"
#import "BusRouteVc.h"
#import "CustomAnnotationView.h"
#import "BusRouteVc.h"
#import "BusLineModel.h"
#import "BuildBusAnnotationView.h"

#define kDefaultCalloutViewMargin       -8
#define kSetingViewHeight   145

typedef NS_ENUM(NSInteger, NavigationTypes)
{
    NavigationTypeNone = 0,
    NavigationTypeSimulator, // 模拟导航
    NavigationTypeGPS,       // 实时导航
};


typedef NS_ENUM(NSInteger, TravelTypes)
{
    TravelTypeCar = 0,    // 驾车方式
    TravelTypeWalk,       // 步行方式
    TravelTypeBus,       // 公交方式
    TravelTypeNone,
};

@interface NavViewController () <AMapNaviViewControllerDelegate,
                                        UIGestureRecognizerDelegate,
                                        MoreMenuViewDelegate,AMapSearchDelegate>
{
    NavigationTypes     _naviType;
    TravelTypes         _travelType;
    
    BOOL _hasCurrLoc;
    UITapGestureRecognizer *_mapViewTapGesture;
    
    CLLocation *_currentLocation;
}

@property (nonatomic, strong) AMapNaviViewController *naviViewController;
@property (nonatomic, strong) NavPointAnnotation *beginAnnotation;
@property (nonatomic, strong) NavPointAnnotation *endAnnotation;
@property (nonatomic, weak) RouteShowViewController *routeShowVC;
@property (nonatomic, weak) BusRouteVc *busRouteVC;

@property (nonatomic, strong) MoreMenuView *moreMenuView;
@property (nonatomic, strong) AMapSearchAPI *search;

@property (nonatomic, strong) UISegmentedControl *segCtrl;
@property (nonatomic, strong) UILabel *startPointLabel;
@property (nonatomic, strong) UILabel *endPointLabel;

@property (nonatomic, strong) NSMutableArray *busPointArr;
@property (nonatomic, strong) NSMutableArray *busDetailArr;

@end

@implementation NavViewController

#pragma mark - Life Cycle

- (id)init
{
    self = [super init];
    if (self)
    {
        [self initTravelType];
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0) {
            [self.naviManager setAllowsBackgroundLocationUpdates:YES];
        }
        _search = [[AMapSearchAPI alloc] init];
        _search.delegate = self;
        
        _busPointArr = [[NSMutableArray alloc]initWithCapacity:20];
        _busDetailArr = [[NSMutableArray alloc]initWithCapacity:20];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initNaviViewController];
    [self configSettingViews];
    [self initGestureRecognizer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.routeShowVC) {
        self.routeShowVC = nil;
    }
    if (self.busRouteVC) {
        self.busRouteVC = nil;
    }
    [self configMapView];
    [self initSettingState];
    [self SetDestinationGeo:_in_Address];
    
    [_segCtrl setSelectedSegmentIndex:UISegmentedControlNoSegment];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.mapView removeGestureRecognizer:_mapViewTapGesture];
}

#pragma mark initSetting
- (void)initTravelType
{
    _travelType = TravelTypeCar;
}

- (void)initNaviViewController
{
    if (_naviViewController == nil)
    {
        _naviViewController = [[AMapNaviViewController alloc] initWithMapView:self.mapView delegate:self];
    }
}

- (void)initGestureRecognizer
{
    _mapViewTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
}

- (void)initSettingState
{
    _beginAnnotation = nil;
    _endAnnotation   = nil;
    
    [self.mapView removeAnnotations:self.mapView.annotations];
    _naviType = NavigationTypeNone;
}

- (void)initMoreMenuView
{
    _moreMenuView = [[MoreMenuView alloc] initWithFrame:self.naviViewController.view.bounds];
    _moreMenuView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _moreMenuView.delegate = self;
}

#pragma mark configView
- (void)configMapView
{
    [self.mapView setDelegate:self];
    [self.mapView setFrame:CGRectMake(0, kSetingViewHeight,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - kSetingViewHeight)];
    
    [self.view insertSubview:self.mapView atIndex:0];
    [self.mapView addGestureRecognizer:_mapViewTapGesture];
    _hasCurrLoc = NO;
    
    self.mapView.showsUserLocation = YES;
    self.mapView.showsCompass= YES; // 设置成NO表示关闭指南针；YES表示显示指南针
    
    self.mapView.compassOrigin= CGPointMake(self.mapView.compassOrigin.x, 22); //设置指南针位置
    self.mapView.showsScale= YES;  //设置成NO表示不显示比例尺；YES表示显示比例尺
    
    self.mapView.scaleOrigin= CGPointMake(self.mapView.scaleOrigin.x, 22);  //设置比例尺位置
    self.mapView.zoomEnabled = YES;
    self.mapView.rotateCameraEnabled= NO;
}

- (void)configSettingViews
{
    _segCtrl = [[UISegmentedControl alloc] initWithItems:@[@"驾车" , @"步行" , @"公交车"]];
    _segCtrl.tintColor = [UIColor lightGrayColor];
    
    [_segCtrl setBounds:CGRectMake (0 ,0 ,240 ,40)];
    [_segCtrl setTitleTextAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:17],NSForegroundColorAttributeName:[UIColor colorWithRed:106/255.0f green:108/255.0f blue:106/255.0f alpha:1]}
                           forState:UIControlStateNormal];
    
    _segCtrl.left                 = (self.view.width - 240)/2;
    _segCtrl.top                  = 40;
    [self.view addSubview:_segCtrl];
    
    [[_segCtrl rac_newSelectedSegmentIndexChannelWithNilValue:nil] subscribeNext:^(NSNumber *segment) {
        _travelType = segment.integerValue;
        
        if (_travelType == TravelTypeBus) {
            _naviType = NavigationTypeNone;
            [self QueryBusLine];
        }else{
            _naviType = NavigationTypeGPS;
            [self calRoute];
        }
    }];
    
    _startPointLabel = [self createTitleLabel:@"从：我的位置"];
    _startPointLabel.left     = 25;
    _startPointLabel.top      = 90;
    [_startPointLabel setTextColor: [UIColor colorWithRed:54/255.0f green:138/255.0f blue:255/255.0f alpha:1]];
    [self.view addSubview:_startPointLabel];
    
    _endPointLabel = [self createTitleLabel:[NSString stringWithFormat:@"到：%@" ,_in_Address]];
    [_endPointLabel setTextColor: [UIColor colorWithRed:106/255.0f green:108/255.0f blue:106/255.0f alpha:1]];

    [_endPointLabel setFrame:CGRectMake(0, 0, kScreen_Width, 30)];
    _endPointLabel.left     = 25;
    _endPointLabel.top      = 115;
    [self.view addSubview:_endPointLabel];
    
    UIButton *routeBtn = [self createToolButton];
    [routeBtn setTitle:@"退出" forState:UIControlStateNormal];
    
    [routeBtn setBackgroundColor:[UIColor colorWithRed:240/255.0f green:43/255.0f blue:30/255.0f alpha:1]];
    [routeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [routeBtn setFrame:CGRectMake(kScreen_Width - 60, 48, 50, 25)];
    [self.view addSubview:routeBtn];
    
    routeBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return [RACSignal empty];
    }];
}

#pragma mark - Helpers
- (CGSize)offsetToContainRect:(CGRect)innerRect inRect:(CGRect)outerRect
{
    CGFloat nudgeRight = fmaxf(0, CGRectGetMinX(outerRect) - (CGRectGetMinX(innerRect)));
    CGFloat nudgeLeft = fminf(0, CGRectGetMaxX(outerRect) - (CGRectGetMaxX(innerRect)));
    CGFloat nudgeTop = fmaxf(0, CGRectGetMinY(outerRect) - (CGRectGetMinY(innerRect)));
    CGFloat nudgeBottom = fminf(0, CGRectGetMaxY(outerRect) - (CGRectGetMaxY(innerRect)));
    return CGSizeMake(nudgeLeft ?: nudgeRight, nudgeTop ?: nudgeBottom);
}

#pragma mark - 查询函数
- (void)SetDestinationGeo:(NSString *)address{
    AMapGeocodeSearchRequest *geo = [[AMapGeocodeSearchRequest alloc] init];
    geo.address = address;
    
    [_search AMapGeocodeSearch: geo];
}

- (void)QueryBusLine{
    [self reGeoAction];
}

- (void)reGeoAction
{
    if (_endAnnotation)
    {
        AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
        request.location = [AMapGeoPoint locationWithLatitude:_endAnnotation.coordinate.latitude longitude:_endAnnotation.coordinate.longitude];
        request.requireExtension = YES;
        [_search AMapReGoecodeSearch:request];
    }
}

#pragma mark - AMapSearchDelegate
- (void)searchRequest:(id)request didFailWithError:(NSError *)error
{
    DDLogError(@"request :%@, error :%@", request, error);
}

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
{
    if (_travelType == TravelTypeBus) {
        AMapTransitRouteSearchRequest *request = [[AMapTransitRouteSearchRequest alloc] init];
        request.origin = [AMapGeoPoint locationWithLatitude:_currentLocation.coordinate.latitude longitude:_currentLocation.coordinate.longitude];
        request.destination = [AMapGeoPoint locationWithLatitude:_endAnnotation.coordinate.latitude longitude:_endAnnotation.coordinate.longitude];
        request.city = response.regeocode.addressComponent.city;
        request.strategy = 2;//最少换乘模式
        request.requireExtension = YES;
        [_search AMapTransitRouteSearch: request];
    }else{
        NSString *title = response.regeocode.addressComponent.city;
        if (title.length == 0)
        {
            title = response.regeocode.addressComponent.province;
        }
        _endAnnotation.navPointType = NavPointAnnotationEnd;
        // 更新我的位置title
        _endAnnotation.title = title;
        _endAnnotation.subtitle = response.regeocode.formattedAddress;
        [self.mapView addAnnotation:_endAnnotation];
        
    }
    [_endPointLabel setText:[NSString stringWithFormat:@"终点：%@" ,response.regeocode.formattedAddress]];
}

- (void)onGeocodeSearchDone:(AMapGeocodeSearchRequest *)request response:(AMapGeocodeSearchResponse *)response
{
    if (response.geocodes.count == 0)
    {
        return;
    }
    
    NSMutableArray *annotations = [NSMutableArray array];
    
    [response.geocodes enumerateObjectsUsingBlock:^(AMapGeocode *obj, NSUInteger idx, BOOL *stop) {
        GeocodeAnnotation *geocodeAnnotation = [[GeocodeAnnotation alloc] initWithGeocode:obj];
        [annotations addObject:geocodeAnnotation];
    }];
    
    if (annotations.count == 1)
    {
        [self.mapView setCenterCoordinate:[(GeocodeAnnotation*)annotations[0] coordinate] animated:YES];
    }
    else
    {
        [self.mapView setVisibleMapRect:[CommonUtility minMapRectForAnnotations:annotations]
                               animated:YES];
    }
    _endAnnotation = [[NavPointAnnotation alloc] init];
    [_endAnnotation setCoordinate:[(GeocodeAnnotation*)annotations[0] coordinate]];
    
    _endAnnotation.navPointType = NavPointAnnotationEnd;
    _endAnnotation.title = _in_Address;
    [self.mapView addAnnotation:_endAnnotation];
}

//实现路径搜索的回调函数
- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response
{
    [_busDetailArr removeAllObjects];
    [_busPointArr removeAllObjects];
    if(response.route == nil)
    {
        return;
    }
    
    for (int i = 0; i < response.count; ++i) {
        NSMutableArray *pointArr = [[NSMutableArray alloc]initWithCapacity:20];
        NSMutableArray *busArr = [[NSMutableArray alloc]initWithCapacity:20];
        AMapTransit *trans = (AMapTransit*)response.route.transits[i];

        for (int j = 0; j< [trans.segments count]; ++j) {
            AMapSegment *segment = trans.segments[j];
            
            AMapWalking *walking = segment.walking;
            for (int q = 0; q < [walking.steps count]; ++q) {
                AMapStep *step = walking.steps[q];
                PolyLineModel *polyModel = [[PolyLineModel alloc]initLine:step.polyline LineType:LineStyleWalk Distance:step.distance];
                [pointArr addObject:polyModel];
//                NSLog(@"%ld,%@,%@,%ld",(long)trans.walkingDistance,step.instruction,step.road,(long)step.distance);
            }
            
            for (int p = 0; p < [segment.buslines count];++p) {
                AMapBusLine * busLine = segment.buslines[p];
                PolyLineModel *polyModel = [[PolyLineModel alloc]initLine:busLine.polyline LineType:[self GetLineType:busLine.type] Distance:0];
                [pointArr addObject:polyModel];
                
                BusLineModel *lineModel = [[BusLineModel alloc]initBusDetail:i name:busLine.name departureStop:busLine.departureStop.name arrivalStop:busLine.arrivalStop.name duration:busLine.duration distance:busLine.distance totalPrice:trans.cost departurelocation:busLine.departureStop.location arrivallocation:busLine.arrivalStop.location viaBusStopCount:[busLine.viaBusStops count]];
                [busArr addObject:lineModel];
//                DDLogDebug(@"[%d],%@,%@,%@,%ld",i,busLine.type,busLine.departureStop.name,busLine.arrivalStop.name,[busLine.viaBusStops count]);
            }
        }
       [_busDetailArr addObject:busArr];
       [_busPointArr addObject:pointArr];
    }
    [self calRoute];
}

#pragma mark - Gesture Action

- (void)handleSingleTap:(UITapGestureRecognizer *)theSingleTap
{
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:[theSingleTap locationInView:self.mapView]
                                              toCoordinateFromView:self.mapView];
    // 添加标注
    if (_endAnnotation != nil)
    {
        // 清理
        [self.mapView removeAnnotation:_endAnnotation];
        _endAnnotation = nil;
    }
    
    _endAnnotation = [[NavPointAnnotation alloc] init];
    _endAnnotation.coordinate = coordinate;
    _travelType = TravelTypeNone;
    [self reGeoAction];
}

#pragma mark - Button Actions

- (void)simulatorNavi:(id)sender
{
    _naviType = NavigationTypeSimulator;
    
    [self calRoute];
}

- (void)calRoute
{
    NSArray *wayPoints;
    NSArray *endPoints;
    if (_endAnnotation)
    {
        endPoints = @[[AMapNaviPoint locationWithLatitude:_endAnnotation.coordinate.latitude
                                                longitude:_endAnnotation.coordinate.longitude]];
    }
    if (endPoints.count > 0)
    {
        if (_travelType == TravelTypeCar)
        {
            [self.naviManager calculateDriveRouteWithEndPoints:endPoints
                                                     wayPoints:wayPoints
                                               drivingStrategy:2];
        }
        else if (_travelType == TravelTypeWalk)
        {
            [self.naviManager calculateWalkRouteWithEndPoints:endPoints];
        }
        else if (_travelType == TravelTypeBus)
        {
            BusRouteVc *busVc = [[BusRouteVc alloc] initWithBus:_busPointArr busline:_busDetailArr  mapView:self.mapView endAnnotation:_endAnnotation];
            self.busRouteVC = busVc;
            
            [self presentViewController:busVc animated:YES completion:nil];
        }
        return;
    }
}

#pragma mark - MAMapView Delegate

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[NavPointAnnotation class]])
    {
        static NSString *reuseIndetifier = @"annotationReuseIndetifier";
        BuildBusAnnotationView *annotationView = (BuildBusAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuseIndetifier];
        if (annotationView == nil)
        {
            annotationView = [[BuildBusAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseIndetifier];
        }
        annotationView.canShowCallout = NO;
        annotationView.image = [UIImage imageNamed:@"restaurant"];

        // 设置中心点偏移，使得标注底部中间点成为经纬度对应点
        annotationView.centerOffset = CGPointMake(0, -18);
        [annotationView setShowTip];

        return annotationView;
    }
    if ([annotation isKindOfClass:[BusPointAnnotation class]])
    {
        static NSString *reuseIndetifier = @"busAnnotationReuseIndetifier";
        BuildBusAnnotationView *annotationView = (BuildBusAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuseIndetifier];
        if (annotationView == nil)
        {
            annotationView = [[BuildBusAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseIndetifier];
        }
        
        annotationView.canShowCallout = NO;
        annotationView.image = [UIImage imageNamed:@"pin"];
        
        // 设置中心点偏移，使得标注底部中间点成为经纬度对应点
        annotationView.centerOffset = CGPointMake(0, -18);
        [annotationView setShowTip];
        return annotationView;
    }
    return nil;
}

- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
    // 选中定位annotation的时候进行逆地理编码查询
    if ([view.annotation isKindOfClass:[MAUserLocation class]])
    {
        [self reGeoAction];
    }
    
    // 调整自定义callout的位置，使其可以完全显示
    if ([view isKindOfClass:[CustomAnnotationView class]]) {
        CustomAnnotationView *cusView = (CustomAnnotationView *)view;
        CGRect frame = [cusView convertRect:cusView.calloutView.frame toView:self.mapView];
        
        frame = UIEdgeInsetsInsetRect(frame, UIEdgeInsetsMake(kDefaultCalloutViewMargin, kDefaultCalloutViewMargin, kDefaultCalloutViewMargin, kDefaultCalloutViewMargin));
        
        if (!CGRectContainsRect(self.mapView.frame, frame))
        {
            CGSize offset = [self offsetToContainRect:frame inRect:self.mapView.frame];
            
            CGPoint theCenter = self.mapView.center;
            theCenter = CGPointMake(theCenter.x - offset.width, theCenter.y - offset.height);
            
            CLLocationCoordinate2D coordinate = [self.mapView convertPoint:theCenter toCoordinateFromView:self.mapView];
            
            [self.mapView setCenterCoordinate:coordinate animated:YES];
        }
    }
}

- (MAOverlayView *)mapView:(MAMapView *)mapView viewForOverlay:(id<MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[CustomPolyline class]])
    {
        CustomPolyline * polyline = (CustomPolyline * )overlay;
        MAPolylineView *polylineView = [[MAPolylineView alloc] initWithPolyline:overlay];
        polylineView.lineWidth = 4.0f;
        if (polyline.lineType == LineStyleBus) {
            polylineView.strokeColor = [UIColor magentaColor];
        }else if (polyline.lineType == LineStyleMetro){
            polylineView.strokeColor = [UIColor purpleColor];
        }
        else{
            polylineView.strokeColor = [UIColor greenColor];
            polylineView.lineDash = YES;
        }
        return polylineView;
    }else{
        if ([overlay isKindOfClass:[MAPolyline class]])
        {
            MAPolylineView *polylineView = [[MAPolylineView alloc] initWithPolyline:overlay];
            
            polylineView.lineWidth = 4.0f;
            polylineView.strokeColor = [UIColor magentaColor];
            return polylineView;
        }
    }
    return nil;
}

- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
    if (!_hasCurrLoc)
    {
        _hasCurrLoc = YES;
    
        [self.mapView setCenterCoordinate:userLocation.coordinate];
        [self.mapView setZoomLevel:12 animated:NO];
        _currentLocation = [userLocation.location copy];
    }
}

#pragma mark - AMapNaviManager Delegate
- (void)naviManager:(AMapNaviManager *)naviManager didPresentNaviViewController:(UIViewController *)naviViewController
{
    [super naviManager:naviManager didPresentNaviViewController:naviViewController];
    
    if (_naviType == NavigationTypeGPS)
    {
        [self.naviManager startGPSNavi];
    }
    else if (_naviType == NavigationTypeSimulator)
    {
        [self.naviManager startEmulatorNavi];
    }
}

- (void)naviManager:(AMapNaviManager *)naviManager didDismissNaviViewController:(UIViewController *)naviViewController
{
    [super naviManager:naviManager didDismissNaviViewController:naviViewController];
    
    if (_naviType == NavigationTypeGPS)
    {
        [self.mapView setDelegate:self];
        [_routeShowVC configMapView];
    }
    else if (_naviType == NavigationTypeSimulator)
    {
        [self configMapView];
        [self initSettingState];
    }
}

- (void)naviManagerOnCalculateRouteSuccess:(AMapNaviManager *)naviManager
{
    [super naviManagerOnCalculateRouteSuccess:naviManager];
    if (_naviType == NavigationTypeGPS)
    {
        if (!_routeShowVC)
        {
            RouteShowViewController *routeShowVC = [[RouteShowViewController alloc] initWithNavManager:naviManager
                                                                                        naviController:_naviViewController
                                                                                               mapView:self.mapView];
            self.routeShowVC = routeShowVC;
//            routeShowVC.title = @"线路展示";
            [self presentViewController:routeShowVC animated:YES completion:nil];
        }
    }
    else if (_naviType == NavigationTypeSimulator)
    {
        [self.naviManager presentNaviViewController:self.naviViewController animated:YES];
    }
}

#pragma mark - AManNaviViewController Delegate

- (void)naviViewControllerCloseButtonClicked:(AMapNaviViewController *)naviViewController
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.iFlySpeechSynthesizer stopSpeaking];
    });
    
    [self.naviManager stopNavi];
    [self.naviManager dismissNaviViewControllerAnimated:YES];
}

- (void)naviViewControllerMoreButtonClicked:(AMapNaviViewController *)naviViewController
{
    if (_moreMenuView == nil)
    {
        [self initMoreMenuView];
    }
    
    [_moreMenuView setViewShowMode:naviViewController.viewShowMode];
    [_moreMenuView setShowNightType:naviViewController.showStandardNightType];
    
    [naviViewController.view addSubview:_moreMenuView];
}

- (void)naviViewControllerTurnIndicatorViewTapped:(AMapNaviViewController *)naviViewController
{
    [self.naviManager readNaviInfoManual];
}

#pragma mark - MoreMenuView Delegate

- (void)moreMenuViewFinishButtonClicked
{
    [_moreMenuView removeFromSuperview];
    
    _moreMenuView.delegate = nil;
    _moreMenuView = nil;
}

- (void)moreMenuViewViewModeChangeTo:(AMapNaviViewShowMode)viewShowMode
{
    if (self.naviViewController)
    {
        [self.naviViewController setViewShowMode:viewShowMode];
    }
}

- (void)moreMenuViewNightTypeChangeTo:(BOOL)isShowNightType
{
    if (self.naviViewController)
    {
        [self.naviViewController setShowStandardNightType:isShowNightType];
    }
}

#pragma mark createcontrol

- (UILabel *)createTitleLabel:(NSString *)title
{
    UILabel *titleLabel = [[UILabel alloc] init];
    
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.font          = [UIFont systemFontOfSize:15];
    titleLabel.text          = title;
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
    toolBtn.titleLabel.font = [UIFont systemFontOfSize: 13.0];
    
    return toolBtn;
}

#pragma mark  tool
-(int )GetLineType:(NSString*)str{
    int reVal = 0;
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:
                                              @"(\\S)*公交(\\S)*" options:0 error:nil];
    NSArray* match = [regularExpression matchesInString:str options:NSMatchingReportCompletion range:NSMakeRange(0, [str length])];
    if (match.count != 0)
    {
        reVal =  LineStyleBus;
    }else{
        regularExpression = [NSRegularExpression regularExpressionWithPattern:
                             @"(\\S)*地铁(\\S)*" options:0 error:nil];
        match = [regularExpression matchesInString:str options:NSMatchingReportCompletion range:NSMakeRange(0, [str length])];
        if (match.count != 0)
        {
            reVal =  LineStyleMetro;
        }
    }
    return reVal;
}

@end

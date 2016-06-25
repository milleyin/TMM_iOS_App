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
#import "BusRouteVc.h"
#import "BusLineModel.h"
#import "BuildBusAnnotationView.h"

#define kDefaultCalloutViewMargin       -8

typedef NS_ENUM(NSInteger, TravelTypes)
{
    TravelTypeCar = 0,    // 驾车方式
    TravelTypeBus,       // 公交方式
    TravelTypeWalk,       // 步行方式
    TravelTypeNone,
};

@interface NavViewController () <AMapNaviViewControllerDelegate, UIGestureRecognizerDelegate, AMapSearchDelegate,MoreMenuViewDelegate>
{
    TravelTypes         _travelType;
    
    BOOL _hasCurrLoc;
    UITapGestureRecognizer *_mapViewTapGesture;
    
    CLLocation *_currentLocation;
}

@property (nonatomic, strong) AMapNaviViewController *naviViewController;
@property (nonatomic, strong) NavPointAnnotation *endAnnotation;
@property (nonatomic, weak) RouteShowViewController *routeShowVC;
@property (nonatomic, weak) BusRouteVc *busRouteVC;

@property (nonatomic, strong) MoreMenuView *moreMenuView;
@property (nonatomic, strong) AMapSearchAPI *search;

@property (nonatomic, strong) UISegmentedControl *segCtrl;
@property (nonatomic, strong) UILabel *endPointLabel;

@property (nonatomic, strong) NSMutableArray *busPointArr;
@property (nonatomic, strong) NSMutableArray *busDetailArr;

@end

@implementation NavViewController

#pragma mark - Life Cycle

- (id)initLocParam:(NSDictionary*)locDic{
    self = [super init];
    if (self) {
        _in_Address = [[NSString alloc]initWithString:[locDic valueForKey:@"address"]];
        _in_city = [[NSString alloc]initWithString:[locDic valueForKey:@"city"]];
        _in_longitude = [[locDic valueForKey:@"lng"] doubleValue];
        _in_latitude = [[locDic valueForKey:@"lat"] doubleValue];
        
        _travelType = TravelTypeCar;
        _hasCurrLoc = NO;
        _search = [[AMapSearchAPI alloc] init];
        
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
    [self SetDestination];
    
    [_segCtrl setSelectedSegmentIndex:UISegmentedControlNoSegment];
}

#pragma mark initSetting

- (void)initNaviViewController
{
    if (_naviViewController == nil)
    {
        _naviViewController = [[AMapNaviViewController alloc] initWithMapView:self.mapView delegate:self];
    }
}

- (void)initSettingState
{
    _endAnnotation   = nil;
    [self.mapView removeAnnotations:self.mapView.annotations];
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
    [self.mapView setFrame:CGRectMake(0, kTopViewHeight,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - kTopViewHeight - kButtomViewHeight)];
    
    [self.view insertSubview:self.mapView atIndex:0];
    
    self.mapView.showsUserLocation = YES;
    self.mapView.showsCompass= YES; // 设置成NO表示关闭指南针；YES表示显示指南针
    
    self.mapView.compassOrigin= CGPointMake(self.mapView.compassOrigin.x, 22); //设置指南针位置
    self.mapView.showsScale= YES;  //设置成NO表示不显示比例尺；YES表示显示比例尺
    
    self.mapView.scaleOrigin= CGPointMake(self.mapView.scaleOrigin.x, 22);  //设置比例尺位置
    self.mapView.zoomEnabled = YES;
    self.mapView.rotateEnabled = NO;
    self.mapView.rotateCameraEnabled= NO;
    
    _search.delegate = self;
}

- (void)configSettingViews
{
    UIView *topView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreen_Width, kTopViewHeight)];
    [self.view addSubview:topView];
    
    UILabel *titleLable = [[UILabel alloc]initWithFrame:CGRectMake(0, 10, 100, 30)];
    [titleLable setText:@"出行方式"];
    [titleLable setTextColor: [UIColor blackColor]];
    [titleLable setFont:[UIFont systemFontOfSize:20.0]];
    [titleLable setTextAlignment:NSTextAlignmentCenter];
    [topView addSubview:titleLable];

    UIButton *exitBtn =  [UIButton buttonWithType:UIButtonTypeCustom];
    [exitBtn setTitle:@"退出导航" forState:UIControlStateNormal];
    [exitBtn setBackgroundColor:[UIColor clearColor]];
    exitBtn.titleLabel.font = [UIFont systemFontOfSize: 16.0];
    [exitBtn setTitleColor:[UIColor colorWithRed:248/255.0f green:72/255.0f blue:83/255.0f alpha:1] forState:UIControlStateNormal];
    [topView addSubview:exitBtn];
    
    exitBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self returnAction];
        return [RACSignal empty];
    }];
    
    UIView *bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, kScreen_Height - kButtomViewHeight, kScreen_Width, kButtomViewHeight)];
    [self.view addSubview:bottomView];
    
    UIImage *startImg = [UIImage imageNamed:@"startPoint"];
    UIImageView *startImgView = [[UIImageView alloc]initWithImage:startImg];
    [startImgView setFrame:CGRectMake(0, 0, startImg.size.width, startImg.size.height)];
    [bottomView addSubview:startImgView];
    
    UILabel *startPointLabel = [[UILabel alloc ] initWithFrame:CGRectMake(0, 0, 20, 20)];
    UITapGestureRecognizer *tapRecognizerStartPoine=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleStartPointTap:)];
    startPointLabel.userInteractionEnabled=YES;
    [startPointLabel addGestureRecognizer:tapRecognizerStartPoine];
    startPointLabel.lineBreakMode = NSLineBreakByWordWrapping;
    startPointLabel.numberOfLines = 0;
    [startPointLabel setText:@"当前位置"];
    [startPointLabel setTextAlignment:NSTextAlignmentCenter];
    [startPointLabel setTextColor: [UIColor blackColor]];
    [startPointLabel setFont:[UIFont boldSystemFontOfSize:17]];
    [bottomView addSubview:startPointLabel];
    
    UIView   *vFrameView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1 ,70)] ;
    vFrameView.layer.borderWidth = 1;
    vFrameView.layer.borderColor = [[UIColor colorWithRed:212/255.0f green:213/255.0f  blue:212/255.0f  alpha:1] CGColor];
    [bottomView addSubview:vFrameView];
    
    UIImage *endImg = [UIImage imageNamed:@"endPoint"];
    UIImageView *endImgView = [[UIImageView alloc]initWithImage:endImg];
    [endImgView setFrame:CGRectMake(0, 0, endImg.size.width, endImg.size.height)];
    [bottomView addSubview:endImgView];
    
    _endPointLabel = [[UILabel alloc ] initWithFrame:CGRectMake(0, 0, 20, 50)];
    UITapGestureRecognizer *tapRecognizerEndPoine=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleEndPointTap:)];
    _endPointLabel.userInteractionEnabled=YES;
    [_endPointLabel addGestureRecognizer:tapRecognizerEndPoine];
    _endPointLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _endPointLabel.numberOfLines = 0;
    [_endPointLabel setText:self.in_Address];
    [_endPointLabel setTextAlignment:NSTextAlignmentCenter];
    [_endPointLabel setTextColor: [UIColor blackColor]];
    [_endPointLabel setFont:[UIFont boldSystemFontOfSize:15]];
    [bottomView addSubview:_endPointLabel];
    
    UIView   *hFrameView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreen_Width ,1)] ;
    hFrameView.layer.borderWidth = 1;
    hFrameView.layer.borderColor = [[UIColor colorWithRed:212/255.0f green:213/255.0f  blue:212/255.0f  alpha:1] CGColor];
    [bottomView addSubview:hFrameView];
    
    _segCtrl = [[UISegmentedControl alloc] initWithItems:@[@"自驾" , @"公交" , @"步行"]];
    _segCtrl.tintColor = [UIColor colorWithRed:19/255.0f green:103/255.0f blue:255/255.0f alpha:1];
    [_segCtrl setBounds:CGRectMake (0 ,0 ,240 ,40)];
    [_segCtrl setTitleTextAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:17],NSForegroundColorAttributeName:[UIColor colorWithRed:13/255.0f green:95/255.0f blue:255/255.0f alpha:1]}
                            forState:UIControlStateNormal];
    [bottomView addSubview:_segCtrl];
    
    [[_segCtrl rac_newSelectedSegmentIndexChannelWithNilValue:nil] subscribeNext:^(NSNumber *segment) {
        _travelType = segment.integerValue;
        if (_travelType == TravelTypeBus) {
            [self QueryBusLine];
        }else{
            [self calRoute];
        }
    }];
    
    __weak UIView* superView = self.view;
    
    [titleLable mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(topView.mas_centerX);
        make.centerY.mas_equalTo(topView.mas_centerY).offset(8);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width, 50));
    }];
    
    [exitBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(topView.mas_centerY).offset(8);
        make.right.mas_equalTo(superView.mas_right).offset(-6);
        make.size.mas_equalTo(CGSizeMake(100, 50));
    }];
    
    [startImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(bottomView.mas_top).offset(15);
        make.centerX.mas_equalTo(superView.mas_centerX).offset(-kScreen_Width/4);
    }];
    
    [startPointLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(startImgView.mas_bottom);
        make.centerX.mas_equalTo(startImgView.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width/2, 40));
    }];
    
    [vFrameView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(bottomView.mas_top).offset(4);
        make.centerX.mas_equalTo(superView.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(1, 70));
    }];
    
    
    [endImgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(bottomView.mas_top).offset(15);
        make.centerX.mas_equalTo(superView.mas_centerX).offset(kScreen_Width/4);
    }];
    
    [_endPointLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(endImgView.mas_bottom);
        make.centerX.mas_equalTo(endImgView.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width/2, 40));
    }];
    
    [hFrameView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(_segCtrl.mas_top).offset(-10);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width ,1));
    }];

    [_segCtrl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(bottomView.mas_bottom).offset(-10);
        make.centerX.mas_equalTo(bottomView.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(kScreen_Width - 60, 40));
    }];
}

//#pragma mark - Gesture Action
- (void)handleStartPointTap:(UITapGestureRecognizer *)theSingleTap
{
    [self.mapView setCenterCoordinate:_currentLocation.coordinate animated:YES];
    [self.mapView setZoomLevel:12 animated:YES];
}

- (void)handleEndPointTap:(UITapGestureRecognizer *)theSingleTap
{
    [self.mapView setCenterCoordinate:_endAnnotation.coordinate animated:YES];
    [self.mapView setZoomLevel:12 animated:YES];
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
- (void)SetDestination{
    [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(self.in_latitude, self.in_longitude) animated:YES];
    _endAnnotation = [[NavPointAnnotation alloc] init];
    [_endAnnotation setCoordinate:CLLocationCoordinate2DMake(self.in_latitude, self.in_longitude)];

    _endAnnotation.title = self.in_Address;
    _endAnnotation.subtitle = self.in_Address;
    [self.mapView addAnnotation:_endAnnotation];
    
    [_endPointLabel setText:[NSString stringWithFormat:@"%@" ,self.in_Address]];

//    AMapGeocodeSearchRequest *geo = [[AMapGeocodeSearchRequest alloc] init];
//    geo.address = address;
//    [_search AMapGeocodeSearch: geo];
}

- (void)QueryBusLine{
    AMapTransitRouteSearchRequest *request = [[AMapTransitRouteSearchRequest alloc] init];
    request.origin = [AMapGeoPoint locationWithLatitude:_currentLocation.coordinate.latitude longitude:_currentLocation.coordinate.longitude];
    request.destination = [AMapGeoPoint locationWithLatitude:_endAnnotation.coordinate.latitude longitude:_endAnnotation.coordinate.longitude];
    request.city = self.in_city;
    request.strategy = 2;//最少换乘模式
    request.requireExtension = YES;
    [_search AMapTransitRouteSearch: request];
//    [self reGeoAction];
}

//- (void)reGeoAction
//{
//    if (_endAnnotation)
//    {
//        AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
//        request.location = [AMapGeoPoint locationWithLatitude:_endAnnotation.coordinate.latitude longitude:_endAnnotation.coordinate.longitude];
//        request.requireExtension = YES;
//        [_search AMapReGoecodeSearch:request];
//    }
//}

#pragma mark - AMapSearchDelegate
- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error;
{
    [JDStatusBarNotification showWithStatus:@"算路失败，请检查网络。" dismissAfter:3 styleName:@"JDStatusBarStyleError"];
}

//- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
//{
//    if (_travelType == TravelTypeBus) {
//       
//    }else{
//        NSString *title = response.regeocode.addressComponent.city;
//        if (title.length == 0)
//        {
//            title = response.regeocode.addressComponent.province;
//        }
//        _endAnnotation.title = title;
//        _endAnnotation.subtitle = response.regeocode.formattedAddress;
//        [self.mapView addAnnotation:_endAnnotation];
//    }
//    [_endPointLabel setText:[NSString stringWithFormat:@"%@" ,response.regeocode.formattedAddress]];
//}

//- (void)onGeocodeSearchDone:(AMapGeocodeSearchRequest *)request response:(AMapGeocodeSearchResponse *)response
//{
//    if (response.geocodes.count == 0)
//    {
//        return;
//    }
//    
//    NSMutableArray *annotations = [NSMutableArray array];
//    [response.geocodes enumerateObjectsUsingBlock:^(AMapGeocode *obj, NSUInteger idx, BOOL *stop) {
//        GeocodeAnnotation *geocodeAnnotation = [[GeocodeAnnotation alloc] initWithGeocode:obj];
//        [annotations addObject:geocodeAnnotation];
//    }];
//    
//    if (annotations.count == 1)
//    {
//        [self.mapView setCenterCoordinate:[(GeocodeAnnotation*)annotations[0] coordinate] animated:YES];
//    }
//    else
//    {
//        [self.mapView setVisibleMapRect:[CommonUtility minMapRectForAnnotations:annotations] animated:YES];
//    }
//    _endAnnotation = [[NavPointAnnotation alloc] init];
//    [_endAnnotation setCoordinate:[(GeocodeAnnotation*)annotations[0] coordinate]];
//    
//    _endAnnotation.title = self.in_Address;
//    _endAnnotation.subtitle = self.in_Address;
//    [self.mapView addAnnotation:_endAnnotation];
//    
//    DDLogDebug(@"end:%f,%f",_endAnnotation.coordinate.latitude,_endAnnotation.coordinate.longitude);
//}

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
                if (p == 0) {  //有多种公交方案时只画第一条
                    AMapBusLine * busLine = segment.buslines[p];
                    PolyLineModel *polyModel = [[PolyLineModel alloc]initLine:busLine.polyline LineType:[self GetLineType:busLine.type] Distance:0];
                    [pointArr addObject:polyModel];
                    
                    BusLineModel *lineModel = [[BusLineModel alloc]initBusLine:busLine cost:trans.cost];
                    [busArr addObject:lineModel];
//                    DDLogDebug(@"[%d],[%d],[%d],%@,%@,%@,%ld",i,j,p,busLine.name,busLine.departureStop.name,busLine.arrivalStop.name,(unsigned long)[busLine.viaBusStops count]);
                }
            }
        }
        DDLogDebug(@"%@",busArr);
       [_busDetailArr addObject:busArr];
       [_busPointArr addObject:pointArr];
    }
    [self calRoute];
}

#pragma mark - Button Actions
- (void)calRoute
{
    NSArray *wayPoints;
    NSArray *endPoints;
    if (_endAnnotation)
    {
        endPoints = @[[AMapNaviPoint locationWithLatitude:_endAnnotation.coordinate.latitude longitude:_endAnnotation.coordinate.longitude]];
    }
    if (endPoints.count > 0)
    {
        if (_travelType == TravelTypeCar)
        {
            [self.naviManager calculateDriveRouteWithEndPoints:endPoints wayPoints:wayPoints drivingStrategy:2];
        }
        else if (_travelType == TravelTypeWalk)
        {
            [self.naviManager calculateWalkRouteWithEndPoints:endPoints];
        }
        else if (_travelType == TravelTypeBus)
        {
            BusRouteVc *busVc = [[BusRouteVc alloc] initWithBus:_busPointArr busline:_busDetailArr mapView:self.mapView endAnnotation:_endAnnotation];
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
        annotationView.image = [UIImage imageNamed:@"endAnnotation"];

        // 设置中心点偏移，使得标注底部中间点成为经纬度对应点
        annotationView.centerOffset = CGPointMake(0, 0);
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
        annotationView.image = [UIImage imageNamed:@"busAnnotation"];
        
        // 设置中心点偏移，使得标注底部中间点成为经纬度对应点
        annotationView.centerOffset = CGPointMake(0, 0);
        [annotationView setShowTip];
        return annotationView;
    }
    return nil;
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
        [self.mapView setVisibleMapRect:[CommonUtility minMapRectForAnnotations:self.mapView.annotations]
                            edgePadding:UIEdgeInsetsMake(RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge)
                               animated:YES];
//        [self.mapView setCenterCoordinate:userLocation.coordinate];
        [self.mapView setZoomLevel:8];

        _currentLocation = [userLocation.location copy];
    }
}

#pragma mark - AMapNaviManager Delegate
- (void)naviManager:(AMapNaviManager *)naviManager didPresentNaviViewController:(UIViewController *)naviViewController
{
    [super naviManager:naviManager didPresentNaviViewController:naviViewController];
    
    [self.naviManager startGPSNavi];
}

- (void)naviManager:(AMapNaviManager *)naviManager didDismissNaviViewController:(UIViewController *)naviViewController
{
    [super naviManager:naviManager didDismissNaviViewController:naviViewController];
    [self.mapView setDelegate:self];
    [_routeShowVC configMapView];
}

- (void)naviManagerOnCalculateRouteSuccess:(AMapNaviManager *)naviManager
{
    [super naviManagerOnCalculateRouteSuccess:naviManager];
    if (!_routeShowVC)
    {
        RouteShowViewController *routeShowVC = [[RouteShowViewController alloc] initWithNavManager:naviManager
                                                                                    naviController:_naviViewController
                                                                                           mapView:self.mapView];
        self.routeShowVC = routeShowVC;
        [self presentViewController:routeShowVC animated:YES completion:nil];
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

//
//  BusRouteVc.m
//  TianMM
//
//  Created by cocoa on 15/11/9.
//  Copyright © 2015年 cocoa. All rights reserved.
//
#import "BusRouteVc.h"
#import "CustomPolyline.h"
#import "NavPointAnnotation.h"

@interface BusRouteVc ()<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) NSArray *walkArrs;
@property (nonatomic, strong) MAPointAnnotation *in_endAnnotation;
@property (nonatomic, strong) NSArray *busDetail;
@property (nonatomic, strong) NSMutableArray *annotationArr;
@property (nonatomic, strong) NSMutableArray *polylinesArr;

@end

@implementation BusRouteVc

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    _annotationArr = [[ NSMutableArray alloc]initWithCapacity:100];
    _polylinesArr = [[ NSMutableArray alloc]initWithCapacity:20];

    UIView *topView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreen_Width, kTopViewHeight)];
    [self.view addSubview:topView];
    
    UIButton *returnBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [returnBtn setImage:[UIImage imageNamed:@"return.png"] forState:UIControlStateNormal];
    [topView addSubview:returnBtn];
    returnBtn.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [self returnAction];
        return [RACSignal empty];
    }];
    
    UILabel *titleLable = [[UILabel alloc]initWithFrame:CGRectMake(0, 10, 100, 30)];
    [titleLable setText:@"公交"];
    [titleLable setTextColor: [UIColor blackColor]];
    [titleLable setFont:[UIFont systemFontOfSize:20.0]];
    [titleLable setTextAlignment:NSTextAlignmentCenter];
    [topView addSubview:titleLable];
    
    CGRect rect = self.view.frame;
    rect.origin.y = kScreen_Height /2 + 100;
    rect.size.height = kScreen_Height/2 - 100;

    UITableView *tableView = [[UITableView alloc]initWithFrame:rect];
    [tableView setDataSource:self];
    [tableView setDelegate:self];
    tableView.rowHeight = 60;
    [self.view addSubview:tableView];
    
    [self configMapView];
    
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
}

- (id)initWithBus:(NSArray *)walkArrs busline:(NSArray *)busline mapView:(MAMapView *)mapView endAnnotation:(MAPointAnnotation*)endAnnotation{
    self = [super init];
    if (self)
    {
        self.mapView            = mapView;
        self.walkArrs           = walkArrs;
        self.in_endAnnotation   = endAnnotation;
        self.busDetail          = busline;
    }
    return self;
}

- (void)configMapView
{
    CGRect rect = self.view.frame;
    rect.origin.y = kTopViewHeight;
    rect.size.height = kScreen_Height/2 + 100 - kTopViewHeight;
    
    [self.mapView setFrame:rect];
    [self.view insertSubview:self.mapView atIndex:0];
    
    [self.mapView setShowsUserLocation:YES];
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];

    [self.mapView setZoomEnabled:YES];
    [self.mapView setZoomLevel:8 animated:YES];

    NavPointAnnotation *endAnnotation = [[NavPointAnnotation alloc] init];
    [endAnnotation setCoordinate:[self.in_endAnnotation coordinate]];
    [self.mapView addAnnotation:endAnnotation];
}

- (void)showRouteWithNaviRoute:(NSInteger)busLine_index
{
    [self.mapView removeOverlays:self.mapView.overlays];
    [self.mapView removeAnnotations:self.mapView.annotations];

    [_annotationArr removeAllObjects];
    [_polylinesArr removeAllObjects];
    
    for (PolyLineModel *model in [self.walkArrs objectAtIndex:busLine_index]) {
        NSArray *pathPolylines  = [self polylinesForPath:model];
        for (CustomPolyline *polyline in pathPolylines) {
            [self.polylinesArr addObject:polyline];
        }
    }
    [self.mapView addOverlays:self.polylinesArr];

    for ( BusLineModel *lineModel in [_busDetail objectAtIndex:busLine_index]) {
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(0, 0);
        BusPointAnnotation *startAnnotation = [[BusPointAnnotation alloc] init];
        coord.latitude = lineModel.departurelocation.latitude;
        coord.longitude = lineModel.departurelocation.longitude;
        [startAnnotation setCoordinate: coord];
        [startAnnotation setSubtitle:lineModel.departureStop];
        [_annotationArr addObject:startAnnotation];
        
        DDLogDebug(@"%@,%@",lineModel.departureStop,lineModel.arrivalStop);
        
        BusPointAnnotation *endAnnotation = [[BusPointAnnotation alloc] init];
        coord.latitude = lineModel.arrivallocation.latitude;
        coord.longitude = lineModel.arrivallocation.longitude;
        [endAnnotation setCoordinate: coord];
        [endAnnotation setSubtitle:[NSString stringWithFormat:@"%@ 下车",lineModel.arrivalStop]];
        [_annotationArr addObject:endAnnotation];

        for (AMapBusStop *viaStop in lineModel.viaBusStops) {
            BusPointAnnotation *viaAnnotation = [[BusPointAnnotation alloc] init];
            coord.latitude = viaStop.location.latitude;
            coord.longitude = viaStop.location.longitude;
            [viaAnnotation setCoordinate:coord];
            [_annotationArr addObject:viaAnnotation];
        }
    }
    
    NavPointAnnotation *endStopAnnotation = [[NavPointAnnotation alloc] init];
    [endStopAnnotation setCoordinate:[self.in_endAnnotation coordinate]];
    [_annotationArr addObject:endStopAnnotation];

    [self.mapView addAnnotations:_annotationArr];
    [self.mapView setVisibleMapRect:[CommonUtility minMapRectForAnnotations:self.mapView.annotations]
                        edgePadding:UIEdgeInsetsMake(RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge, RoutePlanningPaddingEdge)
                           animated:YES];
}

- (CLLocationCoordinate2D *)coordinatesForString:(NSString *)string
                                 coordinateCount:(NSUInteger *)coordinateCount
                                      parseToken:(NSString *)token
{
    if (string == nil)
    {
        return NULL;
    }
    
    if (token == nil)
    {
        token = @",";
    }
    
    NSString *str = @"";
    if (![token isEqualToString:@","])
    {
        str = [string stringByReplacingOccurrencesOfString:token withString:@","];
    }
    
    else
    {
        str = [NSString stringWithString:string];
    }
    
    NSArray *components = [str componentsSeparatedByString:@","];
    NSUInteger count = [components count] / 2;
    if (coordinateCount != NULL)
    {
        *coordinateCount = count;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D*)malloc(count * sizeof(CLLocationCoordinate2D));
    
    for (int i = 0; i < count; i++)
    {
        coordinates[i].longitude = [[components objectAtIndex:2 * i]     doubleValue];
        coordinates[i].latitude  = [[components objectAtIndex:2 * i + 1] doubleValue];
    }
    
    return coordinates;
}

- (NSArray *)polylinesForPath:(PolyLineModel *)model
{
    if (model == nil )
    {
        return nil;
    }
    
    NSMutableArray *polylines = [NSMutableArray array];
    NSUInteger count = 0;
    CLLocationCoordinate2D *coordinates = [self coordinatesForString:model.polyline
                                                     coordinateCount:&count
                                                          parseToken:@";"];
    
    CustomPolyline *polyline = [CustomPolyline polylineWithCoordinates:coordinates count:count];
    polyline.lineType = model.lineType;
    [polylines addObject:polyline];
    
    free(coordinates), coordinates = NULL;
    return polylines;
}

#pragma mark - Utility

- (void)returnAction
{
    [self clearMapView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearMapView
{
     self.mapView.showsUserLocation = NO;
    
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
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

#pragma mark - UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"cellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    NSArray *modelAr = [_busDetail objectAtIndex:[indexPath row]];
    
    long total_duration = 0;
    float total_distance = .0f;
    float totalPrice = .0f;
    long viaBusStopCount = 0;
    NSInteger walk_distance = 0;
    NSMutableString  *line_name = [[NSMutableString alloc] initWithCapacity:20];
    for (BusLineModel *lineModel in modelAr) {
        if ([line_name length] == 0 ) {
            [line_name setString:lineModel.name];
        }else{
            [line_name appendFormat:@" > %@",lineModel.name];
        }
        total_duration += [lineModel duration];
        total_distance += [lineModel distance];
        viaBusStopCount += [lineModel viaBusStopCount];
        walk_distance = lineModel.walk_distance;
        totalPrice = lineModel.totalPrice;
    }
    NSArray * tmpArr = [self.walkArrs objectAtIndex: [indexPath row]];
    for (PolyLineModel *polyModel in tmpArr) {
        walk_distance += polyModel.distance;
    }
    cell.textLabel.text = [self replaceString:line_name];
    if (totalPrice > 0 ) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | %@ | 步行%@ | %0.1f元 | %ld站",[self timeFormatted:total_duration], [self distanceFormatted:total_distance],[self walkdistanceFormatted:walk_distance],totalPrice,viaBusStopCount] ;
    }else{
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | %@ | 步行%@ | %ld站",[self timeFormatted:total_duration], [self distanceFormatted:total_distance],[self walkdistanceFormatted:walk_distance],viaBusStopCount] ;
    }

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _busDetail.count;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showRouteWithNaviRoute:[indexPath row]];
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

- (NSString *)walkdistanceFormatted:(long)totalMeters
{
    if (totalMeters < 1000) {
        return [NSString stringWithFormat:@"%ld米", totalMeters];
    }else{
        float km = totalMeters / 1000.0f;
        return [NSString stringWithFormat:@"%0.2f公里",km];
    }
    return @"";
}

-(NSString*)replaceString:(NSString*)str{
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:
                                              @"(\\(){1}(\\S)*(--)(\\S)*(\\))(\\S)*" options:0 error:nil];
    return [regularExpression stringByReplacingMatchesInString:str options:0 range:NSMakeRange(0, str.length) withTemplate:@""];
}

@end

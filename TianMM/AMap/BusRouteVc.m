//
//  BusRouteVc.m
//  TianMM
//
//  Created by cocoa on 15/11/9.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import "BusRouteVc.h"
#import "CustomPolyline.h"

@interface BusRouteVc ()<UITableViewDelegate,UITableViewDataSource>
{
    NSArray *_pathPolylines;
}
@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) NSArray *walkArrs;
@property (nonatomic, strong) MAPointAnnotation *in_endAnnotation;
@property (nonatomic, strong) NSArray *busDetail;

@end

@implementation BusRouteVc

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGRect rect = self.view.frame;
    rect.origin.y = kScreen_Height /2 + 100;
    rect.size.height = kScreen_Height/2 - 100;

    UITableView *tableView = [[UITableView alloc]initWithFrame:rect];
    [tableView setDataSource:self];
    [tableView setDelegate:self];
    tableView.rowHeight = 60;
    [self.view addSubview:tableView];
    
    [self configMapView];
    
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
    [self.mapView setFrame:CGRectMake(0, 0, self.view.width, self.view.height)];
    [self.view insertSubview:self.mapView atIndex:0];
    
    [self.mapView setShowsUserLocation:YES];
    [self.mapView removeAnnotations:self.mapView.annotations];
    
    [self.mapView setZoomEnabled:YES];
    [self.mapView setZoomLevel:12 animated:YES];

    MAPointAnnotation *endAnnotation = [[MAPointAnnotation alloc] init];
    [endAnnotation setCoordinate:[self.in_endAnnotation coordinate]];
    [self.mapView addAnnotation:endAnnotation];
}

- (void)showRouteWithNaviRoute:(NSInteger)busLine_index
{
    [self.mapView removeOverlays:self.mapView.overlays];
    [self.mapView removeAnnotations:self.mapView.annotations];

    _pathPolylines = nil;
    
    NSArray *lineArr = [self.walkArrs objectAtIndex:busLine_index];
    
    for (int i = 0; i< [lineArr count]; ++i) {
        _pathPolylines = [self polylinesForPath:lineArr[i]];
        if (i == 0) {
            for (CustomPolyline *polyline in _pathPolylines) {
                [self.mapView addOverlay:polyline];
                [self.mapView setVisibleMapRect:[polyline boundingMapRect] animated:NO];
            }
        }else{
            _pathPolylines = [self polylinesForPath:lineArr[i]];
            for (CustomPolyline *polyline in _pathPolylines) {
                [self.mapView insertOverlay:polyline aboveOverlay:self.mapView.overlays[0]];
            }
        }
    }
    
    NSArray *modelArr = [_busDetail objectAtIndex:busLine_index];
    CLLocationCoordinate2D coord[2];
    for (BusLineModel *lineModel in modelArr) {
        coord[0].latitude = lineModel.departurelocation.latitude;
        coord[0].longitude = lineModel.departurelocation.longitude;
        
        coord[1].latitude = lineModel.arrivallocation.latitude;
        coord[1].longitude = lineModel.arrivallocation.longitude;

        BusPointAnnotation *startAnnotation = [[BusPointAnnotation alloc] init];
        [startAnnotation setCoordinate: coord[0]];
        [startAnnotation setSubtitle:lineModel.departureStop];
        [self.mapView addAnnotation:startAnnotation];
        
        BusPointAnnotation *endAnnotation = [[BusPointAnnotation alloc] init];
        [endAnnotation setCoordinate: coord[1]];
        [endAnnotation setSubtitle:lineModel.arrivalStop];
        [self.mapView addAnnotation:endAnnotation];
    }
    
    [self.mapView setZoomLevel:12 animated:YES];
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

- (void)clearMapView
{
     self.mapView.showsUserLocation = NO;
    
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    //    self.mapView.delegate = nil;
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

    NSArray *modelArr = [_busDetail objectAtIndex:[indexPath row]];
    long total_duration = 0;
    float total_distance = .0f;
    float totalPrice = .0f;
    long viaBusStopCount = 0;
    NSInteger walk_distance = 0;
    NSMutableString  *line_name = [[NSMutableString alloc] initWithCapacity:20];
    for (BusLineModel *lineModel in modelArr) {
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
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

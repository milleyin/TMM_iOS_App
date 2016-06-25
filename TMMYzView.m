//
//  TMMYzView.m
//  TianMM
//
//  Created by cocoa on 15/10/26.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import "TMMYzView.h"

#define TITLE_BGVIEW_HEIGHT 44
#define SYSTEM_STATUSBAR_HEIGHT 20

@interface TMMYzView()<UIWebViewDelegate>
@property(assign,nonatomic) NSString * in_url;
@property(assign,nonatomic) UIButton * returnWebBn;
@property(assign,nonatomic) UIButton * shareBn;
@property(assign,nonatomic) NSMutableDictionary *shareJSON;
@property(assign,nonatomic) UILabel *titleLabel;

@end

@implementation TMMYzView

- (instancetype)initWithUrl:(NSString *)szurl frame:(CGRect)viewframe bTabViewType:(BOOL)bTabViewType title:(NSString *)title
{
    self=[super initWithFrame:viewframe];
    if (self) {
        
        self.bTabTypeBn = bTabViewType;
        _shareBlock = nil;
        _in_url  = [[NSString alloc]initWithString:szurl];
        [self setFrame:viewframe];
        [self setBackgroundColor:[UIColor whiteColor]];
        
        UIView *titleBgView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreen_Width, TITLE_BGVIEW_HEIGHT)];
        [titleBgView setBackgroundColor:[UIColor whiteColor]];
        [self addSubview:titleBgView];
        [titleBgView release];
        
        _titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 20, 20)];
        if ([title length] > 0) {
            [_titleLabel setText:title];
        }else{
            [_titleLabel setText:@"觅鲜"];
        }
        
        [_titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];
        [titleBgView addSubview:_titleLabel];
        [_titleLabel release];
        
        _shareBn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_shareBn setFrame:CGRectMake(0, 0, 100, 100)];
        [_shareBn setImage:[UIImage imageNamed:@"share"] forState:UIControlStateNormal];
        [_shareBn setHidden:YES];

        [titleBgView addSubview:_shareBn];
        [_shareBn release];
        
        _shareJSON = [[NSMutableDictionary alloc]initWithCapacity:10];
        
        [[_shareBn rac_signalForControlEvents:UIControlEventTouchUpInside]
            subscribeNext:^(UIButton* x) {
                _shareBlock(_shareJSON);
            }
        ];
        
        UIWebView *yz_webView= [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, kScreen_Width, kScreen_Height)];
        yz_webView.scrollView.bounces = NO;
        yz_webView.delegate = self;
        [self addSubview:yz_webView];
        
        [yz_webView.scrollView setShowsHorizontalScrollIndicator:NO];
        [yz_webView release];
        
        NSURL *url =[NSURL URLWithString:_in_url];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [yz_webView loadRequest:request];
        
        _returnWebBn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_returnWebBn setFrame:CGRectMake(0, 0, 100, 100)];
        [_returnWebBn setImage:[UIImage imageNamed:@"return"] forState:UIControlStateNormal];
        [_returnWebBn setHidden:YES];
        [titleBgView addSubview:_returnWebBn];
        [_returnWebBn release];
        
        [[_returnWebBn rac_signalForControlEvents:UIControlEventTouchUpInside]
            subscribeNext:^(UIButton* x) {
                if ([yz_webView canGoBack]) {
                    [yz_webView goBack];
                }else{
                    if (!_bTabTypeBn) {
                        [self removeFromSuperview];
                    }
                }
            }
         ];
        
        UIView *superview = self;
        [titleBgView mas_makeConstraints:^(MASConstraintMaker *make) {
            if (bTabViewType) {
                make.top.equalTo(superview.mas_top);
            }else{
                make.top.equalTo(superview.mas_top).offset(20);
            }
            make.size.mas_equalTo(CGSizeMake(kScreen_Width, TITLE_BGVIEW_HEIGHT));
        }];
        
        [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(titleBgView.mas_centerX);
            make.centerY.equalTo(titleBgView.mas_centerY);
            make.size.mas_equalTo(CGSizeMake(kScreen_Width, SYSTEM_STATUSBAR_HEIGHT));
        }];
        
        [_shareBn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(titleBgView.mas_right).offset(-16);
            make.centerY.equalTo(titleBgView.mas_centerY);
            make.size.mas_equalTo(CGSizeMake(50, SYSTEM_STATUSBAR_HEIGHT));
        }];
        
        [yz_webView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(titleBgView.mas_bottom);
            make.size.mas_equalTo(CGSizeMake(kScreen_Width, viewframe.size.height-TITLE_BGVIEW_HEIGHT));
        }];
        
        [_returnWebBn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(titleBgView.mas_left).offset(16);
            make.centerY.equalTo(titleBgView.mas_centerY);
        }];
    }
    return  self;
}

- (void)SetShareBlock:(ShareBlock)block
{
    __block TMMYzView* weakSelf = self;
    weakSelf.shareBlock = Block_copy(block);
}

#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    [_shareBn setHidden:YES];
    if ([request.URL.absoluteString isEqualToString:_in_url]) {
        if (_bTabTypeBn) {
            [_returnWebBn setHidden:YES];
        }else{
            [_returnWebBn setHidden:NO];
            [self GetShareData:request.URL.absoluteString];
        }
    }else{
        [_returnWebBn setHidden:NO];
        if (_bTabTypeBn) {
            [self GetShareData:request.URL.absoluteString];
        }
    }
    return YES;
}

- (void)GetShareData:(NSString*)url{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    [configuration setRequestCachePolicy:NSURLRequestReloadIgnoringCacheData];
    NSURLSessionDataTask *task = [[NSURLSession sessionWithConfiguration:configuration] dataTaskWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@",SHARE_DATA_URL,url]]
                                                                                      completionHandler:^(NSData *  data, NSURLResponse *  response, NSError *  error)
                                  {
                                      if ([(NSHTTPURLResponse*)response statusCode] == 200 && error == nil) {
                                          NSDictionary *shareDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              if ([shareDic count] > 0) {
                                                  if ([[shareDic objectForKey:@"status"] intValue] == 1){
                                                      [_shareBn setHidden:NO];
                                                      [_shareJSON setDictionary:[shareDic objectForKey:@"data"]];
                                                  }else{
                                                      [_shareBn setHidden:YES];
                                                  }
                                              }else{
                                                  [_shareBn setHidden:YES];
                                              }
                                          });
                                      }else{
                                          [_shareBn setHidden:YES];
                                      }
                                  }];
    [task resume];
}

//- (void)yzLogin:(NSURL * )Url{
//    NSString *jsBridageString = [[JsBridgeModel sharedManage] parseYOUZANScheme:Url];
//    if(jsBridageString) {
//        if([jsBridageString isEqualToString:CHECK_LOGIN]) {
//            NSString *appLoginPhone = [[NSUserDefaults standardUserDefaults] objectForKey:APP_LOGIN_NAME];
//            if (!appLoginPhone) {
//                if ([_yz_webView canGoBack]) {
//                    [_yz_webView goBack];
//                }
//                _loginBlock();
//            }else{
////                UserInfoModel *model = [UserInfoModel sharedManage];
////                model.gender = @"1";
////                model.userId = appLoginPhone;
////                model.telephone = appLoginPhone;
////                model.name = appLoginPhone;
////                model.bid = appLoginPhone;
////                model.avatar = @"";
//                NSDictionary *userInfo  = @{@"gender":@"1",@"user_id":appLoginPhone,@"user_name":appLoginPhone,@"telephone":appLoginPhone,@"nick_name":appLoginPhone,@"avatar":@""};
//                NSString *string = [[JsBridgeModel sharedManage]  webUserInfoLogin:userInfo];
//                [_yz_webView stringByEvaluatingJavaScriptFromString:string];
//            }
//        }
//    }
//}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
//    [_yz_webView stringByEvaluatingJavaScriptFromString:[[JsBridgeModel sharedManage] JsBridgeWhenWebDidLoad]];
//    _titleLabel.text = [yz_webView stringByEvaluatingJavaScriptFromString:@"document.title"];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    
}

- (void)dealloc{
    [super dealloc];
    [_in_url release];
    [_titleLabel release];
    if (_shareJSON) {
        [_shareJSON release];
        _shareBlock = nil;
    }
    if (_shareBlock) {
        Block_release(_shareBlock);
    }
}

@end

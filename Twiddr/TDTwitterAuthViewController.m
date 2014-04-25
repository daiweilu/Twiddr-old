//
//  TDTwitterAuthViewController.m
//  Twidder-proto
//
//  Created by Daiwei Lu on 3/22/14.
//  Copyright (c) 2014 Daiwei Lu. All rights reserved.
//

#import "TDTwitterAuthViewController.h"
#import "TDAccountTableViewController.h"
#import <STTwitter/STTwitter.h>
#import "Constants.h"
#import "TDAccount.h"
#import <SSKeychain/SSKeychain.h>
#import "TDSingletonCoreDataManager.h"


@interface TDTwitterAuthViewController () {
    STTwitterAPI *_twitterApi;
}
@end


@implementation TDTwitterAuthViewController

static void(^callbackErrorBlock)(NSError *error);

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    callbackErrorBlock = ^void(NSError *error) {
        NSLog(@"-- error: %@", error);
    };
    
    self.webView.delegate = self;
}


- (void)viewDidAppear:(BOOL)animated
{
    _twitterApi = [STTwitterAPI twitterAPIWithOAuthConsumerKey:TWAPIKey consumerSecret:TWAPISecret];
    
    [_twitterApi postTokenRequest:^(NSURL *url, NSString *oauthToken) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    } forceLogin:@(YES) screenName:nil oauthCallback:TWAPICallback errorBlock:callbackErrorBlock];
}


#pragma mark - Web View delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
                                                 navigationType:(UIWebViewNavigationType)navigationType
{
    if ([[request.URL absoluteString] hasPrefix:TWAPICallback]) {
        
        NSDictionary *d = [self parametersDictionaryFromQueryString:[request.URL query]];
        
        [_twitterApi postAccessTokenRequestWithPIN:d[@"oauth_verifier"]
                                      successBlock:^(NSString *oauthToken, NSString *oauthTokenSecret,
                                                     NSString *userID, NSString *screenName)
        {
            [self saveTwitterAccountScreenName:screenName idStr:userID OauthToken:oauthToken
                                   tokenSecret:oauthTokenSecret];
        } errorBlock:callbackErrorBlock];
        
        return NO;
    } else {
        return YES;
    }
}


#pragma mark - IBActions

- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Helpers

- (void)saveTwitterAccountScreenName:(NSString *)screenName
                               idStr:(NSString *)idStr
                          OauthToken:(NSString *)oauthToken
                         tokenSecret:(NSString *)oauthTokenSecret
{
    NSDictionary *accountDict = @{@"id_str":       screenName,
                                  @"screen_name":  screenName,
                                  @"token":        oauthToken,
                                  @"token_secret": oauthTokenSecret};
    
    // Save account info to TDAccount view controller, and dismiss current view
    _account = [TDAccount accountWithRawDictionary:accountDict];
    [TDSingletonCoreDataManager saveContext];
    
    _account.twitterApi = _twitterApi;
    
    [self.accountTableViewController.accounts addObject:_account];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (NSDictionary *)parametersDictionaryFromQueryString:(NSString *)queryString
{
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    NSArray *queryComponents = [queryString componentsSeparatedByString:@"&"];
    for(NSString *s in queryComponents) {
        NSArray *pair = [s componentsSeparatedByString:@"="];
        if([pair count] != 2) continue;
        NSString *key = pair[0];
        NSString *value = pair[1];
        md[key] = value;
    }
    return md;
}


@end

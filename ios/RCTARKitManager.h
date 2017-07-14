//
//  RCTARKitManager.h
//  RCTARKit
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

/* RCTARKitManager_h */

#import <React/RCTViewManager.h>

@interface RCTARKitManager : RCTViewManager

- (void)getCameraPosition:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
- (void)addBox:(NSDictionary *)object resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
- (void)addSphere:(NSDictionary *)object resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
- (void)addCylinder:(NSDictionary *)object resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;

@end


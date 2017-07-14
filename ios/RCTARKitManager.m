//
//  RCTARKitManager.m
//  RCTARKit
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import "RCTARKitManager.h"
#import "RCTARKit.h"

@interface RCTARKitManager ()
@end

@implementation RCTARKitManager

RCT_EXPORT_MODULE()

- (UIView *)view {
    return [RCTARKit sharedInstance];
}

RCT_EXPORT_VIEW_PROPERTY(debug, BOOL)
RCT_EXPORT_VIEW_PROPERTY(planeDetection, BOOL)
RCT_EXPORT_VIEW_PROPERTY(lightEstimation, BOOL)

RCT_EXPORT_VIEW_PROPERTY(onPlaneDetected, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlaneUpdate, RCTBubblingEventBlock)

RCT_EXPORT_METHOD(getCameraPosition:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    resolve([[RCTARKit sharedInstance] cameraPosition]);
}


RCT_EXPORT_METHOD(addBox:(NSDictionary *)object resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    BoxProperty property;
    property.x = [object[@"x"] floatValue];
    property.y = [object[@"y"] floatValue];
    property.z = [object[@"z"] floatValue];
    property.width = [object[@"width"] floatValue];
    property.height = [object[@"height"] floatValue];
    property.length = [object[@"length"] floatValue];
    property.chamfer = [object[@"chamfer"] floatValue];
    [[RCTARKit sharedInstance] addBox:property];
}

RCT_EXPORT_METHOD(addSphere:(NSDictionary *)object resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    SphereProperty property;
    property.x = [object[@"x"] floatValue];
    property.y = [object[@"y"] floatValue];
    property.z = [object[@"z"] floatValue];
    property.radius = [object[@"radius"] floatValue];
    [[RCTARKit sharedInstance] addSphere:property];
}

RCT_EXPORT_METHOD(addCylinder:(NSDictionary *)object resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    CylinderProperty property;
    property.x = [object[@"x"] floatValue];
    property.y = [object[@"y"] floatValue];
    property.z = [object[@"z"] floatValue];
    property.radius = [object[@"radius"] floatValue];
    property.height = [object[@"height"] floatValue];
    [[RCTARKit sharedInstance] addCylinder:property];
}

@end


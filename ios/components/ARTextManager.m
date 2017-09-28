//
//  ARTextManager.m
//  RCTARKit
//
//  Created by Zehao Li on 8/12/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import "ARTextManager.h"
#import "RCTARKitNodes.h"
#import "RCTConvert+ARKit.h"

@implementation ARTextManager

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(mount:(SCNTextNode *)textNode node:(SCNNode *)node) {
    [node addChildNode:textNode];
    [[RCTARKitNodes sharedInstance] addNodeToScene:node];
}

RCT_EXPORT_METHOD(unmount:(NSString *)identifier) {
    [[RCTARKitNodes sharedInstance] removeNodeForKey:identifier];
}

@end

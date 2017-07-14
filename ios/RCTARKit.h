//
//  RCTARKit.h
//  RCTARKit
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <ARKit/ARKit.h>

#import <React/RCTComponent.h>

typedef struct {
    float x;
    float y;
    float z;
    float width;
    float height;
    float length;
    float chamfer;
} BoxProperty;

typedef struct {
    float x;
    float y;
    float z;
    float radius;
} SphereProperty;

typedef struct {
    float x;
    float y;
    float z;
    float radius;
    float height;
} CylinderProperty;

@interface RCTARKit : ARSCNView

+ (instancetype)sharedInstance;

@property (nonatomic, assign) BOOL debug;
@property (nonatomic, assign) BOOL planeDetection;
@property (nonatomic, assign) BOOL lightEstimation;
@property (nonatomic, readonly) NSDictionary *cameraPosition;

@property (nonatomic, copy) RCTBubblingEventBlock onPlaneDetected;
@property (nonatomic, copy) RCTBubblingEventBlock onPlaneUpdate;

@property NSMutableDictionary *planes;
@property NSMutableArray *boxes;

- (void)addBox:(BoxProperty)property;
- (void)addSphere:(SphereProperty)property;
- (void)addCylinder:(CylinderProperty)property;

@end


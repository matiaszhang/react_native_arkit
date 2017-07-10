//
//  RCTARKit.m
//  RCTARKit
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import "RCTARKit.h"
#import "Plane.h"

@interface RCTARKit () <ARSCNViewDelegate>

@property (nonatomic, strong) ARWorldTrackingSessionConfiguration *configuration;

@end


@implementation RCTARKit

+ (instancetype)sharedInstance {
    static RCTARKit *arView = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        if (arView == nil) {
            arView = [[self alloc] init];
        }
    });

    return arView;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.delegate = self;
        [self.session runWithConfiguration:self.configuration];

        self.autoenablesDefaultLighting = YES;
        self.scene = [SCNScene new];

        self.planes = [NSMutableDictionary new];
    }
    return self;
}


#pragma mark - setter-getter

- (BOOL)debug {
    return self.showsStatistics;
}

- (void)setDebug:(BOOL)debug {
    if (debug) {
        self.showsStatistics = YES;
        self.debugOptions = ARSCNDebugOptionShowWorldOrigin | ARSCNDebugOptionShowFeaturePoints;
    } else {
        self.showsStatistics = NO;
        self.debugOptions = SCNDebugOptionNone;
    }
}

- (BOOL)planeDetection {
    return self.configuration.planeDetection == ARPlaneDetectionHorizontal;
}

- (void)setPlaneDetection:(BOOL)planeDetection {
    if (planeDetection) {
        NSLog(@"detect plane");
        self.configuration.planeDetection = ARPlaneDetectionHorizontal;
    } else {
        NSLog(@"do not detect plane");
        self.configuration.planeDetection = ARPlaneDetectionNone;
    }

    [self.session runWithConfiguration:self.configuration];
}

- (BOOL)lightEstimation {
    return self.configuration.lightEstimationEnabled;
}

- (void)setLightEstimation:(BOOL)lightEstimation {
    self.configuration.lightEstimationEnabled = lightEstimation;
    [self.session runWithConfiguration:self.configuration];
}

- (NSDictionary *)cameraPosition {
    simd_float4 position = self.session.currentFrame.camera.transform.columns[3];
    return @{
             @"x": [NSNumber numberWithFloat:position.x],
             @"y": [NSNumber numberWithFloat:position.y],
             @"z": [NSNumber numberWithFloat:position.z]
             };
}


#pragma mark - Lazy loads

-(ARWorldTrackingSessionConfiguration *)configuration {
    if (_configuration) {
        return _configuration;
    }

//    if (!ARWorldTrackingSessionConfiguration.isSupported) {
//    }

    _configuration = [ARWorldTrackingSessionConfiguration new];
    _configuration.planeDetection = ARPlaneDetectionHorizontal;
    return _configuration;
}


#pragma mark - methods

#pragma mark - ARSCNViewDelegate

/**
 Called when a new node has been added.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if (![anchor isKindOfClass:[ARPlaneAnchor class]]) {
        return;
    }

    NSLog(@"plane detected");

    Plane *plane = [[Plane alloc] initWithAnchor: (ARPlaneAnchor *)anchor isHidden: NO];
    [self.planes setObject:plane forKey:anchor.identifier];
    [node addChildNode:plane];
}

/**
 Called when a node will be updated.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
}

/**
 Called when a node has been updated.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    Plane *plane = [self.planes objectForKey:anchor.identifier];
    if (plane == nil) {
        return;
    }

    [plane update:(ARPlaneAnchor *)anchor];
}

/**
 Called when a mapped node has been removed.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    [self.planes removeObjectForKey:anchor.identifier];
}

#pragma mark - session

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
}

- (void)sessionWasInterrupted:(ARSession *)session {
}

- (void)sessionInterruptionEnded:(ARSession *)session {
}

@end

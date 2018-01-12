//
//  RCTARKitNodes.m
//  RCTARKit
//
//  Created by Zehao Li on 9/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import "RCTARKitNodes.h"
#import "RCTConvert+ARKit.h"

@implementation SCNNode (ReferenceFrame)
@dynamic referenceFrame;
@end

CGFloat focDistance = 0.2f;


@interface RCTARKitNodes () <RCTARKitSessionDelegate>

@property (nonatomic, strong) SCNNode* rootNode;

@property NSMutableDictionary *nodes;

@end



@implementation RCTARKitNodes

+ (instancetype)sharedInstance {
    static RCTARKitNodes *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        if (instance == nil) {
            instance = [[self alloc] init];
        }
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        // local reference frame origin
        self.localOrigin = [[SCNNode alloc] init];
        self.localOrigin.name = @"localOrigin";
        
        // camera reference frame origin
        self.cameraOrigin = [[SCNNode alloc] init];
        self.cameraOrigin.name = @"cameraOrigin";
        
        // front-of-camera frame origin
        self.frontOfCamera = [[SCNNode alloc] init];
        self.frontOfCamera.name = @"frontOfCamera";
        
        // init cahces
        self.nodes = [NSMutableDictionary new];
    }
    return self;
}

- (void)setArView:(ARSCNView *)arView {
    //NSLog(@"setArView");
    _arView = arView;
    self.rootNode = arView.scene.rootNode;
  
    self.rootNode.name = @"root";
    
    [self.rootNode addChildNode:self.localOrigin];
    [self.rootNode addChildNode:self.cameraOrigin];
    [self.rootNode addChildNode:self.frontOfCamera];
}

#pragma mark

/**
 add a node to scene in a reference frame
 */
- (void)addNodeToScene:(SCNNode *)node inReferenceFrame:(NSString *)referenceFrame {
    [self registerNode:node forKey:node.name];
    if (!referenceFrame) {
        referenceFrame = @"Local"; // default to Local frame
    }
    NSString *selectorString = [NSString stringWithFormat:@"addNodeTo%@Frame:", referenceFrame];
    SEL selector = NSSelectorFromString(selectorString);
    if ([self respondsToSelector:selector]) {
        // check https://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
        IMP imp = [self methodForSelector:selector];
        void (*func)(id, SEL, SCNNode*) = (void *)imp;
        func(self, selector, node);
    }
}

- (void)clear {
    // clear scene
    NSArray *keys = [self.nodes allKeys];
    
    for (id key in keys) {
        id node = [self.nodes objectForKey:key];
        if (node) {
            [node removeFromParentNode];
        }
        
    }
    [self.nodes removeAllObjects];
}

- (void)addNodeToLocalFrame:(SCNNode *)node {
    node.referenceFrame = RFReferenceFrameLocal;
    
    [self.localOrigin addChildNode:node];
    //NSLog(@"[RCTARKitNodes] Add node %@ to Local frame at (%.2f, %.2f, %.2f)", node.name, node.position.x, node.position.y, node.position.z);
    
}

- (void)addNodeToCameraFrame:(SCNNode *)node {
    node.referenceFrame = RFReferenceFrameCamera;
    //NSLog(@"[RCTARKitNodes] Add node %@ to Camera frame at (%.2f, %.2f, %.2f)", node.name, node.position.x, node.position.y, node.position.z);

    [self.cameraOrigin addChildNode:node];
}

- (void)addNodeToFrontOfCameraFrame:(SCNNode *)node {
    node.referenceFrame = RFReferenceFrameFrontOfCamera;
    
    //NSLog(@"[RCTARKitNodes] Add node %@ to FrontOfCamera frame at (%.2f, %.2f, %.2f)", node.name, node.position.x, node.position.y, node.position.z);

    [self.frontOfCamera addChildNode:node];
}


- (NSDictionary *)getSceneObjectsHitResult:(const CGPoint)tapPoint  {
    NSDictionary *options = @{
                              SCNHitTestRootNodeKey: self.localOrigin,
                              SCNHitTestSortResultsKey: @(YES)
                              };
    NSArray<SCNHitTestResult *> *results = [_arView hitTest:tapPoint options:options];
    NSMutableArray * resultsMapped = [self mapHitResultsWithSceneResults:results];
    NSDictionary *result = getSceneObjectHitResult(resultsMapped, tapPoint);
    return result;
}


static NSDictionary * getSceneObjectHitResult(NSMutableArray *resultsMapped, const CGPoint tapPoint) {
    return @{
             @"results": resultsMapped,
             @"tapPoint": @{
                     @"x": @(tapPoint.x),
                     @"y": @(tapPoint.y)
                     }
             };
}


static SCNVector3 toSCNVector3(simd_float4 float4) {
    SCNVector3 positionAbsolute = SCNVector3Make(float4.x, float4.y, float4.z);
    return positionAbsolute;
}

- (SCNVector3)getRelativePositionToOrigin:(const SCNVector3)positionAbsolute {
    SCNVector3 originPosition = self.localOrigin.position;
    SCNVector3 position = SCNVector3Make(positionAbsolute.x - originPosition.x, positionAbsolute.y- originPosition.y, positionAbsolute.z - originPosition.z);
    return position;
}

- (SCNVector3)getAbsolutePositionToOrigin:(const SCNVector3)positionRelative {
    SCNVector3 originPosition = self.localOrigin.position;
    SCNVector3 position = SCNVector3Make(positionRelative.x + originPosition.x, positionRelative.y+ originPosition.y, positionRelative.z + originPosition.z);
    return position;
}



- (NSMutableArray *) mapHitResultsWithSceneResults: (NSArray<SCNHitTestResult *> *)results {
    
    NSMutableArray *resultsMapped = [NSMutableArray arrayWithCapacity:[results count]];
    
    [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        SCNHitTestResult *result = (SCNHitTestResult *) obj;
        SCNNode * node = result.node;
        
        NSString * nodeId = [self findNodeId:node];
        if(nodeId) {
        
            SCNVector3 positionAbsolute = result.worldCoordinates;
            SCNVector3 position = [self getRelativePositionToOrigin:positionAbsolute];
            SCNVector3 normal = result.worldNormal;
            float distance = [self getCameraDistanceToPoint:positionAbsolute];
         
            NSDictionary *result = @{
                                            @"id": nodeId,
                                            @"distance": @(distance),
                                            @"positionAbsolute": @{
                                                    @"x": @(positionAbsolute.x),
                                                    @"y": @(positionAbsolute.y),
                                                    @"z": @(positionAbsolute.z)
                                                    },
                                            @"position": @{
                                                    @"x": @(position.x),
                                                    @"y": @(position.y),
                                                    @"z": @(position.z)
                                                    },
                                            // point is deprecated
                                            @"point": @{
                                                    @"x": @(position.x),
                                                    @"y": @(position.y),
                                                    @"z": @(position.z)
                                                    },
                                            @"normal": @{
                                                    @"x": @(normal.x),
                                                    @"y": @(normal.y),
                                                    @"z": @(normal.z)
                                                    
                                                    }
                                            };
            [resultsMapped addObject:(result )];
        }
            
    }];
    
    return resultsMapped;
    
}





- (NSMutableArray *) mapHitResults:(NSArray<ARHitTestResult *> *)results {
    NSMutableArray *resultsMapped = [NSMutableArray arrayWithCapacity:[results count]];
    
    [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        ARHitTestResult *result = (ARHitTestResult *) obj;
        
        SCNVector3 positionAbsolute = toSCNVector3(result.worldTransform.columns[3]);
        SCNVector3 position = [self getRelativePositionToOrigin:positionAbsolute];
        [resultsMapped addObject:(@{
                                    @"distance": @(result.distance),
                                    @"id": result.anchor.identifier.UUIDString,
                                    @"positionAbsolute": @{
                                            @"x": @(positionAbsolute.x),
                                            @"y": @(positionAbsolute.y),
                                            @"z": @(positionAbsolute.z)
                                            },
                                    @"position": @{
                                            @"x": @(position.x),
                                            @"y": @(position.y),
                                            @"z": @(position.z)
                                            },
                                    // deprecated
                                    @"point": @{
                                            @"x": @(position.x),
                                            @"y": @(position.y),
                                            @"z": @(position.z)
                                            }
                                    
                                    } )];
    }];
    return resultsMapped;
}

#pragma mark - node register
- (void)registerNode:(SCNNode *)node forKey:(NSString *)key {
    [self removeNodeForKey:key];
    if (node) {
        [self.nodes setObject:node forKey:key];
    }
}


- (NSString *) findNodeId:(SCNNode *)nodeWithParents {

    SCNNode* _node = nodeWithParents;
    while(_node) {
        if(_node.name && [self.nodes objectForKey:_node.name]) {
            return _node.name;
        }
        _node = _node.parentNode;
    }
    return nil;

}


- (SCNNode *)nodeForKey:(NSString *)key {
    return [self.nodes objectForKey:key];
}

- (void)removeNodeForKey:(NSString *)key {
    //NSLog(@"removing node: %@ ", key);
    SCNNode *node = [self.nodes objectForKey:key];
    if (node) {
        [self.nodes removeObjectForKey:key];
        if(node.light) {
            // see https://stackoverflow.com/questions/47270056/how-to-remove-a-light-with-shadowmode-deferred-in-scenekit-arkit?noredirect=1#comment81491270_47270056
            node.hidden = YES;
            [node removeFromParentNode];
        } else {
            [node removeFromParentNode];
        }
    }
}

- (void)updateNode:(NSString *)nodeId properties:(NSDictionary *) properties {
    SCNNode *node = [self.nodes objectForKey:nodeId];
    //NSLog(@"updating node %@ :%@", nodeId, properties);
    if(node) {
        [RCTConvert setNodeProperties:node properties:properties];
        if(node.geometry && properties[@"shape"]) {
              [RCTConvert setShapeProperties:node.geometry properties:properties[@"shape"]];
        }
        if(properties[@"material"]) {
            for (id material in node.geometry.materials) {
                [RCTConvert setMaterialProperties:material properties:properties[@"material"]];
            }
        }
        if(node.light) {
            [RCTConvert setLightProperties:node.light properties:properties];
        }
        
        
    } else {
        NSLog(@"WARNING: node does not exists: %@. This means that the node has not been mounted yet, so native calls got out of order", nodeId);
    }
    
}




#pragma mark - RCTARKitSessionDelegate
- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    simd_float4 pos = frame.camera.transform.columns[3];
    self.cameraOrigin.position = SCNVector3Make(pos.x, pos.y, pos.z);
    simd_float4 z = frame.camera.transform.columns[2];
    self.cameraDirection = SCNVector3Make(-z.x, -z.y, -z.z);
    self.cameraOrigin.eulerAngles = SCNVector3Make(0, atan2f(z.x, z.z), 0);
    self.frontOfCamera.position = SCNVector3Make(pos.x - focDistance * z.x, pos.y  - focDistance * z.y, pos.z - focDistance * z.z);
    self.frontOfCamera.eulerAngles = self.cameraOrigin.eulerAngles;
    
}

- (float)getCameraDistanceToPoint:(SCNVector3)point {
    return getDistance(self.cameraOrigin.position, point);
}

static float getDistance(const SCNVector3 pointA, const SCNVector3 pointB) {
    float xd = pointB.x - pointA.x;
    float yd = pointB.y - pointA.y;
    float zd = pointB.z - pointA.z;
    float distance = sqrt(xd * xd + yd * yd + zd * zd);
    
    if (distance < 0){
        return (distance * -1);
    } else {
        return (distance);
    }
}

@end

//
//  RCTARKit.m
//  RCTARKit
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

#import "RCTARKit.h"
#import "Plane.h"
@import CoreLocation;

@interface RCTARKit () <ARSCNViewDelegate, UIGestureRecognizerDelegate> {
    RCTPromiseResolveBlock _resolve;
    BOOL _metal;
}

@property (nonatomic, strong) ARSession* session;
//@property (nonatomic, strong) ARWorldTrackingSessionConfiguration *configuration;
@property (nonatomic, strong) ARWorldTrackingConfiguration *configuration;

@end


@implementation RCTARKit

+ (instancetype)sharedInstance {
    static RCTARKit *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        if (instance == nil) {
            ARSCNView *arView = [[ARSCNView alloc] init];
            instance = [[self alloc] initWithARView:arView];
        }
    });
    return instance;
}

- (instancetype)initWithARView:(ARSCNView *)arView {
    if ((self = [super init])) {
        self.arView = arView;
        
        // delegates
        arView.delegate = self;
        arView.session.delegate = self;
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        [self.arView addGestureRecognizer:tapGestureRecognizer];
        
        // configuration(s)
        arView.autoenablesDefaultLighting = YES;
        arView.scene.rootNode.name = @"root";
        
        // local reference frame origin
        self.localOrigin = [[SCNNode alloc] init];
        self.localOrigin.name = @"localOrigin";
        [arView.scene.rootNode addChildNode:self.localOrigin];
        
        // camera reference frame origin
        self.cameraOrigin = [[SCNNode alloc] init];
        self.cameraOrigin.name = @"cameraOrigin";
        self.cameraOrigin.opacity = 0.7;
        [arView.scene.rootNode addChildNode:self.cameraOrigin];
        
        // init cahces
        self.nodes = [NSMutableDictionary new];
        self.planes = [NSMutableDictionary new];
        
        // start ARKit
        [self addSubview:arView];
        [self resume];
        
        _metal = YES;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.arView.frame = self.bounds;
}

- (void)pause {
    [self.session pause];
}

- (void)resume {
    // clear scene
    for(id key in self.nodes) {
        id node = [self.nodes objectForKey:key];
        [node removeFromParentNode];
    }
    [self.session runWithConfiguration:self.configuration];
}

- (void)focusScene {
    [self.localOrigin setPosition:self.cameraOrigin.position];
    [self.localOrigin setRotation:self.cameraOrigin.rotation];
}


#pragma mark - setter-getter

- (ARSession*)session {
    return self.arView.session;
}

- (BOOL)debug {
    return self.arView.showsStatistics;
}

- (void)setDebug:(BOOL)debug {
    if (debug) {
        self.arView.showsStatistics = YES;
        self.arView.debugOptions = ARSCNDebugOptionShowWorldOrigin | ARSCNDebugOptionShowFeaturePoints;
    } else {
        self.arView.showsStatistics = NO;
        self.arView.debugOptions = SCNDebugOptionNone;
    }
}

- (BOOL)planeDetection {
    ARWorldTrackingConfiguration *configuration = self.session.configuration;
    return configuration.planeDetection == ARPlaneDetectionHorizontal;
}

- (void)setPlaneDetection:(BOOL)planeDetection {
    // plane detection is on by default for ARCL and cannot be configured for now
    ARWorldTrackingConfiguration *configuration = self.session.configuration;
    if (planeDetection) {
        configuration.planeDetection = ARPlaneDetectionHorizontal;
    } else {
        configuration.planeDetection = ARPlaneDetectionNone;
    }
    [self resume];
}


//- (BOOL)lightEstimation {
//    ARSessionConfiguration *configuration = self.session.configuration;
//    return configuration.lightEstimationEnabled;
//}
//
//- (void)setLightEstimation:(BOOL)lightEstimation {
//    // light estimation is on by default for ARCL and cannot be configured for now
//    ARSessionConfiguration *configuration = self.session.configuration;
//    configuration.lightEstimationEnabled = lightEstimation;
//    [self resume];
//}

- (NSDictionary *)readCameraPosition {
    return @{
             @"x": @(self.cameraOrigin.position.x),
             @"y": @(self.cameraOrigin.position.y),
             @"z": @(self.cameraOrigin.position.z)
             };
}



#pragma mark - Lazy loads

-(ARWorldTrackingConfiguration *)configuration {
    if (_configuration) {
        return _configuration;
    }
    
    if (!ARWorldTrackingConfiguration.isSupported) {}
    
    _configuration = [ARWorldTrackingConfiguration new];
    _configuration.planeDetection = ARPlaneDetectionHorizontal;
    _configuration.lightEstimationEnabled = YES;
    
    return _configuration;
}



#pragma mark - Methods

- (void)hitTestPlane:(const CGPoint)tapPoint types:(ARHitTestResultType)types resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    resolve([self getPlaneHitResult:tapPoint types:types]);
}

- (void)hitTestSceneObjects:(const CGPoint)tapPoint resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    
    resolve([self getSceneObjectsHitResult:tapPoint]);
}


- (void)snapshot:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    UIImage *image = [self.arView snapshot];
    _resolve = resolve;
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(thisImage:savedInAlbumWithError:ctx:), NULL);
}


- (void)snapshotCamera:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    
    // thx https://stackoverflow.com/a/8094038/1463534
    CVPixelBufferRef pixelBuffer = self.arView.session.currentFrame.capturedImage;
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];
    
    UIImage *image = [UIImage imageWithCGImage:videoImage scale: 1.0 orientation:UIImageOrientationRight];
    CGImageRelease(videoImage);
    _resolve = resolve;
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(thisImage:savedInAlbumWithError:ctx:), NULL);
}

- (void)thisImage:(UIImage *)image savedInAlbumWithError:(NSError *)error ctx:(void *)ctx {
    if (error) {
    } else {
        _resolve(@{ @"success": @(YES) });
    }
}


#pragma mark add models in the scene
- (void)addMaterial:(SCNGeometry *)geometry property:(NSDictionary *)property {
    if (property[@"color"]) {
        CGFloat r = [property[@"r"] floatValue];
        CGFloat g = [property[@"g"] floatValue];
        CGFloat b = [property[@"b"] floatValue];
        UIColor *color = [[UIColor alloc] initWithRed:r green:g blue:b alpha:1.0f];
        SCNMaterial *material = [self materialFromDiffuseColor:color];
        if (property[@"shader"]) {
            NSDictionary* shader = property[@"shader"];
            if (shader[@"metalness"]) {
                material.metalness.contents = @([shader[@"metalness"] floatValue]);
            }
            if (shader[@"roughness"]) {
                material.roughness.contents = @([shader[@"roughness"] floatValue]);
            }
        }
        
        geometry.materials = @[material, material, material, material, material, material];
    }
}

- (void)addBox:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    
    CGFloat width = [shape[@"width"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    CGFloat length = [shape[@"length"] floatValue];
    CGFloat chamfer = [shape[@"chamfer"] floatValue];
    
    SCNBox *geometry = [SCNBox boxWithWidth:width height:height length:length chamferRadius:chamfer];
    [self addMaterial:geometry property:property];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self addNodeToScene:node property:property];
}

- (void)addNodeByGeometry:(SCNSphere *)geometry property:(NSDictionary *)property {
    [self addMaterial:geometry property:property];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self addNodeToScene:node property:property];
}

- (void)addSphere:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat radius = [shape[@"radius"] floatValue];
    
    SCNSphere *geometry = [SCNSphere sphereWithRadius:radius];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addCylinder:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat radius = [shape[@"radius"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    
    SCNCylinder *geometry = [SCNCylinder cylinderWithRadius:radius height:height];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addCone:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat topR = [shape[@"topR"] floatValue];
    CGFloat bottomR = [shape[@"bottomR"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    
    SCNCone *geometry = [SCNCone coneWithTopRadius:topR bottomRadius:bottomR height:height];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addPyramid:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat width = [shape[@"width"] floatValue];
    CGFloat length = [shape[@"length"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    
    SCNPyramid *geometry = [SCNPyramid pyramidWithWidth:width height:height length:length];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addTube:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat innerR = [shape[@"innerR"] floatValue];
    CGFloat outerR = [shape[@"outerR"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    SCNTube *geometry = [SCNTube tubeWithInnerRadius:innerR outerRadius:outerR height:height];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addTorus:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat ringR = [shape[@"ringR"] floatValue];
    CGFloat pipeR = [shape[@"pipeR"] floatValue];
    
    SCNTorus *geometry = [SCNTorus torusWithRingRadius:ringR pipeRadius:pipeR];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addCapsule:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat capR = [shape[@"capR"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    
    SCNCapsule *geometry = [SCNCapsule capsuleWithCapRadius:capR height:height];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addPlane:(NSDictionary *)property {
    NSDictionary* shape = property[@"shape"];
    CGFloat width = [shape[@"width"] floatValue];
    CGFloat height = [shape[@"height"] floatValue];
    
    SCNPlane *geometry = [SCNPlane planeWithWidth:width height:height];
    [self addNodeByGeometry:geometry property:property];
}

- (void)addText:(NSDictionary *)property {
    // init SCNText
    NSString *text = property[@"text"];
    CGFloat depth = [property[@"depth"] floatValue];
    if (!text) {
        text = @"(null)";
    }
    if (!depth) {
        depth = 0.0f;
    }
    CGFloat fontSize = [property[@"size"] floatValue];
    CGFloat size = fontSize / 12;
    SCNText *scnText = [SCNText textWithString:text extrusionDepth:depth / size];
    scnText.flatness = 0.1;
    
    // font
    NSString *font = property[@"name"];
    if (font) {
        scnText.font = [UIFont fontWithName:font size:12];
    } else {
        scnText.font = [UIFont systemFontOfSize:12];
    }
    
    // chamfer
    CGFloat chamfer = [property[@"chamfer"] floatValue];
    if (!chamfer) {
        chamfer = 0.0f;
    }
    scnText.chamferRadius = chamfer / size;
    
    // color
    if (property[@"color"]) {
        CGFloat r = [property[@"r"] floatValue];
        CGFloat g = [property[@"g"] floatValue];
        CGFloat b = [property[@"b"] floatValue];
        UIColor *color = [[UIColor alloc] initWithRed:r green:g blue:b alpha:1.0f];
        SCNMaterial *face = [self materialFromDiffuseColor:color];
        SCNMaterial *border = [self materialFromDiffuseColor:color];
        scnText.materials = @[face, face, border, border, border];
    }
    
    // init SCNNode
    SCNNode *textNode = [SCNNode nodeWithGeometry:scnText];
    
    // position textNode
    SCNVector3 min;
    SCNVector3 max;
    [textNode getBoundingBoxMin:&min max:&max];
    textNode.position = SCNVector3Make(-(min.x + max.x) / 2, -(min.y + max.y) / 2, -(min.z + max.z) / 2);
    
    SCNNode *textOrigin = [[SCNNode alloc] init];
    [textOrigin addChildNode:textNode];
    textOrigin.scale = SCNVector3Make(size, size, size);
    [self addNodeToScene:textOrigin property:property];
}

- (void)addModel:(NSDictionary *)property {
    NSDictionary* model = property[@"model"];
    CGFloat scale = [model[@"scale"] floatValue];
    NSString * filePath = model[@"file"];
    NSURL *url;
    if([filePath hasPrefix: @"/"]) {
        url = [NSURL fileURLWithPath: filePath];
    } else {
        url = [[NSBundle mainBundle] URLForResource:filePath withExtension:nil];
    }
    SCNNode *node = [self loadModel:url nodeName:property[@"node"] withAnimation:YES];
    node.scale = SCNVector3Make(scale, scale, scale);
    [self addNodeToScene:node property:property];
}

- (SCNMaterial *)materialFromDiffuseColor:(UIColor *)color {
    SCNMaterial *material = [SCNMaterial new];
    if (color) {
        material.diffuse.contents = color;
    }
    material.lightingModelName = SCNLightingModelPhysicallyBased;
    material.metalness.contents = @(0.08);
    material.roughness.contents = @(0.1);
    return material;
}


#pragma mark model loader

- (SCNNode *)loadModel:(NSURL *)url nodeName:(NSString *)nodeName withAnimation:(BOOL)withAnimation {
    SCNScene *scene = [SCNScene sceneWithURL:url options:nil error:nil];
    
    SCNNode *node;
    if (nodeName) {
        node = [scene.rootNode childNodeWithName:nodeName recursively:YES];
    } else {
        node = [[SCNNode alloc] init];
        
        NSArray *nodeArray = [scene.rootNode childNodes];
        for (SCNNode *eachChild in nodeArray) {
            [node addChildNode:eachChild];
        }
    }
    
    if (withAnimation) {
        NSMutableArray *animationMutableArray = [NSMutableArray array];
        SCNSceneSource *sceneSource = [SCNSceneSource sceneSourceWithURL:url options:@{SCNSceneSourceAnimationImportPolicyKey:SCNSceneSourceAnimationImportPolicyPlayRepeatedly}];
        
        NSArray *animationIds = [sceneSource identifiersOfEntriesWithClass:[CAAnimation class]];
        for (NSString *eachId in animationIds){
            CAAnimation *animation = [sceneSource entryWithIdentifier:eachId withClass:[CAAnimation class]];
            [animationMutableArray addObject:animation];
            
        }
        NSArray *animationArray = [NSArray arrayWithArray:animationMutableArray];
        
        int i = 1;
        for (CAAnimation *animation in animationArray) {
            NSString *key = [NSString stringWithFormat:@"ANIM_%d", i];
            [node addAnimation:animation forKey:key];
            i++;
        }
    }
    
    return node;
}


#pragma mark executors of adding node to scene

- (void)addNodeToScene:(SCNNode *)node property:(NSDictionary *)property {
    node.position = [self getPositionFromProperty:property];
    node.eulerAngles = SCNVector3Make(0, [property[@"angle"] floatValue], 0);
    
    NSString *key = [NSString stringWithFormat:@"%@", property[@"id"]];
    if (key) {
        [self registerNode:node forKey:key];
    }
    [self.localOrigin addChildNode:node];
}

- (SCNVector3)getPositionFromProperty:(NSDictionary *)property {
    NSDictionary* pos = property[@"pos"];
    CGFloat x = [pos[@"x"] floatValue];
    CGFloat y = [pos[@"y"] floatValue];
    CGFloat z = [pos[@"z"] floatValue];
    
    if (pos[@"x"] == NULL) {
        x = self.cameraOrigin.position.x - self.localOrigin.position.x;
    }
    if (pos[@"y"] == NULL) {
        y = self.cameraOrigin.position.y - self.localOrigin.position.y;
    }
    if (pos[@"z"] == NULL) {
        z = self.cameraOrigin.position.z - self.localOrigin.position.z;
    }
    
    return SCNVector3Make(x, y, z);
}


#pragma mark node register

- (void)registerNode:(SCNNode *)node forKey:(NSString *)key {
    [self removeNodeForKey:key];
    [self.nodes setObject:node forKey:key];
}

- (SCNNode *)nodeForKey:(NSString *)key {
    return [self.nodes objectForKey:key];
}

- (void)removeNodeForKey:(NSString *)key {
    SCNNode *node = [self.nodes objectForKey:key];
    if (node == nil) {
        return;
    }
    [node removeFromParentNode];
    [self.nodes removeObjectForKey:key];
}


#pragma mark - plane hit detection

static NSMutableArray * mapHitResults(NSArray<ARHitTestResult *> *results) {
    NSMutableArray *resultsMapped = [NSMutableArray arrayWithCapacity:[results count]];
    [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        ARHitTestResult *result = (ARHitTestResult *) obj;
        [resultsMapped addObject:(@{
                                    @"distance": @(result.distance),
                                    @"point": @{
                                            @"x": @(result.worldTransform.columns[3].x),
                                            @"y": @(result.worldTransform.columns[3].y),
                                            @"z": @(result.worldTransform.columns[3].z)
                                            }
                                    
                                    } )];
    }];
    return resultsMapped;
}

- (NSMutableArray *) mapHitResultsWithSceneResults: (NSArray<SCNHitTestResult *> *)results {
    
    NSMutableArray *resultsMapped = [NSMutableArray arrayWithCapacity:[results count]];
    [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        SCNHitTestResult *result = (SCNHitTestResult *) obj;
        SCNNode * node = result.node;
        NSArray *keys = [self.nodes allKeysForObject: node];
        if([keys count]) {
            
            NSString * firstKey = [keys firstObject];
            [resultsMapped addObject:(@{
                                        
                                        @"id": firstKey
                                        
                                        } )];
        } else {
            NSLog(@"no key found for node %@", node);
            NSLog(@"for results %@", results);
            NSLog(@"all nodes %@", self.nodes);
            NSLog(@"origin %@", self.localOrigin);
        }
        
    }];
    return resultsMapped;
    
    
    
    
    
}


static NSDictionary * getPlaneHitResult(NSMutableArray *resultsMapped, const CGPoint tapPoint) {
    return @{
             @"results": resultsMapped,
             @"tapPoint": @{
                     @"x": @(tapPoint.x),
                     @"y": @(tapPoint.y)
                     }
             };
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

- (NSDictionary *)getPlaneHitResult:(const CGPoint)tapPoint  types:(ARHitTestResultType)types; {
    NSArray<ARHitTestResult *> *results = [self.arView hitTest:tapPoint types:types];
    NSMutableArray * resultsMapped = mapHitResults(results);
    
    NSDictionary *planeHitResult = getPlaneHitResult(resultsMapped, tapPoint);
    return planeHitResult;
}

- (NSDictionary *)getSceneObjectsHitResult:(const CGPoint)tapPoint  {
    
    NSDictionary *options = @{
                              SCNHitTestRootNodeKey: self.localOrigin
                              };
    NSArray<SCNHitTestResult *> *results = [self.arView hitTest:tapPoint  options:options];
    
    NSMutableArray * resultsMapped = [self mapHitResultsWithSceneResults:results];
    
    NSDictionary *planeHitResult = getSceneObjectHitResult(resultsMapped, tapPoint);
    return planeHitResult;
}



- (void)handleTapFrom: (UITapGestureRecognizer *)recognizer {
    // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
    CGPoint tapPoint = [recognizer locationInView:self.arView];
    //
    if(self.onTapOnPlaneUsingExtent) {
        // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
        NSDictionary * planeHitResult = [self getPlaneHitResult:tapPoint types:ARHitTestResultTypeExistingPlaneUsingExtent];
        self.onTapOnPlaneUsingExtent(planeHitResult);
    }
    
    if(self.onTapOnPlaneNoExtent) {
        // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
        NSDictionary * planeHitResult = [self getPlaneHitResult:tapPoint types:ARHitTestResultTypeExistingPlane];
        self.onTapOnPlaneNoExtent(planeHitResult);
    }
    
    
}


#pragma mark - ARSCNViewDelegate

- (void)renderer:(id <SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if (![anchor isKindOfClass:[ARPlaneAnchor class]]) {
        return;
    }
    
    SCNNode *parent = [node parentNode];
    NSLog(@"plane detected");
    //    NSLog(@"%f %f %f", parent.position.x, parent.position.y, parent.position.z);
    
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
    
    //    NSLog(@"%@", @{
    //            @"id": planeAnchor.identifier.UUIDString,
    //            @"alignment": @(planeAnchor.alignment),
    //            @"node": @{ @"x": @(node.position.x), @"y": @(node.position.y), @"z": @(node.position.z) },
    //            @"center": @{ @"x": @(planeAnchor.center.x), @"y": @(planeAnchor.center.y), @"z": @(planeAnchor.center.z) },
    //            @"extent": @{ @"x": @(planeAnchor.extent.x), @"y": @(planeAnchor.extent.y), @"z": @(planeAnchor.extent.z) },
    //            @"camera": @{ @"x": @(self.cameraOrigin.position.x), @"y": @(self.cameraOrigin.position.y), @"z": @(self.cameraOrigin.position.z) }
    //            });
    
    if (self.onPlaneDetected) {
        self.onPlaneDetected(@{
                               @"id": planeAnchor.identifier.UUIDString,
                               @"alignment": @(planeAnchor.alignment),
                               @"node": @{ @"x": @(node.position.x), @"y": @(node.position.y), @"z": @(node.position.z) },
                               @"center": @{ @"x": @(planeAnchor.center.x), @"y": @(planeAnchor.center.y), @"z": @(planeAnchor.center.z) },
                               @"extent": @{ @"x": @(planeAnchor.extent.x), @"y": @(planeAnchor.extent.y), @"z": @(planeAnchor.extent.z) },
                               @"camera": @{ @"x": @(self.cameraOrigin.position.x), @"y": @(self.cameraOrigin.position.y), @"z": @(self.cameraOrigin.position.z) }
                               });
    }
    
    //    Plane *plane = [[Plane alloc] initWithAnchor: (ARPlaneAnchor *)anchor isHidden: NO];
    //    [self.planes setObject:plane forKey:anchor.identifier];
    //    [node addChildNode:plane];
}

- (void)renderer:(id <SCNSceneRenderer>)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
    
    SCNNode *parent = [node parentNode];
    //    NSLog(@"%@", parent.name);
    //    NSLog(@"%f %f %f", node.position.x, node.position.y, node.position.z);
    //    NSLog(@"%f %f %f %f", node.rotation.x, node.rotation.y, node.rotation.z, node.rotation.w);
    
    
    //    NSLog(@"%@", @{
    //                   @"id": planeAnchor.identifier.UUIDString,
    //                   @"alignment": @(planeAnchor.alignment),
    //                   @"node": @{ @"x": @(node.position.x), @"y": @(node.position.y), @"z": @(node.position.z) },
    //                   @"center": @{ @"x": @(planeAnchor.center.x), @"y": @(planeAnchor.center.y), @"z": @(planeAnchor.center.z) },
    //                   @"extent": @{ @"x": @(planeAnchor.extent.x), @"y": @(planeAnchor.extent.y), @"z": @(planeAnchor.extent.z) },
    //                   @"camera": @{ @"x": @(self.cameraOrigin.position.x), @"y": @(self.cameraOrigin.position.y), @"z": @(self.cameraOrigin.position.z) }
    //                   });
    
    if (self.onPlaneUpdate) {
        self.onPlaneUpdate(@{
                             @"id": planeAnchor.identifier.UUIDString,
                             @"alignment": @(planeAnchor.alignment),
                             @"node": @{ @"x": @(node.position.x), @"y": @(node.position.y), @"z": @(node.position.z) },
                             @"center": @{ @"x": @(planeAnchor.center.x), @"y": @(planeAnchor.center.y), @"z": @(planeAnchor.center.z) },
                             @"extent": @{ @"x": @(planeAnchor.extent.x), @"y": @(planeAnchor.extent.y), @"z": @(planeAnchor.extent.z) },
                             @"camera": @{ @"x": @(self.cameraOrigin.position.x), @"y": @(self.cameraOrigin.position.y), @"z": @(self.cameraOrigin.position.z) }
                             });
    }
    
    //    Plane *plane = [self.planes objectForKey:anchor.identifier];
    //    if (plane == nil) {
    //        return;
    //    }
    //
    //    [plane update:(ARPlaneAnchor *)anchor];
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    //    [self.planes removeObjectForKey:anchor.identifier];
}


#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    simd_float4 pos = frame.camera.transform.columns[3];
    self.cameraOrigin.position = SCNVector3Make(pos.x, pos.y, pos.z);
    simd_float4 z = frame.camera.transform.columns[2];
    self.cameraOrigin.eulerAngles = SCNVector3Make(0, atan2f(z.x, z.z), 0);
}

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    if (self.onTrackingState) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onTrackingState(@{
                                   @"state": @(camera.trackingState),
                                   @"reason": @(camera.trackingStateReason)
                                   });
        });
    }
}


#pragma mark - dealloc
-(void) dealloc {
}

@end


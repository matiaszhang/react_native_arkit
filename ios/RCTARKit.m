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

@interface RCTARKit () <ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate> {
    RCTPromiseResolveBlock _resolve;
}

@property (nonatomic, strong) ARSession* session;
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
        
        self.arkitIO = [RCTARKitIO sharedInstance];
        
        // delegates
        arView.delegate = self;
        arView.session.delegate = self;
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        [self.arView addGestureRecognizer:tapGestureRecognizer];
        
        self.touchDelegates = [NSMutableArray array];
        self.rendererDelegates = [NSMutableArray array];
        self.sessionDelegates = [NSMutableArray array];
        
        // nodeManager
        self.nodeManager = [RCTARKitNodes sharedInstance];
        self.nodeManager.arView = arView;
        [self.sessionDelegates addObject:self.nodeManager];
        
        // configuration(s)
        arView.autoenablesDefaultLighting = YES;
        arView.scene.rootNode.name = @"root";
        
        self.planes = [NSMutableDictionary new];
        
        // start ARKit
        [self addSubview:arView];
        [self resume];
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
    [self.session runWithConfiguration:self.configuration];
}

- (void)focusScene {
    [self.nodeManager.localOrigin setPosition:self.nodeManager.cameraOrigin.position];
    [self.nodeManager.localOrigin setRotation:self.nodeManager.cameraOrigin.rotation];
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
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *) self.session.configuration;
    return configuration.planeDetection == ARPlaneDetectionHorizontal;
}

- (void)setPlaneDetection:(BOOL)planeDetection {
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *) self.session.configuration;
    if (planeDetection) {
        configuration.planeDetection = ARPlaneDetectionHorizontal;
    } else {
        configuration.planeDetection = ARPlaneDetectionNone;
    }
    [self resume];
}

- (BOOL)lightEstimation {
    ARConfiguration *configuration = self.session.configuration;
    return configuration.lightEstimationEnabled;
}

- (void)setLightEstimation:(BOOL)lightEstimation {
    ARConfiguration *configuration = self.session.configuration;
    configuration.lightEstimationEnabled = lightEstimation;
    [self resume];
}

- (NSDictionary *)readCameraPosition {
    SCNVector3 cameraPosition = self.nodeManager.cameraOrigin.position;
    return @{ @"x": @(cameraPosition.x), @"y": @(cameraPosition.y), @"z": @(cameraPosition.z) };
}



#pragma mark - Lazy loads

-(ARWorldTrackingConfiguration *)configuration {
    if (_configuration) {
        return _configuration;
    }
    
    if (!ARWorldTrackingConfiguration.isSupported) {}
    
    _configuration = [ARWorldTrackingConfiguration new];
    _configuration.planeDetection = ARPlaneDetectionHorizontal;
    
    return _configuration;
}



#pragma mark - snapshot methods

- (void)snapshot:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    UIImage *image = [self.arView snapshot];
    // FIXME: I belive this is not the right way. I don't know how to pass 'resolve' to the completionSelector
    // If you know how to do it, please PR. Thanks!
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



#pragma mark - add a model or a geometry

- (void)addBox:(NSDictionary *)property {
    CGFloat width = [property[@"width"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    CGFloat length = [property[@"length"] floatValue];
    CGFloat chamfer = [property[@"chamfer"] floatValue];
    SCNBox *geometry = [SCNBox boxWithWidth:width height:height length:length chamferRadius:chamfer];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material, material, material, material, material, material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addSphere:(NSDictionary *)property {
    CGFloat radius = [property[@"radius"] floatValue];
    SCNSphere *geometry = [SCNSphere sphereWithRadius:radius];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addCylinder:(NSDictionary *)property {
    CGFloat radius = [property[@"radius"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    SCNCylinder *geometry = [SCNCylinder cylinderWithRadius:radius height:height];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material, material, material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addCone:(NSDictionary *)property {
    CGFloat topR = [property[@"topR"] floatValue];
    CGFloat bottomR = [property[@"bottomR"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    SCNCone *geometry = [SCNCone coneWithTopRadius:topR bottomRadius:bottomR height:height];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material, material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addPyramid:(NSDictionary *)property {
    CGFloat width = [property[@"width"] floatValue];
    CGFloat length = [property[@"length"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    SCNPyramid *geometry = [SCNPyramid pyramidWithWidth:width height:height length:length];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material, material, material, material, material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addTube:(NSDictionary *)property {
    CGFloat innerR = [property[@"innerR"] floatValue];
    CGFloat outerR = [property[@"outerR"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    SCNTube *geometry = [SCNTube tubeWithInnerRadius:innerR outerRadius:outerR height:height];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material, material, material, material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addTorus:(NSDictionary *)property {
    CGFloat ringR = [property[@"ringR"] floatValue];
    CGFloat pipeR = [property[@"pipeR"] floatValue];
    SCNTorus *geometry = [SCNTorus torusWithRingRadius:ringR pipeRadius:pipeR];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addCapsule:(NSDictionary *)property {
    CGFloat capR = [property[@"capR"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    SCNCapsule *geometry = [SCNCapsule capsuleWithCapRadius:capR height:height];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addPlane:(NSDictionary *)property {
    CGFloat width = [property[@"width"] floatValue];
    CGFloat height = [property[@"height"] floatValue];
    SCNPlane *geometry = [SCNPlane planeWithWidth:width height:height];
    
    SCNMaterial *material = [self materialFromProperty:property];
    geometry.materials = @[material];
    
    SCNNode *node = [SCNNode nodeWithGeometry:geometry];
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addText:(NSDictionary *)property {
    // init SCNText
    NSString *text = [NSString stringWithFormat:@"%@", property[@"text"]];
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
    
    // material
    SCNMaterial *face = [self materialFromProperty:property];
    SCNMaterial *border = [self materialFromProperty:property];
    scnText.materials = @[face, face, border, border, border];
    
    // init SCNNode
    SCNNode *textNode = [SCNNode nodeWithGeometry:scnText];
    
    // position textNode
    SCNVector3 min = SCNVector3Zero;
    SCNVector3 max = SCNVector3Zero;
    [textNode getBoundingBoxMin:&min max:&max];
    textNode.position = SCNVector3Make(-(min.x + max.x) / 2, -(min.y + max.y) / 2, -(min.z + max.z) / 2);
    
    SCNNode *textOrigin = [[SCNNode alloc] init];
    [textOrigin addChildNode:textNode];
    textOrigin.scale = SCNVector3Make(size, size, size);
    [self.nodeManager addNodeToScene:textOrigin property:property];
}

- (void)addModel:(NSDictionary *)property {
    CGFloat scale = [property[@"scale"] floatValue];
    
    NSString *path = [NSString stringWithFormat:@"%@", property[@"file"]];
    SCNNode *node = [self.arkitIO loadModel:path nodeName:property[@"node"] withAnimation:YES];
    
    node.scale = SCNVector3Make(scale, scale, scale);
    [self.nodeManager addNodeToScene:node property:property];
}

- (void)addImage:(NSDictionary *)property {}

- (SCNMaterial *)materialFromProperty:(NSDictionary *)property {
    SCNMaterial *material = [SCNMaterial new];
    
    if (property[@"color"]) {
        CGFloat r = [property[@"r"] floatValue];
        CGFloat g = [property[@"g"] floatValue];
        CGFloat b = [property[@"b"] floatValue];
        CGFloat a = [property[@"a"] floatValue];
        UIColor *color = [[UIColor alloc] initWithRed:r green:g blue:b alpha:a];
        material.diffuse.contents = color;
    } else {
        material.diffuse.contents = [UIColor whiteColor];
    }
    
    if (property[@"metalness"]) {
        material.lightingModelName = SCNLightingModelPhysicallyBased;
        material.metalness.contents = @([property[@"metalness"] floatValue]);
    }
    if (property[@"roughness"]) {
        material.lightingModelName = SCNLightingModelPhysicallyBased;
        material.roughness.contents = @([property[@"roughness"] floatValue]);
    }
    
    return material;
}



#pragma mark - plane hit detection

- (void)hitTestPlane:(const CGPoint)tapPoint types:(ARHitTestResultType)types resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    
    resolve([self getPlaneHitResult:tapPoint types:types]);
}

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

static NSDictionary * getPlaneHitResult(NSMutableArray *resultsMapped, const CGPoint tapPoint) {
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

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    for (id<RCTARKitRendererDelegate> rendererDelegate in self.rendererDelegates) {
        if ([rendererDelegate respondsToSelector:@selector(renderer:updateAtTime:)]) {
            [rendererDelegate renderer:renderer updateAtTime:time];
        }
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time {
    for (id<RCTARKitRendererDelegate> rendererDelegate in self.rendererDelegates) {
        if ([rendererDelegate respondsToSelector:@selector(renderer:didRenderScene:atTime:)]) {
            [rendererDelegate renderer:renderer didRenderScene:scene atTime:time];
        }
    }
}

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
//                               @"camera": @{ @"x": @(self.cameraOrigin.position.x), @"y": @(self.cameraOrigin.position.y), @"z": @(self.cameraOrigin.position.z) }
                               });
    }
    
    //Plane *plane = [[Plane alloc] initWithAnchor: (ARPlaneAnchor *)anchor isHidden: NO];
    //[self.planes setObject:plane forKey:anchor.identifier];
    //[node addChildNode:plane];
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
//                             @"camera": @{ @"x": @(self.cameraOrigin.position.x), @"y": @(self.cameraOrigin.position.y), @"z": @(self.cameraOrigin.position.z) }
                             });
    }
    
    Plane *plane = [self.planes objectForKey:anchor.identifier];
    if (plane == nil) {
        return;
    }

    [plane update:(ARPlaneAnchor *)anchor];
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    [self.planes removeObjectForKey:anchor.identifier];
}



#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    for (id<RCTARKitSessionDelegate> sessionDelegate in self.sessionDelegates) {
        if ([sessionDelegate respondsToSelector:@selector(session:didUpdateFrame:)]) {
            [sessionDelegate session:session didUpdateFrame:frame];
        }
    }
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



#pragma mark - RCTARKitTouchDelegate

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:beganWithEvent:)]) {
            [touchDelegate touches:touches beganWithEvent:event];
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:movedWithEvent:)]) {
            [touchDelegate touches:touches movedWithEvent:event];
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:endedWithEvent:)]) {
            [touchDelegate touches:touches endedWithEvent:event];
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    for (id<RCTARKitTouchDelegate> touchDelegate in self.touchDelegates) {
        if ([touchDelegate respondsToSelector:@selector(touches:cancelledWithEvent:)]) {
            [touchDelegate touches:touches cancelledWithEvent:event];
        }
    }
}



#pragma mark - dealloc
-(void) dealloc {
}

@end


//
//  MMPanAndPinchScrapGestureRecognizer.h
//  LooseLeaf
//
//  Created by Adam Wulf on 8/25/13.
//  Copyright (c) 2013 Milestone Made, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "Constants.h"
#import "MMScrapView.h"
#import "MMPanAndPinchScrapGestureRecognizerDelegate.h"

@interface MMPanAndPinchScrapGestureRecognizer : UIGestureRecognizer{
    // the initial distance between
    // the touches. to be used to calculate
    // scale
    CGFloat initialDistance;

    // the collection of valid touches for this gesture
    NSMutableSet* ignoredTouches;
    NSMutableOrderedSet* possibleTouches;
    NSMutableOrderedSet* validTouches;

    // track which bezels our delegate cares about
    MMBezelDirection bezelDirectionMask;
    // the direction that the user actually did exit, if any
    MMBezelDirection didExitToBezel;
    // track the direction of the scale
    MMBezelScaleDirection scaleDirection;
    
    //
    // don't allow both the 2nd to last touch
    // and the last touch to trigger a repeat
    // of the bezel
    BOOL secondToLastTouchDidBezel;
    
    __weak NSObject<MMPanAndPinchScrapGestureRecognizerDelegate>* scrapDelegate;
    
}

@property (nonatomic, assign) BOOL shouldReset;
@property (nonatomic, assign) MMBezelDirection bezelDirectionMask;
@property (nonatomic, readonly) MMBezelDirection didExitToBezel;
@property (nonatomic, weak) NSObject<MMPanAndPinchScrapGestureRecognizerDelegate>* scrapDelegate;
@property (readonly) NSArray* touches;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat rotation;
@property (nonatomic, readonly) CGPoint translation;
@property (nonatomic, readonly) BOOL isShaking;
@property (nonatomic, weak) MMScrapView* scrap;
@property (assign) CGFloat preGestureScale;
@property (assign) CGFloat preGesturePageScale;
@property (assign) CGFloat preGestureRotation;
@property (assign) CGPoint preGestureCenter;

-(void) ownershipOfTouches:(NSSet*)touches isGesture:(UIGestureRecognizer*)gesture;
-(void) giveUpScrap;
-(void) cancel;
-(void) blessTouches:(NSSet*)touches;

@end

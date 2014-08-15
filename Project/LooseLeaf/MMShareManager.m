//
//  MMShareManager.m
//  LooseLeaf
//
//  Created by Adam Wulf on 8/10/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "MMShareManager.h"
#import "NSThread+BlockAdditions.h"
#import "UIView+Debug.h"
#import <JotUI/JotUI.h>

@implementation MMShareManager{
    // the document controller that we'll
    // use for drawing the buttons
    UIDocumentInteractionController* controller;
    NSMutableArray* allFoundCollectionViews;
    NSTimer* mainThreadSharingTimer;
    
    NSMutableArray* arrayOfDismissViews;
    NSMutableArray* arrayOfAllowableIndexPaths;
    NSArray* arrayOfLastLoadedIndexPaths;
    BOOL needsWait;
    BOOL needsLoad;
}

static UIView* shareTarget;
static BOOL shouldListenToRegisterViews;
static MMShareManager* _instance = nil;

+(BOOL) shouldListenToRegisterViews{
    return shouldListenToRegisterViews;
}

+(UIView*)shareTargetView{
    return shareTarget;
}
+(void) setShareTargetView:(UIView*)_shareTarget{
    shareTarget = _shareTarget;
}

@synthesize delegate;

-(NSArray*)allFoundCollectionViews{
    return [NSArray arrayWithArray:allFoundCollectionViews];
}

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        _instance = self;
        allFoundCollectionViews = [NSMutableArray array];
        arrayOfAllowableIndexPaths = [NSMutableArray array];
        arrayOfDismissViews = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(endSharing)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

    }
    return _instance;
}

+(MMShareManager*) sharedInstance{
    if(!_instance){
        _instance = [[MMShareManager alloc]init];
    }
    return _instance;
}

#pragma mark - Create and Dismiss the Document Controller

-(void) beginSharingWithURL:(NSURL*)fileLocation{
    CheckMainThread;
    if(!controller){
        NSLog(@"begin sharing");
        UIWindow* win = [[UIApplication sharedApplication] keyWindow];
        controller = [UIDocumentInteractionController interactionControllerWithURL:fileLocation];
        
        needsLoad = YES;
        
        shouldListenToRegisterViews = YES;
        [controller presentOpenInMenuFromRect:CGRectMake(0, 0, 10, 10) inView:win animated:NO];
        shouldListenToRegisterViews = NO;
        
        mainThreadSharingTimer = [NSTimer scheduledTimerWithTimeInterval:.03 target:self selector:@selector(tick) userInfo:nil repeats:YES];
        [self performSelector:@selector(tick) withObject:nil afterDelay:.01];
    }
}

-(void) endSharing{
    CheckMainThread;
    
    if(controller){
        NSLog(@"end sharing");
        [controller dismissMenuAnimated:NO];
        controller = nil;
        [allFoundCollectionViews removeAllObjects];
        [MMShareManager setShareTargetView:nil];
        [arrayOfAllowableIndexPaths removeAllObjects];
        
        UIWindow* win = [[UIApplication sharedApplication] keyWindow];
        [[win rootViewController] dismissViewControllerAnimated:NO completion:nil];
        
        [self.delegate sharingHasEnded];
    }
    
    [mainThreadSharingTimer invalidate];
    mainThreadSharingTimer = nil;
}

#pragma mark - Number of Sharable Targets

-(NSUInteger) numberOfShareTargets{
    NSUInteger totalShareItems = 0;
    for(UICollectionView* cv in allFoundCollectionViews){
        totalShareItems += [cv numberOfItemsInSection:0];
    }
    return totalShareItems;
}

-(UIView*) viewForIndexPath:(NSIndexPath*)indexPath forceGet:(BOOL)force{
    CheckMainThread;
    if(indexPath.section < [allFoundCollectionViews count]){
        UICollectionView* cv = [allFoundCollectionViews objectAtIndex:indexPath.section];
        if(indexPath.row < [cv numberOfItemsInSection:0]){
            NSIndexPath* pathInCv = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
            UIView* cell = [cv cellForItemAtIndexPath:pathInCv];
            if(!cell && force){
                [cv scrollToItemAtIndexPath:pathInCv atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally | UICollectionViewScrollPositionCenteredVertically animated:NO];
                [cv reloadItemsAtIndexPaths:[NSArray arrayWithObject:pathInCv]];
                cell = [cv cellForItemAtIndexPath:pathInCv];
            }
            return cell;
        }
    }
    return nil;
}

#pragma mark - Registering Popover and Collection Views

-(void) registerDismissView:(UIView*)dismissView{
    dismissView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:.5];
    dismissView.alpha = .5;
    dismissView.hidden = YES;
}

-(void) addCollectionView:(UICollectionView*)view{
    @synchronized(self){
        NSString* dataSourceType = NSStringFromClass([view.dataSource class]);
        if([dataSourceType rangeOfString:@"Air"].location == NSNotFound &&
           [dataSourceType rangeOfString:@"Drop"].location == NSNotFound){
            NSLog(@"found collection view with datasource type: %@", dataSourceType);
            [allFoundCollectionViews addObject:view];
        }
    }
}

#pragma mark - Dealloc

-(void) dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Timer for finding share items

-(void) tick{
    if(![arrayOfAllowableIndexPaths count] && needsLoad){
        NSInteger section = 0;
        for(UICollectionView* cv in allFoundCollectionViews){
            NSInteger itemCount = [cv numberOfItemsInSection:0];
            for (NSInteger index=0; index < itemCount; index++) {
                [arrayOfAllowableIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:section]];
            }
            section++;
            arrayOfLastLoadedIndexPaths = [NSArray arrayWithArray:arrayOfAllowableIndexPaths];
            needsLoad = NO;
        }
        // notify that we're about to load each cell
        [delegate allCellsWillLoad];
    }else if(!needsLoad && [arrayOfAllowableIndexPaths count]){
        if(needsWait){
            NSIndexPath* loadedPath = [arrayOfAllowableIndexPaths firstObject];
            [arrayOfAllowableIndexPaths removeObject:loadedPath];
            
            UIView* cell = [self viewForIndexPath:loadedPath forceGet:NO];
            [self.delegate cellLoaded:cell forIndexPath:loadedPath];
            needsWait = NO;
//            NSLog(@"notifying to %d:%d", loadedPath.section, loadedPath.row);
            
            if(![arrayOfAllowableIndexPaths count]){
                [delegate allCellsLoaded:arrayOfLastLoadedIndexPaths];
            }
        }else{
            NSIndexPath* loadedPath = [arrayOfAllowableIndexPaths firstObject];
            // force scroll cell into view
            [self viewForIndexPath:loadedPath forceGet:YES];
            needsWait = YES;
//            NSLog(@"scrolling to %d:%d", loadedPath.section, loadedPath.row);
        }
    }else{
        NSInteger section = 0;
        for(UICollectionView* cv in allFoundCollectionViews){
            NSInteger itemCount = [cv numberOfItemsInSection:0];
            NSLog(@"section %@ %d number %d", NSStringFromClass([cv.dataSource class]), section, itemCount);
            section++;
        }
        
        NSLog(@"resetting data to force a reload every time");
        // reload
        [arrayOfAllowableIndexPaths removeAllObjects];
        needsLoad = YES;
        needsWait = NO;
    }
}

@end

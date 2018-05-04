//
//  AIRGoogleMapManager.h
//  AirMaps
//
//  Created by Gil Birman on 9/1/16.
//

#import <React/RCTViewManager.h>
#import "AIRGMSMarker.h"

@interface AIRGoogleMapManager : RCTViewManager

@property (nonatomic, strong) NSMutableArray* warningArray;
@property (nonatomic, strong) AIRGMSMarker* navigationMarker;

@end

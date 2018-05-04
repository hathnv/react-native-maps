//
//  AIRGoogleMapManager.m
//  AirMaps
//
//  Created by Gil Birman on 9/1/16.
//


#import "AIRGoogleMapManager.h"
#import <React/RCTViewManager.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTConvert+CoreLocation.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTViewManager.h>
#import <React/RCTConvert.h>
#import <React/UIView+React.h>
#import "RCTConvert+GMSMapViewType.h"
#import "AIRGoogleMap.h"
#import "AIRMapMarker.h"
#import "AIRMapPolyline.h"
#import "AIRMapPolygon.h"
#import "AIRMapCircle.h"
#import "SMCalloutView.h"
#import "AIRGoogleMapMarker.h"
#import "RCTConvert+AirMap.h"

#import <MapKit/MapKit.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const RCTMapViewKey = @"MapView";

@interface AIRGoogleMapManager() <GMSMapViewDelegate>
{
  BOOL didCallOnMapReady;
}
  
@end

@implementation AIRGoogleMapManager

- (instancetype)init
{
    if ((self = [super init])) {
        _warningArray = [NSMutableArray array];
    }
    return self;
}

RCT_EXPORT_MODULE()

- (UIView *)view
{
  AIRGoogleMap *map = [AIRGoogleMap new];
  map.delegate = self;
  return map;
}

RCT_EXPORT_VIEW_PROPERTY(initialRegion, MKCoordinateRegion)
RCT_EXPORT_VIEW_PROPERTY(region, MKCoordinateRegion)
RCT_EXPORT_VIEW_PROPERTY(showsBuildings, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsCompass, BOOL)
//RCT_EXPORT_VIEW_PROPERTY(showsScale, BOOL)  // Not supported by GoogleMaps
RCT_EXPORT_VIEW_PROPERTY(showsTraffic, BOOL)
RCT_EXPORT_VIEW_PROPERTY(zoomEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(rotateEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(scrollEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(pitchEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsUserLocation, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsMyLocationButton, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showsIndoorLevelPicker, BOOL)
RCT_EXPORT_VIEW_PROPERTY(customMapStyleString, NSString)
RCT_EXPORT_VIEW_PROPERTY(mapPadding, UIEdgeInsets)
RCT_EXPORT_VIEW_PROPERTY(onMapReady, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPress, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLongPress, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onChange, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMarkerPress, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onRegionChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onRegionChangeComplete, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(mapType, GMSMapViewType)
RCT_EXPORT_VIEW_PROPERTY(minZoomLevel, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(maxZoomLevel, CGFloat)

//Custom
RCT_EXPORT_VIEW_PROPERTY(onCustomMarkerPress, RCTBubblingEventBlock)

RCT_EXPORT_METHOD(setMyLocationEnabled: (nonnull NSNumber *)reactTag
                    isMyLocationEnabled: (nonnull NSString *) bState)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[AIRGoogleMap class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
        } else {
            BOOL state;
            if([bState isEqual: @"true"]){
                state = YES;
            } else {
                state = NO;
            }
            AIRGoogleMap *mapView = (AIRGoogleMap *)view;
            mapView.myLocationEnabled = state;
        }
    }];
}

RCT_EXPORT_METHOD(addMarkerNative: (nonnull NSNumber *)reactTag
                  withCoordinate:(CLLocationCoordinate2D)latlng
                  withImage: (NSString *) imageSrc
                  withPointID: (nonnull NSString *) pointId
                  withRotation: (nonnull NSNumber *) rotation){
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[AIRGoogleMap class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
        } else {
            AIRGoogleMap *mapView = (AIRGoogleMap *)view;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSURLRequest *request = [RCTConvert NSURLRequest:imageSrc];
                NSHTTPURLResponse *response = nil;
                NSError *error = nil;
                NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                UIImage* image = [UIImage imageWithData:responseData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(self.navigationMarker == nil){
                        self.navigationMarker = [[AIRGMSMarker alloc] init];
                    }
                    self.navigationMarker.position = latlng;
                    UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
                    CGRect bounds = CGRectMake(0, 0, 116, 116);
                    imageView.contentMode = UIViewContentModeScaleAspectFit;
                    [imageView setFrame:bounds];
                    self.navigationMarker.tracksViewChanges = false;
                    self.navigationMarker.iconView = imageView;
                    self.navigationMarker.rotation = (CLLocationDegrees)[rotation doubleValue];
                    self.navigationMarker.groundAnchor = CGPointMake(0.5, 0.5);
                    self.navigationMarker.flat = YES;
                    self.navigationMarker.map = mapView;
                });
            });
        }
    }];
}

RCT_EXPORT_METHOD(removeMarkerNative: (nonnull NSNumber *)reactTag){
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        if(self.navigationMarker != nil){
            self.navigationMarker.map = nil;
            self.navigationMarker = nil;
        }
    }];
}

RCT_EXPORT_METHOD(addMarker: (nonnull NSNumber *)reactTag
                    withCoordinate:(CLLocationCoordinate2D)latlng
                    withImage: (NSString *) imageSrc
                    withPointId: (nonnull NSString *) pointId
                    withZoomLevel: (nonnull NSNumber *) zoomLevel){
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[AIRGoogleMap class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
        } else {
            AIRGoogleMap *mapView = (AIRGoogleMap *)view;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Background work
              NSURLRequest *request = [RCTConvert NSURLRequest:imageSrc];
              NSHTTPURLResponse *response = nil;
              NSError *error = nil;
              NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
              UIImage* image = [UIImage imageWithData:responseData];
              dispatch_async(dispatch_get_main_queue(), ^{
                  // Update UI
                AIRGMSMarker* marker = [[AIRGMSMarker alloc] init];
                marker.position = latlng;
                  
                  UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
                  
                  float w,h;
//                  if([zoomLevel integerValue] >= 17){
                      w = 30*2; h = 29*2;
//                  } else {
//                      w = 25; h = 24;
//                  }
                  
                  CGRect bounds = CGRectMake(0, 0, w, h);
                  imageView.contentMode = UIViewContentModeScaleAspectFit;
                  [imageView setFrame:bounds];
                  marker.tracksViewChanges = false;
//                marker.icon = image;
                  marker.iconView = imageView;
                marker.identifier = [NSString stringWithFormat:@"%@_%f_%f",pointId,latlng.latitude,latlng.longitude];
                marker.onPress = mapView.onCustomMarkerPress;
//                marker.map = mapView;
                  marker.map = mapView;
                    [self.warningArray addObject:marker];
              });
            });
        }
    }];
}

RCT_EXPORT_METHOD(removeAllMarker: (nonnull NSNumber *)reactTag){
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        for(AIRGMSMarker *marker in self.warningArray){
            marker.map = nil;
        }
        [self.warningArray removeAllObjects];
    }];
}

                    

RCT_EXPORT_METHOD(animateToCameraWithZoom: (nonnull NSNumber *)reactTag
                    withLatitude: (CGFloat) latitude
                    withLongtitude: (CGFloat) longtitude
                    withZoom: (CGFloat) zoom
                    withDuration: (CGFloat) duration)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[AIRGoogleMap class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
        } else {
            // Core Animation must be used to control the animation's duration
            // See http://stackoverflow.com/a/15663039/171744
            [CATransaction begin];
            [CATransaction setAnimationDuration:duration/1000];
            AIRGoogleMap *mapView = (AIRGoogleMap *)view;
            GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude
                                                                    longitude:longtitude
                                                                         zoom:zoom];
            [mapView animateToCameraPosition:camera];
            [CATransaction commit];
        }
    }];
}

RCT_EXPORT_METHOD(animateToCameraWithAngle: (nonnull NSNumber *)reactTag
                    withLatitude: (CGFloat) latitude
                    withLongtitude: (CGFloat) longtitude
                    withZoom: (CGFloat) zoom
                    withAngle: (double) angle
                    withBearing: (CGFloat) bearing
                    withDuration: (CGFloat) duration)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[AIRGoogleMap class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
        } else {
            // Core Animation must be used to control the animation's duration
            // See http://stackoverflow.com/a/15663039/171744
            [CATransaction begin];
            [CATransaction setAnimationDuration:duration/1000];
            AIRGoogleMap *mapView = (AIRGoogleMap *)view;
            CGFloat newBearing;
            if(bearing < 0){
                newBearing = mapView.camera.bearing;
            } else {
                newBearing = bearing;
            }
            CGFloat newLat = latitude + 0.002 * cos(newBearing * M_PI/180);
            CGFloat newLng = longtitude + 0.002 * sin(newBearing * M_PI/180);
            GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude: newLat
                                                                      longitude:newLng
                                                                           zoom:zoom
                                                                        bearing:newBearing
                                                                   viewingAngle:angle];
            [mapView animateToCameraPosition:camera];
            [CATransaction commit];
        }
    }];
}

RCT_EXPORT_METHOD(zoomMap:(nonnull NSNumber *)reactTag
                  withZoomLevel: (CGFloat) zoom
                  withDuration: (CGFloat) duration)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[AIRGoogleMap class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
        } else {
            // Core Animation must be used to control the animation's duration
            // See http://stackoverflow.com/a/15663039/171744
            [CATransaction begin];
            [CATransaction setAnimationDuration:duration/1000];
            AIRGoogleMap *mapView = (AIRGoogleMap *)view;
            [mapView animateToZoom: zoom];
            [CATransaction commit];
        }
    }];
}

RCT_EXPORT_METHOD(animateToRegion:(nonnull NSNumber *)reactTag
                  withRegion:(MKCoordinateRegion)region
                  withDuration:(CGFloat)duration)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      // Core Animation must be used to control the animation's duration
      // See http://stackoverflow.com/a/15663039/171744
      [CATransaction begin];
      [CATransaction setAnimationDuration:duration/1000];
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;
      GMSCameraPosition *camera = [AIRGoogleMap makeGMSCameraPositionFromMap:mapView andMKCoordinateRegion:region];
      [mapView animateToCameraPosition:camera];
      [CATransaction commit];
    }
  }];
}

RCT_EXPORT_METHOD(animateToCoordinate:(nonnull NSNumber *)reactTag
                  withRegion:(CLLocationCoordinate2D)latlng
                  withDuration:(CGFloat)duration)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      [CATransaction begin];
      [CATransaction setAnimationDuration:duration/1000];
      [(AIRGoogleMap *)view animateToLocation:latlng];
      [CATransaction commit];
    }
  }];
}

RCT_EXPORT_METHOD(animateToViewingAngle:(nonnull NSNumber *)reactTag
                  withAngle:(double)angle
                  withDuration:(CGFloat)duration)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      [CATransaction begin];
      [CATransaction setAnimationDuration:duration/1000];
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;
      [mapView animateToViewingAngle:angle];
      [CATransaction commit];
    }
  }];
}

RCT_EXPORT_METHOD(animateToBearing:(nonnull NSNumber *)reactTag
                  withBearing:(CGFloat)bearing
                  withDuration:(CGFloat)duration)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      [CATransaction begin];
      [CATransaction setAnimationDuration:duration/1000];
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;
      [mapView animateToBearing:bearing];
      [CATransaction commit];
    }
  }];
}

RCT_EXPORT_METHOD(fitToElements:(nonnull NSNumber *)reactTag
                  animated:(BOOL)animated)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;

      CLLocationCoordinate2D myLocation = ((AIRGoogleMapMarker *)(mapView.markers.firstObject)).realMarker.position;
      GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:myLocation coordinate:myLocation];

      for (AIRGoogleMapMarker *marker in mapView.markers)
        bounds = [bounds includingCoordinate:marker.realMarker.position];

      [mapView animateWithCameraUpdate:[GMSCameraUpdate fitBounds:bounds withPadding:55.0f]];
    }
  }];
}

RCT_EXPORT_METHOD(fitToSuppliedMarkers:(nonnull NSNumber *)reactTag
                  markers:(nonnull NSArray *)markers
                  animated:(BOOL)animated)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;

      NSPredicate *filterMarkers = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        AIRGoogleMapMarker *marker = (AIRGoogleMapMarker *)evaluatedObject;
        return [marker isKindOfClass:[AIRGoogleMapMarker class]] && [markers containsObject:marker.identifier];
      }];

      NSArray *filteredMarkers = [mapView.markers filteredArrayUsingPredicate:filterMarkers];

      CLLocationCoordinate2D myLocation = ((AIRGoogleMapMarker *)(filteredMarkers.firstObject)).realMarker.position;
      GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:myLocation coordinate:myLocation];

      for (AIRGoogleMapMarker *marker in filteredMarkers)
        bounds = [bounds includingCoordinate:marker.realMarker.position];

      [mapView animateWithCameraUpdate:[GMSCameraUpdate fitBounds:bounds withPadding:55.0f]];
    }
  }];
}

RCT_EXPORT_METHOD(fitToCoordinates:(nonnull NSNumber *)reactTag
                  coordinates:(nonnull NSArray<AIRMapCoordinate *> *)coordinates
                  edgePadding:(nonnull NSDictionary *)edgePadding
                  animated:(BOOL)animated)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;

      CLLocationCoordinate2D myLocation = coordinates.firstObject.coordinate;
      GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:myLocation coordinate:myLocation];

      for (AIRMapCoordinate *coordinate in coordinates)
        bounds = [bounds includingCoordinate:coordinate.coordinate];

      // Set Map viewport
      CGFloat top = [RCTConvert CGFloat:edgePadding[@"top"]];
      CGFloat right = [RCTConvert CGFloat:edgePadding[@"right"]];
      CGFloat bottom = [RCTConvert CGFloat:edgePadding[@"bottom"]];
      CGFloat left = [RCTConvert CGFloat:edgePadding[@"left"]];

      [mapView animateWithCameraUpdate:[GMSCameraUpdate fitBounds:bounds withEdgeInsets:UIEdgeInsetsMake(top, left, bottom, right)]];
    }
  }];
}

RCT_EXPORT_METHOD(takeSnapshot:(nonnull NSNumber *)reactTag
                  withWidth:(nonnull NSNumber *)width
                  withHeight:(nonnull NSNumber *)height
                  withRegion:(MKCoordinateRegion)region
                  format:(nonnull NSString *)format
                  quality:(nonnull NSNumber *)quality
                  result:(nonnull NSString *)result
                  withCallback:(RCTResponseSenderBlock)callback)
{
  NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
  NSString *pathComponent = [NSString stringWithFormat:@"Documents/snapshot-%.20lf.%@", timeStamp, format];
  NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent: pathComponent];

  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
        RCTLogError(@"Invalid view returned from registry, expecting AIRMap, got: %@", view);
    } else {
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;
      
      // TODO: currently we are ignoring width, height, region
        
      UIGraphicsBeginImageContextWithOptions(mapView.frame.size, YES, 0.0f);
      [mapView.layer renderInContext:UIGraphicsGetCurrentContext()];
      UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        
      NSData *data;
      if ([format isEqualToString:@"png"]) {
          data = UIImagePNGRepresentation(image);
          
      }
      else if([format isEqualToString:@"jpg"]) {
            data = UIImageJPEGRepresentation(image, quality.floatValue);
      }
      
      if ([result isEqualToString:@"file"]) {
          [data writeToFile:filePath atomically:YES];
            callback(@[[NSNull null], filePath]);
        }
        else if ([result isEqualToString:@"base64"]) {
            callback(@[[NSNull null], [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]);
        }
        else if ([result isEqualToString:@"legacy"]) {
            
            // In the initial (iOS only) implementation of takeSnapshot,
            // both the uri and the base64 encoded string were returned.
            // Returning both is rarely useful and in fact causes a
            // performance penalty when only the file URI is desired.
            // In that case the base64 encoded string was always marshalled
            // over the JS-bridge (which is quite slow).
            // A new more flexible API was created to cover this.
            // This code should be removed in a future release when the
            // old API is fully deprecated.
            [data writeToFile:filePath atomically:YES];
            NSDictionary *snapshotData = @{
                                           @"uri": filePath,
                                           @"data": [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]
                                           };
            callback(@[[NSNull null], snapshotData]);
        }
    
    }
    UIGraphicsEndImageContext();
  }];
}

RCT_EXPORT_METHOD(setMapBoundaries:(nonnull NSNumber *)reactTag
                  northEast:(CLLocationCoordinate2D)northEast
                  southWest:(CLLocationCoordinate2D)southWest)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    id view = viewRegistry[reactTag];
    if (![view isKindOfClass:[AIRGoogleMap class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting AIRGoogleMap, got: %@", view);
    } else {
      AIRGoogleMap *mapView = (AIRGoogleMap *)view;

      GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:northEast coordinate:southWest];

      mapView.cameraTargetBounds = bounds;
    }
  }];
}

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

- (NSDictionary *)constantsToExport {
  return @{ @"legalNotice": [GMSServices openSourceLicenseInfo] };
}

- (void)mapViewDidStartTileRendering:(GMSMapView *)mapView {
  if (didCallOnMapReady) return;
  didCallOnMapReady = YES;
  
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  [googleMapView didPrepareMap];
}

- (BOOL)mapView:(GMSMapView *)mapView didTapMarker:(GMSMarker *)marker {
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  return [googleMapView didTapMarker:marker];
}

- (void)mapView:(GMSMapView *)mapView didTapOverlay:(GMSPolygon *)polygon {
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  [googleMapView didTapPolygon:polygon];
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  [googleMapView didTapAtCoordinate:coordinate];
}

- (void)mapView:(GMSMapView *)mapView didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate {
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  [googleMapView didLongPressAtCoordinate:coordinate];
}

- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position {
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  [googleMapView didChangeCameraPosition:position];
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position {
  AIRGoogleMap *googleMapView = (AIRGoogleMap *)mapView;
  [googleMapView idleAtCameraPosition:position];
}

- (UIView *)mapView:(GMSMapView *)mapView markerInfoWindow:(GMSMarker *)marker {
  AIRGMSMarker *aMarker = (AIRGMSMarker *)marker;
  return [aMarker.fakeMarker markerInfoWindow];}

- (UIView *)mapView:(GMSMapView *)mapView markerInfoContents:(GMSMarker *)marker {
  AIRGMSMarker *aMarker = (AIRGMSMarker *)marker;
  return [aMarker.fakeMarker markerInfoContents];
}

- (void)mapView:(GMSMapView *)mapView didTapInfoWindowOfMarker:(GMSMarker *)marker {
  AIRGMSMarker *aMarker = (AIRGMSMarker *)marker;
  [aMarker.fakeMarker didTapInfoWindowOfMarker:aMarker];
}

- (void)mapView:(GMSMapView *)mapView didBeginDraggingMarker:(GMSMarker *)marker {
  AIRGMSMarker *aMarker = (AIRGMSMarker *)marker;
  [aMarker.fakeMarker didBeginDraggingMarker:aMarker];
}

- (void)mapView:(GMSMapView *)mapView didEndDraggingMarker:(GMSMarker *)marker {
  AIRGMSMarker *aMarker = (AIRGMSMarker *)marker;
  [aMarker.fakeMarker didEndDraggingMarker:aMarker];
}

- (void)mapView:(GMSMapView *)mapView didDragMarker:(GMSMarker *)marker {
  AIRGMSMarker *aMarker = (AIRGMSMarker *)marker;
  [aMarker.fakeMarker didDragMarker:aMarker];
}

@end

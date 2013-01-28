//
//  Test.h
//  mlcontroller
//
//  Created by Francois Vessaz on 3/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@interface MapAnnotation : NSObject <MKAnnotation> {
    
    CLLocationCoordinate2D myCoord;
    NSString* myName;
    
}

- (id)initWithCoord:(CLLocationCoordinate2D)coord andName:(NSString*)aName;

@end

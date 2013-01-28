//
//  AgentsMapViewController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>
#import "MainViewController.h"

@interface AgentsMapViewController : NSViewController <MKMapViewDelegate, MainViewDelegate> {
    
    MKMapView* mapView;
    BOOL isAnnotationSelected;
    
}

@property (readonly) IBOutlet MKMapView* mapView;

@end

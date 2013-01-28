//
//  AgentsMapViewController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AgentsMapViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "MapAnnotation.h"
#import "MLAppDelegate.h"

@interface AgentsMapViewController () {
    
    MLAppDelegate* appDel;
    
}

@end

@implementation AgentsMapViewController

@synthesize mapView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        appDel = [(MLAppDelegate*)[NSApplication sharedApplication].delegate retain];
        isAnnotationSelected = NO;
    }
    
    return self;
}

-(void)loadView {
    [super loadView];
    
    [mapView setDelegate:self];
}

#pragma mark MapView Delegate & datasource

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    isAnnotationSelected = YES;
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    isAnnotationSelected = NO;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id < MKAnnotation >)annotation {
    MKAnnotationView *pin = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"me"] autorelease];
    pin.imageUrl = [[NSBundle mainBundle] pathForImageResource:@"mbp.png"];
    pin.canShowCallout = YES;
    return pin;
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)aMapView
{
    /*
     * code for path
     
    CLLocationCoordinate2D polyPoints[3];
    polyPoints[0] = CLLocationCoordinate2DMake(46.521984,6.583525);
    polyPoints[1] = CLLocationCoordinate2DMake(46.522205,6.583557);
    polyPoints[2] = CLLocationCoordinate2DMake(46.522205,6.583917);
    MKPolyline* poly = [MKPolyline polylineWithCoordinates:polyPoints count:3];
    [mapView addOverlay:poly];
     */
    [self refreshDisplay];
}

/*
 * code for path
 
- (MKOverlayView *)mapView:(MKMapView *)aMapView viewForOverlay:(id <MKOverlay>)overlay
{
    MKPolylineView* path = [[MKPolylineView alloc] initWithPolyline:overlay];
    path.fillColor = [NSColor clearColor];
    path.strokeColor = [NSColor colorWithDeviceHue:0.3 saturation:0.75 brightness:0.66 alpha:0.8];
    path.lineWidth = 2;
    return path;
}
 */

-(void)refreshDisplay {
    [mapView removeAnnotations:mapView.annotations];
    for (NSArray* agentData in appDel.agentsList) {
        if ([agentData count] == 5) {
            NSNumber* agentLat = [agentData objectAtIndex:2];
            NSNumber* agentLong = [agentData objectAtIndex:3];
            if ([agentLat doubleValue] != 0.0 || [agentLong doubleValue] != 0.0){
                [mapView addAnnotation:[[[MapAnnotation alloc] initWithCoord:CLLocationCoordinate2DMake([agentLat doubleValue],[agentLong doubleValue]) andName:[agentData objectAtIndex:0]] autorelease]];
            }
        }
    }
}

-(BOOL)hasSelectedAgents {
    return isAnnotationSelected;
}

-(NSArray*)selectedAgents {
    NSMutableArray* agentsName = [NSMutableArray array];
    for (MapAnnotation* annotation in mapView.selectedAnnotations) {
        [agentsName addObject:[annotation title]];
    }
    return agentsName;
}

-(void)dealloc {
    [appDel release];
    [mapView setDelegate:nil];
    [mapView release];
    [super dealloc];
}

@end

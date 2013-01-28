//
//  Test.m
//  mlcontroller
//
//  Created by Francois Vessaz on 3/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MapAnnotation.h"

@implementation MapAnnotation

- (id)initWithCoord:(CLLocationCoordinate2D)coord andName:(NSString*)aName
{
    self = [super init];
    if (self) {
        myCoord = coord;
        myName = [aName retain];
    }
    return self;
}

-(CLLocationCoordinate2D)coordinate {
    return myCoord;
}

- (NSString *)title {
    return myName;
}

- (void)dealloc
{
    [myName release];
    [super dealloc];
}

@end

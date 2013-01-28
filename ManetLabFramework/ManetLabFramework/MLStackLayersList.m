//
//  MLStackLayersList.m
//  ManetLabTest
//
//  Created by Francois Vessaz on 2/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MLStackLayersList.h"

@implementation MLStackLayersList

// Override this method to return an array of NSString with available layers in plugin.
-(NSArray*)layersList {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must implement a subclass of %@!",[self description]] userInfo:nil];
}

// Override this method to return class for MLStackLayer name.
-(Class)layerForName:(NSString*)layerName {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must implement a subclass of %@!",[self description]] userInfo:nil];
}

@end

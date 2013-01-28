//
//  MyListOfLayers.m
//  MyFirstManetLabPlugin
//
//  Created by Francois Vessaz on 11/5/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "MyListOfLayers.h"
#import "MyCustomLayer.h"

@implementation MyListOfLayers

/*
 * Override this method from MLStackLayersList to return a NSArray of NSString containing the names of the layers available in this plugin.
 */
-(NSArray*)layersList {
    return @[@"My Custom Layer"];
}

/*
 * Override this method from MLStackLayersList to return the Class corresponding to a given layer name.
 */
-(Class)layerForName:(NSString*)layerName {
    if ([layerName isEqualToString:@"My Custom Layer"]) {
        return [MyCustomLayer class];
    } else {
        // Return NULL if plugin does not contain a class for the given name...
        return NULL;
    }
}

@end

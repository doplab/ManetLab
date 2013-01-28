//
//  MLPLayersList.m
//  MLBasePlugin
//
//  Created by Francois Vessaz on 8/13/12.
//  Modified by Arielle Moro on 16.11.12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "MLPLayersList.h"
#import "Gossip.h"
#import "SimpleFlooding.h"
#import "CBS.h"
#import "Fragmentation.h"

@implementation MLPLayersList

-(NSArray*)layersList {
    return @[   @"Gossip",
                @"SimpleFlooding",
                @"CBS",
                @"Fragmentation"];
}

-(Class)layerForName:(NSString*)layerName {
    if ([layerName isEqualToString:@"Gossip"]) {
        return [Gossip class];
    } else if ([layerName isEqualToString:@"SimpleFlooding"]) {
        return [SimpleFlooding class];
    } else if ([layerName isEqualToString:@"CBS"]) {
        return [CBS class];
    } else if ([layerName isEqualToString:@"Fragmentation"]) {
        return [Fragmentation class];
    }
    return NULL;
}

@end

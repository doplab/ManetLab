//
//  MLStackLayersList.h
//  ManetLabTest
//
//  Created by Francois Vessaz on 2/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MLStackLayer.h"

/*
 * List of available MLStackLayer in the plugin. Principal class of a ManetLab plugin.
 * You need to override/herit from this class to have a valid plugin
 */
@interface MLStackLayersList : NSObject

-(NSArray*)layersList;                      // Array of NSString containing the names of available layers in the plugin
-(Class)layerForName:(NSString*)layerName;  // Class for layer name in the plugin

@end

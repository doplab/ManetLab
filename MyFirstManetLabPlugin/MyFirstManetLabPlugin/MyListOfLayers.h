//
//  MyListOfLayers.h
//  MyFirstManetLabPlugin
//
//  Created by Francois Vessaz on 11/5/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * This class allows ManetLab to know all the available layer classes in the plugin and to get each layer by its name.
 * Override the layersList & layerForName methods inherited from MLStackLayersList in the .m file.
 */

/*
 * Import super class MLStackLayerList
 */
#import <ManetLabFramework/MLStackLayersList.h>

/*
 * Inherit from MLStackLayersList
 */
@interface MyListOfLayers : MLStackLayersList

@end

//
//  MyCustomLayer.h
//  MyFirstManetLabPlugin
//
//  Created by Francois Vessaz on 11/5/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * The MyCustomLayer class implements a layer of the ManetLab adhoc protocol stack.
 * Override the send & deliver methods inherited from MLStackLayer in the .m file to implement the behavior of your layer.
 */

/*
 * Import super class MLStackLayer
 */
#import <ManetLabFramework/MLStackLayer.h>

/* 
 * Inherit from super class MLStackLayer
 */
@interface MyCustomLayer : MLStackLayer

@end

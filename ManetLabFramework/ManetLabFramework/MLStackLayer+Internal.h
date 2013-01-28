//
//  MLStackLayer_Internal.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 10/11/12.
//
//

#import "MLStackLayer.h"

@class MLStack;

@interface MLStackLayer (Internal)

-(void)setUpperLayer:(MLStackLayer*)upperLayer;
-(void)setLowerLayer:(MLStackLayer*)lowerLayer;
-(void)setStack:(MLStack*)stack;

@end

//
//  Gossip.h
//  MLBasePlugin
//
//  Created by Francois Vessaz on 8/13/12.
//  Modified by Arielle Moro on 16.11.12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import <ManetLabFramework/MLStackLayer.h>

@interface Gossip : MLStackLayer

-(id)initWithProb:(double)p name:(NSString*)name andAlgoId:(Byte)algoId;

@end
//
//  UDP6Server.h
//  ManetLab
//
//  Created by François Vessaz on 8/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.

#import "MLStackLayer.h"

@interface MLLowestLayer : MLStackLayer

+(NSString*)getMACOfInterface:(NSString*)interface;

-(id)initOnInterface:(NSString*)anInterface;
-(void)stop;

@end
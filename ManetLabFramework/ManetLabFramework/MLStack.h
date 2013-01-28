//
//  MLStack.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 12/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLStackLayer+Internal.h"

@class MLAgent;

@interface MLStack : MLStackLayer

-(id)initWithLayers:(NSArray*)aStack andAgent:(MLAgent*)anAgent;
-(void)reconnect;

-(void)logToTask:(unsigned int)taskId event:(NSString*)event;

@end

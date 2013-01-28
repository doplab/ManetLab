//
//  MLNetworkController.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLTask.h"

@class MLAgentProxy;

@interface MLController : NSObject

-(id)initWithInterface:(NSString*)anInterface;
-(void)closeConnection:(MLAgentProxy*)agentToClose;
-(void)stopServer;
-(void)agentsList;
-(void)updateTask:(NSString*)aTask ofAgent:(NSString*)anAgent toState:(MLTaskAgentStatus)aState withEvent:(NSString*)event at:(NSDate*)time line:(int)line;
-(void)announceLayers:(NSArray*)layersList forAgent:(NSString*)agentName;

@end

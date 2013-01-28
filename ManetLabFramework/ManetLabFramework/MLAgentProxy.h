//
//  MLAgentProxy.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLStreamsUtility.h"

@class MLController;
@class MLStreamsUtility;

@interface MLAgentProxy : NSObject <MLStreamsUtilityDelegate> {
    
    MLController* server;               // ML network controller TCP server
    MLStreamsUtility* streams;          // streams to agent
    NSString* agentName;                // DNS name of agent
    NSString* agentAddress;             // Address of agent
    NSNumber* agentLat;
    NSNumber* agentLong;
    NSNumber* agentState;
    
}

@property (readonly) NSString* agentName;
@property (readonly) NSString* agentAddress;
@property (readonly) NSNumber* agentLat;
@property (readonly) NSNumber* agentLong;
@property (readonly) NSNumber* agentState;

-(id)initWithInputStream:(NSInputStream*)ins andOutputStream:(NSOutputStream*)outs address:(NSString*)anAddress server:(MLController*)aServer;
-(void)disconnect;
-(void)sendData:(NSDictionary*)dataToSend;

@end

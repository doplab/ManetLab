//
//  MLTask.h
//  ManetLabFramework
//
//  Created by Francois Vessaz on 5/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kMLTaskAgentUndetermined = 0,
    kMLTaskAgentSuccess      = 1,
    kMLTaskAgentFailure      = -1
} MLTaskAgentStatus;

@interface MLTask : NSObject {
    
    NSString* taskId;
    NSMutableDictionary* agentsStatus;  // only agents to initiate task (senders)
    NSMutableArray* log;                // array of array with: time, agentName, event
    NSString* taskLabel;                // type of the task
    NSDateFormatter* dateFormatter;     // date formatter for time
    
}

@property (readonly) NSString* taskId;
@property (readonly) NSString* taskLabel;

-(id)initWithDictionnary:(NSDictionary*)aTaskDict;
-(NSArray*)selectedAgents;
-(void)updateStatusForAgent:(NSString*)agentName toStatus:(MLTaskAgentStatus)status withEvent:(NSString*)event at:(NSDate*)time line:(int)line;
-(NSDictionary*)getTaskDetails;
-(NSString*)getLog;

@end

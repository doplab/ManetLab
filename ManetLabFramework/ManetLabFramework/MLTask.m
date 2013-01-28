//
//  MLTask.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 5/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MLTask.h"

@interface MLTask ()

-(NSDictionary*)lastLogs;

@end

@implementation MLTask

@synthesize taskId, taskLabel;

static int taskCounter = 1;

- (id)initWithDictionnary:(NSDictionary*)aTaskDict
{
    self = [super init];
    if (self) {
        taskId = [[NSString stringWithFormat:@"%i",taskCounter++] retain];
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
        
        agentsStatus = [[NSMutableDictionary dictionary] retain];
        for (NSString* agentName in [aTaskDict valueForKey:@"toAgents"]) {
            [agentsStatus setValue:[NSNumber numberWithInt:kMLTaskAgentUndetermined] forKey:agentName];
        }
        
        log = [[NSMutableArray array] retain];
        taskLabel = [[aTaskDict valueForKey:@"task"] retain];
    }
    return self;
}

- (NSArray*)selectedAgents {
    return [agentsStatus allKeys];
}


-(void)updateStatusForAgent:(NSString*)agentName toStatus:(MLTaskAgentStatus)status withEvent:(NSString*)event at:(NSDate*)time line:(int)line {
    if (status != kMLTaskAgentUndetermined) {
        [agentsStatus setValue:[NSNumber numberWithInt:status] forKey:agentName];
    }
    if (event != nil) {
        [log addObject:[NSArray arrayWithObjects:[NSDate date],time,agentName,event,[NSNumber numberWithInt:line],nil]];
    }
}

-(NSDictionary*)getTaskDetails {
    NSDictionary* res = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"taskDetails",@"action",
                         taskId,@"taskId",
                         taskLabel,@"taskLabel",
                         agentsStatus,@"agentsStatus",
                         [self lastLogs],@"lastLog",nil];
    return res;
}

-(NSDictionary*)lastLogs {
    NSMutableDictionary* res = [NSMutableDictionary dictionary];
    for (NSArray* logEntry in log) {
        [res setValue:[logEntry objectAtIndex:3] forKey:[logEntry objectAtIndex:2]];
    }
    return res;
}

-(NSString*)getLog {
    NSMutableString* res = [NSMutableString string];
    int i = 0;
    for (NSArray* logEntry in log) {
        [res appendFormat:@"%d (%@): on %@ %d (%@): %@\n",i,[dateFormatter stringFromDate:[logEntry objectAtIndex:0]],[logEntry objectAtIndex:2],[[logEntry objectAtIndex:4] intValue],[dateFormatter stringFromDate:[logEntry objectAtIndex:1]],[logEntry objectAtIndex:3]];
        i++;
    }
    return res;
}

- (void)dealloc
{
    [dateFormatter release];
    [taskLabel release];
    [log release];
    [agentsStatus release];
    [taskId release];
    [super dealloc];
}

@end

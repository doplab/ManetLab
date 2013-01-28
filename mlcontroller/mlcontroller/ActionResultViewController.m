//
//  ActionResultViewController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 3/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ActionResultViewController.h"
#import "MLAppDelegate.h"

@interface ActionResultViewController ()

@end

@implementation ActionResultViewController

- (id)initWithTaskId:(NSString*)aTaskId
{
    self = [super initWithNibName:@"ActionResultViewController" bundle:nil];
    if (self) {
        // Initialization code here.
        taskId = [aTaskId retain];
        agentsStatus = nil;
        lastLog = nil;
        
        MLAppDelegate* appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
        [appDel sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                          @"taskDetails",@"action",
                          taskId,@"taskId",nil]];
    }
    
    return self;
}

- (void)loadView {
    [super loadView];
    
    [actionLabel setStringValue:[NSString stringWithFormat:@"Task %@...",taskId]];
    [progressBar startAnimation:self];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [agentsStatus count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    NSString* agentName = [[agentsStatus allKeys] objectAtIndex:rowIndex];
    int agentStatus = [[agentsStatus valueForKey:agentName] intValue];
    if ([aTableColumn.identifier isEqualToString:@"img"]) {
        if (agentStatus == 0) {
            return [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
        } else if (agentStatus == 1) {
            return [NSImage imageNamed:NSImageNameStatusAvailable];
        } else if (agentStatus < 0) {
            return [NSImage imageNamed:NSImageNameStatusUnavailable];
        }
    } else if ([aTableColumn.identifier isEqualToString:@"name"]) {
        return agentName;
    } else if ([aTableColumn.identifier isEqualToString:@"status"]) {
        return [lastLog valueForKey:agentName];
    }
    return nil;
}

-(BOOL)hasSelectedAgents {
    return ([tableView numberOfSelectedRows] > 0);
}

-(void)refreshDisplay {
    MLAppDelegate* appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
    NSDictionary* newData = appDel.lastTaskDetails;
    if (agentsStatus != nil) {
        [agentsStatus release];
    }
    agentsStatus = [[newData valueForKey:@"agentsStatus"] retain];
    if (lastLog != nil) {
        [lastLog release];
    }
    lastLog = [[newData valueForKey:@"lastLog"] retain];
    BOOL terminated = YES;
    for (NSString* agent in agentsStatus) {
        terminated = terminated && [[agentsStatus valueForKey:agent] boolValue];
    }
    if (terminated) {
        [progressBar stopAnimation:self];
        [progressBar setIndeterminate:NO];
        [progressBar setDoubleValue:100.0];
    }
    if ([[newData valueForKey:@"taskLabel"] isEqualToString:@"addPlugin"]) {
        [actionLabel setStringValue:[NSString stringWithFormat:@"Add Plugin (Task %@)",taskId]];
    } else if ([[newData valueForKey:@"taskLabel"] isEqualToString:@"setStack"]){
        [actionLabel setStringValue:[NSString stringWithFormat:@"Configure Stack (Task %@)",taskId]];
    } else if ([[newData valueForKey:@"taskLabel"] isEqualToString:@"send"]){
        [actionLabel setStringValue:[NSString stringWithFormat:@"Send (Task %@)",taskId]];
    }
    [tableView reloadData];
}

-(NSArray*)selectedAgents {
    NSArray* selectedAgents = [[agentsStatus allKeys] objectsAtIndexes:[tableView selectedRowIndexes]];
    return selectedAgents;
}

- (void)dealloc
{
    if (lastLog != nil) {
        [lastLog release];
    }
    if (agentsStatus != nil) {
        [agentsStatus release];
    }
    [taskId release];
    [super dealloc];
}

@end

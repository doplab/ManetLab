//
//  AgentsListViewController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AgentsListViewController.h"
#import "MLAppDelegate.h"

@interface AgentsListViewController () {
    
    MLAppDelegate* appDel;
    NSTableView* tableView;
    
}

@end

@implementation AgentsListViewController

@synthesize tableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        appDel = [(MLAppDelegate*)[NSApplication sharedApplication].delegate retain];
    }
    
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [appDel.agentsList count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    NSArray* agentData = [appDel.agentsList objectAtIndex:rowIndex];
    if ([agentData count] == 5) {
        if ([aTableColumn.identifier isEqualToString:@"status"]) {
            NSNumber* agentStatus = [agentData objectAtIndex:4];
            switch ([agentStatus intValue]) {
                case 1:
                case 2:
                    return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
                case 3:
                    return [NSImage imageNamed:NSImageNameStatusAvailable];
                default:
                    return [NSImage imageNamed:NSImageNameStatusUnavailable];
            }
            return [NSImage imageNamed:NSImageNameStatusAvailable];
        } else if ([aTableColumn.identifier isEqualToString:@"name"]) {
            return [agentData objectAtIndex:0];
        } else if ([aTableColumn.identifier isEqualToString:@"ip"]) {
            return [agentData objectAtIndex:1];
        }
    }
    return nil;
}

-(void)refreshDisplay {
    [tableView reloadData];
}

-(BOOL)hasSelectedAgents {
    return ([tableView numberOfSelectedRows] > 0);
}

-(NSArray*)selectedAgents {
    NSArray* selectedAgents = [appDel.agentsList objectsAtIndexes:[tableView selectedRowIndexes]];
    NSMutableArray* selectedAgentsName = [NSMutableArray array];
    for (NSArray* agentData in selectedAgents) {
        [selectedAgentsName addObject:[agentData  objectAtIndex:0]];
    }
    return selectedAgentsName;
}

- (void)dealloc
{
    [tableView release];
    [appDel release];
    [super dealloc];
}

@end

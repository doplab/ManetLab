//
//  LogWindowController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 7/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LogWindowController.h"
#import "MLAppDelegate.h"

@interface LogWindowController () {
    
    NSString* taskId;
    
}

@end

@implementation LogWindowController
@synthesize progress;
@synthesize refreshButton;
@synthesize logText;

- (id)initWithWindowNibName:(NSString *)windowNibName andTask:(NSString*)aTaskId
{
    self = [super initWithWindowNibName:windowNibName];
    if (self) {
        // Initialization code here.
        taskId = [aTaskId retain];
    }
    
    return self;
}

-(void)windowDidLoad {
    [self.window setTitle:[NSString stringWithFormat:@"Task %@ log",taskId]];
}

- (IBAction)save:(id)sender {
    NSSavePanel* saver = [NSSavePanel savePanel];
    [saver setDelegate:self];
    [saver setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
    [saver setNameFieldStringValue:[NSString stringWithFormat:@"task%@_log.txt",taskId]];
    [saver beginSheetModalForWindow:self.window completionHandler:NULL];
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSString* toSave = [logText string];
    if (![toSave writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:outError]){
        NSLog(@"ERROR while trying to save log: %@",[*outError localizedDescription]);
        return NO;
    }
    return YES;
}

- (IBAction)refresh:(id)sender {
    [refreshButton setEnabled:NO];
    [progress startAnimation:self];
    
    MLAppDelegate* appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
    [appDel sendData:[NSDictionary dictionaryWithObjectsAndKeys:@"getTaskLog",@"action",
                                                                taskId,@"taskId",nil]];
}

- (void)windowWillClose:(NSNotification *)notification {
    MLAppDelegate* appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
    [appDel closeLogWindow:taskId];
    [self release];
}

- (void)updateLog:(NSString*)newLog {
    [logText setString:newLog];
    [refreshButton setEnabled:YES];
    [progress stopAnimation:self];
}

- (void)dealloc
{
    [logText release];
    [taskId release];
    [progress release];
    [refreshButton release];
    [super dealloc];
}

@end

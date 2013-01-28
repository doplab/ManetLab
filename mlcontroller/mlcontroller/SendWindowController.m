//
//  SendWindowController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 4/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SendWindowController.h"
#include <net/ethernet.h>

@interface SendWindowController ()

-(void)validate;

@end

@implementation SendWindowController

-(id)initWithWindowNibName:(NSString*)nibName andAgents:(NSArray*)agentsNames
{
    self = [super initWithWindowNibName:nibName];
    if (self) {
        // Initialization code here.
        selectedURL = nil;
        appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
        selectedAgents = [agentsNames retain];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [formatter setMaximumFractionDigits:0];
    [formatter setRoundingMode:NSNumberFormatterRoundFloor];
}

- (IBAction)changeSendMode:(id)sender {
    NSMatrix* radioMatrix = (NSMatrix*)sender;
    if (radioMatrix.selectedTag == 0) {
        [repeatPauseField setEnabled:YES];
        [repeatTimesField setEnabled:YES];
    } else if (radioMatrix.selectedTag == 1){
        [repeatPauseField setEnabled:NO];
        [repeatTimesField setEnabled:NO];
        [repeatPauseField setIntValue:0];
        [repeatTimesField setIntValue:1];
    }
}

- (IBAction)chooseFile:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setDelegate:self];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setMessage:@"Select a file to send:"];
    [openDlg setPrompt:@"Select file"];
    [openDlg beginSheetModalForWindow:self.window completionHandler:NULL];
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError {
    if (selectedURL != nil) {
        [selectedURL release];
        selectedURL = nil;
    }
    selectedURL = [url retain];
    [fileLabel setStringValue:[selectedURL lastPathComponent]];
    NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:[selectedURL path] error:nil];
    double convertedValue = (double)[attr fileSize];
    int multiplyFactor = 0;
    NSArray *tokens = [NSArray arrayWithObjects:@"bytes",@"KB",@"MB",@"GB",@"TB",nil];
    while (convertedValue > 1024) {
        convertedValue /= 1024;
        multiplyFactor++;
    }
    [sizeLabel setStringValue:[NSString stringWithFormat:@"%4.2f %@",convertedValue, [tokens objectAtIndex:multiplyFactor]]];
    [self validate];
    return YES;
}

- (IBAction)send:(id)sender {
    NSData* dataToSend = nil;
    NSString* type = @"";
    if ([tabView.selectedTabViewItem.identifier isEqualToString:@"1"]) {
        type = @"text";
        dataToSend = [[textView string] dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([tabView.selectedTabViewItem.identifier isEqualToString:@"2"]) {
        type = @"file";
        NSError* err = nil;
        NSFileHandle* file = [NSFileHandle fileHandleForReadingFromURL:selectedURL error:&err];
        if (err != nil) {
            NSLog(@"ERROR: %@",[err localizedDescription]);
        } else {
            dataToSend = [file readDataToEndOfFile];
        }
    }    
    [appDel sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                      @"newTask",@"action",
                      selectedAgents,@"toAgents",
                      type,@"type",
                      dataToSend,@"data",
                      [destinationField stringValue],@"dataTo",
                      [NSNumber numberWithDouble:[repeatPauseField doubleValue]],@"pause",
                      [NSNumber numberWithInt:[repeatTimesField intValue]],@"repeat",
                      @"send",@"task",nil]];
    [NSApp endSheet:[self window]];
}

- (IBAction)cancel:(id)sender {
    [NSApp endSheet:[self window]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    [self close];
    [self release];
}

- (void)textDidChange:(NSNotification *)aNotification {
    [self validate];
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self validate];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    [self validate];
}

-(void)validate {
    BOOL res = YES;
    if ([tabView.selectedTabViewItem.identifier isEqualToString:@"1"]) {
        // text
        res &= [textView string].length > 0;
    } else {
        // file
        res &= selectedURL != nil;
    }
    struct ether_addr* mac = NULL;
    mac = ether_aton([[destinationField stringValue] UTF8String]);
    res &= mac != NULL;
    res &= [repeatPauseField doubleValue] >= 0.0;
    res &= [repeatTimesField intValue] > 0;
    res &= ([repeatTimesField doubleValue] - [repeatTimesField intValue]) == 0;
    
    [sendButton setEnabled:res];
}

- (void)dealloc
{
    [selectedAgents release];
    if (selectedURL != nil) {
        [selectedURL release];
    }
    [super dealloc];
}

@end

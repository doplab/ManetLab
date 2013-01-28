//
//  SendWindowController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 4/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MLAppDelegate.h"

@interface SendWindowController : NSWindowController <NSOpenSavePanelDelegate, NSTextDelegate, NSTextFieldDelegate> {
    
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *textView;
    IBOutlet NSTextField *sizeLabel;
    IBOutlet NSTextField *fileLabel;
    IBOutlet NSTextField *repeatTimesField;
    IBOutlet NSTextField *repeatPauseField;
    IBOutlet NSTextField *destinationField;
    IBOutlet NSNumberFormatter *formatter;
    IBOutlet NSButton *sendButton;
    NSURL* selectedURL;
    MLAppDelegate* appDel;
    NSArray* selectedAgents;
    
}

-(id)initWithWindowNibName:(NSString*)nibName andAgents:(NSArray*)agentsNames;
- (IBAction)chooseFile:(id)sender;
- (IBAction)send:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)changeSendMode:(id)sender;

@end

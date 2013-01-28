//
//  MLAppDelegate.h
//  mlcontroller
//
//  Created by Francois Vessaz on 12/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MLStreamsUtility.h"

@interface MLAppDelegate : NSObject <NSApplicationDelegate, NSToolbarDelegate, NSOpenSavePanelDelegate, MLStreamsUtilityDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSView *mainView;
@property (readonly) NSArray* agentsList;
@property (readonly) NSDictionary* lastTaskDetails;

- (IBAction)openPrefs:(id)sender;
- (IBAction)addPlugin:(id)sender;
- (IBAction)configureStack:(id)sender;
- (IBAction)send:(id)sender;
- (IBAction)showLogs:(id)sender;

-(BOOL)sendData:(NSDictionary*)newData;
-(void)closeLogWindow:(NSString*)aTaskId;

@end

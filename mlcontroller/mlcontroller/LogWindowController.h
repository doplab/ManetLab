//
//  LogWindowController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 7/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LogWindowController : NSWindowController <NSOpenSavePanelDelegate> {
    
    NSProgressIndicator *progress;
    NSButton *refreshButton;
    NSTextView *logText;
    
}

@property (nonatomic, retain) IBOutlet NSProgressIndicator *progress;
@property (nonatomic, retain) IBOutlet NSButton *refreshButton;
@property (nonatomic, retain) IBOutlet NSTextView *logText;

- (id)initWithWindowNibName:(NSString *)windowNibName andTask:(NSString*)aTaskId;
- (IBAction)save:(id)sender;
- (IBAction)refresh:(id)sender;
- (void)updateLog:(NSString*)newLog;

@end

//
//  ActionResultViewController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 3/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainViewController.h"

@interface ActionResultViewController : NSViewController <NSTableViewDelegate, NSTableViewDataSource, MainViewDelegate> {
    
    IBOutlet NSTableView *tableView;
    IBOutlet NSTextField *actionLabel;
    IBOutlet NSProgressIndicator *progressBar;
    
    NSString* taskId;
    NSDictionary* agentsStatus;
    NSDictionary* lastLog;
    
}

- (id)initWithTaskId:(NSString*)aTaskId;

@end

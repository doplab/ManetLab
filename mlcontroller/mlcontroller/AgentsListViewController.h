//
//  AgentsListViewController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainViewController.h"

@interface AgentsListViewController : NSViewController <NSTableViewDelegate, NSTableViewDataSource, MainViewDelegate>

@property (nonatomic, retain) IBOutlet NSTableView* tableView;

@end

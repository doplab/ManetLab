//
//  MainViewController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MainViewDelegate <NSObject>

-(void)refreshDisplay;
-(BOOL)hasSelectedAgents;
-(NSArray*)selectedAgents;

@end

@interface MainViewController : NSViewController <NSSplitViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, MainViewDelegate> {
    
    NSViewController<MainViewDelegate>* _currentViewController;
    NSArray* _sideBarHeaders;
    NSDictionary* _sideBarContent;
    NSMutableArray* sideBarHistory;
    
    IBOutlet NSOutlineView *_sidebar;
    IBOutlet NSView *_contentView;
    
}

@property (readonly) IBOutlet NSOutlineView *_sidebar;

-(void)refreshTasksList:(NSDictionary*)tasksList switchView:(BOOL)switchView;
-(NSString*)selectedTaskId;

@end

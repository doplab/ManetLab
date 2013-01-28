//
//  SetLayersWindowController.h
//  mlcontroller
//
//  Created by Francois Vessaz on 3/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SetLayersWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate> {
    
    IBOutlet NSButton *validateButton;
    NSArray* availableLayers;
    IBOutlet NSTableView *layersTableView;
    int nbOfLayers;
    NSArray* selectedAgentsName;
    
}

-(id)initWithWindowNibName:(NSString*)nibName andAgents:(NSArray*)agentsNames;
-(void)setAvailableLayers:(NSArray*)theLayers;

- (IBAction)validate:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)addLayer:(id)sender;
- (IBAction)removeLayer:(id)sender;
- (IBAction)selectLayer:(id)sender;

@end

//
//  SetLayersWindowController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 3/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SetLayersWindowController.h"
#import "MLAppDelegate.h"

@interface SetLayersWindowController ()

@end

@implementation SetLayersWindowController

-(id)initWithWindowNibName:(NSString*)nibName andAgents:(NSArray*)agentsNames {
    self = [super initWithWindowNibName:nibName];
    if (self) {
        // Initialization code here.
        availableLayers = [[NSArray array] retain];
        nbOfLayers = 0;
        selectedAgentsName = [agentsNames retain];
        
        MLAppDelegate* appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
        [appDel sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                          @"getLayersList",@"action",
                          selectedAgentsName,@"toAgents",nil]];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)addLayer:(id)sender {
    nbOfLayers++;
    [layersTableView reloadData];
}

- (IBAction)removeLayer:(id)sender {
    //[selectedLayers removeObjectAtIndex:[layersTableView selectedRow]];
    nbOfLayers--;
    [layersTableView reloadData];
}

- (IBAction)selectLayer:(id)sender {
    // nothing
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return nbOfLayers;
}

- (IBAction)validate:(id)sender {
    NSMutableArray* selectedLayers = [NSMutableArray array];
    [layersTableView enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){
        NSTableCellView* cellView = [rowView viewAtColumn:0];
        NSPopUpButton* popUp = [cellView viewWithTag:0];
        [selectedLayers addObject:[popUp titleOfSelectedItem]];
    }];
    
    MLAppDelegate* appDel = (MLAppDelegate*)[NSApplication sharedApplication].delegate;
    [appDel sendData:[NSDictionary dictionaryWithObjectsAndKeys:
                      @"newTask",@"action",
                      selectedAgentsName,@"toAgents",
                      @"setStack",@"task",
                      selectedLayers,@"stack",nil]];
    
    [NSApp endSheet:[self window]];
}

- (IBAction)cancel:(id)sender {
    [NSApp endSheet:[self window]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    [self close];
    [self release];
}

-(void)setAvailableLayers:(NSArray*)theLayers {
    [availableLayers release];
    availableLayers = [theLayers retain];
    [layersTableView reloadData];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView* cellView = [tableView makeViewWithIdentifier:@"layerView" owner:self];
    NSPopUpButton* popUp = [cellView viewWithTag:0];
    [popUp addItemsWithTitles:availableLayers];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectPopup:) name:NSPopUpButtonWillPopUpNotification object:popUp];
    return cellView;
}

- (void)selectPopup:(NSNotification*)notif {
    NSPopUpButton* popUp = [notif object];
    NSInteger selected = [layersTableView rowForView:popUp];
    [layersTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selected] byExtendingSelection:NO];
}

- (void)dealloc
{
    [selectedAgentsName release];
    [availableLayers release];
    [super dealloc];
}

@end

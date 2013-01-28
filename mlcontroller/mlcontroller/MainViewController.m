//
//  MainViewController.m
//  mlcontroller
//
//  Created by Francois Vessaz on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MainViewController.h"
#import "AgentsListViewController.h"
#import "AgentsMapViewController.h"
#import "ActionResultViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

@synthesize _sidebar;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        sideBarHistory = [[NSMutableArray array] retain];
        
        _sideBarHeaders = [[NSArray arrayWithObjects:@"AGENTS",@"HISTORY",nil] retain];
        _sideBarContent = [[NSMutableDictionary dictionary] retain];
        [_sideBarContent setValue:
         [NSArray arrayWithObjects:
          [NSArray arrayWithObjects:@"List", NSImageNameListViewTemplate, nil], 
          [NSArray arrayWithObjects:@"Network", @"sidebar-laptop", nil], nil] 
                           forKey:@"AGENTS"];
        [_sideBarContent setValue:sideBarHistory forKey:@"HISTORY"];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    // The basic recipe for a sidebar. Note that the selectionHighlightStyle is set to NSTableViewSelectionHighlightStyleSourceList in the nib
    [_sidebar sizeLastColumnToFit];
    [_sidebar setFloatsGroupRows:NO];
    
    // NSTableViewRowSizeStyleDefault should be used, unless the user has picked an explicit size. In that case, it should be stored out and re-used.
    [_sidebar setRowSizeStyle:NSTableViewRowSizeStyleDefault];
    
    // Expand all the root items; disable the expansion animation that normally happens
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0];
    [_sidebar expandItem:nil expandChildren:YES];
    [NSAnimationContext endGrouping];
    
    [_sidebar selectRowIndexes:[[[NSIndexSet alloc] initWithIndex:1] autorelease] byExtendingSelection:NO];
}

-(BOOL)hasSelectedAgents {
    return [_currentViewController hasSelectedAgents];
}

-(void)refreshDisplay {
    [_currentViewController refreshDisplay];
}

-(NSArray*)selectedAgents {
    return [_currentViewController selectedAgents];
}

-(void)refreshTasksList:(NSDictionary*)tasksList switchView:(BOOL)switchView {
    [sideBarHistory removeAllObjects];
    for (NSString* taskId in tasksList) {
        NSString* taskLabel = [tasksList valueForKey:taskId];
        if ([taskLabel isEqualToString:@"addPlugin"]) {
            [sideBarHistory addObject:[NSArray arrayWithObjects:@"Add Plugin",NSImageNameAddTemplate,taskId,nil]];
        } else if ([taskLabel isEqualToString:@"setStack"]){
            [sideBarHistory addObject:[NSArray arrayWithObjects:@"Configure Stack",NSImageNameActionTemplate,taskId,nil]];
        } else if ([taskLabel isEqualToString:@"send"]){
            [sideBarHistory addObject:[NSArray arrayWithObjects:@"Send",NSImageNameRightFacingTriangleTemplate,taskId,nil]];
        }
    }
    [sideBarHistory sortUsingComparator:^NSComparisonResult(NSArray* tab1, NSArray* tab2) {
        return ([[tab2 objectAtIndex:2] intValue] - [[tab1 objectAtIndex:2] intValue]);
        //return [[tab2 objectAtIndex:2] caseInsensitiveCompare:[tab1 objectAtIndex:2]];
    }];
    [_sidebar reloadData];
    if (switchView) {
        [_sidebar selectRowIndexes:[NSIndexSet indexSetWithIndex:4] byExtendingSelection:NO];
    }
}

#pragma mark -
#pragma mark splitview delegate methods

// keep menu width when resizing window
- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview {
    return ![subview.identifier isEqualToString:@"menu"];
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (proposedMinimumPosition < 100) {
        proposedMinimumPosition = 100;
    }
    return proposedMinimumPosition;
}

#pragma mark -
#pragma mark menu datasource/delegate methods

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return [_sideBarHeaders objectAtIndex:index];
    } else if ([outlineView parentForItem:item] == nil){
        return [(NSArray*)[_sideBarContent objectForKey:item] objectAtIndex:index];
    }
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"SideBarData ERROR" userInfo:nil];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ([outlineView parentForItem:item] == nil);
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return [_sideBarHeaders count];
    } else if ([outlineView parentForItem:item] == nil){
        return [(NSArray*)[_sideBarContent objectForKey:item] count];
    }
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    return ([outlineView parentForItem:item] == nil);
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([_sideBarHeaders containsObject:item]) {
        NSTableCellView *result = [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];
        [result.textField setStringValue:item];
        return result;
    } else {
        NSArray* cellData = (NSArray*)item;
        NSTableCellView *result = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
        [result.textField setStringValue:[cellData objectAtIndex:0]];
        [result.imageView setImage:[NSImage imageNamed:[cellData objectAtIndex:1]]];
        return result;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return ([outlineView parentForItem:item] != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item {
    return NO;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    if (_currentViewController != nil) {
        [[_currentViewController view] removeFromSuperview];
        [_currentViewController release];
    }
    
    NSArray* sidebarItem = [_sidebar itemAtRow:_sidebar.selectedRow];
    if ([[sidebarItem objectAtIndex:0] isEqualToString:@"List"]) {
        _currentViewController = [[AgentsListViewController alloc] initWithNibName:@"AgentsListViewController" bundle:nil];
    } else if ([[sidebarItem objectAtIndex:0] isEqualToString:@"Network"]) {
        _currentViewController = [[AgentsMapViewController alloc] initWithNibName:@"AgentsMapViewController" bundle:nil];
    } else {
        _currentViewController = [[ActionResultViewController alloc] initWithTaskId:[sidebarItem objectAtIndex:2]];
    }
    _currentViewController.view.frame = _contentView.bounds;
    [_currentViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_contentView addSubview:_currentViewController.view];
}

-(NSString*)selectedTaskId {
    NSArray* sidebarItem = [_sidebar itemAtRow:_sidebar.selectedRow];
    return [sidebarItem objectAtIndex:2];
}

- (void)dealloc
{
    [sideBarHistory release];
    [_currentViewController release];
    [_sideBarHeaders release];
    [_sideBarContent release];
    [super dealloc];
}

@end

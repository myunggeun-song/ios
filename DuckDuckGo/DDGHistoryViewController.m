//
//  DDGHistoryViewController.m
//  DuckDuckGo
//
//  Created by Johnnie Walker on 10/04/2013.
//
//

#import "DDGHistoryViewController.h"
#import "DDGHistoryItem.h"
#import "DDGPlusButton.h"
#import "DDGStoryFeed.h"
#import "DDGStory.h"
#import "DDGSettingsViewController.h"
#import "DDGSearchController.h"
#import "ECSlidingViewController.h"
#import "DDGHistoryItemCell.h"

@interface DDGHistoryViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, weak, readwrite) id <DDGSearchHandler> searchHandler;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSMutableSet *deletingIndexPaths;
@end

@implementation DDGHistoryViewController

-(id)initWithSearchHandler:(id <DDGSearchHandler>)searchHandler managedObjectContext:(NSManagedObjectContext *)managedObjectContext;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.managedObjectContext = managedObjectContext;
        self.searchHandler = searchHandler;
        self.deletingIndexPaths = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (nil == self.tableView) {
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.backgroundColor = [UIColor colorWithRed:0.161 green:0.173 blue:0.196 alpha:1.000];
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        [self.view addSubview:tableView];
        
        self.tableView = tableView;
    }
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft:)];
    swipeLeft.direction = (UISwipeGestureRecognizerDirectionLeft);
    swipeLeft.delegate = self;
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight:)];
    swipeRight.direction = (UISwipeGestureRecognizerDirectionRight);
    swipeRight.delegate = self;
    
    [self.tableView addGestureRecognizer:swipeLeft];
    [self.tableView addGestureRecognizer:swipeRight];    
    
    [self fetchedResultsController];
}

- (void)cancelDeletingIndexPathsAnimated:(BOOL)animated {
    for (NSIndexPath *indexPath in self.deletingIndexPaths) {
        DDGHistoryItemCell *cell = (DDGHistoryItemCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        [cell setDeleting:NO animated:animated];
    }
    [self.deletingIndexPaths removeAllObjects];
}

- (void)swipeLeft:(UISwipeGestureRecognizer *)swipe {
    [self swipe:swipe direction:UISwipeGestureRecognizerDirectionLeft];
}

- (void)swipeRight:(UISwipeGestureRecognizer *)swipe {
    [self swipe:swipe direction:UISwipeGestureRecognizerDirectionRight];
}

- (void)swipe:(UISwipeGestureRecognizer *)swipe direction:(UISwipeGestureRecognizerDirection)direction {
    if (swipe.state == UIGestureRecognizerStateRecognized) {
        CGPoint point = [swipe locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
        if (indexPath.section < additionalSections)
            return;
        
        if (nil != indexPath) {
            [self.deletingIndexPaths removeObject:indexPath];
            
            [self cancelDeletingIndexPathsAnimated:YES];
            
            BOOL deleting = (direction == UISwipeGestureRecognizerDirectionLeft);
            
            DDGHistoryItemCell *cell = (DDGHistoryItemCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            [cell setDeleting:deleting animated:YES];
            
            if (deleting)
                [self.deletingIndexPaths addObject:indexPath];            
        }
    }
}

- (NSInteger)historySectionForTableSection:(NSInteger)section {
    return section - [self.additionalSectionsDelegate numberOfAdditionalSections];
}

- (NSInteger)tableSectionForHistorySection:(NSInteger)section {
    return section + [self.additionalSectionsDelegate numberOfAdditionalSections];
}

- (NSIndexPath *)historyIndexPathForTableIndexPath:(NSIndexPath *)indexPath {
    return [NSIndexPath indexPathForRow:indexPath.row inSection:[self historySectionForTableSection:indexPath.section]];
}

- (NSIndexPath *)tableIndexPathForHistoryIndexPath:(NSIndexPath *)indexPath {
    return [NSIndexPath indexPathForRow:indexPath.row inSection:[self tableSectionForHistorySection:indexPath.section]];
}

- (IBAction)delete:(id)sender {
    NSSet *indexPaths = [self.deletingIndexPaths copy];
    [self cancelDeletingIndexPathsAnimated:YES];
    
    for (NSIndexPath *indexPath in indexPaths) {
        NSIndexPath *historyIndexPath = [self historyIndexPathForTableIndexPath:indexPath];
        DDGHistoryItem *historyItem = [self.fetchedResultsController objectAtIndexPath:historyIndexPath];
        [historyItem.managedObjectContext deleteObject:historyItem];
    }
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (nil == _fetchedResultsController) {
        
        BOOL showHistory = [[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingRecordHistory];
        if (showHistory) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[DDGHistoryItem entityName]];
            NSSortDescriptor *timeSort = [NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:NO];
            NSSortDescriptor *sectionSort = [NSSortDescriptor sortDescriptorWithKey:@"isStoryItem" ascending:YES];
            [request setSortDescriptors:@[sectionSort, timeSort]];
            
            NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                                       managedObjectContext:self.managedObjectContext
                                                                                                         sectionNameKeyPath:@"section"
                                                                                                                  cacheName:nil];
            fetchedResultsController.delegate = self;
            
            NSError *error = nil;
            if (![fetchedResultsController performFetch:&error])
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            
            self.fetchedResultsController = fetchedResultsController;            
        }
    }
    
    return _fetchedResultsController;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if (nil == self.view) {
        self.fetchedResultsController = nil;
    }
}

- (UIImage *)searchControllerBackButtonIconDDG {
    return [UIImage imageNamed:@"button_menu_glyph_home"];
}

- (IBAction)plus:(id)sender {
    UIButton *button = nil;
    if ([sender isKindOfClass:[UIButton class]])
        button = (UIButton *)sender;
    
    if (button) {
        CGPoint tappedPoint = [self.tableView convertPoint:button.center fromView:button.superview];
        NSIndexPath *tappedIndex = [self.tableView indexPathForRowAtPoint:tappedPoint];
        NSIndexPath *historyIndexPath = [self historyIndexPathForTableIndexPath:tappedIndex];
        DDGHistoryItem *historyItem = [self.fetchedResultsController objectAtIndexPath:historyIndexPath];
        DDGSearchController *searchController = [self searchControllerDDG];
        DDGAddressBarTextField *searchField = searchController.searchBar.searchField;
        
        [searchField becomeFirstResponder];
        searchField.text = historyItem.title;
        [searchController searchFieldDidChange:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    UIGestureRecognizer *panGesture = [self.slidingViewController panGesture];
    for (UIGestureRecognizer *gr in self.tableView.gestureRecognizers) {
        if ([gr isKindOfClass:[UISwipeGestureRecognizer class]])
            [panGesture requireGestureRecognizerToFail:gr];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint point = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
    return (nil != indexPath);
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self cancelDeletingIndexPathsAnimated:YES];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [self cancelDeletingIndexPathsAnimated:YES];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (indexPath.section < additionalSections) {
        if ([self.additionalSectionsDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
            [self.additionalSectionsDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
        return;
    }
    
    [self cancelDeletingIndexPathsAnimated:YES];    
    NSIndexPath *historyIndexPath = [self historyIndexPathForTableIndexPath:indexPath];
    DDGHistoryItem *historyItem = [self.fetchedResultsController objectAtIndexPath:historyIndexPath];
//    [self.historyProvider relogHistoryItem:historyItem];
    DDGStory *story = historyItem.story;
    if (nil != story)
        [self.searchHandler loadStory:story readabilityMode:[[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingStoriesReadView]];
    else
        [self.searchHandler loadQueryOrURL:historyItem.title];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count] + [self.additionalSectionsDelegate numberOfAdditionalSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (section < additionalSections)
        return [self.additionalSectionsDelegate tableView:tableView numberOfRowsInSection:(NSInteger)section];
    
    NSInteger historySection = [self historySectionForTableSection:section];
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][historySection];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (indexPath.section < additionalSections)
        return [self.additionalSectionsDelegate tableView:tv cellForRowAtIndexPath:indexPath];
    
	static NSString *CellIdentifier = @"HistoryCell";
    
	DDGHistoryItemCell *cell = [tv dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
	{
        cell = [[DDGHistoryItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.imageView.backgroundColor = self.tableView.backgroundColor;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    
	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (section < additionalSections) {
        if ([self.additionalSectionsDelegate respondsToSelector:@selector(tableView:heightForHeaderInSection:)])
            return [self.additionalSectionsDelegate tableView:tableView heightForHeaderInSection:section];
    }
    
    return 23;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (section < additionalSections) {
        if ([self.additionalSectionsDelegate respondsToSelector:@selector(tableView:heightForFooterInSection:)])
            return [self.additionalSectionsDelegate tableView:tableView heightForFooterInSection:section];
    }
    
    NSInteger sections = [self numberOfSectionsInTableView:tableView];
    return (section == (sections-1)) ? 1.0 : 0.0;
}

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (section < additionalSections) {
        if ([self.additionalSectionsDelegate respondsToSelector:@selector(tableView:viewForHeaderInSection:)])
            return [self.additionalSectionsDelegate tableView:tableView viewForHeaderInSection:section];
        return nil;
    }
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 23)];
    [headerView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"bg_divider.png"]]];
    
    NSArray *sections = [self.fetchedResultsController sections];
    NSInteger historySection = [self historySectionForTableSection:section];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, tableView.bounds.size.width-10, 20)];
    NSString *name = [(id <NSFetchedResultsSectionInfo>)[sections objectAtIndex:historySection] name];
    
    if ([name isEqualToString:@"searches"]) {
        title.text = NSLocalizedString(@"Recent Searches", @"Table section header title");
    } else if ([name isEqualToString:@"stories"]) {
        title.text = NSLocalizedString(@"Recent Stories", @"Table section header title");
    } else {
        title.text = name;
    }
    
    title.textColor = [UIColor whiteColor];
    title.opaque = NO;
    title.backgroundColor = [UIColor clearColor];
    title.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:13.0];
    [headerView addSubview:title];
    
    return headerView;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSInteger additionalSections = [self.additionalSectionsDelegate numberOfAdditionalSections];
    if (section < additionalSections) {
        if ([self.additionalSectionsDelegate respondsToSelector:@selector(tableView:viewForFooterInSection:)])
            return [self.additionalSectionsDelegate tableView:tableView viewForFooterInSection:section];
        return nil;
    }
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 1)];
    [footerView setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"end_of_list_highlight.png"]]];
    
    return footerView;
}

//- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return UITableViewCellEditingStyleDelete;
//}
//
////- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
////    return YES;
////}
//
//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        DDGHistoryItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
//        [self.managedObjectContext deleteObject:item];
//    }
//}
//

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    NSInteger tableSectionIndex = [self tableSectionForHistorySection:sectionIndex];
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:tableSectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:tableSectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    NSIndexPath *tableIndexPath = [self tableIndexPathForHistoryIndexPath:indexPath];
    NSIndexPath *newTableIndexPath = [self tableIndexPathForHistoryIndexPath:newIndexPath];
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newTableIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[tableIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:tableIndexPath] atIndexPath:tableIndexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[tableIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newTableIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *historyIndexPath = [self historyIndexPathForTableIndexPath:indexPath];    
    
    DDGHistoryItemCell *underCell = (DDGHistoryItemCell *)cell;
    
    underCell.active = NO;
    
	underCell.imageView.image = nil;
    underCell.imageView.highlightedImage = nil;
    underCell.overhangWidth = 6.0;
    
	UILabel *lbl = cell.textLabel;

    // we have history and it is enabled
    DDGHistoryItem *item = [self.fetchedResultsController objectAtIndexPath:historyIndexPath];
    DDGStory *story = item.story;

    if (nil != story) {
        underCell.fixedSizeImageView.image = story.feed.image;
        cell.accessoryView = nil;
    } else {
        underCell.fixedSizeImageView.image = [UIImage imageNamed:@"search_icon"];
        cell.accessoryView = [DDGPlusButton plusButton];
    }
    lbl.text = item.title;

}

@end
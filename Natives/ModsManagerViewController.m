//
// ModsManagerViewController.m
// AmethystMods
//
// Created by Copilot (adjusted) on 2025-08-22.
// Revised: add profileName handling and robust UI/data updates.
//

#import "ModsManagerViewController.h"
#import "ModTableViewCell.h"
#import "ModService.h"
#import "ModItem.h"

@interface ModsManagerViewController () <UITableViewDataSource, UITableViewDelegate, ModTableViewCellDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ModItem *> *mods;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation ModsManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Manage Mod"; 
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 76;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];

    // Refresh control
    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(refreshList) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = rc;

    // Activity indicator
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    // Empty label
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"Mod Not Found"; 
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    // Navigation item
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshList)];
    self.navigationItem.rightBarButtonItem = refresh;

    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];

    // Initialize data
    self.mods = [NSMutableArray array];

    // Initial load
    [self refreshList];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Refresh list when view appears to pick up external changes
    [self refreshList];
}

#pragma mark - Loading

- (void)setLoading:(BOOL)loading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            [self.activityIndicator startAnimating];
        } else {
            [self.activityIndicator stopAnimating];
            [self.tableView.refreshControl endRefreshing];
        }
    });
}

- (void)refreshList {
    [self setLoading:YES];
    __weak typeof(self) weakSelf = self;
    NSString *profile = self.profileName ?: @"default";
    [[ModService sharedService] scanModsForProfile:profile completion:^(NSArray<ModItem *> *mods) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // Update UI on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf.mods removeAllObjects];
            if (mods.count > 0) {
                [strongSelf.mods addObjectsFromArray:mods];
                strongSelf.emptyLabel.hidden = YES;
            } else {
                strongSelf.emptyLabel.hidden = NO;
            }
            [strongSelf.tableView reloadData];
            [strongSelf setLoading:NO];
        });

        // Fetch metadata for each mod to fill details asynchronously
        for (ModItem *m in mods) {
            [[ModService sharedService] fetchMetadataForMod:m completion:^(ModItem *item, NSError * _Nullable error) {
                __strong typeof(weakSelf) ss = weakSelf;
                if (!ss) return;
                NSUInteger idx = [ss.mods indexOfObjectPassingTest:^BOOL(ModItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj.filePath isEqualToString:item.filePath];
                }];
                if (idx != NSNotFound) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (idx < ss.mods.count) {
                            ModItem *stored = ss.mods[idx];
                            stored.displayName = item.displayName ?: stored.displayName;
                            stored.modDescription = item.modDescription ?: stored.modDescription;
                            stored.iconURL = item.iconURL ?: stored.iconURL;
                            stored.fileSHA1 = item.fileSHA1 ?: stored.fileSHA1;
                            stored.version = item.version ?: stored.version;
                            stored.homepage = item.homepage ?: stored.homepage;
                            stored.isFabric = item.isFabric;
                            stored.isForge = item.isForge;
                            stored.isNeoForge = item.isNeoForge;
                            [ss.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                        }
                    });
                }
            }];
        }
    }];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.mods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    ModItem *m = nil;
    if ((NSUInteger)indexPath.row < self.mods.count) {
        m = self.mods[indexPath.row];
    }
    cell.delegate = self;
    if (m) {
        [cell configureWithMod:m];
    } else {
        // Defensive: create an empty placeholder ModItem if out-of-range
        [cell configureWithMod:[[ModItem alloc] initWithFilePath:@""]];
    }
    return cell;
}

#pragma mark - ModTableViewCellDelegate

- (void)modCellDidTapToggle:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip || (NSUInteger)ip.row >= self.mods.count) return;
    ModItem *mod = self.mods[ip.row];
    NSString *title = mod.disabled ? @"Enable Mod" : @"Disable Mod"; 
    NSString *message = mod.disabled ? @"Are you sure you want to enable this Mod?" : @"Are you sure you want to disable this Mod?"; 
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
[ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; 
    __weak typeof(self) weakSelf = self;
[ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) { 
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] toggleEnableForMod:mod error:&err];
        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *errAc = [UIAlertController alertControllerWithTitle:@"Error" message:err.localizedDescription ?: @"Operation failed" preferredStyle:UIAlertControllerStyleAlert]; 
                [errAc addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; 
                [strongSelf presentViewController:errAc animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf refreshList];
            });
        }
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)modCellDidTapDelete:(UITableViewCell *)cell {
    NSIndexPath *ip = [self.tableView indexPathForCell:cell];
    if (!ip || (NSUInteger)ip.row >= self.mods.count) return;
    ModItem *mod = self.mods[ip.row];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Delete Mod" message:@"Are you sure you want to delete this Mod file? This action is irreversible." preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSError *err = nil;
        BOOL ok = [[ModService sharedService] deleteMod:mod error:&err];
        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *errAc = [UIAlertController alertControllerWithTitle:@"Error" message:err.localizedDescription ?: @"Deletion failed" preferredStyle:UIAlertControllerStyleAlert]; 
                [errAc addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; 
                [strongSelf presentViewController:errAc animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ((NSUInteger)ip.row < strongSelf.mods.count) {
                    [strongSelf.mods removeObjectAtIndex:ip.row];
                    [strongSelf.tableView deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
                    strongSelf.emptyLabel.hidden = (strongSelf.mods.count != 0);
                } else {
                    [strongSelf refreshList];
                }
            });
        }
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Table editing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if ((NSUInteger)indexPath.row >= self.mods.count) return;
        ModItem *m = self.mods[indexPath.row];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *err = nil;
            BOOL ok = [[ModService sharedService] deleteMod:m error:&err];
            __strong typeof(weakSelf) strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!strongSelf) return;
                if (!ok) {
                    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Error" message:err.localizedDescription ?: @"Deletion failed" preferredStyle:UIAlertControllerStyleAlert]; 
                    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; 
                    [strongSelf presentViewController:ac animated:YES completion:nil];
                } else {
                    if ((NSUInteger)indexPath.row < strongSelf.mods.count) {
                        [strongSelf.mods removeObjectAtIndex:indexPath.row];
                        [strongSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        strongSelf.emptyLabel.hidden = (strongSelf.mods.count != 0);
                    } else {
                        [strongSelf refreshList];
                    }
                }
            });
        });
    }
}

@end

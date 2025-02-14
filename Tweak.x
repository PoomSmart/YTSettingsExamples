#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>

#define TweakName @"YouTubeTweak"
#define EnabledKey @"TweakEnabled"
#define Option1Key @"Option1"
#define Option2Key @"Option2"
#define Option3Key @"Option3"
#define Option4Key @"Option4"

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]

static const NSInteger TweakSection = 9999;

@interface YTSettingsSectionItemManager (Tweak)
- (void)updateTweakSectionWithEntry:(id)entry;
@end

static BOOL IsEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static int GetSelection(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

NSBundle *TweakBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/" TweakName ".bundle")];
    });
    return bundle;
}

%hook YTSettingsGroupData

- (NSArray <NSNumber *> *)orderedCategories {
    if (self.type != 1 || class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return %orig;
    NSMutableArray <NSNumber *> *mutableCategories = %orig.mutableCopy;

    // Choose your settings insertion index (when grouped settings experiment is enabled)
    [mutableCategories insertObject:@(TweakSection) atIndex:0];
    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;

    // Choose your settings insertion index
    NSUInteger insertIndex = [order indexOfObject:@(1)]; // "General" index is 1
    if (insertIndex != NSNotFound) {
        NSMutableArray <NSNumber *> *mutableOrder = [order mutableCopy];
        [mutableOrder insertObject:@(TweakSection) atIndex:insertIndex + 1];
        order = mutableOrder.copy;
    }

    return order;
}

%end

// This hook is for pushing YTSettingsPickerViewController with the (boolean) options that have no default selection
// If you uncomment headerItem code below, you don't need this hook
// %hook YTSettingsSectionController

// - (void)setSelectedItem:(NSUInteger)selectedItem {
//     if (selectedItem != NSNotFound) %orig;
// }

// %end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateTweakSectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = TweakBundle();
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // Master switch
    YTSettingsSectionItem *master = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"ENABLED")
        titleDescription:LOC(@"ENABLED DESC")
        accessibilityIdentifier:nil
        switchOn:IsEnabled(EnabledKey)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:EnabledKey];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:master];

    // Boolean option
    YTSettingsSectionItem *option1 = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"OPTION 1")
        titleDescription:LOC(@"OPTION 1 DESC")
        accessibilityIdentifier:nil
        switchOn:IsEnabled(Option1Key)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:Option1Key];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:option1];

    // Picker option (integer)
    YTSettingsSectionItem *option2 = [YTSettingsSectionItemClass itemWithTitle:LOC(@"PICKABLE OPTION")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            switch (GetSelection(Option2Key)) {
                case 1:
                    return LOC(@"SUBOPTION 2");
                case 2:
                    return LOC(@"SUBOPTION 3");
                case 0:
                default:
                    return LOC(@"SUBOPTION 1");
            }
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSString *title = LOC(@"PICKABLE OPTION");
            // YTSettingsSectionItem *headerItem = [YTSettingsSectionItemClass itemWithTitle:title accessibilityIdentifier:nil detailTextBlock:nil selectBlock:nil];
            // headerItem.enabled = NO;
            NSArray <YTSettingsSectionItem *> *rows = @[
                // headerItem,
                [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"SUBOPTION 1") titleDescription:LOC(@"SUBOPTION 1 DESC") selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:Option2Key];
                    [settingsViewController reloadData];
                    return YES;
                }],
                [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"SUBOPTION 2") titleDescription:LOC(@"SUBOPTION 2 DESC") selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:Option2Key];
                    [settingsViewController reloadData];
                    return YES;
                }],
                [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"SUBOPTION 3") titleDescription:LOC(@"SUBOPTION 3 DESC") selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:Option2Key];
                    [settingsViewController reloadData];
                    return YES;
                }]
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:title pickerSectionTitle:nil rows:rows selectedItemIndex:GetSelection(Option2Key) parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:option2];

    // Boolean option (group)
    YTSettingsSectionItem *booleanGroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"BOOLEAN GROUP OPTIONS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSString *title = LOC(@"BOOLEAN GROUP TITLE");
        // YTSettingsSectionItem *headerItem = [YTSettingsSectionItemClass itemWithTitle:title accessibilityIdentifier:nil detailTextBlock:nil selectBlock:nil];
        // headerItem.enabled = NO;
        NSArray <YTSettingsSectionItem *> *rows = @[
            // headerItem,
            [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"OPTION 3")
                titleDescription:LOC(@"OPTION 3 DESC")
                accessibilityIdentifier:nil
                switchOn:IsEnabled(Option3Key)
                switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:Option3Key];
                    return YES;
                }
                settingItemId:0],
            [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"OPTION 4")
                titleDescription:LOC(@"OPTION 4 DESC")
                accessibilityIdentifier:nil
                switchOn:IsEnabled(Option4Key)
                switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:Option4Key];
                    return YES;
                }
                settingItemId:0]
        ];
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:title pickerSectionTitle:nil rows:rows selectedItemIndex:0 /* NSNotFound */ parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    [sectionItems addObject:booleanGroup];

    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        // Choose your settings icon, or pass nil for default icon
        // Check out https://github.com/PoomSmart/YTIcons for choosing your icon
        YTIIcon *icon = [%c(YTIIcon) new];
        // icon.iconType = <some-icon-type>;
        [settingsViewController setSectionItems:sectionItems forCategory:TweakSection title:TweakName icon:icon titleDescription:LOC(@"TITLE DESCRIPTION") headerHidden:NO];
    } else
        [settingsViewController setSectionItems:sectionItems forCategory:TweakSection title:TweakName titleDescription:LOC(@"TITLE DESCRIPTION") headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == TweakSection) {
        [self updateTweakSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

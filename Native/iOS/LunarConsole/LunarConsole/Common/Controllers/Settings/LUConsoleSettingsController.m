//
//  LUConsoleSettingsController.m
//
//  Lunar Unity Mobile Console
//  https://github.com/SpaceMadness/lunar-unity-console
//
//  Copyright 2019 Alex Lementuev, SpaceMadness.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <objc/runtime.h>

#import "Lunar.h"

#import "LUConsoleSettingsController.h"

static const NSInteger kTagName = 1;
static const NSInteger kTagButton = 2;
static const NSInteger kTagInput = 3;
static const NSInteger kTagSwitch = 4;

typedef enum : NSUInteger {
	LUSettingTypeBool,
	LUSettingTypeInt,
	LUSettingTypeDouble,
	LUSettingTypeEnum
} LUSettingType;

static NSDictionary * _propertyTypeLookup;
static NSArray * _proOnlyFeaturesLookup;

@interface LUConsoleSetting : NSObject

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) LUSettingType type;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) BOOL proOnly;

- (instancetype)initWithTarget:(id)target name:(NSString *)name type:(LUSettingType)type title:(NSString *)title;

- (void)setValue:(id)value;

- (BOOL)boolValue;
- (int)intValue;


@end

@implementation LUConsoleSetting

- (instancetype)initWithTarget:(id)target name:(NSString *)name type:(LUSettingType)type title:(NSString *)title {
	self = [super init];
	if (self) {
		_target = target;
		_name = name;
		_type = type;
		_title = title;
	}
	return self;
}

- (void)setValue:(id)value {
	[_target setObject:value forKey:_name];
}

- (id)value {
	return [_target objectForKey:_name];
}

- (BOOL)boolValue {
	return [[self value] boolValue];
}

- (int)intValue {
	return [[self value] intValue];
}

@end

@interface LUConsoleSettingsSection : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray<LUConsoleSetting *> *entries;

- (instancetype)initWithName:(NSString *)name entries:(NSArray<LUConsoleSetting *> *)entries;

@end

@implementation LUConsoleSettingsSection

- (instancetype)initWithName:(NSString *)name entries:(NSArray<LUConsoleSetting *> *)entries {
	self = [super init];
	if (self) {
		_name = name;
		_entries = entries;
	}
	return self;
}

@end

@interface LUConsoleSettingsController () <UITableViewDataSource> {
    NSArray<LUConsoleSettingsSection *> * _sections;
    LUPluginSettings * _settings;
}

@property (nonatomic, weak) IBOutlet UITableView * tableView;

@end

@implementation LUConsoleSettingsController

- (instancetype)initWithSettings:(LUPluginSettings *)settings {
    self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
    if (self)
    {
        _settings = settings;
        _sections = [[self class] listSections:settings];
    }
    return self;
}


#pragma mark -
#pragma mark View

- (void)viewDidLoad {
    [super viewDidLoad];
    
    LUTheme *theme = [LUTheme mainTheme];
    _tableView.backgroundColor = theme.tableColor;
    _tableView.rowHeight = 43;
    
    self.popupTitle = @"Settings";
    self.popupIcon = theme.settingsIconImage;
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sections[section].entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	LUConsoleSetting *setting = _sections[indexPath.section].entries[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Setting Cell"];
    if (cell == nil)
    {
        cell = (UITableViewCell *) [[NSBundle mainBundle] loadNibNamed:@"LUSettingsTableCell" owner:self options:nil].firstObject;
    }
    
    LUTheme *theme = [LUTheme mainTheme];
    
    cell.contentView.backgroundColor = indexPath.row % 2 == 0 ? theme.backgroundColorLight : theme.backgroundColorDark;
    
    UILabel *nameLabel = [cell.contentView viewWithTag:kTagName];
	UIButton *enumButton = [cell.contentView viewWithTag:kTagButton];
	UITextField *inputField = [cell.contentView viewWithTag:kTagInput];
	LUSwitch *boolSwitch = [cell.contentView viewWithTag:kTagSwitch];
	
	enumButton.hidden = YES;
	inputField.hidden = YES;
	boolSwitch.hidden = YES;
	
    BOOL available = LUConsoleIsFullVersion || !setting.proOnly;
    
    nameLabel.font = theme.font;
    nameLabel.textColor = available ? theme.cellLog.textColor : theme.settingsTextColorUnavailable;
    nameLabel.text = setting.title;
	
	switch (setting.type) {
		case LUSettingTypeBool:
			boolSwitch.hidden = NO;
			boolSwitch.on = [setting boolValue];
			boolSwitch.userData = setting;
			[boolSwitch addTarget:self action:@selector(onToggleBoolean:) forControlEvents:UIControlEventValueChanged];
			boolSwitch.enabled = available;
			break;
		case LUSettingTypeInt:
			inputField.hidden = NO;
			break;
		case LUSettingTypeDouble:
			inputField.hidden = NO;
			break;
		case LUSettingTypeEnum:
			enumButton.hidden = NO;
			break;
	}
    
    return cell;
}

#pragma mark -
#pragma mark Controls

- (void)onToggleBoolean:(LUSwitch *)swtch {
    LUConsoleSetting *setting = swtch.userData;
    setting.value = swtch.isOn ? @YES : @NO;
    [self settingEntryDidChange:setting];
}

#pragma mark -
#pragma mark Entries

+ (NSArray<LUConsoleSettingsSection *> *)listSections:(LUPluginSettings *)settings {
	return @[
	  [[LUConsoleSettingsSection alloc] initWithName:@"Exception Warning" entries:@[
        [[LUConsoleSetting alloc] initWithTarget:settings.exceptionWarning name:@"displayMode" type:LUSettingTypeEnum title:@"Display Mode"]
	  ]],
	  [[LUConsoleSettingsSection alloc] initWithName:@"Log Overlay" entries:@[
		[[LUConsoleSetting alloc] initWithTarget:settings.logOverlay name:@"enabled" type:LUSettingTypeDouble title:@"Enabled"],
		[[LUConsoleSetting alloc] initWithTarget:settings.logOverlay name:@"maxVisibleLines" type:LUSettingTypeInt title:@"Max Visible Lines"],
		[[LUConsoleSetting alloc] initWithTarget:settings.logOverlay name:@"timeout" type:LUSettingTypeDouble title:@"Timeout"]
	  ]],
	];
}

- (void)settingEntryDidChange:(LUConsoleSetting *)entry {
//    [_settings setValue:entry.value forKey:entry.name];
//    [_settings save];
}

@end

// OPOperationConditionUserNotification.m
// Copyright (c) 2015 Tom Wilson <tom@toms-stuff.net>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if TARGET_OS_IPHONE

#import "OPOperationConditionUserNotification.h"

#import "OPOperation.h"

#import "UIUserNotificationSettings+Operator.h"
#import "NSError+OPOperationErrors.h"

#import "OPOperationConditionMututallyExclusive.h"

NSString * const kCurrentSetings = @"CurrentUserNotificationSettings";
NSString * const kDesiredSettings = @"DesiredUserNotificationSettings";


#pragma mark - OPOperationConditionUserNotification Private 

@interface OPOperationConditionUserNotification()

@property (strong, nonatomic) UIUserNotificationSettings *settings;
@property (strong, nonatomic) UIApplication *application;
@property (assign, nonatomic) OPOperationConditionUserNotificationBehavior behavior;

@end

#pragma mark - OPUserNotificationPermissionOperation

@interface OPUserNotificationPermissionOperation : OPOperation

@property (strong, nonatomic) UIUserNotificationSettings *settings;
@property (strong, nonatomic) UIApplication *application;
@property (assign, nonatomic) OPOperationConditionUserNotificationBehavior behavior;

@end

@implementation OPUserNotificationPermissionOperation

- (instancetype) initWithSettings:(UIUserNotificationSettings *) settings application:(UIApplication *) appliction behavior:(OPOperationConditionUserNotificationBehavior)behavior
{
    self = [super init];
    if (self)
    {
        _settings = settings;
        _application = appliction;
        _behavior = behavior;
        
        [self addCondition:[OPOperationConditionMututallyExclusive mutuallyExclusiveWith:[UIAlertController class]]];
    }
    return self;
}

- (void) execute
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIUserNotificationSettings *currentSettings = self.application.currentUserNotificationSettings;
        
        UIUserNotificationSettings *settingsToRegister;
        
        switch (self.behavior)
        {
            case OPOperationConditionBehaviorMerge:
                settingsToRegister = [currentSettings settingsByMerging:self.settings];
                break;
            case OPOperationConditionBehaviorReplace:
            default:
                settingsToRegister = self.settings;
                break;
        }
        
        [self.application registerUserNotificationSettings:settingsToRegister];
        
        [self finish];
    });
}

@end

#pragma mark - OPOperationConditionUserNotification Implementation

@implementation OPOperationConditionUserNotification

- (instancetype) initWithSettings:(UIUserNotificationSettings *)settings application:(UIApplication *)application
{
    return [self initWithSettings:settings application:application behavior:OPOperationConditionBehaviorMerge];
}

- (instancetype) initWithSettings:(UIUserNotificationSettings *)settings application:(UIApplication *)application behavior:(OPOperationConditionUserNotificationBehavior)behavior
{
    self = [super init];
    if (self)
    {
        _settings = settings;
        _application = application;
        _behavior = behavior;
    }
    return self;
}

#pragma mark - OPOperationCondition

- (NSString *) name
{
    return @"UserNotification";
}

- (BOOL) isMutuallyExclusive
{
    return NO;
}

- (NSOperation *) dependencyForOperation:(OPOperation *)operation
{
    return [[OPUserNotificationPermissionOperation alloc] initWithSettings:self.settings
                                                               application:self.application
                                                                  behavior:self.behavior];
}

- (void) evaluateConditionForOperation:(OPOperation *)operation completion:(void (^)(NSError *))completion
{
    id result;
    
    UIUserNotificationSettings *current = self.application.currentUserNotificationSettings;
    
    if ([current containsSettings:self.settings])
    {
        result = [NSNull null];
    }
    else
    {
        NSError *error = [NSError errorWithCode:OPOperationErrorCodeConditionFailed userInfo:@{
                                                                                               kOPOperationConditionKey: NSStringFromClass(self.class),
                                                                                               kCurrentSetings: current ? current : [NSNull class],
                                                                                               kDesiredSettings: self.settings
                                                                                               }];
        
        result = error;
    }
    
    completion(result);
}

@end

#endif
//
//  ViewController.m
//  CoreDataThread
//
//  Created by 覃团业 on 2020/2/24.
//  Copyright © 2020 覃团业. All rights reserved.
//

#import "ViewController.h"
#import <CoreData/CoreData.h>
#import "Employee+CoreDataClass.h"

@interface ViewController ()

@property (nonatomic, strong) NSManagedObjectContext *saveContext;
@property (nonatomic, strong) NSManagedObjectContext *mainContext;
@property (nonatomic, strong) NSManagedObjectContext *bgContext;
@property (nonatomic, strong) NSPersistentStoreCoordinator *psc;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 通过监听NSManagedObjectContextDidSaveNotification通知，来获取所有NSManagedObjectContext的改变消息
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextChanged:) name:NSManagedObjectContextDidSaveNotification object:nil];
    
    [self insertEmployee];
    [self performSelector:@selector(query) withObject:nil afterDelay:1.0];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isAfteriOS5 {
    NSLog(@"versiont: %f", NSFoundationVersionNumber);
    if (@available(iOS 8.0, *)) {
        return [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion > 5;
    } else {
        return [[UIDevice currentDevice].systemVersion floatValue] > 5;
    }
}

- (void)insertEmployee {
    Employee *emp = [NSEntityDescription insertNewObjectForEntityForName:@"Employee" inManagedObjectContext:self.bgContext];
    emp.name = @"lxz";
    emp.height = 1.7f;
    emp.brithday = [NSDate date];
    
    [self.bgContext performBlock:^{
        NSError *error = nil;
        [self.bgContext save:&error];
        if (error == nil) {
            [self.saveContext save:&error];
            
            if (error) {
                NSLog(@"Save context save error: %@", error);
            }
        } else {
            NSLog(@"Background context save error: %@", error);
        }
    }];
}

- (void)query {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Employee"];
    
    NSError *error = nil;
    NSArray<Employee *> *employees = [self.mainContext executeFetchRequest:request error:&error];
    if (error == nil) {
        [employees enumerateObjectsUsingBlock:^(Employee * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSLog(@"Employee name: %@, height: %f, brithday: %@", obj.name, obj.height, obj.brithday);
        }];
    } else {
        NSLog(@"Query error: %@", error);
    }
}

#pragma mark - MOC改变后的通知回调

// MOC改变后的通知回调
- (void)contextChanged:(NSNotification *)noti {
    NSManagedObjectContext *MOC = noti.object;
    // 这里需要做判断操作，判断当前改变的NSManagedObjectContext是否我们将要做同步的NSManagedObjectContext，如果就是当前NSManagedObjectContext自己做的改变，那就不需要再同步自己了。
    // 由于项目中可能存在多个NSPersistentStoreCoordinator，所以下面还需要判断NSPersistentStoreCoordinator是否当前操作的NSPersistentStoreCoordinator，如果不是当前NSPersistentStoreCoordinator则不需要同步，不要去同步其他本地存储的数据。
    [MOC performBlock:^{
        // 直接调用系统提供的同步API，系统内部会完成同步的实现细节。
        [MOC mergeChangesFromContextDidSaveNotification:noti];
    }];
}

#pragma mark - 懒加载

- (NSPersistentStoreCoordinator *)psc {
    if (_psc == nil) {
        // 创建托管对象模型，并指明加载Company模型文件
        NSURL *modelPath = [[NSBundle mainBundle] URLForResource:@"CoreDataThread" withExtension:@"momd"];
        if (@available(iOS 11.0, *)) {} else {
            modelPath = [modelPath URLByAppendingPathComponent:@"CoreDataThread.mom"];
        }
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelPath];
        
        // 创建NSPersistentStoreCoordinator对象，并将托管对象模型当做参数传入，其他NSManagedObjectContext都是用这一个NSPersistentStoreCoordinator。
        _psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        
        // 根据指定的路径，创建并关联本地数据库
        NSString *dataPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
        dataPath = [dataPath stringByAppendingFormat:@"/CoreDataThread.sqlite"];
        
        NSError *error = nil;
        [_psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:dataPath] options:nil error:&error];
        
        if (error) {
            NSLog(@"Init NSPersistentStoreCoordinator error: %@", error);
            _psc = nil;
        }
    }
    return _psc;
}

- (NSManagedObjectContext *)saveContext {
    if (_saveContext == nil && self.psc) {
        _saveContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _saveContext.persistentStoreCoordinator = self.psc;
        // 保存出现冲突时，使用当前Context的数据覆盖本地数据，未发生冲突的数据不受影响
        _saveContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    }
    return _saveContext;
}

- (NSManagedObjectContext *)mainContext {
    if (_mainContext == nil && self.psc && self.saveContext != nil) {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _mainContext.parentContext = self.saveContext;
        // 保存出现冲突时，使用当前Context的数据覆盖本地数据，未发生冲突的数据不受影响
        _mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    }
    return _mainContext;
}

- (NSManagedObjectContext *)bgContext {
    if (_bgContext == nil && self.psc && self.saveContext != nil) {
        _bgContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _bgContext.parentContext = _saveContext;
        // 保存出现冲突时，使用当前Context的数据覆盖本地数据，未发生冲突的数据不受影响
        _bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    }
    return _bgContext;
}

@end

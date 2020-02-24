//
//  Employee+CoreDataProperties.m
//  CoreDataThread
//
//  Created by 覃团业 on 2020/2/24.
//  Copyright © 2020 覃团业. All rights reserved.
//
//

#import "Employee+CoreDataProperties.h"

@implementation Employee (CoreDataProperties)

+ (NSFetchRequest<Employee *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Employee"];
}

@dynamic height;
@dynamic name;
@dynamic brithday;

@end

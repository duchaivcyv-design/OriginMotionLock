#import <Foundation/Foundation.h>

@interface OrderedDictionary : NSMutableDictionary {
    NSMutableDictionary *dictionary;
    NSMutableArray *array;
}
- (id)init;
- (id)initWithCapacity:(NSUInteger)capacity;
- (void)setObject:(id)anObject forKey:(id)aKey;
- (void)removeObjectForKey:(id)aKey;
- (NSEnumerator *)keyEnumerator;
- (NSArray *)allKeys;
@end

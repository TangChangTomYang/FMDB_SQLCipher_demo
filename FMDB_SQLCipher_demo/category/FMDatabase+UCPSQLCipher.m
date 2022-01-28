//
//  FMDatabase+UCPSQLCipher.m
//  MKHelloWorld
//
//  Created by 苏尚进 on 2022/1/27.
//

#import "FMDatabase+UCPSQLCipher.h"

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

@implementation FMDatabase (UCPSQLCipher)

+ (instancetype)ucp_openDatabaseWithPath:(NSString *)aPath encryptKey:(nullable NSString *)key{
    [self ucp_tryEncryptDatabaseWithPath:aPath encryptKey:key];
    FMDatabase *db = [self databaseWithPath:aPath];
    if([db open]){
        if(key.length){
            [db setKey:key];
        }
    }
    return db;
}
+ (void)ucp_tryEncryptDatabaseWithPath:(NSString *)aPath encryptKey:(nullable NSString *)key{
    if([[NSFileManager defaultManager] fileExistsAtPath:aPath] && key.length>0){
        FMDatabase *db = [self databaseWithPath:aPath];
        if([db open]){
            [db setKey:key];
            BOOL isGood = [db goodConnection];
            [db close];
            if(!isGood){//打不开时，进行数据库加密迁移
                [self ucp_encryptDatabase:aPath withKey:key];
            }
        }
    }
}
//对指定的非加密数据库进行加密
+ (void)ucp_encryptDatabase:(NSString *)aPath withKey:(NSString *)key{
    NSString *tmpEncryptFile = [NSString stringWithFormat:@"%@.tmpEncryptDB.db",aPath];//临时的加密数据库文件
    if([[NSFileManager defaultManager] fileExistsAtPath:tmpEncryptFile]){
        [[NSFileManager defaultManager] removeItemAtPath:tmpEncryptFile error:nil];
    }
    sqlite3 *unencrypted_DB;
    if (sqlite3_open([aPath UTF8String], &unencrypted_DB) == SQLITE_OK) {
        char *errmsg = NULL;
        int rc = SQLITE_OK;
        
        // Attach empty encrypted database to unencrypted database
        if(rc == SQLITE_OK) rc = sqlite3_exec(unencrypted_DB, [[NSString stringWithFormat:@"ATTACH DATABASE '%@' AS tmpEncryptDB KEY '%@';",tmpEncryptFile,key] UTF8String], NULL, NULL, &errmsg);
        
        // export database
        if(rc == SQLITE_OK) rc = sqlite3_exec(unencrypted_DB, "begin exclusive transaction;", NULL, NULL, &errmsg);
        if(rc == SQLITE_OK) rc = sqlite3_exec(unencrypted_DB, "SELECT sqlcipher_export('tmpEncryptDB');", NULL, NULL, &errmsg);
        if(rc == SQLITE_OK) rc = sqlite3_exec(unencrypted_DB, "commit transaction;", NULL, NULL, &errmsg);
        
        // Detach encrypted database
        if(rc == SQLITE_OK) rc = sqlite3_exec(unencrypted_DB, "DETACH DATABASE tmpEncryptDB;", NULL, NULL, &errmsg);
        
        if(rc == SQLITE_OK) rc = sqlite3_close(unencrypted_DB);
        
        if(rc==SQLITE_OK){
            //使用临时的加密数据库替换原始数据库文件
            NSFileManager *fm = [NSFileManager defaultManager];
            NSError *error = nil;
            NSString *delFile = [NSString stringWithFormat:@"%@.tmp.del",aPath];
            if([[NSFileManager defaultManager] fileExistsAtPath:delFile]){
                [[NSFileManager defaultManager] removeItemAtPath:delFile error:nil];
            }
            [fm moveItemAtPath:aPath toPath:delFile error:&error];
            [fm moveItemAtPath:tmpEncryptFile toPath:aPath error:&error];
            [fm removeItemAtPath:delFile error:&error];
        }
        else{
#ifdef DEBUG
            NSLog(@"迁移数据库(%@),出错:%@,",aPath,[NSString stringWithCString:errmsg encoding:NSUTF8StringEncoding]);
#endif
        }
    }
}
@end






@implementation FMDatabaseQueue (UCPSQLCipher)
+ (nullable instancetype)ucp_databaseQueueWithPath:(NSString * _Nullable)aPath encryptKey:(nullable NSString *)key{
    [FMDatabase ucp_tryEncryptDatabaseWithPath:aPath encryptKey:key];
    FMDatabaseQueue *queue = [self databaseQueueWithPath:aPath];
    [queue __ucp_setupEncryptKey:key];
    return queue;
}
+ (nullable instancetype)ucp_databaseQueueWithURL:(NSURL * _Nullable)url encryptKey:(nullable NSString *)key{
    return [self ucp_databaseQueueWithPath:url.path encryptKey:key];
}
+ (nullable instancetype)ucp_databaseQueueWithPath:(NSString * _Nullable)aPath flags:(int)openFlags encryptKey:(nullable NSString *)key{
    [FMDatabase ucp_tryEncryptDatabaseWithPath:aPath encryptKey:key];
    FMDatabaseQueue *queue = [self databaseQueueWithPath:aPath flags:openFlags];
    [queue __ucp_setupEncryptKey:key];
    return queue;
}
+ (nullable instancetype)ucp_databaseQueueWithURL:(NSURL * _Nullable)url flags:(int)openFlags encryptKey:(nullable NSString *)key{
    return [self ucp_databaseQueueWithPath:url.path flags:openFlags encryptKey:key];
}
- (void)__ucp_setupEncryptKey:(nullable NSString *)key{
    if(key.length){
        [self inDatabase:^(FMDatabase * _Nonnull db) {
            [db setKey:key];
        }];
    }
}
@end

@implementation FMDatabasePool (UCPSQLCipher)
+ (nullable instancetype)ucp_databasePoolWithPath:(NSString * _Nullable)aPath encryptKey:(nullable NSString *)key{
    [FMDatabase ucp_tryEncryptDatabaseWithPath:aPath encryptKey:key];
    FMDatabasePool *pool = [self databasePoolWithPath:aPath];
    [pool __ucp_setupEncryptKey:key];
    return pool;
}
+ (nullable instancetype)ucp_databasePoolWithURL:(NSURL * _Nullable)url encryptKey:(nullable NSString *)key{
    return [self ucp_databasePoolWithPath:url.path encryptKey:key];
}
+ (nullable instancetype)ucp_databasePoolWithPath:(NSString * _Nullable)aPath flags:(int)openFlags encryptKey:(nullable NSString *)key{
    [FMDatabase ucp_tryEncryptDatabaseWithPath:aPath encryptKey:key];
    FMDatabasePool *pool = [self databasePoolWithPath:aPath flags:openFlags];
    [pool __ucp_setupEncryptKey:key];
    return pool;
}
+ (nullable instancetype)ucp_databasePoolWithURL:(NSURL * _Nullable)url flags:(int)openFlags encryptKey:(nullable NSString *)key{
    return [self ucp_databasePoolWithPath:url.path flags:openFlags encryptKey:key];
}
- (void)__ucp_setupEncryptKey:(nullable NSString *)key{
    if(key.length){
        [self inDatabase:^(FMDatabase * _Nonnull db) {
            [db setKey:key];
        }];
    }
}
@end


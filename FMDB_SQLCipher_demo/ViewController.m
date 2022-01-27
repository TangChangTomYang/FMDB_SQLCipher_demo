//
//  ViewController.m
//  abc
//
//  Created by yangrui on 2022/1/20.
//  Copyright © 2022 yangrui. All rights reserved.
//

#import "ViewController.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
//#import "sqlite3.h"

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import "sqlite3.h"
#endif

@interface ViewController ()
@property(nonatomic, strong)FMDatabaseQueue *dbQueue;

@property(nonatomic, assign)BOOL isMingWen;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSError *err = nil;
    NSData *data = [NSData data];
    [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&err];
    
    NSLog(@"%@", err.localizedDescription);
//    [self createDataBase];
}


-(void)createDataBase{
//    NSLog(@"===createDataBase");
    NSArray *directoryArr = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [directoryArr objectAtIndex:0];
    NSString *dataBaseDirectory = [documentDirectory stringByAppendingPathComponent:@"zhangsan"];
        
//    NSLog(@"===createDataBase 数据库目录: \n %@",dataBaseDirectory);
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataBaseDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dataBaseDirectory
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:nil];
    }
    NSString *dbPath = [dataBaseDirectory stringByAppendingPathComponent:@"RCSdb.db"];
    self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    NSLog(@"===createDataBase dbPath: %@",dbPath);
    __block BOOL ret = NO;
 
    // 1.
    NSString *cipherKey = @"cipherKey";
    [self.dbQueue inDatabase:^(FMDatabase *db) {
                // 这个方法只能用于全新的数据库, 或者已经加密的数据库
        ret = [db setKey:cipherKey];
    }];
         
    NSLog(@"===createDataBase 检测链接 goodConnection");
    [self.dbQueue inDatabase:^(FMDatabase *db) {  // 第一时会报警告
        ret = [db goodConnection];
    }];
    NSLog(@"===createDataBase goodConnection status: %d", ret);
    
    if(ret != YES){
        [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            [db close];
        }];
        self.dbQueue = nil;

        NSLog(@"===createDataBase 迁移数据库加密");
        ret = [self transferDataBaseAtPath:dbPath withSqlCipherKey:cipherKey];

        // 重新打开数据库
        NSLog(@"===createDataBase 迁移后重新 打开数据库");
        self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            ret = [db setKey:cipherKey];
        }];
        NSLog(@"===createDataBase 迁移后 设置key: %@ isOk %d",cipherKey, ret);

    }
    
   [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql= @"CREATE TABLE IF NOT EXISTS chat(\
                     messageID         Blob PRIMARY KEY,\
                     OrderId           Integer,\
                     MessageType       Integer,\
                     Status            Integer \
                     );";

        BOOL ret = [db executeUpdate:sql];
        NSLog(@"---创建表: %d",ret);
   }];
    
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *sql= @"CREATE TABLE IF NOT EXISTS chat2(\
                      messageID         Blob PRIMARY KEY,\
                      OrderId           Integer,\
                      MessageType       Integer,\
                      Status            Integer \
                      );";

         BOOL ret = [db executeUpdate:sql];
         NSLog(@"---创建表: %d",ret);
    }];
 
    [self.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *sql= @"CREATE TABLE IF NOT EXISTS chat3(\
                      messageID         Blob PRIMARY KEY,\
                      OrderId           Integer,\
                      MessageType       Integer,\
                      Status            Integer \
                      );";

         BOOL ret = [db executeUpdate:sql];
         NSLog(@"---创建表: %d",ret);
    }];
}




/// 将明文数据库文件 进行 SQLCipher 数据迁移
/// @param path 明文数据库路径
-(BOOL)transferDataBaseAtPath:(NSString *)path withSqlCipherKey:(NSString *)sqlCipherKey{
  
    if (path.length == 0) {
        NSLog(@"数据库SQLCipher迁移时, 明文数据库路径为空");
        return NO;
    }
    
    if (sqlCipherKey.length == 0) {
        NSLog(@"数据库SQLCipher迁移时, sqlCipherKey为空");
        return NO;
    }
     
    
    sqlite3 *unencrypted_db;
    // 1. 打开明文数据库
    if (sqlite3_open([path UTF8String], &unencrypted_db) != SQLITE_OK) {
        NSLog(@"数据库SQLCipher迁移时, 打开明文数据库失败, %s, return",sqlite3_errmsg(unencrypted_db));
        sqlite3_close(unencrypted_db);
        return NO;
    }
    
    // 2. Attach empty encrypted database to unencrypted database
    // 附加一个空的加密数据库到明文数据库
    NSString *tempPath = [NSString stringWithFormat:@"%@.tmp.db",path];
    // 删除 tempPath
    [self removeFile:tempPath];
    char *errmsg;
    
    NSString *attachSql = [NSString stringWithFormat:@"ATTACH DATABASE '%@' AS encrypted KEY '%@';",
                                                        tempPath,
                                                        sqlCipherKey];
    sqlite3_exec(unencrypted_db, attachSql.UTF8String, NULL, NULL, &errmsg);
    if (errmsg) {
        NSLog(@"数据库SQLCipher迁移时, 附加一个空的加密数据库到明文数据库 失败:%@, return",
              [NSString stringWithUTF8String:errmsg]);
        sqlite3_close(unencrypted_db);
        return NO;
    }
    
    NSString *beginSql = @"begin exclusive transaction;";
    sqlite3_exec(unencrypted_db, beginSql.UTF8String, NULL, NULL, &errmsg);
    if (errmsg) {
        NSLog(@"数据库SQLCipher迁移时, 开启事务失败 失败:%@, return",
              [NSString stringWithUTF8String:errmsg]);
        sqlite3_close(unencrypted_db);
        return NO;
    }
    
    // 3. export database
    // 将明文数据库中的数据导出到 加密数据库
    NSString *exportSql = @"SELECT sqlcipher_export('encrypted');";
    sqlite3_exec(unencrypted_db, exportSql.UTF8String, NULL, NULL, &errmsg);
    if (errmsg) {
        NSLog(@"数据库SQLCipher迁移时, 将明文数据库中的数据导出到 加密数据库 失败:%@, return",
              [NSString stringWithUTF8String:errmsg]);
        sqlite3_close(unencrypted_db);
        return NO;
    }
    
    NSString *commitSql = @"commit transaction;";
    sqlite3_exec(unencrypted_db, commitSql.UTF8String, NULL, NULL, &errmsg);
    if (errmsg) {
        NSLog(@"数据库SQLCipher迁移时, 提交事务失败 失败:%@, return",
              [NSString stringWithUTF8String:errmsg]);
        sqlite3_close(unencrypted_db);
        return NO;
    }
    
    // 4. Detach encrypted database
    // 解除加密数据库的附加操作
    NSString *detachSql = @"DETACH DATABASE encrypted;";
    sqlite3_exec(unencrypted_db, detachSql.UTF8String, NULL, NULL, &errmsg);
    if (errmsg) {
        NSLog(@"数据库SQLCipher迁移时, 解除加密数据库的附加操作 失败:%@, return", [NSString stringWithUTF8String:errmsg]);
        sqlite3_close(unencrypted_db);
        return NO;
    }
    
    // 5. close unencrypted_db
    sqlite3_close(unencrypted_db);
    BOOL ret = [self replaceFile:tempPath toFile:path];
    
    NSLog(@"数据库SQLCipher迁移时, 完成 ret: %d",ret);
    return ret;
    
}

-(void)removeFile:(NSString *)path{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    BOOL ret = [fileManager fileExistsAtPath:path];
    if (ret) {
        NSError *err = nil;
        [fileManager removeItemAtPath:path error:&err];
        NSLog(@"删除文件: %@, err: %@", path, err.localizedDescription);
    }
}

-(BOOL)moveFile:(NSString *)file toFile:(NSString *)toFile{
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    BOOL ret = [fileManager fileExistsAtPath:file];
    if (ret) {
        NSError *err = nil;
        ret = [fileManager moveItemAtPath:file toPath:toFile error:&err];
        NSLog(@"移动文件from: %@, toPath: %@",file, toFile);
    }
    return ret;
}

/// 将文件 file 重命名为 toFile, 执行成功后file 会被删除,  只剩toFile
/// @param file 源文件路径
/// @param toFile 目标文件路径
-(BOOL)replaceFile:(NSString *)file toFile:(NSString *)toFile{
    
    [self removeFile:toFile];
    
    return [self moveFile:file toFile:toFile];
}
 

@end


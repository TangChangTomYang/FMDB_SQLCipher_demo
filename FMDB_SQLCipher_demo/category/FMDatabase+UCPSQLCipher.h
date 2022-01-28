//
//  FMDatabase+UCPSQLCipher.h
//  MKHelloWorld
//
//  Created by 苏尚进 on 2022/1/27.
//
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

 

@interface FMDatabase (UCPSQLCipher)
/// 返回打开好的数据库.如果指定非空密码时，将返回加密数据库.(已自动进行未加密数据库的迁移工作）
/// @param aPath 数据库路径
/// @param key 加密密码
+ (instancetype)ucp_openDatabaseWithPath:(NSString *)aPath encryptKey:(nullable NSString *)key;

/// 尝试迁移未加密数据库为加密数据库
/// @param aPath 数据库路径
/// @param key 加密密码
+ (void)ucp_tryEncryptDatabaseWithPath:(NSString *)aPath encryptKey:(nullable NSString *)key;
@end

@interface FMDatabaseQueue (UCPSQLCipher)
//生成加密的数据库。密码为空时，为非加密数据库。（如果加密，自动进行数据库迁移）
+ (nullable instancetype)ucp_databaseQueueWithPath:(NSString * _Nullable)aPath encryptKey:(nullable NSString *)key;
+ (nullable instancetype)ucp_databaseQueueWithURL:(NSURL * _Nullable)url encryptKey:(nullable NSString *)key;
+ (nullable instancetype)ucp_databaseQueueWithPath:(NSString * _Nullable)aPath flags:(int)openFlags encryptKey:(nullable NSString *)key;
+ (nullable instancetype)ucp_databaseQueueWithURL:(NSURL * _Nullable)url flags:(int)openFlags encryptKey:(nullable NSString *)key;
@end

@interface FMDatabasePool (UCPSQLCipher)
//生成加密的数据库。密码为空时，为非加密数据库。（如果加密，自动进行数据库迁移）
+ (nullable instancetype)ucp_databasePoolWithPath:(NSString * _Nullable)aPath encryptKey:(nullable NSString *)key;
+ (nullable instancetype)ucp_databasePoolWithURL:(NSURL * _Nullable)url encryptKey:(nullable NSString *)key;
+ (nullable instancetype)ucp_databasePoolWithPath:(NSString * _Nullable)aPath flags:(int)openFlags encryptKey:(nullable NSString *)key;
+ (nullable instancetype)ucp_databasePoolWithURL:(NSURL * _Nullable)url flags:(int)openFlags encryptKey:(nullable NSString *)key;
@end 

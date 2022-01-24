

# SQLCipher 迁移明文数据库总结

本文章将主要介绍使用SQLCipher 加密数据库, 以及将 为加密的数据库迁移为 加密数据库

## 一、疑问?

**[How to encrypt a plaintext SQLite database to use SQLCipher (and avoid “file is encrypted or is not a database” errors)](https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868)**


如何加密明文SQLite数据库以使用SQLCipher（并避免“文件已加密或不是数据库”错误）

 

## 二、背景

**We often field questions about how SQLCipher encryption works. In one common scenario, a developer wants to convert an existing standard SQLite database to an encrypted SQLCipher database. For example, this might be a requirement for an application that was not previously using SQLCipher, and must convert an insecure database to use SQLCipher full database encryption during an upgrade.**

我们经常提出关于SQLCipher加密如何工作的问题。在一个常见场景中，开发人员希望将现有的标准SQLite数据库转换为加密的SQLCipher数据库。

- 例如:

  对于以前未使用SQLCipher的应用程序，这可能是一个要求，并且在升级期间必须将不安全的数据库转换为使用SQLCipher完全数据库加密。



**In such cases, developers may initially attempt to open a standard SQLite database and then call sqlite3_key 260 or PRAGMA key 171, thinking that SQLCipher will open the existing database and rewrite it using encryption. That is not possible, however, and such attempts will be met with a “file is encrypted or is not a database” error (code 26 / SQLITE_NOTADB).**



## 三、常见误区

**划重点**⭐️

在这种情况下，开发人员可能首先尝试打开一个标准的SQLite数据库，然后调用sqlite3_key 260或PRAGMA key 171，认为SQLCipher将打开现有数据库并使用加密重写它。

**但是，这是不可能的，这样的尝试将遇到“文件已加密或不是数据库”错误（代码26/SQLITE_NOTADB）。**



**The reason is that SQLCipher encryption works on a per-page basis for efficiency, and `sqlite3_key`and `PRAGMA key` can *only* be used:**

- **when opening a *brand new* database (i.e. for the first time), or**
- **when opening an *already encrypted* databases.**

原因是SQLCipher encryption以每页为单位工作以提高效率，sqlite3_key和PRAGMA key只能用于：

- 打开全新数据库时（即首次），或

- 打开已加密的数据库时。



## 四、解决思路

**It follows that the correct way to convert an existing database to use SQLCipher is to create a new, empty, encrypted database, then copy the data from the insecure database to the encrypted database. Once complete, an application can simply remove the original plaintext database and use the encrypted copy from then on.**

因此，将现有数据库转换为使用SQLCipher的正确方法是:

- 创建一个新的、空的、加密的数据库
- 然后将数据从不安全的数据库复制到加密的数据库。

一旦完成，应用程序就可以简单地删除原始明文数据库，并从此使用加密副本。



## 五、SQLCipher 迁移特性

**SQLCipher has supported [`ATTACH` 56](https://www.zetetic.net/sqlcipher/sqlcipher-api/#attach) between encrypted and plaintext databases since it’s initial release, so it has always been possible to do this conversion on an table-by-table basis. However, an even easier option was added to SQLCipher 2.0, in the form of the [`sqlcipher_export()` 915](https://www.zetetic.net/sqlcipher/sqlcipher-api/#sqlcipher_export)convenience function.**

SQLCipher自最初发布以来就支持加密数据库和明文数据库之间的ATTACH 56，因此始终可以逐个表进行转换。但是，SQLCipher 2.0中添加了一个更简单的选项，即SQLCipher_export() 915便利函数。



**The purpose of `sqlcipher_export` is a to duplicate the entire contents of one database into another attached database. It includes all database objects: the schema, triggers, virtual tables, and all data. This makes it very easy to migrate from a standard non-encrypted SQLite database to a SQLCipher encrypted database, or back in the other direction.**

 `sqlcipher_export` 的目的是将一个数据库的全部内容复制到另一个附加数据库中。它包括所有数据库对象：模式、触发器、虚拟表和所有数据。这使得从标准的非加密SQLite数据库迁移到SQLCipher加密数据库或从另一个方向迁移回来非常容易。

> 在开发过程中，经常需要多个表之间进行操作。对于同一个数据库来说，相互之间连接表，容易实现。但是对于不同的数据库，使用Sqlite该怎么实现呢？
>
> 针对这种需要不同数据库之间的表连接操作的情况，SQLite提供了一种将外部数据库附加到当前数据库连接的机制——ATTACH DATABASE。 



**To use `sqlcipher_export()` to encrypt an existing database, first open up the standard SQLite database, but don’t provide a key. Next, ATTACH a new encrypted database, and then call the `sqlcipher_export()` function in a SELECT statement, passing in the name of the attached database you want to write the main database schema and data to.**

- 要使用 `sqlcipher_export（）`加密现有数据库，请首先打开标准SQLite数据库，但不要提供密钥。

- 接下来，附加一个新的加密数据库，然后在SELECT语句中调用`sqlcipher_export（）`函数，传入要将主数据库架构和数据写入的附加数据库的名称。

  ```
  $ ./sqlcipher plaintext.db
  sqlite> ATTACH DATABASE 'encrypted.db' AS encrypted KEY 'newkey';
  sqlite> SELECT sqlcipher_export('encrypted');
  sqlite> DETACH DATABASE encrypted;
  ```

**Finally, securely delete the existing plaintext database, and then open up the new encrypted database as usual using `sqlite3_key` or `PRAGMA key`.**

- 最后，安全地删除现有的明文数据库，然后像往常一样使用`sqlite3_key` 或`PRAGMA key` 打开新的加密数据库。



**The same process also works in reverse to create a plaintext, fully decrypted, copy of an encrypted SQLCipher database that can be opened with standard SQLite.**

同样的过程反过来也可以创建一个加密的SQLCipher数据库的纯文本、完全解密的副本，该数据库可以用标准SQLite打开。

```
$ ./sqlcipher encrypted.db
sqlite> PRAGMA key = 'testkey';
sqlite> ATTACH DATABASE 'plaintext.db' AS plaintext KEY '';  -- empty key will disable encryption
sqlite> SELECT sqlcipher_export('plaintext');
sqlite> DETACH DATABASE plaintext;
```

**It is also possible to use the `sqlcipher_export()` function in specialized cases to change or customized SQLCipher database settings. These advanced concepts are covered further [in the documentation 915](https://www.zetetic.net/sqlcipher/sqlcipher-api/#sqlcipher_export).**

也可以在特殊情况下使用`sqlcipher_export（）`函数更改或自定义sqlcipher数据库设置。这些高级概念将在文档915中进一步介绍。



## 六、SQLCipher 迁移实现

```C++
// 迁移明文数据库为SQLCipher 加密数据库 (这个代码是C++实现的)
void encryptPlainTextDatabase(const string &src_database_file, // 明文数据库路径
                              const string &license_key){			 // SQLCipher 加密的key
	
  sqlite3 *db_plaintext;
	int rc = sqlite3_open(src_database_file.c_str(), &db_plaintext);
	if (rc != SQLITE_OK) {  
    printf(“打开明文数据库失败: %s\n”,src_database_file.c_str() );
  	return;
  }
  
  //not sure if my code will work with open source version
	string lic_st(“PRAGMA cipher_license = '”+ license_key+"’ ;");
	rc = sqlite3_exec(db_plaintext, lic_st.c_str() , NULL, NULL, NULL);
	if (rc != SQLITE_OK) { 
    printf(“Failed in license step with error code: %d\n”,rc );
    return;
	}
	else{ 
     printf(“license step done”);
  }
		

  //If the encrypted file exits we will not be able to proceed, need to ensure
	//output file does not already exist.
  // 将空的加密数据库附加到 明文数据库                
  deleteFile(QString(“outDB.db3”));
	rc = sqlite3_exec(db_plaintext, 
                    “ATTACH DATABASE ‘outDB.db3’ AS encrypted KEY ‘testkey’”, 
                    0, 0, 0);
	if(rc != SQLITE_OK){
		printf(“将空的加密数据库附加到 明文数据库 失败”);
    return;
	}
	else{
    printf(“将空的加密数据库附加到 明文数据库 成功”);
  }
               
  // 将明文数据库的数据导出到密文数据库                
	rc = sqlite3_exec(db_plaintext, “SELECT sqlcipher_export(‘encrypted’)”,0,0,0);
	if(rc != SQLITE_OK){
		printf(“failed in doing sqlcipher_export() with: res: %d”,rc);
    return;
	}
	else{
    printf(“sqlcipher_export() done”);
  }
            
  // 将附加的明文数据库上的加密数据库, 解除附加                
	rc = sqlite3_exec(db_plaintext, “DETACH DATABASE encrypted;”, 0, 0, 0);
	if(rc != SQLITE_OK){
		printf(“failed to detach database with: res:%d ",rc);
		return;
	}
	else{
    printf(“detaching done done”);
  }    
  
  // 关闭明文数据库
	sqlite3_close(db_plaintext);
}
```



# FMDB 相关库

```
# Uncomment the next line to define a global platform for your project

platform :ios, '9.0'

target 'abc' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'FMDB'
  pod 'FMDB/SQLCipher'

  # Pods for abc

end
```







# SQLCipher 数据库使用



| 序号 | 是否加密 | 加密结果 | 连接状态 | 是否创建表 | 创建表结果 | 结果 |
| ---- | -------- | -------- | -------- | ---------- | ---------- | ---- |
| 1    | 否       | 否       | 成功     | 否         | 否         | 成功 |
| 2    | 是       | 成功     | 成功     | 否         | 否         | 成功 |
| 3    | 是       | 成功     | 成功     | 是         | 成功       | 成功 |
|      |          |          |          |            |            |      |
|      |          |          |          |            |            |      |




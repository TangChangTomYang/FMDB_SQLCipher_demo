# Uncomment the next line to define a global platform for your project
platform :ios, '9.0'

target 'FMDB_SQLCipher_demo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # 只能 安装  FMDB/SQLCipher, 不要再 安装 pod 'FMDB' 否则 SQLCipher 可能会报下面这个错:
  # no such function: sqlcipher_export in "SELECT sqlcipher_export('encrypted');
  pod 'FMDB/SQLCipher', '~> 2.7.5'  # FMDB with SQLCipher

end

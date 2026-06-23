#import "ZvecPlugin.h"

#import <dlfcn.h>

typedef void (*ZvecSetDefaultJiebaDictDirFn)(const char *dir);

@implementation ZvecPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [self registerDefaultJiebaDictDirWithRegistrar:registrar];
}

+ (void)registerDefaultJiebaDictDirWithRegistrar:
    (NSObject<FlutterPluginRegistrar> *)registrar {
  NSString *assetKey =
      [registrar lookupKeyForAsset:@"assets/jieba_dict/jieba.dict.utf8"
                        fromPackage:@"zvec"];
  NSString *dictFile = [[NSBundle mainBundle] pathForResource:assetKey
                                                       ofType:nil];
  if (dictFile.length == 0) {
    NSLog(@"ZvecPlugin: bundled Jieba dictionary asset not found: %@",
          assetKey);
    return;
  }

  NSString *dictDir = [dictFile stringByDeletingLastPathComponent];
  NSString *hmmFile = [dictDir stringByAppendingPathComponent:@"hmm_model.utf8"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:hmmFile]) {
    NSLog(@"ZvecPlugin: bundled Jieba HMM model asset not found: %@", hmmFile);
    return;
  }

  [self setDefaultJiebaDictDir:dictDir];
}

+ (void)setDefaultJiebaDictDir:(NSString *)dictDir {
  ZvecSetDefaultJiebaDictDirFn setDefault =
      (ZvecSetDefaultJiebaDictDirFn)dlsym(
          RTLD_DEFAULT, "zvec_set_default_jieba_dict_dir");

  if (setDefault == NULL) {
    void *handle = dlopen("@rpath/zvec.framework/zvec", RTLD_NOW);
    if (handle != NULL) {
      setDefault = (ZvecSetDefaultJiebaDictDirFn)dlsym(
          handle, "zvec_set_default_jieba_dict_dir");
    }
  }

  if (setDefault == NULL) {
    NSLog(@"ZvecPlugin: failed to find zvec_set_default_jieba_dict_dir: %s",
          dlerror());
    return;
  }

  setDefault(dictDir.UTF8String);
}

@end

// Zvec Flutter FFI Plugin.
//
// The actual zvec symbols live in the prebuilt libzvec shared library. On
// Android this companion library only exposes a tiny JNI bridge so the plugin
// registration code can set the process-wide default Jieba dictionary path
// before Dart user code starts using zvec.

#if defined(__ANDROID__)

#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>

#define ZVEC_PLUGIN_LOG_TAG "ZvecPlugin"

typedef void (*zvec_set_default_jieba_dict_dir_fn)(const char *dir);

JNIEXPORT void JNICALL
Java_com_alibaba_zvec_ZvecPlugin_nativeSetDefaultJiebaDictDir(JNIEnv *env,
                                                              jclass clazz,
                                                              jstring dir) {
  (void)clazz;

  if (dir == NULL) {
    return;
  }

  const char *dir_chars = (*env)->GetStringUTFChars(env, dir, NULL);
  if (dir_chars == NULL) {
    return;
  }

  void *handle = dlopen("libzvec.so", RTLD_NOW);
  if (handle == NULL) {
    __android_log_print(ANDROID_LOG_WARN, ZVEC_PLUGIN_LOG_TAG,
                        "Failed to open libzvec.so: %s", dlerror());
    (*env)->ReleaseStringUTFChars(env, dir, dir_chars);
    return;
  }

  zvec_set_default_jieba_dict_dir_fn set_default =
      (zvec_set_default_jieba_dict_dir_fn)dlsym(
          handle, "zvec_set_default_jieba_dict_dir");
  if (set_default == NULL) {
    __android_log_print(
        ANDROID_LOG_WARN, ZVEC_PLUGIN_LOG_TAG,
        "Failed to find zvec_set_default_jieba_dict_dir: %s", dlerror());
    (*env)->ReleaseStringUTFChars(env, dir, dir_chars);
    return;
  }

  set_default(dir_chars);
  (*env)->ReleaseStringUTFChars(env, dir, dir_chars);
}

#endif

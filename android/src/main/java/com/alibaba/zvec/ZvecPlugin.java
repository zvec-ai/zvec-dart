package com.alibaba.zvec;

import android.content.Context;
import android.content.res.AssetManager;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/** Registers bundled Jieba dictionaries with the native zvec engine. */
public final class ZvecPlugin implements FlutterPlugin {
  private static final String TAG = "ZvecPlugin";
  private static final String PACKAGE_NAME = "zvec";
  private static final String DICT_DIR = "zvec_jieba_dict";
  private static final String[] DICT_FILES = {"jieba.dict.utf8", "hmm_model.utf8"};

  private static boolean nativeLoaded = false;
  private static boolean defaultRegistered = false;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    registerDefaultJiebaDictDir(binding);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}

  private static synchronized void registerDefaultJiebaDictDir(FlutterPluginBinding binding) {
    if (defaultRegistered) {
      return;
    }

    try {
      Context context = binding.getApplicationContext();
      File dictDir = new File(context.getFilesDir(), DICT_DIR);
      if (!dictDir.exists() && !dictDir.mkdirs()) {
        Log.w(TAG, "Failed to create Jieba dictionary directory: " + dictDir);
        return;
      }

      AssetManager assets = context.getAssets();
      for (String fileName : DICT_FILES) {
        String assetKey =
            binding
                .getFlutterAssets()
                .getAssetFilePathByName("assets/jieba_dict/" + fileName, PACKAGE_NAME);
        copyAssetIfMissing(assets, assetKey, new File(dictDir, fileName));
      }

      loadNativeLibraries();
      nativeSetDefaultJiebaDictDir(dictDir.getAbsolutePath());
      defaultRegistered = true;
    } catch (Throwable error) {
      Log.w(TAG, "Failed to register bundled Jieba dictionary directory", error);
    }
  }

  private static void copyAssetIfMissing(AssetManager assets, String assetKey, File target)
      throws IOException {
    if (target.exists() && target.length() > 0) {
      return;
    }

    try (InputStream input = assets.open(assetKey);
        FileOutputStream output = new FileOutputStream(target, false)) {
      byte[] buffer = new byte[8192];
      int read;
      while ((read = input.read(buffer)) != -1) {
        output.write(buffer, 0, read);
      }
      output.getFD().sync();
    }
  }

  private static synchronized void loadNativeLibraries() {
    if (nativeLoaded) {
      return;
    }
    System.loadLibrary("zvec");
    System.loadLibrary("zvec_plugin");
    nativeLoaded = true;
  }

  private static native void nativeSetDefaultJiebaDictDir(String dir);
}

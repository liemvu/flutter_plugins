// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/*
 * Copyright (C) 2007-2008 OpenIntents.org
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * This file was modified by the Flutter authors from the following original file:
 * https://raw.githubusercontent.com/iPaulPro/aFileChooser/master/aFileChooser/src/com/ipaulpro/afilechooser/utils/FileUtils.java
 */

package io.flutter.plugins.imagepicker;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

class FileUtils {

  String getPathFromUri(final Context context, final Uri uri) {
    File file = null;
    InputStream inputStream = null;
    OutputStream outputStream = null;
    boolean success = false;
    try {
      String extension = getImageExtension(context, uri);
      String originFileName = getImageOriginalName(context, uri);
      inputStream = context.getContentResolver().openInputStream(uri);
      file = File.createTempFile(originFileName + "_image_picker_", extension, context.getCacheDir());
      file.deleteOnExit();
      outputStream = new FileOutputStream(file);
      if (inputStream != null) {
        copy(inputStream, outputStream);
        success = true;
      }
    } catch (IOException ignored) {
    } finally {
      try {
        if (inputStream != null) inputStream.close();
      } catch (IOException ignored) {
      }
      try {
        if (outputStream != null) outputStream.close();
      } catch (IOException ignored) {
        // If closing the output stream fails, we cannot be sure that the
        // target file was written in full. Flushing the stream merely moves
        // the bytes into the OS, not necessarily to the file.
        success = false;
      }
    }
    return success ? file.getPath() : null;
  }

  /** @return extension of image with dot, or default .jpg if it none. */
  private static String getImageExtension(Context context, Uri uriImage) {
    String extension = null;

    try {
      String imagePath = uriImage.getPath();
      if (uriImage.getScheme().equals(ContentResolver.SCHEME_CONTENT)) {
        final MimeTypeMap mime = MimeTypeMap.getSingleton();
        extension = mime.getExtensionFromMimeType(context.getContentResolver().getType(uriImage));
      } else {
        extension =
            MimeTypeMap.getFileExtensionFromUrl(
                Uri.fromFile(new File(uriImage.getPath())).toString());
      }
    } catch (Exception e) {
      extension = null;
    }

    if (extension == null || extension.isEmpty()) {
      //default extension for matches the previous behavior of the plugin
      extension = "jpg";
    }

    return "." + extension;
  }

  /** @return original file name. */
  private static String getImageOriginalName(Context context, Uri uriImage) {
    String result = null;
    Cursor cursor = null;

    try {
      if (uriImage.getScheme().equals(ContentResolver.SCHEME_CONTENT)) {
        cursor = context.getContentResolver().query(uriImage, null, null, null, null);

        if (cursor != null && cursor.moveToFirst()) {
          int idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
          result = cursor.getString(idx);
        }

      }
    } catch (Exception e) {
      result = null;
    } finally {
      cursor.close();
    }

    if (result == null || result.isEmpty()) {
      //default file name
      result = uriImage.getPath();
      int cut = result.lastIndexOf('/');
      if (cut != -1) {
        result = result.substring(cut + 1);
      }
    }

    return result;
  }

  private static void copy(InputStream in, OutputStream out) throws IOException {
    final byte[] buffer = new byte[4 * 1024];
    int bytesRead;
    while ((bytesRead = in.read(buffer)) != -1) {
      out.write(buffer, 0, bytesRead);
    }
    out.flush();
  }
}

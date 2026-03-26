import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<List<Map<String, dynamic>>> pickWebFolder() async {
  // Chrome等でサポートされている新しいFile System Access APIをチェック
  if (js_util.hasProperty(html.window, 'showDirectoryPicker')) {
    try {
      _injectTraverseScript(); // 探索用JS関数を注入
      
      // "アップロードしますか？" という警告の代わりに "ファイルの表示を許可しますか？" と尋ねるモダンなAPI
      final dirHandle = await js_util.promiseToFuture(
        js_util.callMethod(html.window, 'showDirectoryPicker', [])
      );
      
      final jsFilesPromise = js_util.callMethod(html.window, '__getFilesFromDir', [dirHandle, '']);
      final jsFilesList = await js_util.promiseToFuture(jsFilesPromise);
      
      final result = <Map<String, dynamic>>[];
      final int len = js_util.getProperty(jsFilesList, 'length');
      
      for (int i = 0; i < len; i++) {
        final item = js_util.getProperty(jsFilesList, i);
        final html.File file = js_util.getProperty(item, 'file');
        final String path = js_util.getProperty(item, 'path');
        
        result.add({
          'name': file.name,
          'path': path,
          'size': file.size,
          'file': file,
          'handle': js_util.getProperty(item, 'handle'), // 追記: 書き込み用にハンドルを保持
        });
      }
      return result;
    } catch (e) {
      // ユーザーがキャンセルした場合やエラーなど
      print('Directory picker error/cancelled: $e');
      return [];
    }
  } else {
    // 未対応ブラウザ向けの従来のフォールバック処理 (アップロードダイアログが出る)
    return _pickUsingInput();
  }
}

bool _scriptInjected = false;
void _injectTraverseScript() {
  if (_scriptInjected) return;
  _scriptInjected = true;
  
  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..innerHtml = '''
      window.__getFilesFromDir = async function(dirHandle, path) {
        let files = [];
        for await (const entry of dirHandle.values()) {
          const p = path ? path + '/' + entry.name : entry.name;
          if (entry.kind === 'file') {
            const file = await entry.getFile();
            files.push({ file: file, path: p, handle: entry });
          } else if (entry.kind === 'directory') {
            const subFiles = await window.__getFilesFromDir(entry, p);
            files.push(...subFiles);
          }
        }
        return files;
      };
    ''';
  html.document.body?.append(script);
}

Future<List<Map<String, dynamic>>> _pickUsingInput() async {
  final completer = Completer<List<Map<String, dynamic>>>();
  final input = html.FileUploadInputElement();
  input.setAttribute('webkitdirectory', '');
  input.setAttribute('directory', '');
  input.multiple = true;

  input.onChange.listen((e) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete([]);
      return;
    }
    
    final result = <Map<String, dynamic>>[];
    for (var file in files) {
      result.add({
        'name': file.name,
        'path': file.relativePath ?? file.name,
        'size': file.size,
        'file': file,
      });
    }
    completer.complete(result);
  });

  input.click();
  return completer.future;
}

import 'dart:convert';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:js_util' as js_util;
import 'web_folder_picker.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'SPECIAL SOLO RECORDS Tagger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Widget外（親や別クラスなど）でURLを管理するためのNotifier
  final ValueNotifier<String?> _imageUrlNotifier = ValueNotifier(null);

  // 読み込んだファイルを保持するNotifier
  final ValueNotifier<List<Map<String, dynamic>>?> _loadedFilesNotifier =
      ValueNotifier(null);

  // クリップボードから取得した画像データを保持
  Uint8List? _clipboardArtworkBytes;

  // 処理ステータス
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = "";
  final List<String> _errorFiles = [];

  // アイドル情報のリスト
  List<dynamic> _idols = [];
  // 選択中のアイドル
  dynamic _selectedIdol;
  List<Map<String, dynamic>> _songs = [];
  List<String> _songKeys = [];
  // ドロップダウン用の項目キャッシュ
  List<DropdownMenuItem<dynamic>> _idolMenuItems = [];

  @override
  void initState() {
    super.initState();
    _loadIdols();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final String response = await rootBundle.loadString('assets/song.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _songs = data.cast<Map<String, dynamic>>();
        _songKeys = data
            .map((item) => (item as Map).keys.first.toString())
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading songs: $e');
    }
  }

  Future<void> _loadIdols() async {
    try {
      final String response = await rootBundle.loadString('assets/idols.json');
      final data = await json.decode(response);
      setState(() {
        _idols = data;
        _selectedIdol = null;
        _idolMenuItems = _idols.map<DropdownMenuItem<dynamic>>((idol) {
          return DropdownMenuItem<dynamic>(
            value: idol,
            child: Text('${idol['name']} (CV: ${idol['cv']})'),
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading idols: $e');
    }
  }

  @override
  void dispose() {
    _imageUrlNotifier.dispose();
    _loadedFilesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SPECIAL SOLO RECORDS Tagger')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => html.window.open(
                        'https://github.com/bluetiger/million_solo_record_tagger',
                        '_blank',
                      ),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('使い方 / 解説 (GitHub)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '⚠️ ご利用は自己責任でお願いします',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  '1. アイドル選択',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 16),
                (_idols.isNotEmpty)
                    ? DropdownButtonFormField<dynamic>(
                        value: _selectedIdol,
                        decoration: const InputDecoration(
                          labelText: 'アイドルを選択',
                          border: OutlineInputBorder(),
                        ),
                        items: _idolMenuItems,
                        onChanged: (dynamic newValue) {
                          if (newValue == null) return;
                          setState(() {
                            _selectedIdol = newValue;
                            _clipboardArtworkBytes = null;
                            final index = _idols.indexOf(newValue);
                            if (index != -1) {
                              final releaseNum = (index + 1).toString().padLeft(
                                2,
                                '0',
                              );
                              _imageUrlNotifier.value =
                                  'https://lantis.jp/imas/ssr/images/ph_release/cd$releaseNum.jpg';
                            }
                          });
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),

                if (_selectedIdol != null) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: UpdatableImageWidget(
                      imageUrlNotifier: _imageUrlNotifier,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      '💡 上の画像を右クリックして「画像をコピー」した後、\n「タグ更新とリネームを実行」を押すとアートワークとして埋め込まれます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(thickness: 1.2),
                  const SizedBox(height: 32),
                  const Text(
                    '2. フォルダ選択 & 実行',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final allPickedFiles = await pickWebFolder();
                          if (allPickedFiles.isEmpty) return;

                          // パスでソート
                          allPickedFiles.sort(
                            (a, b) => (a['path'] as String).compareTo(
                              b['path'] as String,
                            ),
                          );

                          // 9個以上なら最初の9個に制限
                          final List<Map<String, dynamic>> files =
                              allPickedFiles.length > 9
                              ? allPickedFiles.sublist(0, 9)
                              : allPickedFiles.cast<Map<String, dynamic>>();

                          // 9個でない場合は警告を出す
                          if (allPickedFiles.length != 9) {
                            String message = allPickedFiles.length > 9
                                ? '選択されたファイルが9個を超えています（${allPickedFiles.length}個）。最初の9個のみを対象にします。'
                                : '楽曲ファイルが9個ではありません（現在の数: ${allPickedFiles.length}個）。想定と異なります。';

                            rootScaffoldMessengerKey.currentState?.showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.orange[800],
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }

                          for (int i = 0; i < files.length; i++) {
                            var file = files[i];
                            if (i < _songKeys.length) {
                              String originalName = file['name'] as String;
                              String extension = "";
                              int lastDot = originalName.lastIndexOf('.');
                              if (lastDot != -1) {
                                extension = originalName.substring(lastDot);
                              }
                              file['newName'] = _songKeys[i] + extension;
                            } else {
                              file['newName'] = file['name'];
                            }
                          }

                          _loadedFilesNotifier.value = List.from(files);
                          if (allPickedFiles.length == 9) {
                            rootScaffoldMessengerKey.currentState?.showSnackBar(
                              SnackBar(
                                content: Text('${files.length}個のファイルが選択されました'),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error: $e');
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('フォルダを選択'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<List<Map<String, dynamic>>?>(
                    valueListenable: _loadedFilesNotifier,
                    builder: (context, files, child) {
                      final bool canProcess =
                          !_isProcessing && (files != null && files.isNotEmpty);
                      return Center(
                        child: ElevatedButton.icon(
                          onPressed: canProcess ? _runUpdateProcess : null,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            _isProcessing ? '処理中...' : 'タグ更新とリネームを実行',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        LinearProgressIndicator(value: _processingProgress),
                        const SizedBox(height: 8),
                        Text(
                          _processingStatus,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  LoadedFilesListWidget(filesNotifier: _loadedFilesNotifier),
                ],
                if (_selectedIdol == null && _idols.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        '↑ まずはアイドルを選択してください',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runUpdateProcess() async {
    final files = _loadedFilesNotifier.value;
    if (files == null || files.isEmpty) return;

    await _pasteFromClipboard(silent: true);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('実行の確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${files.length}個のファイルのタグ更新とリネームを実行します。'),
            const SizedBox(height: 16),
            Text(
              _clipboardArtworkBytes != null
                  ? '埋め込まれるアートワーク (📋 クリップボード)'
                  : '⚠️ クリップボードから画像を読み込めませんでした',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _clipboardArtworkBytes != null
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: _clipboardArtworkBytes != null
                    ? Image.memory(_clipboardArtworkBytes!)
                    : const Center(child: Text('画像なし')),
              ),
            ),
            if (_clipboardArtworkBytes == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '💡 ブラウザでジャケット画像を右クリックして「コピー」した後、もう一度実行ボタンを押してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('実行する'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _errorFiles.clear();
    });

    int successCount = 0;
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      setState(() {
        _processingProgress = i / files.length;
        _processingStatus =
            '${file['name']} を処理中... (${i + 1}/${files.length})';
      });

      // UIを更新させるために次のティックまで待機
      await Future.delayed(const Duration(milliseconds: 10));

      try {
        final handle = file['handle'];
        final newName = file['newName'] as String;
        final html.File originalFile = file['file'];

        if (handle == null || _selectedIdol == null) continue;

        final int index = files.indexOf(file);
        if (index >= _songKeys.length) continue;

        final String songKey = _songKeys[index];
        final Map<String, dynamic> songData = _songs[index][songKey];

        final String idolName = _selectedIdol['name'];
        final String idolCv = _selectedIdol['cv'];
        final String artist = "$idolName(CV: $idolCv)";
        final String album = "${songData['Album']} $idolName";

        final Map<String, dynamic> metadata = {
          ...songData,
          'Artist': artist,
          'Album': album,
          'Title': songData['Title'] ?? songKey,
        };

        final reader = html.FileReader();
        reader.readAsArrayBuffer(originalFile);
        await reader.onLoadEnd.first;
        final Uint8List bytes = reader.result as Uint8List;

        // アートワークはクリップボードから取得できたもののみを使用
        final Uint8List? artworkBytes = _clipboardArtworkBytes;

        final String ext = (originalFile.name.split('.').last).toLowerCase();

        // 処理の合間に制御を返す
        await Future.delayed(Duration.zero);

        // Blob用のチャンク（パーツ）を取得
        final dynamic updatedContent = await FileProcessor.process(
          bytes,
          ext,
          metadata,
          artworkBytes: artworkBytes,
        );

        try {
          await js_util.promiseToFuture(
            js_util.callMethod(handle, 'move', [newName]),
          );
        } catch (e) {
          debugPrint('Rename via move not supported: $e');
        }

        final writable = await js_util.promiseToFuture(
          js_util.callMethod(handle, 'createWritable', []),
        );

        // 保存開始の前に一旦待機
        await Future.delayed(const Duration(milliseconds: 1));

        // Blobとして書き込むことで、巨大なデータのメモリコピーを回避（ブラウザに任せる）
        final blob = html.Blob(
          updatedContent is List ? updatedContent : [updatedContent],
        );

        await js_util.promiseToFuture(
          js_util.callMethod(writable, 'write', [blob]),
        );

        // 書き込み完了直後に一旦待機
        await Future.delayed(const Duration(milliseconds: 1));

        await js_util.promiseToFuture(
          js_util.callMethod(writable, 'close', []),
        );

        // 次のファイルに移る前に少し待機
        await Future.delayed(const Duration(milliseconds: 5));

        successCount++;
      } catch (e) {
        debugPrint('Error processing ${file['name']}: $e');
        _errorFiles.add("${file['name']}: $e");
      }
    }

    setState(() {
      _isProcessing = false;
      _processingProgress = 1.0;
      _processingStatus = '処理完了';
    });

    // 読み込んだファイルをリセット
    _loadedFilesNotifier.value = null;

    // 終了サマリーダイアログ
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('処理完了'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('成功: $successCount ファイル'),
              Text('失敗: ${_errorFiles.length} ファイル'),
              if (_errorFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'エラー詳細:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ..._errorFiles.map(
                  (err) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $err', style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard({bool silent = false}) async {
    try {
      final clipboard = js_util.getProperty(html.window.navigator, 'clipboard');
      if (clipboard == null) throw 'Clipboard API not available';

      final List<dynamic> items = await js_util.promiseToFuture(
        js_util.callMethod(clipboard, 'read', []),
      );

      for (var item in items) {
        final List<String> types = (js_util.getProperty(item, 'types') as List)
            .cast<String>();
        for (var type in types) {
          if (type.startsWith('image/')) {
            final html.Blob blob = await js_util.promiseToFuture(
              js_util.callMethod(item, 'getType', [type]),
            );
            final reader = html.FileReader();
            reader.readAsArrayBuffer(blob);
            await reader.onLoadEnd.first;

            setState(() {
              _clipboardArtworkBytes = reader.result as Uint8List;
            });

            if (!silent) {
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('クリップボードから画像を取得しました')),
              );
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Clipboard error: $e');
    }
  }
}

class LoadedFilesListWidget extends StatelessWidget {
  final ValueNotifier<List<Map<String, dynamic>>?> filesNotifier;

  const LoadedFilesListWidget({super.key, required this.filesNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>?>(
      valueListenable: filesNotifier,
      builder: (context, files, child) {
        if (files == null || files.isEmpty) {
          return Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '現在読み込まれているファイルはありません。\n上の「フォルダを選択」ボタンから\nローカルフォルダを指定してください。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5, color: Colors.black87),
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: 370,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Original Filename (${files.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      flex: 1,
                      child: Text(
                        'New Filename (Preview)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final String originalName = file['name'] as String;
                    final String newName =
                        (file['newName'] ?? originalName) as String;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  originalName,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Text(
                              newName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: originalName != newName
                                    ? Colors.green[700]
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UpdatableImageWidget extends StatefulWidget {
  final ValueNotifier<String?> imageUrlNotifier;

  const UpdatableImageWidget({super.key, required this.imageUrlNotifier});

  @override
  State<UpdatableImageWidget> createState() => _UpdatableImageWidgetState();
}

class _UpdatableImageWidgetState extends State<UpdatableImageWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.imageUrlNotifier,
      builder: (context, imageUrl, child) {
        if (imageUrl == null || imageUrl.isEmpty) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: Text('No Image')),
          );
        }

        final String viewId = 'img-${imageUrl.hashCode}';

        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
          final img = html.ImageElement()
            ..src = imageUrl
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover';
          return img;
        });

        return SizedBox(
          width: 200,
          height: 200,
          child: HtmlElementView(viewType: viewId),
        );
      },
    );
  }
}

class FileProcessor {
  // Webでのメモリ負荷軽減のため、Uint8Listのリスト（チャンク）を返す
  static Future<dynamic> process(
    Uint8List bytes,
    String extension,
    Map<String, dynamic> metadata, {
    Uint8List? artworkBytes,
  }) async {
    switch (extension) {
      case 'mp3':
        return await _processMp3(bytes, metadata, artworkBytes: artworkBytes);
      case 'wav':
        return await _processWav(bytes, metadata, artworkBytes: artworkBytes);
      case 'flac':
        return await _processFlac(bytes, metadata, artworkBytes: artworkBytes);
      default:
        return [bytes];
    }
  }

  static Future<List<dynamic>> _processMp3(
    Uint8List bytes,
    Map<String, dynamic> metadata, {
    Uint8List? artworkBytes,
  }) async {
    debugPrint('Processing MP3 with metadata: $metadata');
    final tag = _createId3v23Tag(metadata, artworkBytes);

    int offset = 0;
    if (bytes.length > 10 &&
        String.fromCharCodes(bytes.sublist(0, 3)) == 'ID3') {
      final int size =
          (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
      offset = 10 + size;
    }

    return [tag, bytes.sublist(offset)];
  }

  static Future<List<dynamic>> _processWav(
    Uint8List bytes,
    Map<String, dynamic> metadata, {
    Uint8List? artworkBytes,
  }) async {
    debugPrint('Processing WAV with metadata: $metadata');
    if (bytes.length < 12 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') {
      return [bytes];
    }

    final List<dynamic> resultChunks = [];
    resultChunks.add(utf8.encode("RIFF"));
    resultChunks.add(Uint8List(4)); // Placeholder for total size
    resultChunks.add(utf8.encode("WAVE"));

    final id3Tag = _createId3v23Tag(metadata, artworkBytes);
    resultChunks.add(utf8.encode("id3 "));
    final int id3Size = id3Tag.length;
    final id3Header = Uint8List(4);
    id3Header[0] = id3Size & 0xFF;
    id3Header[1] = (id3Size >> 8) & 0xFF;
    id3Header[2] = (id3Size >> 16) & 0xFF;
    id3Header[3] = (id3Size >> 24) & 0xFF;
    resultChunks.add(id3Header);
    resultChunks.add(id3Tag);
    if (id3Size % 2 != 0) resultChunks.add(Uint8List(1));

    int offset = 12;
    int totalSize = 4; // "WAVE"
    totalSize += 8 + id3Size + (id3Size % 2);

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final int chunkSize =
          bytes[offset + 4] |
          (bytes[offset + 5] << 8) |
          (bytes[offset + 6] << 16) |
          (bytes[offset + 7] << 24);

      // Skip original id3 chunk for replacement
      if (chunkId.toLowerCase() != "id3 " && chunkId.toLowerCase() != "tag ") {
        final int fullChunkSize = 8 + chunkSize + (chunkSize % 2);
        if (offset + fullChunkSize <= bytes.length) {
          resultChunks.add(bytes.sublist(offset, offset + fullChunkSize));
          totalSize += fullChunkSize;
        }
      }
      offset += 8 + chunkSize + (chunkSize % 2);
    }

    final riffSizeBuf = Uint8List(4);
    riffSizeBuf[0] = totalSize & 0xFF;
    riffSizeBuf[1] = (totalSize >> 8) & 0xFF;
    riffSizeBuf[2] = (totalSize >> 16) & 0xFF;
    riffSizeBuf[3] = (totalSize >> 24) & 0xFF;
    resultChunks[1] = riffSizeBuf;

    return resultChunks;
  }

  static Uint8List _createId3v23Tag(
    Map<String, dynamic> metadata,
    Uint8List? artworkBytes,
  ) {
    final List<int> frames = [];

    void addTextFrame(String id, String value) {
      if (value.isEmpty) return;
      final content = [0x01, ..._encodeUtf16(value)];
      frames.addAll(utf8.encode(id));
      _addInt32BE(frames, content.length);
      frames.addAll([0, 0]);
      frames.addAll(content);
    }

    addTextFrame("TIT2", metadata['Title'] ?? '');
    addTextFrame("TPE1", metadata['Artist'] ?? '');
    addTextFrame("TALB", metadata['Album'] ?? '');
    addTextFrame("TYER", metadata['Year'] ?? '');
    addTextFrame("TRCK", metadata['Track'] ?? '');
    addTextFrame("TCON", metadata['Genre'] ?? '');
    addTextFrame("TCOM", metadata['Composer'] ?? '');
    addTextFrame("TEXT", metadata['Lyricist'] ?? '');

    if (artworkBytes != null) {
      final mime = utf8.encode("image/jpeg");
      final content = [
        0x00, // ISO-8859-1 for mime
        ...mime,
        0x00,
        0x03, // Cover
        0x00, // Description empty
        ...artworkBytes,
      ];
      frames.addAll(utf8.encode("APIC"));
      _addInt32BE(frames, content.length);
      frames.addAll([0, 0]);
      frames.addAll(content);
    }

    final List<int> header = [...utf8.encode("ID3")];
    header.addAll([0x03, 0x00, 0x00]);
    _addSyncsafeInt32(header, frames.length);

    return Uint8List.fromList([...header, ...frames]);
  }

  static List<int> _encodeUtf16(String text) {
    final List<int> result = [0xFF, 0xFE]; // LE BOM
    for (var char in text.runes) {
      result.add(char & 0xFF);
      result.add((char >> 8) & 0xFF);
    }
    return result;
  }

  static void _addSyncsafeInt32(List<int> list, int value) {
    list.add((value >> 21) & 0x7F);
    list.add((value >> 14) & 0x7F);
    list.add((value >> 7) & 0x7F);
    list.add(value & 0x7F);
  }

  static Future<List<dynamic>> _processFlac(
    Uint8List bytes,
    Map<String, dynamic> metadata, {
    Uint8List? artworkBytes,
  }) async {
    if (bytes.length < 4 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'fLaC') {
      debugPrint('Not a valid FLAC file');
      return [bytes];
    }

    final List<dynamic> chunks = [];
    final List<int> vorbisContent = [];

    final vendor = "Reference libFLAC 1.3.2 20170101";
    final vendorBytes = utf8.encode(vendor);
    _addInt32LE(vorbisContent, vendorBytes.length);
    vorbisContent.addAll(vendorBytes);

    final Map<String, String> tags = {
      'TITLE': metadata['Title'] ?? '',
      'ARTIST': metadata['Artist'] ?? '',
      'ALBUM': metadata['Album'] ?? '',
      'DATE': metadata['Year'] ?? '',
      'TRACKNUMBER': metadata['Track'] ?? '',
      'GENRE': metadata['Genre'] ?? '',
      'COMPOSER': metadata['Composer'] ?? '',
      'LYRICIST': metadata['Lyricist'] ?? '',
    };

    final validTags = tags.entries.where((e) => e.value.isNotEmpty).toList();
    _addInt32LE(vorbisContent, validTags.length);

    for (var tag in validTags) {
      final comment = "${tag.key}=${tag.value}";
      final commentBytes = utf8.encode(comment);
      _addInt32LE(vorbisContent, commentBytes.length);
      vorbisContent.addAll(commentBytes);
    }

    chunks.add(bytes.sublist(0, 4)); // fLaC signature

    int offset = 4;
    while (offset + 4 <= bytes.length) {
      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final type = header & 0x7F;
      final size =
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];

      if (type != 4 && type != 6) {
        final List<int> block = bytes
            .sublist(offset, offset + 4 + size)
            .toList();
        block[0] &= 0x7F;
        chunks.add(Uint8List.fromList(block));
      }

      await Future.delayed(Duration.zero);

      offset += 4 + size;
      if (isLast) break;
    }

    if (artworkBytes != null) {
      final List<int> picContent = [];
      _addInt32BE(picContent, 3);
      final mime = "image/jpeg";
      final mimeBytes = utf8.encode(mime);
      _addInt32BE(picContent, mimeBytes.length);
      picContent.addAll(mimeBytes);
      _addInt32BE(picContent, 0);
      _addInt32BE(picContent, 0);
      _addInt32BE(picContent, 0);
      _addInt32BE(picContent, 0);
      _addInt32BE(picContent, 0);
      _addInt32BE(picContent, artworkBytes.length);
      picContent.addAll(artworkBytes);

      final int pSize = picContent.length;
      final picHeader = Uint8List(4);
      picHeader[0] = 6; // Type 6: PICTURE
      picHeader[1] = (pSize >> 16) & 0xFF;
      picHeader[2] = (pSize >> 8) & 0xFF;
      picHeader[3] = pSize & 0xFF;
      chunks.add(picHeader);
      chunks.add(Uint8List.fromList(picContent));
    }

    final int vSize = vorbisContent.length;
    final vorbisHeader = Uint8List(4);
    vorbisHeader[0] = 4; // Type 4: VORBIS_COMMENT
    vorbisHeader[1] = (vSize >> 16) & 0xFF;
    vorbisHeader[2] = (vSize >> 8) & 0xFF;
    vorbisHeader[3] = vSize & 0xFF;

    final int vorbisHeaderIdx = chunks.length;
    chunks.add(vorbisHeader);
    chunks.add(Uint8List.fromList(vorbisContent));

    // 常に最後に追加したヘッダー（ここではVorbisComment）に最後尾フラグを立てる
    (chunks[vorbisHeaderIdx] as Uint8List)[0] |= 0x80;

    await Future.delayed(Duration.zero);

    if (offset < bytes.length) {
      chunks.add(bytes.buffer.asUint8List(bytes.offsetInBytes + offset));
    }

    return chunks;
  }

  static void _addInt32LE(List<int> list, int value) {
    list.add(value & 0xFF);
    list.add((value >> 8) & 0xFF);
    list.add((value >> 16) & 0xFF);
    list.add((value >> 24) & 0xFF);
  }

  static void _addInt32BE(List<int> list, int value) {
    list.add((value >> 24) & 0xFF);
    list.add((value >> 16) & 0xFF);
    list.add((value >> 8) & 0xFF);
    list.add(value & 0xFF);
  }
}

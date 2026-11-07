import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/file_export_service.dart';
import '../services/pdf_tools_service.dart';
import '../widgets/glass_ui.dart';

enum PdfStudioTab { merge, split, images }

class PdfStudioScreen extends StatefulWidget {
  const PdfStudioScreen({super.key, this.initialTab = PdfStudioTab.merge});

  final PdfStudioTab initialTab;

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _mergePaths = [];
  String? _splitSourcePath;
  int _splitPageCount = 1;
  final List<String> _imagePaths = [];

  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickPdfs({required bool multi}) async {
    if (multi) {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (files.isEmpty) return;
      final paths = files.map((f) => f.path).whereType<String>().toList();
      setState(() => _mergePaths.addAll(paths));
      return;
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file?.path == null) return;
    setState(() => _splitSourcePath = file!.path);
  }

  Future<void> _pickImages() async {
    final picks = await _imagePicker.pickMultiImage(imageQuality: 92);
    if (picks.isEmpty) return;
    setState(() => _imagePaths.addAll(picks.map((e) => e.path)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = 'Working…';
    });
    try {
      await action();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF8A3D);

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Document studio',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FrostedPanel(
                blur: 14,
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: 0.25),
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  tabs: const [
                    Tab(text: 'Merge'),
                    Tab(text: 'Split'),
                    Tab(text: 'Scan PDF'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _mergeTab(accent),
                  _splitTab(accent),
                  _imagesTab(accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mergeTab(Color accent) {
    return _tabScaffold(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPrimaryButton(
            accent: accent,
            icon: Icons.upload_file_rounded,
            label: 'Add PDFs',
            onPressed: _busy ? null : () => _pickPdfs(multi: true),
          ),
          const SizedBox(height: 12),
          Expanded(child: _pathList(_mergePaths, onRemove: (i) => setState(() => _mergePaths.removeAt(i)))),
          GlassPrimaryButton(
            accent: accent,
            icon: Icons.merge_type_rounded,
            label: 'Merge PDFs',
            busy: _busy,
            onPressed: _busy || _mergePaths.length < 2
                ? null
                : () => _run(() async {
                      final out = await PdfToolsService.mergePdfs(_mergePaths);
                      setState(() => _status = 'Saved: ${PdfToolsService.basename(out)}');
                      await FileExportService.shareFile(out, text: 'Merged PDF');
                    }),
          ),
        ],
      ),
    );
  }

  Widget _splitTab(Color accent) {
    return _tabScaffold(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPrimaryButton(
            accent: accent,
            icon: Icons.picture_as_pdf_outlined,
            label: _splitSourcePath == null ? 'Choose PDF' : 'Change PDF',
            onPressed: _busy ? null : () => _pickPdfs(multi: false),
          ),
          if (_splitSourcePath != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                PdfToolsService.basename(_splitSourcePath!),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          Text('Pages per output file', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Slider(
            value: _splitPageCount.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_splitPageCount',
            onChanged: _busy ? null : (v) => setState(() => _splitPageCount = v.round()),
          ),
          const Spacer(),
          GlassPrimaryButton(
            accent: accent,
            icon: Icons.content_cut_rounded,
            label: 'Split PDF',
            busy: _busy,
            onPressed: _busy || _splitSourcePath == null
                ? null
                : () => _run(() async {
                      final outs = await PdfToolsService.splitPdf(
                        sourcePath: _splitSourcePath!,
                        pagesPerFile: _splitPageCount,
                      );
                      setState(() => _status = '${outs.length} file(s) created');
                      await FileExportService.shareFiles(outs, text: 'Split PDFs');
                    }),
          ),
        ],
      ),
    );
  }

  Widget _imagesTab(Color accent) {
    return _tabScaffold(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPrimaryButton(
            accent: accent,
            icon: Icons.collections_outlined,
            label: 'Add photos',
            onPressed: _busy ? null : _pickImages,
          ),
          const SizedBox(height: 12),
          Expanded(child: _pathList(_imagePaths, onRemove: (i) => setState(() => _imagePaths.removeAt(i)))),
          GlassPrimaryButton(
            accent: accent,
            icon: Icons.document_scanner_outlined,
            label: 'Create PDF',
            busy: _busy,
            onPressed: _busy || _imagePaths.isEmpty
                ? null
                : () => _run(() async {
                      final out = await PdfToolsService.imagesToPdf(_imagePaths);
                      setState(() => _status = 'Saved: ${PdfToolsService.basename(out)}');
                      await FileExportService.shareFile(out, text: 'Scan PDF');
                    }),
          ),
        ],
      ),
    );
  }

  Widget _tabScaffold({required Color accent, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FrostedPanel(
                padding: const EdgeInsets.all(12),
                child: Text(_status, style: const TextStyle(fontSize: 13)),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _pathList(List<String> paths, {required void Function(int) onRemove}) {
    if (paths.isEmpty) {
      return Center(
        child: Text(
          'Nothing selected yet',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      itemCount: paths.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        return FrostedPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  PdfToolsService.basename(paths[i]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => onRemove(i),
              ),
            ],
          ),
        );
      },
    );
  }
}

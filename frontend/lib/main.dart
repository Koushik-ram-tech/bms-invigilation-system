// BMS Exam Invigilation System v10 — iOS + Android
// ══════════════════════════════════════════════════════════════
// CHANGES v10:
//  1. Room capacity manager — 5th tab "Rooms" to view/edit CA1/CA2/CA3 capacities
//  2. Student names now auto-fill correctly (USN normalised — works any year)
//  3. Universal USN — 1BM25MC, 1BM26MC, 1BM23MCA, all formats supported
//  4. Smooth animated transitions, better card design, improved typography
//  5. Student list shows detected USN prefix after upload
//  6. Upload page shows detected prefix badge so you know what was parsed
//  7. All v9 features: backup invigilators, FilePicker fix, clash logic, iOS+Android
// ══════════════════════════════════════════════════════════════
//
// HOW TO BUILD APK:
//   1. Set kProdBase to your deployed Railway/Render backend URL
//   2. flutter build apk --release --split-per-abi
//   3. APK → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
//   4. Share via Google Drive link → teachers download & install
//   5. Teachers: Settings → Install unknown apps → enable
//
// HOW TO DEPLOY BACKEND (Railway — free):
//   1. Push backend/ folder to GitHub
//   2. railway.app → New Project → Deploy from GitHub
//   3. Add Procfile: web: uvicorn main:app --host 0.0.0.0 --port $PORT
//   4. Get URL → paste into kProdBase below

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// ── Backend URL ────────────────────────────────────────────────
const kLanIp    = '192.168.1.100'; // Your Mac Wi-Fi IP for real device
const kProdBase = '';              // e.g. 'https://your-app.railway.app'

String get kBase {
  if (kProdBase.isNotEmpty) return kProdBase;
  if (Platform.isIOS)     return 'http://localhost:8000';
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}

// ── Design tokens ──────────────────────────────────────────────
const _navy    = Color(0xFF0F172A);
const _blue    = Color(0xFF2563EB);
const _blueLt  = Color(0xFFDBEAFE);
const _surf    = Color(0xFFF1F5F9);
const _card    = Colors.white;
const _line    = Color(0xFFE2E8F0);
const _mid     = Color(0xFF64748B);
const _hint    = Color(0xFF94A3B8);
const _green   = Color(0xFF16A34A);
const _greenLt = Color(0xFFF0FDF4);
const _greenBd = Color(0xFF86EFAC);
const _amber   = Color(0xFFD97706);
const _amberLt = Color(0xFFFFFBEB);
const _amberBd = Color(0xFFFDE68A);
const _red     = Color(0xFFDC2626);
const _redLt   = Color(0xFFFEF2F2);
const _redBd   = Color(0xFFFCA5A5);
const _teal    = Color(0xFF0D9488);
const _tealLt  = Color(0xFFF0FDFA);
const _pur     = Color(0xFF7C3AED);
const _purLt   = Color(0xFFF5F3FF);
const _scroll  = BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
const _exts    = ['pdf','docx','doc','xlsx','xls','csv'];

// ── App entry ─────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }
  runApp(const BmsApp());
}

class BmsApp extends StatelessWidget {
  const BmsApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'BMS Invigilation',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.light),
      scaffoldBackgroundColor: _surf,
      fontFamily: Platform.isIOS ? '.SF Pro Text' : 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: Platform.isIOS ? '.SF Pro Display' : 'Roboto',
            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: _blue, foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
      )),
      cardTheme: CardThemeData(color: _card, elevation: 0, margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _line))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: _surf,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
    home: const AppShell(),
  );
}

// ══════════════════════════════════════════════════════════════
// APP SHELL — 5 tabs: Upload | Results | Workload | Clashes | Rooms
// ══════════════════════════════════════════════════════════════
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  static const _labels = ['Upload','Results','Workload','Clashes','Rooms'];
  static const _subs   = [
    'Three steps to full allocation',
    'Duty roster & attendance sheets',
    'Faculty workload analytics',
    'Teaching vs exam conflicts',
    'Manage classroom capacities',
  ];

  Future<void> _dl(String endpoint, String filename) async {
    _snack('Preparing $filename…', color: _blue);
    try {
      final resp = await http.get(Uri.parse('$kBase/$endpoint'));
      if (resp.statusCode != 200) { _snack('Export failed (${resp.statusCode})', color: _red); return; }
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(resp.bodyBytes);
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done) _snack('Saved: ${file.path}', color: _green);
    } catch (e) {
      final msg = e.toString();
      _snack('Error: ${msg.length > 60 ? msg.substring(0,60) : msg}', color: _red);
    }
  }

  void _snack(String msg, {Color color = _green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_labels[_tab]),
          Text(_subs[_tab], style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.normal)),
        ]),
        flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          if (_tab >= 1)
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 22),
                tooltip: 'Refresh', onPressed: () => setState(() {})),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(_tab), child: _page()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab, backgroundColor: Colors.white,
        indicatorColor: _blueLt, elevation: 8,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.upload_outlined),
              selectedIcon: Icon(Icons.upload_rounded, color: _blue), label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded, color: _blue), label: 'Results'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: _blue), label: 'Workload'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined),
              selectedIcon: Icon(Icons.warning_amber_rounded, color: _blue), label: 'Clashes'),
          NavigationDestination(icon: Icon(Icons.meeting_room_outlined),
              selectedIcon: Icon(Icons.meeting_room_rounded, color: _blue), label: 'Rooms'),
        ],
      ),
    );
  }

  Widget _page() {
    switch (_tab) {
      case 0: return const UploadPage();
      case 1: return ResultsPage(onDl: _dl);
      case 2: return const WorkloadPage();
      case 3: return const ClashPage();
      case 4: return const RoomsPage();
      default: return const UploadPage();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// UPLOAD PAGE
// ══════════════════════════════════════════════════════════════
class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  bool _b1=false, _d1=false; String? _f1;
  Map<String,String> _fMap={}; int _slots=0; String _q1=''; bool _multiBatch=false;
  List<String> _def1=[], _w1=[];

  bool _b2=false, _d2=false; String? _f2;
  int _exCnt=0; List<String> _def2=[], _w2=[];
  Map<String,dynamic>? _alloc;

  bool _b3=false, _d3=false; String? _f3;
  int _studentCnt=0; String _detectedPrefix='';
  List<String> _w3=[];

  Future<PlatformFile?> _pick() async {
    try {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: _exts, withData: true, allowMultiple: false);
      if (r != null && r.files.isNotEmpty) {
        final f = r.files.first;
        if (f.bytes != null && f.bytes!.isNotEmpty) return f;
      }
    } catch (e) { _snack('File picker error: $e', bad: true); }
    return null;
  }

  Future<void> _up1() async {
    final f = await _pick(); if (f == null) return;
    setState(() { _b1=true; _f1=f.name; _d1=false; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$kBase/upload_timetable'))
        ..files.add(http.MultipartFile.fromBytes('file', f.bytes!, filename: f.name));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        final d = _j(resp.body);
        setState(() {
          _d1=true;
          _fMap = (d['faculty_map'] as Map?)?.map((k,v)=>MapEntry('$k','$v')) ?? {};
          _slots = d['busy_slots'] as int? ?? 0;
          _q1 = d['parse_quality'] as String? ?? '';
          _multiBatch = d['multi_batch'] as bool? ?? false;
          _def1 = (d['used_defaults'] as List?)?.cast<String>() ?? [];
          _w1   = (d['warnings']     as List?)?.cast<String>() ?? [];
        });
        _snack('Timetable loaded — ${_fMap.length} faculty detected');
      } else { _snack(_err(resp.body), bad: true); }
    } catch (_) { _snack('Cannot reach backend. Is it running on port 8000?', bad: true); }
    finally { setState(() => _b1=false); }
  }

  Future<void> _up2() async {
    if (!_d1) { _snack('Complete Step 1 first', bad: true); return; }
    final f = await _pick(); if (f == null) return;
    setState(() { _b2=true; _f2=f.name; _d2=false; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$kBase/upload_exam_and_allocate'))
        ..files.add(http.MultipartFile.fromBytes('file', f.bytes!, filename: f.name));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        final d = _j(resp.body);
        setState(() {
          _d2=true;
          _exCnt = d['exams_found'] as int? ?? 0;
          _def2  = (d['used_defaults'] as List?)?.cast<String>() ?? [];
          _w2    = (d['warnings']     as List?)?.cast<String>() ?? [];
          _alloc = d['allocation'] as Map<String,dynamic>?;
        });
        _snack('Done! ${_alloc?["success_count"] ?? 0}/$_exCnt allocated — see Results tab');
      } else { _snack(_err(resp.body), bad: true); }
    } catch (e) { _snack('Connection error: $e', bad: true); }
    finally { setState(() => _b2=false); }
  }

  Future<void> _up3() async {
    final f = await _pick(); if (f == null) return;
    setState(() { _b3=true; _f3=f.name; _d3=false; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$kBase/upload_student_list'))
        ..files.add(http.MultipartFile.fromBytes('file', f.bytes!, filename: f.name));
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        final d = _j(resp.body);
        setState(() {
          _d3=true;
          _studentCnt     = d['students_loaded']   as int?    ?? 0;
          _detectedPrefix = d['detected_prefix']   as String? ?? '';
          _w3 = (d['warnings'] as List?)?.cast<String>() ?? [];
        });
        _snack('$_studentCnt students loaded${_detectedPrefix.isNotEmpty ? " (prefix: $_detectedPrefix)" : ""}');
      } else { _snack(_err(resp.body), bad: true); }
    } catch (e) { _snack('Connection error: $e', bad: true); }
    finally { setState(() => _b3=false); }
  }

  Map<String,dynamic> _j(String b) { try { return jsonDecode(b); } catch(_) { return {}; } }
  String _err(String b) { try { return (_j(b)['detail'] as String?) ?? 'Error'; } catch(_) { return b.length > 80 ? b.substring(0,80) : b; } }

  void _snack(String m, {bool bad=false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: bad ? _red : _green, behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(child: ListView(physics: _scroll, padding: const EdgeInsets.fromLTRB(16,16,16,40), children: [
      const _HeroCard(),
      const SizedBox(height:20),

      // Step 1
      _StepHeader(n: 1, title: 'Faculty Timetable', done: _d1),
      const SizedBox(height:4),
      const _SubText('PDF · DOCX · XLSX · CSV  |  Faculty codes auto-detected'),
      const SizedBox(height:10),
      _UpCard(file:_f1, busy:_b1, done:_d1, label:'Select Timetable File', onTap:_up1),
      if (_d1) ...[
        const SizedBox(height:10),
        _FacCard(map:_fMap, slots:_slots, q:_q1),
        const SizedBox(height:8),
        _Ntc(_multiBatch ? Icons.groups_rounded : Icons.info_outline_rounded,
            _multiBatch ? _pur : _teal,
            _multiBatch ? _purLt : _tealLt,
            _multiBatch ? _pur.withOpacity(0.3) : _teal.withOpacity(0.3),
            _multiBatch ? 'Multi-batch — clash detection ON' : 'Single batch — clash detection OFF',
            _multiBatch ? 'Faculty with classes during exam time will be auto-excluded.'
                : 'No other batches active. Clash detection activates when juniors join.'),
      ],
      ..._notices(_def1, _w1),
      const SizedBox(height:24),

      // Step 2
      _StepHeader(n: 2, title: 'Exam Schedule', done: _d2),
      const SizedBox(height:4),
      const _SubText('CIE 1 · CIE 2 · End Sem  |  Allocation runs instantly after upload'),
      const SizedBox(height:10),
      _UpCard(file:_f2, busy:_b2, done:_d2,
          label: _d1 ? 'Select Exam File → Allocate' : 'Complete Step 1 First',
          onTap: _d1 ? _up2 : null),
      if (_d2) ...[
        const SizedBox(height:10),
        _AllocCard(count:_exCnt, alloc:_alloc),
      ],
      ..._notices(_def2, _w2),
      const SizedBox(height:24),

      // Step 3
      _StepHeader(n: 3, title: 'Student List', done: _d3),
      const SizedBox(height:4),
      const _SubText('PDF · CSV · XLSX  |  USN + Name → names auto-fill in attendance sheets'),
      const SizedBox(height:10),
      _UpCard(file:_f3, busy:_b3, done:_d3, label:'Select Student List File (Optional)', onTap:_up3),
      if (_d3) ...[
        const SizedBox(height:10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _greenLt, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _greenBd)),
          child: Row(children: [
            const Icon(Icons.people_alt_rounded, color: _green, size: 20),
            const SizedBox(width:10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_studentCnt students loaded ✓',
                  style: const TextStyle(fontWeight:FontWeight.w700, color:_green, fontSize:14)),
              if (_detectedPrefix.isNotEmpty)
                Text('USN prefix: $_detectedPrefix  (e.g. ${_detectedPrefix}001)',
                    style: const TextStyle(fontSize:11, color:_green)),
              const Text('Names will auto-fill in attendance sheets',
                  style: TextStyle(fontSize:11, color:_mid)),
            ])),
          ]),
        ),
      ],
      for (final w in _w3) ...[
        const SizedBox(height:8),
        _Ntc(Icons.warning_amber_rounded, _amber, _amberLt, _amberBd, 'Parse notice', w),
      ],

      if (_d1 && _d2) ...[const SizedBox(height:20), const _GoCard()],
    ]));
  }

  List<Widget> _notices(List<String> defs, List<String> warns) => [
    for (final m in defs) ...[const SizedBox(height:8),
      _Ntc(Icons.info_outline_rounded, _blue, _blueLt, _line, 'Default applied', m)],
    for (final m in warns.where((w) => w.toLowerCase().contains('ocr')))
      ...[const SizedBox(height:8),
        _Ntc(Icons.document_scanner_rounded, _teal, _tealLt, _teal.withOpacity(0.3), 'OCR running…', m)],
    for (final m in warns.where((w) => !w.toLowerCase().contains('ocr')))
      ...[const SizedBox(height:8),
        _Ntc(Icons.warning_amber_rounded, _amber, _amberLt, _amberBd, 'Notice', m)],
  ];
}

// ══════════════════════════════════════════════════════════════
// RESULTS PAGE
// ══════════════════════════════════════════════════════════════
class ResultsPage extends StatefulWidget {
  final Future<void> Function(String,String) onDl;
  const ResultsPage({super.key, required this.onDl});
  @override State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool _loading=true; String? _error; Map<String,dynamic>? _data;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading=true; _error=null; });
    try {
      final r = await http.get(Uri.parse('$kBase/results'));
      if (r.statusCode == 200) setState(() { _data=jsonDecode(r.body); _loading=false; });
      else if (r.statusCode == 400) setState(() { _error='No results yet.\nUpload both files from the Upload tab first.'; _loading=false; });
      else setState(() { _error='Server error (${r.statusCode})'; _loading=false; });
    } catch (_) {
      setState(() { _error='Cannot reach backend.\nCheck the server is running on port 8000.'; _loading=false; });
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(), SizedBox(height:16),
      Text('Loading results…', style: TextStyle(color:_mid, fontSize:14)),
    ]));
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.assignment_outlined, size:64, color:_hint), const SizedBox(height:16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize:15, color:_mid, height:1.6)),
          const SizedBox(height:24),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(160,48))),
        ])));

    final results = (_data?['results'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return SafeArea(child: ListView(physics: _scroll, padding: const EdgeInsets.fromLTRB(16,12,16,40), children: [
      // Download cards
      Row(children: [
        Expanded(child: _DlTile(Icons.table_chart_rounded,'Duty Chart','Excel · 3 sheets',_blue,_blueLt,
                () => widget.onDl('export_duty_chart','BMS_Duty_Chart.xlsx'))),
        const SizedBox(width:10),
        Expanded(child: _DlTile(Icons.how_to_reg_rounded,'Attendance','Per room · Names filled',_green,_greenLt,
                () => widget.onDl('export_attendance_sheets','BMS_Attendance.xlsx'))),
      ]),
      const SizedBox(height:14),
      Row(children: [
        _StatChip('Total',  '${_data!['total']          ?? 0}', _blue),
        const SizedBox(width:8),
        _StatChip('Done',   '${_data!['success_count']  ?? 0}', _green),
        const SizedBox(width:8),
        _StatChip('Failed', '${_data!['fail_count']     ?? 0}', _red),
      ]),
      const SizedBox(height:14),
      if (results.isEmpty) const _EmptyState('No results found.')
      else for (final r in results) _ExCard(data: r),
    ]));
  }
}

class _DlTile extends StatelessWidget {
  final IconData icon; final String title, sub; final Color color, bg; final VoidCallback onTap;
  const _DlTile(this.icon, this.title, this.sub, this.color, this.bg, this.onTap);
  @override Widget build(BuildContext context) => Material(color: bg, borderRadius: BorderRadius.circular(14),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
          child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 20)),
                  const Spacer(),
                  Icon(Icons.download_rounded, color: color, size: 16),
                ]),
                const SizedBox(height:10),
                Text(title, style: TextStyle(fontWeight:FontWeight.w700, fontSize:13, color:color)),
                Text(sub,   style: TextStyle(fontSize:10, color:color.withOpacity(0.75))),
              ]))));
}

class _ExCard extends StatefulWidget {
  final Map<String,dynamic> data; const _ExCard({required this.data});
  @override State<_ExCard> createState() => _ExCardState();
}
class _ExCardState extends State<_ExCard> {
  bool _exp = false;
  @override Widget build(BuildContext context) {
    final ok      = widget.data['success'] as bool? ?? false;
    final asn     = (widget.data['assignments'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    final excl    = (widget.data['excluded']    as List?)?.cast<Map<String,dynamic>>() ?? [];
    final backups = (widget.data['backups']      as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Padding(padding: const EdgeInsets.only(bottom:10), child: Column(children: [
      GestureDetector(onTap: () => setState(() => _exp = !_exp),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ok ? _greenLt : _redLt, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ok ? _greenBd : _redBd, width: 1.2),
          ),
          child: Row(children: [
            Container(width:32, height:32,
                decoration: BoxDecoration(color: ok ? _green : _red, shape: BoxShape.circle),
                child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color:Colors.white, size:16)),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.data['subject'] ?? '', style: const TextStyle(fontWeight:FontWeight.w700, fontSize:13)),
              Text('${widget.data['exam_date']??''}  •  ${widget.data['start_time']??''}–${widget.data['end_time']??''}',
                  style: const TextStyle(fontSize:11, color:_mid)),
            ])),
            if (ok) ...[
              _Badge('${asn.length} hall${asn.length>1?"s":""}', _green),
              if (backups.isNotEmpty) ...[const SizedBox(width:4), _Badge('${backups.length} backup', _amber)],
            ],
            const SizedBox(width:6),
            Icon(_exp ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color:_mid, size:20),
          ]),
        ),
      ),
      if (_exp) Container(margin: const EdgeInsets.only(top:2),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
        child: ok
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final a in asn) _ARow(data: a),
          if (backups.isNotEmpty) _BackupPanel(backups: backups),
        ])
            : Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.error_outline_rounded, color:_red, size:16), const SizedBox(width:6),
            Expanded(child: Text(widget.data['error']??'Failed', style: const TextStyle(color:_red, fontSize:13)))]),
          if (excl.isNotEmpty) ...[const SizedBox(height:10),
            const Text('Excluded:', style: TextStyle(fontSize:12, fontWeight:FontWeight.w700, color:_mid)),
            for (final e in excl.take(4)) Text('  • ${e['name']} — ${e['reason']}',
                style: const TextStyle(fontSize:11, color:_mid))],
        ])),
      ),
    ]));
  }
}

class _Badge extends StatelessWidget {
  final String t; final Color c; const _Badge(this.t, this.c);
  @override Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal:8, vertical:3),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: TextStyle(color:c, fontSize:10, fontWeight:FontWeight.w700)));
}

class _BackupPanel extends StatelessWidget {
  final List<Map<String,dynamic>> backups; const _BackupPanel({required this.backups});
  @override Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(12,0,12,12),
      decoration: BoxDecoration(color: _amberLt, borderRadius: BorderRadius.circular(12), border: Border.all(color: _amberBd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
            decoration: BoxDecoration(color: _amber.withOpacity(0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
            Flexible(child: const Row(children: [
              Icon(Icons.swap_horiz_rounded, color:_amber, size:15), SizedBox(width:6),
              Text('Backup Invigilators — activate if primary absent',
                  style: TextStyle(fontWeight:FontWeight.w700, fontSize:12, color:_amber)),
            ]))),
        for (int i=0; i<backups.length; i++) _BackupRow(index: i+1, data: backups[i]),
      ]));
}

class _BackupRow extends StatelessWidget {
  final int index; final Map<String,dynamic> data; const _BackupRow({required this.index, required this.data});
  @override Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal:12, vertical:10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _amberBd))),
      child: Row(children: [
        Container(width:24, height:24, decoration: const BoxDecoration(color:_amber, shape:BoxShape.circle),
            child: Center(child: Text('$index', style: const TextStyle(color:Colors.white, fontSize:11, fontWeight:FontWeight.w800)))),
        const SizedBox(width:10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['faculty_name']??'-', style: const TextStyle(fontWeight:FontWeight.w700, fontSize:13, color:_navy)),
          Text('${data['faculty_code']??'-'}  •  ${data['current_duties']??0} duties', style: const TextStyle(fontSize:11, color:_mid)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:3),
            decoration: BoxDecoration(color:Colors.white, borderRadius:BorderRadius.circular(8), border:Border.all(color:_amberBd)),
            child: const Text('Standby', style: TextStyle(fontSize:10, color:_amber, fontWeight:FontWeight.w700))),
      ]));
}

class _ARow extends StatelessWidget {
  final Map<String,dynamic> data; const _ARow({required this.data});
  @override Widget build(BuildContext context) {
    final r   = data['reasoning'] as Map<String,dynamic>?;
    final why = (r?['why_selected'] as List?)?.cast<String>() ?? [];
    final chk = (r?['checks_passed'] as List?)?.cast<String>() ?? [];
    return Container(padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color:_line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width:40, height:40,
                decoration: BoxDecoration(gradient: const LinearGradient(colors:[_teal,Color(0xFF0F766E)]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_rounded, color:Colors.white, size:22)),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['faculty_name']??'-', style: const TextStyle(fontWeight:FontWeight.w700, fontSize:14)),
              Text('${data['faculty_code']??''}  •  ${data['students']??'-'} students', style: const TextStyle(fontSize:11, color:_mid)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:6),
                decoration: BoxDecoration(color:_tealLt, borderRadius:BorderRadius.circular(10), border:Border.all(color:_teal.withOpacity(0.3))),
                child: Text(data['hall']??'-', style: const TextStyle(color:_teal, fontSize:13, fontWeight:FontWeight.w700))),
          ]),
          if (r != null) ...[
            const SizedBox(height:10),
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _blue.withOpacity(0.15))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal:7, vertical:3),
                        decoration: BoxDecoration(color:_blue, borderRadius:BorderRadius.circular(6)),
                        child: const Row(children: [
                          Icon(Icons.psychology_alt_rounded, size:10, color:Colors.white), SizedBox(width:3),
                          Text('Reasoning Engine', style: TextStyle(fontSize:9, fontWeight:FontWeight.w700, color:Colors.white)),
                        ])),
                    const Spacer(),
                    Text('Score: ${r['score']??'—'}', style: const TextStyle(fontSize:10, color:_mid)),
                  ]),
                  const SizedBox(height:8),
                  for (final w in why) _RL(w, _green, Icons.thumb_up_alt_rounded),
                  for (final c in chk.take(2)) _RL(c, _blue, Icons.verified_rounded),
                  if (r['summary'] != null) ...[const SizedBox(height:4),
                    Text(r['summary'] as String, style: const TextStyle(fontSize:10, color:_hint, fontStyle:FontStyle.italic))],
                ])),
          ],
          if (((data['usn_range'] as String?) ?? '').isNotEmpty) ...[
            const SizedBox(height:6),
            Row(children: [const Icon(Icons.badge_outlined, size:12, color:_hint), const SizedBox(width:4),
              Expanded(child: Text(data['usn_range']??'', style: const TextStyle(fontSize:10, color:_hint), overflow:TextOverflow.ellipsis))]),
          ],
        ]));
  }
}

class _RL extends StatelessWidget {
  final String t; final Color c; final IconData i; const _RL(this.t, this.c, this.i);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom:2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(i, size:11, color:c), const SizedBox(width:4),
        Expanded(child: Text(t, style: TextStyle(fontSize:11, color:c))),
      ]));
}

// ══════════════════════════════════════════════════════════════
// WORKLOAD PAGE
// ══════════════════════════════════════════════════════════════
class WorkloadPage extends StatefulWidget {
  const WorkloadPage({super.key});
  @override State<WorkloadPage> createState() => _WorkloadPageState();
}
class _WorkloadPageState extends State<WorkloadPage> {
  bool _loading=true;
  List<Map<String,dynamic>> _fac=[]; double _mean=0; Map<String,dynamic>? _intel;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading=true);
    try {
      final w  = await http.get(Uri.parse('$kBase/workload'));
      final si = await http.get(Uri.parse('$kBase/semester_intelligence'));
      if (w.statusCode == 200) {
        final d = jsonDecode(w.body) as Map<String,dynamic>;
        setState(() { _fac=(d['faculty'] as List?)?.cast<Map<String,dynamic>>()??[]; _mean=(d['mean_duties'] as num?)?.toDouble()??0; });
      }
      if (si.statusCode == 200) setState(() => _intel=jsonDecode(si.body));
    } catch(_) {}
    setState(() => _loading=false);
  }
  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_fac.isEmpty) return const _EmptyState('No workload data.\nRun allocation from Upload tab.');
    return SafeArea(child: ListView(physics:_scroll, padding: const EdgeInsets.fromLTRB(16,12,16,40), children: [
      Row(children: [
        _StatChip('Duties', '${_fac.fold(0,(s,f)=>s+((f['duties'] as int?)??0))}', _blue),
        const SizedBox(width:8), _StatChip('Faculty','${_fac.length}', _pur),
        const SizedBox(width:8), _StatChip('Avg', _mean.toStringAsFixed(1), _teal),
      ]),
      const SizedBox(height:20),
      const _SL('Duty Distribution'), const SizedBox(height:4),
      const _SubText('Red = above avg  |  Amber = no duties'), const SizedBox(height:10),
      Card(child: Padding(padding: const EdgeInsets.fromLTRB(16,16,8,16),
          child: SizedBox(height:200, child: CustomPaint(size: const Size(double.infinity,200), painter: BarP(faculty:_fac, mean:_mean))))),
      const SizedBox(height:20),
      const _SL('Faculty Load'), const SizedBox(height:8),
      for (final f in _fac)
        Padding(padding: const EdgeInsets.only(bottom:8), child: _FLT(data:f, mean:_mean)),
      if (_intel?['available']==true) ...[const SizedBox(height:20), const _SL('Semester Intelligence'), const SizedBox(height:8), _IC(data:_intel!)],
    ]));
  }
}

class _FLT extends StatelessWidget {
  final Map<String,dynamic> data; final double mean; const _FLT({required this.data, required this.mean});
  @override Widget build(BuildContext context) {
    final d=((data['duties'] as int?)??0).toDouble();
    final high=mean>0&&d>mean*1.2; final zero=d==0;
    final pct=mean>0?(d/(mean*2.5)).clamp(0.0,1.0):0.0;
    final bc=high?_red:zero?_amber:_blue;
    return AnimatedContainer(duration: const Duration(milliseconds:300),
        padding: const EdgeInsets.symmetric(horizontal:14, vertical:12),
        decoration: BoxDecoration(color: high?_redLt:zero?_amberLt:_card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: high?_redBd:zero?_amberBd:_line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(data['name'] as String? ??'-', style: const TextStyle(fontWeight:FontWeight.w600, fontSize:13))),
            Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:4),
                decoration: BoxDecoration(color:bc, borderRadius:BorderRadius.circular(12)),
                child: Text('${d.toInt()} duties', style: const TextStyle(color:Colors.white, fontSize:11, fontWeight:FontWeight.w700))),
          ]),
          const SizedBox(height:8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value:pct, minHeight:5, backgroundColor:Colors.grey.shade200, valueColor:AlwaysStoppedAnimation(bc))),
          if (zero) ...[const SizedBox(height:3), const Text('No duties this season', style: TextStyle(fontSize:10, color:_amber))],
        ]));
  }
}

class _IC extends StatelessWidget {
  final Map<String,dynamic> data; const _IC({required this.data});
  @override Widget build(BuildContext context) {
    final never=(data['zero_duty_faculty'] as List?)?.cast<String>()??[];
    final top=(data['top_invigilators'] as List?)?.cast<Map<String,dynamic>>()??[];
    return Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFF4C1D95),Color(0xFF6D28D9)],
            begin:Alignment.topLeft,end:Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children:[Icon(Icons.insights_rounded,color:Colors.white,size:18),SizedBox(width:8),
            Text('Semester Intelligence',style:TextStyle(fontWeight:FontWeight.w700,fontSize:15,color:Colors.white))]),
          const SizedBox(height:14),
          _IR2('Total duties','${data['total_duties']}'), _IR2('Exams covered','${data['total_exams']}'),
          _IR2('Mean per faculty','${data['mean_duties']}'), _IR2('Busiest day','${data['busiest_day']}'),
          const SizedBox(height:10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color:Colors.white.withOpacity(0.15),borderRadius:BorderRadius.circular(10)),
              child: Text(data['suggestion'] as String??'', style: const TextStyle(fontSize:12,color:Colors.white))),
          if (never.isNotEmpty)...[const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:_amberLt,borderRadius:BorderRadius.circular(10)),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${never.length} with 0 duties:',style:const TextStyle(fontWeight:FontWeight.w700,color:_amber,fontSize:12)),
                  for(final n in never) Text('• $n',style:const TextStyle(fontSize:11,color:_navy))]))],
          if (top.isNotEmpty)...[const SizedBox(height:10),
            const Text('Top invigilators:',style:TextStyle(fontWeight:FontWeight.w600,fontSize:12,color:Colors.white70)),
            for(final t in top) Text('• ${t['name']} — ${t['duties']}',style:const TextStyle(fontSize:12,color:Colors.white))],
        ]));
  }
}
class _IR2 extends StatelessWidget {
  final String l,v; const _IR2(this.l,this.v);
  @override Widget build(BuildContext context) => Padding(padding:const EdgeInsets.symmetric(vertical:2),
      child:Row(children:[Expanded(child:Text(l,style:const TextStyle(fontSize:12,color:Colors.white70))),
        Text(v,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Colors.white))]));
}

// ══════════════════════════════════════════════════════════════
// CLASH PAGE
// ══════════════════════════════════════════════════════════════
class ClashPage extends StatefulWidget { const ClashPage({super.key}); @override State<ClashPage> createState() => _ClashPageState(); }
class _ClashPageState extends State<ClashPage> {
  bool _loading=false, _ran=false; List<Map<String,dynamic>> _items=[]; String _note='';
  Future<void> _check() async {
    setState(() { _loading=true; _items=[]; _note=''; });
    try {
      final r=await http.get(Uri.parse('$kBase/clashes'));
      if (r.statusCode==200) {
        final d=jsonDecode(r.body) as Map<String,dynamic>;
        setState(() { _items=(d['clashes'] as List?)?.cast<Map<String,dynamic>>()??[]; _note=d['note'] as String?? ''; _ran=true; });
      }
    } catch(_) {}
    setState(() => _loading=false);
  }
  @override Widget build(BuildContext context) => SafeArea(child: ListView(physics:_scroll,
      padding: const EdgeInsets.fromLTRB(16,16,16,40), children: [
        _Ntc(Icons.info_outline_rounded,_blue,_blueLt,_line,'About clash detection',
            'Faculty with classes at exam time are auto-excluded from invigilator assignment. '
                'Only active when multiple batches are in the timetable.'),
        const SizedBox(height:16),
        ElevatedButton.icon(onPressed:_loading?null:_check,
            icon:_loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.radar_rounded),
            label:Text(_loading?'Scanning…':'Detect Clashes')),
        const SizedBox(height:20),
        if (_ran)...[
          if (_note.isNotEmpty) _Ntc(Icons.info_outline_rounded,_teal,_tealLt,_teal.withOpacity(0.3),'Single-batch timetable',_note),
          if (_note.isEmpty&&_items.isEmpty) _Ntc(Icons.check_circle_rounded,_green,_greenLt,_greenBd,'No clashes','All faculty are free during exam slots.'),
          if (_items.isNotEmpty)...[
            _Ntc(Icons.warning_rounded,_red,_redLt,_redBd,'${_items.length} clash(es) found','Auto-excluded from invigilator assignment.'),
            const SizedBox(height:12),
            for (final c in _items) Padding(padding:const EdgeInsets.only(bottom:10),child:Container(
                padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(color:_amberLt,borderRadius:BorderRadius.circular(14),border:Border.all(color:_amberBd)),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[const Icon(Icons.warning_amber_rounded,color:_amber,size:15),const SizedBox(width:6),
                    Expanded(child:Text('${c['faculty']} (${c['code']})',style:const TextStyle(fontWeight:FontWeight.w700,color:_amber,fontSize:14)))]),
                  const SizedBox(height:5),
                  Text('Exam: ${c['exam_subject']} — ${c['exam_date']}',style:const TextStyle(fontSize:12)),
                  Text('Has class on: ${c['day']}',style:const TextStyle(fontSize:12,color:_mid)),
                  Text('Result: ${c['action']}',style:const TextStyle(fontSize:12,color:_teal,fontWeight:FontWeight.w600)),
                ]))),
          ],
        ],
      ]));
}

// ══════════════════════════════════════════════════════════════
// ROOMS PAGE (NEW v10) — view & edit room capacities
// ══════════════════════════════════════════════════════════════
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});
  @override State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  bool _loading=true, _saving=false;
  List<Map<String,dynamic>> _rooms=[];
  // Controllers for each room's capacity input
  final List<TextEditingController> _ctrls=[];
  String _prefix=''; int _total=0;

  @override void initState() { super.initState(); _load(); }

  @override void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading=true);
    try {
      final r=await http.get(Uri.parse('$kBase/rooms'));
      if (r.statusCode==200) {
        final d=jsonDecode(r.body) as Map<String,dynamic>;
        final rooms=(d['rooms'] as List?)?.cast<Map<String,dynamic>>()??[];
        for (final c in _ctrls) c.dispose(); _ctrls.clear();
        setState(() {
          _rooms=rooms; _prefix=d['detected_prefix'] as String?? ''; _total=d['total_students'] as int? ?? 0;
          for (final r in _rooms) _ctrls.add(TextEditingController(text:'${r['students']??30}'));
        });
      }
    } catch(_) {}
    setState(() => _loading=false);
  }

  Future<void> _addRoom() async {
    final nameCtrl=TextEditingController();
    final capCtrl=TextEditingController(text:'30');
    final confirmed=await showDialog<bool>(context:context, builder:(ctx)=>AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Room', style: TextStyle(fontWeight:FontWeight.w700)),
      content: Column(mainAxisSize:MainAxisSize.min, children:[
        TextField(controller:nameCtrl, decoration: const InputDecoration(labelText:'Room name (e.g. CA4)')),
        const SizedBox(height:12),
        TextField(controller:capCtrl, keyboardType:TextInputType.number, decoration: const InputDecoration(labelText:'Capacity')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false), child:const Text('Cancel')),
        ElevatedButton(onPressed:()=>Navigator.pop(ctx,true), child:const Text('Add'),
            style:ElevatedButton.styleFrom(minimumSize:const Size(80,40))),
      ],
    ));
    nameCtrl.dispose(); capCtrl.dispose();
    if (confirmed==true && nameCtrl.text.trim().isNotEmpty) await _save();
  }

  Future<void> _save() async {
    // Validate all inputs
    for (int i=0; i<_ctrls.length; i++) {
      final v=int.tryParse(_ctrls[i].text.trim());
      if (v==null||v<1||v>200) {
        _snack('${_rooms[i]['room']}: capacity must be 1–200', bad:true); return;
      }
    }
    setState(()=>_saving=true);
    try {
      final payload={'rooms':[for(int i=0;i<_rooms.length;i++) {'room':_rooms[i]['room'],'students':int.parse(_ctrls[i].text.trim())}]};
      final r=await http.post(Uri.parse('$kBase/rooms'),
          headers:{'Content-Type':'application/json'}, body:jsonEncode(payload));
      if (r.statusCode==200) {
        _snack('Room capacities saved ✓');
        await _load();
      } else { _snack('Save failed: ${r.body}', bad:true); }
    } catch(e) { _snack('Connection error: $e', bad:true); }
    finally { setState(()=>_saving=false); }
  }

  Future<void> _removeRoom(int index) async {
    final confirmed=await showDialog<bool>(context:context, builder:(ctx)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      title:const Text('Remove Room', style:TextStyle(fontWeight:FontWeight.w700)),
      content:Text('Remove ${_rooms[index]['room']}?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false), child:const Text('Cancel')),
        ElevatedButton(onPressed:()=>Navigator.pop(ctx,true), child:const Text('Remove'),
            style:ElevatedButton.styleFrom(backgroundColor:_red, minimumSize:const Size(80,40))),
      ],
    ));
    if (confirmed==true) {
      _rooms.removeAt(index); _ctrls[index].dispose(); _ctrls.removeAt(index);
      await _save();
    }
  }

  void _snack(String m, {bool bad=false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(m,style:const TextStyle(fontWeight:FontWeight.w500)),
        backgroundColor:bad?_red:_green, behavior:SnackBarBehavior.floating,
        margin:const EdgeInsets.all(12),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))));
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child:CircularProgressIndicator());
    final totalNow=_ctrls.fold<int>(0,(s,c)=>s+(int.tryParse(c.text)??0));
    return SafeArea(child:ListView(physics:_scroll, padding:const EdgeInsets.fromLTRB(16,16,16,40), children:[
      // Info card
      Container(padding:const EdgeInsets.all(16), decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[Color(0xFF0F172A),Color(0xFF1E3A5F)],begin:Alignment.topLeft,end:Alignment.bottomRight),
          borderRadius:BorderRadius.circular(16)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[Icon(Icons.meeting_room_rounded,color:Colors.white,size:20),SizedBox(width:8),
              Text('Classroom Configuration',style:TextStyle(fontWeight:FontWeight.w700,fontSize:15,color:Colors.white))]),
            const SizedBox(height:8),
            Text('${_rooms.length} rooms  •  $_total students total',style:const TextStyle(fontSize:12,color:Colors.white70)),
            if (_prefix.isNotEmpty)...[const SizedBox(height:4),
              Text('USN prefix: $_prefix (detected from student list)',style:const TextStyle(fontSize:12,color:Colors.white54))],
            const SizedBox(height:4),
            const Text('Changes apply to next allocation. Edit capacity and tap Save.',style:TextStyle(fontSize:11,color:Colors.white54)),
          ])),
      const SizedBox(height:16),

      // Room cards
      for (int i=0; i<_rooms.length; i++) ...[
        _RoomEditCard(
          room: _rooms[i], ctrl: _ctrls[i],
          onRemove: _rooms.length>1 ? ()=>_removeRoom(i) : null,
          prefix: _prefix,
        ),
        const SizedBox(height:10),
      ],

      // Live total
      Container(padding:const EdgeInsets.all(12), decoration:BoxDecoration(
          color:totalNow>0?_blueLt:_redLt, borderRadius:BorderRadius.circular(12), border:Border.all(color:totalNow>0?_blue.withOpacity(0.3):_redBd)),
          child:Row(children:[
            Icon(Icons.people_rounded,color:totalNow>0?_blue:_red,size:18),const SizedBox(width:8),
            Text('Total students: $totalNow',style:TextStyle(fontWeight:FontWeight.w700,fontSize:14,color:totalNow>0?_blue:_red)),
            if (_prefix.isNotEmpty&&totalNow>0)...[const Spacer(),
              Text('${_prefix}001–${_prefix}${totalNow.toString().padLeft(3,'0')}',style:TextStyle(fontSize:11,color:_blue.withOpacity(0.7)))],
          ])),
      const SizedBox(height:16),

      // Action buttons
      Row(children:[
        Expanded(child:OutlinedButton.icon(
          onPressed:_addRoom,
          icon:const Icon(Icons.add_rounded,size:18),
          label:const Text('Add Room'),
          style:OutlinedButton.styleFrom(foregroundColor:_blue,side:const BorderSide(color:_blue),
              minimumSize:const Size(0,48),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        )),
        const SizedBox(width:10),
        Expanded(child:ElevatedButton.icon(
          onPressed:_saving?null:_save,
          icon:_saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              :const Icon(Icons.save_rounded,size:18),
          label:Text(_saving?'Saving…':'Save Changes'),
          style:ElevatedButton.styleFrom(minimumSize:const Size(0,48),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        )),
      ]),
      const SizedBox(height:16),
      _Ntc(Icons.lightbulb_outline_rounded,_amber,_amberLt,_amberBd,'Tip',
          'After changing room capacities, re-upload the exam schedule (Step 2) to apply the new configuration to allocation.'),
    ]));
  }
}

class _RoomEditCard extends StatelessWidget {
  final Map<String,dynamic> room; final TextEditingController ctrl;
  final VoidCallback? onRemove; final String prefix;
  const _RoomEditCard({required this.room, required this.ctrl, this.onRemove, required this.prefix});
  @override Widget build(BuildContext context) {
    final name=room['room'] as String? ??'';
    final usnStart=room['usn_start'] as String? ??'';
    final usnEnd  =room['usn_end']   as String? ??'';
    return Card(child:Padding(padding:const EdgeInsets.all(16), child:Row(children:[
      // Room name badge
      Container(width:52, height:52,
          decoration:BoxDecoration(color:_blue.withOpacity(0.1),borderRadius:BorderRadius.circular(12),border:Border.all(color:_blue.withOpacity(0.3))),
          child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            const Icon(Icons.meeting_room_rounded,color:_blue,size:18),
            Text(name,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:11,color:_blue)),
          ])),
      const SizedBox(width:14),
      // USN range display
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(name, style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14,color:_navy)),
        if (usnStart.isNotEmpty&&usnEnd.isNotEmpty)
          Text('$usnStart – $usnEnd',style:const TextStyle(fontSize:11,color:_mid))
        else if (prefix.isNotEmpty)
          Text('USN range auto-computed from prefix',style:const TextStyle(fontSize:11,color:_hint)),
      ])),
      const SizedBox(width:12),
      // Capacity field
      SizedBox(width:70, child:TextField(
        controller:ctrl, keyboardType:TextInputType.number,
        textAlign:TextAlign.center,
        style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16,color:_navy),
        decoration:InputDecoration(
          labelText:'Cap.', labelStyle:const TextStyle(fontSize:10),
          contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:10),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
        ),
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],
      )),
      if (onRemove!=null)...[const SizedBox(width:8),
        IconButton(icon:const Icon(Icons.delete_outline_rounded,color:_red,size:20), onPressed:onRemove,
            tooltip:'Remove room', padding:EdgeInsets.zero, constraints:const BoxConstraints(minWidth:32,minHeight:32))],
    ])));
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override Widget build(BuildContext context) => Container(
      padding:const EdgeInsets.all(20),
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0F172A),Color(0xFF1E40AF)],
          begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(20)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:Colors.white.withOpacity(0.15),borderRadius:BorderRadius.circular(12)),
              child:const Icon(Icons.school_rounded,color:Colors.white,size:28)),
          const SizedBox(width:14),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('BMS Invigilation System',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Colors.white)),
            Text('Dept. of Computer Applications',style:TextStyle(fontSize:11,color:Colors.white54)),
          ])),
        ]),
        const SizedBox(height:12),
        const Text('Automated allocation · Backup invigilators · Attendance sheets',
            style:TextStyle(fontSize:12,color:Colors.white70,height:1.5)),
        const SizedBox(height:12),
        const Wrap(spacing:6,children:[
          _Pill('PDF',Icons.picture_as_pdf_rounded), _Pill('DOCX',Icons.description_rounded),
          _Pill('XLSX',Icons.grid_on_rounded),        _Pill('CSV',Icons.table_chart_rounded),
        ]),
      ]));
}
class _Pill extends StatelessWidget {
  final String l; final IconData i; const _Pill(this.l,this.i);
  @override Widget build(BuildContext context) => Container(margin:const EdgeInsets.only(bottom:4),
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
      decoration:BoxDecoration(color:Colors.white.withOpacity(0.15),borderRadius:BorderRadius.circular(20),
          border:Border.all(color:Colors.white.withOpacity(0.2))),
      child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(i,size:11,color:Colors.white70),const SizedBox(width:4),
        Text(l,style:const TextStyle(fontSize:10,color:Colors.white,fontWeight:FontWeight.w600))]));
}

class _StepHeader extends StatelessWidget {
  final int n; final String title; final bool done; const _StepHeader({required this.n, required this.title, required this.done});
  @override Widget build(BuildContext context) => Row(children:[
    AnimatedContainer(duration:const Duration(milliseconds:300), width:30, height:30,
        decoration:BoxDecoration(color:done?_green:_blue,shape:BoxShape.circle),
        child:Center(child:done?const Icon(Icons.check_rounded,color:Colors.white,size:16)
            :Text('$n',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:13)))),
    const SizedBox(width:12),
    Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:_navy)),
  ]);
}

class _UpCard extends StatelessWidget {
  final String? file; final bool busy,done; final String label; final VoidCallback? onTap;
  const _UpCard({required this.file,required this.busy,required this.done,required this.label,required this.onTap});
  IconData _ic(String n){final e=n.split('.').last.toLowerCase();
  if(e=='csv')return Icons.table_chart_rounded;if(e=='xlsx'||e=='xls')return Icons.grid_on_rounded;
  if(e=='docx'||e=='doc')return Icons.description_rounded;return Icons.picture_as_pdf_rounded;}
  @override Widget build(BuildContext context) => Card(child:Padding(padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(file!=null)...[
          Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
              decoration:BoxDecoration(color:_blueLt,borderRadius:BorderRadius.circular(10)),
              child:Row(children:[Icon(_ic(file!),color:_blue,size:18),const SizedBox(width:8),
                Expanded(child:Text(file!,style:const TextStyle(color:_blue,fontSize:13,fontWeight:FontWeight.w600),overflow:TextOverflow.ellipsis)),
                if(done)const Icon(Icons.check_circle_rounded,color:_green,size:16)])),
          const SizedBox(height:10),
        ],
        ElevatedButton.icon(
          onPressed:busy?null:onTap,
          icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              :Icon(done?Icons.refresh_rounded:Icons.upload_file_rounded),
          label:Text(busy?'Processing…':label),
          style:ElevatedButton.styleFrom(backgroundColor:onTap==null?Colors.grey.shade400:_blue),
        ),
      ])));
}

class _FacCard extends StatelessWidget {
  final Map<String,String> map; final int slots; final String q;
  const _FacCard({required this.map,required this.slots,required this.q});
  @override Widget build(BuildContext context) {
    final isDef=q=='default'||q=='codes_as_names';
    return Container(padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:isDef?_amberLt:_greenLt,borderRadius:BorderRadius.circular(14),
            border:Border.all(color:isDef?_amberBd:_greenBd)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(isDef?Icons.info_rounded:Icons.check_circle_rounded,color:isDef?_amber:_green,size:16),const SizedBox(width:6),
            Expanded(child:Text(isDef?'Built-in BMS codes (${map.length})':'${map.length} faculty auto-detected',
                style:TextStyle(fontWeight:FontWeight.w700,color:isDef?_amber:_green,fontSize:13)))]),
          const SizedBox(height:2), Text('$slots teaching slots',style:const TextStyle(fontSize:11,color:_mid)),
          const SizedBox(height:10),
          Wrap(spacing:6,runSpacing:6,children:map.entries.take(12).map((e)=>Container(
              padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
              child:Text('${e.key}  ${e.value}',style:const TextStyle(fontSize:11,color:_navy,fontWeight:FontWeight.w500)))).toList()),
        ]));
  }
}

class _AllocCard extends StatelessWidget {
  final int count; final Map<String,dynamic>? alloc; const _AllocCard({required this.count,required this.alloc});
  @override Widget build(BuildContext context) {
    final ok=alloc?['success_count'] as int??0; final fail=alloc?['fail_count'] as int??0; final aok=fail==0;
    return Container(padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:aok?_greenLt:_amberLt,borderRadius:BorderRadius.circular(14),
            border:Border.all(color:aok?_greenBd:_amberBd)),
        child:Row(children:[
          Icon(aok?Icons.check_circle_rounded:Icons.warning_amber_rounded,color:aok?_green:_amber,size:22),const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(aok?'All $ok exam(s) allocated ✓':'$ok/$count allocated — $fail need attention',
                style:TextStyle(fontWeight:FontWeight.w700,fontSize:14,color:aok?_green:_amber)),
            const SizedBox(height:2),
            const Text('Tap Results tab for roster + downloads',style:TextStyle(fontSize:11,color:_mid)),
          ])),
        ]));
  }
}

class _GoCard extends StatelessWidget {
  const _GoCard();
  @override Widget build(BuildContext context) => Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF1E40AF),Color(0xFF2563EB)]),borderRadius:BorderRadius.circular(14)),
      child:const Row(children:[Icon(Icons.arrow_forward_ios_rounded,color:Colors.white,size:14),SizedBox(width:10),
        Expanded(child:Text('Go to Results tab → download duty chart + attendance sheets',
            style:TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13)))]));
}

class _Ntc extends StatelessWidget {
  final IconData icon; final Color color,bg,bdr; final String title,body;
  const _Ntc(this.icon,this.color,this.bg,this.bdr,this.title,this.body);
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(12),border:Border.all(color:bdr)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,color:color,size:18),const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:TextStyle(fontWeight:FontWeight.w700,color:color,fontSize:13)),
          const SizedBox(height:2), Text(body,style:const TextStyle(fontSize:12,color:_navy,height:1.4)),
        ])),
      ]));
}

class _StatChip extends StatelessWidget {
  final String l,v; final Color c; const _StatChip(this.l,this.v,this.c);
  @override Widget build(BuildContext context) => Expanded(child:Container(
      padding:const EdgeInsets.symmetric(vertical:14),
      decoration:BoxDecoration(color:c.withOpacity(0.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:c.withOpacity(0.25))),
      child:Column(children:[Text(v,style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:c)),
        Text(l,style:const TextStyle(fontSize:10,color:_mid))])));
}

class _SL extends StatelessWidget { final String t; const _SL(this.t);
@override Widget build(BuildContext context) => Text(t,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16,color:_navy)); }
class _SubText extends StatelessWidget { final String t; const _SubText(this.t);
@override Widget build(BuildContext context) => Text(t,style:const TextStyle(fontSize:12,color:_mid)); }
class _EmptyState extends StatelessWidget { final String t; const _EmptyState(this.t);
@override Widget build(BuildContext context) => Center(child:Padding(padding:const EdgeInsets.all(40),
    child:Text(t,textAlign:TextAlign.center,style:const TextStyle(fontSize:15,color:_mid,height:1.7)))); }

// ── Bar chart painter ───────────────────────────────────────────
class BarP extends CustomPainter {
  final List<Map<String,dynamic>> faculty; final double mean;
  const BarP({required this.faculty,required this.mean});
  @override void paint(Canvas canvas,Size size){
    if(faculty.isEmpty)return;
    int maxD=0; for(final f in faculty){final d=(f['duties'] as int?)??0;if(d>maxD)maxD=d;}
    if(maxD==0)return;
    const pL=34.0,pB=44.0,pT=16.0;
    final cW=size.width-pL,cH=size.height-pB-pT,bW=(cW/faculty.length)*0.56,gap=cW/faculty.length;
    final my=pT+cH-(mean/maxD)*cH;
    canvas.drawLine(Offset(pL,my),Offset(size.width,my),Paint()..color=_amber.withOpacity(0.6)..strokeWidth=1.5);
    final fill=Paint()..style=PaintingStyle.fill;
    for(int i=0;i<faculty.length;i++){
      final d=((faculty[i]['duties'] as int?)??0).toDouble();
      final x=pL+i*gap+(gap-bW)/2,bh=(d/maxD)*cH,y=pT+cH-bh;
      fill.color=d==0?_amber.withOpacity(0.7):(mean>0&&d>mean*1.2)?_red.withOpacity(0.8):_blue.withOpacity(0.8);
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x,y,bW,bh),
          topLeft:const Radius.circular(5),topRight:const Radius.circular(5)),fill);
      if(d>0){final tp=TextPainter(text:TextSpan(text:'${d.toInt()}',
          style:const TextStyle(fontSize:10,color:_navy,fontWeight:FontWeight.w700)),textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(x+bW/2-tp.width/2,y-15));}
      final nm=(faculty[i]['name'] as String?? '').split(' ').last;
      final np=TextPainter(text:TextSpan(text:nm,style:const TextStyle(fontSize:9,color:_mid)),textDirection:TextDirection.ltr)..layout();
      canvas.save();canvas.translate(x+bW/2,size.height-4);canvas.rotate(-0.45);np.paint(canvas,Offset(-np.width/2,0));canvas.restore();
    }
    for(int i=0;i<=maxD;i++){
      if(maxD>6&&i%2!=0)continue;
      final y=pT+cH-(i/maxD)*cH;
      final lp=TextPainter(text:TextSpan(text:'$i',style:const TextStyle(fontSize:9,color:_hint)),textDirection:TextDirection.ltr)..layout();
      lp.paint(canvas,Offset(pL-lp.width-4,y-lp.height/2));
    }
  }
  @override bool shouldRepaint(BarP o)=>o.faculty!=faculty;
}

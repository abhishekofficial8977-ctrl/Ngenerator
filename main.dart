
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NGeneratorApp());
}

class NGeneratorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N Generator',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: LoginChoicePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginChoicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('N Generator')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                child: Text('Login as Admin'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLoginPage())),
              ),
              SizedBox(height:12),
              ElevatedButton(
                child: Text('Login as Staff'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffLoginPage())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _userCtl = TextEditingController(text: 'admin');
  final _passCtl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Login')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _userCtl, decoration: InputDecoration(labelText: 'Username')),
          TextField(controller: _passCtl, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
          SizedBox(height:12),
          ElevatedButton(onPressed: () {
            // default admin password: 123456 (changeable later in settings)
            if (_userCtl.text.trim()=='admin' && _passCtl.text.trim()=='123456') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminHomePage()));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid admin credentials (default: admin / 123456)')));
            }
          }, child: Text('Login'))
        ]),
      ),
    );
  }
}

class StaffLoginPage extends StatefulWidget {
  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Staff Login')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _userCtl, decoration: InputDecoration(labelText: 'Username')),
          TextField(controller: _passCtl, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
          SizedBox(height:12),
          ElevatedButton(onPressed: () async {
            // simple local auth - in production, use proper backend
            String u = _userCtl.text.trim();
            String p = _passCtl.text.trim();
            if (u.isEmpty) return;
            // For demo: any username/password works; store created users in DB later
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StaffHomePage(username: u)));
          }, child: Text('Login (demo)'))
        ]),
      ),
    );
  }
}

class AdminHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HomeScaffold(title: 'Admin Dashboard', child: AdminBody());
  }
}

class StaffHomePage extends StatelessWidget {
  final String username;
  StaffHomePage({required this.username});
  @override
  Widget build(BuildContext context) {
    return HomeScaffold(title: 'Staff: \$username', child: StaffBody(username: username));
  }
}

class HomeScaffold extends StatefulWidget {
  final String title;
  final Widget child;
  HomeScaffold({required this.title, required this.child});
  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i){ setState(()=>idx=i); },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class AdminBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CreateNoticeForm(isAdmin: true, onCreated: (path){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notice created at: \$path'))); });
  }
}

class StaffBody extends StatelessWidget {
  final String username;
  StaffBody({required this.username});
  @override
  Widget build(BuildContext context) {
    return CreateNoticeForm(isAdmin: false, onCreated: (path){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notice created at: \$path'))); });
  }
}

class CreateNoticeForm extends StatefulWidget {
  final bool isAdmin;
  final Function(String) onCreated;
  CreateNoticeForm({required this.isAdmin, required this.onCreated});

  @override
  State<CreateNoticeForm> createState() => _CreateNoticeFormState();
}

class _CreateNoticeFormState extends State<CreateNoticeForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _clientId = TextEditingController();
  final _mobile = TextEditingController();
  final _loan = TextEditingController();
  final _emi = TextEditingController();
  final _emiDate = TextEditingController();
  final _outstanding = TextEditingController();
  final _location = TextEditingController();
  File? _photo;

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (img==null) return;
    setState(()=>_photo=File(img.path));
  }

  Future<String> _generatePdf() async {
    final pdf = pw.Document();
    final logo1 = pw.MemoryImage((await DefaultAssetBundle.of(context).load('assets/logo_pragati.png')).buffer.asUint8List());
    final logo2 = pw.MemoryImage((await DefaultAssetBundle.of(context).load('assets/logo_northernarc.png')).buffer.asUint8List());
    final font = await PdfGoogleFonts.openSansRegular();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx){
        return [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Image(logo1, width: 80, height:40),
            pw.Text('LEGAL NOTICE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Image(logo2, width: 80, height:40),
          ]),
          pw.SizedBox(height:12),
          pw.Text('To, ${_name.text}'),
          pw.SizedBox(height:6),
          pw.Text('Client ID: ${_clientId.text}'),
          pw.Text('Mobile: ${_mobile.text}'),
          pw.SizedBox(height:6),
          pw.Text('Loan Amount: ₹${_loan.text}'),
          pw.Text('EMI: ₹${_emi.text} | Due Date: ${_emiDate.text}'),
          pw.Text('Outstanding: ₹${_outstanding.text}'),
          pw.Text('Location: ${_location.text}'),
          pw.SizedBox(height:12),
          if (_photo!=null) pw.Image(pw.MemoryImage(_photo!.readAsBytesSync()), width:100, height:100),
          pw.SizedBox(height:12),
          pw.Text('This loan is backed by Northern Arc Capital through its subsidiary Pragati Finserv Pvt Ltd.'),
          pw.SizedBox(height:20),
          pw.Text('Regards,'),
          pw.Text('Pragati Finserv Pvt Ltd'),
          pw.SizedBox(height:20),
          pw.Divider(),
          pw.Paragraph(text: DateTime.now().toString()),
        ];
      }
    ));

    // Add a watermark on each page by creating a new PDF with transparency
    // For simplicity we add a footer text as watermark on each page here
    final outDir = await getApplicationDocumentsDirectory();
    final file = File('${outDir.path}/Notice_${_name.text}_${_clientId.text}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  @override
  void dispose() {
    _name.dispose(); _clientId.dispose(); _mobile.dispose(); _loan.dispose(); _emi.dispose(); _emiDate.dispose(); _outstanding.dispose(); _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: EdgeInsets.all(12), child: Form(
      key: _formKey,
      child: Column(children: [
        TextFormField(controller: _name, decoration: InputDecoration(labelText: 'Client Name')),
        TextFormField(controller: _clientId, decoration: InputDecoration(labelText: 'Client ID')),
        TextFormField(controller: _mobile, decoration: InputDecoration(labelText: 'Mobile Number')),
        TextFormField(controller: _loan, decoration: InputDecoration(labelText: 'Loan Amount')),
        TextFormField(controller: _emi, decoration: InputDecoration(labelText: 'EMI Amount')),
        TextFormField(controller: _emiDate, decoration: InputDecoration(labelText: 'EMI Date')),
        TextFormField(controller: _outstanding, decoration: InputDecoration(labelText: 'Outstanding Amount')),
        TextFormField(controller: _location, decoration: InputDecoration(labelText: 'Location/Address')),
        SizedBox(height:8),
        Row(children: [
          ElevatedButton.icon(onPressed: _pickPhoto, icon: Icon(Icons.photo), label: Text('Upload Photo (Optional)')),
          SizedBox(width:8),
          if (_photo!=null) Text('Photo selected', style: TextStyle(color: Colors.green)),
        ]),
        SizedBox(height:12),
        ElevatedButton.icon(onPressed: () async {
          if (_name.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter client name'))); return; }
          final path = await _generatePdf();
          widget.onCreated(path);
          // Share directly after creation
          await Share.shareFiles([path], text: 'Legal Notice - ${_name.text}');
        }, icon: Icon(Icons.picture_as_pdf), label: Text('Generate & Share PDF')),
      ]),
    ));
  }
}

class StaffHomePageWrapper extends StatelessWidget {
  final String username;
  StaffHomePageWrapper({required this.username});
  @override Widget build(BuildContext context) => StaffHomePage(username: username);
}

class StaffHomePage extends StatelessWidget {
  final String username;
  StaffHomePage({required this.username});
  @override
  Widget build(BuildContext context) {
    return HomeScaffold(title: 'Staff: \$username', child: StaffBody(username: username));
  }
}

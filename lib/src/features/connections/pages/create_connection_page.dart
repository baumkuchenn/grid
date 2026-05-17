import 'package:flutter/material.dart';
import '../models/database_connection.dart';

class CreateConnectionPage extends StatefulWidget {
  final DatabaseConnection? connectionToEdit;

  const CreateConnectionPage({super.key, this.connectionToEdit});

  @override
  State<CreateConnectionPage> createState() => _CreateConnectionPageState();
}

class _CreateConnectionPageState extends State<CreateConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  
  String _selectedType = 'mysql';

  @override
  void initState() {
    super.initState();
    final edit = widget.connectionToEdit;
    _nameCtrl = TextEditingController(text: edit?.name ?? '');
    _hostCtrl = TextEditingController(text: edit?.host ?? '127.0.0.1');
    _portCtrl = TextEditingController(text: edit?.port.toString() ?? '3306');
    _usernameCtrl = TextEditingController(text: edit?.username ?? 'root');
    _passwordCtrl = TextEditingController(text: edit?.password ?? '');
    _selectedType = edit?.type ?? 'mysql';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (widget.connectionToEdit == null) {
        // Create
        final newConn = DatabaseConnection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameCtrl.text.trim(),
          type: _selectedType,
          host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 3306,
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        globalConnections.add(newConn);
      } else {
        // Update
        final edit = widget.connectionToEdit!;
        edit.name = _nameCtrl.text.trim();
        edit.type = _selectedType;
        edit.host = _hostCtrl.text.trim();
        edit.port = int.tryParse(_portCtrl.text.trim()) ?? 3306;
        edit.username = _usernameCtrl.text.trim();
        edit.password = _passwordCtrl.text;
      }
      await saveConnections();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.connectionToEdit != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "EDIT CONNECTION" : "NEW CONNECTION"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Database Server"),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF888888)),
                    items: const [
                      DropdownMenuItem(
                        value: 'mysql',
                        child: Text("MySQL", style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Connection Details"),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameCtrl,
                label: "Connection Name",
                hint: "e.g., Local Database",
                validator: (val) => val == null || val.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _hostCtrl,
                      label: "Host",
                      hint: "127.0.0.1",
                      validator: (val) => val == null || val.isEmpty ? "Host is required" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _portCtrl,
                      label: "Port",
                      hint: "3306",
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _usernameCtrl,
                label: "Username",
                hint: "root",
                validator: (val) => val == null || val.isEmpty ? "Username is required" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordCtrl,
                label: "Password",
                hint: "Leave blank if no password",
                obscureText: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(isEdit ? "SAVE CHANGES" : "CREATE CONNECTION"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF888888),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

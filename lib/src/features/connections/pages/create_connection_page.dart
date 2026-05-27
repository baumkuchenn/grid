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
        await connectionRepository.add(newConn);
      } else {
        // Update
        final edit = widget.connectionToEdit!;
        await connectionRepository.update(
          edit,
          name: _nameCtrl.text.trim(),
          type: _selectedType,
          host: _hostCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 3306,
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.connectionToEdit != null;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF2D2D2D),
        ), // Sumi Ink back button
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
        ), // Divider Clay
        title: Text(
          isEdit ? "EDIT CONNECTION" : "NEW CONNECTION",
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D2D2D), // Sumi Ink
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Database Server"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EFE9), // Kraft Sand
                          border: Border.all(color: const Color(0xFFE8E5DF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF7F0019), // Muji Red
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "MySQL Server",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D2D2D), // Sumi Ink
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildSectionTitle("Connection Details"),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameCtrl,
                    label: "Connection Name",
                    hint: "e.g., Local Database",
                    validator: (val) =>
                        val == null || val.isEmpty ? "Name is required" : null,
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
                          validator: (val) => val == null || val.isEmpty
                              ? "Host is required"
                              : null,
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
                          validator: (val) =>
                              val == null || val.isEmpty ? "Required" : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _usernameCtrl,
                    label: "Username",
                    hint: "root",
                    validator: (val) => val == null || val.isEmpty
                        ? "Username is required"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordCtrl,
                    label: "Password",
                    hint: "Leave blank if no password",
                    obscureText: true,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(
                        isEdit ? "SAVE CHANGES" : "CREATE CONNECTION",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF73726F), // Wood Ash
        letterSpacing: 1.0,
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
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF73726F), // Wood Ash
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

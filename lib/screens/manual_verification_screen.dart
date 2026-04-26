import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';

class ManualVerificationScreen extends StatefulWidget {
  final String officerId;
  final String assignedBooth;

  const ManualVerificationScreen({
    super.key,
    required this.officerId,
    required this.assignedBooth,
  });

  @override
  State<ManualVerificationScreen> createState() =>
      _ManualVerificationScreenState();
}

class _ManualVerificationScreenState extends State<ManualVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _voterIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  bool _isVerifying = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _voterIdController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _verifyVoter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiService.verifyVoter),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "voterId": _voterIdController.text.trim().toUpperCase(),
          "name": _nameController.text.trim(),
          "dob": _dobController.text.trim(),
          "officerId": widget.officerId,
          "officerBooth": widget.assignedBooth, // ✅ booth enforcement
        }),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showResult(true, data['message'], data['voter']);
      } else if (response.statusCode == 403) {
        // ✅ Wrong booth — dedicated dialog with working OK button
        _showBoothMismatchDialog(data);
      } else {
        setState(
          () => _errorMessage = data['message'] ?? 'Verification failed.',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ✅ Booth mismatch dialog — uses dialogContext so OK always works
  void _showBoothMismatchDialog(dynamic data) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.wrong_location_rounded,
              color: AppTheme.danger,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Wrong Booth!',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['message'] ?? 'Voter is assigned to a different booth.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Booth',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        widget.assignedBooth,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Voter's Booth",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        data['voterBooth'] ?? '-',
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (data['voterConstituency'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Constituency',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            data['voterConstituency'],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.accent,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please redirect this voter to their assigned booth.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // ✅ dialogContext — always works regardless of navigation state
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResult(bool approved, String message, dynamic voterData) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: approved ? 0.80 : 0.4,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: approved
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.danger.withOpacity(0.1),
                ),
                child: Icon(
                  approved ? Icons.how_to_vote_rounded : Icons.cancel_rounded,
                  color: approved ? AppTheme.success : AppTheme.danger,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                approved ? 'VOTER VERIFIED' : 'VERIFICATION FAILED',
                style: TextStyle(
                  color: approved ? AppTheme.success : AppTheme.danger,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),

              // ✅ Show voter details with booth instead of address
              if (approved && voterData != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.success.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _resultRow(
                        Icons.badge_outlined,
                        'Voter ID',
                        voterData['voterId'] ?? '-',
                      ),
                      const Divider(color: AppTheme.border, height: 16),
                      _resultRow(
                        Icons.person_outline_rounded,
                        'Name',
                        voterData['name'] ?? '-',
                      ),
                      const Divider(color: AppTheme.border, height: 16),
                      _resultRow(
                        Icons.cake_outlined,
                        'Date of Birth',
                        voterData['dob'] ?? '-',
                      ),
                      const Divider(color: AppTheme.border, height: 16),
                      // ✅ Show booth number instead of blank address
                      _resultRow(
                        Icons.location_on_outlined,
                        'Booth',
                        voterData['boothNumber'] ?? '-',
                      ),
                      const Divider(color: AppTheme.border, height: 16),
                      // ✅ Show constituency
                      _resultRow(
                        Icons.map_outlined,
                        'Constituency',
                        voterData['constituency'] ?? '-',
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _voterIdController.clear();
                        _nameController.clear();
                        _dobController.clear();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Verify Another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: approved
                            ? AppTheme.success
                            : AppTheme.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Dashboard',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manual Verification',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card with booth display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Manual Entry',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Booth: ${widget.assignedBooth}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _sectionLabel('VOTER INFORMATION'),
                  const SizedBox(height: 14),

                  // Voter ID
                  _buildField(
                    label: 'Voter ID Number *',
                    controller: _voterIdController,
                    icon: Icons.badge_outlined,
                    hint: 'e.g. ABC1234567',
                    textCapitalization: TextCapitalization.characters,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Voter ID is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Name
                  _buildField(
                    label: 'Full Name (optional)',
                    controller: _nameController,
                    icon: Icons.person_outline_rounded,
                    hint: "Enter voter's full name",
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),

                  // DOB
                  _buildField(
                    label: 'Date of Birth *',
                    controller: _dobController,
                    icon: Icons.cake_outlined,
                    hint: 'DD/MM/YYYY',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _DateInputFormatter(),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Date of birth is required';
                      }
                      final dobRegex = RegExp(r'^\d{2}\/\d{2}\/\d{4}$');
                      if (!dobRegex.hasMatch(val.trim())) {
                        return 'Enter in DD/MM/YYYY format';
                      }
                      return null;
                    },
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.danger.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppTheme.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifying ? null : _verifyVoter,
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_user_rounded, size: 20),
                      label: Text(
                        _isVerifying ? 'Verifying...' : 'Verify Voter',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primary.withOpacity(
                          0.4,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Clear button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        _voterIdController.clear();
                        _nameController.clear();
                        _dobController.clear();
                        setState(() => _errorMessage = null);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Clear Fields',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 19),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.danger, width: 1.5),
            ),
            errorStyle: TextStyle(color: AppTheme.danger, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length > 8) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(text[i]);
    }
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

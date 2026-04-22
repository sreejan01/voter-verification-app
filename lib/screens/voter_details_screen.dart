import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class VoterDetailsScreen extends StatefulWidget {
  final Map<String, String?> extractedData;
  final String imagePath;
  final String officerId;
  final String assignedBooth;

  const VoterDetailsScreen({
    super.key,
    required this.extractedData,
    required this.imagePath,
    required this.officerId,
    required this.assignedBooth,
  });

  @override
  State<VoterDetailsScreen> createState() => _VoterDetailsScreenState();
}

class _VoterDetailsScreenState extends State<VoterDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _voterIdController;
  late TextEditingController _nameController;
  late TextEditingController _dobController;

  bool _isVerifying = false;
  Map<String, dynamic>? _fraudData;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _voterIdController = TextEditingController(
      text: widget.extractedData['voterId'] ?? '',
    );
    _nameController = TextEditingController(
      text: widget.extractedData['name'] ?? '',
    );
    final rawDob = widget.extractedData['dob'] ?? '';
    _dobController = TextEditingController(text: _normalizeDob(rawDob));

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

    // ✅ Check fraud on load
    _checkFraud();
  }

  String _normalizeDob(String dob) {
    if (dob.isEmpty) return '';
    dob = dob.trim();
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dob)) return dob;
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(dob)) {
      return dob.replaceAll('-', '/');
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
      final parts = dob.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(dob)) {
      final parts = dob.split('/');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dob;
  }

  Future<void> _checkFraud() async {
    try {
      final response = await http.post(
        Uri.parse(ApiService.detectFraud),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "officerId": widget.officerId,
          "voterId": widget.extractedData['voterId'],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['riskLevel'] != 'Low') {
          setState(() => _fraudData = data);
        }
      }
    } catch (e) {
      print('Fraud check error: $e');
    }
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
    if (_voterIdController.text.trim().isEmpty) {
      _showResult(false, 'Voter ID is required for verification.', null, null);
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final response = await http.post(
        Uri.parse(ApiService.verifyVoter),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "voterId": _voterIdController.text.trim(),
          "name": _nameController.text.trim(),
          "dob": _dobController.text.trim(),
          "officerId": widget.officerId,
          "officerBooth": widget.assignedBooth, // ✅ send booth
        }),
      );
      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showResult(
          true,
          data['message'] ?? 'Voter verified successfully!',
          data['voter'],
          null,
        );
      } else if (response.statusCode == 403) {
        // ✅ Wrong booth error
        _showBoothMismatch(data);
      } else {
        _showResult(
          false,
          data['message'] ?? 'Voter not found in database.',
          null,
          null,
        );
      }
    } catch (e) {
      _showResult(false, 'Network error. Check your connection.', null, null);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ✅ Wrong booth dialog
  void _showBoothMismatch(dynamic data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
              data['message'] ?? 'Voter is from a different booth.',
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
                  _infoRow(
                    'Your Booth',
                    widget.assignedBooth,
                    AppTheme.primary,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    'Voter\'s Booth',
                    data['voterBooth'] ?? '-',
                    AppTheme.danger,
                  ),
                  if (data['voterConstituency'] != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      'Constituency',
                      data['voterConstituency'],
                      AppTheme.textSecondary,
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
              onPressed: () => Navigator.pop(context),
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

  Widget _infoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _showResult(
    bool approved,
    String message,
    dynamic voterData,
    dynamic fraudData,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: approved ? 0.75 : 0.45,
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
                        'DOB',
                        voterData['dob'] ?? '-',
                      ),
                      const Divider(color: AppTheme.border, height: 16),
                      _resultRow(
                        Icons.location_on_outlined,
                        'Booth',
                        voterData['boothNumber'] ?? '-',
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
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
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
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
          'Extracted Details',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scanned image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    width: double.infinity,
                    height: 175,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),

                // ✅ Fraud alert if detected
                if (_fraudData != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _fraudData!['riskLevel'] == 'High'
                          ? AppTheme.danger.withOpacity(0.08)
                          : AppTheme.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _fraudData!['riskLevel'] == 'High'
                            ? AppTheme.danger.withOpacity(0.3)
                            : AppTheme.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: _fraudData!['riskLevel'] == 'High'
                              ? AppTheme.danger
                              : AppTheme.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ ${_fraudData!['riskLevel']} Risk Detected',
                                style: TextStyle(
                                  color: _fraudData!['riskLevel'] == 'High'
                                      ? AppTheme.danger
                                      : AppTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_fraudData!['recommendation'] != null)
                                Text(
                                  _fraudData!['recommendation'],
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // OCR notice
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.15),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.primary,
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI corrected — please verify details below',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                _sectionLabel('VOTER DETAILS'),
                const SizedBox(height: 14),

                _buildField(
                  label: 'Voter ID Number',
                  controller: _voterIdController,
                  icon: Icons.badge_outlined,
                  hint: 'e.g. SHJ2004117',
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'Full Name',
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter full name',
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'Date of Birth (DD/MM/YYYY)',
                  controller: _dobController,
                  icon: Icons.cake_outlined,
                  hint: 'DD/MM/YYYY',
                ),

                const SizedBox(height: 28),

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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    ),
  );

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
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
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
          ),
        ),
      ],
    );
  }
}

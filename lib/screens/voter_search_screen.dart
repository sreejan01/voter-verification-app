import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class VoterSearchScreen extends StatefulWidget {
  final String officerId;
  final String assignedBooth;

  const VoterSearchScreen({
    super.key,
    required this.officerId,
    required this.assignedBooth,
  });

  @override
  State<VoterSearchScreen> createState() => _VoterSearchScreenState();
}

class _VoterSearchScreenState extends State<VoterSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String _lastQuery = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;
    if (query.length >= 2) {
      _search(query);
    } else {
      setState(() {
        _results = [];
        _errorMessage = null;
      });
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiService.searchVoter}?query=$query'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _results = data['voters'] ?? [];
          _isSearching = false;
        });
        _animController.forward(from: 0);
      } else {
        setState(() {
          _errorMessage = 'Search failed. Try again.';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Check your connection.';
        _isSearching = false;
      });
    }
  }

  Future<void> _confirmVerification(dynamic voter) async {
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.how_to_vote_rounded,
                color: AppTheme.primary, size: 40),
            const SizedBox(height: 12),
            const Text('Confirm Verification',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Verify ${voter['name']} (${voter['voterId']})?',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Verify',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isVerifying = true);

    try {
      final response = await http.post(
        Uri.parse(ApiService.verifyVoter),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "voterId": voter['voterId'],
          "dob": voter['dob'],
          "officerId": widget.officerId,
          "officerBooth": widget.assignedBooth, // ✅ booth check
        }),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showResultDialog(true, data['message'] ?? 'Voter verified!');
        _search(_searchController.text.trim());
      } else if (response.statusCode == 403) {
        // ✅ Wrong booth — show dedicated dialog
        _showBoothMismatchDialog(data);
      } else {
        _showResultDialog(
            false, data['message'] ?? 'Verification failed.');
      }
    } catch (e) {
      _showResultDialog(false, 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ✅ Booth mismatch dialog — uses dialogContext so OK button always works
  void _showBoothMismatchDialog(dynamic data) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wrong_location_rounded,
                color: AppTheme.danger, size: 24),
            const SizedBox(width: 8),
            const Text('Wrong Booth!',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['message'] ??
                  'Voter is assigned to a different booth.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.danger.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Booth',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(widget.assignedBooth,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Voter's Booth",
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      Text(data['voterBooth'] ?? '-',
                          style: TextStyle(
                              color: AppTheme.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (data['voterConstituency'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Constituency',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                        Flexible(
                          child: Text(
                            data['voterConstituency'],
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
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
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.accent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please redirect this voter to their assigned booth.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
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
              // ✅ dialogContext ensures OK always works
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(bool approved, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: approved
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.danger.withOpacity(0.1),
              ),
              child: Icon(
                approved
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: approved ? AppTheme.success : AppTheme.danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              approved ? 'VERIFIED' : 'FAILED',
              style: TextStyle(
                  color: approved ? AppTheme.success : AppTheme.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 6),
            Text(message,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      approved ? AppTheme.success : AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
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
        title: const Text('Voter Search',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name or voter ID...',
                  hintStyle: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.primary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppTheme.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _results = [];
                              _errorMessage = null;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Booth info bar
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primary.withOpacity(0.06),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppTheme.primary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Your Booth: ${widget.assignedBooth}',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.textSecondary)))
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded,
                                    color: AppTheme.border, size: 64),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Enter name or voter ID to search'
                                      : 'No voters found',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final voter = _results[index];
                                final hasVoted =
                                    voter['hasVoted'] == true;
                                final isWrongBooth =
                                    voter['boothNumber'] != null &&
                                        voter['boothNumber'] !=
                                            widget.assignedBooth;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: hasVoted
                                          ? AppTheme.success
                                              .withOpacity(0.3)
                                          : isWrongBooth
                                              ? AppTheme.danger
                                                  .withOpacity(0.3)
                                              : AppTheme.border,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: hasVoted
                                                ? AppTheme.success
                                                    .withOpacity(0.1)
                                                : isWrongBooth
                                                    ? AppTheme.danger
                                                        .withOpacity(0.1)
                                                    : AppTheme.primary
                                                        .withOpacity(0.08),
                                          ),
                                          child: Icon(
                                            hasVoted
                                                ? Icons
                                                    .how_to_vote_rounded
                                                : isWrongBooth
                                                    ? Icons
                                                        .wrong_location_rounded
                                                    : Icons
                                                        .person_outline_rounded,
                                            color: hasVoted
                                                ? AppTheme.success
                                                : isWrongBooth
                                                    ? AppTheme.danger
                                                    : AppTheme.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(voter['name'] ?? '-',
                                                  style: const TextStyle(
                                                      color: AppTheme
                                                          .textPrimary,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              const SizedBox(height: 3),
                                              Text(
                                                  voter['voterId'] ?? '-',
                                                  style: const TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize: 12)),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      size: 11,
                                                      color: isWrongBooth
                                                          ? AppTheme
                                                              .danger
                                                          : AppTheme
                                                              .textSecondary),
                                                  const SizedBox(
                                                      width: 3),
                                                  Text(
                                                    'Booth: ${voter['boothNumber'] ?? '-'}',
                                                    style: TextStyle(
                                                        color: isWrongBooth
                                                            ? AppTheme
                                                                .danger
                                                            : AppTheme
                                                                .textSecondary,
                                                        fontSize: 11,
                                                        fontWeight: isWrongBooth
                                                            ? FontWeight
                                                                .w600
                                                            : FontWeight
                                                                .normal),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8,
                                                  vertical: 3),
                                              decoration: BoxDecoration(
                                                color: hasVoted
                                                    ? AppTheme.success
                                                        .withOpacity(0.1)
                                                    : isWrongBooth
                                                        ? AppTheme.danger
                                                            .withOpacity(
                                                                0.1)
                                                        : AppTheme.primary
                                                            .withOpacity(
                                                                0.08),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        6),
                                              ),
                                              child: Text(
                                                hasVoted
                                                    ? 'Voted'
                                                    : isWrongBooth
                                                        ? 'Wrong Booth'
                                                        : 'Not Voted',
                                                style: TextStyle(
                                                    color: hasVoted
                                                        ? AppTheme.success
                                                        : isWrongBooth
                                                            ? AppTheme
                                                                .danger
                                                            : AppTheme
                                                                .primary,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            if (!hasVoted) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 30,
                                                child: ElevatedButton(
                                                  onPressed: _isVerifying
                                                      ? null
                                                      : () =>
                                                          _confirmVerification(
                                                              voter),
                                                  style: ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                        isWrongBooth
                                                            ? AppTheme
                                                                .danger
                                                            : AppTheme
                                                                .primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    6)),
                                                  ),
                                                  child: const Text(
                                                      'Verify',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
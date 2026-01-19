import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late Future<Map<String, dynamic>> analyticsFuture;

  int currentPage = 1;
  int _pageSize = 25; // sent to API and used for pagination

  DateTime? _fromDate;
  DateTime? _toDate;
  final ScrollController _horizontalController = ScrollController();

  // Filters
  String statusFilter = 'pending'; // "settled" or "pending"
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _activeOnly = false;

  @override
  void initState() {
    super.initState();
    // Default date range: 1 Aug 2025 → today
    _fromDate = DateTime(2025, 8, 1); // "From" (older date)
    _toDate = DateTime.now(); // "To" (today)

    analyticsFuture = fetchAnalyticsSummary(
      page: currentPage,
      fromDate: _fromDate != null ? _formatDate(_fromDate!) : null,
      toDate: _toDate != null ? _formatDate(_toDate!) : null,
      activeOnly: _activeOnly,
      pageSize: _pageSize,
    );
    // analyticsFuture = fetchAnalyticsSummary(page: currentPage, pageSize: _pageSize);
  }

  @override
  void dispose() {
    _stockController.dispose();
    _userController.dispose();
    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  // Format date as YYYY-MM-DD for API and UI
  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<Map<String, dynamic>> fetchAnalyticsSummary({
    required int page,
    String? fromDate, // UI From Date
    String? toDate, // UI To Date
    String? stock,
    String? user,
    String? search,
    bool? activeOnly,
    int? pageSize,
  }) async {
    final dio = Dio();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    dio.options.baseUrl =
        "https://www.bbbprediction.com";
    dio.options.headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    final queryParameters = <String, dynamic>{
      "page": page,
    };

    if (pageSize != null && pageSize > 0) {
      queryParameters["page_size"] = pageSize;
    }

    // NOTE (as requested earlier):
    // date_from = TO date (toDate)
    // date_to   = FROM date (fromDate)
    if (toDate != null && toDate.isNotEmpty) {
      queryParameters["date_from"] = toDate;
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      queryParameters["date_to"] = fromDate;
    }

    // status filter: "settled" or "pending"
    if (statusFilter.isNotEmpty) {
      queryParameters['status'] = statusFilter;
    }

    if (stock != null && stock.trim().isNotEmpty) {
      queryParameters['stock'] = stock.trim();
    }
    if (user != null && user.trim().isNotEmpty) {
      queryParameters['user'] = user.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (activeOnly == true) {
      queryParameters['active_only'] = true;
    }

    final response = await dio.get(
      "/admin_panel/analytics/dashboard-new/",
      queryParameters: queryParameters,
    );

    // Debug
    // ignore: avoid_print
    print("Analytics Dashboard Response: Start");
    // ignore: avoid_print
    print(response.data);
    // ignore: avoid_print
    print("Analytics Dashboard Response: End");

    return Map<String, dynamic>.from(response.data);
  }

  void _goToPage(int page) {
    setState(() {
      currentPage = page;
      analyticsFuture = fetchAnalyticsSummary(
        page: currentPage,
        fromDate: _fromDate != null ? _formatDate(_fromDate!) : null,
        toDate: _toDate != null ? _formatDate(_toDate!) : null,
        stock: _stockController.text.trim().isEmpty
            ? null
            : _stockController.text.trim(),
        user: _userController.text.trim().isEmpty
            ? null
            : _userController.text.trim(),
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        activeOnly: _activeOnly,
        pageSize: _pageSize,
      );
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _fromDate : _toDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  void _applyFilters() {
    setState(() {
      currentPage = 1;
      analyticsFuture = fetchAnalyticsSummary(
        page: currentPage,
        fromDate: _fromDate != null ? _formatDate(_fromDate!) : null,
        toDate: _toDate != null ? _formatDate(_toDate!) : null,
        stock: _stockController.text.trim().isEmpty
            ? null
            : _stockController.text.trim(),
        user: _userController.text.trim().isEmpty
            ? null
            : _userController.text.trim(),
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        activeOnly: _activeOnly,
        pageSize: _pageSize,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _stockController.clear();
      _userController.clear();
      _searchController.clear();
      _activeOnly = false;

      currentPage = 1;
      analyticsFuture =
          fetchAnalyticsSummary(page: currentPage, pageSize: _pageSize);
    });
  }

  BoxDecoration _cardStyle() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      );

  String _fmtAmount(dynamic v) {
    if (v == null) return '--';
    final num n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    if (n.abs() >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(2)}M';
    } else if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toStringAsFixed(2);
  }

  String _fmtInt(dynamic v) {
    if (v == null) return '--';
    final num n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(0);
  }

  String _fmtPercent(dynamic v) {
    if (v == null) return '--';
    if (v is String && v.trim().isNotEmpty) {
      final s = v.trim();
      if (s.endsWith('%')) {
        final clean = s.replaceAll('%', '').trim();
        final num? n = num.tryParse(clean);
        if (n == null) return s;
        return '${n.toStringAsFixed(2)}%';
      }
      final num? n = num.tryParse(s);
      if (n == null) return s;
      return '${n.toStringAsFixed(2)}%';
    }
    final num n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    return '${n.toStringAsFixed(2)}%';
  }

  String _fmtDateTime(dynamic v) {
    if (v == null) return '--';
    final s = v.toString();
    if (s.contains('T')) {
      final parts = s.split('T');
      final date = parts[0];
      final time = parts[1].split('.').first;
      return '$date $time';
    } else if (s.contains(' ')) {
      final parts = s.split(' ');
      if (parts.length >= 2) {
        return '${parts[0]} ${parts[1]}';
      }
    }
    return s;
  }

  String _fmtDateOnly(dynamic v) {
    if (v == null) return '--';
    final s = v.toString();
    if (s.contains(' ')) {
      return s.split(' ').first;
    }
    if (s.contains('T')) {
      return s.split('T').first;
    }
    return s;
  }

  /// Build "Asset + Expiry | OUTCOME $Strike" selection text for Bets Feed
  String _fmtSelection(
    dynamic ticker,
    dynamic expiry,
    dynamic outcome,
    dynamic strikePrice,
  ) {
    final t = ticker?.toString() ?? '--';
    final e = _fmtDateOnly(expiry);
    final oRaw = outcome?.toString() ?? '';
    final o = oRaw.isEmpty ? '--' : oRaw.toUpperCase();
    String strikeLabel;
    if (strikePrice == null) {
      strikeLabel = '--';
    } else {
      strikeLabel = '\$${_fmtAmount(strikePrice)}';
    }
    return "$t $e | $o $strikeLabel";
  }

  /// Extract / format Strike Price for a group row.
  /// Priority:
  /// 1) use group['strike_price'] if backend sends it
  /// 2) else try to parse first number from group['group'] string
  String _fmtStrikePriceFromGroup(
    String symbol,
    dynamic expiry,
    Map<String, dynamic> group,
  ) {
    // 1) Direct strike_price field
    if (group['strike_price'] != null) {
      final raw = group['strike_price'];
      final cleaned =
          raw is String ? raw.replaceAll(',', '').trim() : raw.toString();
      final num? n = num.tryParse(cleaned);
      if (n != null) {
        if (n == n.roundToDouble()) {
          return '\$${n.toStringAsFixed(0)}';
        }
        return '\$${n.toStringAsFixed(2)}';
      }
    }

    // 2) Fallback: try to read a number out of "group" label
    final label = group['group']?.toString() ?? '';
    final cleanedLabel = label.replaceAll(',', '');
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(cleanedLabel);
    if (match != null) {
      final raw = match.group(1);
      if (raw != null) {
        final num? n = num.tryParse(raw);
        if (n != null) {
          if (n == n.roundToDouble()) {
            return '\$${n.toStringAsFixed(0)}';
          }
          return '\$${n.toStringAsFixed(2)}';
        }
      }
    }

    return '--';
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel = _fromDate != null ? _formatDate(_fromDate!) : '';
    final toLabel = _toDate != null ? _formatDate(_toDate!) : '';

    final bool hasAnyFilter = _fromDate != null ||
        _toDate != null ||
        _stockController.text.trim().isNotEmpty ||
        _userController.text.trim().isNotEmpty ||
        _searchController.text.trim().isNotEmpty ||
        _activeOnly;

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      body: FutureBuilder<Map<String, dynamic>>(
        future: analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Failed to load analytics data",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                "No analytics data",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final data = snapshot.data!;

          final overall = Map<String, dynamic>.from(data['overall'] ?? {});
          final marketAnalytics =
              Map<String, dynamic>.from(data['market_analytics'] ?? {});
          final betsFeed = Map<String, dynamic>.from(data['bets_feed'] ?? {});
          final meta = Map<String, dynamic>.from(data['meta'] ?? {});

          // ---- OVERALL ----
          final dateRange =
              Map<String, dynamic>.from(overall['date_range'] ?? {});
          final int overallTotalBets = overall['total_bets_count'] is int
              ? overall['total_bets_count'] as int
              : int.tryParse('${overall['total_bets_count'] ?? 0}') ?? 0;

          final String effectiveStatusFilter =
              (overall['status_filter']?.toString().isNotEmpty ?? false)
                  ? overall['status_filter'].toString()
                  : statusFilter;

          final bool overallActiveOnly =
              overall['active_only'] == true || meta['active_only'] == true;

          final overallTopUsers =
              List<Map<String, dynamic>>.from(overall['top_users'] ?? []);
          final overallWorstUsers =
              List<Map<String, dynamic>>.from(overall['worst_users'] ?? []);

          final Map<String, dynamic>? topUser =
              overallTopUsers.isNotEmpty ? overallTopUsers.first : null;
          final Map<String, dynamic>? worstUser =
              overallWorstUsers.isNotEmpty ? overallWorstUsers.first : null;

          // Pending / settled aggregates if present
          final hasPendingAgg = overall.containsKey('total_wager_pending');
          final hasSettledAgg = overall.containsKey('total_wager_settled');

          final bool isPendingOverall =
              effectiveStatusFilter.toLowerCase() == 'pending';

          dynamic summaryHandle;
          dynamic summaryGgr;
          dynamic summaryHold;

          if (isPendingOverall && hasPendingAgg) {
            summaryHandle = overall['total_wager_pending'];
            summaryGgr = overall['potential_ggr'];
            summaryHold = overall['hold_percent_pending'];
          } else if (hasSettledAgg) {
            summaryHandle = overall['total_wager_settled'];
            summaryGgr = overall['settled_ggr'];
            summaryHold = overall['hold_percent_settled'];
          } else {
            summaryHandle =
                overall['total_wager_settled'] ?? overall['total_wager_pending'];
            summaryGgr = overall['settled_ggr'] ?? overall['potential_ggr'];
            summaryHold = overall['hold_percent_settled'] ??
                overall['hold_percent_pending'];
          }

          // ---- MARKET ANALYTICS ----
          final String? marketAnalyticsError =
              marketAnalytics['error']?.toString();
          final String? marketStatusFilter =
              marketAnalytics['status_filter']?.toString();
          final marketFilter =
              Map<String, dynamic>.from(marketAnalytics['date_filter'] ?? {});
          final assetsAnalytics =
              Map<String, dynamic>.from(marketAnalytics['data'] ?? {});

          final bool isPendingMarket =
              (marketStatusFilter ?? '').toLowerCase() == 'pending';

          // ---- BETS FEED ----
          final String? betsFeedError = betsFeed['error']?.toString();
          final int totalBetsCountFeed = betsFeed['count'] is int
              ? betsFeed['count'] as int
              : int.tryParse('${betsFeed['count'] ?? 0}') ?? 0;
          final int pageSizeFromApi = betsFeed['page_size'] is int
              ? betsFeed['page_size'] as int
              : int.tryParse('${betsFeed['page_size'] ?? _pageSize}') ??
                  _pageSize;

          final int computedPages = pageSizeFromApi > 0
              ? ((totalBetsCountFeed + pageSizeFromApi - 1) / pageSizeFromApi)
                  .ceil()
              : 1;

          final int totalPages = betsFeed['total_pages'] is int
              ? betsFeed['total_pages'] as int
              : int.tryParse('${betsFeed['total_pages'] ?? 0}') ??
                  computedPages;

          final betsResults =
              List<Map<String, dynamic>>.from(betsFeed['results'] ?? []);

          final String generatedAt = meta['generated_at']?.toString() ?? '--';
          final bool cached = meta['cached'] == true;

          final String ggrColumnLabel =
              isPendingOverall ? "Potential GGR" : "GGR";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- FILTERS ON TOP ----------------
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _DateFilterField(
                        label: "From Date",
                        value: fromLabel.isEmpty ? null : fromLabel,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: _DateFilterField( 
                        label: "To Date",
                        // NOTE: fromLabel/toLabel are intentionally swapped
                        value: toLabel.isEmpty ? null : toLabel,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                    
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: statusFilter,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'settled',
                            child: Text('Settled'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            statusFilter = value;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: CheckboxListTile(
                        value: _activeOnly,
                        dense: true,
                        title: const Text(
                          "Active only",
                          style: TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) {
                          setState(() {
                            _activeOnly = v ?? false;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                      child: const Text("Apply"),
                    ),
                    TextButton(
                      onPressed: hasAnyFilter ? _clearFilters : null,
                      child: const Text("Clear"),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _stockController,
                        decoration: InputDecoration(
                          labelText: 'Stock (ticker)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: 'User',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search (bets feed)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                    _applyFilters();
                                  },
                                ),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---- HEADER ----
                Text("Hello, Admin",
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900])),
                const SizedBox(height: 6),
                const Text("Here’s your latest platform summary.",
                    style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 8),

                // Date range + last updated + meta
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "Range: ${_fmtDateOnly(dateRange['from'])} → ${_fmtDateOnly(dateRange['to'])}",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const Spacer(),
                    Icon(Icons.update, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "Last updated: ${_fmtDateTime(overall['last_updated'])}",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.sports_mma,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "Total bets in range: ${_fmtInt(overallTotalBets)}",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.filter_alt_outlined,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "Status filter: ${effectiveStatusFilter.toUpperCase()}",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.flash_on,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "Active only: ${overallActiveOnly ? 'YES' : 'NO'}",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      "Generated at: $generatedAt • Cached: ${cached ? 'YES' : 'NO'}",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ---------------- OVERALL SNAPSHOT ----------------
                const _SectionHeader(title: "Overall Snapshot"),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    // Total bets in the selected date range
                    _GlassStatCard(
                      icon: Icons.sports_martial_arts,
                      label: "Total Bets (Range)",
                      value: _fmtInt(overallTotalBets),
                      gradient: _blueGradient,
                    ),

                    // Active users
                    _GlassStatCard(
                      icon: Icons.person,
                      label: "Active Users",
                      value: _fmtInt(overall['active_users']),
                      gradient: _greenGradient,
                    ),

                    // Inactive users
                    _GlassStatCard(
                      icon: Icons.person_off,
                      label: "Inactive Users",
                      value: _fmtInt(overall['inactive_users']),
                      gradient: _redGradient,
                    ),

                    if (hasPendingAgg)
                      _GlassStatCard(
                        icon: Icons.hourglass_top,
                        label: "Total Wager (Pending)",
                        value:
                            "\$${_fmtAmount(overall['total_wager_pending'])}",
                        gradient: _pinkYellowGradient,
                      ),
                    if (hasPendingAgg)
                      _GlassStatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: "Total Payout (Pending)",
                        value:
                            "\$${_fmtAmount(overall['total_payout_pending'])}",
                        gradient: _oceanGradient,
                      ),
                    if (hasPendingAgg)
                      _GlassStatCard(
                        icon: Icons.trending_down,
                        label: "Potential GGR",
                        value: "\$${_fmtAmount(overall['potential_ggr'])}",
                        gradient: _purpleGradient,
                      ),
                    if (hasPendingAgg)
                      _GlassStatCard(
                        icon: Icons.leaderboard_outlined,
                        label: "Hold % (Pending)",
                        value: _fmtPercent(overall['hold_percent_pending']),
                        gradient: _blueGradient,
                      ),

                    if (hasSettledAgg)
                      _GlassStatCard(
                        icon: Icons.check_circle_outline,
                        label: "Settled GGR",
                        value: "\$${_fmtAmount(overall['settled_ggr'])}",
                        gradient: _greenGradient,
                      ),
                    if (hasSettledAgg)
                      _GlassStatCard(
                        icon: Icons.account_balance,
                        label: "Total Wager (Settled)",
                        value:
                            "\$${_fmtAmount(overall['total_wager_settled'])}",
                        gradient: _pinkYellowGradient,
                      ),
                    if (hasSettledAgg)
                      _GlassStatCard(
                        icon: Icons.payments_outlined,
                        label: "Total Payout (Settled)",
                        value:
                            "\$${_fmtAmount(overall['total_payout_settled'])}",
                        gradient: _oceanGradient,
                      ),
                    if (hasSettledAgg)
                      _GlassStatCard(
                        icon: Icons.leaderboard,
                        label: "Hold % (Settled)",
                        value: _fmtPercent(overall['hold_percent_settled']),
                        gradient: _purpleGradient,
                      ),

                    // Top user by GGR (from overall.top_users)
                    if (topUser != null)
                      _GlassStatCard(
                        icon: Icons.emoji_events_outlined,
                        label: "Top User GGR (${topUser['username']})",
                        value: "\$${_fmtAmount(topUser['ggr'])}",
                        gradient: _purpleGradient,
                      ),

                    // Worst user by GGR (from overall.worst_users)
                    if (worstUser != null)
                      _GlassStatCard(
                        icon: Icons.trending_down,
                        label: "Worst User GGR (${worstUser['username']})",
                        value: "\$${_fmtAmount(worstUser['ggr'])}",
                        gradient: _oceanGradient,
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---- OVERALL TOP / WORST USERS (BY GGR) ----
                const _SectionHeader(title: "Overall Users (By GGR)"),
                const SizedBox(height: 12),
                _eCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 720;
                          return isNarrow
                              ? Column(
                                  children: [
                                    _OverallUsersTable(
                                      title: "Top Users",
                                      users: overallTopUsers,
                                      fmtAmount: _fmtAmount,
                                    ),
                                    const SizedBox(height: 16),
                                    _OverallUsersTable(
                                      title: "Worst Users",
                                      users: overallWorstUsers,
                                      fmtAmount: _fmtAmount,
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _OverallUsersTable(
                                        title: "Top Users",
                                        users: overallTopUsers,
                                        fmtAmount: _fmtAmount,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _OverallUsersTable(
                                        title: "Worst Users",
                                        users: overallWorstUsers,
                                        fmtAmount: _fmtAmount,
                                      ),
                                    ),
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- MARKET ANALYTICS ----------------
                const _SectionHeader(title: "Summary PnL & Market Analytics"),
                const SizedBox(height: 12),
                _eCard(
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded:
                          marketAnalyticsError == null &&
                              assetsAnalytics.isNotEmpty,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const _TileTitle(
                        icon: Icons.trending_up,
                        title: "Summary PnL Overview",
                      ),
                      trailing: const _TileChevron(),
                      children: [
                        const SizedBox(height: 8),

                        if (marketAnalyticsError != null &&
                            marketAnalyticsError.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  marketAnalyticsError,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ] else if (assetsAnalytics.isEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "No market analytics data available for this date range.",
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.filter_alt,
                                  size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                "Filter: ${_fmtDateOnly(marketFilter['from'])} → ${_fmtDateOnly(marketFilter['to'])} • Status: ${(marketStatusFilter ?? '').toUpperCase()}",
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Top summary row: Total Bets / Handle / GGR / Hold %
                          const Text(
                            "Summary PnL (Holistic View)",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text("Total Bets")),
                                DataColumn(label: Text("Total Handle")),
                                DataColumn(label: Text("Total GGR")),
                                DataColumn(label: Text("Total Hold %")),
                              ],
                              rows: [
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(_fmtInt(overallTotalBets)),
                                    ),
                                    DataCell(
                                      Text(
                                        "\$${_fmtAmount(summaryHandle)}",
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "\$${_fmtAmount(summaryGgr)}",
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _fmtPercent(summaryHold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "Asset PnL by Expiry",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 8),

                          // Asset + Expiry table (AAPL 11/7/2025 style)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text("Asset")),
                                DataColumn(label: Text("Expiry Date")),
                                DataColumn(label: Text("# of Bets")),
                                DataColumn(label: Text("Handle")),
                                DataColumn(label: Text("GGR")),
                                DataColumn(label: Text("Hold %")),
                              ],
                              rows: assetsAnalytics.entries.expand((entry) {
                                final symbol = entry.key;
                                final assetData = Map<String, dynamic>.from(
                                    entry.value ?? {});
                                final expiries = Map<String, dynamic>.from(
                                    assetData['expiries'] ?? {});
                                if (expiries.isEmpty) {
                                  final totals = Map<String, dynamic>.from(
                                      assetData['totals'] ?? {});
                                  final dynamic ggrValue =
                                      totals['realized_ggr'] ??
                                          totals['potential_ggr'];
                                  return [
                                    DataRow(
                                      cells: [
                                        DataCell(Text(symbol)),
                                        const DataCell(Text("--")),
                                        DataCell(
                                            Text(_fmtInt(totals['num_bets']))),
                                        DataCell(Text(
                                            "\$${_fmtAmount(totals['handle'])}")),
                                        DataCell(Text(
                                            "\$${_fmtAmount(ggrValue)}")),
                                        DataCell(Text(_fmtPercent(
                                            totals['hold_percent']))),
                                      ],
                                    ),
                                  ];
                                }
                                return expiries.entries.map((expEntry) {
                                  final expiry = expEntry.key;
                                  final expData = Map<String, dynamic>.from(
                                      expEntry.value ?? {});
                                  final expTotals = Map<String, dynamic>.from(
                                      expData['totals'] ?? {});
                                  final dynamic expGgr =
                                      expTotals['realized_ggr'] ??
                                          expTotals['potential_ggr'];
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(symbol)),
                                      DataCell(Text(_fmtDateOnly(expiry))),
                                      DataCell(Text(
                                          _fmtInt(expTotals['num_bets']))),
                                      DataCell(Text(
                                          "\$${_fmtAmount(expTotals['handle'])}")),
                                      DataCell(
                                          Text("\$${_fmtAmount(expGgr)}")),
                                      DataCell(Text(_fmtPercent(
                                          expTotals['hold_percent']))),
                                    ],
                                  );
                                });
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          const Text(
                            "Expiry & Strike Groups",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 8),

                          // Expiries + groups per asset
                          ...assetsAnalytics.entries.map((entry) {
                            final symbol = entry.key;
                            final assetData =
                                Map<String, dynamic>.from(entry.value ?? {});
                            final expiries = Map<String, dynamic>.from(
                                assetData['expiries'] ?? {});
                            if (expiries.isEmpty) {
                              return Container();
                            }
                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                symbol,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5),
                              ),
                              children: [
                                const SizedBox(height: 4),
                                ...expiries.entries.map((expEntry) {
                                  final expiry = expEntry.key;
                                  final expData = Map<String, dynamic>.from(
                                      expEntry.value ?? {});
                                  final expTotals = Map<String, dynamic>.from(
                                      expData['totals'] ?? {});
                                  final groups =
                                      List<Map<String, dynamic>>.from(
                                          expData['groups'] ?? []);
                                  final dynamic expGgr =
                                      expTotals['realized_ggr'] ??
                                          expTotals['potential_ggr'];

                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff9fafb),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xffeef0f2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.event,
                                                size: 18,
                                                color: Colors.black54),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Expiry: $expiry",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const Spacer(),
                                            Text(
                                              "Bets: ${_fmtInt(expTotals['num_bets'])} • Handle: \$${_fmtAmount(expTotals['handle'])} • GGR: \$${_fmtAmount(expGgr)} • Hold: ${_fmtPercent(expTotals['hold_percent'])}",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(
                                                  label: Text("Asset")),
                                              DataColumn(
                                                  label:
                                                      Text("Expiry Date")),
                                              DataColumn(
                                                  label:
                                                      Text("Strike Price")),
                                              DataColumn(
                                                  label: Text("# of Bets")),
                                              DataColumn(
                                                  label: Text("Handle")),
                                              DataColumn(
                                                  label: Text("GGR")),
                                              DataColumn(
                                                  label: Text("Hold %")),
                                            ],
                                            rows: [
                                              // One row per strike/group
                                              ...groups.map((g) {
                                                final dynamic groupGgr =
                                                    g['realized_ggr'] ??
                                                        g['potential_ggr'];

                                                final strikeText =
                                                    _fmtStrikePriceFromGroup(
                                                  symbol,
                                                  expiry,
                                                  g,
                                                );

                                                return DataRow(
                                                  cells: [
                                                    // Asset
                                                    DataCell(Text(symbol)),
                                                    // Expiry Date
                                                    DataCell(Text(
                                                        _fmtDateOnly(
                                                            expiry))),
                                                    // Strike Price
                                                    DataCell(
                                                        Text(strikeText)),
                                                    // # of Bets
                                                    DataCell(Text(_fmtInt(
                                                        g['num_bets']))),
                                                    // Handle
                                                    DataCell(Text(
                                                        "\$${_fmtAmount(g['handle'])}")),
                                                    // GGR
                                                    DataCell(Text(
                                                        "\$${_fmtAmount(groupGgr)}")),
                                                    // Hold %
                                                    DataCell(Text(_fmtPercent(
                                                        g['hold_percent']))),
                                                  ],
                                                );
                                              }).toList(),

                                              // Sum row
                                              DataRow(
                                                cells: [
                                                  const DataCell(
                                                    Text(
                                                      "Sum",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700),
                                                    ),
                                                  ),
                                                  const DataCell(Text("")),
                                                  const DataCell(Text("")),
                                                  DataCell(
                                                    Text(
                                                      _fmtInt(expTotals[
                                                          'num_bets']),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      "\$${_fmtAmount(expTotals['handle'])}",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      "\$${_fmtAmount(expGgr)}",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      _fmtPercent(expTotals[
                                                          'hold_percent']),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- BETS FEED ----------------
                const _SectionHeader(title: "Bets Feed"),
                const SizedBox(height: 12),
                _eCard(
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const _TileTitle(
                          icon: Icons.feed, title: "Bets Feed"),
                      trailing: const _TileChevron(),
                      children: [
                        const SizedBox(height: 12),

                        if (betsFeedError != null &&
                            betsFeedError.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  betsFeedError,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ] else if (betsResults.isEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "No bets found for this date range / filters.",
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: Scrollbar(
                              controller: _horizontalController,
                              thumbVisibility: true,
                              notificationPredicate: (n) =>
                                  n.metrics.axis == Axis.horizontal,
                              child: SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    const DataColumn(
                                        label: Text("Bet Time")),
                                    const DataColumn(
                                        label: Text("Patron")),
                                    const DataColumn(label: Text("CRS")),
                                    const DataColumn(label: Text("Bet #")),
                                    const DataColumn(label: Text("Asset")),
                                    const DataColumn(
                                        label: Text(
                                            "Selection (Expiry, Strike)")),
                                    const DataColumn(label: Text("Wager")),
                                    const DataColumn(
                                        label: Text("Odds (Dec)")),
                                    const DataColumn(
                                        label: Text("% Max Wager")),
                                    const DataColumn(
                                        label: Text("Potential Payout")),
                                    DataColumn(label: Text(ggrColumnLabel)),
                                    const DataColumn(label: Text("Status")),
                                    const DataColumn(
                                        label: Text("Allowable Profit")),
                                    const DataColumn(
                                        label: Text("Settled At")),
                                  ],
                                  rows: betsResults.map((bet) {
                                    final odds = Map<String, dynamic>.from(
                                        bet['odds'] ?? {});
                                    final username =
                                        bet['username']?.toString();
                                    final dynamic strikePrice =
                                        bet['strike_price'];
                                    final dynamic allowableProfit =
                                        bet['allowable_profit'];

                                    return DataRow(
                                      cells: [
                                        // Bet Time
                                        DataCell(Text(
                                            _fmtDateTime(bet['created_at']))),

                                        // Patron (clickable)
                                        DataCell(
                                          MouseRegion(
                                            cursor:
                                                SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (username != null &&
                                                    username.isNotEmpty) {
                                                  context.go(
                                                      '/dashboard/user_details/$username');
                                                }
                                              },
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                      Icons.person_outline,
                                                      size: 18,
                                                      color: Colors.blue),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    username ?? "N/A",
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // CRS
                                        DataCell(Text(_fmtInt(
                                            bet['crs_risk_score']))),

                                        // Bet #
                                        DataCell(Text("${bet['bet_id']}")),

                                        // Asset
                                        DataCell(Text(
                                            bet['ticker']?.toString() ??
                                                "--")),

                                        // Selection (Expiry, Strike)
                                        DataCell(
                                          Text(
                                            _fmtSelection(
                                              bet['ticker'],
                                              bet['expiry_date'],
                                              bet['chosen_outcome'],
                                              strikePrice,
                                            ),
                                          ),
                                        ),

                                        // Wager
                                        DataCell(
                                          Text(
                                              "\$${_fmtAmount(bet['stake'])}"),
                                        ),

                                        // Odds (Dec)
                                        DataCell(
                                          Text(
                                            odds['decimal']?.toString() ??
                                                "--",
                                          ),
                                        ),

                                        // % Max Wager
                                        DataCell(
                                          Text(_fmtPercent(
                                              bet['max_wager_pct'])),
                                        ),

                                        // Potential Payout
                                        DataCell(
                                          Text(
                                              "\$${_fmtAmount(bet['potential_payout'])}"),
                                        ),

                                        // GGR / Potential GGR
                                        DataCell(
                                          Text(
                                              "\$${_fmtAmount(bet['ggr'])}"),
                                        ),

                                        // Status
                                        DataCell(
                                          _StatusTag(
                                            text: bet['status']
                                                    ?.toString() ??
                                                "--",
                                          ),
                                        ),

                                        // Allowable Profit
                                        DataCell(
                                          Text(
                                            allowableProfit == null
                                                ? "--"
                                                : "\$${_fmtAmount(allowableProfit)}",
                                          ),
                                        ),

                                        // Settled At
                                        DataCell(Text(
                                            _fmtDateTime(bet['settled_at']))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: currentPage > 1
                                    ? () => _goToPage(currentPage - 1)
                                    : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Previous"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                  "Page $currentPage of ${totalPages <= 0 ? 1 : totalPages}"),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: (currentPage <
                                        (totalPages <= 0
                                            ? 1
                                            : totalPages))
                                    ? () => _goToPage(currentPage + 1)
                                    : null,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text("Next"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SMALL HELPERS
// -----------------------------------------------------------------------------
Widget _eCard({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    child: child,
  );
}

class _TileTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _TileTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _TileChevron extends StatelessWidget {
  const _TileChevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.expand_more, color: Colors.black54);
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff3f4f6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe5e7eb)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade800),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String text;
  const _StatusTag({required this.text});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xfff3f4f6);
    Color fg = Colors.black87;
    final t = text.toLowerCase();
    if (t.contains('live') || t.contains('active')) {
      bg = const Color(0xffe8faf0);
      fg = const Color(0xff117a39);
    } else if (t.contains('settled') ||
        t.contains('completed') ||
        t.contains('won') ||
        t.contains('lost')) {
      bg = const Color(0xffe6f0ff);
      fg = const Color(0xff1f3d8a);
    } else if (t.contains('pending')) {
      bg = const Color(0xfffff7e6);
      fg = const Color(0xff8a6d1f);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

// Overall users (simple table)
class _OverallUsersTable extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final String Function(dynamic) fmtAmount;

  const _OverallUsersTable({
    required this.title,
    required this.users,
    required this.fmtAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.black87)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text("User ID")),
              DataColumn(label: Text("Patron")),
              DataColumn(label: Text("GGR")),
            ],
            rows: users.map((u) {
              final username = u["username"];
              return DataRow(
                cells: [
                  DataCell(Text("${u['user_id']}")),
                  DataCell(
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (username != null &&
                              username.toString().isNotEmpty) {
                            context.go('/dashboard/user_details/$username');
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              username ?? "N/A",
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text("\$${fmtAmount(u['ggr'])}")),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// Date filter field
class _DateFilterField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateFilterField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value == null || value!.isEmpty ? 'Select date' : value!,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GRADIENTS
// -----------------------------------------------------------------------------
const _blueGradient =
    LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]);
const _greenGradient =
    LinearGradient(colors: [Color(0xFF43e97b), Color(0xFF38f9d7)]);
const _pinkYellowGradient =
    LinearGradient(colors: [Color(0xFFfa709a), Color(0xFFfee140)]);
const _purpleGradient =
    LinearGradient(colors: [Color(0xFFa18cd1), Color(0xFFfbc2eb)]);
const _oceanGradient =
    LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]);
const _redGradient =
    LinearGradient(colors: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)]);

// -----------------------------------------------------------------------------
// GLASS STAT CARD WIDGET
// -----------------------------------------------------------------------------
class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Gradient gradient;

  const _GlassStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(18),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const Spacer(),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION HEADER WIDGET
// -----------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87));
  }
}

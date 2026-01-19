import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper model for table rows (label, value, optional trailing widget)
class _SummaryRowItem {
  final String label;
  final String? value;
  final Widget? trailing;

  const _SummaryRowItem(this.label, this.value, {this.trailing});
}

class UserDetails extends StatefulWidget {
  final String username;

  const UserDetails({super.key, required this.username});

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  // Main data for each tab
  Map<String, dynamic>? settledData; // single user object for settled
  Map<String, dynamic>? pendingData; // single user object for pending

  // Summary blocks (date_range, total_users, crs_distribution, etc.)
  Map<String, dynamic>? settledSummary;
  Map<String, dynamic>? pendingSummary;

  bool loading = true;

  int? userId;
  double? crsScore;

  // Date filters
  DateTime? _fromDate;
  DateTime? _toDate;
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  final String baseUrl =
      "https://api.bbbprediction.com/";

  @override
  void initState() {
    super.initState();

    // Default date range: last 60 days until today
    final now = DateTime.now();
    _toDate = now;
    _fromDate = now.subtract(const Duration(days: 60));

    fetchAll(
      widget.username,
      from: _fromDate,
      to: _toDate,
    );
  }

  /* ----------------------------------------------------
     MASTER FETCH (with optional date range)
  ---------------------------------------------------- */
  Future<void> fetchAll(
    String username, {
    DateTime? from,
    DateTime? to,
  }) async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        setState(() => loading = false);
        return;
      }

      final dio = Dio()
        ..options.baseUrl = baseUrl
        ..options.headers = {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        };

      String settledUrl =
          "admin_panel/analytics/user-dashboard/?user=$username&status=settled";
      String pendingUrl =
          "admin_panel/analytics/user-dashboard/?user=$username&status=pending";

      if (from != null) {
        final fromStr = _apiDateFormat.format(from);
        settledUrl += "&date_from=$fromStr";
        pendingUrl += "&date_from=$fromStr";
      }
      if (to != null) {
        final toStr = _apiDateFormat.format(to);
        settledUrl += "&date_to=$toStr";
        pendingUrl += "&date_to=$toStr";
      }

      final responses = await Future.wait([
        dio.get(settledUrl),
        dio.get(pendingUrl),
      ]);

      print("Single User response (settled):");
      print(responses[0].data);
      print("Single User response (pending):");
      print(responses[1].data);

      // ---- SETTLED SUMMARY + USERS ----
      final sSummaryRaw =
          responses[0].data['user_summary'] as Map<String, dynamic>?;
      final pSummaryRaw =
          responses[1].data['user_summary'] as Map<String, dynamic>?;

      settledSummary =
          sSummaryRaw != null ? Map<String, dynamic>.from(sSummaryRaw) : null;
      pendingSummary =
          pSummaryRaw != null ? Map<String, dynamic>.from(pSummaryRaw) : null;

      final settledUsers =
          (settledSummary?['users'] as List<dynamic>?) ?? <dynamic>[];
      final pendingUsers =
          (pendingSummary?['users'] as List<dynamic>?) ?? <dynamic>[];

      settledData = settledUsers.isNotEmpty
          ? Map<String, dynamic>.from(settledUsers[0] as Map)
          : null;

      pendingData = pendingUsers.isNotEmpty
          ? Map<String, dynamic>.from(pendingUsers[0] as Map)
          : null;

      userId = settledData?['user_id'] ?? pendingData?['user_id'];

      if (userId != null) {
        await fetchCrsScore(userId!);
      }

      setState(() => loading = false);
    } catch (e) {
      print("Fetch error: $e");
      setState(() => loading = false);
    }
  }

  String _formatFullTimestamp(dynamic iso) {
    if (iso == null) return "--";
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return iso.toString();
    }
  }

  String _formatStatusLabel(String? status) {
    switch (status) {
      case "pending":
        return "Live";
      case "won":
        return "Settled - Won";
      case "lost":
        return "Settled - Lost";
      case "void":
        return "Voided";
      case "settled":
        return "Settled";
      default:
        return status ?? "N/A";
    }
  }

  /* ----------------------------------------------------
     CRS APIs
  ---------------------------------------------------- */

  Future<void> fetchCrsScore(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return;

      final dio = Dio()
        ..options.baseUrl = baseUrl
        ..options.headers = {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        };

      final response = await dio.get("admin_panel/crs/?user_id=$id");

      print("CRS Response");
      print(response.data);

      if (response.data['success'] == true) {
        crsScore = double.tryParse(
          response.data['data']['crs_risk_score'].toString(),
        );
      }
    } catch (e) {
      print("CRS fetch error: $e");
    }
  }

  Future<void> updateCrsDialog() async {
    final controller =
        TextEditingController(text: crsScore?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update CRS Score"),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "New CRS",
            hintText: "Example: 0.95",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newScore = double.tryParse(controller.text.trim());
              if (newScore == null || userId == null) return;

              Navigator.of(context, rootNavigator: true).pop();
              await updateCrs(userId!, newScore);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> updateCrs(int id, double score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return;

      final dio = Dio()
        ..options.baseUrl = baseUrl
        ..options.headers = {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        };

      final response = await dio.post(
        "admin_panel/crs/",
        data: {"user_id": id, "new_crs": score},
      );

      if (response.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'])),
        );
        // Re-fetch with current filters
        fetchAll(
          widget.username,
          from: _fromDate,
          to: _toDate,
        );
      }
    } catch (e) {
      print("CRS update error: $e");
    }
  }

  /* ----------------------------------------------------
     DATE FILTER HANDLERS
  ---------------------------------------------------- */

  Future<void> _pickFromDate() async {
    final initial =
        _fromDate ?? DateTime.now().subtract(const Duration(days: 60));
    final last = _toDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: last,
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
      });
    }
  }

  Future<void> _pickToDate() async {
    final initial = _toDate ?? DateTime.now();
    final first = _fromDate ?? DateTime(2024);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  void _onApplyFilter() {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both From and To dates'),
        ),
      );
      return;
    }

    fetchAll(
      widget.username,
      from: _fromDate,
      to: _toDate,
    );
  }

  void _onResetFilter() {
    final now = DateTime.now();
    setState(() {
      _toDate = now;
      _fromDate = now.subtract(const Duration(days: 60));
    });

    fetchAll(
      widget.username,
      from: _fromDate,
      to: _toDate,
    );
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /* ----------------------------------------------------
     UI
  ---------------------------------------------------- */

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.8,
          title: Text(
            'Details of ${widget.username}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Settled"),
              Tab(text: "Pending"),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildDateFilterBar(),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : TabBarView(
                      children: [
                        _buildUserTab(
                          settledSummary,
                          settledData,
                          false,
                        ),
                        _buildUserTab(
                          pendingSummary,
                          pendingData,
                          true,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          _dateField(
            label: 'From',
            value: _formatDateLabel(_fromDate),
            onTap: _pickFromDate,
          ),
          const SizedBox(width: 12),
          _dateField(
            label: 'To',
            value: _formatDateLabel(_toDate),
            onTap: _pickToDate,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _onApplyFilter,
            icon: const Icon(Icons.search, size: 18, color: Colors.black),
            label: const Text(
              'Apply',
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _onResetFilter,
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTab(
    Map<String, dynamic>? summary,
    Map<String, dynamic>? data,
    bool isPending,
  ) {
    final crsDist =
        (summary?['crs_distribution'] as List<dynamic>?) ?? [];

    if (data == null) {
      // Show filter summary + "no data"
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            if (summary != null)
              _section("Filter Summary", [
                _filterSummaryDataTable(summary),
                if (crsDist.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _crsDistributionRow(crsDist),
                ],
              ]),
            const SizedBox(height: 32),
            const Center(child: Text("No data available for this filter")),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          if (summary != null)
            _section("Filter Summary", [
              _filterSummaryDataTable(summary),
              if (crsDist.isNotEmpty) ...[
                const SizedBox(height: 12),
                _crsDistributionRow(crsDist),
              ],
            ]),
          _section(
            "Account Info",
            [
              _accountInfoDataTable(data),
            ],
          ),
          _section("Financial Summary", [
            _financialSummaryDataTable(data, isPending),
          ]),
          _section(
            "Recent Bets (by Asset)",
            _buildBetsTable(data['recent_bets_by_asset'], isPending),
          ),
        ],
      ),
    );
  }

  Widget _crsDistributionRow(List<dynamic> dist) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CRS DISTRIBUTION",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: dist.map<Widget>((item) {
              final map = Map<String, dynamic>.from(item as Map);
              final level = map['crs_risk_level']?.toString() ?? '--';
              final count = map['count']?.toString() ?? '0';
              return Chip(
                label: Text("$level ($count)"),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// OLD: label/value table (kept for compatibility, not used now)
  Widget _keyValueTable(List<_SummaryRowItem> items) {
    if (items.isEmpty) {
      return const Text("No data");
    }

    return SizedBox(
      width: double.infinity, // <- 100% width inside section card
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
          2: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: items.map((item) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  item.label.toUpperCase(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    item.value ?? '--',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: item.trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// NEW: Filter Summary as DataTable (labels as columns, values in one row)
  Widget _filterSummaryDataTable(Map<String, dynamic> summary) {
    final dateRange =
        summary['date_range'] as Map<String, dynamic>?;

    final statusFilter = summary['status_filter']?.toString() ?? '--';
    final from = dateRange?['from']?.toString() ?? '--';
    final to = dateRange?['to']?.toString() ?? '--';
    final totalUsers = summary['total_users']?.toString() ?? '--';

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Status Filter")),
            DataColumn(label: Text("From Date")),
            DataColumn(label: Text("To Date")),
            DataColumn(label: Text("Total Users in Range")),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(Text(statusFilter)),
                DataCell(Text(from)),
                DataCell(Text(to)),
                DataCell(Text(totalUsers)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// NEW: Account Info as a full-width DataTable (labels as columns, values in one row)
  Widget _accountInfoDataTable(Map<String, dynamic> data) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Username")),
            DataColumn(label: Text("Email")),
            DataColumn(label: Text("KYC Status")),
            DataColumn(label: Text("CRS Level")),
            DataColumn(label: Text("CRS Score")),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(
                  Text(
                    data['username']?.toString() ?? '--',
                  ),
                ),
                DataCell(
                  Text(
                    data['email']?.toString() ?? '--',
                  ),
                ),
                DataCell(
                  Text(
                    data['kyc_status']?.toString() ?? '--',
                  ),
                ),
                DataCell(
                  Text(
                    data['crs_risk_level']?.toString() ?? '--',
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        crsScore != null
                            ? crsScore!.toStringAsFixed(2)
                            : '--',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Edit CRS Score',
                        onPressed: updateCrsDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// NEW: Financial Summary as DataTable
  Widget _financialSummaryDataTable(
      Map<String, dynamic> data, bool isPending) {
    final balance = data['balance']?.toString() ?? '--';
    final totalHandle = data['total_handle']?.toString() ?? '--';
    final payoutValue = isPending
        ? (data['potential_total_payout']?.toString() ?? '--')
        : (data['total_payout']?.toString() ?? '--');
    final ggrValue = isPending
        ? (data['potential_ggr']?.toString() ?? '--')
        : (data['realized_ggr']?.toString() ?? '--');
    final holdPercent = data['hold_percent']?.toString() ?? '--';
    final totalBets = data['total_bets']?.toString() ?? '--';

    final payoutLabel = isPending ? "Potential Payout" : "Total Payout";
    final ggrLabel = isPending ? "Potential GGR" : "Realized GGR";

    String _money(String v) =>
        v == '--' ? '\$--' : '\$$v';

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text("Balance")),
            const DataColumn(label: Text("Total Handle")),
            DataColumn(label: Text(payoutLabel)),
            DataColumn(label: Text(ggrLabel)),
            const DataColumn(label: Text("Hold %")),
            const DataColumn(label: Text("Total Bets")),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(Text(_money(balance))),
                DataCell(Text(_money(totalHandle))),
                DataCell(Text(_money(payoutValue))),
                DataCell(Text(_money(ggrValue))),
                DataCell(Text(holdPercent == '--' ? '--' : '$holdPercent%')),
                DataCell(Text(totalBets)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Kept for compatibility (not used in UI flow)
  Widget _crsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "CRS SCORE",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                crsScore?.toStringAsFixed(2) ?? '--',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: updateCrsDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBetsTable(dynamic list, bool isPending) {
    if (list == null || list is! List || list.isEmpty) {
      return const [Text("No recent bets")];
    }

    final List<DataRow> rows = [];

    for (final item in list) {
      final asset = Map<String, dynamic>.from(item as Map);
      final assetSymbol = asset['asset_symbol']?.toString() ?? '--';
      final crsByAsset = asset['crs_by_asset']?.toString() ?? '--';
      final totalBetsAsset =
          asset['total_bets_asset']?.toString() ?? '--';
      final maxPercentWager =
          asset['max_percent_wager']?.toString() ?? '--';

      final bets = (asset['most_recent_bets'] as List<dynamic>?) ??
          (asset['most_recent_bet'] != null
              ? [asset['most_recent_bet']]
              : <dynamic>[]);

      if (bets.isEmpty) {
        rows.add(
          DataRow(
            cells: [
              DataCell(Text(assetSymbol)),
              DataCell(Text(crsByAsset)),
              DataCell(Text(totalBetsAsset)),
              DataCell(Text(maxPercentWager)),
              const DataCell(Text('--')),
              const DataCell(Text('--')),
              const DataCell(Text('--')),
              const DataCell(Text('--')),
              const DataCell(Text('\$--')),
              const DataCell(Text('--')),
              const DataCell(Text('\$--')),
              const DataCell(Text('\$--')),
              const DataCell(Text('--')),
              const DataCell(Text('--')),
            ],
          ),
        );
        continue;
      }

      for (final betItem in bets) {
        final bet = Map<String, dynamic>.from(betItem as Map);
        final betId = bet['bet_id']?.toString() ?? '--';
        final betTime = _formatFullTimestamp(bet['bet_time']);
        final category = bet['category']?.toString() ?? '--';
        final selection = bet['selection']?.toString() ?? '--';
        final wager = bet['wager']?.toString() ?? '--';
        final status = bet['status']?.toString() ?? '--';
        final odds = bet['odds_at_placement']?.toString() ?? '--';
        final legs = bet['no_of_legs']?.toString() ?? '--';

        final payoutValue = isPending
            ? bet['potential_payout']?.toString()
            : bet['payout']?.toString();
        final ggrValue = isPending
            ? bet['potential_ggr']?.toString()
            : bet['realized_ggr']?.toString();

        rows.add(
          DataRow(
            cells: [
              DataCell(Text(assetSymbol)),
              DataCell(Text(crsByAsset)),
              DataCell(Text(totalBetsAsset)),
              DataCell(Text(maxPercentWager)),
              DataCell(Text(betId)),
              DataCell(Text(betTime)),
              DataCell(Text(category)),
              DataCell(Text(selection)),
              DataCell(Text("\$${wager == '--' ? '--' : wager}")),
              DataCell(Text(odds)),
              DataCell(Text("\$${payoutValue ?? '--'}")),
              DataCell(Text("\$${ggrValue ?? '--'}")),
              DataCell(Text(_formatStatusLabel(status))),
              DataCell(Text(legs)),
            ],
          ),
        );
      }
    }

    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Asset")),
            DataColumn(label: Text("CRS")),
            DataColumn(label: Text("Total Bets")),
            DataColumn(label: Text("Wager %")),
            DataColumn(label: Text("Bet ID")),
            DataColumn(label: Text("Placed At")),
            DataColumn(label: Text("Category")),
            DataColumn(label: Text("Selection")),
            DataColumn(label: Text("Wager")),
            DataColumn(label: Text("Odds")),
            DataColumn(label: Text("Payout")),
            DataColumn(label: Text("GGR")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("Legs")),
          ],
          rows: rows,
        ),
      ),
    ];
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _row(String label, String? value) {
    // Not used now, but keeping in case you reuse it.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 13),
          ),
          Flexible(
            child: Text(
              value ?? '--',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

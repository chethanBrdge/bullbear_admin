import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
class SettlementsScreen extends StatefulWidget {
  const SettlementsScreen({super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  List<dynamic> settlements = [];
  bool loading = true;

  // Dialog control
  bool showSettleDialog = false;
  String? selectedStatus = 'won';
  int? selectedBetId;

  // Pagination state (from API: count, next, previous)
  int currentPage = 1;
  int? totalCount;
  String? nextUrl;
  String? prevUrl;
  int pageSize = 0;

  @override
  void initState() {
    super.initState();
    fetchSettlements(page: currentPage);
  }

  Future<void> fetchSettlements({int page = 1}) async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      dio.options.baseUrl =
          "https://www.bbbprediction.com";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final res = await dio.get(
        "/admin_panel/bet-settlements/",
        queryParameters: {"page": page},
      );
      debugPrint("Settlements:");
      debugPrint(res.data.toString());

      final data = Map<String, dynamic>.from(res.data as Map);
      final results = List<dynamic>.from(data['results'] ?? []);

      setState(() {
        settlements = results;
        totalCount = data['count'] as int?;
        nextUrl = data['next']?.toString();
        prevUrl = data['previous']?.toString();
        pageSize = results.isNotEmpty ? results.length : pageSize;
        currentPage = page;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      debugPrint("Error fetching settlements: $e");
    }
  }

  Future<void> settleBet() async {
    if (selectedBetId == null || selectedStatus == null) return;

    setState(() => showSettleDialog = false);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      dio.options.baseUrl =
          "https://www.bbbprediction.com";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final response = await dio.post(
        "/admin_panel/bets/$selectedBetId/settle/",
        data: {"status": selectedStatus},
      );

      debugPrint("Settlement Response: ${response.data}");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Success: ${response.data}")),
      );
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['error'] ?? "Something went wrong";
      debugPrint("Error Response: $errorMessage");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $errorMessage")),
      );
    }

    // Refresh the current page after settlement
    setState(() => loading = true);
    await fetchSettlements(page: currentPage);
  }

  int _computeNumPages() {
    if (totalCount == null || (pageSize <= 0 && settlements.isEmpty)) {
      return currentPage;
    }
    final effectiveSize = pageSize > 0 ? pageSize : settlements.length;
    if (effectiveSize == 0) return currentPage;
    return ((totalCount ?? settlements.length) + effectiveSize - 1) ~/ effectiveSize;
  }

  @override
  Widget build(BuildContext context) {
    final numPages = _computeNumPages();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header + meta info
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Bet Settlements",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Total groups: ${settlements.length} • Total bets (count): ${totalCount ?? '--'}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                              ),
                            ),
                            const Divider(height: 1),

                            // Groups + bets list
                            Expanded(
                              child: settlements.isEmpty
                                  ? const Center(
                                      child: Text("No settlement groups found."),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: settlements.length,
                                      itemBuilder: (context, index) {
                                        final group = Map<String, dynamic>.from(
                                            settlements[index] as Map);
                                        return _SettlementGroupCard(
                                          group: group,
                                          onSettlePressed: (betId) {
                                            setState(() {
                                              selectedBetId = betId;
                                              selectedStatus = 'won';
                                              showSettleDialog = true;
                                            });
                                          },
                                        );
                                      },
                                    ),
                            ),

                            // Pagination controls
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.black12, width: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: (!loading &&
                                            currentPage > 1 &&
                                            prevUrl != null)
                                        ? () => fetchSettlements(
                                              page: currentPage - 1,
                                            )
                                        : null,
                                    icon: const Icon(Icons.arrow_back, size: 16),
                                    label: const Text("Previous"),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    "Page $currentPage of $numPages",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    onPressed: (!loading && nextUrl != null)
                                        ? () => fetchSettlements(
                                              page: currentPage + 1,
                                            )
                                        : null,
                                    icon:
                                        const Icon(Icons.arrow_forward, size: 16),
                                    label: const Text("Next"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),

          // Settle Dialog overlay
          if (showSettleDialog)
            Container(
              color: Colors.black.withOpacity(0.3),
              alignment: Alignment.center,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Settle Bet",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'won', child: Text("Won")),
                        DropdownMenuItem(value: 'lost', child: Text("Lost")),
                        DropdownMenuItem(value: 'void', child: Text("Void")),
                      ],
                      onChanged: (value) {
                        setState(() => selectedStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => showSettleDialog = false);
                          },
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: settleBet,
                          child: const Text("Submit"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
 

// -----------------------------------------------------------------------------
// Group Card + Bets Table
// -----------------------------------------------------------------------------
class _SettlementGroupCard extends StatefulWidget {
  final Map<String, dynamic> group;
  final void Function(int betId) onSettlePressed;

  const _SettlementGroupCard({
    required this.group,
    required this.onSettlePressed,
  });

  @override
  State<_SettlementGroupCard> createState() => _SettlementGroupCardState();
}

class _SettlementGroupCardState extends State<_SettlementGroupCard> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  // Can settle only if:
  // - status == 'pending'
  // - settled_at is null / empty
  // - expiry date is before now
  bool _canSettle({
    required String? expiryDateStr,
    required String? status,
    required String? settledAt,
  }) {
    if (status == null) return false;
    final statusLower = status.toLowerCase();

    // Only pending bets can be settled
    if (statusLower != 'pending') return false;

    // If it already has a settled_at value, do NOT allow settlement again
    if (settledAt != null &&
        settledAt.isNotEmpty &&
        settledAt.toLowerCase() != 'null') {
      return false;
    }

    if (expiryDateStr == null || expiryDateStr.isEmpty) return false;

    try {
      final date = DateTime.parse(expiryDateStr);
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  // Money formatter with $ prefix
  String _fmtMoney(dynamic v) {
    if (v == null) return "\$0";
    final num n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    if (n % 1 == 0) {
      return "\$${n.toInt()}";
    }
    return "\$${n.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> group = widget.group;

    final String title = group['group_title']?.toString() ?? 'N/A';
    final int totalBets = group['total_bets'] ?? 0;
    final dynamic handleRaw = group['total_handle'];
    final dynamic payoutRaw = group['total_payout'];

    final List<dynamic> betsRaw = group['bets'] ?? [];
    final List<Map<String, dynamic>> bets =
        betsRaw.map((b) => Map<String, dynamic>.from(b as Map)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff9fafb),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe5e7eb)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _InfoChip(label: "Total Bets", value: "$totalBets"),
              _InfoChip(label: "Total Handle", value: _fmtMoney(handleRaw)),
              _InfoChip(label: "Total Payout", value: _fmtMoney(payoutRaw)),
            ],
          ),
          children: [
            const SizedBox(height: 8),
            // Horizontal scroll + scrollbar for the table
            Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowHeight: 52,
                  columns: const [
                    DataColumn(label: Text("Bet ID")),
                    DataColumn(label: Text("Type")),
                    DataColumn(label: Text("Username")),
                    DataColumn(label: Text("Ticker")),
                    DataColumn(label: Text("Asset")),
                    DataColumn(label: Text("Strike")),
                    DataColumn(label: Text("Expiry Date")),
                    DataColumn(label: Text("Outcome")),
                    // Selection removed (group_title already describes it)
                    DataColumn(label: Text("Amount Wagered")),
                    DataColumn(label: Text("Payout Amount")),
                    DataColumn(label: Text("Potential Payout")),
                    DataColumn(label: Text("Odds (Am/Dec/Frac)")),
                    DataColumn(label: Text("Placed At")),
                    DataColumn(label: Text("Settled At")),
                    DataColumn(label: Text("Status")),
                    DataColumn(label: Text("Legs")),
                    DataColumn(label: Text("Action")),
                  ],
                  rows: bets.map((bet) {
                    final String expStr =
                        bet['expiry_date']?.toString() ?? 'N/A';

                    final String statusStr =
                        bet['status']?.toString() ?? 'N/A';

                    final settledAtRaw = bet['settled_at'];
                    final String settledAtStr =
                        (settledAtRaw == null ||
                                settledAtRaw.toString().isEmpty ||
                                settledAtRaw.toString().toLowerCase() == 'null')
                            ? 'N/A'
                            : settledAtRaw.toString();

                    final bool canSettle = _canSettle(
                      expiryDateStr: bet['expiry_date']?.toString(),
                      status: statusStr,
                      settledAt: settledAtRaw?.toString(),
                    );

                    final odds = Map<String, dynamic>.from(
                        (bet['odds'] ?? {}) as Map);
                    final String oddsText =
                        "Am: ${odds['american'] ?? '--'} | "
                        "Dec: ${odds['decimal'] ?? '--'} | "
                        "Frac: ${odds['fractional'] ?? '--'}";

                    final betIdRaw = bet['bet_id'];
                    int? betId;
                    if (betIdRaw is int) {
                      betId = betIdRaw;
                    } else if (betIdRaw is String) {
                      betId = int.tryParse(betIdRaw);
                    }

                    return DataRow(
                      cells: [
                        DataCell(Text(bet['bet_id']?.toString() ?? 'N/A')),
                        DataCell(Text(bet['bet_type']?.toString() ?? 'N/A')),
                        // DataCell(Text(bet['username']?.toString() ?? 'N/A')),
                        DataCell(
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                final username = bet["username"];
                                if (username != null && username.toString().isNotEmpty) {
                                  context.go('/dashboard/user_details/$username');
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 18, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(
                                    bet["username"] ?? "N/A",
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
                                        DataCell(Text(bet['ticker']?.toString() ?? 'N/A')),
                        DataCell(Text(bet['asset']?.toString() ?? 'N/A')),
                        DataCell(
                            Text(bet['strike_price']?.toString() ?? 'N/A')),
                        DataCell(Text(expStr)),
                        DataCell(Text(bet['outcome']?.toString() ?? 'N/A')),
                        // Selection removed
                        DataCell(Text(_fmtMoney(bet['amount_wagered']))),
                        DataCell(Text(_fmtMoney(bet['payout_amount']))),
                        DataCell(Text(_fmtMoney(bet['potential_payout']))),
                        DataCell(Text(oddsText)),
                        DataCell(Text(bet['placed_at']?.toString() ?? 'N/A')),
                        DataCell(Text(settledAtStr)),
                        DataCell(Text(statusStr)),
                        DataCell(Text(bet['legs_count']?.toString() ?? '--')),
                        DataCell(
                          canSettle && betId != null
                              ? ElevatedButton(
                                  onPressed: () =>
                                      widget.onSettlePressed(betId!),
                                  child: const Text("Settle"),
                                )
                              : const Text(
                                  "Cannot settle now",
                                  style: TextStyle(color: Colors.grey),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


 
 
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffe5e7eb),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

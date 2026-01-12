import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class UserBetsScreen extends StatefulWidget {
  final String username;

  const UserBetsScreen({
    super.key,
    required this.username,
  });

  @override
  State<UserBetsScreen> createState() => _UserBetsScreenState();
}

class _UserBetsScreenState extends State<UserBetsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> bets = [];
  bool loading = true;

  int currentPage = 1;
  String? nextUrl;
  String? prevUrl;
  int? totalCount;

  String currentStatus = "pending"; // pending, won, lost

  late final TabController _tabController;
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      setState(() {
        currentPage = 1;
        currentStatus = _tabController.index == 0
            ? "pending"
            : _tabController.index == 1
                ? "won"
                : "lost";
        loading = true;
      });

      fetchBetsForUser();
    });

    fetchBetsForUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  // ---------------- API (unchanged) ----------------
  Future<void> fetchBetsForUser() async {
    try {
      setState(() => loading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final dio = Dio();
      dio.options.baseUrl =
          "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final encodedUsername =
          Uri.encodeQueryComponent(widget.username.trim());

      final res = await dio.get(
        "/admin_panel/bet_feed/"
        "?search=$encodedUsername"
        "&status=$currentStatus"
        "&page=$currentPage",
      );

      final data = res.data as Map<String, dynamic>;
      // Debug
      // ignore: avoid_print
      print("User Bets");
      // ignore: avoid_print
      print(res.data);

      if (!mounted) return;

      setState(() {
        bets = List<dynamic>.from(data['results'] ?? []);
        nextUrl = data['next'] as String?;
        prevUrl = data['previous'] as String?;
        totalCount = data['count'] as int?;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      debugPrint("Error fetching user bets: $e");
    }
  }

  // ---------------- FORMATTERS (display only) ----------------

  String formatStatus(String? status) {
    switch (status) {
      case "pending":
        return "Pending";
      case "won":
        return "Won";
      case "lost":
        return "Lost";
      default:
        return status ?? "N/A";
    }
  }

  String fmtMoney(dynamic v) {
    if (v == null) return "\$0.00";
    final d =
        (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return "\$${d.toStringAsFixed(2)}";
  }

  String fmtDateOnly(dynamic v) {
    if (v == null) return "N/A";
    final s = v.toString();
    if (s.contains('T')) {
      return s.split('T').first;
    }
    if (s.contains(' ')) {
      return s.split(' ').first;
    }
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String fmtDateTime(dynamic v) {
    if (v == null) return "N/A";
    final s = v.toString();
    if (s.contains('T')) {
      final parts = s.split('T');
      final date = parts[0];
      final time = parts[1].split('.').first;
      return "$date $time";
    } else if (s.contains(' ')) {
      final parts = s.split(' ');
      if (parts.length >= 2) {
        return "${parts[0]} ${parts[1]}";
      }
    }
    return s;
  }

  String fmtPercent(dynamic v) {
    if (v == null) return "--";
    if (v is String && v.trim().isNotEmpty) {
      final s = v.trim();
      if (s.endsWith('%')) {
        final clean = s.replaceAll('%', '').trim();
        final num? n = num.tryParse(clean);
        if (n == null) return s;
        return "${n.toStringAsFixed(2)}%";
      }
      final num? n = num.tryParse(s);
      if (n == null) return s;
      return "${n.toStringAsFixed(2)}%";
    }
    final num n = (v is num) ? v : num.tryParse(v.toString()) ?? 0;
    return "${n.toStringAsFixed(2)}%";
  }

  String get statusLabel =>
      currentStatus[0].toUpperCase() + currentStatus.substring(1);

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (loading && bets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
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
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "$statusLabel Bets for ${widget.username} (${totalCount ?? 0})",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Tabs: Pending / Won / Lost
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Colors.black,
              tabs: const [
                Tab(text: "Pending"),
                Tab(text: "Won"),
                Tab(text: "Lost"),
              ],
            ),

            const Divider(height: 1),

            // Table
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowHeight: 44,
                            dataRowHeight: 52,
                            // decimal odds only (no US / fractional)
                            columns: const [
                              DataColumn(label: Text("Created At")),
                              DataColumn(label: Text("Bet ID")),
                              DataColumn(label: Text("Ticker")),
                              DataColumn(label: Text("Chosen Outcome")),
                              DataColumn(label: Text("Strike Price")),
                              DataColumn(label: Text("Expiry Date")),
                              DataColumn(label: Text("Stake")),
                              DataColumn(label: Text("Odds (Dec)")),
                              DataColumn(label: Text("Potential Payout")),
                              DataColumn(label: Text("GGR")),
                              DataColumn(label: Text("CRS Score")),
                              DataColumn(label: Text("CRS Level")),
                              DataColumn(label: Text("Max Wager %")),
                              DataColumn(label: Text("Allowable Profit")),
                              DataColumn(label: Text("Settled At")),
                              DataColumn(label: Text("Status")),
                            ],
                            rows: bets.map<DataRow>((bet) {
                              final odds = Map<String, dynamic>.from(
                                  bet['odds'] ?? {});
                              return DataRow(
                                cells: [
                                  DataCell(
                                      Text(fmtDateTime(bet['created_at']))),
                                  DataCell(Text(bet['bet_id'].toString())),
                                  DataCell(Text(bet['ticker'] ?? 'N/A')),
                                  DataCell(
                                      Text(bet['chosen_outcome'] ?? 'N/A')),
                                  DataCell(Text(
                                      bet['strike_price']?.toString() ??
                                          'N/A')),
                                  DataCell(
                                      Text(fmtDateOnly(bet['expiry_date']))),
                                  DataCell(Text(fmtMoney(bet['stake']))),
                                  DataCell(Text(
                                      odds['decimal']?.toString() ?? 'N/A')),
                                  DataCell(Text(
                                      fmtMoney(bet['potential_payout']))),
                                  DataCell(Text(fmtMoney(bet['ggr']))),
                                  DataCell(Text(
                                      bet['crs_risk_score']?.toString() ??
                                          'N/A')),
                                  DataCell(
                                      Text(bet['crs_risk_level'] ?? 'N/A')),
                                  DataCell(Text(
                                      fmtPercent(bet['max_wager_pct']))),
                                  DataCell(Text(
                                      fmtMoney(bet['allowable_profit']))),
                                  DataCell(
                                      Text(fmtDateTime(bet['settled_at']))),
                                  DataCell(
                                    _StatusTag(
                                      text: formatStatus(bet['status']),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),

            // Pagination footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Page $currentPage"),
                  Row(
                    children: [
                      TextButton(
                        onPressed: prevUrl != null && currentPage > 1
                            ? () {
                                setState(() => currentPage--);
                                fetchBetsForUser();
                              }
                            : null,
                        child: const Text("Previous"),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: nextUrl != null
                            ? () {
                                setState(() => currentPage++);
                                fetchBetsForUser();
                              }
                            : null,
                        child: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Status pill (same style as other tables)
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

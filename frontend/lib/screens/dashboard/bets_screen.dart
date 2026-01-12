import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class BetsScreen extends StatefulWidget {
  const BetsScreen({super.key});

  @override
  State<BetsScreen> createState() => _BetsScreenState();
}

class _BetsScreenState extends State<BetsScreen> {
  List<dynamic> bets = [];
  bool loading = true;

  int currentPage = 1;
  String? nextUrl;
  String? prevUrl;
  int? totalCount;
  String? selectedStatus;
  final TextEditingController searchController = TextEditingController();
  final List<String> statusOptions = ['pending', 'won', 'lost'];
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchBets();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchBets() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      dio.options.baseUrl = "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      String query = "page=$currentPage";
      if (selectedStatus != null) query += "&status=$selectedStatus";
      if (searchController.text.trim().isNotEmpty) {
        query += "&search=${searchController.text.trim()}";
      }

      final res = await dio.get("/admin_panel/bet_feed/?$query");
      final data = res.data as Map<String, dynamic>;
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
      debugPrint("Error fetching bets: $e");
    }
  }

  String fmtMoney(dynamic v) {
    if (v == null) return "\$0.00";
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return "\$${d.toStringAsFixed(2)}";
  }

  String fmtDateTime(dynamic iso) {
    if (iso == null) return "N/A";
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return "${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}";
    } catch (_) {
      return iso.toString();
    }
  }

  String _twoDigits(int n) => n < 10 ? "0$n" : "$n";

  String formatStatus(String? status) {
    switch (status) {
      case "pending":
        return "Live";
      case "won":
        return "Settled - Won";
      case "lost":
        return "Settled - Lost";
      default:
        return status ?? "N/A";
    }
  }


  String fmtDateYmd(dynamic iso) {
  if (iso == null) return "N/A";
  try {
    final dt = DateTime.parse(iso.toString()).toLocal();
    return "${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)}";
  } catch (_) {
    return iso.toString();
  }
}


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "Search (username, stock)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                hint: const Text("Filter Status"),
                value: selectedStatus,
                items: statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value;
                    currentPage = 1;
                  });
                  fetchBets();
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  currentPage = 1;
                  fetchBets();
                },
                child: const Text("Apply Filters"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          loading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 44,
                          dataRowHeight: 52,
                          columns: const [
                            DataColumn(label: Text("Time")),
                            DataColumn(label: Text("Settled At")),
                            DataColumn(label: Text("Patron")),
                            DataColumn(label: Text("CRS")),
                            DataColumn(label: Text("Bet #")),
                            DataColumn(label: Text("Category")), // Placeholder if needed
                            DataColumn(label: Text("Asset")),
                            DataColumn(label: Text("Selection")),
                            DataColumn(label: Text("Wager")),
                            DataColumn(label: Text("Odds")),
                            DataColumn(label: Text("Max Potential")),
                            DataColumn(label: Text("GGR")),
                            DataColumn(label: Text("Status")),
                          ],
                          rows: bets.map<DataRow>((bet) {
                            final odds = bet['odds'] ?? {};
                            final selection = "${fmtDateYmd(bet['expiry_date'])} ${bet['chosen_outcome']?.toUpperCase() ?? ''} \$${bet['strike_price']}";

                            return DataRow(
                              cells: [
                                DataCell(Text(fmtDateTime(bet['created_at']))),
                                DataCell(Text(fmtDateTime(bet['settled_at']))),
                                DataCell(Text(bet['username'] ?? 'N/A')),
                                DataCell(Text(bet['crs_risk_score']?.toString() ?? 'N/A')),
                                DataCell(Text(bet['bet_id'].toString())),
                                const DataCell(Text("N/A")), // Placeholder Category
                                DataCell(Text(bet['ticker'] ?? 'N/A')),
                                DataCell(Text(selection)),
                                DataCell(Text(fmtMoney(bet['stake']))),
                                DataCell(Text(odds['decimal']?.toString() ?? 'N/A')),
                                DataCell(Text(fmtMoney(bet['potential_payout']))),
                                DataCell(Text(fmtMoney(bet['ggr']))),
                                DataCell(Text(formatStatus(bet['status']))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

          // Pagination
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
                              fetchBets();
                            }
                          : null,
                      child: const Text("Previous"),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: nextUrl != null
                          ? () {
                              setState(() => currentPage++);
                              fetchBets();
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
    );
  }
}

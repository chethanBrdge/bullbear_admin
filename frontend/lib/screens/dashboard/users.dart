import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  List<dynamic> userList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      dio.options.baseUrl =
          "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final res = await dio.get("admin_panel/user-bets/");
      print("✅ User List Response Chethan:");
      print(res.data);

      setState(() {
        userList = res.data is List ? res.data : [];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      debugPrint("❌ Error fetching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "User Admin",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
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
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: PaginatedDataTable(
                        columnSpacing: 24,
                        rowsPerPage: 10,
                        header: const Text(
                          "User List",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        columns: const [
                          DataColumn(label: Text("Username")),
                          DataColumn(label: Text("Balance")),
                          DataColumn(label: Text("CRS")),
                          DataColumn(label: Text("GGR")),
                          DataColumn(label: Text("Bet Count")),
                          DataColumn(label: Text("KYC Status")),
                          DataColumn(label: Text("Bets")),         // 👈 NEW
                          DataColumn(label: Text("View Details")),
                        ],
                        source: loading
                            ? LoadingDataTableSource()
                            : UsersDataTableSource(userList, context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UsersDataTableSource extends DataTableSource {
  final List<dynamic> data;
  final BuildContext context;

  UsersDataTableSource(this.data, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final row = data[index];
    final username = row['username']?.toString() ?? 'N/A';

    return DataRow(
      cells: [
        DataCell(Text(username)),
        DataCell(Text(row['balance']?.toString() ?? '0.00')),
        DataCell(Text(row['crs']?.toString() ?? '0.00')),
        DataCell(Text(row['ggr']?.toString() ?? '0.00')),
        DataCell(Text(row['bet_count']?.toString() ?? '0')),
        DataCell(
          Text(
            row['kyc_status']?.toString().toUpperCase() ?? 'N/A',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _getKycColor(row['kyc_status']),
            ),
          ),
        ),
        // 👇 NEW: View Bets button
        DataCell(
          OutlinedButton(
            onPressed: () {
              if (username != 'N/A') {
                GoRouter.of(context).go('/dashboard/user_bets/$username');
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'View Bets',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
        // Existing View Details button
        DataCell(
          OutlinedButton(
            onPressed: () {
              if (username != 'N/A') {
                GoRouter.of(context)
                    .go('/dashboard/user_details/$username');
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'View',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  static Color _getKycColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  int get rowCount => data.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

class LoadingDataTableSource extends DataTableSource {
  @override
  DataRow? getRow(int index) {
    return const DataRow(
      cells: [
        DataCell(Text("Loading...")),
        DataCell(Text("")),
        DataCell(Text("")),
        DataCell(Text("")),
        DataCell(Text("")),
        DataCell(Text("")),
        DataCell(Text("")), // for Bets column
        DataCell(Text("")), // for View Details column
      ],
    );
  }

  @override
  int get rowCount => 1;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

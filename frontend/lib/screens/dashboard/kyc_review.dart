import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html; // For opening URLs in a new tab (Flutter Web)

class KycReviewScreen extends StatefulWidget {
  const KycReviewScreen({super.key});

  @override
  State<KycReviewScreen> createState() => _KycReviewScreenState();
}

class _KycReviewScreenState extends State<KycReviewScreen> {
  List<dynamic> kycList = [];
  bool loading = true;
  String statusFilter = "all"; // all | pending | approved | rejected

  // Dialog state
  bool showKycDialog = false;
  Map<String, dynamic>? selectedKyc;
  String selectedAction = '';
  String rejectionReason = '';

  @override
  void initState() {
    super.initState();
    fetchKycData();
  }

  Future<void> fetchKycData() async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      dio.options.baseUrl =
          "https://www.bbbprediction.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final query = statusFilter == "all" ? "" : "?status=$statusFilter";
      final res = await dio.get("/admin_panel/kyc/$query");
      print("KYC data is: ");
      print(res.data);

      setState(() {
        kycList = res.data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      debugPrint("Error fetching KYC data: $e");
    }
  }

  void fetchSingleKycDetail(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      dio.options.baseUrl =
          "https://www.bbbprediction.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final res = await dio.get("/admin_panel/kyc/$userId/");
      print("KYC Detail Response: ${res.data}");
    } catch (e) {
      print("Error fetching KYC detail: $e");
    }
  }

  void showKycDetailsDialog(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();
      dio.options.baseUrl =
          "https://www.bbbprediction.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final res = await dio.get("/admin_panel/kyc/$userId/");
      final data = res.data;

      setState(() {
        selectedKyc = {
          "userId": data["user_id"],
          "fullName": data["full_name"] ?? "N/A",
          "username": data["username"] ?? "N/A",
          "email": data["email"] ?? "N/A",
          "status": data["kyc_status"] ?? "N/A",
          "idType": data["id_document_type"] ?? "N/A",
          "idVerified": data["id_verified"] == true ? "Yes" : "No",
          "reviewerComment": data["reviewer_comment"] ?? "N/A",
          "submittedAt": data["submitted_at"] ?? "N/A",
          "reviewedAt": data["reviewed_at"] ?? "N/A",
        };
        selectedAction = '';
        rejectionReason = '';
        showKycDialog = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error loading KYC details")),
      );
    }
  }

  Future<void> handleKycAction() async {
    final userId = selectedKyc?["userId"];
    if (userId == null || selectedAction.isEmpty) return;

    if (selectedAction == "reject" && rejectionReason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reason to reject")),
      );
      return;
    }

    setState(() => showKycDialog = false);

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

      late Response res;
      if (selectedAction == "approve") {
        res = await dio.post("/admin_panel/kyc/approve/$userId/");
      } else {
        res = await dio.post(
          "/admin_panel/kyc/reject/$userId/",
          data: {"comment": rejectionReason},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.data["message"] ?? "Success")),
      );
      fetchKycData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error processing KYC: $e")),
      );
    }
  }

  Widget infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          )
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: PaginatedDataTable(
                            columnSpacing: 24,
                            rowsPerPage: 10,
                            header: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("KYC Records",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                                DropdownButton<String>(
                                  value: statusFilter,
                                  items: const [
                                    DropdownMenuItem(
                                        value: "all", child: Text("All")),
                                    DropdownMenuItem(
                                        value: "pending",
                                        child: Text("Pending")),
                                    DropdownMenuItem(
                                        value: "approved",
                                        child: Text("Approved")),
                                    DropdownMenuItem(
                                        value: "rejected",
                                        child: Text("Rejected")),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => statusFilter = value);
                                      fetchKycData();
                                    }
                                  },
                                ),
                              ],
                            ),
                            columns: const [
                              DataColumn(label: Text("User ID")),
                              DataColumn(label: Text("Full Name")),
                              DataColumn(label: Text("Username")),
                              DataColumn(label: Text("Email")),
                              DataColumn(label: Text("Status")),
                              DataColumn(label: Text("Action")),
                              DataColumn(label: Text("KYC Document")), // 🆕
                              DataColumn(label: Text("Selfie Image")), // 🆕
                            ],
                            source: loading
                                ? LoadingDataTableSource()
                                : KycDataTableSource(
                                    kycList,
                                    context,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ✅ DataTableSource with View Document & View Selfie columns
class KycDataTableSource extends DataTableSource {
  final List<dynamic> data;
  final BuildContext context;

  KycDataTableSource(this.data, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;

    final row = data[index];
    final rawId = row["user_id"] ?? "";
    final parsedId = rawId.replaceAll(RegExp(r'^U-0*'), '');
    final docUrl = row["document_url"];
    final selfieUrl = row["selfie_image"];

    return DataRow(
      cells: [
        DataCell(Text(rawId)),
        DataCell(Text(row["full_name"]?.toString().isNotEmpty == true
            ? row["full_name"]
            : "N/A")),
        DataCell(
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final username = row["username"];
                if (username != null && username.toString().isNotEmpty) {
                  context.go('/dashboard/user_details/$username');
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    row["username"] ?? "N/A",
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

        DataCell(Text(row["email"] ?? "N/A")),
        DataCell(Text(row["kyc_status"]?.toString().toUpperCase() ?? "N/A")),
        DataCell(
          ElevatedButton(
            onPressed: () {
              context.go('/dashboard/kyc/$parsedId');
            },
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text("View Details"),
          ),
        ),
        // 🆕 View Document Button
        DataCell(
          docUrl != null && docUrl.toString().isNotEmpty
              ? ElevatedButton(
                  onPressed: () {
                    html.window.open(docUrl, '_blank');
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text("View"),
                )
              : const Text("N/A"),
        ),
        // 🆕 View Selfie Button
        DataCell(
          selfieUrl != null && selfieUrl.toString().isNotEmpty
              ? ElevatedButton(
                  onPressed: () {
                    html.window.open(selfieUrl, '_blank');
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text("View"),
                )
              : const Text("N/A"),
        ),
      ],
    );
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
    return const DataRow(cells: [
      DataCell(Text("Loading...")),
      DataCell(Text("")),
      DataCell(Text("")),
      DataCell(Text("")),
      DataCell(Text("")),
      DataCell(Text("")),
      DataCell(Text("")),
      DataCell(Text("")),
    ]);
  }

  @override
  int get rowCount => 1;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:html' as html;

class KycDetailPage extends StatefulWidget {
  final String kycId;

  const KycDetailPage({super.key, required this.kycId});

  @override
  State<KycDetailPage> createState() => _KycDetailPageState();
}

class _KycDetailPageState extends State<KycDetailPage> {
  Map<String, dynamic>? kycData;
  bool loading = true;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    fetchKycDetails();
  }

  Future<void> fetchKycDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      // Convert "U-00001" → "1"
      String rawId = widget.kycId;
      String parsedId = rawId.replaceAll(RegExp(r'^U-0*'), '');

      dio.options.baseUrl =
          "https://api.bbbprediction.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final res = await dio.get("/admin_panel/kyc/$parsedId/");
      print("Single KYC Data");
      print(res.data);
      setState(() {
        kycData = res.data;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error loading KYC details: $e");
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching KYC details")),
      );
    }
  }

  Future<void> updateKycStatus(String status, {String? reason}) async {
    try {
      setState(() => updating = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final dio = Dio();

      String rawId = widget.kycId;
      String parsedId = rawId.replaceAll(RegExp(r'^U-0*'), '');

      dio.options.baseUrl =
          "https://api.bbbprediction.com/";
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final data = {"kyc_status": status};
      if (reason != null && reason.isNotEmpty) {
        data["reviewer_comment"] = reason;
      }

      await dio.patch("/admin_panel/kyc/$parsedId/review/", data: data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("KYC ${status.toUpperCase()} Successfully")),
      );

      await fetchKycDetails();
    } catch (e) {
      debugPrint("Error updating KYC: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating KYC status")),
      );
    } finally {
      setState(() => updating = false);
    }
  }

  Future<void> showRejectionDialog() async {
    final TextEditingController reasonController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Center(
            child: Text(
              "Rejection Reason",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Enter reason for rejection...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black26),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please enter a reason"),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      updateKycStatus("rejected", reason: reason);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : kycData == null
              ? const Center(child: Text("No KYC data found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Go Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.go('/dashboard/kyc-review'),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          label: const Text(
                            "Go Back",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.black12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kycData?["full_name"] ?? "Unknown User",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            infoTile("User ID", kycData?["user_id"] ?? "N/A"),
                            infoTile("Username", kycData?["username"] ?? "N/A"),
                            infoTile("Email", kycData?["email"] ?? "N/A"),
                            infoTile("Document Type",
                                kycData?["id_document_type"] ?? "N/A"),
                            infoTile(
                              "KYC Status",
                              (kycData?["kyc_status"] ?? "N/A")
                                  .toString()
                                  .toUpperCase(),
                            ),
                            infoTile("Reviewer Comment",
                                kycData?["reviewer_comment"] ?? "N/A"),
                            infoTile("Submitted At",
                                kycData?["submitted_at"]?.toString() ?? "N/A"),
                            infoTile("Reviewed At",
                                kycData?["reviewed_at"]?.toString() ?? "N/A"),

                            const SizedBox(height: 20),

                            if (kycData?["document_name"] != null)
                              infoTile("Document",
                                  kycData?["document_name"] ?? "N/A"),

                            if (kycData?["document_url"] != null)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final fullUrl =
                                      kycData?["document_url"].toString();
                                  if (fullUrl != null && fullUrl.isNotEmpty) {
                                    html.window.open(fullUrl, "_blank");
                                  }
                                },
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text("View Document"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                              ),

                            if (kycData?["selfie_image"] != null) ...[
                              const SizedBox(height: 24),
                              const Text("Selfie Image:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  kycData?["selfie_image"],
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, _, __) =>
                                      const Icon(Icons.broken_image, size: 100),
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // ✅ Approve / Reject Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: updating
                                      ? null
                                      : () => updateKycStatus("approved"),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                          color: Colors.black26),
                                    ),
                                  ),
                                  child: updating
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          "Approve",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600),
                                        ),
                                ),
                                TextButton(
                                  onPressed:
                                      updating ? null : () => showRejectionDialog(),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                          color: Colors.black26),
                                    ),
                                  ),
                                  child: updating
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          "Reject",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600),
                                        ),
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

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlatformConfigScreen extends StatefulWidget {
  const PlatformConfigScreen({super.key});

  @override
  State<PlatformConfigScreen> createState() => _PlatformConfigScreenState();
}

class _PlatformConfigScreenState extends State<PlatformConfigScreen> {
  final TextEditingController _baseExposureController = TextEditingController();
  final TextEditingController _maxProfitController = TextEditingController();
  final TextEditingController _maxCrsController = TextEditingController();
  final TextEditingController _minStakeController = TextEditingController();

  bool loading = true;
  final Dio dio = Dio();
  final String baseUrl = "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com/";

  @override
  void initState() {
    super.initState();
    fetchPlatformConfig();
  }

  Future<void> fetchPlatformConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) return;

      dio.options.baseUrl = baseUrl;
      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final response = await dio.get("admin_panel/platform_settings/");
      final data = response.data;

      _baseExposureController.text = data["base_exposure_limit"];
      _maxProfitController.text = data["max_profit"];
      _maxCrsController.text = data["max_crs"];
      _minStakeController.text = data["minimum_stake"];

      setState(() {
        loading = false;
      });
    } catch (e) {
      print("Error fetching platform config: $e");
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> updatePlatformConfig() async {
    try {
      setState(() {
        loading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      dio.options.headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final payload = {
        "base_exposure_limit": _baseExposureController.text.trim(),
        "max_profit": _maxProfitController.text.trim(),
        "max_crs": _maxCrsController.text.trim(),
        "minimum_stake": _minStakeController.text.trim(),
      };

      final response = await dio.post(
        "admin_panel/platform_settings/",
        data: payload,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings updated")),
        );
      }
    } catch (e) {
      print("Error updating config: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update failed")),
      );
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    _baseExposureController.dispose();
    _maxProfitController.dispose();
    _maxCrsController.dispose();
    _minStakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text(
          'Platform Config',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  children: [
                    _buildField("Base Exposure Limit", _baseExposureController),
                    _buildField("Max Profit", _maxProfitController),
                    _buildField("Max CRS", _maxCrsController),
                    _buildField("Minimum Stake", _minStakeController),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: updatePlatformConfig,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text("Save Changes"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.black),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  List<dynamic> stocks = [];
  bool loading = true;
  List<String> stockSymbols = [];

  @override
  void initState() {
    super.initState();
    fetchAllStocks();
  }

  Future<void> fetchAllStocks() async {
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

      final res = await dio.get("/admin_panel/stocks/");
      final symbols = res.data
          .map<String>((stock) => stock['symbol'].toString())
          .toSet()
          .toList();

      setState(() {
        stocks = res.data ?? [];
        stockSymbols = symbols;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      debugPrint("Error fetching Stocks: $e");
    }
  }

  Future<void> toggleStockStatus({
    required int stockId,
    bool? marketStatus,
    bool? autoOdds,
  }) async {
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

      final data = {
        if (marketStatus != null) "market_status": marketStatus,
        if (autoOdds != null) "auto_odds": autoOdds,
      };

      final res = await   dio.patch("/admin_panel/stock/$stockId/toggle/", data: data);
      print("Requested Url");
      print(res.realUri);
      print("Sent Data");
      print(data);
      print("Status Response");
      print(res.data);
      fetchAllStocks(); // refresh the list
    } catch (e) {
      debugPrint("Error toggling stock: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Padding(
                   padding: const EdgeInsets.all(20.0),
                   child: Text("Stocks Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                 ),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: stocks.map((stock) {
                    final id = stock['id'];
                    final name = stock['company_name'];
                    final symbol = stock['symbol'];
                    final price = stock['price'];
                    final change = stock['change'];
                    final percent = stock['percent_change'];
                    final marketStatus = stock['market_status'];
                    final autoOdds = stock['auto_odds'];
                    final logoUrl = stock['url'];
                
                    return SizedBox(
                      width: MediaQuery.of(context).size.width > 600 ? 300 : double.infinity,
                      child: Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                      context.go('/dashboard/stocks/$symbol/');
                                    },
                                  child: Row(
                                    children: [
                                      if (logoUrl != null)
                                        Image.network(
                                          logoUrl,
                                          width: 32,
                                          height: 32,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.image),
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "$name ($symbol)",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Price: $price"),
                              Text("Change: $change ($percent)"),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text("Status: "),
                                  Switch(
                                    value: marketStatus,
                                    onChanged: (value) => toggleStockStatus(
                                      stockId: id,
                                      marketStatus: value,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text("Auto Odds: "),
                                  Switch(
                                    value: autoOdds,
                                    onChanged: (value) => toggleStockStatus(
                                      stockId: id,
                                      autoOdds: value,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
  }
}

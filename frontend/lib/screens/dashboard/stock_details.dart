import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class MarketBySymbolScreen extends StatefulWidget {
  final String symbol;
  const MarketBySymbolScreen({super.key, required this.symbol});

  @override
  State<MarketBySymbolScreen> createState() => _MarketBySymbolScreenState();
}

class _MarketBySymbolScreenState extends State<MarketBySymbolScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? stock;
  List<dynamic> groupedMarkets = [];
  bool loading = true;
  TabController? _tabController;
    /// NEW: Store nudges by marketId: { marketId: {"total": x, "net": y} }
  Map<int, Map<String, dynamic>> nudgeData = {};
    int _currentTabIndex = 0; // 👈 add this

  
  @override
  void initState() {
    super.initState();
    fetchMarketsBySymbol();
  }

  Future<void> fetchMarketsBySymbol() async {
  // 👇 remember which tab was selected before refresh
  final previousIndex = _tabController?.index ?? _currentTabIndex;

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

    final res = await dio.get("/admin_panel/markets/", queryParameters: {
      'symbol': widget.symbol,
    });

    final data = res.data;
    final markets = data['grouped_markets'] ?? [];
    print("Market Response");
    print(data);

    if (!mounted) return;

    setState(() {
      stock = data['stock'];
      groupedMarkets = markets;
      loading = false;

      // dispose old controller
      _tabController?.dispose();

      if (groupedMarkets.isNotEmpty) {
        // 👇 make sure index is in range after refresh
        final safeIndex = previousIndex.clamp(0, groupedMarkets.length - 1);

        _tabController = TabController(
          length: groupedMarkets.length,
          vsync: this,
          initialIndex: safeIndex,
        );

        // 👇 keep tracking the selected tab
        _tabController!.addListener(() {
          _currentTabIndex = _tabController!.index;
        });
      } else {
        _tabController = null;
        _currentTabIndex = 0;
      }
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => loading = false);
    debugPrint("Error fetching markets by symbol: $e");
  }
}


  Future<void> toggleMarketStatus(int marketId, bool status) async {
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

      final res = await dio.patch(
        "/admin_panel/market/$marketId/status/",
        data: {"is_active": status},
      );

      debugPrint("Status updated: ${res.data}");
      fetchMarketsBySymbol(); // refresh after toggle
    } catch (e, stackTrace) {
      debugPrint("Error in toggleMarketStatus: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
  }
Future<void> nudgeOdds({
  required int marketId,
  required String side,
  required int direction,
}) async {
  try {
    print("Market Id is: $marketId");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final dio = Dio();

    dio.options.baseUrl = "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com/";
    dio.options.headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    final res = await dio.post(
      "/admin_panel/markets/$marketId/nudge/",
      data: {
        "side": side,
        "direction": direction,
      },
    );

    final total = res.data["total_nudges"];
    final net = res.data["net_nudge"];

    // setState(() {
    //   // ✅ Update nudgeData without re-fetching everything
    //   nudgeData[marketId] = {
    //     "total": total,
    //     "net": net,
    //   };

    //   // ✅ Also manually update the affected odds in groupedMarkets
    //   for (var group in groupedMarkets) {
    //     for (var market in group["markets"]) {
    //       if (market["id"] == marketId) {
    //         final targetSide = market[side];
    //         final newDecimal = res.data["new_decimal"];
    //         if (targetSide != null && newDecimal != null) {
    //           targetSide["decimal"] = newDecimal;
    //         }
    //       }
    //     }
    //   }
    // });
    fetchMarketsBySymbol();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Odds nudged: $side ${direction > 0 ? '+' : '-'}")),
      );
      // ❌ Don't refresh full markets here, or you lose memory
      // await fetchMarketsBySymbol();
    }
  } catch (e) {
    debugPrint("Error nudging odds: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to nudge odds.")),
    );
  }
}



Future<void> resetMarketOdds(int marketId) async {
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

    final res = await dio.post("/admin_panel/markets/$marketId/reset/");
     print("Market reset: ${res.data}");
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Market odds reset successfully.")),
      );
      fetchMarketsBySymbol(); // Refresh data after reset
    }
  } catch (e, stackTrace) {
    debugPrint("Error resetting market odds: $e");
    debugPrintStack(stackTrace: stackTrace);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to reset market odds.")),
    );
  }
}


 Future<void> updateVigPercent(int marketId, double vigPercent) async {
  try {
    final fixedVig = double.parse(vigPercent.toStringAsFixed(1));
    debugPrint("Market id: $marketId");
    debugPrint("Vig Percent (rounded): $fixedVig");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final dio = Dio();

    dio.options.baseUrl =
        "http://ec2-56-228-15-3.eu-north-1.compute.amazonaws.com/";
    dio.options.headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    final res = await dio.post(
      "/admin_panel/market/set-vig/",
      data: {
        "market_id": marketId.toString(),
        "vig_percent": fixedVig,
      },
    );

    debugPrint("Vig update response: ${res.data}");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vig updated to ${fixedVig.toStringAsFixed(1)}%")),
      );
      fetchMarketsBySymbol();
    }
  } on DioException catch (e) {
    debugPrint("Server error: ${e.response?.statusCode} - ${e.response?.data}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to update vig.")),
    );
  } catch (e) {
    debugPrint("Error in updateVigPercent: $e");
  }
}



 void showVigDialog(int marketId, double currentVig) {
  double tempVig = currentVig;

  showDialog(
    context: context,
    builder: (dialogContext) { // ✅ use this local context!
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Update Vig Percentage"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Current Vig: ${tempVig.toStringAsFixed(2)}%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Slider(
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: "${tempVig.toStringAsFixed(1)}%",
                  value: tempVig,
                  onChanged: (value) {
                    setDialogState(() {
                      tempVig = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(), // ✅ safe pop
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // ✅ safe pop
                  updateVigPercent(marketId, tempVig);
                },
                child: const Text("Update"),
              ),
            ],
          );
        },
      );
    },
  );
}


  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/dashboard/stocks');
          },
        ),
        title: Text("Markets - ${widget.symbol}"),
        bottom: groupedMarkets.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () {
                        _tabController?.animateTo(
                          (_tabController?.index ?? 0) > 0
                              ? _tabController!.index - 1
                              : 0,
                        );
                      },
                    ),
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: groupedMarkets
                            .map<Tab>(
                                (group) => Tab(text: group['expiry_date']))
                            .toList(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () {
                        if ((_tabController?.index ?? 0) <
                            (_tabController?.length ?? 0) - 1) {
                          _tabController?.animateTo(_tabController!.index + 1);
                        }
                      },
                    ),
                  ],
                ),
              )
            : null,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : stock == null
              ? const Center(child: Text("No data available."))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stock Header Info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (stock!['url'] != null)
                            Image.network(
                              stock!['url'],
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${stock!['company_name']} (${stock!['symbol']})",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text("Last Price: \$${stock!['last_price']}"),
                                Text(
                                    "Change: ${stock!['last_change']} (${stock!['last_percent_change']})"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Market Cards by Expiry Date
                    Expanded(
                      child: groupedMarkets.isEmpty
                          ? const Center(child: Text("No market data found."))
                          : TabBarView(
                              controller: _tabController,
                              children: groupedMarkets.map<Widget>((group) {
                                final markets =
                                    group['markets'] as List<dynamic>;
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: markets.map<Widget>((market) {
                                      final target = market['target_price'];
                                      final over = market['over'];
                                      final under = market['under'];
                                      final marketId = market['id'];
                                      final isActive =
                                          market['is_active'] ?? false;

                                      // Calculate vig
                                      double overDecimal =
                                          market['over']['decimal'];
                                      double underDecimal =
                                          market['under']['decimal'];
                                      final totalNudges =  market['total_nudges'] ?? 0;
                                      final netNudge = market['net_nudge']?? 0;


                                        final overImp = (over['implied_odds'] as num).toDouble();
                                        final underImp = (under['implied_odds'] as num).toDouble();

                                        final vig = ((overImp + underImp) - 1) * 100;
                                         
                                      return SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width >
                                                    600
                                                ? 400
                                                : double.infinity,
                                        child: Card(
                                          elevation: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Target Price: \$${target}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),

                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                              "Over Odds",
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                          const SizedBox(
                                                              height: 4),
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  const Text("Decimal:"),
                                                                  Row(
                                                                    children: [
                                                                      IconButton(
                                                                        icon: const Icon(Icons.remove),
                                                                        visualDensity: VisualDensity.compact,
                                                                        tooltip: "Decrease Over Odds",
                                                                        onPressed: () {
                                                                          nudgeOdds(marketId: marketId, side: "over", direction: -1);
                                                                        },
                                                                      ),
                                                                      Text(over['decimal'].toStringAsFixed(2)),
                                                                      IconButton(
                                                                        icon: const Icon(Icons.add),
                                                                        visualDensity: VisualDensity.compact,
                                                                        tooltip: "Increase Over Odds",
                                                                        onPressed: () {
                                                                          nudgeOdds(marketId: marketId, side: "over", direction: 1);
                                                                        },
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),

                                                          // Text(
                                                          //     "Decimal: ${over['decimal']}"),
                                                          Text(
                                                              "Display: ${over['display_odds']}"),
                                                          Text(
                                                              "Fractional: ${over['fractional']}"),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                              "Under Odds",
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                          const SizedBox(
                                                              height: 4),
                                                              Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      const Text("Decimal:"),
                                                                      Row(
                                                                        children: [
                                                                          IconButton(
                                                                            icon: const Icon(Icons.remove),
                                                                            visualDensity: VisualDensity.compact,
                                                                            tooltip: "Decrease Under Odds",
                                                                            onPressed: () {
                                                                              nudgeOdds(marketId: marketId, side: "under", direction: -1);
                                                                            },
                                                                          ),
                                                                          Text(under['decimal'].toStringAsFixed(2)),
                                                                          IconButton(
                                                                            icon: const Icon(Icons.add),
                                                                            visualDensity: VisualDensity.compact,
                                                                            tooltip: "Increase Under Odds",
                                                                            onPressed: () {
                                                                              nudgeOdds(marketId: marketId, side: "under", direction: 1);
                                                                            },
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),

                                                          // Text(
                                                          //     "Decimal: ${under['decimal']}"),
                                                          Text(
                                                              "Display: ${under['display_odds']}"),
                                                          Text(
                                                              "Fractional: ${under['fractional']}"),
                                                        const SizedBox(height: 12),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              "Total Nudges:",
                                                              style: TextStyle(fontWeight: FontWeight.w600),
                                                            ),
                                                            Text(totalNudges.toString()),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              "Net Direction:",
                                                              style: TextStyle(fontWeight: FontWeight.w600),
                                                            ),
                                                            Text(
                                                              netNudge > 0
                                                                  ? "Over (+$netNudge)"
                                                                  : netNudge < 0
                                                                      ? "Under ($netNudge)"
                                                                      : "Neutral",
                                                              style: TextStyle(
                                                                color: netNudge > 0
                                                                    ? Colors.green
                                                                    : netNudge < 0
                                                                        ? Colors.red
                                                                        : Colors.grey,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        ],
                                                        
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 12),

                                                // Vig display
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      "Vig Percentage:",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                    ),
                                                    Text(
                                                      // "${vig.toStringAsFixed(2)}%",
                                                      "9.0%",
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        showVigDialog(marketId, vig);
                                                      },
                                                      child: const Text("Update Vig %"),
                                                    ),
                                                    ElevatedButton(
                                                      
                                                      onPressed: () {
                                                        resetMarketOdds(marketId);
                                                      },
                                                      child: const Text("Reset Odds"),
                                                    ),
                                                  ],
                                                ),


                                                const SizedBox(height: 12),

                                                // Market status toggle
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text("Market Status"),
                                                    Switch(
                                                      value: isActive,
                                                      onChanged: (value) {
                                                        if (marketId != null) {
                                                          toggleMarketStatus(
                                                              marketId, value);
                                                        } else {
                                                          debugPrint(
                                                              "Market ID is null");
                                                        }
                                                      },
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
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
    );
  }
}

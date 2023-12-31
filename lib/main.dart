import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AssetsPage());
  }
}

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Drawer(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('보유자산'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const AssetsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('실시간자산'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const RealTimePage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart_outlined),
              title: const Text('자산추이'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const GraphPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const SettingPage()));
              },
            ),
          ],
        ),
      );
}

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  List<StockData> stockList = [];

  @override
  void initState() {
    super.initState();
    _updateStockList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('보유자산'),
          centerTitle: true,
        ),
        drawer: const NavigationDrawer(),
        body: Align(
          alignment: Alignment.topCenter,
          child: ListView(children: [
            const CashTile(),
            ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: stockList.length,
              itemBuilder: (context, index) => ListTile(
                key: ValueKey(index),
                title:
                    Text('${stockList[index].name}(${stockList[index].code})'),
                onTap: () => showStockDialog(context, index),
              ),
              onReorder: _reorderStock,
            ),
            AssetsTileContainer(
              tile: ElevatedButton(
                  child: const Icon(Icons.add),
                  onPressed: () => showStockDialog(context, -1)),
            ),
          ]),
        ),
      );

  void showStockDialog(BuildContext context, int index) {
    final StockData stock = (index < 0)
        ? StockData(name: '', code: '', weight: 0, price: 0, quantity: 0)
        : stockList[index];
    final nameTextConroller = TextEditingController(text: stock.name);
    final weightTextController =
        TextEditingController(text: stock.weight.toString());
    final priceTextController =
        TextEditingController(text: stock.price.toString());
    final quantityTextController =
        TextEditingController(text: stock.quantity.toString());

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('종목 추가'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('종목명'),
              TextField(
                controller: nameTextConroller,
              ),
              const Text('비중(%)'),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))
                ],
                controller: weightTextController,
              ),
              const Text('매수가격(원)'),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: priceTextController,
              ),
              const Text('수량'),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: quantityTextController,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            child: Text((index < 0) ? '추가' : '수정'),
            onPressed: () {
              _updateStock(
                  StockData(
                      name: nameTextConroller.text,
                      code: '',
                      weight: double.parse(weightTextController.text),
                      price: int.parse(priceTextController.text),
                      quantity: int.parse(quantityTextController.text)),
                  index);
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: Text((index < 0) ? '취소' : '제거'),
            onPressed: () {
              if (index >= 0) {
                _removeStock(index);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _updateStock(StockData stock, int index) async {
    stock.code = await fetchStockCode(stock.name);
    String stockJson = jsonEncode(stock.toJson());
    print(stockJson);

    final prefs = await SharedPreferences.getInstance();
    List<String> stockJsonList = prefs.getStringList('stocks') ?? [];

    if (index < 0) {
      stockJsonList.add(stockJson);
    } else {
      stockJsonList[index] = stockJson;
    }

    await prefs.setStringList('stocks', stockJsonList);

    _updateStockList();
  }

  void _removeStock(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stockJsonList = prefs.getStringList('stocks') ?? [];

    stockJsonList.removeAt(index);

    await prefs.setStringList('stocks', stockJsonList);

    _updateStockList();
  }

  void _reorderStock(int oldIdx, int newIdx) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stockJsonList = prefs.getStringList('stocks') ?? [];

    if (oldIdx < newIdx) {
      newIdx -= 1;
    }
    String stockJson = stockJsonList.removeAt(oldIdx);
    stockJsonList.insert(newIdx, stockJson);

    await prefs.setStringList('stocks', stockJsonList);

    _updateStockList();
  }

  void _updateStockList() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stockJsonList = prefs.getStringList('stocks') ?? [];

    setState(() {
      stockList.clear();
      for (String stockJson in stockJsonList) {
        stockList.add(StockData.fromJson(jsonDecode(stockJson)));
      }
    });
  }
}

class AssetsTileContainer extends StatelessWidget {
  final Widget tile;

  const AssetsTileContainer({super.key, required this.tile});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(10),
        height: 100,
        decoration: BoxDecoration(border: Border.all(color: Colors.black)),
        child: tile,
      );
}

class CashTile extends StatefulWidget {
  const CashTile({super.key});

  @override
  State<CashTile> createState() => _CashTileState();
}

class _CashTileState extends State<CashTile> {
  String cashStr = '현금 데이터 로딩 중';

  @override
  void initState() {
    super.initState();
    _loadCash();
  }

  @override
  Widget build(BuildContext context) => AssetsTileContainer(
        tile: ListView(
          children: [
            const Text('현금'),
            Text(cashStr),
            ElevatedButton(
              child: const Text('수정'),
              onPressed: () => showCashEditDialog(context),
            )
          ],
        ),
      );

  void showCashEditDialog(BuildContext context) {
    final cashTextController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('현금(원)'),
        content: TextField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          controller: cashTextController,
        ),
        actions: [
          ElevatedButton(
            child: const Text('수정'),
            onPressed: () {
              int cash = int.parse(cashTextController.text);
              _saveCash(cash);
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: const Text('취소'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future _loadCash() async {
    final prefs = await SharedPreferences.getInstance();
    // await prefs.clear();
    int cash = prefs.getInt('cash') ?? 0;
    setState(() {
      cashStr = cashIntToString(cash);
    });
  }

  void _saveCash(int cash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cash', cash);
    setState(() {
      cashStr = cashIntToString(cash);
    });
  }
}

class StockData {
  String name;
  String code;
  double weight;
  int price;
  int quantity;

  StockData(
      {required this.name,
      required this.code,
      required this.weight,
      required this.price,
      required this.quantity});

  factory StockData.fromJson(Map<String, dynamic> json) {
    return StockData(
        name: json['name'],
        code: json['code'],
        weight: json['weight'],
        price: json['price'],
        quantity: json['quantity']);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'weight': weight,
        'price': price,
        'quantity': quantity
      };
}

// ListTile을 찾아보자

class StockTile extends StatelessWidget {
  final StockData stockData;
  const StockTile({super.key, required this.stockData});

  @override
  Widget build(BuildContext context) => AssetsTileContainer(
        tile: ListView(
          children: [
            Text('${stockData.name}(${stockData.code})'),
            Text('가격: ${cashIntToString(stockData.price)}'),
            Text('수량: ${stockData.quantity}'),
            ElevatedButton(
              child: const Text('수정'),
              onPressed: () {},
            )
          ],
        ),
      );
}

class RealTimePage extends StatefulWidget {
  const RealTimePage({super.key});

  @override
  State<RealTimePage> createState() => _RealTimePageState();
}

class _RealTimePageState extends State<RealTimePage> {
  List<DataRow> cashDataList = [];
  List<DataRow> tableDataList = [];

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('실시간자산'),
          centerTitle: true,
        ),
        drawer: const NavigationDrawer(),
        body: ListView(children: [
          DataTable(
              columnSpacing: 10,
              columns: const [
                DataColumn(label: DataColumnLabel(text: '현금')),
                DataColumn(label: DataColumnLabel(text: '현금목표비중')),
                DataColumn(label: DataColumnLabel(text: '현금비중')),
                DataColumn(label: DataColumnLabel(text: '총평가')),
              ],
              rows: cashDataList),
          DataTable(
              columnSpacing: 5,
              columns: const [
                DataColumn(label: DataColumnLabel(text: '종목')),
                DataColumn(label: DataColumnLabel(text: '평가금액')),
                DataColumn(label: DataColumnLabel(text: '매수금액')),
                DataColumn(label: DataColumnLabel(text: '손익')),
                DataColumn(label: DataColumnLabel(text: '목표비중')),
                DataColumn(label: DataColumnLabel(text: '평가비중')),
                DataColumn(label: DataColumnLabel(text: '매수비중')),
              ],
              rows: tableDataList),
        ]),
      );

  void _update() async {
    final prefs = await SharedPreferences.getInstance();
    List<DataRow> cashDataList = [];
    List<DataRow> tableRowList = [];

    int cash = prefs.getInt('cash') ?? 0;

    List<String> stockJsonList = prefs.getStringList('stocks') ?? [];
    List<Future<StockTableData>> futureList = [];
    for (String stockJson in stockJsonList) {
      StockData stock = StockData.fromJson(jsonDecode(stockJson));
      futureList.add(_generateStockTableData(stock));
    }
    List<StockTableData> tableDataList = await Future.wait(futureList);

    int totalValue = cash, totalBuy = cash;
    double totalWeight = 0;
    for (StockTableData tableData in tableDataList) {
      totalValue += tableData.valueAmount;
      totalBuy += tableData.buyAmount;
      totalWeight += tableData.targetWeight;
    }

    cashDataList.add(DataRow(cells: [
      DataCell(DataCellText(text: cashIntToString(cash))),
      DataCell(DataCellText(text: weightToString(100 - totalWeight))),
      DataCell(DataCellText(text: weightToString(cash / totalValue * 100))),
      DataCell(DataCellText(text: cashIntToString(totalValue))),
    ]));

    for (StockTableData tableData in tableDataList) {
      tableData.valueWeight = tableData.valueAmount / totalValue * 100;
      tableData.buyWeight = tableData.buyAmount / totalBuy * 100;
      int profit = tableData.valueAmount - tableData.buyAmount;

      tableRowList.add(DataRow(cells: [
        DataCell(DataCellText(text: tableData.name)),
        DataCell(DataCellText(text: cashIntToString(tableData.valueAmount))),
        DataCell(DataCellText(text: cashIntToString(tableData.buyAmount))),
        DataCell(DataCellText(text: profitIntToString(profit))),
        DataCell(DataCellText(text: weightToString(tableData.targetWeight))),
        DataCell(DataCellText(text: weightToString(tableData.valueWeight))),
        DataCell(DataCellText(text: weightToString(tableData.buyWeight))),
      ]));
    }

    setState(() {
      this.cashDataList = cashDataList;
      this.tableDataList = tableRowList;
    });
  }

  Future<StockTableData> _generateStockTableData(StockData stock) async {
    int curPrice = await fetchStockPrice(stock.code);
    int valueAmount = curPrice * stock.quantity;
    int buyAmount = stock.price * stock.quantity;

    return StockTableData(
        name: stock.name,
        valueAmount: valueAmount,
        buyAmount: buyAmount,
        targetWeight: stock.weight);
  }
}

class StockTableData {
  String name;
  int valueAmount;
  int buyAmount;
  double targetWeight;
  double valueWeight;
  double buyWeight;

  StockTableData(
      {required this.name,
      required this.valueAmount,
      required this.buyAmount,
      required this.targetWeight,
      this.valueWeight = 0,
      this.buyWeight = 0});
}

class DataColumnLabel extends StatelessWidget {
  final String text;

  const DataColumnLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Flexible(
        child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            )));
  }
}

class DataCellText extends StatelessWidget {
  final String text;
  final TextAlign? align;
  const DataCellText({super.key, required this.text, this.align});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textAlign: TextAlign.right,
        ));
  }
}

class GraphPage extends StatelessWidget {
  const GraphPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('자산추이'),
        centerTitle: true,
      ),
      drawer: const NavigationDrawer(),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            child: const Text('안녕')),
      ));
}

class SettingPage extends StatelessWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      drawer: const NavigationDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [CupertinoTextField()],
      ));
}

Future<String> fetchStockCode(String name) async {
  final resp = await http.get(Uri.parse(
      'https://m.stock.naver.com/api/json/search/searchListJson.nhn?keyword=$name'));

  if (resp.statusCode == 200) {
    List<dynamic> dList = jsonDecode(resp.body)['result']['d'];
    for (dynamic d in dList) {
      if (d['nm'] == name) {
        return d['cd'];
      }
    }
    throw Exception('Fail to find stock code.');
  } else {
    throw Exception('Fail to load stock code.');
  }
}

Future<int> fetchStockPrice(String code) async {
  DateTime now = DateTime.now();
  DateTime sixDaysAgo = now.subtract(const Duration(days: 60));
  String startTime = dateTimeToString(sixDaysAgo);
  String endTime = dateTimeToString(now);
  final resp = await http.get(Uri.parse(
      'https://api.finance.naver.com/siseJson.naver?symbol=$code&requestType=1&timeframe=day&startTime=$startTime&endTime=$endTime'));

  if (resp.statusCode == 200) {
    List<dynamic> siseList = jsonDecode(resp.body.replaceAll("'", '"'));
    if (siseList.length < 2) {
      throw Exception('Fail to find stock price.');
    }
    return siseList[siseList.length - 1][4];
  } else {
    throw Exception('Fail to load stock price.');
  }
}

String dateTimeToString(DateTime dateTime) {
  String y = dateTime.year.toString().padLeft(4, '0');
  String m = dateTime.month.toString().padLeft(2, '0');
  String d = dateTime.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

String cashIntToString(int cash) {
  String str = cash.toString();
  String cashStr = '';
  while (str.length > 3) {
    cashStr = ',${str.substring(str.length - 3)}$cashStr';
    str = str.substring(0, str.length - 3);
  }
  cashStr = '$str$cashStr원';
  return cashStr;
}

String profitIntToString(int profit) {
  String sign = '+';
  if (profit < 0) {
    sign = '-';
    profit *= -1;
  }
  return '$sign${cashIntToString(profit)}';
}

String weightToString(double weight) {
  return '${weight.toStringAsFixed(2)}%';
}

Color stringToBrightColor(String str) {
  int hash = str.hashCode;

  // hash to rgb
  int r = (hash & 0xFF0000) >> 16;
  int g = (hash & 0x00FF00) >> 8;
  int b = hash & 0x0000FF;

  // rgb to bright
  int bright = (r + b + g) ~/ 3;
  if (bright < 128) {
    int add = bright - 128;
    r += add;
    g += add;
    b += add;
  }

  // to Color
  return Color(0xFF000000 | (r << 16) | (g << 8) | b);
}

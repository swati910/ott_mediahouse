import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:provider/provider.dart';

class MovieSalesTable extends StatelessWidget {
  final List<Map<String, String>> movieSalesData = [
    {
      "date": "2024-03-15",
      "price": "185",
      "sale": "570",
      "views": "600",
      "revenue": "105450"
    },
    {
      "date": "2024-03-14",
      "price": "215",
      "sale": "770",
      "views": "800",
      "revenue": "165550"
    },
    {
      "date": "2024-03-13",
      "price": "190",
      "sale": "590",
      "views": "620",
      "revenue": "112100"
    },
    {
      "date": "2024-03-12",
      "price": "200",
      "sale": "650",
      "views": "690",
      "revenue": "130000"
    },
    {
      "date": "2024-03-11",
      "price": "175",
      "sale": "500",
      "views": "530",
      "revenue": "87500"
    },
    {
      "date": "2024-03-10",
      "price": "220",
      "sale": "740",
      "views": "780",
      "revenue": "162800"
    },
    {
      "date": "2024-03-09",
      "price": "195",
      "sale": "610",
      "views": "640",
      "revenue": "118950"
    },
    {
      "date": "2024-03-08",
      "price": "180",
      "sale": "580",
      "views": "620",
      "revenue": "104400"
    },
    {
      "date": "2024-03-07",
      "price": "210",
      "sale": "720",
      "views": "750",
      "revenue": "151200"
    },
    {
      "date": "2024-03-06",
      "price": "203",
      "sale": "630",
      "views": "650",
      "revenue": "127890"
    },
  ];

  MovieSalesTable({super.key});

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatter = NumberFormat.decimalPattern(); // For commas
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Column(
      children: [
        // Table Header
        Container(
          color: selectedThemeData.cardColor.withOpacity(0.6),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: const [
              _TableHeaderCell(label: 'Date'),
              _TableHeaderCell(label: 'Price'),
              _TableHeaderCell(label: 'Sale'),
              _TableHeaderCell(label: 'Views'),
              _TableHeaderCell(label: 'Revenue'),
            ],
          ),
        ),
        // Table Data
        Expanded(
          child: ListView.builder(
            itemCount: movieSalesData.length,
            itemBuilder: (context, index) {
              final row = movieSalesData[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selectedThemeData.canvasColor.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _TableCell(text: row['date']!),
                    _TableCell(
                        text: formatAmount(row['price']!)),
                    _TableCell(
                        text: formatter.format(int.parse(row['sale']!))),
                    _TableCell(
                        text: formatter.format(int.parse(row['views']!))),
                    _TableCell(
                        text: formatAmount(row['revenue']!)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String label;
  const _TableHeaderCell({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        style:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

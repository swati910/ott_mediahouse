import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_house/domain/entities/content.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/videoProvider.dart';

class PurchasedUsersTab extends StatefulWidget {
  final Content movie;
  final ThemeData theme;

  const PurchasedUsersTab({
    super.key,
    required this.movie,
    required this.theme,
  });

  @override
  State<PurchasedUsersTab> createState() => _PurchasedUsersTabState();
}

class _PurchasedUsersTabState extends State<PurchasedUsersTab> {
  int _currentPage = 0;
  final int _pageSize = 10;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers({int page = 0}) {
    if (widget.movie.id != null) {
      setState(() => _currentPage = page);
      Provider.of<VideoProvider>(context, listen: false).fetchPurchasedUsers(
        widget.movie.id!,
        page: page,
        size: _pageSize,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingPurchasedUsers && provider.purchasedUsers.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            ),
          );
        }

        final users = provider.purchasedUsers.where((u) {
          if (_searchQuery.trim().isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return (u.userName ?? '').toLowerCase().contains(q) ||
              (u.email ?? '').toLowerCase().contains(q) ||
              (u.mobileNumber ?? '').toLowerCase().contains(q) ||
              (u.transactionId ?? '').toLowerCase().contains(q) ||
              (u.city ?? '').toLowerCase().contains(q) ||
              (u.state ?? '').toLowerCase().contains(q);
        }).toList();

        final totalElements = provider.purchasedUsersTotalCount > 0
            ? provider.purchasedUsersTotalCount
            : users.length;
        final totalPages = provider.purchasedUsersTotalPages > 0
            ? provider.purchasedUsersTotalPages
            : 1;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Search
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchased Audience ($totalElements)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verified buyers who unlocked this title',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search user / phone...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              if (users.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No purchased users matching "$_searchQuery"'
                              : 'No purchase records found for this title yet.',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.grey.shade50,
                    ),
                    columns: const [
                      DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: users.map((u) {
                      final loc = [u.city, u.state]
                          .where((s) => s != null && s.trim().isNotEmpty)
                          .join(', ');
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                                  child: Text(
                                    (u.userName?.isNotEmpty == true)
                                        ? u.userName![0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  u.userName ?? 'User #${u.userId ?? u.id ?? "-"}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (u.mobileNumber != null && u.mobileNumber!.isNotEmpty)
                                  Text(
                                    u.mobileNumber!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (u.email != null && u.email!.isNotEmpty)
                                  Text(
                                    u.email!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              CurrencyFormatter.format(u.amountPaid ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              loc.isNotEmpty ? loc : 'India',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              u.transactionId ?? 'TXN-${u.id ?? "-"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              u.purchaseDate ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                u.paymentStatus ?? 'SUCCESS',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

              // Pagination Footer
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page ${_currentPage + 1} of $totalPages',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0
                                ? () => _loadUsers(page: _currentPage - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < totalPages - 1
                                ? () => _loadUsers(page: _currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

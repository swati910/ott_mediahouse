import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/response/getRaisedTicketListResponse.dart';
import '../../../../device/utils/ResponsiveWidget.dart';
import '../../../provider/themeProvider.dart';
import '../../../provider/ticketProvider.dart';
import '../../../widget/custom_textfield.dart';

class HelpDeskPage extends StatefulWidget {
  const HelpDeskPage({super.key});

  @override
  State<HelpDeskPage> createState() => _HelpDeskPageState();
}

class _HelpDeskPageState extends State<HelpDeskPage> {
  int? _selectedIndex;
  final _searchController = TextEditingController();
  final _responseController = TextEditingController();
  String _selectedTab = "All"; // "All", "Open", "Solved"
  String? _selectedCategoryFilter;

  final List<String> _categories = [
    'SETTLEMENT',
    'CONTENT',
    'TECHNICAL',
    'ACCOUNT',
    'GENERAL',
  ];

  final List<String> _priorities = [
    'HIGH',
    'MEDIUM',
    'LOW',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _fetchTickets() {
    final provider = context.read<TicketProvider>();
    provider.getRaisedTicketByUserId();
    _selectedIndex = null;
  }

  List<TicketRaised> _filteredTickets(List<TicketRaised> tickets) {
    final query = _searchController.text.trim().toLowerCase();
    return tickets.where((ticket) {
      // Tab status filter
      if (_selectedTab == "Open" && (ticket.isResolved == true)) return false;
      if (_selectedTab == "Solved" && (ticket.isResolved != true)) return false;

      // Category filter
      if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'ALL') {
        if ((ticket.category ?? '').toUpperCase() != _selectedCategoryFilter) {
          return false;
        }
      }

      // Query filter
      if (query.isNotEmpty) {
        final topic = (ticket.topic ?? ticket.title ?? '').toLowerCase();
        final desc = (ticket.description ?? '').toLowerCase();
        final email = (ticket.email ?? '').toLowerCase();
        final id = ticket.tickedId?.toString() ?? '';
        return topic.contains(query) ||
            desc.contains(query) ||
            email.contains(query) ||
            id.contains(query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedThemeData = context.watch<ThemeProvider>().getTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Help & Support Desk",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: selectedThemeData.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<TicketProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: selectedThemeData.primaryColor,
              ),
            );
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Error: ${provider.error}"),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchTickets,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final tickets = _filteredTickets(provider.tickets);

          return Column(
            children: [
              _buildHeader(selectedThemeData, context),
              Expanded(
                child: ResponsiveWidget.isDesktop(context)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTicketDetails(
                              selectedThemeData,
                              tickets,
                              provider,
                            ),
                          ),
                          Container(
                            width: 1,
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                          _buildSidebar(selectedThemeData, tickets),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSidebar(selectedThemeData, tickets, isMobile: true),
                          Expanded(
                            child: _buildTicketDetails(
                              selectedThemeData,
                              tickets,
                              provider,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData selectedThemeData, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceChip(
                label: const Text("All Tickets"),
                selected: _selectedTab == "All",
                onSelected: (_) => setState(() => _selectedTab = "All"),
                selectedColor: selectedThemeData.primaryColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _selectedTab == "All"
                      ? selectedThemeData.primaryColor
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Open"),
                selected: _selectedTab == "Open",
                onSelected: (_) => setState(() => _selectedTab = "Open"),
                selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _selectedTab == "Open"
                      ? const Color(0xFFF59E0B)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Resolved"),
                selected: _selectedTab == "Solved",
                onSelected: (_) => setState(() => _selectedTab = "Solved"),
                selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _selectedTab == "Solved"
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Search tickets / query...",
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = null),
                icon: const Icon(Icons.add_comment_outlined, size: 16),
                label: const Text('New Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedThemeData.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    ThemeData selectedThemeData,
    List<TicketRaised> tickets, {
    bool isMobile = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: isMobile ? double.infinity : 380,
      height: isMobile ? 260 : double.infinity,
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: tickets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No tickets found.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final isSelected = _selectedIndex == index;
                final isResolved = ticket.isResolved == true;
                final priority = (ticket.priority ?? 'MEDIUM').toUpperCase();

                Color priorityColor;
                if (priority == 'HIGH') {
                  priorityColor = const Color(0xFFEF4444);
                } else if (priority == 'LOW') {
                  priorityColor = const Color(0xFF10B981);
                } else {
                  priorityColor = const Color(0xFFF59E0B);
                }

                return Card(
                  color: isSelected
                      ? selectedThemeData.primaryColor.withValues(alpha: 0.12)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? selectedThemeData.primaryColor
                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    onTap: () => setState(() => _selectedIndex = index),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isResolved
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      child: Icon(
                        isResolved ? Icons.check_circle : Icons.pending_outlined,
                        color: isResolved
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      ticket.topic ?? ticket.title ?? 'Support Request',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(
                          ticket.description ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                priority,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            if (ticket.category != null &&
                                ticket.category!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                ticket.category!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTicketDetails(
    ThemeData selectedThemeData,
    List<TicketRaised> tickets,
    TicketProvider provider,
  ) {
    if (_selectedIndex == null || _selectedIndex! >= tickets.length) {
      return addTicket(provider, selectedThemeData);
    }

    final ticket = tickets[_selectedIndex!];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isResolved = ticket.isResolved == true;
    final priority = (ticket.priority ?? 'MEDIUM').toUpperCase();

    Color priorityColor = (priority == 'HIGH')
        ? const Color(0xFFEF4444)
        : (priority == 'LOW')
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.topic ?? ticket.title ?? "Support Query",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isResolved
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isResolved ? "SOLVED" : "OPEN",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isResolved
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Priority: $priority",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            if (ticket.category != null &&
                                ticket.category!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ticket.category!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete Ticket',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeTicket(ticket, provider),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Metadata Row
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  if (ticket.email != null)
                    _metaItem(Icons.email_outlined, 'Email', ticket.email!),
                  if (ticket.mobileNumber != null)
                    _metaItem(Icons.phone_outlined, 'Phone', ticket.mobileNumber!),
                  if (ticket.date != null)
                    _metaItem(
                      Icons.calendar_today_outlined,
                      'Created',
                      DateTime.fromMillisecondsSinceEpoch(ticket.date!).toString().split('.')[0],
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Query Description
              Text(
                "Query Description",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  ticket.description ?? 'No description provided.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),

              if (ticket.image != null && ticket.image!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  "Attachment",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ticket.image!,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Text('Image unavailable'),
                  ),
                ),
              ],

              if (ticket.feedback != null && ticket.feedback!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  "Support Admin Response",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    ticket.feedback!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget addTicket(TicketProvider provider, ThemeData theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raise a Support Ticket',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Our support and operations team typically responds within 24 hours',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 20),

              // Category & Priority Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: provider.selectedCategory,
                              dropdownColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              items: _categories.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) provider.setCategory(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Priority',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: provider.selectedPriority,
                              dropdownColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              items: _priorities.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(p, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) provider.setPriority(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subject / Topic
              Text(
                'Subject / Topic',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                controller: provider.topicController,
                hintText: 'e.g., Weekly Settlement Query for Batch #...',
                textInputType: TextInputType.text,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Query Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                controller: provider.descController,
                hintText: 'Describe your issue or request in detail...',
                textInputType: TextInputType.multiline,
                maxLine: 5,
              ),
              const SizedBox(height: 16),

              // Image Attachment
              provider.uploadedImageUrl == null || provider.uploadedImageUrl == ''
                  ? OutlinedButton.icon(
                      onPressed: provider.pickImage,
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Attach Screenshot / Document'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            provider.uploadedImageUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: provider.removeImage,
                          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                          label: const Text('Remove', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () async {
                  if (provider.topicController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a ticket subject')),
                    );
                    return;
                  }
                  final res = await provider.raiseTicket();
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message'].toString())),
                    );
                    _fetchTickets();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message']?.toString() ?? 'Error raising ticket')),
                    );
                  }
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Submit Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeTicket(TicketRaised ticket, TicketProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ticket #${ticket.tickedId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteQuery(ticket);
              if (mounted) {
                Navigator.of(context).pop();
                setState(() => _selectedIndex = null);
                _fetchTickets();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

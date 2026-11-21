import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_history.dart';
import 'evidence_viewer.dart';

class HistoryTable extends StatefulWidget {
  final List<AttendanceHistoryItem> history;
  final String studentName;

  const HistoryTable({
    super.key,
    required this.history,
    required this.studentName,
  });

  @override
  State<HistoryTable> createState() => _HistoryTableState();
}

class _HistoryTableState extends State<HistoryTable> {
  String _selectedFilter = 'Semua';
  DateTime? _selectedDate;
  int _pageSize = 8;
  int _currentPage = 1;

  final List<String> _filterOptions = [
    'Semua',
    'Hadir',
    'Terlambat',
    'Sakit',
    'Izin',
    'Tidur',
  ];

  Color _getStatusBadgeBg(String type) {
    switch (type.toLowerCase()) {
      case 'hadir':
        return const Color(0xFFDCFCE7);
      case 'terlambat':
        return const Color(0xFFFEF3C7);
      case 'sakit':
        return const Color(0xFFDBEAFE);
      case 'izin':
      case 'dispensasi':
        return const Color(0xFFF3E8FF);
      case 'tidur':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusBadgeText(String type) {
    switch (type.toLowerCase()) {
      case 'hadir':
        return const Color(0xFF15803D);
      case 'terlambat':
        return const Color(0xFFB45309);
      case 'sakit':
        return const Color(0xFF1D4ED8);
      case 'izin':
      case 'dispensasi':
        return const Color(0xFF7E22CE);
      case 'tidur':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF64748B);
    }
  }

  List<AttendanceHistoryItem> get _filteredHistory {
    var list = widget.history;

    // Filter Keterangan
    if (_selectedFilter != 'Semua') {
      list = list.where((item) {
        if (_selectedFilter == 'Izin') {
          return item.type == 'izin' || item.type == 'dispensasi';
        }
        return item.type.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }

    // Filter Tanggal
    if (_selectedDate != null) {
      list = list.where((item) {
        return item.timestamp.year == _selectedDate!.year &&
            item.timestamp.month == _selectedDate!.month &&
            item.timestamp.day == _selectedDate!.day;
      }).toList();
    }

    // Urut terbaru di atas (Sort by timestamp desc)
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredHistory;
    final totalItems = filtered.length;
    final maxPages = (totalItems / _pageSize).ceil();
    final paginatedItems = filtered
        .skip((_currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Controls
        Row(
          children: [
            // Filter Jenis Keterangan
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                    items: _filterOptions.map((opt) {
                      return DropdownMenuItem(value: opt, child: Text(opt));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filter Tanggal Button
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: _selectedDate != null
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF64748B),
              ),
              label: Text(
                _selectedDate != null
                    ? DateFormat('dd/MM').format(_selectedDate!)
                    : 'Tanggal',
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedDate != null
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: _selectedDate != null
                    ? const Color(0xFFE0E7FF)
                    : Colors.white,
                side: BorderSide(
                  color: _selectedDate != null
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFFCBD5E1),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            if (_selectedDate != null) ...[
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                tooltip: 'Reset Tanggal',
                onPressed: () {
                  setState(() {
                    _selectedDate = null;
                    _currentPage = 1;
                  });
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Tabel Riwayat
        if (filtered.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off_rounded,
                    size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text(
                  'Belum ada riwayat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Riwayat capture CCTV dan dokumen akan tampil di sini.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columnSpacing: 18,
                  horizontalMargin: 14,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Tanggal & Jam',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Keterangan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Bukti',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                  rows: paginatedItems.map((item) {
                    final dateStr = DateFormat('dd MMM yyyy\nHH:mm:ss')
                        .format(item.timestamp);

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              height: 1.3,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusBadgeBg(item.type),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusBadgeText(item.type),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          item.evidenceUrl.isNotEmpty
                              ? TextButton.icon(
                                  onPressed: () {
                                    EvidenceViewer.show(
                                      context,
                                      item: item,
                                      studentName: widget.studentName,
                                    );
                                  },
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 14),
                                  label: const Text('Lihat Bukti'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E3A8A),
                                    textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                  ),
                                )
                              : const Text(
                                  '-',
                                  style: TextStyle(color: Colors.grey),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Pagination Controls
          if (maxPages > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hal $_currentPage dari $maxPages ($totalItems riwayat)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _currentPage < maxPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}


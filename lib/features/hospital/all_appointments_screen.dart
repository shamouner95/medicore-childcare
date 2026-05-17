import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/hospital_provider.dart';
import 'widgets/appointment_card.dart';

class AllAppointmentsScreen extends ConsumerStatefulWidget {
  const AllAppointmentsScreen({super.key});

  @override
  ConsumerState<AllAppointmentsScreen> createState() => _AllAppointmentsScreenState();
}

class _AllAppointmentsScreenState extends ConsumerState<AllAppointmentsScreen> {
  String _statusFilter = 'All';
  DateTime? _dateFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(hospitalAppointmentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : AppColors.textDeep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Appointments',
          style: GoogleFonts.playfairDisplay(
            color: isDark ? Colors.white : AppColors.textDeep,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(isDark),
          Expanded(
            child: appointmentsAsync.when(
              data: (appointments) {
                final filtered = appointments.where((appt) {
                  // Status filter
                  if (_statusFilter != 'All' && 
                      (appt['status'] as String).toLowerCase() != _statusFilter.toLowerCase()) {
                    return false;
                  }
                  
                  // Date filter
                  if (_dateFilter != null) {
                    final apptDate = appt['appointmentDate'] as String;
                    final filterDateStr = DateFormat('yyyy-MM-dd').format(_dateFilter!);
                    if (apptDate != filterDateStr) return false;
                  }

                  // Search query
                  if (_searchQuery.isNotEmpty) {
                    final patientName = (appt['patientName'] as String).toLowerCase();
                    if (!patientName.contains(_searchQuery.toLowerCase())) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, 
                          size: 64, 
                          color: isDark ? Colors.white24 : AppColors.shelf
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No appointments found',
                          style: GoogleFonts.plusJakartaSans(
                            color: isDark ? Colors.white60 : AppColors.textDeep.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final appointment = filtered[index];
                    return AppointmentCard(
                      appointment: appointment,
                      isMobile: true,
                      docId: appointment['id'],
                      isDark: isDark,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search patient name...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.shelf),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.shelf),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.shelf),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                      items: ['All', 'Pending', 'Accepted', 'Completed', 'Cancelled']
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, style: GoogleFonts.plusJakartaSans()),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _statusFilter = val!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _dateFilter = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.shelf),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateFilter == null
                                ? 'Date'
                                : DateFormat('MMM dd, yyyy').format(_dateFilter!),
                            style: GoogleFonts.plusJakartaSans(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_dateFilter != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _dateFilter = null),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

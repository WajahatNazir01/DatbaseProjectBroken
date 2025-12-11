import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AdminDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  String selectedMenu = 'Doctors';
  String selectedReportType = 'Daily Patient Report';
  List<dynamic> doctors = [];
  List<dynamic> receptionists = [];
  List<dynamic> specializations = [];
  List<dynamic> reportData = [];
  Map<String, dynamic> reportSummary = {};
  bool isLoading = false;
  bool isLoadingSpecializations = false;
  bool isLoadingReports = false;
  int? selectedSpecializationId;

  // Date variables for reports
  DateTime selectedDate = DateTime.now();
  DateTime? startDate;
  DateTime? endDate;
  DateTimeRange? dateRange;

  // Form Controllers
  final doctorFirstNameController = TextEditingController();
  final doctorLastNameController = TextEditingController();
  final doctorAgeController = TextEditingController();
  final doctorPasswordController = TextEditingController();
  final doctorConsultationFeeController = TextEditingController();
  final doctorPhoneController = TextEditingController();
  final doctorExperienceController = TextEditingController();
  final doctorRegistrationController = TextEditingController();

  final receptionistFirstNameController = TextEditingController();
  final receptionistLastNameController = TextEditingController();
  final receptionistPhoneController = TextEditingController();
  final receptionistPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDoctors();
    fetchSpecializations();
  }

  @override
  void dispose() {
    doctorFirstNameController.dispose();
    doctorLastNameController.dispose();
    doctorAgeController.dispose();
    doctorPasswordController.dispose();
    doctorConsultationFeeController.dispose();
    doctorPhoneController.dispose();
    doctorExperienceController.dispose();
    doctorRegistrationController.dispose();
    receptionistFirstNameController.dispose();
    receptionistLastNameController.dispose();
    receptionistPhoneController.dispose();
    receptionistPasswordController.dispose();
    super.dispose();
  }

  // Fetch data methods
  Future<void> fetchDoctors() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/doctors'));
      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          doctors = data;
        });
      } else {
        setState(() {
          doctors = [];
        });
        print('Failed to fetch doctors: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        doctors = [];
      });
      print('Error fetching doctors: $e');
    }
  }

  Future<void> fetchReceptionists() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/receptionists'));
      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          receptionists = data;
        });
      } else {
        setState(() {
          receptionists = [];
        });
        print('Failed to fetch receptionists: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        receptionists = [];
      });
      print('Error fetching receptionists: $e');
    }
  }

  Future<void> fetchSpecializations() async {
    setState(() => isLoadingSpecializations = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/specializations'));
      setState(() => isLoadingSpecializations = false);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          specializations = data;
          if (specializations.isNotEmpty) {
            selectedSpecializationId = specializations[0]['specialization_id'];
          }
        });
      } else {
        setState(() {
          specializations = [];
        });
        print('Failed to fetch specializations: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoadingSpecializations = false;
        specializations = [];
      });
      print('Error fetching specializations: $e');
    }
  }

  // Report fetching methods
  Future<void> fetchReport() async {
    setState(() => isLoadingReports = true);
    reportData.clear();
    reportSummary.clear();

    try {
      String url = '';
      Map<String, String> queryParams = {};

      switch (selectedReportType) {
        case 'Daily Patient Report':
          url = '$baseUrl/reports/daily-patients';
          queryParams = {
            'date': selectedDate.toIso8601String().split('T')[0]
          };
          break;

        case 'Daily Doctor Report':
          url = '$baseUrl/reports/daily-doctors';
          queryParams = {
            'date': selectedDate.toIso8601String().split('T')[0]
          };
          break;

        case 'Patient Reports in Range':
          if (startDate != null && endDate != null) {
            url = '$baseUrl/reports/patients-range';
            queryParams = {
              'start_date': startDate!.toIso8601String().split('T')[0],
              'end_date': endDate!.toIso8601String().split('T')[0]
            };
          } else {
            showError('Please select start and end dates');
            setState(() => isLoadingReports = false);
            return;
          }
          break;

        case 'Doctor Reports in Range':
          if (startDate != null && endDate != null) {
            url = '$baseUrl/reports/doctors-range';
            queryParams = {
              'start_date': startDate!.toIso8601String().split('T')[0],
              'end_date': endDate!.toIso8601String().split('T')[0]
            };
          } else {
            showError('Please select start and end dates');
            setState(() => isLoadingReports = false);
            return;
          }
          break;
      }

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      setState(() => isLoadingReports = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          reportSummary = data['summary'] ?? {};
          reportData = data['data'] ?? [];
        });
      } else {
        showError('Failed to fetch report: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoadingReports = false);
      print('Error fetching report: $e');
      showError('Error: $e');
    }
  }

  // Date selection methods
  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      fetchReport();
    }
  }

  Future<void> selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateRange,
    );
    if (picked != null) {
      setState(() {
        dateRange = picked;
        startDate = picked.start;
        endDate = picked.end;
      });
      fetchReport();
    }
  }

  // Helper methods
  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // UI Widgets
  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_hospital,
                color: Color(0xFF4A90E2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'MedCare Admin',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (isWideScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Welcome, ${widget.userData['first_name']}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF666666)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar - shown on wide screens
          if (isWideScreen)
            Container(
              width: 260,
              color: Colors.white,
              child: _buildSidebar(),
            ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Mobile menu tabs
                if (!isWideScreen)
                  Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMobileTab('Doctors', Icons.medical_services),
                          _buildMobileTab('Receptionists', Icons.person),
                          _buildMobileTab('Reports', Icons.assessment),
                        ],
                      ),
                    ),
                  ),

                // Content Area
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildMenuItem('Doctors', Icons.medical_services),
        _buildMenuItem('Receptionists', Icons.person),
        _buildMenuItem('Reports', Icons.assessment),

        // Report types submenu when Reports is selected
        if (selectedMenu == 'Reports') _buildReportTypes(),
      ],
    );
  }

  Widget _buildReportTypes() {
    final reportTypes = [
      'Daily Patient Report',
      'Daily Doctor Report',
      'Patient Reports in Range',
      'Doctor Reports in Range',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 48, top: 16, bottom: 8),
          child: Text(
            'Report Types',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...reportTypes.map((type) => _buildReportTypeItem(type)).toList(),
      ],
    );
  }

  Widget _buildReportTypeItem(String type) {
    final isSelected = selectedReportType == type;
    return InkWell(
      onTap: () {
        setState(() {
          selectedReportType = type;
        });
        // Reset date range when switching report types
        if (type.contains('Range')) {
          startDate = null;
          endDate = null;
          dateRange = null;
        }
        // Fetch report data
        fetchReport();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFFCCCCCC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF666666),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon) {
    final isSelected = selectedMenu == title;
    return InkWell(
      onTap: () {
        setState(() => selectedMenu = title);
        if (title == 'Doctors') {
          fetchDoctors();
        } else if (title == 'Receptionists') {
          fetchReceptionists();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF666666),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF666666),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTab(String title, IconData icon) {
    final isSelected = selectedMenu == title;
    return InkWell(
      onTap: () {
        setState(() => selectedMenu = title);
        if (title == 'Doctors') {
          fetchDoctors();
        } else if (title == 'Receptionists') {
          fetchReceptionists();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF999999),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF666666),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (selectedMenu == 'Doctors') {
      return _buildDoctorsView();
    } else if (selectedMenu == 'Receptionists') {
      return _buildReceptionistsView();
    } else if (selectedMenu == 'Reports') {
      return _buildReportsView();
    } else {
      return Center(
        child: Text(
          '$selectedMenu - Coming Soon',
          style: const TextStyle(fontSize: 18, color: Color(0xFF666666)),
        ),
      );
    }
  }

  Widget _buildReportsView() {
    return Column(
      children: [
        // Report Header
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedReportType,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getReportDescription(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: fetchReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Generate Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Date Selection Section
        if (selectedReportType.contains('Daily') || selectedReportType.contains('Range'))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: const Color(0xFFF8F9FA),
            child: _buildDateSelection(),
          ),

        // Report Content
        Expanded(
          child: isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : reportData.isEmpty
              ? _buildEmptyReportView()
              : _buildReportData(),
        ),
      ],
    );
  }

  Widget _buildDateSelection() {
    final isDailyReport = selectedReportType.contains('Daily');
    final isRangeReport = selectedReportType.contains('Range');

    return Row(
      children: [
        if (isDailyReport) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF666666)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (isRangeReport) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => selectDateRange(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          startDate != null && endDate != null
                              ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')} to ${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                              : 'Select date range',
                          style: TextStyle(
                            fontSize: 14,
                            color: startDate != null && endDate != null ? Colors.black : const Color(0xFF999999),
                          ),
                        ),
                        const Icon(Icons.date_range, size: 18, color: Color(0xFF666666)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyReportView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Report Data',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "Generate Report" to fetch data',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportData() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary Cards
          if (reportSummary.isNotEmpty) _buildSummaryCards(),

          // Data Table
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _getDataTableColumns(),
                  rows: _getDataTableRows(),
                  headingRowColor: MaterialStateProperty.resolveWith(
                        (states) => const Color(0xFF4A90E2).withOpacity(0.1),
                  ),
                  dataRowHeight: 48,
                  headingRowHeight: 56,
                  horizontalMargin: 24,
                  columnSpacing: 32,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    List<Widget> cards = [];

    switch (selectedReportType) {
      case 'Daily Patient Report':
        cards = [
          _buildSummaryCard('Total Patients', reportSummary['total_patients']?.toString() ?? '0', Icons.people),
          _buildSummaryCard('New Patients', reportSummary['new_patients']?.toString() ?? '0', Icons.person_add),
          _buildSummaryCard('Appointments Today', reportSummary['appointments_today']?.toString() ?? '0', Icons.event_note),
          _buildSummaryCard('Admissions Today', reportSummary['admissions_today']?.toString() ?? '0', Icons.local_hospital),
        ];
        break;

      case 'Daily Doctor Report':
        cards = [
          _buildSummaryCard('Total Doctors', reportSummary['total_doctors']?.toString() ?? '0', Icons.medical_services),
          _buildSummaryCard('Total Appointments', reportSummary['total_appointments']?.toString() ?? '0', Icons.calendar_today),
          _buildSummaryCard('Total Revenue', '₹${reportSummary['total_revenue']?.toStringAsFixed(2) ?? '0.00'}', Icons.attach_money),
        ];
        break;

      case 'Patient Reports in Range':
        cards = [
          _buildSummaryCard('Total Patients', reportSummary['total_patients']?.toString() ?? '0', Icons.people),
          _buildSummaryCard('New Registrations', reportSummary['new_registrations']?.toString() ?? '0', Icons.person_add),
          _buildSummaryCard('Total Appointments', reportSummary['total_appointments']?.toString() ?? '0', Icons.event_note),
          _buildSummaryCard('Total Admissions', reportSummary['total_admissions']?.toString() ?? '0', Icons.local_hospital),
          _buildSummaryCard('Total Revenue', '₹${reportSummary['total_revenue']?.toStringAsFixed(2) ?? '0.00'}', Icons.attach_money),
        ];
        break;

      case 'Doctor Reports in Range':
        cards = [
          _buildSummaryCard('Total Doctors', reportSummary['total_doctors']?.toString() ?? '0', Icons.medical_services),
          _buildSummaryCard('Total Appointments', reportSummary['total_appointments']?.toString() ?? '0', Icons.calendar_today),
          _buildSummaryCard('Total Revenue', '₹${reportSummary['total_revenue']?.toStringAsFixed(2) ?? '0.00'}', Icons.attach_money),
          _buildSummaryCard('Avg Completion', '${reportSummary['average_completion_rate']?.toStringAsFixed(1) ?? '0'}%', Icons.trending_up),
        ];
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards,
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4A90E2), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _getDataTableColumns() {
    if (reportData.isEmpty) return [];

    // Get column names from first data row
    final firstRow = reportData[0];
    if (firstRow is! Map) return [];

    return firstRow.keys.map<DataColumn>((key) {
      return DataColumn(
        label: Text(
          _formatColumnName(key.toString()),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Color(0xFF333333),
          ),
        ),
      );
    }).toList();
  }

  List<DataRow> _getDataTableRows() {
    return reportData.map<DataRow>((item) {
      if (item is! Map) return DataRow(cells: []);

      return DataRow(
        cells: item.keys.map<DataCell>((key) {
          final value = item[key];
          return DataCell(
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                _formatCellValue(value),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(),
      );
    }).toList();
  }

  String _formatColumnName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  String _getReportDescription() {
    switch (selectedReportType) {
      case 'Daily Patient Report':
        return 'Shows patient activities and statistics for a specific day';
      case 'Daily Doctor Report':
        return 'Displays doctor performance, appointments, and revenue for today';
      case 'Patient Reports in Range':
        return 'Patient statistics, history, and activities between selected dates';
      case 'Doctor Reports in Range':
        return 'Comprehensive doctor performance metrics over a period';
      default:
        return '';
    }
  }

  // Add Doctor Dialog
  void showAddDoctorDialog() {
    if (specializations.isNotEmpty) {
      selectedSpecializationId = specializations[0]['specialization_id'];
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add New Doctor',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* Required fields',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField('First Name *', doctorFirstNameController),
                      const SizedBox(height: 16),
                      _buildTextField('Last Name *', doctorLastNameController),
                      const SizedBox(height: 16),
                      _buildTextField('Age *', doctorAgeController, isNumber: true),
                      const SizedBox(height: 16),
                      _buildTextField('Password *', doctorPasswordController, isPassword: true),
                      const SizedBox(height: 16),

                      // Specialization Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Specialization *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: isLoadingSpecializations
                                ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Loading specializations...'),
                            )
                                : specializations.isEmpty
                                ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('No specializations available'),
                            )
                                : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedSpecializationId,
                                isExpanded: true,
                                items: specializations.map((spec) {
                                  return DropdownMenuItem<int>(
                                    value: spec['specialization_id'],
                                    child: Text(spec['specialization_name'] ?? 'Unknown'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSpecializationId = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Optional fields
                      _buildTextField('Consultation Fee', doctorConsultationFeeController, isNumber: true),
                      const SizedBox(height: 16),
                      _buildTextField('Phone Number', doctorPhoneController),
                      const SizedBox(height: 16),
                      _buildTextField('Experience Years *', doctorExperienceController, isNumber: true),
                      const SizedBox(height: 16),
                      _buildTextField('Registration Number', doctorRegistrationController),
                      const SizedBox(height: 24),

                      // Add Doctor Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : addDoctor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            disabledBackgroundColor: const Color(0xFFBBDEFB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Add Doctor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Doctor view methods
  Widget _buildDoctorsView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Doctors',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${doctors.length} doctors registered',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: showAddDoctorDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Doctor',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Doctors List
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : doctors.isEmpty
              ? const Center(
            child: Text(
              'No doctors found',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200 ? 3 : constraints.maxWidth > 800 ? 2 : 1;

              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return _buildDoctorCard(doctor);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF4A90E2),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Dr. ${doctor['first_name']} ${doctor['last_name']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  doctor['specialization'] ?? 'General',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${doctor['doctor_login_id']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceptionistsView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receptionists',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${receptionists.length} receptionists registered',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: showAddReceptionistDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Receptionist',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Receptionists List
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : receptionists.isEmpty
              ? const Center(
            child: Text(
              'No receptionists found',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200 ? 3 : constraints.maxWidth > 800 ? 2 : 1;

              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: receptionists.length,
                itemBuilder: (context, index) {
                  final receptionist = receptionists[index];
                  return _buildReceptionistCard(receptionist);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReceptionistCard(Map<String, dynamic> receptionist) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF4A90E2),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${receptionist['first_name']} ${receptionist['last_name']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  receptionist['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${receptionist['receptionist_login_id']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showAddReceptionistDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Receptionist',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildTextField('First Name', receptionistFirstNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Last Name', receptionistLastNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Contact', receptionistPhoneController),
                  const SizedBox(height: 16),
                  _buildTextField('Password', receptionistPasswordController, isPassword: true),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : addReceptionist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        disabledBackgroundColor: const Color(0xFFBBDEFB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Add Receptionist',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> addDoctor() async {
    if (doctorFirstNameController.text.isEmpty ||
        doctorLastNameController.text.isEmpty ||
        doctorAgeController.text.isEmpty ||
        doctorPasswordController.text.isEmpty ||
        selectedSpecializationId == null ||
        doctorExperienceController.text.isEmpty) {
      showError(
          'Please fill all required fields (First Name, Last Name, Age, Password, Specialization, Experience Years)'
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final requestBody = {
        'first_name': doctorFirstNameController.text.trim(),
        'last_name': doctorLastNameController.text.trim(),
        'age': int.parse(doctorAgeController.text),
        'password': doctorPasswordController.text,
        'specialization_id': selectedSpecializationId,
        'experience_years': int.parse(doctorExperienceController.text),
      };

      // Optional fields
      if (doctorConsultationFeeController.text.isNotEmpty) {
        requestBody['consultation_fee'] = double.parse(doctorConsultationFeeController.text);
      }
      if (doctorPhoneController.text.isNotEmpty) {
        requestBody['phone_no'] = doctorPhoneController.text.trim();
      }
      if (doctorRegistrationController.text.isNotEmpty) {
        requestBody['registration_number'] = doctorRegistrationController.text.trim();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/doctors'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final doctor = data['doctor'];
        showSuccess('Doctor added successfully! Login ID: ${doctor['doctor_login_id']}');

        // Clear form
        doctorFirstNameController.clear();
        doctorLastNameController.clear();
        doctorAgeController.clear();
        doctorPasswordController.clear();
        doctorConsultationFeeController.clear();
        doctorPhoneController.clear();
        doctorExperienceController.clear();
        doctorRegistrationController.clear();

        Navigator.pop(context);
        fetchDoctors();
      } else {
        final errorData = jsonDecode(response.body);
        showError(errorData['error'] ?? 'Failed to add doctor');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError('Error: $e');
    }
  }

  Future<void> addReceptionist() async {
    if (receptionistFirstNameController.text.isEmpty ||
        receptionistLastNameController.text.isEmpty ||
        receptionistPhoneController.text.isEmpty ||
        receptionistPasswordController.text.isEmpty) {
      showError('Please fill all fields');
      return;
    }

    setState(() => isLoading = true);

    try {
      final requestBody = {
        'first_name': receptionistFirstNameController.text.trim(),
        'last_name': receptionistLastNameController.text.trim(),
        'contact_no': receptionistPhoneController.text.trim(),
        'password': receptionistPasswordController.text,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/receptionists'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final receptionist = data['receptionist'];
        showSuccess('Receptionist added successfully! Login ID: ${receptionist['receptionist_login_id']}');

        receptionistFirstNameController.clear();
        receptionistLastNameController.clear();
        receptionistPhoneController.clear();
        receptionistPasswordController.clear();

        Navigator.pop(context);
        fetchReceptionists();
      } else {
        final errorData = jsonDecode(response.body);
        showError(errorData['error'] ?? 'Failed to add receptionist');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError('Error: $e');
    }
  }
}
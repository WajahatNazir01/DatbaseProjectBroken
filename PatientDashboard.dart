
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class PatientDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PatientDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
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

  String selectedTab = 'Book Appointment';
  bool isLoading = false;

  // Doctors data
  List<dynamic> allDoctors = [];
  List<dynamic> filteredDoctors = [];
  TextEditingController searchController = TextEditingController();

  // Upcoming bookings data
  List<dynamic> upcomingBookings = [];

  // Medical records data
  List<dynamic> medicalRecords = [];

  @override
  void initState() {
    super.initState();
    fetchAllDoctors();
    fetchUpcomingBookings();
    fetchMedicalRecords();

    searchController.addListener(() {
      filterDoctors(searchController.text);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAllDoctors() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/doctors'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          allDoctors = data;
          filteredDoctors = data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        showError('Failed to fetch doctors');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError('Error: $e');
    }
  }

  Future<void> fetchUpcomingBookings() async {
    setState(() => isLoading = true);

    try {
      // DEBUG: Print the raw user data to see what keys exist
      print("------------------------------------------------");
      print("DEBUG: Raw User Data: ${widget.userData}");

      // FIX: Try to get ID from 'user_id', 'patient_id', OR 'id'
      final patientId = widget.userData['user_id'] ??
          widget.userData['patient_id'] ??
          widget.userData['id'];

      // Safety Check: Stop if ID is missing
      if (patientId == null) {
        print("CRITICAL ERROR: Patient ID is NULL. Cannot fetch bookings.");
        setState(() => isLoading = false);
        showError('Error: Could not find Patient ID');
        return;
      }

      print("DEBUG: Using Patient ID: $patientId");

      final response = await http.get(
        Uri.parse('$baseUrl/appointments?patient_id=$patientId'),
      );

      print("DEBUG: Response Code: ${response.statusCode}");
      print("DEBUG: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);
        List<dynamic> data = [];

        if (decodedData is List) {
          data = decodedData;
        } else if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('data')) {
            data = decodedData['data'];
          } else if (decodedData.containsKey('appointments')) {
            data = decodedData['appointments'];
          }
        }

        print("DEBUG: Found ${data.length} appointments");

        setState(() {
          upcomingBookings = data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print("Server Error: ${response.body}");
        showError('Failed to fetch: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Exception Caught: $e");
      showError('Error: $e');
    }
  }


  Future<void> fetchMedicalRecords() async {
    setState(() => isLoading = true);
    try {
      final patientId = widget.userData['user_id'] ?? widget.userData['patient_id'];
      final response = await http.get(
        Uri.parse('$baseUrl/consultations/patient/$patientId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          medicalRecords = data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void filterDoctors(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredDoctors = allDoctors;
      } else {
        filteredDoctors = allDoctors.where((doctor) {
          final fullName = '${doctor['first_name']} ${doctor['last_name']}'.toLowerCase();
          final specialization = (doctor['specialization_name'] ?? '').toLowerCase();
          return fullName.contains(query.toLowerCase()) ||
              specialization.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void showBookAppointmentDialog(Map<String, dynamic> doctor) {
    showDialog(
      context: context,
      builder: (context) => BookAppointmentDialog(
        doctor: doctor,
        patientId: widget.userData['user_id'] ?? widget.userData['patient_id'],
        baseUrl: baseUrl,
        onSuccess: () {
          fetchUpcomingBookings();
          showSuccess('Appointment booked successfully!');
        },
      ),
    );
  }

  Future<void> cancelAppointment(int appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Note: Make sure your backend supports DELETE on this route, or uses POST /cancel
      final response = await http.delete(
        Uri.parse('$baseUrl/appointments/$appointmentId'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        fetchUpcomingBookings();
        showSuccess('Appointment cancelled successfully');
      } else {
        showError('Failed to cancel appointment');
      }
    } catch (e) {
      showError('Error: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF4A90E2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.userData['first_name']} ${widget.userData['last_name']}',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Patient',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF666666)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Book Appointment', Icons.calendar_month),
                _buildTab('View Records', Icons.medical_information),
                _buildTab('Upcoming Bookings', Icons.event_note),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, IconData icon) {
    final isSelected = selectedTab == title;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF999999),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (selectedTab == 'Book Appointment') {
      return _buildBookAppointmentView();
    } else if (selectedTab == 'View Records') {
      return _buildMedicalRecordsView();
    } else {
      return _buildUpcomingBookingsView();
    }
  }

  Widget _buildBookAppointmentView() {
    if (isLoading && allDoctors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search doctors by name or specialization...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => searchController.clear(),
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Doctors List
        Expanded(
          child: filteredDoctors.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchController.text.isNotEmpty
                      ? Icons.search_off
                      : Icons.medical_services_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  searchController.text.isNotEmpty
                      ? 'No doctors found'
                      : 'No doctors available',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDoctors.length,
            itemBuilder: (context, index) {
              final doctor = filteredDoctors[index];
              return _buildDoctorCard(doctor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF4A90E2),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor['first_name']} ${doctor['last_name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doctor['specialization_name'] ?? 'General',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.work_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${doctor['experience_years'] ?? 0} years experience',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 24),
                Icon(Icons.payments_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Rs. ${doctor['consultation_fee'] ?? 0}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showBookAppointmentDialog(doctor),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Book Appointment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBookingsView() {
    // 1. Loading State
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Empty State (With Debug Button)
    if (upcomingBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No upcoming appointments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 20),

            // --- THIS IS THE FIX ---
            ElevatedButton.icon(
              onPressed: () {
                print("Manual Refresh Clicked!"); // This must show up
                fetchUpcomingBookings();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Force Fetch Bookings"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                "Click to check console logs",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    // 3. List Data State
    return RefreshIndicator(
      onRefresh: fetchUpcomingBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: upcomingBookings.length,
        itemBuilder: (context, index) {
          final booking = upcomingBookings[index];
          return _buildBookingCard(booking);

        },
      ),
    );
  }
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    // 1. ROBUST DATE PARSING
    DateTime displayDate;
    String? dateString = booking['appointment_date']?.toString();

    // Fallback to created_at if appointment_date is missing
    if (dateString == null || dateString == 'null') {
      dateString = booking['created_at']?.toString();
    }

    try {
      if (dateString != null) {
        displayDate = DateTime.parse(dateString);
      } else {
        displayDate = DateTime.now(); // Final fallback
      }
    } catch (e) {
      print("Date parsing error for booking ${booking['appointment_id']}: $e");
      displayDate = DateTime.now();
    }

    // 2. Visual Status Variables
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(displayDate.year, displayDate.month, displayDate.day);
    final isToday = bookingDay == today;
    final isTomorrow = bookingDay == today.add(const Duration(days: 1));

    // 3. Safe Data Access
    final doctorName = booking['doctor_name'] ?? 'Doctor ID: ${booking['doctor_id']}';
    final specialization = booking['specialization_name'] ?? 'General';

    // 4. Get time string - using the fixed _formatTime method
    String timeStr = _formatTime(booking['start_time']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isToday ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? const Color(0xFF4A90E2) : const Color(0xFFE0E0E0),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF4A90E2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. $doctorName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          specialization,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // REMOVED SCHEDULED BADGE - as requested
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Date and Time Row
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(displayDate), // Use the same date formatting
                  style: TextStyle(
                    fontSize: 14,
                    color: isToday ? const Color(0xFF4A90E2) :
                    isTomorrow ? Colors.orange : const Color(0xFF333333),
                    fontWeight: (isToday || isTomorrow) ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (isTomorrow) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TOMORROW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(), // Pushes time to the right
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),

            // Consultation Fee Row
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Rs. ${booking['consultation_fee'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),

            // REMOVED Cancel Appointment button - as requested
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsView() {
    if (isLoading && medicalRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: fetchMedicalRecords,
      child: medicalRecords.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_information_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No medical records',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your consultation records will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: medicalRecords.length,
        itemBuilder: (context, index) {
          final record = medicalRecords[index];
          return _buildMedicalRecordCard(record);
        },
      ),
    );
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> record) {
    final consultationDate = DateTime.parse(record['consultation_date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Color(0xFF4A90E2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${record['doctor_name'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        _formatDate(consultationDate),
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
            if (record['diagnosis'] != null && record['diagnosis'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Diagnosis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record['diagnosis'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
            if (record['blood_pressure'] != null ||
                record['temperature'] != null ||
                record['oxygen_saturation'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Vitals',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (record['blood_pressure'] != null)
                    _buildVitalChip('BP', record['blood_pressure'], Icons.favorite),
                  if (record['temperature'] != null)
                    _buildVitalChip('Temp', '${record['temperature']}°F', Icons.thermostat),
                  if (record['oxygen_saturation'] != null)
                    _buildVitalChip('SpO2', '${record['oxygen_saturation']}%', Icons.air),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4A90E2)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

      // Show like "Mon, Dec 13, 2025"
      return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _formatTime(dynamic time) {
    if (time == null) return 'Time not set';

    String timeStr = time.toString().trim();
    print("DEBUG: Raw time string: '$timeStr'");

    // Handle cases where time might be like "16:00:00.0000000" or "1970-01-01T16:00:00"
    if (timeStr.contains('T')) {
      // Extract time from ISO string like "1970-01-01T16:00:00"
      try {
        // Split at 'T' and get the time part
        String timePart = timeStr.split('T')[1];
        // Remove milliseconds if present
        timePart = timePart.split('.')[0];
        timeStr = timePart;
      } catch (e) {
        print("Error parsing ISO time: $e");
      }
    }

    // If time is in "HH:mm:ss" format, extract just "HH:mm"
    if (timeStr.contains(':')) {
      List<String> parts = timeStr.split(':');
      if (parts.length >= 2) {
        // Parse hour and minute
        String hourStr = parts[0];
        String minuteStr = parts[1];

        // Remove leading zeros from hour
        int hour = int.tryParse(hourStr) ?? 0;

        // Format as 12-hour time with AM/PM
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : hour;
        displayHour = displayHour == 0 ? 12 : displayHour;

        return '${displayHour.toString().padLeft(2, '0')}:${minuteStr.padLeft(2, '0')} $period';
      }
    }

    // Return original if no better format found
    return timeStr;
  }
}

// Booking Dialog
class BookAppointmentDialog extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final int patientId;
  final String baseUrl;
  final VoidCallback onSuccess;

  const BookAppointmentDialog({
    Key? key,
    required this.doctor,
    required this.patientId,
    required this.baseUrl,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<BookAppointmentDialog> createState() => _BookAppointmentDialogState();
}

class _BookAppointmentDialogState extends State<BookAppointmentDialog> {
  DateTime? selectedDate;
  Map<String, dynamic>? selectedSlot;
  List<dynamic> availableSlots = [];
  bool isLoadingSlots = false;
  bool isBooking = false;
  int currentStep = 0;

  final TextEditingController symptomsController = TextEditingController();
  final TextEditingController medicalHistoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    fetchAvailableSlots();
  }

  @override
  void dispose() {
    symptomsController.dispose();
    medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> fetchAvailableSlots() async {
    if (selectedDate == null) return;

    setState(() => isLoadingSlots = true);
    try {
      final dateStr = selectedDate!.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/doctors/${widget
            .doctor['doctor_id']}/available-schedule?date=$dateStr'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Handle both structure types (just in case)
          if (data is Map && data.containsKey('slots')) {
            availableSlots = (data['slots'] as List).where((slot) => slot['is_available'] == 1).toList();
          } else if (data is List) {
            availableSlots = data.where((slot) => slot['is_available'] == 1).toList();
          }

          isLoadingSlots = false;
        });
      } else {
        setState(() => isLoadingSlots = false);
        _showError('Failed to fetch available slots');
      }
    } catch (e) {
      setState(() => isLoadingSlots = false);
      _showError('Error: $e');
    }
  }

  Future<void> bookAppointment(String symptoms, String medicalHistory) async {
    if (selectedDate == null || selectedSlot == null) {
      _showError('Please select a date and time slot');
      return;
    }

    setState(() => isBooking = true);
    try {
      final dateStr = selectedDate!.toIso8601String().split('T')[0];

      final bookingResponse = await http.post(
        Uri.parse('${widget.baseUrl}/slots/book'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': widget.patientId,
          'doctor_id': widget.doctor['doctor_id'],
          'appointment_date': dateStr,
          'slot_id': selectedSlot!['slot_id'],
        }),
      );

      if (bookingResponse.statusCode == 201) {
        final bookingData = jsonDecode(bookingResponse.body);
        final appointmentId = bookingData['appointment_id'];

        final formResponse = await http.post(
          Uri.parse('${widget.baseUrl}/appointment-forms'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'appointment_id': appointmentId,
            'patient_id': widget.patientId,
            'symptoms': symptoms,
            'medical_history': medicalHistory,
          }),
        );

        setState(() => isBooking = false);

        if (formResponse.statusCode == 201) {
          Navigator.pop(context);
          widget.onSuccess();
        } else {
          Navigator.pop(context);
          widget.onSuccess();
          _showError('Appointment booked but form submission failed');
        }
      } else {
        setState(() => isBooking = false);
        final error = jsonDecode(bookingResponse.body);
        _showError(error['error'] ?? 'Failed to book appointment');
      }
    } catch (e) {
      setState(() => isBooking = false);
      _showError('Error: $e');
    }
  }

  Future<void> selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime maxDate = today.add(const Duration(days: 7));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? today,
      firstDate: today,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedSlot = null;
      });
      fetchAvailableSlots();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    String timeStr = time.toString().trim();

    if (timeStr.contains(' ')) {
      List<String> parts = timeStr.split(' ');
      for (String part in parts) {
        if (part.contains(':')) {
          timeStr = part;
          break;
        }
      }
    }

    if (timeStr.contains('_')) {
      timeStr = timeStr.split('_')[0];
    }

    if (timeStr.contains(':')) {
      List<String> parts = timeStr.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
    }

    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Dr. ${widget.doctor['first_name']} ${widget
                              .doctor['last_name']}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: currentStep == 0
                    ? _buildDateTimeSelection()
                    : _buildAppointmentForm(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
              ),
              child: currentStep == 0
                  ? _buildDateTimeFooter()
                  : _buildFormFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Appointments can be booked up to 7 days in advance',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? _formatDate(selectedDate!)
                        : 'Select a date',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF999999)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Available Time Slots',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        if (isLoadingSlots)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else
          if (availableSlots.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No slots available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Try selecting a different date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSlots.map((slot) {
                final isSelected = selectedSlot?['slot_id'] == slot['slot_id'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedSlot = slot;
                      currentStep = 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4A90E2) : Colors
                          .white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFFE0E0E0),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: isSelected ? Colors.white : const Color(
                              0xFF4A90E2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(slot['start_time']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(
                                0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
      ],
    );
  }

  Widget _buildAppointmentForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                        Icons.info_outline, size: 18, color: Color(0xFF1976D2)),
                    const SizedBox(width: 8),
                    const Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Date: ${_formatDate(selectedDate!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1565C0),
                  ),
                ),
                Text(
                  'Time: ${_formatTime(selectedSlot!['start_time'])}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Symptoms *',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: symptomsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe your symptoms...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF4A90E2), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value
                  .trim()
                  .isEmpty) {
                return 'Please describe your symptoms';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Medical History (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicalHistoryController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Any relevant medical history, allergies, current medications...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF4A90E2), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeFooter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Select a time slot',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFooter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isBooking ? null : () {
              setState(() {
                currentStep = 0;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isBooking ? null : () {
              if (_formKey.currentState!.validate()) {
                bookAppointment(
                  symptomsController.text.trim(),
                  medicalHistoryController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: isBooking
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'Confirm Booking',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
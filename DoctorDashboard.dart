import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DoctorDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DoctorDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
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

  String selectedTab = 'Patients';
  bool isLoading = false;

  // Schedule Data
  List<dynamic> timeSlots = [];
  Map<String, bool> scheduleMatrix = {};
  Map<String, bool> bookedSlots = {};
  String? specializationName;
  bool isEditingSchedule = false;

  // Patient & Appointment Data
  List<dynamic> allPatients = [];
  List<dynamic> filteredPatients = [];
  List<dynamic> upcomingAppointments = [];
  TextEditingController searchController = TextEditingController();

  // Consultation check tracking
  Map<int, bool> consultationExistsMap = {};

  final List<String> daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    searchController.addListener(() {
      filterPatients(searchController.text);
    });
  }

  Future<void> _initializeDashboard() async {
    setState(() => isLoading = true);
    await fetchTimeSlots();
    await fetchDoctorSchedule();
    await fetchDoctorDetails();
    await fetchDoctorPatients();
    await fetchUpcomingAppointments();
    await fetchBookedSlots();
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // --- API CALLS ---

  Future<void> fetchBookedSlots() async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final now = DateTime.now();
      final currentWeekday = now.weekday % 7;
      final startOfWeek = now.subtract(Duration(days: currentWeekday));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final response = await http.get(
        Uri.parse('$baseUrl/doctors/$doctorId/appointments?start_date=${startOfWeek.toIso8601String().split('T')[0]}&end_date=${endOfWeek.toIso8601String().split('T')[0]}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> appointments = jsonDecode(response.body);
        bookedSlots.clear();

        for (var appointment in appointments) {
          if (appointment['slot_id'] == null) continue;
          String dateStr = appointment['appointment_date'].toString().split('T')[0];
          final appointmentDate = DateTime.parse(dateStr);
          int dayOfWeek = appointmentDate.weekday % 7;
          final slotId = appointment['slot_id'];
          String key = '${dayOfWeek}_$slotId';
          bookedSlots[key] = true;
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error fetching booked slots: $e');
    }
  }

  Future<void> fetchDoctorPatients() async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final response = await http.get(
        Uri.parse('$baseUrl/doctors/$doctorId/patients'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          allPatients = data;
          filteredPatients = data;
        });
      }
    } catch (e) {
      print('Error fetching patients: $e');
    }
  }

  Future<void> fetchUpcomingAppointments() async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 7));

      final response = await http.get(
        Uri.parse('$baseUrl/doctors/$doctorId/appointments?start_date=${startDate.toIso8601String().split('T')[0]}&end_date=${endDate.toIso8601String().split('T')[0]}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> allAppointments = jsonDecode(response.body);

        // Clear previous data
        consultationExistsMap.clear();

        // Filter to get only scheduled appointments (status_id = 1)
        List<dynamic> scheduledAppointments = [];

        for (var appointment in allAppointments) {
          final statusId = appointment['status_id'] ?? 0;

          if (statusId == 1) { // Scheduled appointments only
            // Check if consultation exists
            final hasConsultation = await _checkConsultationExists(appointment['appointment_id']);

            // If consultation exists, mark appointment as completed
            if (hasConsultation) {
              await _markAppointmentAsCompleted(appointment['appointment_id']);
            } else {
              scheduledAppointments.add(appointment);
            }
          }
        }

        setState(() {
          upcomingAppointments = scheduledAppointments;
        });

        // Refresh the list after status updates
        await Future.delayed(const Duration(milliseconds: 500));
        await _refreshAppointmentsList();
      }
    } catch (e) {
      print('Error fetching appointments: $e');
      showError('Error: $e');
    }
  }

  Future<bool> _checkConsultationExists(int appointmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/consultations/appointment/$appointmentId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final exists = data['exists'] ?? false;

        setState(() {
          consultationExistsMap[appointmentId] = exists;
        });

        return exists;
      }
      return false;
    } catch (e) {
      print('Error checking consultation: $e');
      return false;
    }
  }

  Future<void> _markAppointmentAsCompleted(int appointmentId) async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final response = await http.put(
        Uri.parse('$baseUrl/appointments/$appointmentId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'updated_by_doctor_id': doctorId,
        }),
      );

      if (response.statusCode == 200) {
        print('Appointment $appointmentId marked as completed');
      }
    } catch (e) {
      print('Error marking appointment as completed: $e');
    }
  }

  Future<void> _refreshAppointmentsList() async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 7));

      final response = await http.get(
        Uri.parse('$baseUrl/doctors/$doctorId/appointments?start_date=${startDate.toIso8601String().split('T')[0]}&end_date=${endDate.toIso8601String().split('T')[0]}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> allAppointments = jsonDecode(response.body);

        // Filter to show only scheduled appointments (status_id = 1)
        final scheduledAppointments = allAppointments.where((appointment) {
          return (appointment['status_id'] ?? 0) == 1;
        }).toList();

        // Check consultation for each
        for (var appointment in scheduledAppointments) {
          await _checkConsultationExists(appointment['appointment_id']);
        }

        setState(() {
          upcomingAppointments = scheduledAppointments;
        });
      }
    } catch (e) {
      print('Error refreshing appointments: $e');
    }
  }

  Future<bool> _hasUpcomingAppointment(int patientId) async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 7));

      final response = await http.get(
        Uri.parse('$baseUrl/doctors/$doctorId/appointments?start_date=${startDate.toIso8601String().split('T')[0]}&end_date=${endDate.toIso8601String().split('T')[0]}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> appointments = jsonDecode(response.body);
        return appointments.any((apt) =>
        apt['patient_id'] == patientId &&
            (apt['status_id'] ?? 0) == 1
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchDoctorDetails() async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final response = await http.get(Uri.parse('$baseUrl/doctors/$doctorId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          specializationName = data['specialization_name'];
        });
      }
    } catch (e) {
      print('Error fetching doctor details: $e');
    }
  }

  Future<void> fetchTimeSlots() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/time-slots'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          timeSlots = data;
        });
      }
    } catch (e) {
      print('Error fetching time slots: $e');
      showError('Error: $e');
    }
  }

  Future<void> fetchDoctorSchedule() async {
    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];
      final response = await http.get(
        Uri.parse('$baseUrl/schedules?doctor_id=$doctorId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        scheduleMatrix.clear();

        for (var schedule in data) {
          if (schedule['is_active'] == true || schedule['is_active'] == 1) {
            String key = '${schedule['day_of_week']}_${schedule['slot_id']}';
            scheduleMatrix[key] = true;
          }
        }
        setState(() {});
      }
    } catch (e) {
      print('Error fetching doctor schedule: $e');
    }
  }

  Future<void> toggleScheduleSlot(int dayOfWeek, int slotId) async {
    String key = '${dayOfWeek}_$slotId';
    bool isCurrentlyActive = scheduleMatrix[key] ?? false;

    setState(() {
      scheduleMatrix[key] = !isCurrentlyActive;
    });

    try {
      final doctorId = widget.userData['user_id'] ?? widget.userData['doctor_id'];

      if (!isCurrentlyActive) {
        final response = await http.post(
          Uri.parse('$baseUrl/doctors/$doctorId/schedules'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'day_of_week': dayOfWeek,
            'slot_id': slotId,
            'is_active': 1,
          }),
        );

        if (response.statusCode != 201) {
          setState(() {
            scheduleMatrix[key] = isCurrentlyActive;
          });
          showError('Failed to add schedule slot');
        }
      } else {
        final scheduleResponse = await http.get(
          Uri.parse('$baseUrl/schedules?doctor_id=$doctorId&day_of_week=$dayOfWeek'),
        );

        if (scheduleResponse.statusCode == 200) {
          final List<dynamic> schedules = jsonDecode(scheduleResponse.body);
          final schedule = schedules.firstWhere(
                (s) => s['slot_id'] == slotId,
            orElse: () => null,
          );

          if (schedule != null) {
            final deleteResponse = await http.delete(
              Uri.parse('$baseUrl/schedules/${schedule['schedule_id']}'),
            );

            if (deleteResponse.statusCode != 200) {
              setState(() {
                scheduleMatrix[key] = isCurrentlyActive;
              });
              showError('Failed to remove schedule slot');
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        scheduleMatrix[key] = isCurrentlyActive;
      });
      showError('Error: $e');
    }
  }

  Future<void> saveSchedule() async {
    setState(() {
      isEditingSchedule = false;
    });
    await fetchBookedSlots();
    showSuccess('Schedule updated successfully');
  }

  // --- HELPERS ---

  void filterPatients(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredPatients = allPatients;
      } else {
        filteredPatients = allPatients.where((patient) {
          final fullName = '${patient['first_name']} ${patient['last_name']}'.toLowerCase();
          return fullName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  bool _isConsultButtonEnabled(Map<String, dynamic> appointment) {
    try {
      final now = DateTime.now();
      final dateStr = appointment['appointment_date']?.toString().split('T')[0];

      if (dateStr == null) return false;

      final appointmentDate = DateTime.parse(dateStr);
      final isToday = now.year == appointmentDate.year &&
          now.month == appointmentDate.month &&
          now.day == appointmentDate.day;

      final isScheduled = appointment['status_id'] == 1;
      final appointmentId = appointment['appointment_id'];
      final hasConsultation = consultationExistsMap[appointmentId] ?? false;

      // Enable only if: today + scheduled + no existing consultation
      return isToday && isScheduled && !hasConsultation;
    } catch (e) {
      print('Error checking consult button enabled: $e');
      return false;
    }
  }

  bool _shouldShowConsultButton(Map<String, dynamic> appointment) {
    final appointmentId = appointment['appointment_id'];
    final hasConsultation = consultationExistsMap[appointmentId] ?? false;
    final isScheduled = appointment['status_id'] == 1;

    // Show button if: scheduled and no consultation exists
    return isScheduled && !hasConsultation;
  }

  String _extractTimeOnly(String timeStr) {
    if (timeStr.contains('1970-01-01T')) {
      timeStr = timeStr.replaceFirst('1970-01-01T', '');
    }

    if (timeStr.contains('T')) {
      timeStr = timeStr.split('T')[1];
    }
    if (timeStr.contains('.')) {
      timeStr = timeStr.split('.')[0];
    }
    if (timeStr.contains('Z')) {
      timeStr = timeStr.replaceAll('Z', '');
    }

    return timeStr;
  }

  String _formatTime(dynamic time) {
    if (time == null) return '--:--';
    String timeStr = time.toString().trim();

    if (timeStr.isEmpty || timeStr == 'null') return '--:--';

    if (timeStr.contains('1970-01-01T')) {
      timeStr = timeStr.replaceFirst('1970-01-01T', '');
    }

    if (timeStr.contains('T')) {
      timeStr = timeStr.split('T')[1];
    }

    if (timeStr.contains('Z')) {
      timeStr = timeStr.replaceAll('Z', '');
    }

    if (timeStr.contains('.')) {
      timeStr = timeStr.split('.')[0];
    }

    if (timeStr.contains(':')) {
      List<String> parts = timeStr.split(':');

      if (parts.length >= 2) {
        String hourStr = parts[0];
        String minuteStr = parts[1];

        if (minuteStr.contains('.')) {
          minuteStr = minuteStr.split('.')[0];
        }

        try {
          int hour = int.parse(hourStr);
          int minute = int.parse(minuteStr);

          String period = hour >= 12 ? 'PM' : 'AM';
          int displayHour = hour > 12 ? hour - 12 : hour;
          displayHour = displayHour == 0 ? 12 : displayHour;

          return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
        } catch (e) {
          return '$hourStr:${minuteStr.padLeft(2, '0')}';
        }
      }
    }

    return timeStr;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == DateTime(now.year, now.month, now.day)) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _getStatusText(int statusId) {
    switch (statusId) {
      case 1: return 'SCHEDULED';
      case 2: return 'COMPLETED';
      case 3: return 'CANCELLED';
      case 4: return 'CONFIRMED';
      default: return 'PENDING';
    }
  }

  Color _getStatusColor(int statusId) {
    switch (statusId) {
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.red;
      case 4: return Colors.orange;
      default: return Colors.grey;
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

  String _getTimeUntilConsultation(Map<String, dynamic> appointment) {
    try {
      final now = DateTime.now();
      final dateStr = appointment['appointment_date']?.toString().split('T')[0];
      final timeStr = appointment['start_time']?.toString();

      if (dateStr == null || timeStr == null) return 'Not available';

      final appointmentDateTimeStr = '$dateStr ${_extractTimeOnly(timeStr)}';
      final appointmentDateTime = DateTime.parse(appointmentDateTimeStr.replaceAll(' ', 'T'));

      final difference = appointmentDateTime.difference(now);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''}';
      } else if (difference.inMinutes == 0) {
        return 'Now';
      } else {
        return 'Past';
      }
    } catch (e) {
      return 'Error';
    }
  }

  // --- UI BUILDERS ---

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
                Icons.local_hospital,
                color: Color(0xFF4A90E2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${widget.userData['first_name']} ${widget.userData['last_name']}',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (specializationName != null)
                  Text(
                    specializationName!,
                    style: const TextStyle(
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
            icon: const Icon(Icons.refresh, color: Color(0xFF666666)),
            onPressed: () => _initializeDashboard(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF666666)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Exit',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Patients', Icons.people),
                _buildTab('Appointments', Icons.event_note),
                _buildTab('Schedule', Icons.calendar_today),
              ],
            ),
          ),
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
        onTap: () {
          setState(() => selectedTab = title);
          if (title == 'Appointments') {
            fetchUpcomingAppointments();
          }
        },
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }

  Widget _buildContent() {
    if (selectedTab == 'Patients') {
      return _buildPatientsView();
    } else if (selectedTab == 'Appointments') {
      return _buildAppointmentsView();
    } else {
      return _buildScheduleView();
    }
  }

  Widget _buildPatientsView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search patients by name...',
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
        Expanded(
          child: filteredPatients.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  searchController.text.isNotEmpty
                      ? 'No patients found'
                      : 'No patients yet',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPatients.length,
            itemBuilder: (context, index) {
              return _buildPatientCard(filteredPatients[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    // Calculate age from date of birth if available
    int? age;
    if (patient['date_of_birth'] != null) {
      try {
        final dob = DateTime.parse(patient['date_of_birth']);
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      } catch (e) {
        age = patient['age'] as int?;
      }
    } else {
      age = patient['age'] as int?;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => showPatientDetails(patient),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Patient Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    '${patient['first_name'][0]}${patient['last_name'][0]}'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Patient Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${patient['first_name']} ${patient['last_name']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Patient ID
                    Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          patient['patient_login_id'] ?? 'ID: ${patient['patient_id']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Age and Gender
                    Row(
                      children: [
                        Icon(Icons.cake_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${age ?? 'N/A'} yrs',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),

                        if (patient['gender'] != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            patient['gender'].toString().toUpperCase(),
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),

                    // Contact info if available
                    if (patient['phone_no'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            patient['phone_no'],
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Status indicator (if patient has upcoming appointments)
              FutureBuilder<bool>(
                future: _hasUpcomingAppointment(patient['patient_id']),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available, size: 12, color: Colors.orange[700]!),
                          const SizedBox(width: 4),
                          Text(
                            'Upcoming',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700]!,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF999999)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showPatientDetails(Map<String, dynamic> patient) {
    // Calculate age from date of birth if available
    int? age;
    if (patient['date_of_birth'] != null) {
      try {
        final dob = DateTime.parse(patient['date_of_birth']);
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      } catch (e) {
        age = patient['age'] as int?;
      }
    } else {
      age = patient['age'] as int?;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Patient header
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: Text(
                      '${patient['first_name'][0]}${patient['last_name'][0]}'.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${patient['first_name']} ${patient['last_name']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        patient['patient_login_id'] ?? 'ID: ${patient['patient_id']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Patient details grid
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDetailRow('Age', '${age ?? 'N/A'} years'),
                    _buildDetailRow('Gender', patient['gender']?.toString() ?? 'Not specified'),
                    _buildDetailRow('Date of Birth', patient['date_of_birth']?.toString().split('T')[0] ?? 'Not available'),
                    _buildDetailRow('Phone', patient['phone_no'] ?? 'Not available'),
                    _buildDetailRow('Email', patient['email'] ?? 'Not available'),
                    _buildDetailRow('Address', patient['address'] ?? 'Not available'),
                    _buildDetailRow('Blood Group', patient['blood_group'] ?? 'Not available'),

                    const SizedBox(height: 20),

                    // Medical History button
                    if (patient['patient_id'] != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _viewMedicalHistory(patient);
                        },
                        icon: const Icon(Icons.history, size: 20),
                        label: const Text('View Medical History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewMedicalHistory(Map<String, dynamic> patient) {
    // Navigate to medical history screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Medical History'),
        content: const Text('Medical history feature coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConsultationDialog(Map<String, dynamic> appointment) async {
    final appointmentId = appointment['appointment_id'];

    // Check if consultation already exists before showing dialog
    final hasConsultation = consultationExistsMap[appointmentId] ?? false;
    if (hasConsultation) {
      showError('Consultation already completed for this appointment');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConsultationDialog(
        appointment: appointment,
        doctorId: widget.userData['user_id'] ?? widget.userData['doctor_id'],
        doctorName: 'Dr. ${widget.userData['first_name']} ${widget.userData['last_name']}',
        baseUrl: baseUrl,
        onSuccess: () {
          // Mark consultation as exists
          setState(() {
            consultationExistsMap[appointmentId] = true;
          });

          // Remove from UI immediately
          setState(() {
            upcomingAppointments.removeWhere((apt) =>
            apt['appointment_id'] == appointmentId);
          });

          // Refresh data
          Future.delayed(Duration.zero, () {
            fetchUpcomingAppointments();
            fetchBookedSlots();
          });

          showSuccess('Consultation completed successfully!');
        },
      ),
    );
  }

  Widget _buildAppointmentsView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.event_note, color: Color(0xFF4A90E2)),
              const SizedBox(width: 12),
              const Text(
                'Scheduled Appointments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF4A90E2)),
                onPressed: fetchUpcomingAppointments,
                tooltip: 'Refresh appointments',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${upcomingAppointments.length} appts',
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
        if (upcomingAppointments.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No scheduled appointments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No scheduled appointments for the next 7 days',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: fetchUpcomingAppointments,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchUpcomingAppointments,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: upcomingAppointments.length,
                itemBuilder: (context, index) {
                  final appointment = upcomingAppointments[index];

                  // Double-check status - should always be 1 but verify
                  final statusId = appointment['status_id'] ?? 0;
                  if (statusId != 1) {
                    // Skip non-scheduled appointments
                    return const SizedBox.shrink();
                  }

                  return _buildAppointmentCard(appointment);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    DateTime appointmentDate;
    try {
      final dateStr = appointment['appointment_date']?.toString().split('T')[0];
      appointmentDate = DateTime.parse(dateStr ?? DateTime.now().toString());
    } catch (e) {
      appointmentDate = DateTime.now();
    }

    final now = DateTime.now();
    final isToday = now.day == appointmentDate.day &&
        now.month == appointmentDate.month &&
        now.year == appointmentDate.year;

    final patientName = '${appointment['patient_first_name'] ?? 'Unknown'} '
        '${appointment['patient_last_name'] ?? ''}'.trim();

    final patientId = appointment['patient_login_id'] ??
        'ID: ${appointment['patient_id']}';

    final statusId = appointment['status_id'] ?? 1;
    final statusText = _getStatusText(statusId);

    final appointmentId = appointment['appointment_id'];
    final hasConsultation = consultationExistsMap[appointmentId] ?? false;
    final showConsultButton = _shouldShowConsultButton(appointment);
    final isConsultEnabled = _isConsultButtonEnabled(appointment);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
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
                        patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patientId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusId),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(appointmentDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: isToday ? const Color(0xFF4A90E2) : const Color(0xFF333333),
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
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
                const Spacer(),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${_formatTime(appointment['start_time'])} - ${_formatTime(appointment['end_time'])}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.numbers, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Appt #${appointment['appointment_id']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                if (appointment['phone_no'] != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    appointment['phone_no'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ],
            ),

            if (showConsultButton)
              Column(
                children: [
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isConsultEnabled ? () => _showConsultationDialog(appointment) : null,
                      icon: const Icon(Icons.medical_services, size: 18),
                      label: isConsultEnabled
                          ? const Text('Start Consultation')
                          : Column(
                        children: [
                          const Text('Consultation'),
                          Text(
                            _getTimeUntilConsultation(appointment),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConsultEnabled ? const Color(0xFF4CAF50) : Colors.grey[400],
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

            // Show consultation status if it exists
            if (hasConsultation)
              Column(
                children: [
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medical_services, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Consultation Completed',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (timeSlots.isEmpty) {
      return const Center(child: Text('No time slots available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Schedule',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEditingSchedule
                        ? 'Select available time slots for each day'
                        : 'Your available time slots',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (isEditingSchedule) {
                    saveSchedule();
                  } else {
                    setState(() {
                      isEditingSchedule = true;
                    });
                  }
                },
                icon: Icon(isEditingSchedule ? Icons.save : Icons.edit, size: 18),
                label: Text(isEditingSchedule ? 'Save Schedule' : 'Update Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 130,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90E2),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.access_time, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Time Slot',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ...daysOfWeek.map((day) => Container(
                        width: 100,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90E2),
                          border: Border(left: BorderSide(color: Colors.white24)),
                        ),
                        child: Text(
                          day.substring(0, 3).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      )),
                    ],
                  ),

                  ...timeSlots.map((slot) {
                    return Row(
                      children: [
                        Container(
                          width: 130,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                              right: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Text(
                            '${_formatTime(slot['start_time'])} - ${_formatTime(slot['end_time'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),

                        ...List.generate(7, (dayIndex) {
                          String key = '${dayIndex}_${slot['slot_id']}';
                          bool isAvailable = scheduleMatrix[key] ?? false;
                          bool isBooked = bookedSlots[key] ?? false;

                          Color cellColor;
                          Widget cellContent;

                          if (isEditingSchedule) {
                            cellColor = Colors.white;
                            cellContent = Transform.scale(
                              scale: 0.9,
                              child: Checkbox(
                                value: isAvailable,
                                onChanged: isBooked ? null : (value) {
                                  toggleScheduleSlot(dayIndex, slot['slot_id']);
                                },
                                activeColor: const Color(0xFF4A90E2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            );
                          } else {
                            if (isBooked) {
                              cellColor = const Color(0xFFE3F2FD);
                              cellContent = Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bookmark, size: 16, color: Color(0xFF1565C0)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Booked',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              );
                            } else if (isAvailable) {
                              cellColor = const Color(0xFFF1F8E9);
                              cellContent = const Icon(Icons.check_circle, size: 20, color: Color(0xFF4CAF50));
                            } else {
                              cellColor = Colors.white;
                              cellContent = const SizedBox.shrink();
                            }
                          }

                          return Container(
                            width: 100,
                            height: 60,
                            decoration: BoxDecoration(
                              color: cellColor,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                                right: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: Center(child: cellContent),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!isEditingSchedule)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Checkmarks indicate available slots for patients. Blue cells are already booked.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          if (isEditingSchedule)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFFE65100), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Check boxes to mark availability. Booked slots cannot be modified. Click "Save Schedule" when done.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// CONSULTATION DIALOG WITH ACTION TYPES
class ConsultationDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final int doctorId;
  final String doctorName;
  final String baseUrl;
  final VoidCallback onSuccess;

  const ConsultationDialog({
    Key? key,
    required this.appointment,
    required this.doctorId,
    required this.doctorName,
    required this.baseUrl,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<ConsultationDialog> createState() => _ConsultationDialogState();
}

class _ConsultationDialogState extends State<ConsultationDialog> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isSubmitting = false;

  // Form controllers
  final TextEditingController bpController = TextEditingController();
  final TextEditingController tempController = TextEditingController();
  final TextEditingController oxygenController = TextEditingController();
  final TextEditingController diagnosisController = TextEditingController();
  final TextEditingController actionNotesController = TextEditingController();

  // Medicine form controllers
  final List<Map<String, TextEditingController>> medicineControllers = [];
  int medicineCounter = 1;

  // Action Types
  List<Map<String, dynamic>> actionTypes = [];
  Map<int, bool> selectedActions = {};

  @override
  void initState() {
    super.initState();
    _addMedicineRow();
    _fetchActionTypes();
  }

  @override
  void dispose() {
    bpController.dispose();
    tempController.dispose();
    oxygenController.dispose();
    diagnosisController.dispose();
    actionNotesController.dispose();
    _disposeMedicineControllers();
    super.dispose();
  }

  void _disposeMedicineControllers() {
    for (var medicine in medicineControllers) {
      medicine['name']?.dispose();
      medicine['dosage']?.dispose();
      medicine['frequency']?.dispose();
      medicine['duration']?.dispose();
    }
  }

  void _addMedicineRow() {
    setState(() {
      medicineControllers.add({
        'name': TextEditingController(),
        'dosage': TextEditingController(),
        'frequency': TextEditingController(),
        'duration': TextEditingController(),
      });
      medicineCounter++;
    });
  }

  void _removeMedicineRow(int index) {
    if (medicineControllers.length > 1) {
      setState(() {
        medicineControllers[index]['name']?.dispose();
        medicineControllers[index]['dosage']?.dispose();
        medicineControllers[index]['frequency']?.dispose();
        medicineControllers[index]['duration']?.dispose();
        medicineControllers.removeAt(index);
        medicineCounter--;
      });
    }
  }

  Future<void> _fetchActionTypes() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/action-types'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          actionTypes = List<Map<String, dynamic>>.from(data);
          for (var action in actionTypes) {
            selectedActions[action['action_type_id']] = false;
          }
        });
      } else {
        // If action-types endpoint doesn't exist, create default actions
        _createDefaultActions();
      }
    } catch (e) {
      // If endpoint fails, create default actions
      _createDefaultActions();
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _createDefaultActions() {
    setState(() {
      actionTypes = [
        {'action_type_id': 1, 'action_name': 'Follow-up Required'},
        {'action_type_id': 2, 'action_name': 'Lab Tests Needed'},
        {'action_type_id': 3, 'action_name': 'Refer to Specialist'},
        {'action_type_id': 4, 'action_name': 'Admission Recommended'},
        {'action_type_id': 5, 'action_name': 'Diet Plan'},
        {'action_type_id': 6, 'action_name': 'Exercise Regimen'},
        {'action_type_id': 7, 'action_name': 'Rest Recommended'},
      ];
      for (var action in actionTypes) {
        selectedActions[action['action_type_id']] = false;
      }
    });
  }

  Future<bool> _submitConsultation() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() => isSubmitting = true);

    try {
      print('=== CONSULTATION SUBMISSION STARTED ===');

      // First check if consultation already exists
      print('Checking if consultation already exists...');
      final checkResponse = await http.get(
        Uri.parse('${widget.baseUrl}/consultations/appointment/${widget.appointment['appointment_id']}'),
      );

      if (checkResponse.statusCode == 200) {
        final checkData = jsonDecode(checkResponse.body);
        if (checkData['exists'] == true) {
          throw Exception('Consultation already exists for this appointment');
        }
      }

      // 1. Create consultation
      print('Creating consultation...');
      final consultationResponse = await http.post(
        Uri.parse('${widget.baseUrl}/consultations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appointment_id': widget.appointment['appointment_id'],
          'doctor_id': widget.doctorId,
          'patient_id': widget.appointment['patient_id'],
          'blood_pressure': bpController.text.trim(),
          'temperature': tempController.text.isNotEmpty
              ? double.tryParse(tempController.text)
              : null,
          'oxygen_saturation': oxygenController.text.isNotEmpty
              ? int.tryParse(oxygenController.text)
              : null,
          'diagnosis': diagnosisController.text.trim(),
        }),
      );

      print('Consultation creation response: ${consultationResponse.statusCode}');
      print('Consultation creation body: ${consultationResponse.body}');

      if (consultationResponse.statusCode != 201) {
        final error = jsonDecode(consultationResponse.body);
        throw Exception(error['error'] ?? 'Failed to create consultation');
      }

      final consultationData = jsonDecode(consultationResponse.body);
      final consultationId = consultationData['consultation']['consultation_id'];
      print('Consultation created with ID: $consultationId');

      // 2. Add prescribed medicines (if any)
      print('Adding prescribed medicines...');
      for (var medicine in medicineControllers) {
        final name = medicine['name']!.text.trim();
        final dosage = medicine['dosage']!.text.trim();
        final frequency = medicine['frequency']!.text.trim();
        final duration = medicine['duration']!.text.trim();

        if (name.isNotEmpty && dosage.isNotEmpty &&
            frequency.isNotEmpty && duration.isNotEmpty) {
          final medicineResponse = await http.post(
            Uri.parse('${widget.baseUrl}/prescribed-medicines'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'consultation_id': consultationId,
              'medicine_name': name,
              'dosage': dosage,
              'frequency': frequency,
              'duration': duration,
            }),
          );

          if (medicineResponse.statusCode != 201) {
            print('Failed to add medicine: ${medicineResponse.body}');
          }
        }
      }

      // 3. Create consultation actions for selected checkboxes (if endpoint exists)
      print('Adding consultation actions...');
      final selectedActionIds = selectedActions.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      if (selectedActionIds.isNotEmpty) {
        try {
          // Try to create consultation-actions (this might not exist in your backend yet)
          for (var actionId in selectedActionIds) {
            final actionResponse = await http.post(
              Uri.parse('${widget.baseUrl}/consultation-actions'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'consultation_id': consultationId,
                'action_type_id': actionId,
                'notes': actionNotesController.text.trim().isNotEmpty
                    ? actionNotesController.text.trim()
                    : 'Action recommended by ${widget.doctorName}',
              }),
            );

            if (actionResponse.statusCode != 201) {
              print('Note: Consultation actions endpoint might not exist or failed: ${actionResponse.body}');
            }
          }
        } catch (e) {
          print('Note: Consultation actions endpoint might not exist: $e');
          // Continue without actions if endpoint doesn't exist
        }
      }

      // 4. Update appointment status to completed
      print('Updating appointment status to completed...');
      print('Appointment ID: ${widget.appointment['appointment_id']}');
      print('Doctor ID: ${widget.doctorId}');

      final statusUpdateResponse = await http.put(
        Uri.parse('${widget.baseUrl}/appointments/${widget.appointment['appointment_id']}/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'updated_by_doctor_id': widget.doctorId,
        }),
      );

      print('Status update response: ${statusUpdateResponse.statusCode}');
      print('Status update body: ${statusUpdateResponse.body}');

      if (statusUpdateResponse.statusCode != 200) {
        throw Exception('Failed to update appointment status');
      }

      final statusResult = jsonDecode(statusUpdateResponse.body);
      print('Appointment marked as completed. Previous status: ${statusResult['previous_status']}, New status: ${statusResult['new_status']}');

      setState(() => isSubmitting = false);
      return true;

    } catch (e) {
      print('Error in _submitConsultation: $e');
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Widget _buildActionTypesSection() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (actionTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'No action types available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select recommended actions for this consultation',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Action Type Checkboxes
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actionTypes.map((action) {
            final actionId = action['action_type_id'] as int;
            final actionName = action['action_name'] as String;
            return FilterChip(
              label: Text(actionName),
              selected: selectedActions[actionId] ?? false,
              onSelected: (bool selected) {
                setState(() {
                  selectedActions[actionId] = selected;
                });
              },
              selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
              checkmarkColor: const Color(0xFF4CAF50),
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: selectedActions[actionId] ?? false
                    ? const Color(0xFF4CAF50)
                    : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Notes for actions
        TextFormField(
          controller: actionNotesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Action Notes (Optional)',
            hintText: 'Add any additional notes for the selected actions...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientName = '${widget.appointment['patient_first_name'] ?? ''} '
        '${widget.appointment['patient_last_name'] ?? ''}'.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Consultation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          patientName,
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

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vitals Section
                      const Text(
                        'Patient Vitals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record the patient\'s vital signs',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Vitals Input Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: bpController,
                              decoration: const InputDecoration(
                                labelText: 'Blood Pressure',
                                hintText: 'e.g., 120/80',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: tempController,
                              decoration: const InputDecoration(
                                labelText: 'Temperature (°F)',
                                hintText: 'e.g., 98.6',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: oxygenController,
                              decoration: const InputDecoration(
                                labelText: 'Oxygen Saturation (%)',
                                hintText: 'e.g., 98',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      // Diagnosis Section
                      const SizedBox(height: 24),
                      const Text(
                        'Diagnosis & Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: diagnosisController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis',
                          hintText: 'Enter diagnosis and notes...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter diagnosis';
                          }
                          return null;
                        },
                      ),

                      // Action Types Section
                      const SizedBox(height: 24),
                      _buildActionTypesSection(),

                      // Medicines Section
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Prescribed Medicines',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                            onPressed: _addMedicineRow,
                            tooltip: 'Add another medicine',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add prescribed medicines (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Medicine List
                      ...medicineControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controllers = entry.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.medication, color: Color(0xFF4CAF50), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Medicine ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (medicineControllers.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                        onPressed: () => _removeMedicineRow(index),
                                        tooltip: 'Remove medicine',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: controllers['name'],
                                        decoration: const InputDecoration(
                                          labelText: 'Medicine Name',
                                          hintText: 'e.g., Paracetamol',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: controllers['dosage'],
                                        decoration: const InputDecoration(
                                          labelText: 'Dosage',
                                          hintText: 'e.g., 500mg',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: controllers['frequency'],
                                        decoration: const InputDecoration(
                                          labelText: 'Frequency',
                                          hintText: 'e.g., 3 times daily',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: controllers['duration'],
                                        decoration: const InputDecoration(
                                          labelText: 'Duration',
                                          hintText: 'e.g., 7 days',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
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
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        final success = await _submitConsultation();
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          widget.onSuccess();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        'Complete Consultation',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
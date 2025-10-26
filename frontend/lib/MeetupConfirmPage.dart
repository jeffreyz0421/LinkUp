// lib/meetup_confirm_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:http/http.dart' as http;

import 'session_manager.dart';
import 'services/profile_service.dart';
import 'main_screen_logic.dart';            // for styleUri, etc.
import 'MeetupLocationPage.dart';
import 'Meetup_master_and_vibe.dart';
// lib/meetup_confirm_page.dart

/// STEP 4/4: Confirmation + Create
class MeetupConfirmPage extends StatefulWidget {
  final String vibe;
  final String locationName;
  final mapbox.Point coordinates;
  final List<String> invited;

  const MeetupConfirmPage({
    required this.vibe,
    required this.locationName,
    required this.coordinates,
    required this.invited,
    super.key,
  });

  @override
  State<MeetupConfirmPage> createState() => _MeetupConfirmPageState();
}

class _MeetupConfirmPageState extends State<MeetupConfirmPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  DateTime? _start;

  bool get _canCreate => _nameCtrl.text.isNotEmpty && _start != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _createEvent() async {
    // TODO: hook this up to your backend
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// CONFIRM BUTTON AT BOTTOM
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        child: GestureDetector(
          onTap: _canCreate ? _createEvent : null,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: _canCreate
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFF16365),
                        Color(0xFFEC4899),
                        Color(0xFFF5600B),
                      ],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF9E9E9E), Color(0xFF9E9E9E)],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Confirm Meetup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ─── Top bar with orange back button and title ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5600B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Confirm Meetup',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: Color(0xFF1C1B1F),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Scrollable content ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Event Name
                    _Section(
                      label: 'Event Name',
                      borderColor: const Color(0xFFD1D5DB),
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter event name',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          hintStyle: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            color: Color(0xFFB2B2B2),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Date & Time
                    _Section(
                      label: 'Select Date & Time',
                      borderColor: const Color(0xFFD1D5DB),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _start == null
                              ? 'Pick a time'
                              : '${_start!.toLocal()}'.split('.').first,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF4B5563),
                        ),
                        onTap: _pickDateTime,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Description
                    _Section(
                      label: 'Description',
                      borderColor: const Color(0xFFD1D5DB),
                      fixedHeight: 92,
                      child: TextField(
                        controller: _descCtrl,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Enter event description',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.all(12),
                          hintStyle: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            color: Color(0xFFB2B2B2),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Vibe, Location, Invited boxes
                    _InfoBox(
                      title: 'Event Vibe',
                      value: widget.vibe,
                      backgroundColor: const Color(0xFFFFE3E3),
                      borderColor: const Color(0xFFD84040),
                    ),
                    const SizedBox(height: 24),
                    _InfoBox(
                      title: 'Location',
                      value: widget.locationName,
                      backgroundColor: const Color(0xFFFFEFF6),
                      borderColor: const Color(0xFFFF4099),
                    ),
                    const SizedBox(height: 24),
                    _InfoBox(
                      title: 'People Invited',
                      value: widget.invited.join(', '),
                      backgroundColor: const Color(0xFFFEF4E8),
                      borderColor: const Color(0xFFEA8408),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labeled input section with a border.
class _Section extends StatelessWidget {
  final String label;
  final Color borderColor;
  final Widget child;
  final double? fixedHeight;

  const _Section({
    required this.label,
    required this.borderColor,
    required this.child,
    this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: fixedHeight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// A read-only info box matching your friend’s style.
class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  final Color backgroundColor;
  final Color borderColor;

  const _InfoBox({
    required this.title,
    required this.value,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(width: 4, color: borderColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

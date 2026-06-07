import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/child_profile.dart';
import '../../utils/app_localizations.dart';

class VisitationCalendarScreen extends StatefulWidget {
  const VisitationCalendarScreen({super.key});

  @override
  State<VisitationCalendarScreen> createState() => _VisitationCalendarScreenState();
}

class _VisitationCalendarScreenState extends State<VisitationCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  CaseChildProfile? _selectedProfile;
  List<CaseChildProfile> _availableProfiles = [];
  List<Map<String, dynamic>> _allEvents = [];
  bool _isLoading = true;

  // Event type config
  static const _eventTypes = [
    {'label': 'With Mother', 'color': 0xFF1E88E5, 'icon': 'home'},
    {'label': 'With Father', 'color': 0xFF43A047, 'icon': 'home'},
    {'label': 'Handover', 'color': 0xFFE64A19, 'icon': 'repeat'},
    {'label': 'School Event', 'color': 0xFF8E24AA, 'icon': 'book'},
    {'label': 'Medical', 'color': 0xFFD32F2F, 'icon': 'heart'},
    {'label': 'Holiday', 'color': 0xFFF9A825, 'icon': 'sun'},
    {'label': 'Other', 'color': 0xFF546E7A, 'icon': 'calendar'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadProfiles();
  }

  void _loadProfiles() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final uid = auth.currentUserId;
    if (uid == null) { setState(() => _isLoading = false); return; }

    firestore.streamChildProfiles(uid).listen((profiles) {
      if (mounted) setState(() {
        _availableProfiles = profiles;
        _isLoading = false;
        if (profiles.isNotEmpty && _selectedProfile == null) {
          _selectedProfile = profiles.first;
        }
      });
    });

    firestore.streamVisitationEvents(uid).listen((events) {
      if (mounted) setState(() => _allEvents = events);
    });
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final profileId = _selectedProfile?.id ?? '';
    return _allEvents.where((e) {
      if ((e['childProfileId'] ?? '') != profileId) return false;
      final eventDate = DateTime.tryParse(e['date'] ?? '');
      return eventDate != null && isSameDay(eventDate, day);
    }).toList();
  }

  void _showAddEventDialog(DateTime day) {
    String selectedType = (_eventTypes.first['label'] as String);
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Text(
                  'Add Event — ${day.day}/${day.month}/${day.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 20),
                const Text('Event Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _eventTypes.map((type) {
                    final label = type['label'] as String;
                    final color = Color(type['color'] as int);
                    final isSelected = selectedType == label;
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedType = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color, width: isSelected ? 0 : 1),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Pick up at school gate at 4pm',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_selectedProfile == null) return;
                      final auth = Provider.of<AuthService>(context, listen: false);
                      final firestore = Provider.of<FirestoreService>(context, listen: false);
                      final uid = auth.currentUserId;
                      if (uid == null) return;

                      final typeConfig = _eventTypes.firstWhere((t) => t['label'] == selectedType);
                      await firestore.addVisitationEvent(uid, {
                        'childProfileId': _selectedProfile!.id,
                        'childName': _selectedProfile!.name,
                        'date': day.toIso8601String().split('T').first,
                        'type': selectedType,
                        'color': typeConfig['color'],
                        'notes': notesCtrl.text.trim(),
                      });

                      if (mounted) Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteEvent(String eventId) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final uid = auth.currentUserId;
    if (uid == null) return;
    await firestore.deleteVisitationEvent(uid, eventId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _selectedDay != null ? _eventsForDay(_selectedDay!) : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('visitation_calendar') ?? 'Visitation Calendar'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedDay != null)
            IconButton(
              icon: const Icon(LucideIcons.plusCircle),
              tooltip: 'Add event',
              onPressed: () => _showAddEventDialog(_selectedDay!),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableProfiles.isEmpty
              ? _buildNoProfileState()
              : Column(
                  children: [
                    _profileSelectorHeader(),
                    Card(
                      margin: const EdgeInsets.all(12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: TableCalendar<Map<String, dynamic>>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        eventLoader: _eventsForDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onFormatChanged: (format) => setState(() => _calendarFormat = format),
                        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return null;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: events.take(3).map((e) => Container(
                                width: 7, height: 7,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: Color(e['color'] as int? ?? 0xFF009688),
                                  shape: BoxShape.circle,
                                ),
                              )).toList(),
                            );
                          },
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(color: Colors.teal.withOpacity(0.4), shape: BoxShape.circle),
                          selectedDecoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                          markersMaxCount: 3,
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: true,
                          titleCentered: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildDayDetail(selectedDayEvents),
                    ),
                  ],
                ),
      floatingActionButton: _selectedDay != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEventDialog(_selectedDay!),
              label: const Text('Add Event'),
              icon: const Icon(LucideIcons.plus),
              backgroundColor: Colors.teal,
            )
          : null,
    );
  }

  Widget _buildDayDetail(List<Map<String, dynamic>> events) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedDay == null
                    ? 'Tap a date to view events'
                    : 'Schedule — ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (events.isNotEmpty)
                Text('${events.length} event${events.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.calendarPlus, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No events. Tap + to add one.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final ev = events[i];
                  final color = Color(ev['color'] as int? ?? 0xFF009688);
                  return Dismissible(
                    key: Key(ev['id'] ?? i.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.trash2, color: Colors.red),
                    ),
                    onDismissed: (_) => _deleteEvent(ev['id'] ?? ''),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ev['type'] ?? '',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                                if ((ev['notes'] as String?)?.isNotEmpty == true)
                                  Text(ev['notes'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.trash2, size: 16, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.calendar, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No child profile found.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Create a Child Profile first to start scheduling.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _profileSelectorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.teal.shade50,
      child: Row(
        children: [
          const Icon(LucideIcons.baby, size: 16, color: Colors.teal),
          const SizedBox(width: 8),
          const Text('Schedule for:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<CaseChildProfile>(
              value: _selectedProfile,
              isExpanded: true,
              underline: const SizedBox(),
              items: _availableProfiles.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) => setState(() => _selectedProfile = val),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/child_profile.dart';
import '../../utils/app_localizations.dart';

class ChildProfileScreen extends StatefulWidget {
  final CaseChildProfile? existingProfile;
  const ChildProfileScreen({super.key, this.existingProfile});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _schoolController;
  late TextEditingController _gradeController;
  late TextEditingController _specialNeedsController;
  late TextEditingController _routineController;
  late TextEditingController _workHoursA;
  late TextEditingController _workHoursB;
  
  String _livingArrangement = 'Pending';
  double _distance = 5.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _dobController = TextEditingController(text: p?.dob ?? '');
    _schoolController = TextEditingController(text: p?.school ?? '');
    _gradeController = TextEditingController(text: p?.grade ?? '');
    _specialNeedsController = TextEditingController(text: p?.specialNeeds ?? '');
    _routineController = TextEditingController(text: p?.dailyRoutine ?? '');
    _workHoursA = TextEditingController(text: p?.parentAWorkHours ?? '9 AM - 5 PM');
    _workHoursB = TextEditingController(text: p?.parentBWorkHours ?? '9 AM - 5 PM');
    _livingArrangement = p?.currentLivingArrangement ?? 'Pending';
    _distance = p?.distanceBetweenHomes ?? 5.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _schoolController.dispose();
    _gradeController.dispose();
    _specialNeedsController.dispose();
    _routineController.dispose();
    _workHoursA.dispose();
    _workHoursB.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter child name')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      
      final profile = CaseChildProfile(
        id: widget.existingProfile?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        dob: _dobController.text,
        school: _schoolController.text,
        grade: _gradeController.text,
        specialNeeds: _specialNeedsController.text,
        dailyRoutine: _routineController.text,
        currentLivingArrangement: _livingArrangement,
        distanceBetweenHomes: _distance,
        parentAWorkHours: _workHoursA.text,
        parentBWorkHours: _workHoursB.text,
        parentingPlan: widget.existingProfile?.parentingPlan,
      );

      await firestore.saveChildProfile(auth.currentUserId!, profile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child Profile Saved to Cloud!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('child_profile_context') ?? 'Child Profile & Context'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Basic Information'),
                _buildTextField('Child\'s Full Name', _nameController, LucideIcons.user),
                const SizedBox(height: 16),
                _buildDateField('Date of Birth', _dobController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('School Name', _schoolController, LucideIcons.school)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Grade/Class', _gradeController, LucideIcons.graduationCap)),
                  ],
                ),
                
                const SizedBox(height: 32),
                _sectionHeader('Health & Routine'),
                _buildTextField('Special Needs / Medical Conditions', _specialNeedsController, LucideIcons.stethoscope, maxLines: 2),
                const SizedBox(height: 16),
                _buildTextField('Daily Routine Snapshot', _routineController, LucideIcons.clock, hint: 'e.g. Wake up 7am, Football at 5pm', maxLines: 3),
                
                const SizedBox(height: 32),
                _sectionHeader('Custody Context'),
                const Text('Current Living Arrangement', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _livingArrangement,
                  items: ['Pending', 'With Mother', 'With Father', 'Split / Shared'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _livingArrangement = val!),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                Text('Distance Between Parents\' Residences: ${_distance.round()} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _distance,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_distance.round()} km',
                  onChanged: (val) => setState(() => _distance = val),
                  activeColor: Colors.teal,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Parent A Work Hours', _workHoursA, LucideIcons.briefcase)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Parent B Work Hours', _workHoursB, LucideIcons.briefcase)),
                  ],
                ),
                
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE CHILD PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Container(width: 40, height: 3, color: Colors.teal),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            DateTime initial = now.subtract(const Duration(days: 365 * 5));
            if (controller.text.isNotEmpty) {
              final parsed = DateTime.tryParse(controller.text);
              if (parsed != null) initial = parsed;
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(now.year - 25),
              lastDate: now,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(primary: Colors.teal.shade700),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              controller.text =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Tap to select date',
                prefixIcon: Icon(LucideIcons.calendar, size: 20, color: Colors.teal),
                suffixIcon: Icon(LucideIcons.calendarDays, size: 18, color: Colors.grey.shade400),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.teal),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

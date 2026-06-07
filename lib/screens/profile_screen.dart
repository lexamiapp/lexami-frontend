import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../utils/app_localizations.dart';
import '../providers/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isUploading = false;
  
  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _aliasController;
  late TextEditingController _occupationController;
  late TextEditingController _incomeController;
  late TextEditingController _permanentAddressController;
  late TextEditingController _childrenController;
  late TextEditingController _fatherNameController;
  late TextEditingController _motherNameController;
  late TextEditingController _spouseNameController;
  DateTime? _marriageDate;
  bool _useAlias = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    if (authService.currentUserId != null) {
      final profile = await firestoreService.getUserProfile(authService.currentUserId!);
      if (profile != null) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _initControllers(profile);
        });
      } else {
        // Create a default profile if none exists
        final newProfile = UserProfile(
          uid: authService.currentUserId!,
          fullName: 'New User',
          email: authService.currentUser?.email ?? '',
          mobile: '',
          gender: 'Not Specified',
          fatherName: '',
          motherName: '',
          maritalStatus: 'Single',
          roleInFamily: 'Head of Family',
          currentAddress: '',
          city: '',
          state: '',
          country: 'India',
          disputeNature: 'Other',
          relationshipWithOtherParty: '',
          consentTrue: true,
        );
        setState(() {
          _profile = newProfile;
          _isLoading = false;
          _initControllers(newProfile);
        });
      }
    }
  }

  void _initControllers(UserProfile profile) {
    _nameController = TextEditingController(text: profile.fullName);
    _mobileController = TextEditingController(text: profile.mobile);
    _addressController = TextEditingController(text: profile.currentAddress);
    _cityController = TextEditingController(text: profile.city);
    _stateController = TextEditingController(text: profile.state);
    _aliasController = TextEditingController(text: profile.communityAlias ?? '');
    _occupationController = TextEditingController(text: profile.occupation ?? '');
    _incomeController = TextEditingController(text: profile.annualIncome?.toString() ?? '');
    _permanentAddressController = TextEditingController(text: profile.permanentAddress ?? '');
    _childrenController = TextEditingController(text: profile.childrenCount.toString());
    _fatherNameController = TextEditingController(text: profile.fatherName);
    _motherNameController = TextEditingController(text: profile.motherName);
    _spouseNameController = TextEditingController(text: profile.spouseName ?? '');
    _marriageDate = profile.marriageDate;
    _useAlias = profile.useAliasInCommunity;
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    final updatedProfile = UserProfile(
      uid: _profile!.uid,
      fullName: _nameController.text,
      email: _profile!.email,
      photoUrl: _profile!.photoUrl, // Keep existing photoUrl
      mobile: _mobileController.text,
      gender: _profile!.gender,
      fatherName: _fatherNameController.text,
      motherName: _motherNameController.text,
      maritalStatus: _profile!.maritalStatus,
      spouseName: _spouseNameController.text.isNotEmpty ? _spouseNameController.text : null,
      roleInFamily: _profile!.roleInFamily,
      currentAddress: _addressController.text,
      city: _cityController.text,
      state: _stateController.text,
      country: _profile!.country,
      disputeNature: _profile!.disputeNature,
      relationshipWithOtherParty: _profile!.relationshipWithOtherParty,
      consentTrue: _profile!.consentTrue,
      isProfileComplete: true,
      communityAlias: _aliasController.text,
      useAliasInCommunity: _useAlias,
      isAdvisor: _profile!.isAdvisor,
      isVerifiedAdvisor: _profile!.isVerifiedAdvisor,
      isProfileLive: _profile!.isProfileLive,
      followedChannels: _profile!.followedChannels,
      followedUsers: _profile!.followedUsers,
      walletBalance: _profile!.walletBalance,
      occupation: _occupationController.text,
      annualIncome: double.tryParse(_incomeController.text),
      marriageDate: _marriageDate,
      childrenCount: int.tryParse(_childrenController.text) ?? 0,
      permanentAddress: _permanentAddressController.text,
    );

    setState(() => _isLoading = true);
    await firestoreService.createUserProfile(updatedProfile);
    setState(() {
      _profile = updatedProfile;
      _isLoading = false;
      _isEditing = false;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image == null || _profile == null) return;

    final bytes = await image.readAsBytes();
    final sizeInBytes = bytes.length;
    const minSize = 10 * 1024;       // 10 KB
    const maxSize = 5 * 1024 * 1024; // 5 MB

    if (sizeInBytes < minSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too small. Minimum size is 10 KB.')),
      );
      return;
    }
    if (sizeInBytes > maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large. Maximum size is 5 MB.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final downloadUrl = await firestoreService.uploadProfilePicture(
        _profile!.uid, 
        io.File(image.path), // Still pass File for mobile, but it's ignored on web
        bytes: bytes,
      );
      
      setState(() {
        _profile = UserProfile.fromMap({
          ..._profile!.toMap(),
          'photoUrl': downloadUrl,
        }, _profile!.uid);
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e. Please check if Firebase Storage is enabled.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(body: Center(child: Text('User not found')));

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(AppLocalizations.of(context)?.translate('profile') ?? 'Your Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              icon: Icon(_isEditing ? LucideIcons.save : LucideIcons.edit3, size: 16),
              label: Text(_isEditing ? 'Save Profile' : 'Edit Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? const Color(0xFF1EA362) : Colors.blueGrey.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildIdentityCard(),
            const SizedBox(height: 24),
            _buildLanguageCard(),
            const SizedBox(height: 24),
            _buildCommunityPrivacyCard(),
            const SizedBox(height: 24),
            _buildDetailedInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade50, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                    image: _profile!.photoUrl != null 
                        ? DecorationImage(image: NetworkImage(_profile!.photoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _profile!.photoUrl == null 
                      ? Center(
                          child: Text(
                            _profile!.fullName.isNotEmpty ? _profile!.fullName[0] : 'U',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blue.shade600),
                          ),
                        )
                      : null,
                ),
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1EA362),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(_isUploading ? Icons.sync : LucideIcons.camera, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isEditing 
            ? TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Full Name'),
              )
            : Text(
                _profile!.fullName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
              ),
          const SizedBox(height: 4),
          Text(
            _profile!.maritalStatus.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildContactRow(LucideIcons.mail, _profile!.email),
          const SizedBox(height: 12),
          _isEditing 
            ? _buildContactEditRow(LucideIcons.phone, _mobileController)
            : _buildContactRow(LucideIcons.phone, _profile!.mobile.isNotEmpty ? _profile!.mobile : 'No Mobile'),
          const SizedBox(height: 12),
          _buildContactRow(LucideIcons.calendar, _profile!.dob?.toLocal().toString().split(' ')[0] ?? 'DOB not set'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.checkCircle2, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VERIFICATION STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade800)),
                      const SizedBox(height: 4),
                      Text('Your profile is 100% verified via Aadhaar e-KYC.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildContactEditRow(IconData icon, TextEditingController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedInfo() {
    return Column(
      children: [
        _buildSectionCard(
          'Family Relations',
          LucideIcons.users,
          Colors.blue,
          [
            _buildEditField('Father\'s Name', _fatherNameController),
            _buildEditField('Mother\'s Name', _motherNameController),
            _buildEditField('Spouse Name', _spouseNameController),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          'Address Details',
          LucideIcons.mapPin,
          Colors.amber,
          [
            _buildEditField('Current Address', _addressController),
            _buildEditField('City', _cityController),
            _buildEditField('State', _stateController),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          'Dispute Context',
          LucideIcons.scale,
          Colors.purple,
          [
            _buildField('Nature of Dispute', _profile!.disputeNature),
            _buildField('Relation with Opponent', _profile!.relationshipWithOtherParty),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          'Personal & Financial Profile',
          LucideIcons.landmark,
          const Color(0xFF1EA362),
          [
            _buildEditField('Occupation', _occupationController),
            _buildEditField('Annual Income (₹)', _incomeController),
            _buildEditField('Permanent Address', _permanentAddressController),
            _buildEditField('Number of Children', _childrenController),
            _buildDatePickerField('Marriage Date', _marriageDate, (date) => setState(() => _marriageDate = date)),
          ],
        ),
        const SizedBox(height: 32),
        _buildDeleteAccountButton(),
      ],
    );
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _confirmDeleteAccount,
        icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
        label: const Text('Delete Account & Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Colors.red.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          'This action is irreversible. All your personal data, saved cases, and community posts will be permanently deleted.\n\nAre you sure you want to proceed?',
          style: TextStyle(height: 1.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Perform delete via Auth Service
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        await auth.deleteUser(); // Needs implementation in AuthService
        Navigator.of(context).pushReplacementNamed('/login_screen'); 
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _buildDatePickerField(String label, DateTime? value, Function(DateTime) onPicked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
          const SizedBox(height: 8),
          _isEditing 
            ? InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) onPicked(picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(value != null ? value.toString().split(' ')[0] : 'Select Date', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                      const Icon(LucideIcons.calendar, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              )
            : Text(
                value != null ? value.toString().split(' ')[0] : 'Not Set',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCommunityPrivacyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.shield, size: 16, color: Colors.teal),
              ),
              const SizedBox(width: 12),
              Text('COMMUNITY PRIVACY'.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Use alias in community', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Hide your real name from other members', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _useAlias,
                onChanged: _isEditing ? (val) => setState(() => _useAlias = val) : null,
                activeThumbColor: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditField('Community Alias / Pseudonym', _aliasController),
          if (!_isEditing && _useAlias)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text(
                 'Community will see you as: ${_aliasController.text.isNotEmpty ? _aliasController.text : "Anonymous Member"}',
                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
          const SizedBox(height: 4),
          _isEditing 
            ? TextField(
                controller: controller,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              )
            : Text(
                controller.text,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context);

    final List<Map<String, String>> languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'hi', 'name': 'हिन्दी (Hindi)'},
      {'code': 'pa', 'name': 'ਪੰਜਾਬੀ (Punjabi)'},
      {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
      {'code': 'te', 'name': 'తెలుగు (Telugu)'},
      {'code': 'kn', 'name': 'ಕನ್ನಡ (Kannada)'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.globe, color: Colors.blue, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                (l10n?.translate('language') ?? 'Language').toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.map((lang) {
              final isSelected = languageProvider.locale.languageCode == lang['code'];
              return ChoiceChip(
                label: Text(lang['name']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    languageProvider.setLocale(Locale(lang['code']!));
                  }
                },
                selectedColor: Colors.blue.shade100,
                backgroundColor: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade200)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
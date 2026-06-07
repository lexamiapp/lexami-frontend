import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/advisor_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/shimmer_loader.dart';

class AdvisorSearchScreen extends StatefulWidget {
  const AdvisorSearchScreen({super.key});

  @override
  State<AdvisorSearchScreen> createState() => _AdvisorSearchScreenState();
}

class _AdvisorSearchScreenState extends State<AdvisorSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String? _selectedState;
  String? _selectedSpecialization;
  double _minRating = 0.0;
  double _minExperience = 0.0;
  int _minCasesWon = 0;
  double _maxPrice = 10000; // Default max price slider limit

  final List<String> _categories = ['Advocates', 'Counselors'];
  final List<String> _states = ['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'Uttar Pradesh', 'West Bengal', 'Gujarat', 'Punjab'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showFilters() {
    // Determine active tab index and category
    final int index = _tabController.index;
    final String currentCategory = _categories[index];
    final bool isAdvocate = currentCategory == 'Advocates';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Refine $currentCategory', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const Text('Customize your search results', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  
                  // Common Filter: Location
                  _buildRefineLabel('Location / State'),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                    initialValue: _selectedState,
                    hint: const Text('All over India'),
                    items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (val) => setModalState(() => _selectedState = val),
                  ),
                  const SizedBox(height: 16),

                  if (isAdvocate) ...[
                    _buildRefineLabel('Practice Area / Specialization'),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                      initialValue: _selectedSpecialization,
                      hint: const Text('All Specializations'),
                      items: [null, 'Divorce', 'Child Custody', 'Alimony', 'Domestic Violence', 'Property Dispute', 'Maintenance']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s ?? 'All Specializations', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (val) => setModalState(() => _selectedSpecialization = val),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Common Filter: Rating
                  _buildRefineLabel('Minimum Rating: ${_minRating.toInt()}+ Stars'),
                   Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    activeColor: Colors.amber.shade700,
                    label: _minRating.toInt().toString(),
                    onChanged: (val) => setModalState(() => _minRating = val),
                  ),
                  
                  // Advocate/Counselor Filter: Experience
                  _buildRefineLabel('Experience: ${_minExperience.toStringAsFixed(1)}+ Years'),
                   Slider(
                    value: _minExperience,
                    min: 0,
                    max: 40,
                    activeColor: Colors.blue.shade700,
                    label: _minExperience.toStringAsFixed(1),
                    onChanged: (val) => setModalState(() => _minExperience = val),
                  ),

                  // Advocate Specific Filters
                  if (isAdvocate) ...[
                    _buildRefineLabel('Cases Won (Minimum): ${_minCasesWon.toInt()}+'),
                     Slider(
                      value: _minCasesWon.toDouble(),
                      min: 0,
                      max: 500,
                      activeColor: Colors.green.shade700,
                      label: _minCasesWon.toString(),
                      onChanged: (val) => setModalState(() => _minCasesWon = val.toInt()),
                    ),
                  ],

                  // Common/Specific: Price Limit
                  _buildRefineLabel(isAdvocate ? 'Budget (Price per Case): ₹${_maxPrice.toInt()}' : 'Budget (Price per Session): ₹${_maxPrice.toInt()}'),
                  Slider(
                    value: _maxPrice,
                    min: 0,
                    max: 50000,
                    activeColor: Colors.orange.shade700,
                    label: '₹${_maxPrice.toInt()}',
                    onChanged: (val) => setModalState(() => _maxPrice = val),
                  ),

                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade900, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('REFINE RESULTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Advisor Marketplace', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade700,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw), 
            onPressed: () => setState(() {}),
            tooltip: 'Refresh Advisors',
          ),
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal), 
            onPressed: _showFilters,
            tooltip: 'Refine Search',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((cat) => _buildAdvisorList(cat)).toList(),
      ),
    );
  }

  Widget _buildAdvisorList(String uiCategory) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AdvisorService.getAllAdvisors(),
      builder: (context, snapshot) {
        print('📊 Advisor List Build - ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, Data Length: ${snapshot.data?.length ?? 0}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonAdvisorList();
        }

        if (snapshot.hasError) {
          print('❌ Error in advisor list: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.alertCircle, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error loading advisors', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('${snapshot.error}', style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(LucideIcons.rotateCw, size: 16),
                  label: const Text('Retry'),
                )
              ],
            ),
          );
        }

        final allAdvisors = snapshot.data ?? [];
        print('📋 Total advisors from backend: ${allAdvisors.length}');
        if (allAdvisors.isNotEmpty) {
          print('👤 First advisor: ${allAdvisors.first['fullName'] ?? 'N/A'} - Status: ${allAdvisors.first['verificationStatus'] ?? 'N/A'}');
        }
        
        // Filter advisors based on category and filters
        final filteredAdvisors = allAdvisors.where((advisor) {
          // Filter by state if selected
          if (_selectedState != null && 
              (advisor['stateBarCouncil'] as String?)?.toLowerCase() != _selectedState?.toLowerCase()) {
            return false;
          }

          // Filter by specialization if selected (for advocates)
          if (uiCategory == 'Advocates' && _selectedSpecialization != null) {
            final area = (advisor['areaOfPractice'] as String?)?.toLowerCase() ?? '';
            if (!area.contains(_selectedSpecialization!.toLowerCase())) {
              return false;
            }
          }

          // Filter by experience if set
          if (_minExperience > 0) {
            final yearsOfPractice = (advisor['yearsOfPractice'] as num?)?.toDouble() ?? 0;
            if (yearsOfPractice < _minExperience) {
              return false;
            }
          }

          return true;
        }).toList();
        
        print('🔍 $uiCategory after filtering: ${filteredAdvisors.length} (State filter: $_selectedState, Spec filter: $_selectedSpecialization)');

        if (filteredAdvisors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.userX, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                if (allAdvisors.isEmpty)
                  const Text('No advisors registered yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                else
                  Text('No ${uiCategory.toLowerCase()} matching your filters.', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                if (allAdvisors.isNotEmpty && (_selectedState != null || _selectedSpecialization != null || _minExperience > 0)) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _selectedState = null;
                      _selectedSpecialization = null;
                      _minExperience = 0;
                    }),
                    child: const Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: filteredAdvisors.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildAdvisorCard(filteredAdvisors[index]),
        );
      },
    );
  }

  Widget _buildAdvisorCard(Map<String, dynamic> advisor) {
    final isVerified = advisor['verificationStatus'] == 'verified' && (advisor['isVerified'] == true);
    final isUnverified = advisor['verificationStatus'] == 'unverified' || advisor['verificationStatus'] == 'pending';
    
    // Extract data with defaults
    final String name = advisor['fullName'] ?? 'N/A';
    final String? photoUrl = advisor['photographUrl'];
    final String specialization = (advisor['areaOfPractice'] ?? 'General Practice') as String;
    final int yearsExp = (advisor['yearsOfPractice'] as num?)?.toInt() ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty 
                      ? NetworkImage(photoUrl) 
                      : null,
                    child: photoUrl == null || photoUrl.isEmpty 
                      ? Text(name.isNotEmpty ? name[0] : 'A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)) 
                      : null,
                  ),
                  // Verification badge - Blue checkmark for verified
                  if (isVerified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  // Unverified badge - Orange circle
                  if (isUnverified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.clock,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        // Status badge next to name
                        if (isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.check, size: 10, color: Colors.blue.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade600),
                                ),
                              ],
                            ),
                          ),
                        if (isUnverified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.clock, size: 10, color: Colors.orange.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Unverified',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Text(specialization, style: TextStyle(color: Colors.blue.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.briefcase, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('$yearsExp yrs', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.messageSquare, size: 16),
                  label: const Text('CHAT'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Start call logic
                  },
                  icon: const Icon(LucideIcons.phone, size: 16),
                  label: const Text('CALL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefineLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1),
      ),
    );
  }
}

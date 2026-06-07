import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
// Using the models defined in models/ if available
import '../widgets/app_drawer.dart';

// Since I don't see separate model files for LegalStatute and LandmarkJudgment in the viewed list, 
// I'll assume they are defined within firestore_service or models.
// Let's verify models directory.
import '../models/legal_knowledge.dart';

class LegalLibraryScreen extends StatefulWidget {
  const LegalLibraryScreen({super.key});

  @override
  State<LegalLibraryScreen> createState() => _LegalLibraryScreenState();
}

class _LegalLibraryScreenState extends State<LegalLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Legal Library', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade700,
          tabs: const [
            Tab(text: 'Statutes & Acts'),
            Tab(text: 'Landmark Judgments'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search laws, sections, or cases...',
                prefixIcon: const Icon(LucideIcons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatutesList(),
                _buildJudgmentsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatutesList() {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    return FutureBuilder<List<LegalStatute>>(
      future: firestore.getStatutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data ?? [];
        final filtered = items.where((i) => i.actName.toLowerCase().contains(_searchQuery) || i.section.toLowerCase().contains(_searchQuery) || i.description.toLowerCase().contains(_searchQuery)).toList();

        if (filtered.isEmpty) return const Center(child: Text('No statutes found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                title: Text(item.actName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(item.section, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(item.description, style: const TextStyle(height: 1.5)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJudgmentsList() {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    return FutureBuilder<List<LandmarkJudgment>>(
      future: firestore.getJudgments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data ?? [];
        final filtered = items.where((i) => i.caseName.toLowerCase().contains(_searchQuery) || i.summary.toLowerCase().contains(_searchQuery)).toList();

        if (filtered.isEmpty) return const Center(child: Text('No judgments found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                title: Text(item.caseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('${item.court} (${item.year})', style: const TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SUMMARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(item.summary, style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 16),
                        const Text('RULING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(item.ruling, style: const TextStyle(height: 1.5, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: item.applicableSections.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 10)))).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

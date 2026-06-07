import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class EvidenceSelector extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelected;
  final Function(List<Map<String, dynamic>>) onSelectionChanged;

  const EvidenceSelector({
    super.key,
    this.initialSelected = const [],
    required this.onSelectionChanged,
  });

  @override
  State<EvidenceSelector> createState() => _EvidenceSelectorState();
}

class _EvidenceSelectorState extends State<EvidenceSelector> {
  late List<Map<String, dynamic>> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.initialSelected);
  }

  void _toggleSelection(Map<String, dynamic> item) {
    setState(() {
      final index = _selectedItems.indexWhere((element) => element['id'] == item['id']);
      if (index >= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems.add(item);
      }
    });
    widget.onSelectionChanged(_selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SELECT FROM EVIDENCE VAULT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
            ),
            if (_selectedItems.isNotEmpty)
              Text(
                '${_selectedItems.length} SELECTED',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1.2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestore.streamEvidence(auth.currentUserId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final evidence = snapshot.data ?? [];
              if (evidence.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Center(
                    child: Text(
                      'No evidence in vault. Upload in Evidence Vault first.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: evidence.length,
                itemBuilder: (context, index) {
                  final item = evidence[index];
                  final isSelected = _selectedItems.any((element) => element['id'] == item['id']);
                  
                  IconData icon;
                  Color color;
                  switch (item['category']) {
                    case 'Photos': icon = LucideIcons.image; color = Colors.orange; break;
                    case 'Documents': icon = LucideIcons.fileText; color = Colors.green; break;
                    case 'Recordings': icon = LucideIcons.mic; color = Colors.purple; break;
                    default: icon = LucideIcons.file; color = Colors.blue;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => _toggleSelection(item),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: color, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              item['name'] ?? 'File',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                color: isSelected ? color : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

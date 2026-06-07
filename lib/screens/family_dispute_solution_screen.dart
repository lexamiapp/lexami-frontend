import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_drawer.dart';

class FamilyDisputeSolutionScreen extends StatelessWidget {
  const FamilyDisputeSolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Bubbles/Decorative elements for premium feel
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Header
                  const Text(
                    'Family Dispute Solution',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Holistic legal and emotional support to navigate your family matters with dignity and clarity.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Solution Cards
                  _buildSolutionItem(
                    index: '01',
                    title: 'Face to Face Confidential Counselling',
                    description: 'Connect with empathetic experts for private sessions. We prioritize your privacy and emotional well-being.',
                    icon: LucideIcons.userCheck,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(height: 20),
                  _buildSolutionItem(
                    index: '02',
                    title: 'Transparent Legal Fees & Analysis',
                    description: 'Get clear estimates of lawyer fees and court costs. No hidden charges—just fair, AI-driven financial insights.',
                    icon: LucideIcons.coins,
                    color: Colors.teal.shade400,
                  ),
                  const SizedBox(height: 20),
                  _buildSolutionItem(
                    index: '03',
                    title: 'Direct Access to Experts',
                    description: 'Find and call specialized family lawyers instantly. Browse through our network of 120+ verified advisors.',
                    icon: LucideIcons.phoneCall,
                    color: Colors.amber.shade400,
                  ),
                  const SizedBox(height: 20),
                  _buildSolutionItem(
                    index: '04',
                    title: 'Personalized AI Assistant',
                    description: '24/7 access to your \'Tathya\' AI for document drafting, alimony calculations, and instant legal guidance.',
                    icon: LucideIcons.brainCircuit,
                    color: Colors.purple.shade400,
                  ),
                  
                  const SizedBox(height: 64),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => context.go('/home/ai-match'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 10,
                        shadowColor: Colors.blue.withOpacity(0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('START CASE ANALYSIS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                          SizedBox(width: 12),
                          Icon(LucideIcons.arrowRight, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/advisors'),
                      child: Text(
                        'Browse Advisor Network',
                        style: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildSolutionItem({
    required String index,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.blueGrey.shade200,
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
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
}

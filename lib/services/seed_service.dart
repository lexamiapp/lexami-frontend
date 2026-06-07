import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class SeedService {
  static Future<void> seedLegalData() async {
    final db = FirebaseFirestore.instance;
    
    // 1. Seed Statutes (Acts)
    final statutes = [
      {
        'actName': 'Hindu Marriage Act, 1955',
        'section': 'Section 13',
        'description': 'Provides grounds for divorce including adultery, cruelty, desertion, conversion, insanity, leprosy, and venereal disease.',
        'keywords': ['divorce', 'grounds', 'cruelty', 'desertion', 'adultery'],
      },
      {
        'actName': 'Hindu Marriage Act, 1955',
        'section': 'Section 24',
        'description': 'Maintenance pendente lite and expenses of proceedings.',
        'keywords': ['maintenance', 'alimony', 'expenses', 'interim'],
      },
      {
        'actName': 'Hindu Marriage Act, 1955',
        'section': 'Section 26',
        'description': 'Custody of children. The court may pass orders with respect to the custody, maintenance, and education of minor children.',
        'keywords': ['custody', 'child', 'minor', 'education'],
      },
      {
        'actName': 'Hindu Adoptions and Maintenance Act, 1956',
        'section': 'Section 18',
        'description': 'Maintenance of wife. A Hindu wife shall be entitled to be maintained by her husband during her lifetime.',
        'keywords': ['maintenance', 'wife', 'alimony'],
      },
      {
        'actName': 'Protection of Women from Domestic Violence Act, 2005',
        'section': 'Section 12',
        'description': 'Application to Magistrate for various reliefs including protection orders, residence orders, and monetary relief.',
        'keywords': ['domestic violence', 'protection', 'monetary', 'relief'],
      },
    ];

    for (var s in statutes) {
      await db.collection(AppConstants.statutesCollection).add(s);
    }

    // 2. Seed Landmark Judgments
    final judgments = [
      {
        'caseName': 'Gaurav Nagpal v. Sumedha Nagpal',
        'court': 'Supreme Court of India',
        'year': 2009,
        'summary': 'The court held that the welfare of the child is the paramount consideration in custody matters, prevailing over the statutory rights of parents.',
        'ruling': 'Custody should be decided based on what serves the child best interest, regardless of parent gender.',
        'applicableSections': ['Section 26 HMA', 'Section 17 GWA'],
      },
      {
        'caseName': 'Rajnesh v. Neha',
        'court': 'Supreme Court of India',
        'year': 2020,
        'summary': 'Established comprehensive guidelines for payment of maintenance in matrimonial matters to prevent delays and ensure consistency.',
        'ruling': 'Both parties must file an Affidavit of Disclosure of Assets and Liabilities. Maintenance is payable from the date of application.',
        'applicableSections': ['Section 125 CrPC', 'Section 24 HMA', 'Section 18 HAMA'],
      },
      {
        'caseName': 'A. Jayachandra v. Aneel Kaur',
        'court': 'Supreme Court of India',
        'year': 2005,
        'summary': 'Dealt with the concept of mental cruelty in matrimonial cases.',
        'ruling': 'Mental cruelty is a course of conduct which inflicts such mental pain and suffering as would make it impossible for the party to live with the other.',
        'applicableSections': ['Section 13(1)(ia) HMA'],
      },
    ];

    for (var j in judgments) {
      await db.collection(AppConstants.judgmentsCollection).add(j);
    }

    // 3. Seed Expert Blogs
    final blogs = [
      {
        'authorId': 'l1',
        'authorName': 'Advocate Priya Sharma',
        'title': 'Navigating Divorce with Empathy',
        'content': 'Divorce is not just a legal battle; it is an emotional journey. It is important to prioritize mental well-being and child welfare. Mediation is often a better route than litigation for amicable settlements.',
        'createdAt': Timestamp.now(),
        'isApproved': true,
      },
      {
        'authorId': 'l2',
        'authorName': 'Advocate Suresh Menon',
        'title': 'Guide to Workplace Harassment Laws',
        'content': 'The POSH Act provides a robust framework for reporting harassment. If you feel anxious or unsafe, document every incident and report it to the internal committee immediately.',
        'createdAt': Timestamp.now(),
        'isApproved': true,
      },
    ];

    for (var b in blogs) {
      await db.collection(AppConstants.blogsCollection).add(b);
    }

    // 4. Seed Community Forum Topics
    final forumQuestions = [
      {
        'userId': 'user123',
        'authorName': 'AnxiousSoul',
        'title': 'Feeling lost after separation',
        'description': 'I have recently separated from my spouse and I feel extremely anxious about the future. Has anyone else gone through this? What are the first legal steps?',
        'tags': ['separation', 'anxiety', 'advice'],
        'answersCount': 5,
        'createdAt': Timestamp.now(),
      },
      {
        'userId': 'user456',
        'authorName': 'LegalSeeker',
        'title': 'How to document harassment?',
        'description': 'I need to know the best way to collect evidence for a harassment case without putting myself at risk.',
        'tags': ['harassment', 'evidence', 'safety'],
        'answersCount': 3,
        'createdAt': Timestamp.now(),
      },
    ];

    for (var f in forumQuestions) {
      await db.collection(AppConstants.forumCollection).add(f);
    }
  }
}

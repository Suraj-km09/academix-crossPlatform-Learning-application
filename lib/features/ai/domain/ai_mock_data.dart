import 'package:flutter/material.dart';

enum ResourceType { note, pyq, mcq, dsa }

enum TopicStatus { strong, proficient, moderateGap, criticalGap }

class AcademicResource {
  const AcademicResource({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.subtitle,
    required this.badgeText,
    required this.targetRoute,
    this.rating = 4.8,
  });

  final String id;
  final String title;
  final ResourceType type;
  final String subject;
  final String subtitle;
  final String badgeText;
  final String targetRoute;
  final double rating;

  IconData get icon {
    switch (type) {
      case ResourceType.note:
        return Icons.menu_book_rounded;
      case ResourceType.pyq:
        return Icons.quiz_rounded;
      case ResourceType.mcq:
        return Icons.fact_check_outlined;
      case ResourceType.dsa:
        return Icons.code_rounded;
    }
  }

  Color get color {
    switch (type) {
      case ResourceType.note:
        return const Color(0xFF2563EB); // Blue
      case ResourceType.pyq:
        return const Color(0xFFD97706); // Amber
      case ResourceType.mcq:
        return const Color(0xFF059669); // Emerald
      case ResourceType.dsa:
        return const Color(0xFF7C3AED); // Purple
    }
  }
}

class AiMessage {
  AiMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.resources = const [],
    this.highlightGapAction = false,
    this.gapTopicName,
  });

  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<AcademicResource> resources;
  final bool highlightGapAction;
  final String? gapTopicName;
}

class TopicPerformance {
  const TopicPerformance({
    required this.id,
    required this.name,
    required this.subject,
    required this.scorePercentage,
    required this.status,
    required this.totalQuestions,
    required this.correctQuestions,
    required this.aiDiagnosticInsight,
  });

  final String id;
  final String name;
  final String subject;
  final int scorePercentage;
  final TopicStatus status;
  final int totalQuestions;
  final int correctQuestions;
  final String aiDiagnosticInsight;

  Color get statusColor {
    switch (status) {
      case TopicStatus.strong:
        return const Color(0xFF16A34A); // Green
      case TopicStatus.proficient:
        return const Color(0xFF0D9488); // Teal
      case TopicStatus.moderateGap:
        return const Color(0xFFF59E0B); // Amber
      case TopicStatus.criticalGap:
        return const Color(0xFFDC2626); // Red
    }
  }

  String get statusLabel {
    switch (status) {
      case TopicStatus.strong:
        return 'Strong (Mastered)';
      case TopicStatus.proficient:
        return 'Proficient';
      case TopicStatus.moderateGap:
        return 'Moderate Gap';
      case TopicStatus.criticalGap:
        return 'Critical Learning Gap';
    }
  }
}

class StudyTask {
  StudyTask({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.tag,
    required this.resource,
    this.isDone = false,
  });

  final String id;
  final String title;
  final int durationMinutes;
  final String tag;
  final AcademicResource? resource;
  bool isDone;
}

class StudyPlanDay {
  StudyPlanDay({
    required this.dayNumber,
    required this.dayTitle,
    required this.focusTheme,
    required this.tasks,
  });

  final int dayNumber;
  final String dayTitle;
  final String focusTheme;
  final List<StudyTask> tasks;
}

class CareerMilestone {
  const CareerMilestone({
    required this.phase,
    required this.title,
    required this.description,
    required this.progressPercent,
    required this.skills,
    required this.isTargetForSemester,
  });

  final String phase;
  final String title;
  final String description;
  final int progressPercent;
  final List<String> skills;
  final bool isTargetForSemester;
}

/// Static mock repository for Academix AI prototype
class AiMockData {
  AiMockData._();

  // Student Profile
  static const String studentName = 'Rahul Sharma';
  static const String studentBranch = 'Computer Science & Engineering (CSE)';
  static const String studentSemester = '5th Semester';
  static const String studentGoal = 'Software Development Engineer (SDE-1)';
  static const String dailyStudyTime = '2 Hours / Day';

  // Common Academic Resources
  static const AcademicResource noteNormalization = AcademicResource(
    id: 'res_note_norm',
    title: 'Unit 3: Normalization & Functional Dependency',
    type: ResourceType.note,
    subject: 'DBMS (CS501)',
    subtitle: 'By Prof. Sharma (CSE Dept) • 28 Pages • Verified',
    badgeText: 'Curriculum Note',
    targetRoute: '/notes',
  );

  static const AcademicResource pyqNormalization = AcademicResource(
    id: 'res_pyq_aktu23',
    title: '2023 End-Sem Solved Paper: Q4(a) 3NF vs BCNF',
    type: ResourceType.pyq,
    subject: 'DBMS (CS501)',
    subtitle: '7-Mark Detailed Solution with Lossless Join Proof',
    badgeText: 'Past Exam Question',
    targetRoute: '/notes',
  );

  static const AcademicResource mcqNormalization = AcademicResource(
    id: 'res_mcq_norm',
    title: 'Normalization Master Quiz (15 MCQs)',
    type: ResourceType.mcq,
    subject: 'DBMS (CS501)',
    subtitle: 'Candidate Keys, 2NF/3NF & Multivalued Dependencies',
    badgeText: 'Practice Test',
    targetRoute: '/placement',
  );

  static const AcademicResource dsaGraphPrep = AcademicResource(
    id: 'res_dsa_trees',
    title: 'Binary Search Trees & Traversal Practice',
    type: ResourceType.dsa,
    subject: 'Placement DSA',
    subtitle: 'Top 10 Tier-1 Product Company Interview Problems',
    badgeText: 'Interview Prep',
    targetRoute: '/placement/dsa',
  );

  // Quick Prompt Chips
  static const List<String> quickPrompts = [
    'Explain normalization in DBMS in simple Hindi.',
    'Difference between 3NF and BCNF with exam example.',
    'What are ACID properties in Transactions?',
    'What are my critical learning gaps in DBMS?',
  ];

  // Pre-configured response for "Explain normalization in DBMS in simple Hindi"
  static final AiMessage hindiNormalizationResponse = AiMessage(
    id: 'resp_norm_hindi',
    isUser: false,
    timestamp: DateTime.now(),
    text: '''### 📚 DBMS में Normalization (सरल हिंदी में समझें)

**Normalization क्या है?**
सरल शब्दों में, **Normalization** एक ऐसी तकनीक (technique) है जिसमें हम एक बड़े और जटिल Database Table को छोटे, व्यवस्थित (well-structured) Tables में विभाजित करते हैं ताकि:
1. **Data Redundancy (डेटा का दोहराव)** समाप्त हो सके।
2. **Data Anomalies (Insertion, Updation, Deletion की गड़बड़ियां)** रुक सकें।
3. **Data Integrity (डेटा की सटीकता)** बनी रहे।

---
### 🔍 4 प्रमुख Normal Forms (Exam Revision):

1. **1NF (First Normal Form)**:
   - हर column में केवल **Atomic Values** (एकल मान) होने चाहिए।
   - एक ही cell में multiple values (जैसे दो mobile numbers) नहीं हो सकते।

2. **2NF (Second Normal Form)**:
   - Table पहले **1NF** में होना चाहिए।
   - कोई भी **Partial Dependency** नहीं होनी चाहिए (यानि non-prime attribute, candidate key के किसी टुकड़े पर निर्भर न हो, बल्कि पूरी Key पर निर्भर हो).

3. **3NF (Third Normal Form)**:
   - Table **2NF** में होना चाहिए।
   - कोई **Transitive Dependency** नहीं होनी चाहिए (यानि यदि A ➔ B और B ➔ C है, तो non-key C सीधे key A से अलग table में होना चाहिए).

4. **BCNF (Boyce-Codd Normal Form)**:
   - यह 3NF का कड़ा रूप है।
   - हर कार्यात्मक निर्भरता (Functional Dependency) **X ➔ Y** में **X एक Candidate/Super Key** होना अनिवार्य है।

---
💡 **University Exam Tip (CSE Sem 5)**:
End-Sem परीक्षा में 7-10 अंक का प्रश्न अक्सर **"Explain 1NF to BCNF with a Student-Department example"** आता है। Functional Dependency का तीर (Arrow notation) अवश्य बनाएं!''',
    resources: [noteNormalization, pyqNormalization, mcqNormalization],
    highlightGapAction: true,
    gapTopicName: 'Normalization (41% Gap Detected)',
  );

  // Response for 3NF vs BCNF
  static final AiMessage bcnfComparisonResponse = AiMessage(
    id: 'resp_bcnf_comp',
    isUser: false,
    timestamp: DateTime.now(),
    text: '''### ⚖️ 3NF vs BCNF: मुख्य अंतर (Quick Exam Table)

| विशेषता (Feature) | 3NF (Third Normal Form) | BCNF (Boyce-Codd Normal Form) |
| :--- | :--- | :--- |
| **नियम (Rule)** | X ➔ Y में X Super Key हो **या** Y Prime Attribute हो | X ➔ Y में केवल X का **Super Key** होना अनिवार्य है |
| **कठोरता (Strictness)** | कम सख्त (Less strict) | अधिक सख्त (Strict 3.5NF) |
| **Dependency Preservation**| हमेशा सुरक्षित (Guaranteed) | हमेशा सुरक्षित नहीं होती |
| **Redundancy** | कुछ मात्रा में रह सकती है | न्यूनतम (Minimal) |

---
📌 **Real Exam Example**:
मान लीजिए `Course_Teacher (Course, Teacher, Room)` में:
- `(Course, Teacher)` Candidate Key है।
- Functional Dependency: `Teacher ➔ Room` (जहाँ Teacher Candidate Key नहीं है).
यह Table **3NF में हो सकती है**, लेकिन **BCNF में नहीं** क्योंकि LHS (`Teacher`) Super Key नहीं है। इसे 2 tables में decompose करना होगा।''',
    resources: [noteNormalization, pyqNormalization],
    highlightGapAction: false,
  );

  // Initial Welcome Messages
  static List<AiMessage> getInitialMessages() {
    return [
      AiMessage(
        id: 'msg_welcome',
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        text:
            '👋 **नमस्ते $studentName! मैं हूँ आपका Academix AI Copilot.**\n\n'
            'मैं आपके पाठ्यक्रम (**B.Tech CSE - Semester 5**) और हाल के प्रदर्शन से जुड़ा हुआ हूँ। आप मुझसे अपने विषयों (DBMS, OS, CN, DSA) के किसी भी कठिन concept को अंग्रेजी या सरल हिंदी/Hinglish में पूछ सकते हैं।\n\n'
            'नीचे दिए गए किसी भी prompt पर tap करें या अपना प्रश्न लिखें 👇',
        resources: [noteNormalization, mcqNormalization],
      ),
    ];
  }

  // Topic Performance list for DBMS
  static const List<TopicPerformance> dbmsTopics = [
    TopicPerformance(
      id: 'dbms_sql',
      name: 'SQL Queries & Joins',
      subject: 'DBMS',
      scorePercentage: 85,
      status: TopicStatus.strong,
      totalQuestions: 40,
      correctQuestions: 34,
      aiDiagnosticInsight:
          'Excellent grasp of SELECT clauses, GROUP BY, and Nested Subqueries.',
    ),
    TopicPerformance(
      id: 'dbms_idx',
      name: 'Indexing & B-Trees',
      subject: 'DBMS',
      scorePercentage: 79,
      status: TopicStatus.proficient,
      totalQuestions: 28,
      correctQuestions: 22,
      aiDiagnosticInsight:
          'Consistent understanding of clustered vs secondary indices.',
    ),
    TopicPerformance(
      id: 'dbms_er',
      name: 'ER Modeling & Schema Design',
      subject: 'DBMS',
      scorePercentage: 72,
      status: TopicStatus.proficient,
      totalQuestions: 25,
      correctQuestions: 18,
      aiDiagnosticInsight:
          'Good structural logic; minor errors in cardinality constraints.',
    ),
    TopicPerformance(
      id: 'dbms_trans',
      name: 'Transactions & Concurrency Control',
      subject: 'DBMS',
      scorePercentage: 52,
      status: TopicStatus.moderateGap,
      totalQuestions: 30,
      correctQuestions: 16,
      aiDiagnosticInsight:
          'Confused between Strict 2PL and Rigorous 2PL deadlock scenarios.',
    ),
    TopicPerformance(
      id: 'dbms_norm',
      name: 'Normalization & Normal Forms',
      subject: 'DBMS',
      scorePercentage: 41,
      status: TopicStatus.criticalGap,
      totalQuestions: 35,
      correctQuestions: 14,
      aiDiagnosticInsight:
          'Critical gap in identifying Candidate Keys and calculating Lossless Joins during BCNF decomposition.',
    ),
  ];

  // Overall DBMS Readiness
  static const int overallReadinessScore = 68;

  // 7-Day Study Plan
  static List<StudyPlanDay> get7DayPlan() {
    return [
      StudyPlanDay(
        dayNumber: 1,
        dayTitle: 'Day 1 — Foundation Rehab',
        focusTheme: 'Functional Dependency & 1NF/2NF',
        tasks: [
          StudyTask(
            id: 'task_1_1',
            title: 'Read Academix Unit 3 Notes (Pages 1-12)',
            durationMinutes: 45,
            tag: 'Notes Reading',
            resource: noteNormalization,
            isDone: true,
          ),
          StudyTask(
            id: 'task_1_2',
            title: 'Solve 10 1NF/2NF Practice Problems',
            durationMinutes: 45,
            tag: 'Practice Drill',
            resource: mcqNormalization,
            isDone: true,
          ),
          StudyTask(
            id: 'task_1_3',
            title: 'LeetCode 1: Two Sum (Warmup DSA)',
            durationMinutes: 30,
            tag: 'DSA Daily',
            resource: dsaGraphPrep,
            isDone: false,
          ),
        ],
      ),
      StudyPlanDay(
        dayNumber: 2,
        dayTitle: 'Day 2 — 3NF & BCNF Breakdown',
        focusTheme: 'Transitive Dependency & Lossless Decomposition',
        tasks: [
          StudyTask(
            id: 'task_2_1',
            title: 'Study 3NF vs BCNF Proofs & Canonical Cover',
            durationMinutes: 50,
            tag: 'Core Theory',
            resource: noteNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_2_2',
            title: 'Solve 2023 End-Sem Solved Question Q4(a)',
            durationMinutes: 40,
            tag: 'PYQ Drill',
            resource: pyqNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_2_3',
            title: 'Binary Search Tree Search & Insert (Medium)',
            durationMinutes: 30,
            tag: 'Placement DSA',
            resource: dsaGraphPrep,
            isDone: false,
          ),
        ],
      ),
      StudyPlanDay(
        dayNumber: 3,
        dayTitle: 'Day 3 — Multi-valued Dependency & 4NF',
        focusTheme: 'Advanced Decomposition & Preservation',
        tasks: [
          StudyTask(
            id: 'task_3_1',
            title: 'Review 4NF & 5NF definitions with textbook notes',
            durationMinutes: 40,
            tag: 'Academix Note',
            resource: noteNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_3_2',
            title: 'Complete 15 Normalization Practice MCQs',
            durationMinutes: 50,
            tag: 'MCQ Assessment',
            resource: mcqNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_3_3',
            title: 'Quick 30-min revision on ER Model Mapping',
            durationMinutes: 30,
            tag: 'Revision',
            resource: null,
            isDone: false,
          ),
        ],
      ),
      StudyPlanDay(
        dayNumber: 4,
        dayTitle: 'Day 4 — Transaction Concurrency',
        focusTheme: 'ACID Properties & Serializability',
        tasks: [
          StudyTask(
            id: 'task_4_1',
            title: 'Learn Conflict Serializability & Precedence Graphs',
            durationMinutes: 50,
            tag: 'Subject Core',
            resource: null,
            isDone: false,
          ),
          StudyTask(
            id: 'task_4_2',
            title: 'Solve Past 3 Years Solved Concurrency PYQs',
            durationMinutes: 40,
            tag: 'PYQ Drill',
            resource: pyqNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_4_3',
            title: 'DSA: Balanced Binary Trees (AVL Concept)',
            durationMinutes: 30,
            tag: 'Interview Prep',
            resource: dsaGraphPrep,
            isDone: false,
          ),
        ],
      ),
      StudyPlanDay(
        dayNumber: 5,
        dayTitle: 'Day 5 — Full DBMS Mock Quiz',
        focusTheme: 'Simulated Mid-Sem Assessment',
        tasks: [
          StudyTask(
            id: 'task_5_1',
            title: 'Take 45-Minute Timed DBMS Mock Test (30 Questions)',
            durationMinutes: 45,
            tag: 'Adaptive Quiz',
            resource: mcqNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_5_2',
            title: 'Review Incorrect Questions with AI Explanations',
            durationMinutes: 45,
            tag: 'Gap Closing',
            resource: null,
            isDone: false,
          ),
          StudyTask(
            id: 'task_5_3',
            title: 'DSA: Tree BFS (Level Order Traversal)',
            durationMinutes: 30,
            tag: 'Placement DSA',
            resource: dsaGraphPrep,
            isDone: false,
          ),
        ],
      ),
      StudyPlanDay(
        dayNumber: 6,
        dayTitle: 'Day 6 — Software Engineer Project Focus',
        focusTheme: 'Database Design for Real Application',
        tasks: [
          StudyTask(
            id: 'task_6_1',
            title: 'Design Normalized PostgreSQL Schema for E-Commerce App',
            durationMinutes: 60,
            tag: 'Portfolio Project',
            resource: null,
            isDone: false,
          ),
          StudyTask(
            id: 'task_6_2',
            title: 'Index Optimization & Execution Plan Analysis',
            durationMinutes: 60,
            tag: 'Industry Skill',
            resource: null,
            isDone: false,
          ),
        ],
      ),
      StudyPlanDay(
        dayNumber: 7,
        dayTitle: 'Day 7 — AI Reassessment & Dynamic Adaptation',
        focusTheme: 'Adaptive Plan Recalculation',
        tasks: [
          StudyTask(
            id: 'task_7_1',
            title: 'Official Academix AI Adaptive Reassessment (20 Min)',
            durationMinutes: 20,
            tag: 'Reassessment',
            resource: mcqNormalization,
            isDone: false,
          ),
          StudyTask(
            id: 'task_7_2',
            title: 'Generate Week 2 Adapted Roadmap based on updated scores',
            durationMinutes: 40,
            tag: 'Roadmap Refresh',
            resource: null,
            isDone: false,
          ),
        ],
      ),
    ];
  }

  // Career Roadmap Milestones for SDE-1
  static const List<CareerMilestone> careerRoadmap = [
    CareerMilestone(
      phase: 'Phase 1',
      title: 'Academic Core Mastery',
      description:
          'Ensure strong conceptual foundation in DBMS, Operating Systems, Computer Networks, and Object-Oriented Programming.',
      progressPercent: 78,
      skills: ['DBMS', 'Operating Systems', 'Computer Networks', 'OOPs'],
      isTargetForSemester: true,
    ),
    CareerMilestone(
      phase: 'Phase 2',
      title: 'Data Structures & Algorithms (DSA)',
      description:
          'Master Arrays, Trees, Graphs, Dynamic Programming and solve 200+ standard interview problems for campus drives.',
      progressPercent: 62,
      skills: ['Arrays & HashMaps', 'Trees & Graphs', 'DP', 'Greedy'],
      isTargetForSemester: true,
    ),
    CareerMilestone(
      phase: 'Phase 3',
      title: 'Full-Stack / Backend Engineering',
      description:
          'Build and deploy 2 production-ready applications with REST APIs, authentication, and normalized databases.',
      progressPercent: 40,
      skills: ['Flutter / React', 'Node.js / Django', 'PostgreSQL', 'Docker'],
      isTargetForSemester: false,
    ),
    CareerMilestone(
      phase: 'Phase 4',
      title: 'Placement Drives & Mock Interviews',
      description:
          'Resume building using Academix ATS templates, mock peer interviews, and alumni referral applications.',
      progressPercent: 20,
      skills: [
        'ATS Resume',
        'System Design Basics',
        'HR & Behavioral',
        'Alumni Referrals',
      ],
      isTargetForSemester: false,
    ),
  ];
}

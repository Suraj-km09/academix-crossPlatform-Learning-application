import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final bool enabled;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
      highlightColor: highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!),
      enabled: enabled,
      child: child,
    );
  }

  static Widget rectangle({
    double? width,
    double height = 20,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }

  static Widget circle({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class NoteCardSkeleton extends StatelessWidget {
  const NoteCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SkeletonLoader.rectangle(height: 20, width: double.infinity),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader.rectangle(height: 16, width: 200),
            const SizedBox(height: 8),
            SkeletonLoader.rectangle(height: 14, width: 150),
            const SizedBox(height: 12),
            Row(
              children: [
                SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader.rectangle(height: 12, width: 100),
                SkeletonLoader.rectangle(height: 12, width: 60),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CurriculumCardSkeleton extends StatelessWidget {
  const CurriculumCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SkeletonLoader.rectangle(height: 20, width: double.infinity),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader.rectangle(height: 14, width: 180),
            const SizedBox(height: 12),
            SkeletonLoader.rectangle(height: 14, width: double.infinity),
            const SizedBox(height: 6),
            SkeletonLoader.rectangle(height: 14, width: double.infinity),
            const SizedBox(height: 12),
            Row(
              children: [
                SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
              ],
            ),
            const SizedBox(height: 16),
            SkeletonLoader.rectangle(height: 12, width: 120),
          ],
        ),
      ),
    );
  }
}

class SubjectCardSkeleton extends StatelessWidget {
  const SubjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SkeletonLoader(
              child: Icon(Icons.book_outlined, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            SkeletonLoader.rectangle(height: 14, width: 80),
          ],
        ),
      ),
    );
  }
}

class QuestionTileSkeleton extends StatelessWidget {
  const QuestionTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SkeletonLoader.rectangle(height: 18, width: double.infinity),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SkeletonLoader.rectangle(height: 24, width: 60, borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              SkeletonLoader.rectangle(height: 24, width: 60, borderRadius: BorderRadius.circular(12)),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class TopicTileSkeleton extends StatelessWidget {
  const TopicTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader.circle(size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader.rectangle(height: 16, width: 150),
                  const SizedBox(height: 8),
                  SkeletonLoader.rectangle(height: 12, width: 100),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class LockerFileSkeleton extends StatelessWidget {
  const LockerFileSkeleton({super.key, this.gridMode = false});

  final bool gridMode;

  @override
  Widget build(BuildContext context) {
    if (gridMode) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SkeletonLoader(
                  child: Icon(Icons.picture_as_pdf_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              SkeletonLoader.rectangle(height: 14, width: double.infinity),
              const SizedBox(height: 6),
              SkeletonLoader.rectangle(height: 12, width: 60),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader.rectangle(height: 10, width: 50),
                  SkeletonLoader.circle(size: 20),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const SkeletonLoader(
          child: Icon(Icons.picture_as_pdf_rounded, size: 32, color: Colors.white),
        ),
        title: SkeletonLoader.rectangle(height: 16, width: 180),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SkeletonLoader.rectangle(height: 12, width: 100),
        ),
        trailing: SkeletonLoader.circle(size: 24),
      ),
    );
  }
}

class BulletinCardSkeleton extends StatelessWidget {
  const BulletinCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
                const Spacer(),
                SkeletonLoader.rectangle(height: 12, width: 60),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader.rectangle(height: 20, width: double.infinity),
            const SizedBox(height: 8),
            SkeletonLoader.rectangle(height: 14, width: double.infinity),
            const SizedBox(height: 6),
            SkeletonLoader.rectangle(height: 14, width: 200),
            const SizedBox(height: 16),
            Row(
              children: [
                SkeletonLoader.circle(size: 24),
                const SizedBox(width: 8),
                SkeletonLoader.rectangle(height: 12, width: 100),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader.circle(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader.rectangle(height: 16, width: double.infinity),
                  const SizedBox(height: 8),
                  SkeletonLoader.rectangle(height: 14, width: 200),
                  const SizedBox(height: 8),
                  SkeletonLoader.rectangle(height: 10, width: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlacementMaterialSkeleton extends StatelessWidget {
  const PlacementMaterialSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Expanded(
                child: SkeletonLoader.rectangle(height: 16, width: double.infinity),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class AlumniCardSkeleton extends StatelessWidget {
  const AlumniCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader.circle(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader.rectangle(height: 18, width: 150),
                  const SizedBox(height: 8),
                  SkeletonLoader.rectangle(height: 14, width: double.infinity),
                  const SizedBox(height: 6),
                  SkeletonLoader.rectangle(height: 14, width: 120),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
                      const SizedBox(width: 8),
                      SkeletonLoader.rectangle(height: 24, width: 60, borderRadius: BorderRadius.circular(12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatTileSkeleton extends StatelessWidget {
  const ChatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: SkeletonLoader.circle(size: 44),
        title: SkeletonLoader.rectangle(height: 16, width: 140),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SkeletonLoader.rectangle(height: 12, width: double.infinity),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonLoader.rectangle(height: 10, width: 40),
            const SizedBox(height: 8),
            SkeletonLoader.circle(size: 16),
          ],
        ),
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.withOpacity(0.1),
          ),
          child: Row(
            children: [
              SkeletonLoader.circle(size: 56),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader.rectangle(height: 20, width: 150),
                  const SizedBox(height: 8),
                  SkeletonLoader.rectangle(height: 14, width: 200),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(3, (index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.rectangle(height: 18, width: 120),
                const SizedBox(height: 16),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SkeletonLoader.rectangle(height: 14, width: 80),
                      const SizedBox(width: 16),
                      SkeletonLoader.rectangle(height: 14, width: 150),
                    ],
                  ),
                )),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class NoteDetailSkeleton extends StatelessWidget {
  const NoteDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.grey.withOpacity(0.1),
            child: const Center(
              child: SkeletonLoader(
                child: Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.white),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader.rectangle(height: 22, width: double.infinity),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(4, (index) => 
                  SkeletonLoader.rectangle(height: 24, width: 100, borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SkeletonLoader.rectangle(height: 14, width: 250),
              const SizedBox(height: 8),
              SkeletonLoader.rectangle(height: 14, width: 200),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SkeletonLoader.rectangle(height: 48, borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(width: 12),
                  SkeletonLoader.rectangle(height: 48, width: 48, borderRadius: BorderRadius.circular(12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReferralCardSkeleton extends StatelessWidget {
  const ReferralCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SkeletonLoader.rectangle(height: 18, width: 200),
                ),
                const SizedBox(width: 8),
                SkeletonLoader.rectangle(height: 24, width: 80, borderRadius: BorderRadius.circular(12)),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader.rectangle(height: 14, width: 150),
            const SizedBox(height: 6),
            SkeletonLoader.rectangle(height: 14, width: 150),
            const SizedBox(height: 10),
            SkeletonLoader.rectangle(height: 12, width: 120),
          ],
        ),
      ),
    );
  }
}

class AlumniProfileSkeleton extends StatelessWidget {
  const AlumniProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AlumniCardSkeleton(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.rectangle(height: 18, width: 100),
                const SizedBox(height: 12),
                SkeletonLoader.rectangle(height: 14, width: double.infinity),
                const SizedBox(height: 6),
                SkeletonLoader.rectangle(height: 14, width: 200),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.rectangle(height: 18, width: 80),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(5, (index) => 
                    SkeletonLoader.rectangle(height: 28, width: 70, borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonLoader.rectangle(height: 48, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(child: SkeletonLoader.rectangle(height: 48, borderRadius: BorderRadius.circular(12))),
          ],
        ),
      ],
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SkeletonLoader.rectangle(height: 80, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 16),
        SkeletonLoader.rectangle(height: 120, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.90,
          ),
          itemBuilder: (context, index) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader.circle(size: 44),
                  const Spacer(),
                  SkeletonLoader.rectangle(height: 14, width: 100),
                  const SizedBox(height: 6),
                  SkeletonLoader.rectangle(height: 10, width: double.infinity),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AlumniDashboardSkeleton extends StatelessWidget {
  const AlumniDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(3, (index) => Expanded(
                child: Column(
                  children: [
                    SkeletonLoader.rectangle(height: 20, width: 40),
                    const SizedBox(height: 8),
                    SkeletonLoader.rectangle(height: 12, width: 60),
                  ],
                ),
              )),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SkeletonLoader.rectangle(height: 18, width: 180),
        const SizedBox(height: 12),
        ...List.generate(2, (index) => const ReferralCardSkeleton()),
        const SizedBox(height: 24),
        SkeletonLoader.rectangle(height: 18, width: 180),
        const SizedBox(height: 12),
        ...List.generate(2, (index) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.rectangle(height: 16, width: double.infinity),
                const SizedBox(height: 12),
                SkeletonLoader.rectangle(height: 36, width: 100, borderRadius: BorderRadius.circular(8)),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class McqTileSkeleton extends StatelessWidget {
  const McqTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SkeletonLoader.circle(size: 40),
        title: SkeletonLoader.rectangle(height: 16, width: 180),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SkeletonLoader.rectangle(height: 12, width: 120),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

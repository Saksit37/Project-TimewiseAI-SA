import 'package:flutter/material.dart';

import '../models/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 6.3.2 หน้าหลัก (Dashboard)
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final free = s.freeMinutes;
        final need = s.requiredMinutes;
        final pending = s.pending;
        final urgent = pending.where((a) => !a.recurring && daysBetween(s.now, a.deadline) <= 1).toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        final done = s.activities.where((a) => a.status == ActivityStatus.done).length;
        final total = s.activities.length;
        final logged = s.activities.where((a) => a.actualMinutes != null && a.status == ActivityStatus.done).toList();
        final planSum = logged.fold<int>(0, (x, a) => x + a.minutes);
        final actSum = logged.fold<int>(0, (x, a) => x + (a.actualMinutes ?? 0));
        final overrun = planSum == 0 ? 0 : ((actSum - planSum) / planSum * 100).round();

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Row(
                  children: [
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pushNamed(context, Routes.profile),
                      child: UserAvatar(s.userName),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateLong(s.now), style: AppText.muted),
                          Text('สวัสดี คุณ${s.userName}', style: AppText.title),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'การแจ้งเตือน',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pushNamed(context, Routes.notifications),
                      icon: Badge(
                        isLabelVisible: s.unreadCount > 0,
                        label: Text('${s.unreadCount}'),
                        backgroundColor: AppColors.high,
                        child: const Icon(Icons.notifications_none),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _HeroCard(free: free, need: need, pendingCount: pending.length),
                if (urgent.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  InfoBanner(
                    icon: Icons.flag_outlined,
                    tone: Tone.high,
                    text: 'ใกล้ถึง Deadline: “${urgent.first.name}” ${relativeDeadline(urgent.first.deadline, s.now)} ${timeOf(urgent.first.deadline)} น.',
                  ),
                ],
                const SizedBox(height: 20),
                SectionTitle(
                  s.planCode == null ? 'แผนวันนี้' : 'แผนวันนี้ (ทางเลือก ${s.planCode})',
                  trailing: LinkText('ดูตาราง', onTap: () => s.homeTab.value = 2),
                ),
                const SizedBox(height: 10),
                if (s.plan.isEmpty)
                  EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'ยังไม่มีแผนสำหรับวันนี้',
                    message: 'ให้ AI ช่วยสร้างทางเลือกจากกิจกรรม เวลาว่าง และเป้าหมายของคุณ',
                    action: AppButton('สร้างแผนด้วย AI', icon: Icons.auto_awesome, onPressed: () => Navigator.pushNamed(context, Routes.askAi)),
                  )
                else
                  for (final b in s.plan) _PlanRow(block: b),
                const SizedBox(height: 20),
                const SectionTitle('ความคืบหน้า'),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(child: Text('กิจกรรมที่เสร็จแล้ว', style: AppText.muted)),
                        Text('$done / $total รายการ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      ProgressBar(total == 0 ? 0.0 : done / total, height: 10),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: Text(
                            overrun > 0 ? 'ใช้เวลาจริงมากกว่าที่คาด $overrun%' : 'ใช้เวลาได้ตามที่ประเมินไว้',
                            style: AppText.small,
                          ),
                        ),
                        LinkText('ดูรายงาน', onTap: () => s.homeTab.value = 3),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.free, required this.need, required this.pendingCount});
  final int free;
  final int need;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFE6F1EF))),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ภาพรวมวันนี้', style: TextStyle(fontSize: 13, color: Color(0xFFD6E9E6))),
                    Text(
                      need > free ? 'มีกิจกรรมมากกว่าเวลาที่ว่าง' : 'เวลาว่างเพียงพอสำหรับกิจกรรม',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.auto_awesome, color: Colors.white),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            stat(duration(free), 'เวลาว่าง'),
            const SizedBox(width: 8),
            stat(duration(need), 'ต้องใช้'),
            const SizedBox(width: 8),
            stat('$pendingCount', 'งานรอทำ'),
          ]),
          const SizedBox(height: 14),
          AppButton(
            'ให้ AI ช่วยจัดลำดับและสร้างทางเลือก',
            variant: ButtonVariant.white,
            icon: Icons.auto_awesome,
            height: 46,
            onPressed: () => Navigator.pushNamed(context, Routes.askAi),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.block});
  final PlanBlock block;

  @override
  Widget build(BuildContext context) {
    final a = appState.byId(block.activityId);
    if (a == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hm(block.start), style: AppText.label),
                Text(hm(block.end), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
              ],
            ),
          ),
          Expanded(
            child: AppCard(
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => Navigator.pushNamed(context, Routes.track, arguments: a.id),
              child: Row(
                children: [
                  Container(width: 4, height: 40, decoration: BoxDecoration(color: toneFg(priorityTone(a.priority)), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: AppText.bodyStrong),
                        Text('${a.type.label} · ${duration(block.minutes)}', style: AppText.small),
                      ],
                    ),
                  ),
                  Pill(a.status.label, tone: statusTone(a.status)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

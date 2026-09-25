import 'package:flutter/material.dart';

import '../routes.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'activities_screens.dart';
import 'dashboard_screen.dart';
import 'report_screens.dart';
import 'schedule_screens.dart';

/// โครงหน้าหลักพร้อมเมนูด้านล่าง (หน้าหลัก / กิจกรรม / ถาม AI / ตาราง / รายงาน)
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = <Widget>[DashboardTab(), ActivitiesTab(), ScheduleTab(), ReportTab()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appState.homeTab,
      builder: (context, tab, _) {
        return Scaffold(
          body: IndexedStack(index: tab, children: _tabs),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, Routes.askAi),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            tooltip: 'ขอคำแนะนำจาก AI',
            child: const Icon(Icons.auto_awesome),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            color: AppColors.surface,
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: const CircularNotchedRectangle(),
            notchMargin: 6,
            child: Row(
              children: [
                _navItem(0, Icons.home_outlined, 'หน้าหลัก', tab),
                _navItem(1, Icons.checklist_rounded, 'กิจกรรม', tab),
                const SizedBox(width: 72),
                _navItem(2, Icons.calendar_month_outlined, 'ตาราง', tab),
                _navItem(3, Icons.bar_chart_rounded, 'รายงาน', tab),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(int index, IconData icon, String label, int current) {
    final selected = index == current;
    final color = selected ? AppColors.accent : AppColors.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => appState.homeTab.value = index,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

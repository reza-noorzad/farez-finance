import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../categories/categories_page.dart';
import '../debts/debts_page.dart';
import '../recurring/recurring_page.dart';
import '../reports/product_analytics_page.dart';
import '../reports/reports_page.dart';
import '../settings/app_settings_mock_data.dart';
import '../settings/settings_page.dart';
import '../travel/travel_plans_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppSettingsMockData.settingsNotifier,
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppStrings.more),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _MoreMenuItem(
                icon: Icons.repeat,
                title: 'Wiederkehrend',
                subtitle: 'Monatliche Einnahmen und Ausgaben übernehmen',
                page: RecurringPage(),
              ),
              _MoreMenuItem(
                icon: Icons.flight_takeoff,
                title: AppStrings.travelPlans,
                subtitle: AppStrings.travelPlansSubtitle,
                page: const TravelPlansPage(),
              ),
              _MoreMenuItem(
                icon: Icons.inventory_2_outlined,
                title: AppStrings.productAnalytics,
                subtitle: AppStrings.productAnalyticsSubtitle,
                page: const ProductAnalyticsPage(),
              ),
              _MoreMenuItem(
                icon: Icons.account_balance_wallet_outlined,
                title: AppStrings.debtsReceivables,
                subtitle: AppStrings.debtsReceivablesSubtitle,
                page: const DebtsPage(),
              ),
              _MoreMenuItem(
                icon: Icons.bar_chart_outlined,
                title: AppStrings.reports,
                subtitle: AppStrings.reportsSubtitle,
                page: const ReportsPage(),
              ),
              _MoreMenuItem(
                icon: Icons.category_outlined,
                title: AppStrings.categories,
                subtitle: AppStrings.categoriesSubtitle,
                page: const CategoriesPage(),
              ),
              _MoreMenuItem(
                icon: Icons.settings_outlined,
                title: AppStrings.settings,
                subtitle: AppStrings.settingsSubtitle,
                page: const SettingsPage(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? page;

  const _MoreMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: page == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => page!,
                  ),
                );
              },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../features/budgets/budgets_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/expenses/expenses_page.dart';
import '../features/income/income_page.dart';
import '../features/more/more_page.dart';
import '../features/savings/accounts_page.dart';
import '../features/settings/app_settings_mock_data.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    IncomePage(),
    ExpensesPage(),
    AccountsPage(),
    BudgetsPage(),
    MorePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppSettingsMockData.settingsNotifier,
      builder: (context, settings, child) {
        return Scaffold(
          body: _pages[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: AppStrings.dashboard,
              ),
              NavigationDestination(
                icon: const Icon(Icons.arrow_downward_outlined),
                selectedIcon: const Icon(Icons.arrow_downward),
                label: AppStrings.income,
              ),
              NavigationDestination(
                icon: const Icon(Icons.arrow_upward_outlined),
                selectedIcon: const Icon(Icons.arrow_upward),
                label: AppStrings.expenses,
              ),
              NavigationDestination(
                icon: const Icon(Icons.savings_outlined),
                selectedIcon: const Icon(Icons.savings),
                label: AppStrings.savings,
              ),
              const NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart),
                label: 'Budgets',
              ),
              NavigationDestination(
                icon: const Icon(Icons.more_horiz_outlined),
                selectedIcon: const Icon(Icons.more_horiz),
                label: AppStrings.more,
              ),
            ],
          ),
        );
      },
    );
  }
}

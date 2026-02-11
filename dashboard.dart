import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'danger_map.dart';
import 'reports.dart';
import 'userpage.dart'; // import the new UserPage

// --- Controllers ---
class DashboardController extends GetxController {
  var selectedIndex = 0.obs;

  void changeTab(int index) {
    selectedIndex.value = index;
    Get.back(); // closes the drawer after selection
  }
}

// --- Pages for each tab ---
class DangerMapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DangerMap();
  }
}

class CrookReportsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ReportsPage();
  }
}

// Replace the recursive class with our UserPage
class UserAccountPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const UserPage();
  }
}

// --- Dashboard Screen ---
class DashboardScreen extends StatelessWidget {
  final DashboardController controller = Get.put(DashboardController());

  final List<Widget> pages = [
    DangerMapPage(),
    CrookReportsPage(),
    UserAccountPage(),
  ];

  final List<String> titles = ["Danger Map", "Crook Reports", "User Account"];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        appBar: AppBar(
          title: Text(titles[controller.selectedIndex.value]),
          backgroundColor: Colors.redAccent,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.redAccent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CrookWatch",
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Stay Safe. Stay Connected.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.map),
                title: Text("Danger Map"),
                onTap: () => controller.changeTab(0),
              ),
              ListTile(
                leading: Icon(Icons.report),
                title: Text("Crook Reports"),
                onTap: () => controller.changeTab(1),
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text("User Account"),
                onTap: () => controller.changeTab(2),
              ),
            ],
          ),
        ),
        body: pages[controller.selectedIndex.value],
      );
    });
  }
}

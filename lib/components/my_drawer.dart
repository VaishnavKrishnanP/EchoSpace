import 'package:echospace/components/icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' show Provider;
import '../pages/settings_page.dart';
import 'package:echospace/services/auth/auth_service.dart';

import '../themes/theme_provider.dart';


class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void logout() {
    final auth = AuthService();
        auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              DrawerHeader(
              child: Center(
                child: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: SvgIcon(
                size: 150,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
            ),
              ),
          ),

          Padding(
            padding: const EdgeInsets.only(left:25.0),
            child: ListTile(
              title: const Text("H O M E"),
              leading: const Icon(Icons.home),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left:25.0),
            child: ListTile(
              title: const Text("S E T T I N G S"),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context)=>SettingsPage(),
                )
                );
              },
            ),
          )
            ],
          )

          ,Padding(
            padding: const EdgeInsets.only(left:25.0,bottom: 25.0),
            child: ListTile(
              title: const Text("L O G O U T"),
              leading: const Icon(Icons.logout),
              onTap: logout,
            ),
          )
          
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/sync_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _vaultPathController = TextEditingController();
  final TextEditingController _driveFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(syncPreferencesProvider);
    _vaultPathController.text = prefs.localVaultPath ?? '';
    _driveFolderController.text = prefs.driveFolderName;
  }

  @override
  void dispose() {
    _vaultPathController.dispose();
    _driveFolderController.dispose();
    super.dispose();
  }

  Future<void> _pickVaultDirectory() async {
    String? result;
    try {
      result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select your Obsidian Vault Folder',
      );
    } catch (e) {
      print('File picker error: $e');
    }

    // Fallback to manual text entry dialog if picker was cancelled or errored
    if (result == null && mounted) {
      final controller = TextEditingController(text: _vaultPathController.text);
      result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Enter Vault Path Manually',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white70),
            decoration: InputDecoration(
              hintText: '/storage/emulated/0/Vault',
              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text('Save', style: GoogleFonts.outfit(color: const Color(0xFF6CBE83), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (result != null && result.isNotEmpty) {
      setState(() => _vaultPathController.text = result!);
      await ref.read(syncPreferencesProvider).setLocalVaultPath(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault path saved: $result'),
            backgroundColor: const Color(0xFF6CBE83),
          ),
        );
      }
    }
  }

  Future<void> _saveDriveFolderName(String value) async {
    if (value.trim().isNotEmpty) {
      await ref.read(syncPreferencesProvider).setDriveFolderName(value.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(syncPreferencesProvider);
    final isMockMode = ref.watch(mockModeProvider);
    final authState = ref.watch(authProvider);

    final accentColor = const Color(0xFF6CBE83); // Obsidian Mint Green
    final darkBackground = const Color(0xFF121212); // Deep Obsidian
    final surfaceColor = const Color(0xFF1E1E1E); // Slate Card
    final surfaceBorder = Colors.white.withOpacity(0.06);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Mode Selector
              _buildSectionHeader('CONNECTION MODE'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surfaceBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeSegment(
                        'Local Sandbox',
                        'Mock Mode',
                        isMockMode,
                        () async {
                          ref.read(mockModeProvider.notifier).state = true;
                          await prefs.setUseMockMode(true);
                          // Re-init auth
                          ref.invalidate(authProvider);
                        },
                        accentColor,
                      ),
                    ),
                    Expanded(
                      child: _buildModeSegment(
                        'Google Drive',
                        'Real REST API',
                        !isMockMode,
                        () async {
                          ref.read(mockModeProvider.notifier).state = false;
                          await prefs.setUseMockMode(false);
                          ref.invalidate(authProvider);
                        },
                        accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  isMockMode
                      ? 'Local Sandbox Mode is fully active. All sync operations write to a simulated local folder. No internet or Google API credentials required!'
                      : 'Google Drive Mode is active. Uses standard REST APIs to sync files directly to your live Google cloud account.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // 2. Authentication Card
              _buildSectionHeader('ACCOUNT SECURITY'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: surfaceBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: authState.isAuthenticated ? accentColor : Colors.white38,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.isAuthenticated
                                ? (isMockMode ? 'Mock User Account' : 'Google Drive Account')
                                : 'Not Authenticated',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authState.isAuthenticated
                                ? (authState.email ?? 'No email associated')
                                : 'Authenticate to start syncing to the cloud.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sign In/Out button
                    authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white38),
                            ),
                          )
                        : TextButton(
                            onPressed: () async {
                              if (authState.isAuthenticated) {
                                await ref.read(authProvider.notifier).signOut();
                              } else {
                                try {
                                  final ok = await ref.read(authProvider.notifier).signIn();
                                  if (ok && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Successfully Authenticated!'),
                                        backgroundColor: accentColor,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: authState.isAuthenticated ? Colors.redAccent : accentColor,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: Text(
                              authState.isAuthenticated ? 'LOGOUT' : 'LOGIN',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 3. Folder Sync Configurations
              _buildSectionHeader('SYNC PREFERENCES'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: surfaceBorder, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. Local Vault Path field
                    Text(
                      'LOCAL OBSIDIAN VAULT PATH',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _vaultPathController,
                            onChanged: (val) => prefs.setLocalVaultPath(val.trim().isEmpty ? null : val.trim()),
                            style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white70),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              hintText: '/Documents/Obsidian_Vault',
                              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: surfaceBorder, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _pickVaultDirectory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.04),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: surfaceBorder),
                            ),
                          ),
                          child: const Icon(Icons.folder_open, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // B. Google Drive Folder Name field
                    Text(
                      'GOOGLE DRIVE TARGET FOLDER',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _driveFolderController,
                      onChanged: _saveDriveFolderName,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        hintText: 'Obsidan',
                        hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: surfaceBorder, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 4. Sync History Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('SYNC HISTORY LOG'),
                  if (prefs.syncHistory.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        await prefs.clearSyncHistory();
                        setState(() {});
                      },
                      child: Text(
                        'CLEAR HISTORY',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: surfaceBorder, width: 1.5),
                ),
                child: prefs.syncHistory.isEmpty
                    ? Center(
                        child: Text(
                          'No sync activity recorded yet.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white24,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: prefs.syncHistory.length,
                        itemBuilder: (context, index) {
                          final log = prefs.syncHistory[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  log.contains('Failed') ? Icons.cancel : Icons.check_circle,
                                  color: log.contains('Failed') ? Colors.redAccent : accentColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    log,
                                    style: GoogleFonts.firaCode(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildModeSegment(
    String title,
    String subtitle,
    bool isActive,
    VoidCallback onTap,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? accentColor.withOpacity(0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.white38,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isActive ? accentColor : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

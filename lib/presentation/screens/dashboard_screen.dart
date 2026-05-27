import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/sync_providers.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(activeSyncProvider);
    final authState = ref.watch(authProvider);
    final isMockMode = ref.watch(mockModeProvider);
    final prefs = ref.watch(syncPreferencesProvider);

    // Scroll logs automatically when a new log appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (syncState.liveLogs.isNotEmpty) {
        _scrollToBottom();
      }
    });

    final accentColor = const Color(0xFF6CBE83); // Obsidian Mint Green
    final darkBackground = const Color(0xFF121212); // Deep Obsidian
    final surfaceColor = const Color(0xFF1E1E1E); // Slate Card
    final surfaceBorder = Colors.white.withOpacity(0.06);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.sync, color: accentColor, size: 22)
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: const Duration(seconds: 12)),
            const SizedBox(width: 10),
            Text(
              'SynGo',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Connection status badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isMockMode 
                  ? Colors.blue.withOpacity(0.12)
                  : (authState.isAuthenticated ? accentColor.withOpacity(0.12) : Colors.red.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isMockMode 
                    ? Colors.blue.withOpacity(0.3)
                    : (authState.isAuthenticated ? accentColor.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isMockMode 
                        ? Colors.blueAccent 
                        : (authState.isAuthenticated ? accentColor : Colors.redAccent),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isMockMode 
                      ? 'Local Mock Mode' 
                      : (authState.isAuthenticated ? 'Cloud Live' : 'Disconnected'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Interactive Pulse Ring Screen (Pulsing ring showing status)
              Expanded(
                flex: 4,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulse ring outer shadows
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: syncState.isSyncing 
                                      ? accentColor.withOpacity(0.15) 
                                      : accentColor.withOpacity(0.04),
                                  blurRadius: 40,
                                  spreadRadius: syncState.isSyncing ? 15 : 5,
                                ),
                              ],
                            ),
                          ),
                          // Breathing ring
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: syncState.isSyncing 
                                    ? accentColor.withOpacity(0.8) 
                                    : accentColor.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                          )
                              .animate(
                                target: syncState.isSyncing ? 1 : 0,
                                onPlay: (controller) => controller.repeat(reverse: true),
                              )
                              .scaleXY(
                                begin: 0.95,
                                end: 1.05,
                                duration: const Duration(seconds: 2),
                                curve: Curves.easeInOut,
                              ),
                          // Core status disk
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: surfaceBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  syncState.isSyncing 
                                      ? Icons.sync 
                                      : (syncState.statusMessage.contains('Failed') ? Icons.warning : Icons.check_circle_outline),
                                  color: syncState.statusMessage.contains('Failed') ? Colors.redAccent : accentColor,
                                  size: 32,
                                )
                                    .animate(
                                      target: syncState.isSyncing ? 1 : 0,
                                      onPlay: (controller) => controller.repeat(),
                                    )
                                    .rotate(duration: const Duration(seconds: 3)),
                                const SizedBox(height: 10),
                                Text(
                                  syncState.isSyncing 
                                      ? 'SYNCING...' 
                                      : (syncState.statusMessage.contains('Success') ? 'SYNCED' : 'READY'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Text(
                        syncState.statusMessage,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
                      if (prefs.lastSyncTime != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Last sync: ${prefs.lastSyncTime!.substring(11, 16)}  (${prefs.lastSyncTime!.substring(0, 10)})',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 2. Statistics Row
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'FILES SCANNED',
                        '${syncState.lastStats?.filesScanned ?? 0}',
                        Icons.description,
                        accentColor,
                        surfaceColor,
                        surfaceBorder,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        'CHANGED & SYNCED',
                        '${(syncState.lastStats?.filesUploaded ?? 0) + (syncState.lastStats?.filesDownloaded ?? 0)}',
                        Icons.cloud_upload,
                        accentColor,
                        surfaceColor,
                        surfaceBorder,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Execution Control Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildSyncActionButton(
                      'Sync Up',
                      'Upload newer local files',
                      Icons.upload,
                      syncState.isSyncing ? null : () => ref.read(activeSyncProvider.notifier).performSyncUp(),
                      accentColor,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildSyncActionButton(
                      'Sync Down',
                      'Download newer cloud files',
                      Icons.download,
                      syncState.isSyncing ? null : () => ref.read(activeSyncProvider.notifier).performSyncDown(),
                      accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Live Console Console Panel
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: surfaceBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header of console
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: surfaceColor.withOpacity(0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(
                            bottom: BorderSide(color: surfaceBorder),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.amberAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sync Engine Terminal',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            if (syncState.liveLogs.isNotEmpty)
                              GestureDetector(
                                onTap: () => ref.read(activeSyncProvider.notifier).clearLogs(),
                                child: Text(
                                  'CLEAR',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Console content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: syncState.liveLogs.isEmpty
                              ? Center(
                                  child: Text(
                                    'No logs to display.\nTap Sync Up or Sync Down to start.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.firaCode(
                                      fontSize: 12,
                                      color: Colors.white24,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _logScrollController,
                                  itemCount: syncState.liveLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = syncState.liveLogs[index];
                                    Color logColor = Colors.white70;
                                    if (log.contains('Error') || log.contains('Failed')) {
                                      logColor = Colors.redAccent;
                                    } else if (log.contains('Uploading') || log.contains('Downloading')) {
                                      logColor = accentColor;
                                    } else if (log.contains('Success') || log.contains('successfully')) {
                                      logColor = const Color(0xFF81C784);
                                    } else if (log.contains('[Info]')) {
                                      logColor = Colors.blueAccent;
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Text(
                                        log,
                                        style: GoogleFonts.firaCode(
                                          fontSize: 11,
                                          color: logColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.white38,
                ),
              ),
              Icon(icon, color: accentColor.withOpacity(0.6), size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActionButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onPressed,
    Color accentColor,
  ) {
    final bool disabled = onPressed == null;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: disabled 
            ? LinearGradient(
                colors: [Colors.white.withOpacity(0.02), Colors.white.withOpacity(0.04)],
              )
            : LinearGradient(
                colors: [accentColor.withOpacity(0.12), accentColor.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: disabled
              ? Colors.white.withOpacity(0.03)
              : accentColor.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          splashColor: accentColor.withOpacity(0.15),
          hoverColor: accentColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: disabled
                        ? Colors.white.withOpacity(0.04)
                        : accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon, 
                    color: disabled ? Colors.white24 : accentColor, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: disabled ? Colors.white30 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: disabled ? Colors.white24 : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

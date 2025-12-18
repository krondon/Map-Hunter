
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

void showGameSnackBar(BuildContext context, {required String title, required String message, bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 4),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? AppTheme.dangerRed.withOpacity(0.9) : AppTheme.successGreen.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white24,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showGameDialog(BuildContext context, {required String title, required String message, required IconData icon, Color iconColor = AppTheme.primaryPurple}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
             BoxShadow(color: iconColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: iconColor.withOpacity(0.1),
               ),
               child: Icon(icon, size: 40, color: iconColor),
             ),
             const SizedBox(height: 16),
             Text(
               title,
               textAlign: TextAlign.center,
               style: const TextStyle(
                 color: Colors.white, 
                 fontSize: 22, 
                 fontWeight: FontWeight.bold,
                 letterSpacing: 1
               ),
             ),
             const SizedBox(height: 12),
             Text(
               message,
               textAlign: TextAlign.center,
               style: const TextStyle(color: Colors.white70, fontSize: 15),
             ),
             const SizedBox(height: 24),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: () => Navigator.pop(context),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: iconColor,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   padding: const EdgeInsets.symmetric(vertical: 12),
                 ),
                 child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
               ),
             )
          ],
        ),
      ),
    ),
  );
}

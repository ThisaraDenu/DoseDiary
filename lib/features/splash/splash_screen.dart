import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/route_names.dart';
import '../../core/services/permission_service.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../main.dart';
import '../../services/dose_alarm_scheduler.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _loopCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;
    if (!onboardingDone) {
      context.go(RouteNames.onboarding);
    } else if (session != null) {
      SupabaseSyncService.pullFromCloud()
          .then((_) => DoseAlarmScheduler.syncUpcomingAlarms())
          .ignore();
      final needsGoogleProfile = AuthService.isGoogleUser &&
          await AuthService.needsProfileCompletion();
      if (!mounted) return;
      if (needsGoogleProfile) {
        context.go(RouteNames.completeGoogleProfile);
      } else if (!PermissionService.hasPrompted(prefs)) {
        context.go(RouteNames.permissions);
      } else {
        context.go(RouteNames.home);
      }
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solid cream Scaffold ensures no black flash on any theme / renderer
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE7),
      body: Stack(
        children: [
          // ── Background texture ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash_bg.jpg',
              fit: BoxFit.cover,
              // errorBuilder prevents any crash if asset isn't bundled yet
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFF3EFE7),
              ),
            ),
          ),

          // ── Animated centre content ─────────────────────────────────────
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                animation: _loopCtrl,
                builder: (context, _) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo + clock hands
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/images/splash_logo.png',
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(),
                                ),
                              ),
                              // Clock hands — no MaskFilter, no BoxShadow
                              CustomPaint(
                                size: const Size(220, 220),
                                painter: _ClockPainter(_loopCtrl.value),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Brand name
                        Text(
                          'DoseDiary',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Your medication companion',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF7A7060),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Three-dot wave
                        _WaveDots(t: _loopCtrl.value),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clock-hands painter (no MaskFilter.blur — safe on Impeller / OpenGLES)
// ---------------------------------------------------------------------------
class _ClockPainter extends CustomPainter {
  final double t; // 0..1 loop progress

  const _ClockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Centre of the capsule pill in the logo image (empirically measured)
    final c = Offset(size.width * 0.478, size.height * 0.492);

    final minAngle = -math.pi / 4 + t * 2 * math.pi; // full rotation
    final hrAngle = -math.pi / 4 + t * 0.5 * math.pi; // quarter rotation

    final minLen = size.width * 0.16;
    final hrLen = size.width * 0.11;

    // Offset shadow — GPU-safe alternative to MaskFilter.blur
    const sh = Offset(2.0, 3.0);
    final shPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final hp = Paint()
      ..color = const Color(0xFFDC143C)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final hrEnd =
        c + Offset(math.cos(hrAngle) * hrLen, math.sin(hrAngle) * hrLen);
    final minEnd =
        c + Offset(math.cos(minAngle) * minLen, math.sin(minAngle) * minLen);

    // Hour hand
    shPaint.strokeWidth = hp.strokeWidth = size.width * 0.024;
    canvas.drawLine(c + sh, hrEnd + sh, shPaint);
    canvas.drawLine(c, hrEnd, hp);

    // Minute hand
    shPaint.strokeWidth = hp.strokeWidth = size.width * 0.018;
    canvas.drawLine(c + sh, minEnd + sh, shPaint);
    canvas.drawLine(c, minEnd, hp);

    // Pivot pin shadow
    final r = size.width * 0.022;
    canvas.drawCircle(
        c + sh,
        r,
        Paint()
          ..color = Colors.black.withOpacity(0.15)
          ..style = PaintingStyle.fill);

    // Pivot pin fill
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = const Color(0xFFDC143C)
          ..style = PaintingStyle.fill);

    // Specular highlight
    canvas.drawCircle(
        c - const Offset(0.8, 0.8),
        r * 0.35,
        Paint()
          ..color = Colors.white.withOpacity(0.80)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Three-dot wave loading indicator
// ---------------------------------------------------------------------------
class _WaveDots extends StatelessWidget {
  final double t;
  const _WaveDots({required this.t});

  @override
  Widget build(BuildContext context) {
    final wave = (t * 2.2) % 1.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = ((wave - i * 0.28) % 1.0 + 1.0) % 1.0;
        final intensity =
            phase < 0.5 ? math.sin(phase * 2 * math.pi).clamp(0.0, 1.0) : 0.0;
        final color = Color.lerp(
          const Color(0xFFE8C5CC),
          const Color(0xFFDC143C),
          intensity,
        )!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: 1.0 + 0.3 * intensity,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      }),
    );
  }
}

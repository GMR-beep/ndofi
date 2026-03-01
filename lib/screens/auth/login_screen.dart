import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_state.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMsg = '';
  bool _showSuccess = false;

  // Animations
  late AnimationController _fadeCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _successCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();

    // Fade + slide au chargement
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();

    // Shake sur erreur
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    // Animation succès
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successScale = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    _successOpacity = CurvedAnimation(
        parent: _successCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMsg = 'Veuillez remplir tous les champs';
      });
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() { _isLoading = true; _hasError = false; });

    final ok = await context.read<AppState>().login(username, password);

    if (!mounted) return;

    if (ok) {
      // Animation de succès
      setState(() { _showSuccess = true; _isLoading = false; });
      await _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;

      // Navigation vers dashboard
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => const DashboardScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim, child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMsg = 'Identifiant ou mot de passe incorrect';
      });
      _shakeCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écran de succès
    if (_showSuccess) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: ScaleTransition(
            scale: _successScale,
            child: FadeTransition(
              opacity: _successOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bienvenue,\n${_userCtrl.text.trim()} !',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chargement de votre espace...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white54),
                      strokeWidth: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _fadeCtrl,
        builder: (_, child) => Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 48),

                // Logo
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.people_alt,
                      size: 48, color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Titre
                const Text(
                  "N'Dofi",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gestion intelligente des présences',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Formulaire avec shake
                AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      _shakeAnim.value > 0
                          ? 8 * (0.5 - (_shakeAnim.value % 1).abs())
                          : 0,
                      0,
                    ),
                    child: child,
                  ),
                  child: Column(children: [
                    // Champ identifiant
                    TextField(
                      controller: _userCtrl,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() => _hasError = false),
                      decoration: InputDecoration(
                        labelText: 'Identifiant',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError
                                ? AppColors.absent.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Champ mot de passe
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      onChanged: (_) => setState(() => _hasError = false),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError
                                ? AppColors.absent.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Message d'erreur
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _hasError
                          ? Container(
                              key: const ValueKey('error'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.absent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.absent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_errorMsg,
                                      style: const TextStyle(
                                          color: AppColors.absent,
                                          fontSize: 13)),
                                ),
                              ]),
                            )
                          : const SizedBox.shrink(key: ValueKey('no_error')),
                    ),
                    const SizedBox(height: 24),

                    // Bouton connexion
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white)),
                              )
                            : const Text('Se connecter',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 48),

                // Footer
                const Text(
                  '100% hors ligne · Données sécurisées',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.storage,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  const Text('SQLite local',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

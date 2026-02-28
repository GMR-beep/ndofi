import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../providers/app_state.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _hasError = false;
  bool _loading = false;
  String _errorMsg = '';
  int _tapCount = 0;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMsg = 'Veuillez remplir tous les champs';
      });
      return;
    }

    setState(() { _loading = true; _hasError = false; });
    bool ok = false;
    try {
      // AJOUT DES .TRIM() POUR EVITER LES ESPACES CACHES
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text.trim();

      ok = await context.read<AppState>()
          .login(username, password)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
    } catch (e) {
      ok = false;
    }

    if (!mounted) return;
    setState(() { _loading = false; });

    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      setState(() {
        _hasError = true;
        _errorMsg = 'Identifiant ou mot de passe incorrect, ou compte bloqué';
      });
    }
  }

  // Appuyer 5 fois sur le logo pour afficher la réinitialisation
  void _onLogoTap() {
    setState(() => _tapCount++);
    if (_tapCount >= 5) {
      setState(() => _tapCount = 0);
      _showResetDialog();
    }
  }

  Future<void> _showResetDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réinitialisation d\'urgence'),
        content: const Text(
          'Ceci va réinitialiser le compte admin avec le mot de passe par défaut "admin123".\n\nContinuer ?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.resetAdminAccount();
      setState(() {
        _userCtrl.text = 'admin';
        _passCtrl.text = '';
        _hasError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Compte réinitialisé ! Connectez-vous avec admin / admin123'),
          backgroundColor: AppColors.present,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _onLogoTap,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_alt, size: 60, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "N' Dofi",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestion intelligente des présences',
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                    ),
                    if (_tapCount > 0 && _tapCount < 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _tapCount
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.2),
                            ),
                          )),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entrez vos identifiants pour continuer',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Identifiant',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        errorText: _hasError ? _errorMsg : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const Spacer(),
                    Center(
                      child: Text(
                        'Par défaut : admin / admin123',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: GestureDetector(
                        onTap: _showResetDialog,
                        child: Text(
                          'Réinitialiser le compte admin',
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.25),
                            fontSize: 10,
                          ),
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
    );
  }
}
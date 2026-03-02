import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool loading = false;
  bool obscure1 = true;
  bool obscure2 = true;
  String? error;
  bool success = false;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }

    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$");

    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != password.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  Future<void> doRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await Supabase.instance.client.functions.invoke(
        'send_verification_code',
        body: {'email': email.text.trim()},
      );

      setState(() => success = true);

      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;
      context.push(
        '/auth/verify',
        extra: {'email': email.text.trim(), 'password': password.text},
      );
    } catch (e) {
      setState(() => error = 'No se pudo crear la cuenta');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _gradientButton() {
    return GestureDetector(
      onTap: loading ? null : doRegister,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : success
              ? const Icon(Icons.check, color: Colors.white)
              : Text(
                  'Crear cuenta',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    if (error == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F5F9), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      const Text(
                        'Crear cuenta 🚀',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Comienza a administrar tus eventos',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                      _errorBanner(),
                      Hero(
                        tag: 'auth-card',
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: email,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: password,
                                    obscureText: obscure1,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscure1
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () => setState(
                                          () => obscure1 = !obscure1,
                                        ),
                                      ),
                                    ),
                                    validator: _validatePassword,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: confirm,
                                    obscureText: obscure2,
                                    decoration: InputDecoration(
                                      labelText: 'Confirmar contraseña',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscure2
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () => setState(
                                          () => obscure2 = !obscure2,
                                        ),
                                      ),
                                    ),
                                    validator: _validateConfirm,
                                  ),
                                  const SizedBox(height: 30),
                                  _gradientButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/auth/login'),
                          child: const Text('Ya tengo cuenta'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

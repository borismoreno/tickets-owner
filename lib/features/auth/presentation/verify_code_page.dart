import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifyCodePage extends StatefulWidget {
  final String email;
  final String password;

  const VerifyCodePage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage>
    with SingleTickerProviderStateMixin {
  final codeController = TextEditingController();

  bool loading = false;
  bool success = false;
  String? error;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(_fade);

    _controller.forward();
  }

  @override
  void dispose() {
    codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> verifyCode() async {
    if (codeController.text.length != 6) {
      setState(() => error = "Ingresa un código válido de 6 dígitos");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify_code',
        body: {
          'email': widget.email,
          'password': widget.password,
          'code': codeController.text,
        },
      );

      if (response.status == 200) {
        setState(() => success = true);

        // Login automático
        await Supabase.instance.client.auth.signInWithPassword(
          email: widget.email,
          password: widget.password,
        );

        if (!mounted) return;
        context.go('/events');
      } else {
        throw Exception();
      }
    } catch (_) {
      setState(() => error = "Código inválido o expirado");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resendCode() async {
    await Supabase.instance.client.functions.invoke(
      'send-verification-code',
      body: {'email': widget.email},
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Código reenviado")));
  }

  Widget _gradientButton() {
    return GestureDetector(
      onTap: loading ? null : verifyCode,
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
              : const Text(
                  'Verificar',
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      resizeToAvoidBottomInset: true,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    const Text(
                      "Verifica tu email 📩",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Enviamos un código a\n${widget.email}",
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 40),

                    _errorBanner(),

                    TextField(
                      controller: codeController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        counterText: "",
                        hintText: "000000",
                      ),
                    ),

                    const SizedBox(height: 30),

                    _gradientButton(),

                    const SizedBox(height: 20),

                    Center(
                      child: TextButton(
                        onPressed: resendCode,
                        child: const Text("Reenviar código"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore_for_file: avoid_print, flutter_style_todos, lines_longer_than_80_chars, inference_failure_on_instance_creation

import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homi/login_page.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _isButtonEnabled = true;

  // Map of Firebase error codes to user-friendly messages
  Map<String, String> _getErrorMessages(AppLocalizations l10n) => {
    'success': l10n.passwordResetLinkSent,
    'invalid-email': l10n.invalidEmail,
    'user-not-found': l10n.noAccountFound,
    'too-many-requests': l10n.tooManyAttempts,
    'network-request-failed': l10n.networkError,
  };

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (value == null || value.isEmpty) {
        _errorMessage = l10n.pleaseEnterEmail;
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        _errorMessage = l10n.pleaseEnterValidEmail;
      } else {
        _errorMessage = null;
      }
    });
  }

  Future<void> _handleResetPassword() async {
    if (!_isButtonEnabled || _isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final errorMessages = _getErrorMessages(l10n);

    setState(() {
      _isLoading = true;
      _isButtonEnabled = false;
      _errorMessage = null; // Clear previous messages
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _errorMessage = errorMessages['success'];
      });

      // Navigate back to LoginPage after a short delay to show the message
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = errorMessages[e.code] ?? l10n.failedToSendResetEmail;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = l10n.unexpectedError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Re-enable button after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isButtonEnabled = true;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Directionality(
      textDirection: TextDirection.ltr, // Keep LTR for consistent layout
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      l10n.forgotPassword,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      l10n.forgotPasswordDescription,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.5,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        labelStyle: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                          fontFamily: 'Montserrat',
                        ),
                        prefixIcon: Icon(Iconsax.sms, color: Colors.grey.shade800),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade800, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        errorText: null, // Prevent default error text
                        errorStyle: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontFamily: 'Montserrat',
                      ),
                      onChanged: _validateEmail,
                      validator: (value) {
                        // Validation handled by _validateEmail
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),

                  // Error or Success Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 24),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _errorMessage == _getErrorMessages(l10n)['success']
                              ? const Color(0xFF43A047) // Green for success
                              : Colors.red.shade600, // Red for errors
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Reset Password Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _handleResetPassword,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _isLoading ? Colors.grey.shade300 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.grey,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Iconsax.lock,
                                    color: Colors.grey.shade800,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.resetPassword,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
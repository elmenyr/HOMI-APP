import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homi/app.dart';
import 'package:homi/app_data.dart';
import 'package:homi/login_page.dart';
import 'package:homi/pages/complete_profile_page.dart';
import 'package:iconsax/iconsax.dart';
import 'package:homi/utils/user_preferences.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Password validation states
  bool _hasLowercase = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasMinLength = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  void _validatePassword(String password) {
    setState(() {
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasMinLength = password.length >= 8;
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _passwordsMatch = _confirmPasswordController.text.isNotEmpty &&
          _confirmPasswordController.text == password;
    });
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => _validatePassword(_passwordController.text));
    _confirmPasswordController.addListener(() {
      setState(() {
        _passwordsMatch = _confirmPasswordController.text == _passwordController.text;
      });
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(() => _validatePassword(_passwordController.text));
    _confirmPasswordController.removeListener(() {});
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invalid Email',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
              Text(
                'Please enter a valid email address',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
              Text(
                'Please meet all password requirements',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passwords do not match',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await userCredential.user?.updateDisplayName(_fullNameController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // This is definitely a first login since the user just signed up
      // No need to check UserPreferences.isFirstLogin here

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully!',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Color(0xFF66BB6A),
        ),
      );

      // Navigate to CompleteProfileScreen instead of directly to App
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CompleteProfileScreen(),
        ),
      );
      
      // Mark user as logged in for future sessions
      if (userCredential.user != null) {
        await UserPreferences.markUserLoggedIn(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      var errorMessage = 'An error occurred during sign up';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
            ),
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'An error occurred. Please try again later.',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Force left alignment
                  children: [
                    const SizedBox(height: 60),

                    // Title
                    Container(
                      alignment: Alignment.centerLeft, // Force left alignment
                      child: Text(
                        AppLocalizations.of(context)!.signUp,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'Montserrat',
                          height: 1.2,
                        ),
                        textAlign: TextAlign.left, // Force left text alignment
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Form fields
                    TextFormField(
                      controller: _fullNameController,
                      textAlign: TextAlign.left, // Force left text alignment
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.fullName,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                        prefixIcon: Icon(Iconsax.user, color: Colors.grey[800]),
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
                          vertical: 20,
                        ),
                        errorStyle: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                        alignLabelWithHint: true, // Align hint with text
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.enterFullName;
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      textAlign: TextAlign.left, // Force left text alignment
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.emailHint,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                        prefixIcon: Icon(Iconsax.sms, color: Colors.grey[800]),
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
                          vertical: 20,
                        ),
                        errorStyle: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                        alignLabelWithHint: true, // Align hint with text
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.emailRequired;
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return AppLocalizations.of(context)!.invalidEmail;
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textAlign: TextAlign.left, // Force left text alignment
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.password,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                        prefixIcon: Icon(Iconsax.lock, color: Colors.grey[800]),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                            color: Colors.grey.shade800,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
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
                          vertical: 20,
                        ),
                        errorStyle: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                        alignLabelWithHint: true, // Align hint with text
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.passwordRequired;
                        }
                        if (value.length < 8) {
                          return AppLocalizations.of(context)!.passwordLength;
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textAlign: TextAlign.left, // Force left text alignment
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.password,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                        prefixIcon: Icon(Iconsax.lock, color: Colors.grey[800]),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                            color: Colors.grey.shade800,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
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
                          vertical: 20,
                        ),
                        errorStyle: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                        alignLabelWithHint: true, // Align hint with text
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context)!.passwordRequired;
                        }
                        if (value != _passwordController.text) {
                          return AppLocalizations.of(context)!.passwordLength;
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Requirements
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildRequirement('At least 8 characters', _hasMinLength),
                          _buildRequirement('Contains uppercase letter', _hasUppercase),
                          _buildRequirement('Contains lowercase letter', _hasLowercase),
                          _buildRequirement('Contains number', _hasNumber),
                          _buildRequirement('Contains special character', _hasSpecialChar),
                          _buildRequirement('Passwords match', _passwordsMatch),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Create Account Button
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleSignUp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.grey))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Iconsax.user_add,
                                      color: Color(0xFF616161),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      AppLocalizations.of(context)!.signUp,
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
                    const SizedBox(height: 16),

                    // Sign In Link
                    Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.noAccount,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              AppLocalizations.of(context)!.signIn,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Logo at top-right corner
            Positioned(
              top: 16,
              right: 16,
              child: Image.asset(
                'assets/images/home.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    // Get the appropriate translation key based on the text
    String translatedText;
    switch (text) {
      case 'At least 8 characters':
        translatedText = AppLocalizations.of(context)!.passwordMinChars;
        break;
      case 'Contains uppercase letter':
        translatedText = AppLocalizations.of(context)!.passwordUppercase;
        break;
      case 'Contains lowercase letter':
        translatedText = AppLocalizations.of(context)!.passwordLowercase;
        break;
      case 'Contains number':
        translatedText = AppLocalizations.of(context)!.passwordNumber;
        break;
      case 'Contains special character':
        translatedText = AppLocalizations.of(context)!.passwordSpecialChar;
        break;
      case 'Passwords match':
        translatedText = AppLocalizations.of(context)!.passwordsMatch;
        break;
      default:
        translatedText = text;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            translatedText,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}
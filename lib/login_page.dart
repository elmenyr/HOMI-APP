// ignore_for_file: flutter_style_todos, avoid_print, prefer_int_literals, inference_failure_on_instance_creation, lines_longer_than_80_chars, directives_ordering, avoid_void_async, unawaited_futures, omit_local_variable_types, unused_import, deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:homi/app.dart';
import 'package:homi/app_data.dart';
import 'package:homi/forgot_password_page.dart';
import 'package:homi/signup_page.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homi/utils/user_preferences.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Constants for styling and configuration
class LoginConstants {
  static const animationDuration = Duration(milliseconds: 800);
  static const snackBarDuration = Duration(seconds: 3);
  static const buttonHeight = 48.0;
  static const borderRadius = 10.0;
  static const borderWidth = 1.5;
  static const iconSize = 18.0;
  static const loadingIndicatorSize = 20.0;
  static const loadingIndicatorStrokeWidth = 2.0;
  static const horizontalPadding = 24.0;
  static const verticalPadding = 16.0;
  static const spacingSmall = 8.0;
  static const spacingMedium = 16.0;
  static const spacingLarge = 20.0;
  static const spacingXLarge = 40.0;
  
  static const fontFamily = 'Montserrat';
  static const titleFontSize = 28.0;
  static const bodyFontSize = 16.0;
  static const buttonFontSize = 14.0;
}

// Keys for SharedPreferences
class PreferenceKeys {
  static const rememberMe = 'rememberMe';
  static const email = 'email';
  static const password = 'password';
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleSignIn = GoogleSignIn();
  
  late SharedPreferences _prefs;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  
  bool _isEmailSignInLoading = false;
  bool _isGoogleSignInLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSavedCredentials();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: LoginConstants.animationDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  Future<void> _loadSavedCredentials() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = _prefs.getBool(PreferenceKeys.rememberMe) ?? false;
      if (_rememberMe) {
        _emailController.text = _prefs.getString(PreferenceKeys.email) ?? '';
        _passwordController.text = _prefs.getString(PreferenceKeys.password) ?? '';
      }
    });
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _prefs.setString(PreferenceKeys.email, _emailController.text);
      await _prefs.setString(PreferenceKeys.password, _passwordController.text);
      await _prefs.setBool(PreferenceKeys.rememberMe, true);
    } else {
      await _prefs.remove(PreferenceKeys.email);
      await _prefs.remove(PreferenceKeys.password);
      await _prefs.setBool(PreferenceKeys.rememberMe, false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: LoginConstants.bodyFontSize,
            fontWeight: FontWeight.w500,
            fontFamily: LoginConstants.fontFamily,
          ),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(LoginConstants.spacingMedium),
        duration: LoginConstants.snackBarDuration,
      ),
    );
  }

  String _getFirebaseAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found for this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'The email address is invalid';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts, please try again later';
      default:
        return 'Sign-in failed: $errorCode';
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _isEmailSignInLoading = true);
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await _saveCredentials();
      
      if (userCredential.user != null) {
        await _navigateToMainApp(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isEmailSignInLoading = false);
        _showErrorMessage(_getFirebaseAuthErrorMessage(e.code));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEmailSignInLoading = false);
        _showErrorMessage('An unexpected error occurred');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleSignInLoading) return;
    
    if (mounted) {
      setState(() => _isGoogleSignInLoading = true);
    }

    try {
      await _setSystemUIStyle();
      
      final googleUser = await _attemptGoogleSignIn();
      if (googleUser == null) {
        _handleGoogleSignInCancelled();
        return;
      }

      await _completeGoogleSignIn(googleUser);
    } catch (e) {
      _handleGoogleSignInError(e);
    }
  }

  Future<void> _setSystemUIStyle() async {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<GoogleSignInAccount?> _attemptGoogleSignIn() async {
    final silentSignIn = await _googleSignIn.signInSilently();
    if (silentSignIn != null) return silentSignIn;
    return _googleSignIn.signIn();
  }

  void _handleGoogleSignInCancelled() {
    if (mounted) {
      setState(() => _isGoogleSignInLoading = false);
    }
  }

  Future<void> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _navigateToMainApp(userCredential.user!.uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleSignInLoading = false);
        _showErrorMessage('An error occurred during sign-in');
      }
    }
  }

  void _handleGoogleSignInError(dynamic error) {
    debugPrint('Google Sign-In error: $error');
    if (mounted) {
      _showErrorMessage('An error occurred during sign-in');
      setState(() => _isGoogleSignInLoading = false);
    }
  }

  Future<void> _navigateToMainApp(String userId) async {
    if (!mounted) return;
    
    setState(() {
      _isEmailSignInLoading = false;
      _isGoogleSignInLoading = false;
    });
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => FeatureDiscovery(
          child: App(
            data: AppData(),
            isFirstLogin: true,
          ),
        ),
      ),
      (route) => false,
    );
    
    await UserPreferences.markUserLoggedIn(userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        appBar: _buildAppBar(),
        body: _buildBody(l10n),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        maintainBottomViewPadding: true,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LoginConstants.horizontalPadding,
                vertical: LoginConstants.verticalPadding,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    _buildTitle(l10n),
                    const SizedBox(height: LoginConstants.spacingXLarge),
                    const SizedBox(height: LoginConstants.spacingLarge),
                    _buildEmailField(l10n),
                    const SizedBox(height: LoginConstants.spacingMedium),
                    _buildPasswordField(l10n),
                    const SizedBox(height: LoginConstants.spacingSmall),
                    _buildRememberMeCheckbox(l10n),
                    const SizedBox(height: LoginConstants.spacingMedium),
                    _buildForgotPasswordButton(l10n),
                    const SizedBox(height: LoginConstants.spacingLarge),
                    _buildEmailSignInButton(l10n),
                    const SizedBox(height: LoginConstants.spacingSmall),
                    _buildGoogleSignInButton(l10n),
                    const SizedBox(height: LoginConstants.spacingMedium),
                    _buildSignUpLink(l10n),
                    const SizedBox(height: LoginConstants.spacingLarge),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _fadeController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: Image.asset(
            'assets/images/home.png',
            height: 40,
            width: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _fadeController,
          curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.login,
            style: const TextStyle(
              fontSize: LoginConstants.titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: LoginConstants.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(AppLocalizations l10n) {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        hintText: l10n.emailHint,
        hintStyle: TextStyle(
          color: Colors.grey.shade600,
          fontFamily: LoginConstants.fontFamily,
        ),
        prefixIcon: Icon(Iconsax.user, color: Colors.grey.shade800),
        border: _buildInputBorder(),
        enabledBorder: _buildInputBorder(),
        focusedBorder: _buildInputBorder(width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LoginConstants.horizontalPadding,
          vertical: LoginConstants.verticalPadding,
        ),
        errorStyle: TextStyle(
          color: Colors.red.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: LoginConstants.fontFamily,
        ),
      ),
      validator: _validateEmail,
      style: const TextStyle(
        fontSize: LoginConstants.bodyFontSize,
        fontFamily: LoginConstants.fontFamily,
      ),
      textAlignVertical: TextAlignVertical.center,
    );
  }

  Widget _buildPasswordField(AppLocalizations l10n) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: l10n.password,
        hintStyle: TextStyle(
          color: Colors.grey.shade600,
          fontFamily: LoginConstants.fontFamily,
        ),
        prefixIcon: Icon(Iconsax.lock, color: Colors.grey.shade800),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
            color: Colors.grey.shade800,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: _buildInputBorder(),
        enabledBorder: _buildInputBorder(),
        focusedBorder: _buildInputBorder(width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LoginConstants.horizontalPadding,
          vertical: LoginConstants.verticalPadding,
        ),
        errorStyle: TextStyle(
          color: Colors.red.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: LoginConstants.fontFamily,
        ),
      ),
      validator: _validatePassword,
      style: const TextStyle(
        fontSize: LoginConstants.bodyFontSize,
        fontFamily: LoginConstants.fontFamily,
      ),
      textAlignVertical: TextAlignVertical.center,
    );
  }

  String? _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l10n.emailRequired;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return l10n.invalidEmail;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l10n.passwordRequired;
    }
    if (value.length < 8) {
      return l10n.passwordLength;
    }
    return null;
  }

  InputBorder _buildInputBorder({double width = LoginConstants.borderWidth}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(LoginConstants.borderRadius),
      borderSide: BorderSide(
        color: width == 2 ? Colors.grey.shade800 : Colors.grey.shade300,
        width: width,
      ),
    );
  }

  Widget _buildRememberMeCheckbox(AppLocalizations l10n) {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: Colors.grey.shade800,
        ),
        Text(
          l10n.rememberMe,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: LoginConstants.bodyFontSize,
            fontFamily: LoginConstants.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordButton(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ForgotPasswordPage(),
            ),
          );
        },
        child: Text(
          l10n.forgotPassword,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
            fontSize: LoginConstants.bodyFontSize,
            fontFamily: LoginConstants.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSignInButton(AppLocalizations l10n) {
    return _buildAuthButton(
      onPressed: _isEmailSignInLoading ? null : _handleEmailSignIn,
      isLoading: _isEmailSignInLoading,
      icon: Iconsax.login,
      label: l10n.signIn,
    );
  }

  Widget _buildGoogleSignInButton(AppLocalizations l10n) {
    return _buildAuthButton(
      onPressed: _isGoogleSignInLoading ? null : _handleGoogleSignIn,
      isLoading: _isGoogleSignInLoading,
      icon: null,
      label: l10n.signInWithGoogle,
      leadingWidget: Image.asset(
        'assets/images/googlelogo.png',
        height: LoginConstants.loadingIndicatorSize,
        width: LoginConstants.loadingIndicatorSize,
      ),
    );
  }

  Widget _buildAuthButton({
    VoidCallback? onPressed,
    required bool isLoading,
    IconData? icon,
    required String label,
    Widget? leadingWidget,
  }) {
    return Container(
      width: double.infinity,
      height: LoginConstants.buttonHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade800,
          width: LoginConstants.borderWidth,
        ),
        borderRadius: BorderRadius.circular(LoginConstants.borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LoginConstants.borderRadius),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: LoginConstants.loadingIndicatorSize,
                    height: LoginConstants.loadingIndicatorSize,
                    child: CircularProgressIndicator(
                      strokeWidth: LoginConstants.loadingIndicatorStrokeWidth,
                      color: Colors.grey,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingWidget != null) leadingWidget,
                      if (icon != null)
                        Icon(
                          icon,
                          color: Colors.grey.shade800,
                          size: LoginConstants.iconSize,
                        ),
                      const SizedBox(width: LoginConstants.spacingSmall),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: LoginConstants.buttonFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          fontFamily: LoginConstants.fontFamily,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.noAccount,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: LoginConstants.bodyFontSize,
            fontFamily: LoginConstants.fontFamily,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SignUpPage()),
            );
          },
          child: Text(
            l10n.signUp,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.bold,
              fontSize: LoginConstants.bodyFontSize,
              fontFamily: LoginConstants.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:media_house/app/provider/sign_up_provider.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/ui/pages/sign%20in%20page/SignInPage.dart';
import 'package:media_house/app/widget/custom_textfield.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  static const List<String> _firmTypeOptions = [
    'Private Limited',
    'LLP',
    'Partnership',
    'Proprietory',
    'Other',
  ];

  static const List<String> _designationOptions = [
    'Owner',
    'Director',
    'CEO',
    'Manager',
    'Authorized Signatory',
    'Other',
  ];

  int _currentStep = 0;
  final List<GlobalKey<FormState>> _stepKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  final List<bool> _showStepValidation = [false, false, false, false];

  final Map<String, String> _labels = {
    'mediaHouseName': 'Production House Name',
    'firmType': 'Firm Type',
    'discription': 'Description',
    'email': 'Autherized Email',
    'emailId': 'Alternate Email',
    'contactNumber': 'Autherized Contact Number',
    'mobileNumber': 'Autherized Mobile Number',
    'refferedBy': 'Referred By',
    'postCount': 'Post Count',
    'totalViews': 'Total Views',
    'totalReveneu': 'Total Revenue',
    'officeBuilding': 'Office Building',
    'address': 'Address',
    'area': 'Area',
    'city': 'City',
    'district': 'District',
    'taluka': 'Taluka',
    'state': 'State',
    'country': 'Country',
    'pincode': 'Pincode',
    'dob': 'Date of Birth',
    'designation': 'Designation',
    'ceoName': 'CEO Name',
    'ceoEmail': 'CEO Email',
    'ceoMobile': 'CEO Mobile',
    'directorName': 'Firm Director Name',
    'directorEmail': 'Firm Director Email',
    'directorMobile': 'Firm Director Mobile',
    'accountHolderName': 'Account Holder Name',
    'bankName': 'Bank Name',
    'bankAccountNumber': 'Bank Account Number',
    'bankIFSCNumber': 'Bank IFSC Number',
    'logo': 'Logo',
    'profileImage': 'Profile Image',
    'addressProof': 'Address Proof',
    'adharCard': 'Signing Authority Aadhaar Card',
    'panCard': 'Firm PAN Card',
    'bankProof': 'Bank Proof',
    'gstCertificates': 'GST Certificate',
    'registrationCertificate': 'Registration Certificate',
    'shopAct': 'Shop Act/Udyam Aadhaar',
    'password': 'Password',
    'confirmPassword': 'Confirm Password',
  };

  final Set<String> _requiredFields = {
    'mediaHouseName',
    'firmType',
    'email',
    'mobileNumber',
    'directorName',
    'directorEmail',
    'directorMobile',
    'city',
    'state',
    'country',
    'pincode',
    'bankName',
    'bankAccountNumber',
    'bankIFSCNumber',
    'password',
    'confirmPassword',
  };

  final Set<String> _emailFields = {
    'email',
    'emailId',
    'ceoEmail',
    'directorEmail',
  };

  final Set<String> _contactPhoneFields = {
    'contactNumber',
    'mobileNumber',
    'ceoMobile',
    'directorMobile',
  };
  final Set<String> _uploadFields = {
    'logo',
    'addressProof',
    'adharCard',
    'panCard',
    'bankProof',
    'gstCertificates',
    'shopAct',
    'registrationCertificate',
  };
  final Set<String> _requiredUploadFields = {
    //  'registrationCertificate',
    'adharCard',
    'panCard',
    'bankProof',
    //'gstCertificates',
    'addressProof',
  };

  final List<String> _stepOneFields = [
    'mediaHouseName',
    'firmType',
    'registrationCertificate',
    'designation',
  ];

  final List<String> _stepTwoFields = [
    'country',
    'state',
    'district',
    'city',
    'taluka',
    'officeBuilding',
    'area',
    'pincode',
  ];

  final List<String> _stepThreeFields = [
    'accountHolderName',
    'bankName',
    'bankAccountNumber',
    'bankIFSCNumber',
    'logo',
    'addressProof',
    'adharCard',
    'panCard',
    'bankProof',
    'gstCertificates',
    'shopAct',
  ];

  final List<String> _stepFourFields = [
    'email',
    'emailId',
    'mobileNumber',
    'password',
    'confirmPassword',
  ];

  final List<String> _stepFiveFields = [
    'directorName',
    'directorEmail',
    'directorMobile',
    'ceoName',
    'ceoEmail',
    'ceoMobile',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SignUpProvider>().fetchCountriesIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final selectedThemeData = themeProvider.getTheme;
    final isDark = selectedThemeData.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: selectedThemeData.scaffoldBackgroundColor,
        elevation: 0,
        toolbarHeight: ResponsiveWidget.isMobile(context) ? 10 : 50,
        /*   title: SizedBox(
          height: ResponsiveWidget.isMobile(context) ? 70 : 100,
          child: Image.asset(ImageConstant.logo),
        ), */
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                color: selectedThemeData.canvasColor,
              ),
              onPressed: themeProvider.toggleTheme,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight -
                        40 -
                        MediaQuery.of(context).viewInsets.bottom)
                    .clamp(0.0, double.infinity),
              ),
              child: Center(
                child: SizedBox(
                  width:
                      ResponsiveWidget.isMobile(context) ? double.infinity : 700,
                  child: Consumer<SignUpProvider>(
                    builder: (context, signUpProvider, child) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: selectedThemeData.canvasColor
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: selectedThemeData.dividerColor
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildHeaderCard(selectedThemeData),
                                _buildProgressIndicator(selectedThemeData),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: selectedThemeData
                                          .scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: selectedThemeData.dividerColor
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Form(
                                      key: _stepKeys[_currentStep],
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _stepTitle,
                                            style: TextStyle(
                                              color:
                                                  selectedThemeData.primaryColor,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ..._buildFields(
                                            signUpProvider,
                                            _currentStepFields,
                                            selectedThemeData,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                _buildFooter(selectedThemeData, signUpProvider),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: TextStyle(
                                  color: selectedThemeData.canvasColor,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: _navigateToSignIn,
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: selectedThemeData.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFields(
      SignUpProvider provider, List<String> keys, ThemeData themeData) {
    return keys.map((key) {
      final isRequired = _requiredFields.contains(key);
      final isEmail = _emailFields.contains(key);
      final isPhone = _contactPhoneFields.contains(key);
      final isDigitsOnly = key == 'pincode' || key == 'bankAccountNumber';

      if (_uploadFields.contains(key)) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildUploadField(provider, key, themeData),
        );
      }

      if (key == 'firmType') {
        return _buildFirmTypeField(provider, themeData);
      }

      if (key == 'designation') {
        return _buildDesignationField(provider, themeData);
      }

      if (key == 'country') {
        return _buildCountryField(provider, themeData);
      }

      if (key == 'state') {
        return _buildStateField(provider, themeData);
      }

      if (key == 'password' || key == 'confirmPassword') {
        return CustomTextField(
          controller: provider.controller(key),
          hintText: 'Enter ${_labels[key] ?? key}',
          label: _labels[key] ?? key,
          showRequiredAsterisk: true,
          textInputType: TextInputType.visiblePassword,
          isPassword: true,
          isValidator: false,
          validator: (value) => _validateFieldByKey(key, provider),
        );
      }

      String? Function(String?)? validator;
      if (isEmail) {
        validator = (value) => _validateEmail(value, key, isRequired);
      } else if (isPhone) {
        validator = (value) => _validatePhone(value, key, isRequired);
      } else {
        validator =
            (value) => _validateTextField(value, key, isRequired, isDigitsOnly);
      }

      return CustomTextField(
        controller: provider.controller(key),
        hintText: 'Enter ${_labels[key] ?? key}',
        label: _labels[key] ?? key,
        showRequiredAsterisk: isRequired,
        textInputType: (isPhone || isDigitsOnly)
            ? TextInputType.phone
            : TextInputType.text,
        capitalization:
            isEmail ? TextCapitalization.none : TextCapitalization.words,
        isValidator: false,
        isEmail: isEmail,
        isDigits: isDigitsOnly,
        isPhoneNumber: isPhone,
        validator: validator,
      );
    }).toList(growable: false);
  }

  String? _validateEmail(
    String? value,
    String key,
    bool isRequired, {
    bool force = false,
  }) {
    if (!force && !_shouldValidateCurrentStep) return null;
    final text = (value ?? '').trim();
    final label = _labels[key] ?? key;
    if (text.isEmpty) {
      return isRequired ? '$label is required' : null;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'Enter a valid $label';
    }
    return null;
  }

  String? _validatePhone(
    String? value,
    String key,
    bool isRequired, {
    bool force = false,
  }) {
    if (!force && !_shouldValidateCurrentStep) return null;
    final text = (value ?? '').trim();
    final label = _labels[key] ?? key;
    if (text.isEmpty) {
      return isRequired ? '$label is required' : null;
    }
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return '$label must contain digits only';
    }
    if (text.length < 10 || text.length > 15) {
      return '$label must be between 10 and 15 digits';
    }
    return null;
  }

  String? _validateTextField(
    String? value,
    String key,
    bool isRequired,
    bool isDigitsOnly, {
    bool force = false,
  }) {
    if (!force && !_shouldValidateCurrentStep) return null;
    final text = (value ?? '').trim();
    final label = _labels[key] ?? key;

    if (text.isEmpty) {
      return isRequired ? '$label is required' : null;
    }

    if (isDigitsOnly && !RegExp(r'^\d+$').hasMatch(text)) {
      return '$label must contain digits only';
    }

    return null;
  }

  bool get _shouldValidateCurrentStep => _showStepValidation[_currentStep];

  List<String> get _currentStepFields {
    if (_currentStep == 0) return _stepOneFields;
    if (_currentStep == 1) return _stepTwoFields;
    if (_currentStep == 2) return _stepThreeFields;
    if (_currentStep == 3) return _stepFourFields;
    return _stepFiveFields;
  }

  String get _stepTitle {
    if (_currentStep == 0) return 'Basic Details';
    if (_currentStep == 1) return 'Address & Management';
    if (_currentStep == 2) return 'Bank & Documents';
    if (_currentStep == 3) return 'Contact Details';
    return 'Address Details';
  }

  Widget _buildHeaderCard(ThemeData themeData) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: themeData.canvasColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Production House Sign Up',
                style: TextStyle(
                  color: themeData.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _stepTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeData.canvasColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: themeData.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step ${_currentStep + 1}/5',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            onPressed: _onCloseTap,
            style: IconButton.styleFrom(
              backgroundColor:
                  themeData.scaffoldBackgroundColor.withValues(alpha: 0.35),
              foregroundColor: themeData.canvasColor,
            ),
            icon: const Icon(Icons.close, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData themeData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? themeData.primaryColor
                          : themeData.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 4) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter(ThemeData themeData, SignUpProvider signUpProvider) {
    final isLast = _currentStep == 4;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: signUpProvider.isSubmitting ? null : _onBack,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: themeData.primaryColor),
                  foregroundColor: themeData.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: signUpProvider.isSubmitting
                  ? null
                  : () => _onContinue(signUpProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeData.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: signUpProvider.isSubmitting && isLast
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isLast ? 'Sign Up' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadField(
      SignUpProvider provider, String key, ThemeData themeData) {
    final label = _labels[key] ?? key;
    final url = provider.controller(key).text.trim();
    final isUploading = provider.isUploadingField(key);
    final isUploaded = url.isNotEmpty;
    final isRequired = _requiredUploadFields.contains(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeData.canvasColor,
            ),
            children: [
              TextSpan(text: label),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isUploading ? null : () => provider.pickAndUploadImage(key),
          child: Container(
            height: isUploaded ? 120 : 84,
            decoration: BoxDecoration(
              color: isUploaded
                  ? Colors.green.withValues(alpha: 0.1)
                  : themeData.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUploaded
                    ? Colors.green.withValues(alpha: 0.45)
                    : themeData.primaryColor.withValues(alpha: 0.35),
                width: 1.6,
              ),
            ),
            child: Stack(
              children: [
                if (isUploaded) ...[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.description_outlined,
                              color: themeData.primaryColor,
                              size: 34,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                Center(
                  child: isUploading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: themeData.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Uploading...",
                              style: TextStyle(
                                color: themeData.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isUploaded
                                  ? Icons.check_circle_outline
                                  : Icons.cloud_upload_outlined,
                              color: isUploaded
                                  ? Colors.white
                                  : themeData.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                isUploaded
                                    ? "$label Uploaded"
                                    : "Upload $label",
                                style: TextStyle(
                                  color: isUploaded
                                      ? Colors.white
                                      : themeData.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onContinue(SignUpProvider signUpProvider) async {
    if (_currentStep < 4) {
      setState(() {
        _currentStep += 1;
      });
      return;
    }

    final invalidKey = _findFirstInvalidField(signUpProvider);
    if (invalidKey != null) {
      final invalidStep = _stepIndexForField(invalidKey) ?? 2;
      setState(() {
        _showStepValidation[invalidStep] = true;
        _currentStep = invalidStep;
      });

      if (_requiredUploadFields.contains(invalidKey)) {
        CustomToast.show(
          context,
          '${_labels[invalidKey] ?? invalidKey} is required',
          isSuccess: false,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _stepKeys[_currentStep].currentState?.validate();
        });
      }
      return;
    }

    final result = await signUpProvider.submitSignUp();
    if (!mounted) return;
    final success = result['success'] == true;

    CustomToast.show(
      context,
      result['message']?.toString() ?? (success ? 'Success' : 'Failed'),
      isSuccess: success,
    );

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  void _onBack() {
    setState(() {
      _currentStep -= 1;
    });
  }

  void _navigateToSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInPage()),
    );
  }

  void _onCloseTap() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _navigateToSignIn();
  }

  String? _findFirstInvalidField(SignUpProvider provider) {
    for (final key in _stepOneFields) {
      if (_validateFieldByKey(key, provider) != null) return key;
    }
    for (final key in _stepTwoFields) {
      if (_validateFieldByKey(key, provider) != null) return key;
    }
    for (final key in _stepThreeFields) {
      if (_validateFieldByKey(key, provider) != null) return key;
    }
    for (final key in _stepFourFields) {
      if (_validateFieldByKey(key, provider) != null) return key;
    }
    return null;
  }

  int? _stepIndexForField(String key) {
    if (_stepOneFields.contains(key)) return 0;
    if (_stepTwoFields.contains(key)) return 1;
    if (_stepThreeFields.contains(key)) return 2;
    if (_stepFourFields.contains(key)) return 3;
    return null;
  }

  String? _validateFieldByKey(String key, SignUpProvider provider) {
    final value = provider.controller(key).text.trim();

    if (_requiredUploadFields.contains(key)) {
      return value.isEmpty ? '${_labels[key] ?? key} is required' : null;
    }

    if (key == 'firmType' || key == 'country' || key == 'state') {
      return value.isEmpty ? '${_labels[key] ?? key} is required' : null;
    }

    if (key == 'password') {
      if (value.isEmpty) return 'Password is required';
      if (value.length < 6) return 'Password must be at least 6 characters';
      return null;
    }

    if (key == 'confirmPassword') {
      if (value.isEmpty) return 'Confirm Password is required';
      final pass = provider.controller('password').text.trim();
      if (value != pass) return 'Passwords do not match';
      return null;
    }

    final isRequired = _requiredFields.contains(key);
    if (_emailFields.contains(key)) {
      return _validateEmail(value, key, isRequired, force: true);
    }
    if (_contactPhoneFields.contains(key)) {
      return _validatePhone(value, key, isRequired, force: true);
    }

    final isDigitsOnly = key == 'pincode' || key == 'bankAccountNumber';
    return _validateTextField(
      value,
      key,
      isRequired,
      isDigitsOnly,
      force: true,
    );
  }

  Widget _buildFirmTypeField(SignUpProvider provider, ThemeData themeData) {
    final controller = provider.controller('firmType');
    final selectedValue = controller.text.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: themeData.canvasColor,
                ),
                children: const [
                  TextSpan(text: 'Firm Type'),
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: selectedValue.isEmpty ? null : selectedValue,
            items: _firmTypeOptions
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              controller.text = value ?? '';
            },
            validator: (value) {
              if (!_shouldValidateCurrentStep) return null;
              if ((value ?? '').trim().isEmpty) {
                return 'Firm Type is required';
              }
              return null;
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: themeData.inputDecorationTheme.fillColor ??
                  themeData.cardColor.withValues(alpha: 0.05),
              hintText: 'Select Firm Type',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: themeData.dividerColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: themeData.dividerColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: themeData.primaryColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.5,
                ),
              ),
            ),
            dropdownColor: themeData.cardColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDesignationField(SignUpProvider provider, ThemeData themeData) {
    final controller = provider.controller('designation');
    final selectedValue = controller.text.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Designation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: themeData.canvasColor,
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: selectedValue.isEmpty ? null : selectedValue,
            items: _designationOptions
                .map(
                  (designation) => DropdownMenuItem<String>(
                    value: designation,
                    child: Text(designation),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              controller.text = value ?? '';
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: themeData.inputDecorationTheme.fillColor ??
                  themeData.cardColor.withValues(alpha: 0.05),
              hintText: 'Select Designation',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: themeData.dividerColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: themeData.dividerColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: themeData.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
            dropdownColor: themeData.cardColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCountryField(SignUpProvider provider, ThemeData themeData) {
    return FormField<String>(
      validator: (selected) {
        if (!_shouldValidateCurrentStep) return null;
        if ((selected ?? '').trim().isEmpty) {
          return 'Country is required';
        }
        return null;
      },
      builder: (field) {
        final currentValue = provider.controller('country').text.trim();
        return _buildSearchableSelectField(
          label: 'Country',
          value: currentValue,
          hint: provider.isLoadingCountries
              ? 'Loading countries...'
              : 'Select Country',
          enabled: !provider.isLoadingCountries,
          themeData: themeData,
          errorText: field.errorText,
          onTap: () async {
            await provider.fetchCountriesIfNeeded();
            final selected = await _showSearchableSelectionDialog(
              title: 'Select Country',
              options: provider.countryOptions,
              initialValue: currentValue,
            );
            if (selected == null || selected == currentValue) return;
            await provider.selectCountryAndLoadStates(selected);
            field.didChange(selected);
          },
        );
      },
    );
  }

  Widget _buildStateField(SignUpProvider provider, ThemeData themeData) {
    final country = provider.controller('country').text.trim();
    final enabled = country.isNotEmpty;

    return FormField<String>(
      validator: (selected) {
        if (!_shouldValidateCurrentStep) return null;
        if ((selected ?? '').trim().isEmpty) {
          return 'State is required';
        }
        return null;
      },
      builder: (field) {
        final currentValue = provider.controller('state').text.trim();
        return _buildSearchableSelectField(
          label: 'State',
          value: currentValue,
          hint: !enabled
              ? 'Select Country First'
              : provider.isLoadingStates
                  ? 'Loading states...'
                  : 'Select State',
          enabled: enabled && !provider.isLoadingStates,
          themeData: themeData,
          errorText: field.errorText,
          onTap: () async {
            if (!enabled) return;
            if (provider.stateOptions.isEmpty && !provider.isLoadingStates) {
              await provider.fetchStatesByCountry(country);
            }
            final selected = await _showSearchableSelectionDialog(
              title: 'Select State',
              options: provider.stateOptions,
              initialValue: currentValue,
            );
            if (selected == null || selected == currentValue) return;
            provider.controller('state').text = selected;
            field.didChange(selected);
          },
        );
      },
    );
  }

  Widget _buildSearchableSelectField({
    required String label,
    required String value,
    required String hint,
    required bool enabled,
    required ThemeData themeData,
    required VoidCallback onTap,
    String? errorText,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: themeData.canvasColor,
                ),
                children: [
                  TextSpan(text: label),
                  if (label == 'Country' || label == 'State')
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: themeData.inputDecorationTheme.fillColor ??
                    themeData.cardColor.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeData.dividerColor,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeData.dividerColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeData.primaryColor,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 1.2,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeData.dividerColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                errorText: errorText,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.isEmpty ? hint : value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: value.isEmpty
                            ? themeData.hintColor
                            : themeData.canvasColor,
                        fontWeight:
                            value.isEmpty ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.search,
                    color: themeData.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: themeData.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showSearchableSelectionDialog({
    required String title,
    required List<String> options,
    required String initialValue,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final searchController = TextEditingController();
        String query = '';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = options
                .where((option) =>
                    option.toLowerCase().contains(query.toLowerCase()))
                .toList(growable: false);
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No results found'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (_, index) {
                                final item = filtered[index];
                                final isSelected = item == initialValue;
                                return ListTile(
                                  dense: true,
                                  title: Text(item),
                                  trailing: isSelected
                                      ? const Icon(Icons.check, size: 18)
                                      : null,
                                  onTap: () {
                                    Navigator.of(dialogContext).pop(item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

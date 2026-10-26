import 'package:flutter/material.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/widget/custom_textfield.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/app/core/utils/user_message.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/sharepreferences.dart';
import '../../../../provider/mediaHouseProvider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _personalFormKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  final TextEditingController _confirmBankAccountController =
      TextEditingController();

  bool _isSavingPersonal = false;
  bool _isSavingBank = false;
  bool _isSavingAddress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getData();
    });
  }

  Future<void> getData() async {
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();

    if (user?.id != null && mounted) {
      final provider = Provider.of<MediaHouseProvider>(context, listen: false);
      await provider.fetchMediaHouseByUserId(user!.id!);
      if (mounted) {
        _confirmBankAccountController.text =
            provider.bankAccountNumberController.text;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confirmBankAccountController.dispose();
    super.dispose();
  }

  String _maskAccountNumber(String? number) {
    if (number == null || number.trim().isEmpty) return "Not Added";
    final clean = number.trim();
    if (clean.length <= 4) return clean;
    final lastFour = clean.substring(clean.length - 4);
    return "•••• •••• $lastFour";
  }

  // --- Step 1: Save Personal Details ---
  Future<void> _savePersonalDetails() async {
    if (!_personalFormKey.currentState!.validate()) {
      CustomToast.show(
        context,
        'Please correct the errors in personal details.',
        isSuccess: false,
      );
      return;
    }

    final provider = Provider.of<MediaHouseProvider>(context, listen: false);
    if (provider.isUploading) {
      CustomToast.show(
        context,
        'Please wait for logo upload to finish.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSavingPersonal = true);
    final result = await provider.updatePersonalDetails();
    if (!mounted) return;
    setState(() => _isSavingPersonal = false);

    if (result['success'] == true) {
      CustomToast.show(
        context,
        UserMessage.resolve(
          apiMessage: result['message']?.toString(),
          fallbackMessage: 'Personal details updated successfully.',
        ),
        isSuccess: true,
      );
    } else {
      CustomToast.show(
        context,
        UserMessage.resolve(
          apiMessage: result['message']?.toString(),
          fallbackMessage: 'Unable to update personal details. Please try again.',
        ),
        isSuccess: false,
      );
    }
  }

  // --- Step 2: Save Bank Details ---
  Future<void> _saveBankDetails() async {
    if (!_bankFormKey.currentState!.validate()) {
      CustomToast.show(
        context,
        'Please correct the errors in bank details.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSavingBank = true);
    final provider = Provider.of<MediaHouseProvider>(context, listen: false);
    final result = await provider.updateBankDetails();
    if (!mounted) return;
    setState(() => _isSavingBank = false);

    if (result['success'] == true) {
      CustomToast.show(
        context,
        UserMessage.resolve(
          apiMessage: result['message']?.toString(),
          fallbackMessage: 'Bank details updated successfully.',
        ),
        isSuccess: true,
      );
    } else {
      CustomToast.show(
        context,
        UserMessage.resolve(
          apiMessage: result['message']?.toString(),
          fallbackMessage: 'Unable to update bank details. Please try again.',
        ),
        isSuccess: false,
      );
    }
  }

  // --- Step 3: Save Address Details ---
  Future<void> _saveAddressDetails() async {
    if (!_addressFormKey.currentState!.validate()) {
      CustomToast.show(
        context,
        'Please correct the errors in address details.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSavingAddress = true);
    final provider = Provider.of<MediaHouseProvider>(context, listen: false);
    final result = await provider.updateAddressDetails();
    if (!mounted) return;
    setState(() => _isSavingAddress = false);

    if (result['success'] == true) {
      CustomToast.show(
        context,
        UserMessage.resolve(
          apiMessage: result['message']?.toString(),
          fallbackMessage: 'Address details updated successfully.',
        ),
        isSuccess: true,
      );
    } else {
      CustomToast.show(
        context,
        UserMessage.resolve(
          apiMessage: result['message']?.toString(),
          fallbackMessage: 'Unable to update address details. Please try again.',
        ),
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final selectedThemeData = themeProvider.getTheme;
    final isMobile = ResponsiveWidget.isMobile(context);

    return Consumer<MediaHouseProvider>(
      builder: (context, provider, child) {
        final mediaHouse = provider.mediaHouse;

        if (mediaHouse.id == null) {
          return Scaffold(
            backgroundColor: selectedThemeData.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: selectedThemeData.primaryColor,
              title: const Text('Edit Production House Profile'),
            ),
            body: Center(
              child: CircularProgressIndicator(
                color: selectedThemeData.primaryColor,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: selectedThemeData.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: selectedThemeData.primaryColor,
            elevation: 1,
            title: Text(
              mediaHouse.mediaHouseName?.isNotEmpty == true
                  ? 'Edit ${mediaHouse.mediaHouseName}'
                  : 'Edit Production House Profile',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                color: selectedThemeData.primaryColor.withValues(alpha: 0.95),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.business_center_rounded, size: 20),
                      text: "1. Personal",
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_rounded, size: 20),
                      text: "2. Bank Details",
                    ),
                    Tab(
                      icon: Icon(Icons.location_on_rounded, size: 20),
                      text: "3. Address",
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 680,
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalStep(provider, selectedThemeData),
                  _buildBankStep(provider, selectedThemeData),
                  _buildAddressStep(provider, selectedThemeData),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // STEP 1: PERSONAL DETAILS
  // ==========================================
  Widget _buildPersonalStep(
      MediaHouseProvider provider, ThemeData selectedThemeData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo / Avatar Uploader
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedThemeData.primaryColor.withValues(alpha: 0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: provider.profileImageProvider,
                      child: provider.isUploading
                          ? const CircularProgressIndicator()
                          : provider.profileImageProvider == null
                              ? const Icon(
                                  Icons.business_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                )
                              : null,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Material(
                      color: selectedThemeData.primaryColor,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          provider.pickImage(context, "profile");
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Upload Official Studio / Media House Logo",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            CustomTextField(
              controller: provider.mediaHouseNameController,
              label: 'Production House Name',
              showRequiredAsterisk: true,
              hintText: 'e.g. Red Chillies Entertainment',
              isValidator: true,
              textInputType: TextInputType.name,
              prefixIcon: const Icon(Icons.business_rounded, size: 20),
            ),

            // Firm Type Dropdown
            _buildFirmTypeDropdown(provider, selectedThemeData),

            // Email
            CustomTextField(
              controller: provider.emailController,
              label: 'Official Email Address',
              showRequiredAsterisk: true,
              isEmail: true,
              isValidator: true,
              hintText: 'e.g. contact@mediahouse.com',
              textInputType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
            ),

            // Contact Number
            CustomTextField(
              controller: provider.mobileController,
              label: 'Contact Number (10 Digits)',
              showRequiredAsterisk: true,
              isPhoneNumber: true,
              isValidator: true,
              hintText: 'e.g. 9876543210',
              textInputType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            ),

            // Description
            CustomTextField(
              controller: provider.descriptionController,
              label: 'About / Studio Description',
              showRequiredAsterisk: false,
              isValidator: false,
              maxLine: 3,
              hintText: 'Enter a short summary of the production house...',
              textInputType: TextInputType.multiline,
              prefixIcon: const Icon(Icons.description_outlined, size: 20),
            ),

            const SizedBox(height: 28),

            // Save Personal Button
            _buildSaveButton(
              label: "Save Personal Details",
              isLoading: _isSavingPersonal,
              onPressed: _savePersonalDetails,
              theme: selectedThemeData,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFirmTypeDropdown(
      MediaHouseProvider provider, ThemeData selectedThemeData) {
    final firmTypes = [
      'Private Limited (Pvt Ltd)',
      'Sole Proprietorship',
      'Partnership Firm',
      'Limited Liability Partnership (LLP)',
      'Public Limited',
      'Individual / Freelance Studio',
    ];

    final currentVal = provider.firmTypeController.text;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: 'Firm / Business Type'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(currentVal),
            initialValue: firmTypes.contains(currentVal) ? currentVal : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: selectedThemeData.cardColor.withValues(alpha: 0.05),
              prefixIcon: const Icon(Icons.category_outlined, size: 20),
              hintText: 'Select Firm Type',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: selectedThemeData.dividerColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: selectedThemeData.dividerColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
            items: firmTypes
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  provider.firmTypeController.text = val;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: BANK DETAILS
  // ==========================================
  Widget _buildBankStep(
      MediaHouseProvider provider, ThemeData selectedThemeData) {
    final hasExistingAccount =
        provider.bankAccountNumberController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: _bankFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payout & Security Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Settlement & Payout Account",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Revenue share settlements and wallet withdrawals will be credited directly to this verified bank account.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Masked account preview banner
            if (hasExistingAccount)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          "Current Linked Account:",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _maskAccountNumber(
                          provider.bankAccountNumberController.text),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

            // Account Holder Name
            CustomTextField(
              controller: provider.accountHolderNameController,
              label: 'Account Holder Name',
              showRequiredAsterisk: true,
              hintText: 'As registered in bank records',
              isValidator: true,
              textInputType: TextInputType.name,
              prefixIcon: const Icon(Icons.person_outline, size: 20),
            ),

            // Bank Name
            CustomTextField(
              controller: provider.bankNameController,
              label: 'Bank Name',
              showRequiredAsterisk: true,
              hintText: 'e.g. HDFC Bank / State Bank of India / ICICI',
              isValidator: true,
              textInputType: TextInputType.text,
              prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
            ),

            // Account Number
            CustomTextField(
              controller: provider.bankAccountNumberController,
              label: 'Bank Account Number',
              showRequiredAsterisk: true,
              hintText: 'Enter 9-18 digit account number',
              isValidator: true,
              textInputType: TextInputType.number,
              prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bank account number is required';
                }
                if (!RegExp(r'^[0-9]{9,18}$').hasMatch(value.trim())) {
                  return 'Account number must be between 9 and 18 digits';
                }
                return null;
              },
            ),

            // Confirm Account Number
            CustomTextField(
              controller: _confirmBankAccountController,
              label: 'Confirm Bank Account Number',
              showRequiredAsterisk: true,
              hintText: 'Re-enter bank account number',
              isValidator: true,
              textInputType: TextInputType.number,
              prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please re-enter the account number';
                }
                if (value.trim() !=
                    provider.bankAccountNumberController.text.trim()) {
                  return 'Account numbers do not match';
                }
                return null;
              },
            ),

            // IFSC Code
            CustomTextField(
              controller: provider.bankIfscController,
              label: 'IFSC Code',
              showRequiredAsterisk: true,
              hintText: 'e.g. HDFC0001234',
              capitalization: TextCapitalization.characters,
              isValidator: true,
              textInputType: TextInputType.text,
              prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'IFSC code is required';
                }
                final formatted = value.trim().toUpperCase();
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(formatted)) {
                  return 'Enter a valid 11-digit IFSC code (e.g. HDFC0001234)';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Bank Proof Document Upload Card
            _buildBankProofCard(provider, selectedThemeData),

            const SizedBox(height: 28),

            // Save Bank Button
            _buildSaveButton(
              label: "Save Bank Details",
              isLoading: _isSavingBank,
              onPressed: _saveBankDetails,
              theme: selectedThemeData,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBankProofCard(
      MediaHouseProvider provider, ThemeData selectedThemeData) {
    final hasProof = provider.bankProofController.text.trim().isNotEmpty ||
        (provider.mediaHouse.bankProof != null &&
            provider.mediaHouse.bankProof!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selectedThemeData.cardColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedThemeData.dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: selectedThemeData.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Bank Proof Document",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (hasProof)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        "Uploaded",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Upload a cancelled cheque, bank passbook, or account statement for KYC verification.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              provider.pickImage(context, "Bank Proof");
            },
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(
              hasProof ? "Change Bank Proof" : "Upload Bank Proof",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3: ADDRESS DETAILS
  // ==========================================
  Widget _buildAddressStep(
      MediaHouseProvider provider, ThemeData selectedThemeData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Registered Office Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_rounded,
                    color: Colors.amber.shade900,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Official Registered Address & Studio Headquarters",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Building / Office
            CustomTextField(
              controller: provider.officeBuildingController,
              label: 'Office / Building / Premise Name',
              showRequiredAsterisk: true,
              hintText: 'e.g. Unit 402, Lotus Grandeur, Veera Desai Road',
              isValidator: true,
              textInputType: TextInputType.streetAddress,
              prefixIcon: const Icon(Icons.apartment_rounded, size: 20),
            ),

            // Area / Landmark
            CustomTextField(
              controller: provider.areaController,
              label: 'Area / Street / Landmark',
              showRequiredAsterisk: false,
              isValidator: false,
              hintText: 'e.g. Andheri West',
              textInputType: TextInputType.text,
              prefixIcon: const Icon(Icons.map_outlined, size: 20),
            ),

            // City & Taluka Row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: provider.cityController,
                    label: 'City',
                    showRequiredAsterisk: true,
                    hintText: 'e.g. Mumbai',
                    isValidator: true,
                    textInputType: TextInputType.text,
                    prefixIcon:
                        const Icon(Icons.location_city_outlined, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: provider.talukaController,
                    label: 'Taluka',
                    showRequiredAsterisk: false,
                    hintText: 'e.g. Andheri',
                    isValidator: false,
                    textInputType: TextInputType.text,
                  ),
                ),
              ],
            ),

            // District & State Row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: provider.districtController,
                    label: 'District',
                    showRequiredAsterisk: true,
                    hintText: 'e.g. Mumbai Suburban',
                    isValidator: true,
                    textInputType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: provider.stateController,
                    label: 'State',
                    showRequiredAsterisk: true,
                    hintText: 'e.g. Maharashtra',
                    isValidator: true,
                    textInputType: TextInputType.text,
                  ),
                ),
              ],
            ),

            // Country & Pincode Row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: provider.countryController,
                    label: 'Country',
                    showRequiredAsterisk: true,
                    hintText: 'India',
                    isValidator: true,
                    textInputType: TextInputType.text,
                    prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: provider.pincodeController,
                    label: 'PIN / Postal Code',
                    showRequiredAsterisk: true,
                    hintText: 'e.g. 400053',
                    isValidator: true,
                    isDigits: true,
                    textInputType: TextInputType.number,
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'PIN code is required';
                      }
                      if (!RegExp(r'^[0-9]{6}$').hasMatch(value.trim())) {
                        return 'Enter a valid 6-digit PIN code';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Save Address Button
            _buildSaveButton(
              label: "Save Address Details",
              isLoading: _isSavingAddress,
              onPressed: _saveAddressDetails,
              theme: selectedThemeData,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 2,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}

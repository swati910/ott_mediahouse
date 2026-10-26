import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import '../../data/models/response/image_upload_response.dart';

import '../core/constant/api_constant.dart';
import '../core/network/api_helper.dart';

class SignUpProvider extends ChangeNotifier {
  static const Set<String> _excludedSignupKeys = {
    'postCount',
    'totalViews',
    'totalReveneu',
    'confirmPassword',
  };

  final Map<String, TextEditingController> _controllers = {
    'accountHolderName': TextEditingController(),
    'address': TextEditingController(),
    'addressProof': TextEditingController(),
    'adharCard': TextEditingController(),
    'area': TextEditingController(),
    'bankAccountNumber': TextEditingController(),
    'bankIFSCNumber': TextEditingController(),
    'bankName': TextEditingController(),
    'bankProof': TextEditingController(),
    'ceoEmail': TextEditingController(),
    'ceoMobile': TextEditingController(),
    'ceoName': TextEditingController(),
    'city': TextEditingController(),
    'contactNumber': TextEditingController(),
    'country': TextEditingController(),
    'directorEmail': TextEditingController(),
    'directorMobile': TextEditingController(),
    'directorName': TextEditingController(),
    'designation': TextEditingController(),
    'discription': TextEditingController(),
    'district': TextEditingController(),
    'dob': TextEditingController(),
    'email': TextEditingController(),
    'emailId': TextEditingController(),
    'firmType': TextEditingController(),
    'gstCertificates': TextEditingController(),
    'identityProof': TextEditingController(),
    'logo': TextEditingController(),
    'mediaHouseName': TextEditingController(),
    'mobileNumber': TextEditingController(),
    'officeBuilding': TextEditingController(),
    'panCard': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'pincode': TextEditingController(),
    'postCount': TextEditingController(),
    'profileImage': TextEditingController(),
    'refferedBy': TextEditingController(),
    'registrationCertificate': TextEditingController(),
    'shopAct': TextEditingController(),
    'state': TextEditingController(),
    'taluka': TextEditingController(),
    'totalReveneu': TextEditingController(),
    'totalViews': TextEditingController(),
  };

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;
  final Map<String, bool> _uploadingByKey = {};
  final List<String> _countryOptions = [];
  List<String> get countryOptions => _countryOptions;
  final List<String> _stateOptions = [];
  List<String> get stateOptions => _stateOptions;
  bool _isLoadingCountries = false;
  bool get isLoadingCountries => _isLoadingCountries;
  bool _isLoadingStates = false;
  bool get isLoadingStates => _isLoadingStates;

  bool isUploadingField(String key) => _uploadingByKey[key] ?? false;

  TextEditingController controller(String key) {
    return _controllers[key]!;
  }

  List<String> get allKeys => _controllers.keys.toList(growable: false);

  Map<String, String> _buildPayload() {
    final Map<String, String> payload = {};
    for (final entry in _controllers.entries) {
      if (_excludedSignupKeys.contains(entry.key)) {
        continue;
      }
      payload[entry.key] = entry.value.text.trim();
    }
    payload['postCount'] = '0';
    payload['totalReveneu'] = '0';
    payload['totalViews'] = '0';
    return payload;
  }

  Future<void> fetchCountriesIfNeeded() async {
    if (_countryOptions.isNotEmpty || _isLoadingCountries) return;
    await fetchCountries();
  }

  Future<void> fetchCountries() async {
    _isLoadingCountries = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/positions'),
      );
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>? ?? const []);
      _countryOptions
        ..clear()
        ..addAll(
          data
              .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((e) => e.trim().isNotEmpty),
        );
      _countryOptions
          .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (_) {
      // silent fallback
    } finally {
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatesByCountry(String country) async {
    _isLoadingStates = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': country}),
      );
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final states = (data?['states'] as List<dynamic>? ?? const []);
      _stateOptions
        ..clear()
        ..addAll(
          states
              .map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((e) => e.trim().isNotEmpty),
        );
      _stateOptions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (_) {
      _stateOptions.clear();
    } finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  Future<void> selectCountryAndLoadStates(String country) async {
    _controllers['country']?.text = country.trim();
    _controllers['state']?.clear();
    _stateOptions.clear();
    notifyListeners();
    if (country.trim().isEmpty) return;
    await fetchStatesByCountry(country.trim());
  }

  Future<Map<String, dynamic>> submitSignUp() async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final apiHelper = ApiHelper();
      final payload = _buildPayload();
      final response =
          await apiHelper.postApiWithBody(ApiConstant.saveMediaHouse, payload);
      debugPrint(ApiConstant.saveMediaHouse);
      debugPrint(payload.toString());
      debugPrint(response.body);

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final bool apiSuccess = (decoded['success'] == true) ||
          (decoded['isSuccess'] == true) ||
          (response.statusCode == 200 || response.statusCode == 201);

      return {
        'success': apiSuccess,
        'message': decoded['message'] ??
            (apiSuccess
                ? 'Production house registered successfully'
                : 'Signup failed'),
        'data': decoded,
      };
    } catch (error) {
      return {
        'success': false,
        'message': 'Unable to sign up. Please try again.',
      };
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> pickAndUploadImage(String key) async {
    if (!_controllers.containsKey(key)) return;

    if (kIsWeb) {
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((_) async {
        if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
          await _uploadWebFile(key, uploadInput.files!.first);
        }
      });
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    await _uploadMobileFile(key, io.File(pickedFile.path));
  }

  Future<void> _uploadWebFile(String key, html.File file) async {
    _uploadingByKey[key] = true;
    notifyListeners();
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConstant.uploadImg));
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        reader.result as List<int>,
        filename: file.name,
      );
      request.files.add(multipartFile);

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final parsed = ImageUploadResponse.fromJson(
            jsonDecode(responseBody) as Map<String, dynamic>);
        _controllers[key]!.text = parsed.data?.fileUrl ?? '';
      }
    } catch (_) {
      _controllers[key]!.text = '';
    } finally {
      _uploadingByKey[key] = false;
      notifyListeners();
    }
  }

  Future<void> _uploadMobileFile(String key, io.File file) async {
    _uploadingByKey[key] = true;
    notifyListeners();
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConstant.uploadImg));
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final parsed = ImageUploadResponse.fromJson(
            jsonDecode(responseBody) as Map<String, dynamic>);
        _controllers[key]!.text = parsed.data?.fileUrl ?? '';
      }
    } catch (_) {
      _controllers[key]!.text = '';
    } finally {
      _uploadingByKey[key] = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

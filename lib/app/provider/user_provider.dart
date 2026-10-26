import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_house/data/models/response/addUserResponse.dart';
import 'package:media_house/data/models/response/updateUserResponse.dart';
import 'dart:convert';
import '../../data/models/response/getAllUserResponse.dart';
import '../../data/models/response/getMediaHouseResponse.dart';
import '../../domain/entities/mediaHouse.dart';
import '../../domain/entities/user.dart';
import '../core/constant/api_constant.dart';
import '../core/constant/prefrense_constant.dart';
import '../core/auth/auth_service.dart';
import '../core/network/api_helper.dart';
import '../core/utils/sharepreferences.dart';

import '../widget/show_toast.dart';

class UserProvider extends ChangeNotifier {
  UserProvider() : super() {
    searchController.addListener(filterUsers);
  }

  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController countryController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController districtController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController officeBuildingController = TextEditingController();
  TextEditingController registrationDateController = TextEditingController();
  TextEditingController profileController = TextEditingController();
  TextEditingController pinCodeDateController = TextEditingController();
  TextEditingController refferedByController = TextEditingController();
  TextEditingController roleController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String? selectedGender;
  List<String> selectedLanguages = [];
  File? image;

  bool isEnbale = false;

  void filterUsers() {
    _filteredUsers = _users.where((user) {
      final query = searchController.text.toLowerCase();
      return (user.firstName ?? '').toLowerCase().contains(query) ||
          (user.lastName ?? '').toLowerCase().contains(query) ||
          (user.mobileNumber ?? '').toLowerCase().contains(query) ||
          (user.emailId ?? '').toLowerCase().contains(query) ||
          (user.location?.state ?? '').toLowerCase().contains(query) ||
          (user.location?.district ?? '').toLowerCase().contains(query) ||
          (user.location?.taluka ?? '').toLowerCase().contains(query);
    }).toList();
    notifyListeners();
  }

  setValue(MediaHouse? mediaHouse) async {
    print("SEtData${mediaHouse!.mediaHouseName}");
    firstNameController.text = mediaHouse.mediaHouseName ?? "";
    mobileController.text = mediaHouse.contactNumber ?? "";
    emailController.text = mediaHouse.email ?? "";
    descriptionController.text = mediaHouse.discription ?? "";
    profileController.text = mediaHouse.logo ?? "";
    notifyListeners();
  }

  checkValidation() {
    if (firstNameController.text.isNotEmpty &&
        emailController.text.isNotEmpty &&
        mobileController.text.isNotEmpty &&
        passwordController.text.isNotEmpty &&
        confirmPasswordController.text.isNotEmpty &&
        dobController.text.isNotEmpty) {
      isEnbale = true;
    } else {
      isEnbale = false;
    }
    notifyListeners();
  }

  List<User> _users = [];
  List<User> _filteredUsers = [];
  User user = User();

  List<User> get users => _users;
  List<User> get filteredUsers => _filteredUsers;
  User get userObj => user;

  Future<Map<String, Object>> updateMediaHouse() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    String apiUrl = ApiConstant.editMediaHouseById;
    ApiHelper apiHelper = ApiHelper();
    Map<String, dynamic> data = {
      "emailId": emailController.text,
      "firstName": firstNameController.text,
      "id": user!.id,
      "lastName": lastNameController.text,
      "mobileNumber": mobileController.text
    };

    try {
      var response = await apiHelper.putApiWithBody(apiUrl, data);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        UpdateUserResponse updateUserResponse =
            UpdateUserResponse.fromJson(responseBody);

        debugPrint("data: ${updateUserResponse.message}");
        if (updateUserResponse.success == true) {
          if (updateUserResponse.data != null) {
            user = updateUserResponse.data!;
            print("before SEtData ${user.firstName}");
            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser,
                jsonEncode(updateUserResponse.data!));
            print(
                "after SEtData ${await localSharePreferences.getString(SharedPreferencesConstant.currentUser)}");
            notifyListeners();
            return {
              'success': true,
              'message': updateUserResponse.message ?? ""
            };
          } else {
            debugPrint("Empty data: ${updateUserResponse.message}");
            return {
              'success': false,
              'message': updateUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          debugPrint("Error: ${updateUserResponse.message}");
          return {
            'success': false,
            'message': updateUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 404) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);
        debugPrint("Error: ${addUserResponse.message}");
        return {
          'success': false,
          'message': addUserResponse.message ?? 'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to update the user. Please try again.'
      };
    }
  }

  // Delete a user
  Future<void> deleteUser(int id) async {
    String apiUrl = ApiConstant.deleteUserById(id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.deleteApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse deleteUserResponse =
            AddUserResponse.fromJson(responseBody);
        if (deleteUserResponse.success == true) {
          notifyListeners();
        } else {
          debugPrint("Error: ${deleteUserResponse.message}");
        }
      } else {
        throw Exception(
            'Failed to delete user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while delete user.');
    }
  }

  Future<void> getUserById(int id) async {
    String apiUrl = ApiConstant.getUserById(id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);
        if (addUserResponse.success == true) {
          if (addUserResponse.data != null &&
              addUserResponse.data!.user != null) {
            user = addUserResponse.data!.user!;

            notifyListeners();
          } else {
            debugPrint("empty data: ${addUserResponse.message}");
          }
        } else {
          debugPrint("Error: ${addUserResponse.message}");
        }
      } else {
        throw Exception(
            'Failed to delete user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while delete user.');
    }
  }

  setImage(XFile pickedFile) {
    image = null;
    image = File(pickedFile.path);
    notifyListeners();
  }

  setDate(DateTime pickedDate) {
    dobController.text = pickedDate.toLocal().toString().split(' ')[0];
    notifyListeners();
  }

  MediaHouse _mediaHouse = MediaHouse();
  MediaHouse get mediaHouse => _mediaHouse;

  /*login(String email, String password,context) async {
    String apiUrl = ApiConstant.login;
    Map<String,dynamic> data = {
      "emailId": email,
      "password": password
    };
    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.postApiWithBody(apiUrl,data);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse = AddUserResponse.fromJson(responseBody);

        debugPrint("data: ${addUserResponse.message}");
        if (addUserResponse.success == true) {
          if (addUserResponse.data != null) {
            if(addUserResponse.data?.user?.role?.any((role) => role == "MediaHouse") ?? false){
              user = addUserResponse.data!.user!;
              print("before SEtData ${user.firstName}");
              LocalSharePreferences localSharePreferences=LocalSharePreferences();
              localSharePreferences.setBool(SharedPreferencesConstant.isLogin, true);
              print("check  SEtLogin ${await localSharePreferences.getBool(SharedPreferencesConstant.isLogin)}");
              localSharePreferences.setString(SharedPreferencesConstant.currentUser, jsonEncode(addUserResponse.data!.user));
              print("after SEtData ${ await localSharePreferences.getString(SharedPreferencesConstant.currentUser)}");
              await fetchMediaHouseByUserId(addUserResponse.data!.user!.id!,context);

              notifyListeners();
              return {'success': true, 'message': 'logged in successfully'};
            }else{
              CustomToast.show("You are not media house user..try with media house user credentials...", isSuccess: false);
              notifyListeners();
              return {'success': false, 'message': "You are not media house user..try with media house user credentials..."};
            }
          } else {
            debugPrint("Empty data: ${addUserResponse.message}");
            return {'success': false, 'message': addUserResponse.message ?? 'No data returned'};
          }
        } else {
          debugPrint("Error: ${addUserResponse.message}");
          return {'success': false, 'message': addUserResponse.message ?? 'Error in response'};
        }
      } else if(response.statusCode == 401 || response.statusCode == 500){
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse = AddUserResponse.fromJson(responseBody);
        debugPrint("Error: ${addUserResponse.message}");
        return {'success': false, 'message': addUserResponse.message ?? 'Error in response'};
      }else{
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {'success': false, 'message': 'Unable to sign in. Please try again.'};
    }
  }*/

  Future<void> fetchMediaHouseByUserId(int userId, context) async {
    String apiUrl = ApiConstant.getMediaHouseByUserId(userId);
    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.getApi(apiUrl);
      debugPrint("Production house by id response::: ${response.body}");

      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetMediaHouse getAllMediaHouseResponse =
            GetMediaHouse.fromJson(responseBody);
        if (getAllMediaHouseResponse.success == true) {
          if (getAllMediaHouseResponse.data!.mediaHouse != null) {
            _mediaHouse = getAllMediaHouseResponse.data!.mediaHouse!;
            setValue(_mediaHouse);
            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            await localSharePreferences.setString(
                SharedPreferencesConstant.currentMediaHouse,
                jsonEncode(_mediaHouse.toJson()));
            notifyListeners();
          } else {
            debugPrint("No data found: ${getAllMediaHouseResponse.message}");
          }
        } else {
          CustomToast.show(context, getAllMediaHouseResponse.message ?? "",
              isSuccess: getAllMediaHouseResponse.success!);
        }
      } else {
        throw Exception(
            'Failed to fetch Production House. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching Production House.');
    }
  }

  // Fetch all users
  Future<void> fetchUsers() async {
    String apiUrl = ApiConstant.getAllUser;
    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetAllUserResponse getAllUserResponse =
            GetAllUserResponse.fromJson(responseBody);
        if (getAllUserResponse.success == true) {
          if (getAllUserResponse.data != null) {
            _users = getAllUserResponse.data!.user!;
            _filteredUsers = _users;
            notifyListeners();
          } else {
            debugPrint("empty list: ${getAllUserResponse.message}");
          }
        } else {
          debugPrint("Error: ${getAllUserResponse.message}");
        }
      } else {
        throw Exception(
            'Failed to fetch users. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching users.');
    }
  }

  Future loginWithMobile(String mobile, BuildContext context) async {
    String apiUrl = ApiConstant.login(mobile);

    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.postApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);
        debugPrint("data: ${addUserResponse.message}");
        if (addUserResponse.success == true) {
          return {'success': true, 'message': addUserResponse.message ?? ''};
        } else {
          debugPrint("Error: ${addUserResponse.message}");
          return {
            'success': false,
            'message': addUserResponse.message ?? 'Error in response'
          };
        }
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to sign in. Please try again.'
      };
    }
  }

  Future loginWithCredentials(
      String username, String password, BuildContext context) async {
    if (password.trim().isEmpty) {
      return {'success': false, 'message': 'Password is required'};
    }

    final apiHelper = ApiHelper();
    final payload = {
      'username': username,
      'password': password,
    };

    try {
      debugPrint('OTP Requested');
      final response = await apiHelper.postApiWithoutBodyAndToken(
        ApiConstant.twoStepLogin,
        payload,
      );
      final responseBody = json.decode(response.body);
      final addUserResponse = AddUserResponse.fromJson(responseBody);

      if (response.statusCode == 200 && addUserResponse.success == true) {
        return {
          'success': true,
          'message': addUserResponse.message ?? 'OTP sent successfully',
          'data': responseBody['data'],
        };
      }

      debugPrint('Login Failed: ${addUserResponse.message}');
      return {
        'success': false,
        'message': addUserResponse.message ?? 'Unable to send OTP'
      };
    } catch (error) {
      debugPrint('Login Failed: $error');
      return {
        'success': false,
        'message': 'Unable to request an OTP. Please check your connection and try again.'
      };
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
      String mobile, String otp, BuildContext context) async {
    final apiHelper = ApiHelper();

    try {
      final payload = await AuthService.buildDevicePayload(
        username: mobile,
        otp: otp,
      );
      final response = await apiHelper.postApiWithoutBodyAndToken(
        ApiConstant.twoStepVerifyOtp,
        payload,
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);

        debugPrint("OTP Verified: ${addUserResponse.message}");
        if (addUserResponse.success == true) {
          if (addUserResponse.data != null) {
            final loginUser = addUserResponse.data!.user;
            final accessToken = addUserResponse.data!.token ??
                addUserResponse.data!.accessToken;

            if (loginUser != null &&
                AuthService.hasProductionHouseAccess(loginUser)) {
              if (accessToken == null || accessToken.trim().isEmpty) {
                debugPrint('Login Failed: JWT missing in verify OTP response');
                return {
                  'success': false,
                  'message': 'Login failed: access token missing'
                };
              }

              user = addUserResponse.data!.user!;
              await AuthService.saveLoginSession(
                accessToken: accessToken,
                refreshToken: addUserResponse.data!.refreshToken,
                sessionId: addUserResponse.data!.sessionId,
                user: user,
                permissions: addUserResponse.data!.permissions,
              );
              await fetchMediaHouseByUserId(
                  addUserResponse.data!.user!.id!, context);

              notifyListeners();
              debugPrint('Login Success');
              return {'success': true, 'message': 'logged in successfully'};
            } else {
              debugPrint('Login Failed: Unauthorized role');
              CustomToast.show(context,
                  "You are not Production house user..try with Production house user credentials...",
                  isSuccess: false);
              notifyListeners();
              return {
                'success': false,
                'message':
                    "You are not Production house user..try with Production house user credentials..."
              };
            }
          } else {
            debugPrint("Login Failed: ${addUserResponse.message}");
            return {
              'success': false,
              'message': addUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          debugPrint("Login Failed: ${addUserResponse.message}");
          return {
            'success': false,
            'message': addUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 500) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);
        debugPrint("Login Failed: ${addUserResponse.message}");
        return {
          'success': false,
          'message': addUserResponse.message ?? 'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Login Failed: $error");
      return {
        'success': false,
        'message': 'Unable to verify the OTP. Please try again.'
      };
    }
  }
}

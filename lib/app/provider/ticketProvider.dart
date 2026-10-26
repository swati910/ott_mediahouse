import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/request/raiseTicketRequest.dart';
import '../../data/models/response/getRaisedTicketListResponse.dart';
import '../../data/models/response/image_upload_response.dart';
import '../../data/models/response/raiseTicketResponse.dart';
import '../../data/models/response/ticket_search_filter_response.dart';
import '../../domain/entities/user.dart';
import '../core/constant/api_constant.dart';
import '../core/network/api_helper.dart';
import '../core/utils/sharepreferences.dart';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;

class TicketProvider extends ChangeNotifier {
  List<TicketRaised> _ticketList = [];
  List<TicketRaised> get tickets => _ticketList;

  TextEditingController topicController = TextEditingController();
  TextEditingController feedbackController = TextEditingController();
  TextEditingController descController = TextEditingController();
  String imgUrl = '';

  String _selectedPriority = 'HIGH';
  String get selectedPriority => _selectedPriority;
  void setPriority(String value) {
    _selectedPriority = value;
    notifyListeners();
  }

  String _selectedCategory = 'SETTLEMENT';
  String get selectedCategory => _selectedCategory;
  void setCategory(String value) {
    _selectedCategory = value;
    notifyListeners();
  }

  bool _isSearchingTickets = false;
  bool get isSearchingTickets => _isSearchingTickets;

  Future<Map<String, Object>> raiseTicket() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    DateTime now = DateTime.now().toUtc(); // Get current time in UTC
    String formattedDate = now.toIso8601String();
    String apiUrl = ApiConstant.raiseTicket;
    RaiseTicketRequest raiseTicketRequest = RaiseTicketRequest();
    raiseTicketRequest.userId = user!.id!;
    raiseTicketRequest.description = descController.text;
    raiseTicketRequest.isResolved = false;
    raiseTicketRequest.mobileNumber =
        user.mobileNumber; //client or admin mobile number
    raiseTicketRequest.email = user.emailId; //client or admin email
    raiseTicketRequest.image = imgUrl;
    raiseTicketRequest.date = formattedDate;
    raiseTicketRequest.feedback = feedbackController.text;
    raiseTicketRequest.tickedId = 0;
    raiseTicketRequest.topic = topicController.text;
    raiseTicketRequest.title = topicController.text;
    raiseTicketRequest.priority = _selectedPriority;
    raiseTicketRequest.category = _selectedCategory;

    ApiHelper apiHelper = ApiHelper();

    try {
      var response =
          await apiHelper.postApiWithBody(apiUrl, raiseTicketRequest.toJson());
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        RaiseTicketResponse raiseTicketResponse =
            RaiseTicketResponse.fromJson(responseBody);
        if (raiseTicketResponse.data != null) {
          if (raiseTicketResponse.data?.ticketRaised != null) {
            _ticketList.add(raiseTicketResponse.data!.ticketRaised!);

            imgUrl = '';
            _uploadedImageUrl = '';
            topicController.clear();
            descController.clear();
            notifyListeners();
            return {
              'success': true,
              'message':
                  raiseTicketResponse.message ?? 'Ticket raised successfully'
            };
          } else {
            debugPrint("Empty data: ${raiseTicketResponse.message}");
            return {
              'success': false,
              'message': raiseTicketResponse.message ?? 'No data returned'
            };
          }
        } else {
          debugPrint("Error: ${raiseTicketResponse.message}");
          return {
            'success': false,
            'message': raiseTicketResponse.message ?? 'Error in response'
          };
        }
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to create the support ticket. Please try again.'
      };
    }
  }

  Future<Map<String, Object>> updateRaiseTicket(
      TicketRaised ticketRaised, bool isResolved, String feedback) async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    DateTime now = DateTime.now().toUtc(); // Get current time in UTC
    String formattedDate = now.toIso8601String();
    String apiUrl = ApiConstant.updateTicket(ticketRaised.tickedId);
    RaiseTicketRequest raiseTicketRequest = RaiseTicketRequest();
    raiseTicketRequest.userId = ticketRaised.userId!;
    raiseTicketRequest.description = ticketRaised.description;
    raiseTicketRequest.isResolved = isResolved;
    raiseTicketRequest.mobileNumber =
        ticketRaised.mobileNumber;
    raiseTicketRequest.email = ticketRaised.email;
    raiseTicketRequest.image = ticketRaised.image;
    raiseTicketRequest.date = formattedDate;
    raiseTicketRequest.feedback = feedback;
    raiseTicketRequest.tickedId = ticketRaised.tickedId;
    raiseTicketRequest.topic = ticketRaised.topic;

    ApiHelper apiHelper = ApiHelper();

    try {
      var response =
          await apiHelper.putApiWithBody(apiUrl, raiseTicketRequest.toJson());
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        RaiseTicketResponse raiseTicketResponse =
            RaiseTicketResponse.fromJson(responseBody);
        if (raiseTicketResponse.data != null) {
          if (raiseTicketResponse.data?.ticketRaised != null) {
            getRaisedTicketByUserId();
            imgUrl = '';
            _uploadedImageUrl = '';
            topicController.clear();
            notifyListeners();
            return {
              'success': true,
              'message':
                  raiseTicketResponse.message ?? 'Ticket updated successfully'
            };
          } else {
            debugPrint("Empty data: ${raiseTicketResponse.message}");
            return {
              'success': false,
              'message': raiseTicketResponse.message ?? 'No data returned'
            };
          }
        } else {
          debugPrint("Error: ${raiseTicketResponse.message}");
          return {
            'success': false,
            'message': raiseTicketResponse.message ?? 'Error in response'
          };
        }
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to update the support ticket. Please try again.'
      };
    }
  }

  Future<Map<String, Object>> getRaisedTicketByUserId() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    String apiUrl = ApiConstant.getRaisedTicketByUserId(user!.id);

    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetRaiseTicketListResponse getRaiseTicketListResponse =
            GetRaiseTicketListResponse.fromJson(responseBody);
        if (getRaiseTicketListResponse.data != null) {
          if (getRaiseTicketListResponse.data!.ticketRaised != null) {
            _ticketList.clear();
            _ticketList.addAll(getRaiseTicketListResponse.data!.ticketRaised!);
            notifyListeners();
            return {
              'success': true,
              'message': getRaiseTicketListResponse.message!
            };
          } else {
            debugPrint("Empty data: ${getRaiseTicketListResponse.message}");
            return {
              'success': false,
              'message':
                  getRaiseTicketListResponse.message ?? 'No data returned'
            };
          }
        } else {
          debugPrint("Error: ${getRaiseTicketListResponse.message}");
          return {
            'success': false,
            'message': getRaiseTicketListResponse.message ?? 'Error in response'
          };
        }
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to load support tickets. Please try again.'
      };
    }
  }

  Future<Map<String, Object>> getAllRaisedTicketByFlag(bool isResolved) async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    String apiUrl = ApiConstant.getRaisedTicketByFlag(isResolved, user!.id);

    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetRaiseTicketListResponse getRaiseTicketListResponse =
            GetRaiseTicketListResponse.fromJson(responseBody);
        if (getRaiseTicketListResponse.data != null) {
          if (getRaiseTicketListResponse.data!.ticketRaised != null) {
            _ticketList.clear();
            _ticketList.addAll(getRaiseTicketListResponse.data!.ticketRaised!);
            notifyListeners();
            return {
              'success': true,
              'message': getRaiseTicketListResponse.message!
            };
          } else {
            debugPrint("Empty data: ${getRaiseTicketListResponse.message}");
            return {
              'success': false,
              'message':
                  getRaiseTicketListResponse.message ?? 'No data returned'
            };
          }
        } else {
          debugPrint("Error: ${getRaiseTicketListResponse.message}");
          return {
            'success': false,
            'message': getRaiseTicketListResponse.message ?? 'Error in response'
          };
        }
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to load support tickets. Please try again.'
      };
    }
  }

  // ==========================================
  // TICKET SEARCH AND FILTER (v2 API)
  // ==========================================
  Future<void> searchAndFilterTickets({
    String? keyword,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    _isSearchingTickets = true;
    notifyListeners();

    final apiUrl = ApiConstant.searchAndFilterTickets(
      role: 'MEDIA_HOUSE',
      keyword: keyword,
      status: status,
      startDate: startDate,
      endDate: endDate,
    );

    final apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic body = json.decode(response.body);
        final filterResponse = TicketSearchFilterResponse.fromJson(body);
        if (filterResponse.data.isNotEmpty || filterResponse.success == true) {
          _ticketList.clear();
          _ticketList.addAll(filterResponse.data);
        } else {
          _ticketList.clear();
        }
      } else {
        await getRaisedTicketByUserId();
      }
    } catch (e) {
      debugPrint("Error searching tickets: $e");
      await getRaisedTicketByUserId();
    } finally {
      _isSearchingTickets = false;
      notifyListeners();
    }
  }

  io.File? _imageFile;
  html.File? _webFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  bool isLoading = false;
  var error;

  io.File? get imageFile => _imageFile;
  html.File? get webFile => _webFile;
  String? get uploadedImageUrl => _uploadedImageUrl;
  bool get isUploading => _isUploading;

  Future<void> pickImage() async {
    if (kIsWeb) {
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((event) async {
        if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
          _webFile = uploadInput.files!.first;
          await uploadImage();
          notifyListeners();
        }
      });
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        _imageFile = io.File(pickedFile.path);
        if (kIsWeb && _webFile != null) {
          await uploadImage();
        }
        notifyListeners();
      }
    }
  }

  Future<void> uploadImage() async {
    if ((!kIsWeb && _imageFile == null) || (kIsWeb && _webFile == null)) {
      return;
    }

    final url = Uri.parse(ApiConstant.uploadImg);
    _isUploading = true;
    notifyListeners();

    try {
      if (kIsWeb && _webFile != null) {
        final request = http.MultipartRequest('POST', url);
        final reader = html.FileReader();
        reader.readAsArrayBuffer(_webFile!);
        await reader.onLoad.first;

        final byteData = reader.result as List<int>;
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          byteData,
          filename: _webFile!.name,
        );

        request.files.add(multipartFile);
        final response = await request.send();

        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          ImageUploadResponse imageUploadResponse =
              ImageUploadResponse.fromJson(jsonDecode(responseBody));
          _uploadedImageUrl = imageUploadResponse.data!.fileUrl;
          imgUrl = _uploadedImageUrl!;
          notifyListeners();
        }
      } else if (!kIsWeb && _imageFile != null) {
        final request = http.MultipartRequest('POST', url);
        request.files.add(await http.MultipartFile.fromPath(
          'profilePicture',
          _imageFile!.path,
        ));
        final response = await request.send();

        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          _uploadedImageUrl = jsonDecode(responseBody);
          imgUrl = _uploadedImageUrl!;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error uploading image: $e');
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  deleteQuery(TicketRaised ticketList) async {
    String apiUrl = ApiConstant.deleteTicket(ticketList.tickedId!);
    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.deleteApi(apiUrl);
      if (response.statusCode == 200) {
        getRaisedTicketByUserId();
        return {'success': true, 'message': "Ticket Deleted Successfully"};
      } else {
        return {'success': false, 'message': "Something went wrong!!!"};
      }
    } catch (error) {
      debugPrint("Error: $error");
      return {
        'success': false,
        'message': 'Unable to delete the support ticket. Please try again.'
      };
    }
  }

  toggleResolvedStatus(TicketRaised ticketRaised, bool newStatus) {
    updateRaiseTicket(ticketRaised, newStatus, ticketRaised.feedback!);
  }

  void removeImage() {
    _uploadedImageUrl = '';
    notifyListeners();
  }
}

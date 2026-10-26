import 'package:media_house/domain/entities/location.dart';
import 'package:media_house/domain/entities/user.dart';

class MediaHouse {
  int? id;
  String? mediaHouseName;
  String? address;
  String? contactNumber;
  String? email;
  String? registrationCertificate;
  String? gstCertificates;
  String? adharCard;
  dynamic shopAct;
  String? panCard;
  int? createdDate;
  dynamic updatedDate;
  dynamic profileImage;
  dynamic otp;
  dynamic password;
  String? status;
  dynamic joinDate;
  dynamic logo;
  dynamic totalReveneu;
  dynamic postCount;
  dynamic discription;
  String? bankAccountNumber;
  String? bankIfscNumber;
  String? bankProof;
  String? identityProof;
  String? addressProof;
  dynamic bankName;
  dynamic accountHolderName;
  dynamic firmType;
  String? designation;
  String? gstNumber;
  String? authorizedPerson;
  String? companyVerificationStatus;
  dynamic companyVerificationSubmittedAt;
  dynamic companyVerificationReviewedAt;
  String? companyVerificationRejectionRemarks;
  String? companyVerificationAdminRemark;
  int? directorId;
  int? ceoId;
  User? user;
  User? director;
  User? ceo;
  Location? location;
  dynamic totalViews;
  dynamic mediaHouseRevenue;
  dynamic totalRevenue;
  dynamic adminRevenue;
  bool? active;

  MediaHouse({
    this.id,
    this.mediaHouseName,
    this.address,
    this.contactNumber,
    this.email,
    this.registrationCertificate,
    this.gstCertificates,
    this.adharCard,
    this.shopAct,
    this.panCard,
    this.createdDate,
    this.updatedDate,
    this.profileImage,
    this.otp,
    this.password,
    this.status,
    this.joinDate,
    this.logo,
    this.totalReveneu,
    this.postCount,
    this.discription,
    this.bankAccountNumber,
    this.bankIfscNumber,
    this.bankProof,
    this.identityProof,
    this.addressProof,
    this.bankName,
    this.accountHolderName,
    this.firmType,
    this.designation,
    this.gstNumber,
    this.authorizedPerson,
    this.companyVerificationStatus,
    this.companyVerificationSubmittedAt,
    this.companyVerificationReviewedAt,
    this.companyVerificationRejectionRemarks,
    this.companyVerificationAdminRemark,
    this.directorId,
    this.ceoId,
    this.user,
    this.director,
    this.ceo,
    this.location,
    this.totalViews,
    this.mediaHouseRevenue,
    this.totalRevenue,
    this.adminRevenue,
    this.active,
  });

  factory MediaHouse.fromJson(Map<String, dynamic> json) => MediaHouse(
        id: _readNullableInt(json["id"]),
        mediaHouseName: json["mediaHouseName"]?.toString(),
        address: json["address"]?.toString(),
        contactNumber: json["contactNumber"]?.toString(),
        email: json["email"]?.toString(),
        registrationCertificate: json["registrationCertificate"]?.toString(),
        gstCertificates: json["gstCertificates"]?.toString(),
        adharCard: json["adharCard"]?.toString(),
        shopAct: json["shopAct"],
        panCard: json["panCard"]?.toString(),
        createdDate: _readNullableInt(json["createdDate"]),
        updatedDate: json["updatedDate"],
        profileImage: json["profileImage"],
        otp: json["otp"],
        password: json["password"],
        status: json["status"]?.toString(),
        joinDate: json["joinDate"],
        logo: json["logo"],
        totalReveneu: json["totalReveneu"],
        postCount: json["postCount"],
        discription: json["discription"],
        bankAccountNumber: json["bankAccountNumber"]?.toString(),
        bankIfscNumber: json["bankIFSCNumber"]?.toString() ?? json["bankIfscNumber"]?.toString(),
        bankProof: json["bankProof"]?.toString(),
        identityProof: json["identityProof"]?.toString(),
        addressProof: json["addressProof"]?.toString(),
        bankName: json["bankName"],
        accountHolderName: json["accountHolderName"],
        firmType: json["firmType"],
        designation: json["designation"]?.toString(),
        gstNumber: json["gstNumber"]?.toString(),
        authorizedPerson: json["authorizedPerson"]?.toString(),
        companyVerificationStatus: json["companyVerificationStatus"]?.toString(),
        companyVerificationSubmittedAt: json["companyVerificationSubmittedAt"],
        companyVerificationReviewedAt: json["companyVerificationReviewedAt"],
        companyVerificationRejectionRemarks:
            json["companyVerificationRejectionRemarks"]?.toString(),
        companyVerificationAdminRemark:
            json["companyVerificationAdminRemark"]?.toString(),
        directorId: _readNullableInt(json["directorId"]),
        ceoId: _readNullableInt(json["ceoId"]),
        user: json["user"] == null ? null : User.fromJson(json["user"]),
        director:
            json["director"] == null ? null : User.fromJson(json["director"]),
        ceo: json["ceo"] == null ? null : User.fromJson(json["ceo"]),
        location: json["location"] == null
            ? null
            : Location.fromJson(json["location"]),
        totalViews: json["totalViews"],
        mediaHouseRevenue: json["mediaHouseRevenue"],
        totalRevenue: json["totalRevenue"],
        adminRevenue: json["AdminRevnue"] ?? json["adminRevenue"],
        active: json["active"] == true,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "mediaHouseName": mediaHouseName,
        "address": address,
        "contactNumber": contactNumber,
        "email": email,
        "registrationCertificate": registrationCertificate,
        "gstCertificates": gstCertificates,
        "adharCard": adharCard,
        "shopAct": shopAct,
        "panCard": panCard,
        "createdDate": createdDate,
        "updatedDate": updatedDate,
        "profileImage": profileImage,
        "otp": otp,
        "password": password,
        "status": status,
        "joinDate": joinDate,
        "logo": logo,
        "totalReveneu": totalReveneu,
        "postCount": postCount,
        "discription": discription,
        "bankAccountNumber": bankAccountNumber,
        "bankIFSCNumber": bankIfscNumber,
        "bankProof": bankProof,
        "identityProof": identityProof,
        "addressProof": addressProof,
        "bankName": bankName,
        "accountHolderName": accountHolderName,
        "firmType": firmType,
        "designation": designation,
        "gstNumber": gstNumber,
        "authorizedPerson": authorizedPerson,
        "companyVerificationStatus": companyVerificationStatus,
        "companyVerificationSubmittedAt": companyVerificationSubmittedAt,
        "companyVerificationReviewedAt": companyVerificationReviewedAt,
        "companyVerificationRejectionRemarks":
            companyVerificationRejectionRemarks,
        "companyVerificationAdminRemark": companyVerificationAdminRemark,
        "directorId": directorId,
        "ceoId": ceoId,
        "user": user?.toJson(),
        "director": director?.toJson(),
        "ceo": ceo?.toJson(),
        "location": location?.toJson(),
        "totalViews": totalViews,
        "mediaHouseRevenue": mediaHouseRevenue,
        "totalRevenue": totalRevenue,
        "AdminRevnue": adminRevenue,
        "active": active,
      };
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

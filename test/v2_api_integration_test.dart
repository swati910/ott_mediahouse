import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/data/models/response/getMediaHouseResponse.dart';
import 'package:media_house/data/models/response/mediaHouseDashboardCount.dart';
import 'package:media_house/data/models/response/movie_transaction.dart';

void main() {
  group('V2 API Models & JSON Integration Tests', () {
    test('1. GetMediaHouseById (v2) parses exact backend response with capital MediaHouse key', () {
      const rawJson = '''{
    "message": "Production House fetched successfully",
    "data": {
        "MediaHouse": {
            "id": 5,
            "mediaHouseName": "Kalyani Production",
            "address": "",
            "contactNumber": "8459968089",
            "email": "kalyaniproduction75@gmail.com",
            "registrationCertificate": "",
            "gstCertificates": "",
            "adharCard": "https://filmytell-document.s3.ap-south-1.amazonaws.com/documents/kalyani-aadhdhar-card-1788006127915.jpeg",
            "shopAct": null,
            "panCard": "https://filmytell-document.s3.ap-south-1.amazonaws.com/documents/kalyani-pan-card-1788006132832.jpeg",
            "createdDate": 1788006265000,
            "updatedDate": null,
            "profileImage": null,
            "otp": null,
            "password": "\$2a\$10\$.dqb.95jQnwHrn4PR9nRVOiwD9V1E5D4CL7x33H.V6Ad5kCxDM/je",
            "status": "APPROVED",
            "refferedBy": null,
            "role": "ROLE_MEDIA_HOUSE",
            "location": null,
            "discription": "Great production house",
            "firmType": null,
            "designation": null,
            "gstNumber": null,
            "bankProof": null,
            "identityProof": null,
            "addressProof": null,
            "authorizedPerson": null,
            "companyVerificationStatus": null,
            "companyVerificationSubmittedAt": null,
            "companyVerificationReviewedAt": null,
            "companyVerificationRejectionRemarks": null,
            "companyVerificationAdminRemark": null,
            "accountHolderName": null,
            "bankName": null,
            "bankAccountNumber": null,
            "bankIfscNumber": null,
            "directorId": null,
            "ceoId": null,
            "mediaHouseRevenue": 0.0,
            "totalRevenue": 0.0,
            "adminRevenue": 0.0,
            "logo": null
        }
    }
}''';

      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final response = GetMediaHouse.fromJson(decoded);

      expect(response.message, 'Production House fetched successfully');
      expect(response.data, isNotNull);
      expect(response.data!.mediaHouse, isNotNull);

      final mh = response.data!.mediaHouse!;
      expect(mh.id, 5);
      expect(mh.mediaHouseName, 'Kalyani Production');
      expect(mh.contactNumber, '8459968089');
      expect(mh.email, 'kalyaniproduction75@gmail.com');
      expect(mh.status, 'APPROVED');
      expect(mh.adharCard, contains('kalyani-aadhdhar-card'));
      expect(mh.panCard, contains('kalyani-pan-card'));
      expect(mh.discription, 'Great production house');
    });

    test('2. GetMediaHouseDashboardCount (v2) parses exact backend response with spaces and numeric fields', () {
      const rawJson = '''{
    "data": {
        "Production House Name": "Kalyani Production",
        "Purchase Count": 1,
        "Customer Payment": 118.0,
        "GST Charges": 18.0,
        "Base Amount After GST": 100.0,
        "Payment Gateway Fees": 2.0,
        "Net Revenue": 98.0,
        "Platform Revenue": 47.6,
        "Production House Revenue": 50.4,
        "Live Content": 2,
        "Upcoming Content": 0,
        "Pending Content": 0,
        "Total Views": 0,
        "Wallet Amount": 0.0
    }
}''';

      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final count = MediaHouseDashboardCount.fromJson(decoded);

      expect(count.data, isNotNull);
      final d = count.data!;
      expect(d.productionHouseName, 'Kalyani Production');
      expect(d.purchaseCount, 1);
      expect(d.customerPayment, 118.0);
      expect(d.gstCharges, 18.0);
      expect(d.baseAmountAfterGST, 100.0);
      expect(d.paymentGatewayFees, 2.0);
      expect(d.netRevenue, 98.0);
      expect(d.platformRevenue, 47.6);
      expect(d.productionHouseRevenue, 50.4);
      expect(d.liveContent, 2);
      expect(d.upcomingContent, 0);
      expect(d.pendingContent, 0);
      expect(d.totalViews, 0);
      expect(d.walletAmount, 0.0);

      // Verify backward-compatible getters
      expect(d.approvedContent, 2);
      expect(d.mediaHouseNetRevenue, 50.4);
      expect(d.mediaHouseGrossRevenue, 118.0);
    });

    test('3. MovieTransactions (v2) parses exact backend array and item fields', () {
      const rawJson = '''{
    "message": "Transactions fetched successfully",
    "data": [
        {
            "transactionId": "TXN14",
            "movieId": 6,
            "movieTitle": "Kalki 2898 AD",
            "dateFrom": 1772303400000,
            "dateTo": 1774981800000,
            "status": "COMPLETED",
            "customerPayment": 118.0,
            "baseAmount": 100.0,
            "gstAmount": 18.0,
            "gatewayFee": 2.0,
            "netRevenue": 98.0,
            "mediaHouseRevenueShare": 50.4,
            "adminRevenueShare": 47.6
        }
    ]
}''';

      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final response = MovieTransactionResponse.fromJson(decoded);

      expect(response.message, 'Transactions fetched successfully');
      expect(response.data.length, 1);

      final txn = response.data.first;
      expect(txn.transactionId, 'TXN14');
      expect(txn.movieId, 6);
      expect(txn.movieTitle, 'Kalki 2898 AD');
      expect(txn.status, 'COMPLETED');
      expect(txn.customerPayment, 118.0);
      expect(txn.baseAmount, 100.0);
      expect(txn.gstAmount, 18.0);
      expect(txn.gatewayFee, 2.0);
      expect(txn.netRevenue, 98.0);
      expect(txn.mediaHouseRevenueShare, 50.4);
      expect(txn.adminRevenueShare, 47.6);
      expect(txn.fromDateTime, isNotNull);
      expect(txn.toDateTime, isNotNull);
    });

    test('4. ApiConstant endpoint URLs are formatted accurately', () {
      expect(
        ApiConstant.getMediaHouseById(5),
        '${ApiConstant.baseUrl}api/v2/mediaHouse/getMediaHouseById/5',
      );
      expect(
        ApiConstant.getMediaHouseDashboardCount(5),
        '${ApiConstant.baseUrl}api/v2/mediaHouse/getMediaHouseDashboardCountForAdmin/5',
      );
      expect(
        ApiConstant.movieTransactionsByMediaHouse(5),
        '${ApiConstant.baseUrl}api/v2/user/movie-transactions-by-media-house/5',
      );
    });
  });
}

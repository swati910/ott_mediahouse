import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/domain/entities/location.dart';
import 'package:media_house/domain/entities/mediaHouse.dart';
import 'package:media_house/app/provider/mediaHouseProvider.dart';

void main() {
  group('Edit Profile Flow & MediaHouseProvider Tests', () {
    late MediaHouseProvider provider;

    setUp(() {
      provider = MediaHouseProvider();
    });

    test('setValue sets all personal, bank, and address controllers correctly', () {
      final mediaHouse = MediaHouse(
        id: 101,
        mediaHouseName: "Star Studios",
        firmType: "Private Limited (Pvt Ltd)",
        email: "producer@starstudios.com",
        contactNumber: "9876543210",
        discription: "Premier film production studio",
        logo: "https://example.com/logo.png",
        accountHolderName: "Star Studios Pvt Ltd",
        bankName: "HDFC Bank",
        bankAccountNumber: "50100234567890",
        bankIfscNumber: "HDFC0001234",
        bankProof: "https://example.com/cheque.png",
        location: Location(
          id: 55,
          officeBuilding: "Unit 402, Lotus Grandeur",
          area: "Veera Desai Road",
          city: "Mumbai",
          taluka: "Andheri",
          district: "Mumbai Suburban",
          state: "Maharashtra",
          country: "India",
          pincode: "400053",
        ),
      );

      provider.setValue(mediaHouse);

      // Verify Personal Details
      expect(provider.mediaHouseNameController.text, "Star Studios");
      expect(provider.firmTypeController.text, "Private Limited (Pvt Ltd)");
      expect(provider.emailController.text, "producer@starstudios.com");
      expect(provider.mobileController.text, "9876543210");
      expect(provider.descriptionController.text, "Premier film production studio");
      expect(provider.profileController.text, "https://example.com/logo.png");

      // Verify Bank Details
      expect(provider.accountHolderNameController.text, "Star Studios Pvt Ltd");
      expect(provider.bankNameController.text, "HDFC Bank");
      expect(provider.bankAccountNumberController.text, "50100234567890");
      expect(provider.bankIfscController.text, "HDFC0001234");
      expect(provider.bankProofController.text, "https://example.com/cheque.png");

      // Verify Address & Location Details
      expect(provider.officeBuildingController.text, "Unit 402, Lotus Grandeur");
      expect(provider.areaController.text, "Veera Desai Road");
      expect(provider.cityController.text, "Mumbai");
      expect(provider.talukaController.text, "Andheri");
      expect(provider.districtController.text, "Mumbai Suburban");
      expect(provider.stateController.text, "Maharashtra");
      expect(provider.countryController.text, "India");
      expect(provider.pincodeController.text, "400053");
    });

    test('IFSC Code regex validation pattern check', () {
      final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

      expect(ifscRegex.hasMatch('HDFC0001234'), isTrue);
      expect(ifscRegex.hasMatch('SBIN0000300'), isTrue);
      expect(ifscRegex.hasMatch('ICIC0000001'), isTrue);
      expect(ifscRegex.hasMatch('UTIB0001234'), isTrue);

      // Invalid IFSCs
      expect(ifscRegex.hasMatch('HDFC1001234'), isFalse, reason: '5th character must be 0');
      expect(ifscRegex.hasMatch('HDF0001234'), isFalse, reason: 'Too short');
      expect(ifscRegex.hasMatch('HDFC00012345'), isFalse, reason: 'Too long');
      expect(ifscRegex.hasMatch('hdfc0001234'), isFalse, reason: 'Must be uppercase');
    });

    test('PIN code regex validation pattern check', () {
      final pincodeRegex = RegExp(r'^[0-9]{6}$');

      expect(pincodeRegex.hasMatch('400053'), isTrue);
      expect(pincodeRegex.hasMatch('110001'), isTrue);
      expect(pincodeRegex.hasMatch('560001'), isTrue);

      // Invalid PIN codes
      expect(pincodeRegex.hasMatch('40005'), isFalse, reason: '5 digits');
      expect(pincodeRegex.hasMatch('4000531'), isFalse, reason: '7 digits');
      expect(pincodeRegex.hasMatch('40005A'), isFalse, reason: 'Alphanumeric');
    });

    test('Bank account number regex validation pattern check', () {
      final accountRegex = RegExp(r'^[0-9]{9,18}$');

      expect(accountRegex.hasMatch('123456789'), isTrue);
      expect(accountRegex.hasMatch('50100234567890'), isTrue);
      expect(accountRegex.hasMatch('123456789012345678'), isTrue);

      // Invalid Account Numbers
      expect(accountRegex.hasMatch('12345678'), isFalse, reason: 'Less than 9 digits');
      expect(accountRegex.hasMatch('1234567890123456789'), isFalse, reason: 'More than 18 digits');
      expect(accountRegex.hasMatch('5010023456ABCD'), isFalse, reason: 'Contains alphabets');
    });
  });
}

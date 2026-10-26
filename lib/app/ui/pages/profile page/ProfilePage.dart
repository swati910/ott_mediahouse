import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_house/app/core/constant/app_constant.dart';
import 'package:media_house/app/provider/mediaHouseProvider.dart';
import 'package:media_house/app/ui/pages/help%20support%20page/helpDesk.dart';
import 'package:media_house/app/ui/pages/profile%20page/component/EditProfilePage.dart';
import 'package:media_house/app/ui/pages/profile%20page/component/about_filmytell.dart';
import 'package:media_house/app/ui/pages/sign%20in%20page/SignInPage.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/sharepreferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<MediaHouseProvider>(
      builder: (context, provider, _) {
        final mediaHouse = provider.mediaHouse;

        if (isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bool isApproved =
            (mediaHouse.status ?? 'PENDING').toUpperCase() == 'APPROVED';

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                  child: Column(
                    children: [
                      _buildHeroBoard(theme, mediaHouse, isApproved),
                      const SizedBox(height: 14),
                      _buildPinterestBody(context, provider),
                      const SizedBox(height: 14),
                      _buildActionPanel(context),
                      const SizedBox(height: 24),
                      Text(
                        "Version · ${AppConstant.appVersion}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "© Filmytell - All Rights Reserved.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroBoard(ThemeData theme, dynamic mediaHouse, bool isApproved) {
    final logo = _display(mediaHouse.logo);
    final views = _display(mediaHouse.totalViews);
    final revenue = _display(mediaHouse.totalReveneu);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.94),
            theme.primaryColor.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          final profileBlock = Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: compact ? 34 : 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    backgroundImage: logo != '-' ? NetworkImage(logo) : null,
                    child: logo == '-'
                        ? const Icon(Icons.business,
                            color: Colors.white, size: 30)
                        : null,
                  ),
                  if (isApproved)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(Icons.verified_rounded,
                          color: Colors.white, size: 18),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _display(mediaHouse.mediaHouseName),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 24 : 30,
                        fontWeight: FontWeight.w800,
                        height: 1.06,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _display(mediaHouse.email),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      _display(mediaHouse.user?.mobileNumber ??
                          mediaHouse.contactNumber),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          );

          final stats = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("Views", views),
              _pill("Revenue", revenue),
              _pill("Status", isApproved ? "Approved" : "Pending"),
            ],
          );

          final editButton = ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profileBlock,
                const SizedBox(height: 12),
                stats,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: editButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: profileBlock),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(alignment: Alignment.centerRight, child: stats),
                    const SizedBox(height: 10),
                    editButton,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPinterestBody(
      BuildContext context, MediaHouseProvider provider) {
    final media = provider.mediaHouse;
    final location = media.location;
    final user = media.user;

    final infoTiles = [
      _infoCard(
        context,
        title: 'Basic Details',
        accent: const Color(0xFF2A9D8F),
        fields: [
          _field('Production House Name', media.mediaHouseName),
          _field('Firm Type', media.firmType),
          _field('Description', media.discription),
          _field('Email', media.email),
          _field('Alternate Email', user?.emailId),
          _field('Contact Number', media.contactNumber),
          _field('Mobile Number', user?.mobileNumber),
          _field('Referred By', user?.refferedBy),
        ],
      ),
      _infoCard(
        context,
        title: 'Address Details',
        accent: const Color(0xFFE9C46A),
        fields: [
          _field('Country', location?.country),
          _field('State', location?.state),
          _field('District', location?.district),
          _field('Taluka', location?.taluka),
          _field('City', location?.city),
          _field('Area', location?.area),
          _field('Pincode', location?.pincode),
          _field('Office Building', location?.officeBuilding),
        ],
      ),
      _infoCard(
        context,
        title: 'CEO & Director Details',
        accent: const Color(0xFFE76F51),
        fields: [
          _field('CEO Name', media.ceo?.firstName),
          _field('CEO Email', media.ceo?.emailId),
          _field('CEO Mobile', media.ceo?.mobileNumber),
          _field('Director Name', media.director?.firstName),
          _field('Director Email', media.director?.emailId),
          _field('Director Mobile', media.director?.mobileNumber),
        ],
      ),
      _infoCard(
        context,
        title: 'Bank & Business',
        accent: const Color(0xFF4361EE),
        fields: [
          _field('Account Holder Name', media.accountHolderName),
          _field('Bank Name', media.bankName),
          _field('Bank Account Number', media.bankAccountNumber),
          _field('Bank IFSC Number', media.bankIfscNumber),
        ],
      ),
    ];

    final uploaded = <MapEntry<String, String>>[
      MapEntry('Registration Certificate',
          _resolveUploadedFile(provider, 'Registration Certificate')),
      MapEntry('Aadhaar Card', _resolveUploadedFile(provider, 'Aadhaar Card')),
      MapEntry('PAN Card', _resolveUploadedFile(provider, 'PAN Card')),
      MapEntry(
          'GST Certificate', _resolveUploadedFile(provider, 'GST Certificate')),
      MapEntry('Shop Act', _resolveUploadedFile(provider, 'Shop Act')),
      MapEntry('Bank Proof', _resolveUploadedFile(provider, 'Bank Proof')),
      MapEntry(
          'Identity Proof', _resolveUploadedFile(provider, 'Identity Proof')),
      MapEntry(
          'Address Proof', _resolveUploadedFile(provider, 'Address Proof')),
    ].where((e) => e.value != '-').toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep profile details and document previews stacked throughout the
        // tablet range. The split layout needs desktop width to avoid narrow,
        // clipped document cards.
        final compact = constraints.maxWidth < 1100;

        if (compact) {
          return Column(
            children: [
              ...infoTiles.map((tile) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: tile,
                  )),
              _masonrySection(context, uploaded),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  infoTiles[0],
                  const SizedBox(height: 10),
                  infoTiles[1],
                  const SizedBox(height: 10),
                  infoTiles[2],
                  const SizedBox(height: 10),
                  infoTiles[3],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _masonrySection(context, uploaded),
            ),
          ],
        );
      },
    );
  }

  Widget _masonrySection(
      BuildContext context, List<MapEntry<String, String>> items) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.collections_bookmark_rounded,
                    color: theme.primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Uploaded Visuals',
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'No uploaded files available.',
                style:
                    TextStyle(color: theme.canvasColor.withValues(alpha: 0.6)),
              )
            else
              LayoutBuilder(
                builder: (_, c) {
                  final col = c.maxWidth > 440 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: col,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return _masonryTile(context, item.key, item.value, index);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _masonryTile(
      BuildContext context, String label, String url, int index) {
    final theme = Theme.of(context);
    final aligns = [
      Alignment.topCenter,
      Alignment.center,
      Alignment.bottomCenter,
      Alignment.topRight,
      Alignment.bottomLeft,
    ];

    return Material(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showImagePreview(context, label, url),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: aligns[index % aligns.length],
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.cardColor.withValues(alpha: 0.5),
                      alignment: Alignment.center,
                      child: Icon(Icons.insert_drive_file_outlined,
                          color: theme.primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.canvasColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required Color accent,
    required List<MapEntry<String, String>> fields,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...fields.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.key,
                        style: TextStyle(
                          color: theme.canvasColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        item.value,
                        style: TextStyle(
                          color: theme.canvasColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return Column(
      children: [
        _profileCard(
          context,
          title: "Feedback & Information",
          children: [
            ProfileOption(
              icon: Icons.support_agent_sharp,
              title: "Help & Support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpDeskPage()),
              ),
            ),
            ProfileOption(
              icon: Icons.file_copy,
              title: "Terms, Policies and Liscenses",
              onTap: () {
                _openPrivacyPolicy();
              },
            ),
            ProfileOption(
              icon: Icons.info,
              title: "About Filmytell",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutFilmytellScreen(),
                  ),
                );
              },
            ),
            ProfileOption(
              icon: Icons.star,
              title: "Rate Us",
              onTap: () {
                _openRateUs();
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            child: ProfileOption(
              icon: Icons.logout,
              title: "Logout",
              isDestructive: true,
              onTap: () => _showLogoutDialog(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      await launchUrl(
        Uri.parse(AppConstant.privacyPolicy),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Unable to open privacy policy page right now.',
        isSuccess: false,
      );
    }
  }

  Future<void> _openTerms() async {
    try {
      await launchUrl(
        Uri.parse(AppConstant.playStoreLink),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Unable to open terms and condition right now.',
        isSuccess: false,
      );
    }
  }

  Future<void> _openRateUs() async {
    try {
      bool launched = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final marketUri = Uri.parse('market://details?id=com.filmytell.ott');
        launched = await launchUrl(
          marketUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched) {
        launched = await launchUrl(
          Uri.parse(AppConstant.playStoreLink),
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched && mounted) {
        CustomToast.show(
          context,
          'Unable to open rating page right now.',
          isSuccess: false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Unable to open rating page right now.',
        isSuccess: false,
      );
    }
  }

  Widget _pill(String label, String value) {
    return Builder(builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    });
  }

  MapEntry<String, String> _field(String label, dynamic value) {
    return MapEntry(label, _display(value));
  }

  String _display(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '-';
    return text;
  }

  String _resolveUploadedFile(MediaHouseProvider provider, String label) {
    final fromMap = _display(provider.uploadedDocuments[label]?['file']);
    if (fromMap != '-') return fromMap;

    final media = provider.mediaHouse;
    switch (label) {
      case 'Logo':
        return _display(media.logo);
      case 'Profile Image':
        return _display(media.profileImage);
      case 'Registration Certificate':
        return _display(media.registrationCertificate);
      case 'Aadhaar Card':
        return _display(media.adharCard);
      case 'PAN Card':
        return _display(media.panCard);
      case 'GST Certificate':
        return _display(media.gstCertificates);
      case 'Shop Act':
        return _display(media.shopAct);
      case 'Bank Proof':
        return _display(media.bankProof);
      case 'Identity Proof':
        return _display(media.identityProof);
      case 'Address Proof':
        return _display(media.addressProof);
      default:
        return '-';
    }
  }

  void _showImagePreview(BuildContext context, String label, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.broken_image, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final parentContext = context;

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Logout"),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await LocalSharePreferences().logOut();

              if (!parentContext.mounted) return;

              Navigator.pushReplacement(
                parentContext,
                MaterialPageRoute(builder: (_) => const SignInPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _profileCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const ProfileOption({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Icon(icon, color: theme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDestructive ? theme.primaryColor : theme.canvasColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}

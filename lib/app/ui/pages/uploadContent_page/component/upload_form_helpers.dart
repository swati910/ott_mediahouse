import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_house/app/widget/custom_textfield.dart';

import '../../../../provider/videoProvider.dart';
import 'multiselect_dialog.dart';

class UploadFormHelpers {
  static DateTime _nextFriday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final daysUntilFriday = (DateTime.friday - normalized.weekday + 7) % 7;
    return normalized.add(Duration(days: daysUntilFriday));
  }

  static Widget buildSectionCard(
      String title, List<Widget> children, ThemeData themeData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeData.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeData.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeData.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  static Widget buildModernDateField(
      BuildContext context,
      VideoProvider provider,
      ThemeData themeData,
      Function(DateTime) onDateSelected,
      {String label = "Release Date"}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: themeData.canvasColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeData.dividerColor),
          ),
      child: TextFormField(
        cursorColor: themeData.primaryColor,
        controller: provider.releaseDateController,
        readOnly: true,
        onTap: () async {
          final firstDate = DateTime(1900);
          final lastDate = DateTime(9900);
          final selectedDate =
              DateTime.tryParse(provider.releaseDateController.text.trim());
          final initialDate =
              selectedDate != null && selectedDate.weekday == DateTime.friday
                  ? selectedDate
                  : _nextFriday(DateTime.now());

          DateTime? pickedDate = await showDatePicker(
            context: context, // Use the passed context
            initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            selectableDayPredicate: (day) => day.weekday == DateTime.friday,
          );
          if (pickedDate != null) {
            onDateSelected(pickedDate);
          }
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: themeData.cardColor,
          hintText: "Select Release Date",
          hintStyle: TextStyle(
            color: themeData.canvasColor.withOpacity(0.6),
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeData.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today,
              color: themeData.primaryColor,
              size: 20,
            ),
          ),
        ),
      ),
    ),
  ],
);
}

  static Widget buildModernDropdownField(
    String label,
    List<String> items,
    BuildContext context,
    VideoProvider provider,
    ThemeData themeData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: themeData.canvasColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeData.dividerColor),
          ),
          child: DropdownButtonFormField<String>(
            value: () {
              String? val;
              if (label == "Age Rating") {
                val = provider.ageRatingController.text.trim();
              } else if (label == "Type") {
                val = provider.typeController.text.trim();
              } else if (label == "Rental Duration") {
                val = provider.rentalDurationController.text.trim();
              }
              if (val != null && val.isEmpty) val = null;
              if (val != null && !items.contains(val)) {
                final match = items.firstWhere(
                  (item) =>
                      item.toLowerCase().contains(val!.toLowerCase()) ||
                      val.toLowerCase().contains(item.toLowerCase()),
                  orElse: () => '',
                );
                val = match.isNotEmpty ? match : null;
              }
              return val;
            }(),
            hint: Text(
              "Select $label",
              style: TextStyle(
                color: themeData.canvasColor.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: themeData.canvasColor,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              provider.dropDownSelection(value!, label);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: themeData.cardColor,
            ),
            dropdownColor: themeData.cardColor,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: themeData.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildModernMultiSelectDropdownField(
      String label, List<String> items, BuildContext context, ThemeData theme,
      {Map<String, List<String>> groupedItems = const {}}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.canvasColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final provider = context.read<VideoProvider>();
            final usesLanguageApi =
                label == "Languages" || label == "Audio Languages";
            if (usesLanguageApi && provider.languageOptions.isEmpty) {
              await provider.fetchGroupedLanguages();
              if (!context.mounted) return;
            }
            final dialogGroupedItems = usesLanguageApi
                ? provider.groupedLanguageOptions
                : groupedItems;
            final dialogItems = dialogGroupedItems.isEmpty
                ? items
                : dialogGroupedItems.values.expand((value) => value).toList();
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return MultiSelectDialog(
                  label: label,
                  items: dialogItems,
                  groupedItems: dialogGroupedItems,
                  theme: theme,
                );
              },
            );
          },
          child: Consumer<VideoProvider>(
            builder: (context, provider, child) {
              return Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                  color: theme.cardColor,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        UploadFormHelpers.getDisplayText(label, provider),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.canvasColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.primaryColor,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget builtModernMultiValueTextField(
      String label, ThemeData selectedThemeData) {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selectedThemeData.canvasColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selectedThemeData.dividerColor),
              ),
              child: TextField(
                controller: label == "Cast"
                    ? provider.castController
                    : provider.directorController,
                decoration: InputDecoration(
                  hintText: "Enter $label names separated by commas",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: selectedThemeData.cardColor,
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selectedThemeData.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.add, color: Colors.white, size: 20),
                      onPressed: () {
                        provider.addValuesToList(label);
                      },
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.contains(',')) {
                    provider.addValuesToList(label);
                  }
                },
                onSubmitted: (_) => provider.addValuesToList(label),
              ),
            ),
            const SizedBox(height: 12),
            // Display chips
            if (label == "Cast" && provider.castList.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: provider.castList
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              selectedThemeData.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                selectedThemeData.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                color: selectedThemeData.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                provider.castList.remove(item);
                                provider.notifyListeners();
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: selectedThemeData.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (label == "Director" && provider.directorList.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: provider.directorList
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              selectedThemeData.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                selectedThemeData.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                color: selectedThemeData.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                provider.directorList.remove(item);
                                provider.notifyListeners();
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: selectedThemeData.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  static Widget buildModernToggleRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    ThemeData themeData,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeData.dividerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeData.canvasColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeData.canvasColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: themeData.primaryColor,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  static String getDisplayText(String label, VideoProvider provider) {
    if (label == "Genres") {
      return provider.selectedGeners.isNotEmpty
          ? provider.selectedGeners.join(', ')
          : 'Select $label';
    } else if (label == "Audio Formats") {
      return provider.selectedAudioFormat.isNotEmpty
          ? provider.selectedAudioFormat.join(', ')
          : 'Select $label';
    } else if (label == "Subtitle Languages") {
      return provider.selectedSubLanguages.isNotEmpty
          ? provider.selectedSubLanguages.join(', ')
          : 'Select $label';
    } else {
      return provider.selectedLanguages.isNotEmpty
          ? provider.selectedLanguages
              .map((language) => language.language ?? "")
              .where((language) => language.isNotEmpty)
              .join(', ')
          : 'Select $label';
    }
  }
}

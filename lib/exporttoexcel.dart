import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'providers/societyprovider.dart';
import 'models/userprofile.dart';
import 'common/normalizetype.dart';

Future<void> exportToExcel(
    BuildContext context, List<UserProfile> users) async {
  try {
    // Get current society to properly filter data and get requirements
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot export: No society selected')),
      );
      return;
    }

    // Set up Excel document
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Members'];
    int maxEvents = 0;

    // Get all user IDs for batched queries
    final userIds = users.map((u) => u.id).toList();

    // Get email addresses
    final profilesResponse = await Supabase.instance.client
        .from('profiles')
        .select('user_id, email, graduation_year')
        .inFilter('user_id', userIds);

    final emailMap = {
      for (var item in profilesResponse)
        item['user_id'] as String: item['email'] as String
    };

    final graduationYearMap = {
      for (var item in profilesResponse)
        item['user_id'] as String: item['graduation_year']?.toString() ?? ''
    };

    // Get service hours for current society only
    final hoursResponse = await Supabase.instance.client
        .from('Service hours')
        .select('user_id, event_name, hours, type, date, timeslot')
        .eq('society_id', society.id) // Filter by current society
        .inFilter('user_id', userIds)
        .order('date');

    // Build a list of society's hour requirement types
    List<String> requirementTypes = ['Meeting']; // Always include Meeting
    for (final req in society.hourRequirements) {
      if (req.isActive && !requirementTypes.contains(req.type)) {
        requirementTypes.add(req.type);
      }
    }

    // Process hours data for each user
    Map<String, dynamic> userServiceData = {};
    for (final entry in hoursResponse) {
      try {
        final userId = entry['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;

        final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
        final type = entry['type']?.toString() ?? 'Unknown Type';
        final normalizedType =
            normalizeType(type); // Normalize for consistent comparison
        final eventName = entry['event_name']?.toString() ?? 'Unnamed Event';

        // Parse date safely
        DateTime date;
        try {
          date = entry['date'] != null
              ? DateTime.parse(entry['date'].toString())
              : DateTime.now();
        } catch (e) {
          date = DateTime.now();
        }

        final timeSlot = entry['timeslot']?.toString() ?? 'No time specified';

        if (userId.isNotEmpty) {
          // Initialize user data structure if not already done
          if (!userServiceData.containsKey(userId)) {
            userServiceData[userId] = {
              'eventsList': <String>[],
              'hoursByType': {
                for (var type in requirementTypes) normalizeType(type): 0.0
              },
              'meetingsAttended': 0,
              'totalHours': 0.0,
            };
          }

          final userData = userServiceData[userId];

          // Update hour totals based on type
          // Use normalized comparison to match requirement types
          bool typeMatched = false;
          for (var reqType in requirementTypes) {
            if (normalizeType(reqType) == normalizedType) {
              if (reqType == 'Meeting') {
                userData['meetingsAttended'] += 1; // Count meetings
              } else {
                userData['hoursByType'][normalizeType(reqType)] += hours;
              }
              typeMatched = true;
              break;
            }
          }

          // If no match found, try to add to a fallback category
          if (!typeMatched) {
            if (userData['hoursByType'].containsKey('Service')) {
              userData['hoursByType']['Service'] += hours;
            } else if (userData['hoursByType'].isNotEmpty) {
              // Add to the first available requirement type as fallback
              final firstType = userData['hoursByType'].keys.first;
              userData['hoursByType'][firstType] += hours;
            }
          }

          // Update total hours
          userData['totalHours'] = (userData['totalHours'] as double) + hours;

          // Format and add event detail to ordered list
          final formattedDate = '${date.month}/${date.day}/${date.year}';
          final eventDetail =
              '$eventName ($formattedDate - $timeSlot): $hours hours ($type)';
          userData['eventsList'].add(eventDetail);

          // Update max events count
          maxEvents = userData['eventsList'].length > maxEvents
              ? userData['eventsList'].length
              : maxEvents;
        }
      } catch (e) {
        print('Error processing entry: $e');
        continue;
      }
    }

    // Prepare dynamic headers based on society's requirements
    final baseHeaders = [
      'Name',
      'Email',
      'Graduation Year',
      'Dues Paid',
      'Total Hours',
      'Meetings Attended',
    ];

    // Add headers for each requirement type
    final requirementHeaders = requirementTypes
        .where((type) => type != 'Meeting') // Meeting already covered
        .map((type) => '$type Hours')
        .toList();

    // Event headers
    final eventHeaders = List.generate(maxEvents, (i) => 'Event ${i + 1}');
    final allHeaders = [...baseHeaders, ...requirementHeaders, ...eventHeaders];

    // Write headers to Excel
    for (var i = 0; i < allHeaders.length; i++) {
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(allHeaders[i])
        ..cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
    }

    // Write data for each user
    int rowIndex = 1;
    for (var user in users) {
      final userData = userServiceData[user.id] ??
          {
            'hoursByType': {
              for (var type in requirementTypes) normalizeType(type): 0.0
            },
            'meetingsAttended': 0,
            'totalHours': 0.0,
            'eventsList': <String>[],
          };

      // Column index tracker
      int colIndex = 0;

      // Base data
      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(user.name);

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(emailMap[user.id] ?? '');
          
      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(graduationYearMap[user.id] ?? "0000");

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(user.hasPaidDues ? 'Yes' : 'No');

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = DoubleCellValue(userData['totalHours']);

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = IntCellValue(userData['meetingsAttended']);

      // Dynamic requirement type hours
      for (var type in requirementTypes) {
        if (type == 'Meeting') continue; // Skip Meeting (already added)

        final hours = userData['hoursByType'][normalizeType(type)] ?? 0.0;
        sheetObject
            .cell(CellIndex.indexByColumnRow(
                columnIndex: colIndex++, rowIndex: rowIndex))
            .value = DoubleCellValue(hours);
      }

      // Event details in sequential columns
      for (var i = 0; i < (userData['eventsList'] as List).length; i++) {
        sheetObject
            .cell(CellIndex.indexByColumnRow(
                columnIndex: colIndex + i, rowIndex: rowIndex))
            .value = TextCellValue(userData['eventsList'][i]);
      }

      rowIndex++;
    }

    // Auto-fit columns
    for (var i = 0; i < allHeaders.length; i++) {
      sheetObject.setColumnWidth(i, 30);
    }

    // Save the file
    final fileBytes = excel.save(fileName: 'NHS_Members_Report.xlsx');
    if (fileBytes != null) {
      if (kIsWeb) {
        // Web handling is automatic through excel package
      } else {
        if (Platform.isAndroid) {
          final file =
              File('storage/emulated/0/Download/NHS_Members_Report.xlsx');
          await file.writeAsBytes(fileBytes);
        } else if (Platform.isIOS) {
          final Directory dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/NHS_Members_Report.xlsx');
          await file.writeAsBytes(fileBytes);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved successfully!')),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error generating report: $e')),
    );
  }
}

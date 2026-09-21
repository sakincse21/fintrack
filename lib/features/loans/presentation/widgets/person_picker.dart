import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../providers/loans_provider.dart';

class PersonPicker {
  static Future<Person?> show(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<Person>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonPickerSheet(ref: ref),
    );
  }
}

class _PersonPickerSheet extends StatefulWidget {
  final WidgetRef ref;
  const _PersonPickerSheet({required this.ref});

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  bool _isAddingNew = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContactFromDevice() async {
    try {
      final Contact? contact = await _contactPicker.selectContact();
      if (contact == null) return;

      final name = contact.fullName?.trim() ?? '';
      final phone = contact.phoneNumbers?.isNotEmpty == true
          ? contact.phoneNumbers!.first.trim()
          : null;

      if (name.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read contact name')),
          );
        }
        return;
      }

      final db = widget.ref.read(databaseProvider);
      final id = await db.insertPerson(
        PeopleCompanion.insert(
          name: name,
          phone: drift.Value(phone?.isEmpty ?? true ? null : phone),
        ),
      );

      final person = Person(
        id: id,
        name: name,
        phone: phone?.isEmpty ?? true ? null : phone,
      );

      if (mounted) Navigator.pop(context, person);
    } catch (e) {
      if (mounted) {
        // User may cancel contact picker or deny permission
        debugPrint('Contact pick error: $e');
      }
    }
  }

  Future<void> _saveNewPerson() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    final db = widget.ref.read(databaseProvider);
    final id = await db.insertPerson(
      PeopleCompanion.insert(
        name: name,
        phone: drift.Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
      ),
    );

    final person = Person(
      id: id,
      name: name,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    if (mounted) Navigator.pop(context, person);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peopleAsync = widget.ref.watch(peopleListProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Person',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            if (_isAddingNew)
              _buildAddNewForm(isDark)
            else ...[
              // Search bar
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons: Add manually or Import from contacts
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isAddingNew = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.userPlus, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Add New',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickContactFromDevice,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.contactRound, size: 16, color: AppColors.secondary),
                            SizedBox(width: 8),
                            Text(
                              'Import Contact',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // People list
              Flexible(
                child: peopleAsync.when(
                  data: (people) {
                    final filtered = _searchQuery.isEmpty
                        ? people
                        : people
                            .where((p) =>
                                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                (p.phone?.contains(_searchQuery) ?? false))
                            .toList();

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            people.isEmpty
                                ? 'No people added yet'
                                : 'No matching results',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: person.phone != null && person.phone!.isNotEmpty
                              ? Text(
                                  person.phone!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                )
                              : null,
                          trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                          onTap: () => Navigator.pop(context, person),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewForm(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name *',
            hintText: 'Enter person name',
            prefixIcon: const Icon(LucideIcons.user, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone (optional)',
            hintText: 'Enter phone number',
            prefixIcon: const Icon(LucideIcons.phone, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isAddingNew = false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveNewPerson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


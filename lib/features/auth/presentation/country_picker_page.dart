import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/countries.dart';

class CountryPickerPage extends StatefulWidget {
  const CountryPickerPage({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<CountryPickerPage> createState() => _CountryPickerPageState();
}

class _CountryPickerPageState extends State<CountryPickerPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryOption> get _filteredCountries {
    if (_query.isEmpty) return worldCountries;
    final query = _query.toLowerCase();
    return worldCountries
        .where(
          (country) =>
              country.name.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final countries = _filteredCountries;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تحديد الدولة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن دولة...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(
              child: countries.isEmpty
                  ? const Center(
                      child: Text(
                        'لم يتم العثور على دولة بهذا الاسم',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: countries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final selected = country.code == widget.initialCode;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: .16,
                            ),
                            child: Text(
                              country.code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            country.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                )
                              : const Icon(
                                  Icons.chevron_left,
                                  color: AppColors.mutedText,
                                ),
                          onTap: () => Navigator.of(context).pop(country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

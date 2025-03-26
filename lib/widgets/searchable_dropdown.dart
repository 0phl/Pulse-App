import 'package:flutter/material.dart';

class SearchableDropdown extends StatefulWidget {
  final TextEditingController controller;
  final List<String> items;
  final Function(String) onItemSelected;
  final Function(String) onSearch;
  final String? selectedItem;
  final String hintText;

  const SearchableDropdown({
    Key? key,
    required this.controller,
    required this.items,
    required this.onItemSelected,
    required this.onSearch,
    this.selectedItem,
    this.hintText = 'Select an item',
  }) : super(key: key);

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field
        TextFormField(
          controller: widget.controller,
          onTap: () {
            setState(() {
              _isSearching = true;
            });
          },
          onChanged: widget.onSearch,
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixIcon: Icon(
              _isSearching ? Icons.close : Icons.arrow_drop_down,
              color: Colors.grey,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          readOnly: false,
        ),

        // Dropdown options
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              maxHeight: 180,
            ),
            child: widget.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No items found',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          item,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () {
                          setState(() {
                            _isSearching = false;
                          });
                          widget.onItemSelected(item);
                        },
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

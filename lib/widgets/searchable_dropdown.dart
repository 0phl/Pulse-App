import 'package:flutter/material.dart';

class SearchableDropdown extends StatefulWidget {
  final TextEditingController controller;
  final List<String> items;
  final Function(String) onItemSelected;
  final Function(String) onSearch;
  final String? selectedItem;
  final String hintText;
  final bool allowCustomValue;

  const SearchableDropdown({
    Key? key,
    required this.controller,
    required this.items,
    required this.onItemSelected,
    required this.onSearch,
    this.selectedItem,
    this.hintText = 'Select an item',
    this.allowCustomValue = false,
  }) : super(key: key);

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  bool _isSearching = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.allowCustomValue) {
      // When focus is lost and custom values are allowed,
      // use the current text as the selected value
      if (widget.controller.text.isNotEmpty) {
        widget.onItemSelected(widget.controller.text);
      }
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          onTap: () {
            setState(() {
              _isSearching = true;
            });
          },
          onChanged: (value) {
            widget.onSearch(value);
            // If custom values are allowed, update the selected item as the user types
            if (widget.allowCustomValue) {
              widget.onItemSelected(value);
            }
          },
          onFieldSubmitted: (value) {
            if (widget.allowCustomValue && value.isNotEmpty) {
              widget.onItemSelected(value);
              setState(() {
                _isSearching = false;
              });
            }
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                });
              },
              child: Icon(
                _isSearching ? Icons.close : Icons.arrow_drop_down,
                color: Colors.grey,
                size: 20,
              ),
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
                ? widget.allowCustomValue
                    ? ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              'No items found',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          if (widget.controller.text.isNotEmpty)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isSearching = false;
                                  });
                                  widget.onItemSelected(widget.controller.text);
                                },
                                hoverColor: const Color(0xFF00C49A).withOpacity(0.05),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.add_circle_outline,
                                        size: 16,
                                        color: Color(0xFF00C49A),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Use "${widget.controller.text}"',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF00C49A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
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

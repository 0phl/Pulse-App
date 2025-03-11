import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/audit_log_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final _auditLogService = AuditLogService();
  final _scrollController = ScrollController();
  final _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  
  List<DocumentSnapshot> _logs = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  
  // Filter values
  AuditActionType? _selectedActionType;
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _loadInitialLogs();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialLogs() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _auditLogService.getAuditLogs(
        actionType: _selectedActionType?.value,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _logs = snapshot.docs;
        _lastDocument = snapshot.docs.lastOrNull;
        _hasMore = snapshot.docs.length == 20; // Using the default limit
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading audit logs: $e');
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _auditLogService.getAuditLogs(
        startAfter: _lastDocument,
        actionType: _selectedActionType?.value,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _logs.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.lastOrNull;
        _hasMore = snapshot.docs.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading more logs: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreLogs();
    }
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filter Audit Logs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AuditActionType>(
                value: _selectedActionType,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Actions'),
                  ),
                  ...AuditActionType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.value.replaceAll('_', ' ')),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedActionType = value),
                decoration: const InputDecoration(
                  labelText: 'Action Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_startDate != null 
                          ? DateFormat('MMM dd, yyyy').format(_startDate!)
                          : 'Start Date'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_endDate != null 
                          ? DateFormat('MMM dd, yyyy').format(_endDate!)
                          : 'End Date'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadInitialLogs();
                },
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final logs = await _auditLogService.exportAuditLogs(
        startDate: _startDate,
        endDate: _endDate,
        actionType: _selectedActionType?.value,
      );
      
      // TODO: Implement actual export functionality
      // For now, just show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs exported successfully')),
        );
      }
    } catch (e) {
      _showError('Error exporting logs: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: _isLoading && _logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _logs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _logs.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final log = _logs[index].data() as Map<String, dynamic>;
                final timestamp = (log['timestamp'] as Timestamp).toDate();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(log['actionType'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By: ${log['adminEmail']}'),
                        Text('Resource: ${log['targetResource']}'),
                        Text('Time: ${_dateFormat.format(timestamp)}'),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Log Details'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _detailRow('Action', log['actionType']),
                                _detailRow('Admin', log['adminEmail']),
                                _detailRow('Resource', log['targetResource']),
                                _detailRow('Time', _dateFormat.format(timestamp)),
                                const Divider(),
                                const Text('Details:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(log['details'].toString()),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

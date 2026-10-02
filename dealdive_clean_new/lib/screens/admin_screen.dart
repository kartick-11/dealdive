import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _storeController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Food');
  final _priceController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isHot = false;

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _storeController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveDeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final price = double.parse(_priceController.text.trim());
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());

      await FirebaseFirestore.instance.collection('deals').add({
        'title': _titleController.text.trim(),
        'storeName': _storeController.text.trim(),
        'category': _categoryController.text.trim(),
        'price': price,
        'latitude': lat,
        'longitude': lng,
        'description': _descriptionController.text.trim(),
        'isHot': _isHot,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal added')),
      );

      _formKey.currentState!.reset();
      _isHot = false;
      setState(() {});

      _priceController.clear();
      _latController.clear();
      _lngController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding deal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – Add deal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Quickly add or test new deals.\nCoordinates must be in decimal lat/lng.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Deal title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _storeController,
                decoration: const InputDecoration(labelText: 'Store name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter store name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter price';
                  }
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a valid number'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration:
                          const InputDecoration(labelText: 'Latitude'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Lat required';
                        }
                        return double.tryParse(v.trim()) == null
                            ? 'Invalid'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration:
                          const InputDecoration(labelText: 'Longitude'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Lng required';
                        }
                        return double.tryParse(v.trim()) == null
                            ? 'Invalid'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isHot,
                onChanged: (v) => setState(() => _isHot = v),
                title: const Text('Mark as hot deal (🔥)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveDeal,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save deal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

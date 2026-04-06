import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/preferences_service.dart';
import '../app.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _bloodType = 'O+';
  String _contactName = '';
  String _contactPhone = '';

  void _saveAndContinue() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      await PreferencesService.setRiderName(_name);
      await PreferencesService.setBloodType(_bloodType);
      await PreferencesService.setEmergencyContactName(_contactName);
      await PreferencesService.setEmergencyContactPhone(_contactPhone);
      await PreferencesService.setFirstLaunchComplete();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Welcome to Impact Node', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We just need a few details to set up your automatic SOS defense system.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              const Text('Rider Profile', style: TextStyle(color: AppColors.activeRed, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField('Full Name', Icons.person, (v) => _name = v!),
              const SizedBox(height: 16),
              _buildTextField('Blood Type (e.g. O+)', Icons.medical_services, (v) => _bloodType = v!),
              
              const SizedBox(height: 32),
              const Text('Emergency Contact', style: TextStyle(color: AppColors.activeRed, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField('Contact Name', Icons.group, (v) => _contactName = v!),
              const SizedBox(height: 16),
              _buildTextField('Contact Phone', Icons.phone, (v) => _contactPhone = v!, keyboardType: TextInputType.phone),
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveAndContinue,
                  child: const Text('ACTIVATE DEFENSE SYSTEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, Function(String?) onSave, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.activeRed),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.activeRed),
        ),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required field' : null,
      onSaved: onSave,
    );
  }
}

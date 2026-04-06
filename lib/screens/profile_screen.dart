import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/rider.dart';

class ProfileScreen extends StatefulWidget {
  final Rider rider;
  final Function(Rider) onSave;

  const ProfileScreen({
    super.key,
    required this.rider,
    required this.onSave,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _vehicleController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rider.name);
    _phoneController = TextEditingController(text: widget.rider.phone);
    _vehicleController = TextEditingController(text: widget.rider.vehicleType);
    _emergencyNameController =
        TextEditingController(text: widget.rider.emergencyContactName);
    _emergencyPhoneController =
        TextEditingController(text: widget.rider.emergencyContactPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      // Save
      final updatedRider = widget.rider.copyWith(
        name: _nameController.text,
        phone: _phoneController.text,
        vehicleType: _vehicleController.text,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
      );
      widget.onSave(updatedRider);
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROFILE',
                  style: AppTheme.labelStyle.copyWith(
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                TextButton(
                  onPressed: _toggleEdit,
                  child: Text(
                    _isEditing ? 'SAVE' : 'EDIT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isEditing
                          ? AppColors.safeGreenLight
                          : AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Avatar
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.rider.name.isNotEmpty
                        ? widget.rider.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Rider info section
            Text('RIDER INFO', style: AppTheme.labelStyle),
            const SizedBox(height: 8),

            GlassCard(
              child: Column(
                children: [
                  _ProfileField(
                    label: 'Name',
                    controller: _nameController,
                    isEditing: _isEditing,
                    icon: Icons.person_outline,
                  ),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _ProfileField(
                    label: 'Phone',
                    controller: _phoneController,
                    isEditing: _isEditing,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _ProfileField(
                    label: 'Vehicle',
                    controller: _vehicleController,
                    isEditing: _isEditing,
                    icon: Icons.two_wheeler,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Emergency contact section
            Text('EMERGENCY CONTACT', style: AppTheme.labelStyle),
            const SizedBox(height: 8),

            GlassCard(
              child: Column(
                children: [
                  _ProfileField(
                    label: 'Name',
                    controller: _emergencyNameController,
                    isEditing: _isEditing,
                    icon: Icons.shield_outlined,
                  ),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _ProfileField(
                    label: 'Phone',
                    controller: _emergencyPhoneController,
                    isEditing: _isEditing,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final IconData icon;
  final TextInputType keyboardType;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.isEditing,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.label, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTheme.labelStyle,
                ),
                const SizedBox(height: 2),
                isEditing
                    ? TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        controller.text.isEmpty ? '—' : controller.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

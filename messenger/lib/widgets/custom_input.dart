import 'package:flutter/material.dart';

class CustomInputField extends StatefulWidget {
  final String hintText;
  final bool isPassword;
  final TextEditingController controller;
  final IconData? iconData;

  const CustomInputField({
    super.key,
    required this.hintText,
    required this.isPassword,
    required this.controller,
    this.iconData,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  bool _isObscured = true;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.isPassword;
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _showClearButton = widget.controller.text.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🪄 ОПРЕДЕЛЯЕМ ЦВЕТА В ЗАВИСИМОСТИ ОТ ТЕМЫ
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F2);
    Color textColor = isDark ? Colors.white : Colors.black;
    Color hintColor = isDark ? Colors.grey[500]! : Colors.black54;
    Color iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _isObscured : false,
        // Используем динамический цвет текста
        style: TextStyle(fontSize: 17, color: textColor, fontFamily: 'SF Pro'),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: hintColor, fontSize: 17),
          
          filled: true,
          fillColor: bgColor, // Динамический фон
          
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          
          prefixIcon: widget.iconData != null 
              ? Icon(widget.iconData, color: iconColor) 
              : null,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF0088FF), width: 2),
          ),

          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: iconColor,
                    ),
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                  )
                : (_showClearButton
                    ? IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            // Серый кружок тоже адаптируем
                            color: isDark ? Colors.grey[700] : const Color(0xFFC4C4C6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                        onPressed: () => widget.controller.clear(),
                      )
                    : null),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'fake_lock.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _operand1 = '';
  String _operator = '';
  String _operand2 = '';
  bool _shouldReset = false;

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'AC' || key == 'C') {
        _clearAll();
      } else if (key == '+/-') {
        _toggleSign();
      } else if (key == '%') {
        _applyPercent();
      } else if (key == '+' || key == '-' || key == '×' || key == '÷') {
        _selectOperator(key);
      } else if (key == '=') {
        _calculateResult();
      } else {
        _appendDigit(key);
      }
    });
  }

  void _clearAll() {
    _display = '0';
    _operand1 = '';
    _operator = '';
    _operand2 = '';
    _shouldReset = false;
  }

  void _toggleSign() {
    if (_display == '0') return;
    if (_display.startsWith('-')) {
      _display = _display.substring(1);
    } else {
      _display = '-$_display';
    }
  }

  void _applyPercent() {
    double val = double.tryParse(_display) ?? 0.0;
    val = val / 100.0;
    _display = _formatNumber(val);
  }

  void _selectOperator(String op) {
    _operand1 = _display;
    _operator = op;
    _shouldReset = true;
  }

  void _appendDigit(String digit) {
    if (_display == '0' || _shouldReset) {
      if (digit == '.') {
        _display = '0.';
      } else {
        _display = digit;
      }
      _shouldReset = false;
    } else {
      if (digit == '.' && _display.contains('.')) {
        return; // Avoid multiple decimals
      }
      _display += digit;
    }
  }

  Future<void> _calculateResult() async {
    // 1. Intercept for passcode checking first
    // If it returns true, the lock handled it (e.g. SOS or navigated away).
    final intercepted = await FakeLock.evaluateInput(context, _display);
    if (intercepted) {
      _clearAll();
      return;
    }

    // 2. Perform regular calculator math
    if (_operator.isEmpty) return;

    _operand2 = _display;
    double num1 = double.tryParse(_operand1) ?? 0.0;
    double num2 = double.tryParse(_operand2) ?? 0.0;
    double result = 0.0;

    switch (_operator) {
      case '+':
        result = num1 + num2;
        break;
      case '-':
        result = num1 - num2;
        break;
      case '×':
        result = num1 * num2;
        break;
      case '÷':
        if (num2 != 0) {
          result = num1 / num2;
        } else {
          _display = 'Error';
          _operator = '';
          _shouldReset = true;
          return;
        }
        break;
    }

    _display = _formatNumber(result);
    _operator = '';
    _operand1 = '';
    _operand2 = '';
    _shouldReset = true;
  }

  String _formatNumber(double num) {
    if (num % 1 == 0) {
      return num.toInt().toString();
    }
    // Limit decimals to fit screen nicely
    String str = num.toString();
    if (str.length > 10) {
      return num.toStringAsPrecision(8);
    }
    return str;
  }

  Widget _buildButton(String text, Color textColor, Color bgColor, {double widthFactor = 1.0}) {
    return Expanded(
      flex: (widthFactor * 10).toInt(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => _onKeyPress(text),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: bgColor,
              shape: widthFactor == 1.0 ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widthFactor > 1.0 ? BorderRadius.circular(40) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                )
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color digitBg = Colors.grey[850]!;
    final Color funcBg = Colors.grey[400]!;
    final Color opBg = Colors.orange[800]!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Decoy status bar or just padding
            const Spacer(),
            
            // Calculator Screen Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w300,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),

            // Calculator Keypad
            Column(
              children: [
                Row(
                  children: [
                    _buildButton('AC', Colors.black, funcBg),
                    _buildButton('+/-', Colors.black, funcBg),
                    _buildButton('%', Colors.black, funcBg),
                    _buildButton('÷', Colors.white, opBg),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('7', Colors.white, digitBg),
                    _buildButton('8', Colors.white, digitBg),
                    _buildButton('9', Colors.white, digitBg),
                    _buildButton('×', Colors.white, opBg),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('4', Colors.white, digitBg),
                    _buildButton('5', Colors.white, digitBg),
                    _buildButton('6', Colors.white, digitBg),
                    _buildButton('-', Colors.white, opBg),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('1', Colors.white, digitBg),
                    _buildButton('2', Colors.white, digitBg),
                    _buildButton('3', Colors.white, digitBg),
                    _buildButton('+', Colors.white, opBg),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('0', Colors.white, digitBg, widthFactor: 2.0),
                    _buildButton('.', Colors.white, digitBg),
                    _buildButton('=', Colors.white, opBg),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

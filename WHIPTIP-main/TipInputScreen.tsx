import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, KeyboardAvoidingView, Platform, SafeAreaView } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
// Adjust import path for flattened repo structure. In the root-level
// structure, `calc.ts` sits alongside this file, so we import from
// `./calc` instead of `../utils/calc`.
import { SplitMethod, StaffMember, TipShare, calculateTips } from './calc';

interface Props {
  /**
   * List of staff members collected from the previous screen.
   */
  staff: StaffMember[];
  /**
   * Selected split method from onboarding.
   */
  method: SplitMethod;
  /**
   * Called with the calculated shares when the user completes this step.
   */
  onDone: (shares: TipShare[]) => void;
}

/**
 * TipInputScreen prompts the user to enter the total amount of tips
 * collected during the shift. Once provided, it invokes the math
 * engine to calculate each person’s share and advances to the
 * results screen. Basic validation prevents invalid inputs.
 */
const TipInputScreen: React.FC<Props> = ({ staff, method, onDone }) => {
  const [total, setTotal] = useState('');

  const handleCalculate = () => {
    const amount = parseFloat(total);
    if (isNaN(amount) || amount < 0) {
      Alert.alert('Invalid amount', 'Please enter a valid number for total tips.');
      return;
    }
    // Validate custom percentages sum to ~100 when using custom percentages
    if (method === SplitMethod.CustomPercentages) {
      const percentages = staff
        .map((m) => (typeof m.customPercentage === 'number' ? m.customPercentage! : 0))
        .filter((p) => p > 0);
      const sum = percentages.reduce((a, b) => a + b, 0);
      // allow small rounding error
      if (percentages.length > 0 && (sum < 99.5 || sum > 100.5)) {
        Alert.alert(
          'Percentages must total 100%',
          `Your custom percentages add up to ${sum.toFixed(1)}%. Please adjust so they total 100%.`,
        );
        return;
      }
    }
    const shares = calculateTips(amount, staff, method);
    // Cache last session and append to history for offline usage
    const saveSession = async () => {
      try {
        const session = {
          method,
          staff,
          totalTips: amount,
          results: shares,
          timestamp: Date.now(),
        };
        await AsyncStorage.setItem('lastSession', JSON.stringify(session));
        // Append to history list
        const histStr = await AsyncStorage.getItem('history');
        let hist: any[] = [];
        if (histStr) {
          try {
            hist = JSON.parse(histStr);
          } catch {
            hist = [];
          }
        }
        hist.push(session);
        await AsyncStorage.setItem('history', JSON.stringify(hist));
      } catch (err) {
        console.warn('Failed to save session', err);
      }
    };
    saveSession();
    onDone(shares);
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Text style={styles.title}>Total tips collected</Text>
        <TextInput
          style={styles.input}
          placeholder="$0.00"
          keyboardType="numeric"
          value={total}
          onChangeText={setTotal}
        />
        <TouchableOpacity style={styles.calculateButton} onPress={handleCalculate}>
          <Text style={styles.calcText}>Calculate</Text>
        </TouchableOpacity>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  input: {
    width: '80%',
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
    padding: 12,
    fontSize: 18,
    marginBottom: 16,
  },
  calculateButton: {
    backgroundColor: '#5856d6',
    paddingVertical: 14,
    paddingHorizontal: 40,
    borderRadius: 8,
  },
  calcText: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '600',
  },
});

export default TipInputScreen;
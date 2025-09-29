import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Alert, KeyboardAvoidingView, Platform, SafeAreaView } from 'react-native';
// Adjust import paths for flattened repo structure. When these files
// are placed in the repository root, the `StaffRow` component and
// `calc.ts` sit alongside this file. Use relative imports without
// subdirectories.
import StaffRow from './StaffRow';
import { SplitMethod, StaffMember } from './calc';

interface Props {
  /**
   * The selected split method from onboarding. Determines which inputs
   * appear for each staff row.
   */
  method: SplitMethod;
  /**
   * Called when the user is done entering staff. Provides the list
   * of staff back to the parent.
   */
  onDone: (staff: StaffMember[]) => void;
}

/**
 * StaffEntryScreen collects information about everyone who worked
 * during the shift. Users can add as many rows as needed. Each row
 * includes fields appropriate to the chosen split method. Once the
 * user is satisfied, they can proceed to enter the total tips.
 */
const StaffEntryScreen: React.FC<Props> = ({ method, onDone }) => {
  const [staffList, setStaffList] = useState<StaffMember[]>([
    { name: '', role: '', hoursWorked: 0 },
  ]);

  const updateMember = (index: number, updated: StaffMember) => {
    setStaffList((prev) => {
      const newList = [...prev];
      newList[index] = updated;
      return newList;
    });
  };

  const addStaff = () => {
    setStaffList((prev) => [...prev, { name: '', role: '', hoursWorked: 0 }]);
  };

  const handleNext = () => {
    // Filter out completely empty entries (no name and zero hours)
    const cleaned = staffList.filter((m) => m.name.trim() !== '' || m.hoursWorked > 0);
    if (cleaned.length === 0) {
      Alert.alert('No staff entered', 'Please add at least one staff member with hours worked.');
      return;
    }
    onDone(cleaned);
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Text style={styles.title}>Enter your crew</Text>
        <ScrollView style={{ flex: 1 }} keyboardShouldPersistTaps="handled">
          {staffList.map((member, idx) => (
            <StaffRow
              key={idx}
              index={idx}
              member={member}
              method={method}
              onChange={(updated) => updateMember(idx, updated)}
            />
          ))}
          <TouchableOpacity style={styles.addButton} onPress={addStaff}>
            <Text style={styles.addText}>+ Add Staff</Text>
          </TouchableOpacity>
        </ScrollView>
        <TouchableOpacity style={styles.nextButton} onPress={handleNext}>
          <Text style={styles.nextText}>Next</Text>
        </TouchableOpacity>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    paddingTop: 40,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  addButton: {
    marginTop: 8,
    paddingVertical: 10,
  },
  addText: {
    color: '#007aff',
    fontSize: 16,
  },
  nextButton: {
    backgroundColor: '#34c759',
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 8,
    marginTop: 16,
  },
  nextText: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '600',
  },
});

export default StaffEntryScreen;
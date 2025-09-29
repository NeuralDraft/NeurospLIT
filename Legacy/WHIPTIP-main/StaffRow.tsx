import React from 'react';
import { View, TextInput, Text, StyleSheet } from 'react-native';
// Adjust import path for flattened repo structure. When the component
// is placed in the repository root, import from the sibling `calc.ts`.
import { SplitMethod, StaffMember } from './calc';

interface Props {
  /**
   * Index of this row in the parent list. Useful for keys and labels.
   */
  index: number;
  /**
   * Current staff member values for this row.
   */
  member: StaffMember;
  /**
   * Selected split method. This controls which inputs are shown.
   */
  method: SplitMethod;
  /**
   * Callback invoked whenever a field in this row changes. The
   * parent should update its state accordingly.
   */
  onChange: (updated: StaffMember) => void;
}

/**
 * A single row in the staff entry form. Displays inputs for name,
 * role, hours and optionally custom point/percentage values based on
 * the selected split method. Minimal styling ensures focus remains on
 * the data entry itself.
 */
const StaffRow: React.FC<Props> = ({ index, member, method, onChange }) => {
  /**
   * Helper to update a single field on the member object.
   */
  const updateField = (field: keyof StaffMember, value: string) => {
    let parsedValue: number | string | undefined = value;
    if (field === 'hoursWorked' || field === 'customPoints' || field === 'customPercentage') {
      // Convert empty string to undefined, otherwise parse as float
      parsedValue = value === '' ? undefined : Number(value);
      if (isNaN(parsedValue as number)) {
        parsedValue = undefined;
      }
    }
    const updated: StaffMember = {
      ...member,
      [field]: parsedValue,
    } as StaffMember;
    onChange(updated);
  };

  return (
    <View style={styles.row}>
      <Text style={styles.label}>{index + 1}.</Text>
      <TextInput
        style={[styles.input, { flex: 2 }]}
        placeholder="Name"
        value={member.name}
        onChangeText={(text) => updateField('name', text)}
      />
      <TextInput
        style={[styles.input, { flex: 2 }]}
        placeholder="Role"
        value={member.role}
        onChangeText={(text) => updateField('role', text)}
      />
      <TextInput
        style={[styles.input, { flex: 1 }]}
        placeholder="Hours"
        keyboardType="numeric"
        value={member.hoursWorked ? String(member.hoursWorked) : ''}
        onChangeText={(text) => updateField('hoursWorked', text)}
      />
      {method === SplitMethod.RolePoints && (
        <TextInput
          style={[styles.input, { flex: 1 }]}
          placeholder="Pts"
          keyboardType="numeric"
          value={member.customPoints !== undefined ? String(member.customPoints) : ''}
          onChangeText={(text) => updateField('customPoints', text)}
        />
      )}
      {method === SplitMethod.CustomPercentages && (
        <TextInput
          style={[styles.input, { flex: 1 }]}
          placeholder="%"
          keyboardType="numeric"
          value={member.customPercentage !== undefined ? String(member.customPercentage) : ''}
          onChangeText={(text) => updateField('customPercentage', text)}
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 4,
  },
  label: {
    marginRight: 4,
    fontSize: 16,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 4,
    padding: 8,
    marginHorizontal: 2,
    minWidth: 60,
  },
});

// Wrap the row component in React.memo to avoid unnecessary re‑renders
// when the parent state updates. The default shallow prop comparison
// suffices because the parent passes stable references for member and
// onChange via useState/update patterns.
export default React.memo(StaffRow);
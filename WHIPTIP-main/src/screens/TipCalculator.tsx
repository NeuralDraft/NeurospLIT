import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Alert,
} from 'react-native';
import Decimal from 'decimal.js';
import { TipSplitEngine, TeamMember, AllocationStep } from '../engine/TipSplitEngine';

export const TipCalculator: React.FC = () => {
  const [cashTips, setCashTips] = useState('');
  const [cardTips, setCardTips] = useState('');
  const [members, setMembers] = useState<TeamMember[]>([
    { id: '1', name: 'Sarah', role: 'server', hours: 8 },
    { id: '2', name: 'Mike', role: 'bartender', hours: 6 },
    { id: '3', name: 'Alex', role: 'busser', hours: 4 },
  ]);
  const [steps, setSteps] = useState<AllocationStep[]>([]);
  const [results, setResults] = useState<Map<string, Decimal>>(new Map());

  const engine = new TipSplitEngine();

  const calculate = () => {
    const total = new Decimal(cashTips || 0).plus(new Decimal(cardTips || 0));
    
    if (total.isZero()) {
      Alert.alert('No Tips', 'Please enter tip amounts');
      return;
    }
    
    if (members.length === 0) {
      Alert.alert('No Team', 'Please add team members');
      return;
    }
    
    // Use default equal split if no steps defined
    const stepsToUse = steps.length > 0 ? steps : [{
      id: 'default',
      name: 'Equal Split',
      type: 'all-remaining' as const,
      filter: { type: 'everyone' as const },
      method: { type: 'equal' as const },
      priority: 1
    }];
    
    const result = engine.calculate(total, members, stepsToUse);
    setResults(result.allocations);
  };

  const addMember = () => {
    const newMember: TeamMember = {
      id: Date.now().toString(),
      name: '',
      role: 'server',
      hours: 0
    };
    setMembers([...members, newMember]);
  };

  const updateMember = (id: string, field: keyof TeamMember, value: any) => {
    setMembers(members.map(m => 
      m.id === id ? { ...m, [field]: value } : m
    ));
  };

  const removeMember = (id: string) => {
    setMembers(members.filter(m => m.id !== id));
  };

  return (
    <ScrollView style={styles.container}>
      {/* Tip Input Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Tips to Split</Text>
        <View style={styles.tipInputs}>
          <View style={styles.tipInput}>
            <Text style={styles.label}>Cash Tips</Text>
            <TextInput
              style={styles.input}
              value={cashTips}
              onChangeText={setCashTips}
              keyboardType="decimal-pad"
              placeholder="0.00"
            />
          </View>
          <View style={styles.tipInput}>
            <Text style={styles.label}>Card Tips</Text>
            <TextInput
              style={styles.input}
              value={cardTips}
              onChangeText={setCardTips}
              keyboardType="decimal-pad"
              placeholder="0.00"
            />
          </View>
        </View>
        <View style={styles.totalRow}>
          <Text style={styles.totalLabel}>Total Tips:</Text>
          <Text style={styles.totalAmount}>
            ${new Decimal(cashTips || 0).plus(new Decimal(cardTips || 0)).toFixed(2)}
          </Text>
        </View>
      </View>

      {/* Team Members Section */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Team Members</Text>
          <TouchableOpacity onPress={addMember} style={styles.addButton}>
            <Text style={styles.addButtonText}>+ Add</Text>
          </TouchableOpacity>
        </View>

        {members.map(member => (
          <View key={member.id} style={styles.memberCard}>
            <View style={styles.memberRow}>
              <TextInput
                style={[styles.input, styles.nameInput]}
                value={member.name}
                onChangeText={(text) => updateMember(member.id, 'name', text)}
                placeholder="Name"
              />
              <TextInput
                style={[styles.input, styles.roleInput]}
                value={member.role}
                onChangeText={(text) => updateMember(member.id, 'role', text)}
                placeholder="Role"
              />
              <TextInput
                style={[styles.input, styles.hoursInput]}
                value={member.hours?.toString() || ''}
                onChangeText={(text) => updateMember(member.id, 'hours', parseFloat(text) || 0)}
                keyboardType="decimal-pad"
                placeholder="Hours"
              />
              <TouchableOpacity
                onPress={() => removeMember(member.id)}
                style={styles.removeButton}
              >
                <Text style={styles.removeButtonText}>✕</Text>
              </TouchableOpacity>
            </View>
          </View>
        ))}
      </View>

      {/* Quick Actions */}
      <View style={styles.quickActions}>
        <TouchableOpacity
          style={styles.quickAction}
          onPress={() => {
            setSteps([{
              id: '1',
              name: 'Equal Split',
              type: 'all-remaining',
              filter: { type: 'everyone' },
              method: { type: 'equal' },
              priority: 1
            }]);
            calculate();
          }}
        >
          <Text style={styles.quickActionText}>Equal Split</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.quickAction}
          onPress={() => {
            setSteps([{
              id: '1',
              name: 'By Hours',
              type: 'all-remaining',
              filter: { type: 'everyone' },
              method: { type: 'by-hours' },
              priority: 1
            }]);
            calculate();
          }}
        >
          <Text style={styles.quickActionText}>By Hours</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.quickAction}
          onPress={() => {
            // Open custom rule builder
            Alert.alert('Custom Rules', 'Rule builder would open here');
          }}
        >
          <Text style={styles.quickActionText}>Custom</Text>
        </TouchableOpacity>
      </View>

      {/* Calculate Button */}
      <TouchableOpacity style={styles.calculateButton} onPress={calculate}>
        <Text style={styles.calculateButtonText}>Calculate Split</Text>
      </TouchableOpacity>

      {/* Results Section */}
      {results.size > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Results</Text>
          {Array.from(results.entries())
            .sort((a, b) => a[0].localeCompare(b[0]))
            .map(([name, amount]) => (
              <View key={name} style={styles.resultRow}>
                <Text style={styles.resultName}>{name}</Text>
                <Text style={styles.resultAmount}>
                  ${amount.toFixed(2)}
                </Text>
              </View>
            ))}
          
          <View style={styles.totalRow}>
            <Text style={styles.totalLabel}>Total Distributed:</Text>
            <Text style={styles.totalAmount}>
              ${Array.from(results.values())
                .reduce((sum, val) => sum.plus(val), new Decimal(0))
                .toFixed(2)}
            </Text>
          </View>
        </View>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  section: {
    backgroundColor: 'white',
    margin: 15,
    padding: 15,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 2,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    marginBottom: 15,
  },
  tipInputs: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  tipInput: {
    flex: 1,
    marginHorizontal: 5,
  },
  label: {
    fontSize: 14,
    color: '#666',
    marginBottom: 5,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 10,
    fontSize: 16,
  },
  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 15,
    paddingTop: 15,
    borderTopWidth: 1,
    borderTopColor: '#eee',
  },
  totalLabel: {
    fontSize: 16,
    fontWeight: '600',
  },
  totalAmount: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#667eea',
  },
  addButton: {
    backgroundColor: '#667eea',
    paddingHorizontal: 15,
    paddingVertical: 8,
    borderRadius: 6,
  },
  addButtonText: {
    color: 'white',
    fontWeight: '600',
  },
  memberCard: {
    marginBottom: 10,
  },
  memberRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  nameInput: {
    flex: 2,
    marginRight: 5,
  },
  roleInput: {
    flex: 1.5,
    marginRight: 5,
  },
  hoursInput: {
    flex: 1,
    marginRight: 5,
  },
  removeButton: {
    padding: 10,
  },
  removeButtonText: {
    color: '#ff4444',
    fontSize: 20,
  },
  quickActions: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginHorizontal: 15,
    marginBottom: 15,
  },
  quickAction: {
    backgroundColor: 'white',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#667eea',
  },
  quickActionText: {
    color: '#667eea',
    fontWeight: '600',
  },
  calculateButton: {
    backgroundColor: '#667eea',
    marginHorizontal: 15,
    padding: 18,
    borderRadius: 12,
    alignItems: 'center',
  },
  calculateButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: '600',
  },
  resultRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  resultName: {
    fontSize: 16,
  },
  resultAmount: {
    fontSize: 16,
    fontWeight: '600',
  },
});

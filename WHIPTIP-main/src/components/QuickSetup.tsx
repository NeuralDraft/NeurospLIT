import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import Decimal from 'decimal.js';
import { AllocationStep } from '../engine/TipSplitEngine';

interface QuickTemplate {
  id: string;
  name: string;
  description: string;
  icon: string;
  steps: AllocationStep[];
}

const QUICK_TEMPLATES: QuickTemplate[] = [
  {
    id: 'equal-split',
    name: 'Equal Split',
    description: 'Everyone gets the same amount',
    icon: '⚖️',
    steps: [{
      id: '1',
      name: 'Equal Distribution',
      type: 'all-remaining',
      filter: { type: 'everyone' },
      method: { type: 'equal' },
      priority: 1
    }]
  },
  {
    id: 'hourly-split',
    name: 'By Hours Worked',
    description: 'Split proportional to hours',
    icon: '⏰',
    steps: [{
      id: '1',
      name: 'Hourly Distribution',
      type: 'all-remaining',
      filter: { type: 'everyone' },
      method: { type: 'by-hours' },
      priority: 1
    }]
  },
  {
    id: 'front-back-house',
    name: 'Front/Back of House',
    description: '70% servers/bartenders, 30% kitchen',
    icon: '🍽️',
    steps: [
      {
        id: '1',
        name: 'Front of House',
        type: 'percentage-of-total',
        percentage: 70,
        filter: { type: 'by-role', roles: ['server', 'bartender', 'host'] },
        method: { type: 'by-hours' },
        priority: 1
      },
      {
        id: '2',
        name: 'Back of House',
        type: 'percentage-of-total',
        percentage: 30,
        filter: { type: 'by-role', roles: ['cook', 'dishwasher', 'prep'] },
        method: { type: 'by-hours' },
        priority: 2
      }
    ]
  },
  {
    id: 'manager-first',
    name: 'Manager + Team',
    description: 'Manager gets fixed amount, team splits rest',
    icon: '👔',
    steps: [
      {
        id: '1',
        name: 'Manager Share',
        type: 'fixed-amount',
        amount: new Decimal(50),
        filter: { type: 'by-role', roles: ['manager'] },
        method: { type: 'equal' },
        priority: 1
      },
      {
        id: '2',
        name: 'Team Share',
        type: 'all-remaining',
        filter: { type: 'everyone' },
        method: { type: 'by-hours' },
        priority: 2
      }
    ]
  }
];

export const QuickSetup: React.FC<{
  onSelectTemplate: (template: QuickTemplate) => void;
  onCustomSetup: () => void;
}> = ({ onSelectTemplate, onCustomSetup }) => {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Choose Your Setup</Text>
      <Text style={styles.subtitle}>
        Select a template or create your own custom rules
      </Text>

      <View style={styles.grid}>
        {QUICK_TEMPLATES.map(template => (
          <TouchableOpacity
            key={template.id}
            style={styles.templateCard}
            onPress={() => onSelectTemplate(template)}
          >
            <Text style={styles.templateIcon}>{template.icon}</Text>
            <Text style={styles.templateName}>{template.name}</Text>
            <Text style={styles.templateDescription}>
              {template.description}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <TouchableOpacity
        style={styles.customButton}
        onPress={onCustomSetup}
      >
        <Text style={styles.customButtonText}>
          Create Custom Rules
        </Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 30,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  templateCard: {
    width: '48%',
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  templateIcon: {
    fontSize: 40,
    marginBottom: 10,
  },
  templateName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 5,
  },
  templateDescription: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
  customButton: {
    backgroundColor: '#667eea',
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
    marginTop: 20,
  },
  customButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: '600',
  },
});

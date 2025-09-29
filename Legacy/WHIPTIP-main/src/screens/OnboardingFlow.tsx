import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  ScrollView,
  Animated,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { LinearGradient } from 'expo-linear-gradient';
import { AllocationStep } from '../engine/TipSplitEngine';

interface OnboardingStep {
  id: string;
  question: string;
  subtitle?: string;
  type: 'single-choice' | 'multi-choice' | 'text' | 'number' | 'team-builder';
  options?: Array<{
    id: string;
    label: string;
    description?: string;
    icon?: string;
  }>;
  validation?: (value: any) => boolean;
}

const ONBOARDING_STEPS: OnboardingStep[] = [
  {
    id: 'restaurant-type',
    question: 'What type of restaurant are you?',
    subtitle: 'This helps us suggest the right splitting methods',
    type: 'single-choice',
    options: [
      {
        id: 'fine-dining',
        label: 'Fine Dining',
        description: 'High-end service, sommelier, multiple courses',
        icon: '🍷'
      },
      {
        id: 'casual-dining',
        label: 'Casual Dining',
        description: 'Full service, moderate prices',
        icon: '🍽️'
      },
      {
        id: 'fast-casual',
        label: 'Fast Casual',
        description: 'Counter service, quality ingredients',
        icon: '🥗'
      },
      {
        id: 'bar-pub',
        label: 'Bar & Pub',
        description: 'Drinks-focused with food',
        icon: '🍺'
      },
      {
        id: 'cafe-coffee',
        label: 'Café / Coffee Shop',
        description: 'Coffee, pastries, light meals',
        icon: '☕'
      },
      {
        id: 'food-truck',
        label: 'Food Truck / Quick Service',
        description: 'Fast service, limited menu',
        icon: '🚚'
      }
    ]
  },
  {
    id: 'team-size',
    question: 'How many people typically work a shift?',
    type: 'single-choice',
    options: [
      { id: '1-3', label: '1-3 people', icon: '👤' },
      { id: '4-7', label: '4-7 people', icon: '👥' },
      { id: '8-15', label: '8-15 people', icon: '👥👥' },
      { id: '16+', label: '16+ people', icon: '👥👥👥' }
    ]
  },
  {
    id: 'roles',
    question: 'What roles do you have?',
    subtitle: 'Select all that apply',
    type: 'multi-choice',
    options: [
      { id: 'manager', label: 'Manager/Shift Lead' },
      { id: 'server', label: 'Servers' },
      { id: 'bartender', label: 'Bartenders' },
      { id: 'host', label: 'Host/Hostess' },
      { id: 'busser', label: 'Bussers' },
      { id: 'runner', label: 'Food Runners' },
      { id: 'barista', label: 'Baristas' },
      { id: 'cook', label: 'Cooks/Kitchen' },
      { id: 'dishwasher', label: 'Dishwashers' },
      { id: 'barback', label: 'Barbacks' }
    ]
  },
  {
    id: 'current-method',
    question: 'How do you currently split tips?',
    subtitle: 'We\'ll help you recreate or improve it',
    type: 'single-choice',
    options: [
      {
        id: 'equal',
        label: 'Equal Split',
        description: 'Everyone gets the same amount',
        icon: '⚖️'
      },
      {
        id: 'hours',
        label: 'By Hours Worked',
        description: 'More hours = more tips',
        icon: '⏰'
      },
      {
        id: 'points',
        label: 'Point System',
        description: 'Different roles get different points',
        icon: '📊'
      },
      {
        id: 'manager-decides',
        label: 'Manager Decides',
        description: 'Discretionary based on performance',
        icon: '👔'
      },
      {
        id: 'sales-based',
        label: 'Sales-Based',
        description: 'Based on individual sales',
        icon: '💰'
      },
      {
        id: 'complex',
        label: 'It\'s Complicated',
        description: 'Mix of methods or special rules',
        icon: '🔀'
      },
      {
        id: 'none',
        label: 'We Don\'t Pool Tips',
        description: 'Everyone keeps their own',
        icon: '🚫'
      }
    ]
  },
  {
    id: 'pain-points',
    question: 'What challenges do you face?',
    subtitle: 'Select all that apply',
    type: 'multi-choice',
    options: [
      { id: 'fairness', label: 'Disputes about fairness' },
      { id: 'calculation', label: 'Math errors / takes too long' },
      { id: 'transparency', label: 'Lack of transparency' },
      { id: 'flexibility', label: 'Can\'t handle special situations' },
      { id: 'tracking', label: 'No record keeping' },
      { id: 'cash-card', label: 'Mixing cash and card tips' }
    ]
  }
];

export const OnboardingFlow: React.FC<{
  onComplete: (profile: RestaurantProfile) => void;
}> = ({ onComplete }) => {
  const [currentStep, setCurrentStep] = useState(0);
  const [answers, setAnswers] = useState<Record<string, any>>({});
  const [fadeAnim] = useState(new Animated.Value(1));

  // Check for saved profile on mount. If found, skip onboarding and call onComplete.
  useEffect(() => {
    const loadProfile = async () => {
      try {
        const saved = await AsyncStorage.getItem('tipSplitProfile');
        if (saved) {
          const parsed = JSON.parse(saved);
          if (parsed) {
            onComplete(parsed);
          }
        }
      } catch (error) {
        console.warn('Failed to load saved profile', error);
      }
    };
    loadProfile();
  }, []);

  // Handle user answer for current step. When finished, generate and persist profile
  const handleAnswer = async (value: any) => {
    setAnswers(prev => ({
      ...prev,
      [ONBOARDING_STEPS[currentStep].id]: value
    }));

    // Animate transition between questions
    Animated.sequence([
      Animated.timing(fadeAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true,
      }),
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 200,
        useNativeDriver: true,
      }),
    ]).start(async () => {
      if (currentStep < ONBOARDING_STEPS.length - 1) {
        setCurrentStep(currentStep + 1);
      } else {
        // Generate profile based on answers
        const profile = generateProfile({
          ...answers,
          [ONBOARDING_STEPS[currentStep].id]: value
        });
        try {
          await AsyncStorage.setItem('tipSplitProfile', JSON.stringify(profile));
        } catch (error) {
          console.warn('Failed to save profile', error);
        }
        onComplete(profile);
      }
    });
  };

  const step = ONBOARDING_STEPS[currentStep];

  return (
    <LinearGradient
      colors={['#667eea', '#764ba2']}
      style={styles.container}
    >
      <View style={styles.progressBar}>
        <View
          style={[
            styles.progressFill,
            {
              width: `${((currentStep + 1) / ONBOARDING_STEPS.length) * 100}%`
            }
          ]}
        />
      </View>

      <Animated.View
        style={[styles.content, { opacity: fadeAnim }]}
      >
        <Text style={styles.stepNumber}>
          Step {currentStep + 1} of {ONBOARDING_STEPS.length}
        </Text>
        
        <Text style={styles.question}>{step.question}</Text>
        
        {step.subtitle && (
          <Text style={styles.subtitle}>{step.subtitle}</Text>
        )}

        <ScrollView style={styles.optionsContainer}>
          {step.type === 'single-choice' && step.options?.map(option => (
            <TouchableOpacity
              key={option.id}
              style={styles.optionCard}
              onPress={() => handleAnswer(option.id)}
            >
              {option.icon && (
                <Text style={styles.optionIcon}>{option.icon}</Text>
              )}
              <View style={styles.optionText}>
                <Text style={styles.optionLabel}>{option.label}</Text>
                {option.description && (
                  <Text style={styles.optionDescription}>
                    {option.description}
                  </Text>
                )}
              </View>
            </TouchableOpacity>
          ))}

          {step.type === 'multi-choice' && (
            <MultiChoiceSelector
              options={step.options || []}
              onSelect={handleAnswer}
            />
          )}
        </ScrollView>
      </Animated.View>
    </LinearGradient>
  );
};

// Multi-choice component
const MultiChoiceSelector: React.FC<{
  options: Array<{ id: string; label: string }>;
  onSelect: (values: string[]) => void;
}> = ({ options, onSelect }) => {
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const toggle = (id: string) => {
    const newSelected = new Set(selected);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelected(newSelected);
  };

  return (
    <>
      {options.map(option => (
        <TouchableOpacity
          key={option.id}
          style={[
            styles.multiOption,
            selected.has(option.id) && styles.multiOptionSelected
          ]}
          onPress={() => toggle(option.id)}
        >
          <Text
            style={[
              styles.multiOptionText,
              selected.has(option.id) && styles.multiOptionTextSelected
            ]}
          >
            {option.label}
          </Text>
        </TouchableOpacity>
      ))}
      
      <TouchableOpacity
        style={styles.continueButton}
        onPress={() => onSelect(Array.from(selected))}
      >
        <Text style={styles.continueButtonText}>Continue</Text>
      </TouchableOpacity>
    </>
  );
};

// Generate recommended profile based on answers
interface RestaurantProfile {
  type: string;
  teamSize: string;
  roles: string[];
  suggestedMethods: AllocationStep[];
  features: string[];
}

function generateProfile(answers: Record<string, any>): RestaurantProfile {
  const profile: RestaurantProfile = {
    type: answers['restaurant-type'],
    teamSize: answers['team-size'],
    roles: answers['roles'] || [],
    suggestedMethods: [],
    features: []
  };

  // Generate smart suggestions based on restaurant type and current method
  if (answers['restaurant-type'] === 'fine-dining') {
    profile.suggestedMethods.push({
      id: '1',
      name: 'Service Staff Pool',
      type: 'percentage-of-total',
      percentage: 70,
      filter: { type: 'by-role', roles: ['server', 'bartender', 'sommelier'] },
      method: { type: 'by-hours' },
      priority: 1
    });
    profile.suggestedMethods.push({
      id: '2',
      name: 'Support Staff Pool',
      type: 'percentage-of-total',
      percentage: 20,
      filter: { type: 'by-role', roles: ['busser', 'runner', 'host'] },
      method: { type: 'by-hours' },
      priority: 2
    });
    profile.suggestedMethods.push({
      id: '3',
      name: 'Management',
      type: 'percentage-of-total',
      percentage: 10,
      filter: { type: 'by-role', roles: ['manager'] },
      method: { type: 'equal' },
      priority: 3
    });
  } else if (answers['current-method'] === 'points') {
    // Recreate their point system with smart defaults
    const rolePoints: Record<string, number> = {
      'manager': 1.5,
      'server': 1.0,
      'bartender': 1.0,
      'host': 0.5,
      'busser': 0.5,
      'runner': 0.5,
      'cook': 0.8,
      'dishwasher': 0.4
    };

    profile.suggestedMethods.push({
      id: '1',
      name: 'Point-Based Distribution',
      type: 'all-remaining',
      filter: { type: 'everyone' },
      method: { type: 'weighted', weights: rolePoints },
      priority: 1
    });
  }

  // Add features based on pain points
  if (answers['pain-points']?.includes('transparency')) {
    profile.features.push('detailed-receipts');
    profile.features.push('audit-trail');
  }
  if (answers['pain-points']?.includes('calculation')) {
    profile.features.push('auto-calculate');
    profile.features.push('rounding-rules');
  }

  return profile;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 60,
  },
  progressBar: {
    height: 4,
    backgroundColor: 'rgba(255,255,255,0.3)',
    marginHorizontal: 20,
    borderRadius: 2,
  },
  progressFill: {
    height: '100%',
    backgroundColor: 'white',
    borderRadius: 2,
  },
  content: {
    flex: 1,
    padding: 20,
  },
  stepNumber: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 14,
    marginBottom: 10,
  },
  question: {
    color: 'white',
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  subtitle: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 16,
    marginBottom: 30,
  },
  optionsContainer: {
    flex: 1,
  },
  optionCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  optionIcon: {
    fontSize: 32,
    marginRight: 15,
  },
  optionText: {
    flex: 1,
  },
  optionLabel: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  optionDescription: {
    fontSize: 14,
    color: '#666',
  },
  multiOption: {
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 8,
    padding: 15,
    marginBottom: 10,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  multiOptionSelected: {
    backgroundColor: 'white',
    borderColor: '#667eea',
  },
  multiOptionText: {
    fontSize: 16,
    color: '#333',
  },
  multiOptionTextSelected: {
    fontWeight: '600',
    color: '#667eea',
  },
  continueButton: {
    backgroundColor: 'white',
    borderRadius: 8,
    padding: 18,
    marginTop: 20,
    alignItems: 'center',
  },
  continueButtonText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#667eea',
  },
});

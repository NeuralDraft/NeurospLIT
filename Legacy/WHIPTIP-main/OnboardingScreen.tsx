import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
// Adjust import path for flattened repo structure. In the root-level
// structure, `calc.ts` resides alongside this file, so use a
// relative path without the `utils` folder.
import { SplitMethod } from './calc';

interface Props {
  /**
   * Called when the user completes onboarding by selecting a split method.
   */
  onDone: (method: SplitMethod) => void;
  /**
   * Whether there is saved history available. Controls the visibility
   * of the "View History" button.
   */
  hasHistory?: boolean;
  /**
   * Invoked when the user taps the "View History" button. Should
   * navigate to the history screen.
   */
  onViewHistory?: () => void;

  /**
   * Optional callback to show additional information about the available
   * splitting methods. When provided, a "Learn how it works" button will
   * appear at the bottom of the onboarding screen. Pressing it
   * invokes this callback.
   */
  onLearnMore?: () => void;
}

/**
 * OnboardingScreen presents the user with a choice of how they want to
 * split tips. This step is critical because the subsequent screens
 * change based on the chosen method. The screen remains simple and
 * focused: list the options and allow one to be selected. Once a
 * selection is made, a “Next” button appears to proceed.
 */
const OnboardingScreen: React.FC<Props> = ({ onDone, hasHistory = false, onViewHistory, onLearnMore }) => {
  const [selected, setSelected] = useState<SplitMethod | null>(null);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>How would you like to split the tips?</Text>
      {Object.values(SplitMethod).map((method) => (
        <TouchableOpacity
          key={method}
          style={[styles.option, selected === method && styles.optionSelected]}
          onPress={() => setSelected(method)}
        >
          <Text style={styles.optionText}>{labelForMethod(method)}</Text>
        </TouchableOpacity>
      ))}
      {selected && (
        <TouchableOpacity style={styles.nextButton} onPress={() => onDone(selected)}>
          <Text style={styles.nextText}>Next</Text>
        </TouchableOpacity>
      )}
      {hasHistory && onViewHistory && (
        <TouchableOpacity style={styles.historyButton} onPress={onViewHistory}>
          <Text style={styles.historyText}>View History</Text>
        </TouchableOpacity>
      )}

      {/* Show a button to learn more about splitting methods */}
      {onLearnMore && (
        <TouchableOpacity style={styles.learnButton} onPress={onLearnMore}>
          <Text style={styles.learnText}>Learn how it works</Text>
        </TouchableOpacity>
      )}
    </View>
  );
};

/**
 * Provide human‑readable labels for each split method. If new methods
 * are added in the future, update this function accordingly.
 */
function labelForMethod(method: SplitMethod): string {
  switch (method) {
    case SplitMethod.Hours:
      return 'By hours worked';
    case SplitMethod.RolePoints:
      return 'By role weight';
    case SplitMethod.Equal:
      return 'Equally';
    case SplitMethod.CustomPercentages:
      return 'Custom percentages';
    default:
      return method;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  option: {
    width: '100%',
    padding: 16,
    marginVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#cccccc',
    backgroundColor: '#f9f9f9',
  },
  optionSelected: {
    backgroundColor: '#d0e7ff',
    borderColor: '#6699cc',
  },
  optionText: {
    fontSize: 18,
    textAlign: 'center',
  },
  nextButton: {
    marginTop: 24,
    paddingVertical: 12,
    paddingHorizontal: 32,
    backgroundColor: '#007aff',
    borderRadius: 8,
  },
  nextText: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '600',
  },
  historyButton: {
    marginTop: 16,
    paddingVertical: 12,
    paddingHorizontal: 32,
    backgroundColor: '#34c759',
    borderRadius: 8,
  },
  historyText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },

  /**
   * Styles for the "learn how it works" button. This uses a subtle
   * purple tone to differentiate it from the primary navigation
   * buttons while still inviting interaction.
   */
  learnButton: {
    marginTop: 8,
    paddingVertical: 10,
  },
  learnText: {
    color: '#5856d6',
    fontSize: 16,
  },
});

export default OnboardingScreen;
import React from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet } from 'react-native';

/**
 * InfoScreen explains how the various tip splitting methods work.
 * It provides a brief overview of each method so users can make
 * an informed decision when starting a new calculation. The
 * content is distilled from research into common practices and
 * legal considerations across U.S. service industries. A simple
 * back button returns the user to onboarding.
 */
interface Props {
  /**
   * Invoked when the user is done reading and wants to return to
   * the onboarding screen.
   */
  onClose: () => void;
}

const InfoScreen: React.FC<Props> = ({ onClose }) => {
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>How Tip Splitting Works</Text>
      <Text style={styles.paragraph}>
        There are several ways to distribute a pool of gratuities among staff members. The
        most common are based on hours worked, role‑based points, equal shares, or custom
        percentages. Choosing the right method depends on your team&apos;s preferences and
        the duties performed during the shift.
      </Text>
      <Text style={styles.heading}>By Hours Worked</Text>
      <Text style={styles.paragraph}>
        Each worker receives a share proportional to the number of hours they worked. For
        example, if someone worked half as long as another, they will receive roughly half
        as much of the tip pool. This is a straightforward and commonly accepted approach.
      </Text>
      <Text style={styles.heading}>By Role Weight</Text>
      <Text style={styles.paragraph}>
        Some roles contribute more directly to revenue generation and thus are assigned
        higher point values. For instance, bartenders might be weighted more heavily than
        bussers. Points are multiplied by hours to determine each person&apos;s share. You can
        override default points when entering staff.
      </Text>
      <Text style={styles.heading}>Equal Split</Text>
      <Text style={styles.paragraph}>
        Everyone receives an identical percentage of the tips regardless of hours or role.
        This method is best suited to small teams performing similar tasks.
      </Text>
      <Text style={styles.heading}>Custom Percentages</Text>
      <Text style={styles.paragraph}>
        Use this option if your team has agreed on specific percentages ahead of time.
        Enter each person&apos;s percentage in the staff entry form. The total must add up to
        100%. Any remainder can be distributed by hours if desired.
      </Text>
      <TouchableOpacity style={styles.backButton} onPress={onClose}>
        <Text style={styles.backText}>Back</Text>
      </TouchableOpacity>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: 24,
    paddingTop: 40,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 16,
    textAlign: 'center',
  },
  heading: {
    fontSize: 20,
    fontWeight: 'bold',
    marginTop: 16,
    marginBottom: 8,
  },
  paragraph: {
    fontSize: 16,
    lineHeight: 22,
    color: '#333',
  },
  backButton: {
    marginTop: 24,
    alignSelf: 'center',
    backgroundColor: '#007aff',
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderRadius: 8,
  },
  backText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default InfoScreen;
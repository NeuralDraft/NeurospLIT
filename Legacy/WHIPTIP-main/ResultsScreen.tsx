import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Share, SafeAreaView } from 'react-native';
// Adjust import path for flattened repo structure. When this file
// lives in the repository root, import TipShare from the local
// `calc.ts` module.
import { TipShare } from './calc';

interface Props {
  /**
   * Array of calculated shares to display.
   */
  shares: TipShare[];
  /**
   * Handler invoked when the user wants to start over or perform
   * another calculation.
   */
  onRestart: () => void;
}

/**
 * ResultsScreen lists the calculated payouts for each staff member.
 * It presents both the raw numbers and the debug breakdown so that
 * everyone can understand how their share was computed. A restart
 * button allows users to return to onboarding and run another
 * calculation.
 */
const ResultsScreen: React.FC<Props> = ({ shares, onRestart }) => {
  /**
   * Share the results with teammates. Builds a simple string of each
   * worker’s name, their payout and percentage, then invokes the
   * native share sheet. If sharing fails (e.g. cancelled), it is
   * silently ignored. This promotes transparency by making it easy
   * to copy or send results via text, email or messaging apps.
   */
  const handleShare = async () => {
    const message = shares
      .map(
        (s) => `${s.name}: $${s.shareAmount.toFixed(2)} (${s.percentage.toFixed(1)}%)`,
      )
      .join('\n');
    try {
      await Share.share({ message });
    } catch (err) {
      // ignore share errors – user may have cancelled
      console.warn('Share cancelled or failed', err);
    }
  };
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>Tip Split Results</Text>
      <ScrollView style={{ flex: 1 }}>
        {shares.map((share, idx) => (
          <View key={idx} style={styles.row}>
            <Text style={styles.name}>{share.name}</Text>
            <Text style={styles.amount}>${share.shareAmount.toFixed(2)}</Text>
            <Text style={styles.breakdown}>{share.debugBreakdown}</Text>
          </View>
        ))}
      </ScrollView>
      <View style={styles.actionsContainer}>
        <TouchableOpacity style={styles.shareButton} onPress={handleShare}>
          <Text style={styles.shareText}>Share Summary</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.csvButton}
          onPress={() => {
            // Generate CSV and share it. Wrap in try/catch to
            // gracefully handle cancelled or failed sharing.
            const header = 'Name,Amount,Percentage';
            const rows = shares.map(
              (s) => `${s.name},${s.shareAmount.toFixed(2)},${s.percentage.toFixed(2)}`,
            );
            const csv = [header, ...rows].join('\n');
            Share.share({ title: 'Tip Split CSV', message: csv }).catch((err) =>
              console.warn('Share cancelled or failed', err),
            );
          }}
        >
          <Text style={styles.csvText}>Export CSV</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.restartButton} onPress={onRestart}>
          <Text style={styles.restartText}>Start Over</Text>
        </TouchableOpacity>
      </View>
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
    textAlign: 'center',
  },
  row: {
    marginBottom: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    backgroundColor: '#fafafa',
  },
  name: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  amount: {
    fontSize: 18,
    color: '#34c759',
    marginBottom: 4,
  },
  breakdown: {
    fontSize: 12,
    color: '#555',
  },
  restartButton: {
    backgroundColor: '#ff3b30',
    paddingVertical: 14,
    paddingHorizontal: 24,
    alignItems: 'center',
    borderRadius: 8,
    marginLeft: 8,
  },
  restartText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 20,
  },
  shareButton: {
    backgroundColor: '#34c759',
    paddingVertical: 14,
    paddingHorizontal: 24,
    alignItems: 'center',
    borderRadius: 8,
    marginRight: 8,
  },
  shareText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  csvButton: {
    backgroundColor: '#007aff',
    paddingVertical: 14,
    paddingHorizontal: 24,
    alignItems: 'center',
    borderRadius: 8,
    marginRight: 8,
  },
  csvText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default ResultsScreen;
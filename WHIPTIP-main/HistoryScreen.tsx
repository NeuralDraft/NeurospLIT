import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  Share,
} from 'react-native';
// Adjust import path for flattened repo structure. When this file
// resides in the repository root, the `calc.ts` module sits in
// the same directory, so we import from `./calc`.
import { SplitMethod, StaffMember, TipShare } from './calc';

/**
 * A single stored session. Includes everything needed to resume
 * a past calculation. The timestamp is used to sort and label
 * sessions chronologically. When resuming, the App component
 * simply injects the saved method, staff and results back into
 * state instead of re‑running the calculation.
 */
export interface SavedSession {
  method: SplitMethod;
  staff: StaffMember[];
  totalTips: number;
  results: TipShare[];
  timestamp: number;
}

interface Props {
  /**
   * Array of saved sessions to display. Newest sessions
   * should appear last in the list.
   */
  history: SavedSession[];
  /**
   * Called when the user selects a session to resume. The
   * selected session is passed back to the parent.
   */
  onSelect: (session: SavedSession) => void;
  /**
   * Invoked when the user taps the back button.
   */
  onBack: () => void;

  /**
   * Optional callback invoked when the user requests to clear all
   * saved sessions. When provided and there is at least one
   * session, a "Clear History" button will appear below the
   * export button. The parent component should handle removal
   * from storage and update its state accordingly.
   */
  onClearHistory?: () => void;
}

/**
 * HistoryScreen shows a scrollable list of previously calculated
 * tip splits. Each entry summarises the total tips, chosen method
 * and the timestamp the session was recorded. Tapping an entry
 * resumes that session. A simple back button returns to
 * onboarding. This screen enables users to revisit prior shifts
 * without needing to re‑enter data.
 */
const HistoryScreen: React.FC<Props> = ({ history, onSelect, onBack, onClearHistory }) => {
  // Sort sessions chronologically so the oldest appears first and the newest
  // appears last. This ensures the numbering in the list remains stable
  // across app launches.
  const sortedHistory = React.useMemo(() => {
    return [...history].sort((a, b) => a.timestamp - b.timestamp);
  }, [history]);

  // Export the entire history to a CSV file. Each row includes the
  // session date, worker name, individual amount, percentage, total
  // tips and the method used. The CSV is then shared using the
  // platform share dialog. If sharing fails (e.g. user cancels), it is
  // silently ignored.
  const handleExport = async () => {
    const header = 'Date,Method,Worker,Amount,Percentage,TotalTips';
    const rows: string[] = [];
    history.forEach((session) => {
      const date = new Date(session.timestamp).toLocaleString();
      session.results.forEach((r) => {
        rows.push(
          `${date},${session.method},${r.name},${r.shareAmount.toFixed(2)},${r.percentage.toFixed(2)},${session.totalTips.toFixed(2)}`,
        );
      });
    });
    const csv = [header, ...rows].join('\n');
    try {
      await Share.share({ title: 'Tip Split History', message: csv });
    } catch (err) {
      console.warn('Share cancelled or failed', err);
    }
  };

  // Render a list item for a session
  const renderItem = ({ item, index }: { item: SavedSession; index: number }) => {
    const date = new Date(item.timestamp);
    return (
      <TouchableOpacity style={styles.sessionRow} onPress={() => onSelect(item)}>
        <Text style={styles.sessionTitle}>Session {index + 1}</Text>
        <Text style={styles.sessionDetail}>Total: ${item.totalTips.toFixed(2)}</Text>
        <Text style={styles.sessionDetail}>Method: {labelForMethod(item.method)}</Text>
        <Text style={styles.sessionDetail}>Date: {date.toLocaleString()}</Text>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Past Sessions</Text>
      <FlatList
        data={sortedHistory}
        keyExtractor={(_, idx) => idx.toString()}
        renderItem={renderItem}
        ListEmptyComponent={<Text style={styles.empty}>No sessions saved.</Text>}
        contentContainerStyle={{ flexGrow: 1 }}
      />
      <TouchableOpacity style={styles.backButton} onPress={onBack}>
        <Text style={styles.backText}>Back</Text>
      </TouchableOpacity>
      {/* Export history CSV button */}
      {history.length > 0 && (
        <TouchableOpacity style={styles.exportButton} onPress={handleExport}>
          <Text style={styles.exportText}>Export History CSV</Text>
        </TouchableOpacity>
      )}

      {/* Clear history button appears only if a callback is provided and
          there is at least one saved session. */}
      {history.length > 0 && onClearHistory && (
        <TouchableOpacity style={styles.clearButton} onPress={onClearHistory}>
          <Text style={styles.clearText}>Clear History</Text>
        </TouchableOpacity>
      )}
    </View>
  );
};

/**
 * Human‑readable labels for split methods used in the history list.
 * Matches the labels used on the onboarding screen.
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
    padding: 20,
    paddingTop: 40,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 16,
    textAlign: 'center',
  },
  sessionRow: {
    padding: 12,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    marginBottom: 10,
    backgroundColor: '#fafafa',
  },
  sessionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  sessionDetail: {
    fontSize: 14,
    color: '#444',
  },
  backButton: {
    marginTop: 16,
    alignItems: 'center',
    paddingVertical: 14,
    borderRadius: 8,
    backgroundColor: '#007aff',
  },
  backText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  exportButton: {
    marginTop: 12,
    alignItems: 'center',
    paddingVertical: 14,
    borderRadius: 8,
    backgroundColor: '#34c759',
  },
  exportText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  // Button used to clear all saved history. Uses a red colour
  // to indicate a destructive action, consistent with other
  // destructive buttons in the app.
  clearButton: {
    marginTop: 12,
    alignItems: 'center',
    paddingVertical: 14,
    borderRadius: 8,
    backgroundColor: '#ff3b30',
  },
  clearText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  empty: {
    textAlign: 'center',
    color: '#777',
    marginTop: 40,
    fontSize: 16,
  },
});

export default HistoryScreen;
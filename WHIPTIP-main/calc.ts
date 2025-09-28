/*
 * Tip calculation utilities.
 *
 * This module provides the core calculation logic for splitting a pool
 * of gratuities among staff members using a variety of methods. It is
 * adapted from a Swift implementation used in a prior version of the
 * app. The goal is to mirror the original behaviour while taking
 * advantage of TypeScript’s type system for safety.
 */

export interface StaffMember {
  /**
   * Display name for the worker (e.g. "Alice").
   */
  name: string;
  /**
   * Role or job title. Used when applying role‑based point values.
   */
  role: string;
  /**
   * Number of hours worked during the shift. A value of 0
   * indicates the worker should receive no share for methods based on hours.
   */
  hoursWorked: number;
  /**
   * Optional override for the worker’s point value when using the
   * role‑points method. If not provided the default for their role
   * is used.
   */
  customPoints?: number;
  /**
   * Optional override for the worker’s share percentage when using
   * custom percentage splits. If defined, this should be a percentage
   * between 0 and 100.
   */
  customPercentage?: number;
}

export interface TipShare {
  /**
   * Name of the worker.
   */
  name: string;
  /**
   * Amount of the tip pool allocated to this worker.
   */
  shareAmount: number;
  /**
   * Percentage of the total pool allocated.
   */
  percentage: number;
  /**
   * Debug breakdown describing how the share was computed. Useful
   * for transparency in the UI.
   */
  debugBreakdown: string;
}

/**
 * Supported split methods. These strings are used for user
 * selection and branching in the calculation function.
 */
export enum SplitMethod {
  Hours = 'hours',
  RolePoints = 'rolePoints',
  Equal = 'equal',
  CustomPercentages = 'customPercentages',
}

/**
 * Default point values for common roles. When using the role‑points
 * method, each worker’s points is either the default for their role
 * or a custom value supplied on the StaffMember object. You can
 * extend or override this map as needed in your application.
 */
export const ROLE_POINTS_DEFAULT: Record<string, number> = {
  Bartender: 10.0,
  Server: 8.0,
  Barback: 6.0,
  Busser: 5.0,
  Runner: 5.0,
  Host: 4.0,
};

/**
 * Calculate tip shares for a given set of staff members using the
 * specified split method.
 *
 * @param totalTips The total amount of money to distribute. Must be ≥ 0.
 * @param staff     A list of staff members who participated in the shift.
 * @param method    The splitting method to use.
 * @param customAllocations Optional allocations for custom percentage
 *                          splits. Each entry names a worker and
 *                          allocates a percentage of the total pool to
 *                          them off the top before distributing the
 *                          remainder by hours.
 */
export function calculateTips(
  totalTips: number,
  staff: StaffMember[],
  method: SplitMethod,
  customAllocations?: { name: string; percentage: number }[],
): TipShare[] {
  // Guard: no tips to distribute
  if (totalTips <= 0) {
    return staff.map((member) => ({
      name: member.name,
      shareAmount: 0,
      percentage: 0,
      debugBreakdown: 'No tips to distribute',
    }));
  }
  // Guard: no staff provided
  if (staff.length === 0) {
    return [];
  }
  // Guard: single worker gets everything
  if (staff.length === 1) {
    return [
      {
        name: staff[0].name,
        shareAmount: totalTips,
        percentage: 100,
        debugBreakdown: `Single worker receives 100% = $${totalTips.toFixed(2)}`,
      },
    ];
  }

  // Route based on method
  switch (method) {
    case SplitMethod.Hours:
      return calculateHoursBased(totalTips, staff);
    case SplitMethod.RolePoints:
      return calculateRolePointsBased(totalTips, staff);
    case SplitMethod.Equal:
      return calculateEqualSplit(totalTips, staff);
    case SplitMethod.CustomPercentages:
      // Build allocations from staff-provided custom percentages if none provided
      let allocs = customAllocations;
      if (!allocs || allocs.length === 0) {
        const derived = staff
          .filter((m) => typeof m.customPercentage === 'number' && m.customPercentage! > 0)
          .map((m) => ({ name: m.name, percentage: m.customPercentage! }));
        if (derived.length > 0) {
          allocs = derived;
        }
      }
      return calculateCustomPercentages(totalTips, staff, allocs);
    default:
      // Fallback to equal split for unknown methods
      return calculateEqualSplit(totalTips, staff);
  }
}

/**
 * Hours‑based split. Each worker receives a portion of the pool
 * proportional to the number of hours they worked. Workers with
 * zero hours receive nothing.
 */
function calculateHoursBased(totalTips: number, staff: StaffMember[]): TipShare[] {
  const activeStaff = staff.filter((m) => m.hoursWorked > 0);
  // If no one worked hours, allocate zero to everyone
  if (activeStaff.length === 0) {
    return staff.map((member) => ({
      name: member.name,
      shareAmount: 0,
      percentage: 0,
      debugBreakdown: '0 hours worked → $0.00',
    }));
  }
  const totalHours = activeStaff.reduce((sum, m) => sum + m.hoursWorked, 0);
  const tipPerHour = totalTips / totalHours;
  let distributed = 0;
  const shares: TipShare[] = [];
  activeStaff.forEach((member, index) => {
    const rawShare = member.hoursWorked * tipPerHour;
    let shareAmount: number;
    if (index === activeStaff.length - 1) {
      // Assign remainder to last worker to account for rounding
      shareAmount = totalTips - distributed;
    } else {
      shareAmount = Math.round(rawShare * 100) / 100;
      distributed += shareAmount;
    }
    const percentage = (member.hoursWorked / totalHours) * 100;
    shares.push({
      name: member.name,
      shareAmount,
      percentage,
      debugBreakdown: `${member.hoursWorked.toFixed(1)} hrs ÷ ${totalHours.toFixed(1)} total hrs = ${percentage.toFixed(1)}% → $${shareAmount.toFixed(2)}`,
    });
  });
  // Add zero shares for those with no hours
  staff
    .filter((m) => m.hoursWorked <= 0)
    .forEach((m) => {
      shares.push({
        name: m.name,
        shareAmount: 0,
        percentage: 0,
        debugBreakdown: '0 hours worked → $0.00',
      });
    });
  return shares;
}

/**
 * Role points‑based split. Each worker is assigned a point value based on
 * their role (or a custom override). Points are multiplied by hours
 * worked to produce a weighted total. Shares are proportional to
 * these totals.
 */
function calculateRolePointsBased(totalTips: number, staff: StaffMember[]): TipShare[] {
  const staffPoints: { member: StaffMember; points: number }[] = [];
  staff.forEach((member) => {
    // Determine base points for this role or custom override
    const basePoints = member.customPoints ?? ROLE_POINTS_DEFAULT[member.role] ?? 5.0;
    // Only include those with positive hours and points
    if (member.hoursWorked > 0 && basePoints > 0) {
      const totalPoints = basePoints * member.hoursWorked;
      staffPoints.push({ member, points: totalPoints });
    }
  });
  // If no one qualifies, return zero shares
  if (staffPoints.length === 0) {
    return staff.map((m) => ({
      name: m.name,
      shareAmount: 0,
      percentage: 0,
      debugBreakdown: 'No valid points/hours combination',
    }));
  }
  const sumPoints = staffPoints.reduce((sum, sp) => sum + sp.points, 0);
  const dollarPerPoint = totalTips / sumPoints;
  let distributed = 0;
  const shares: TipShare[] = [];
  staffPoints.forEach((sp, index) => {
    const percentage = (sp.points / sumPoints) * 100;
    let shareAmount: number;
    if (index === staffPoints.length - 1) {
      shareAmount = totalTips - distributed;
    } else {
      const raw = sp.points * dollarPerPoint;
      shareAmount = Math.round(raw * 100) / 100;
      distributed += shareAmount;
    }
    const rolePoints = sp.member.customPoints ?? ROLE_POINTS_DEFAULT[sp.member.role] ?? 5.0;
    const breakdown = `${sp.member.role} (${rolePoints.toFixed(0)} pts) × ${sp.member.hoursWorked.toFixed(1)} hrs = ${sp.points.toFixed(1)} total pts → ${percentage.toFixed(1)}% → $${shareAmount.toFixed(2)}`;
    shares.push({
      name: sp.member.name,
      shareAmount,
      percentage,
      debugBreakdown: breakdown,
    });
  });
  // Add zero shares for excluded staff
  staff.forEach((m) => {
    if (!staffPoints.some((sp) => sp.member.name === m.name)) {
      shares.push({
        name: m.name,
        shareAmount: 0,
        percentage: 0,
        debugBreakdown: 'No hours worked or zero points → $0.00',
      });
    }
  });
  return shares;
}

/**
 * Equal split. Divides the pool equally among all workers who
 * recorded positive hours. Workers with zero hours receive nothing.
 */
function calculateEqualSplit(totalTips: number, staff: StaffMember[]): TipShare[] {
  const active = staff.filter((m) => m.hoursWorked > 0);
  if (active.length === 0) {
    return staff.map((m) => ({
      name: m.name,
      shareAmount: 0,
      percentage: 0,
      debugBreakdown: 'No hours worked',
    }));
  }
  const sharePerPerson = totalTips / active.length;
  const percentage = 100 / active.length;
  let distributed = 0;
  const shares: TipShare[] = [];
  active.forEach((m, index) => {
    let shareAmount: number;
    if (index === active.length - 1) {
      shareAmount = totalTips - distributed;
    } else {
      shareAmount = Math.round(sharePerPerson * 100) / 100;
      distributed += shareAmount;
    }
    shares.push({
      name: m.name,
      shareAmount,
      percentage,
      debugBreakdown: `Equal split among ${active.length} workers = ${percentage.toFixed(1)}% → $${shareAmount.toFixed(2)}`,
    });
  });
  // Add zero shares for inactive staff
  staff
    .filter((m) => m.hoursWorked <= 0)
    .forEach((m) => {
      shares.push({
        name: m.name,
        shareAmount: 0,
        percentage: 0,
        debugBreakdown: 'Did not work → $0.00',
      });
    });
  return shares;
}

/**
 * Custom percentages split. Allows a portion of the pool to be
 * distributed according to explicit percentage allocations for
 * specific workers. The remainder is then split by hours among
 * everyone else. Each custom allocation entry names a worker and
 * assigns them a percentage of the total pool off the top.
 */
function calculateCustomPercentages(
  totalTips: number,
  staff: StaffMember[],
  allocations?: { name: string; percentage: number }[],
): TipShare[] {
  const shares: TipShare[] = [];
  let remainingTips = totalTips;
  let remainingStaff = [...staff];
  // Apply each custom allocation
  if (allocations) {
    allocations.forEach((alloc) => {
      const amount = (alloc.percentage / 100) * totalTips;
      const rounded = Math.round(amount * 100) / 100;
      const member = staff.find((m) => m.name === alloc.name);
      if (member) {
        shares.push({
          name: member.name,
          shareAmount: rounded,
          percentage: alloc.percentage,
          debugBreakdown: `Custom allocation: ${alloc.percentage.toFixed(1)}% of total → $${rounded.toFixed(2)}`,
        });
        remainingTips -= rounded;
        remainingStaff = remainingStaff.filter((m) => m.name !== alloc.name);
      }
    });
  }
  // Split remaining tips by hours among remaining staff
  if (remainingTips > 0 && remainingStaff.length > 0) {
    const activeRemaining = remainingStaff.filter((m) => m.hoursWorked > 0);
    if (activeRemaining.length > 0) {
      const totalHours = activeRemaining.reduce((sum, m) => sum + m.hoursWorked, 0);
      let distributed = 0;
      activeRemaining.forEach((m, index) => {
        const rawShare = (m.hoursWorked / totalHours) * remainingTips;
        let shareAmount: number;
        if (index === activeRemaining.length - 1) {
          shareAmount = remainingTips - distributed;
        } else {
          shareAmount = Math.round(rawShare * 100) / 100;
          distributed += shareAmount;
        }
        const perc = (m.hoursWorked / totalHours) * (remainingTips / totalTips) * 100;
        shares.push({
          name: m.name,
          shareAmount,
          percentage: perc,
          debugBreakdown: `From remaining pool: ${m.hoursWorked.toFixed(1)} hrs ÷ ${totalHours.toFixed(1)} hrs = ${((m.hoursWorked / totalHours) * 100).toFixed(1)}% of remainder → $${shareAmount.toFixed(2)}`,
        });
      });
      // zero shares for inactive remainder
      remainingStaff
        .filter((m) => m.hoursWorked <= 0)
        .forEach((m) => {
          shares.push({
            name: m.name,
            shareAmount: 0,
            percentage: 0,
            debugBreakdown: 'No hours worked → $0.00',
          });
        });
    } else {
      // If nobody has hours, allocate zero to each
      remainingStaff.forEach((m) => {
        shares.push({
          name: m.name,
          shareAmount: 0,
          percentage: 0,
          debugBreakdown: 'No hours worked → $0.00',
        });
      });
    }
  }
  return shares;
}
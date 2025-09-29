import Decimal from 'decimal.js';

// Core types for the allocation engine
export interface TeamMember {
  id: string;
  name: string;
  role: string;
  hours?: number;
  sales?: number;
  performance?: number; // 1-5 scale
  customPoints?: number;
  isTrainee?: boolean;
  seniorityMonths?: number;
}

export interface AllocationStep {
  id: string;
  name: string;
  type: StepType;
  filter: RecipientFilter;
  method: AllocationMethod;
  amount?: Decimal;
  percentage?: number;
  priority: number;
}

export type StepType =
  | 'fixed-amount'
  | 'percentage-of-total'
  | 'percentage-of-remaining'
  | 'all-remaining';

export interface RecipientFilter {
  type: 'everyone' | 'by-role' | 'by-names' | 'by-condition';
  roles?: string[];
  names?: string[];
  condition?: (member: TeamMember) => boolean;
}

export interface AllocationMethod {
  type: 'equal' | 'by-hours' | 'by-sales' | 'by-points' | 'by-seniority' | 'weighted';
  weights?: Record<string, number>;
}

export interface SplitResult {
  allocations: Map<string, Decimal>;
  trace: AllocationTrace[];
  summary: {
    total: Decimal;
    distributed: Decimal;
    remainder: Decimal;
  };
}

export interface AllocationTrace {
  stepName: string;
  recipients: Array<{ name: string; amount: Decimal }>;
  totalAllocated: Decimal;
  remainingAfter: Decimal;
}

export class TipSplitEngine {
  private readonly PRECISION = 2; // cents

  public calculate(
    totalTips: Decimal,
    members: TeamMember[],
    steps: AllocationStep[]
  ): SplitResult {
    let remaining = new Decimal(totalTips);
    const allocations = new Map<string, Decimal>();
    const trace: AllocationTrace[] = [];

    // Initialize all members with zero
    members.forEach(m => allocations.set(m.name, new Decimal(0)));

    // Sort steps by priority
    const sortedSteps = [...steps].sort((a, b) => a.priority - b.priority);

    for (const step of sortedSteps) {
      const recipients = this.filterRecipients(members, step.filter);
      if (recipients.length === 0) continue;

      const { allocated, details } = this.executeStep(
        step,
        recipients,
        remaining,
        totalTips,
        allocations
      );

      remaining = remaining.minus(allocated);

      trace.push({
        stepName: step.name,
        recipients: details,
        totalAllocated: allocated,
        remainingAfter: remaining
      });
    }

    // Handle any remaining cents
    if (remaining.greaterThan(0)) {
      const pennies = remaining.times(100).toNumber();
      const sortedMembers = [...members].sort((a, b) => a.name.localeCompare(b.name));

      for (let i = 0; i < pennies && i < sortedMembers.length; i++) {
        const current = allocations.get(sortedMembers[i].name) || new Decimal(0);
        allocations.set(sortedMembers[i].name, current.plus(0.01));
      }
    }

    return {
      allocations,
      trace,
      summary: {
        total: totalTips,
        distributed: Array.from(allocations.values()).reduce(
          (sum, val) => sum.plus(val),
          new Decimal(0)
        ),
        remainder: remaining
      }
    };
  }

  private filterRecipients(
    members: TeamMember[],
    filter: RecipientFilter
  ): TeamMember[] {
    switch (filter.type) {
      case 'everyone':
        return members;

      case 'by-role':
        return members.filter(m => filter.roles?.includes(m.role));

      case 'by-names':
        return members.filter(m => filter.names?.includes(m.name));

      case 'by-condition':
        return filter.condition ? members.filter(filter.condition) : [];

      default:
        return [];
    }
  }

  private executeStep(
    step: AllocationStep,
    recipients: TeamMember[],
    remaining: Decimal,
    total: Decimal,
    allocations: Map<string, Decimal>
  ): { allocated: Decimal; details: Array<{ name: string; amount: Decimal }> } {
    let pot: Decimal;

    switch (step.type) {
      case 'fixed-amount':
        pot = step.amount || new Decimal(0);
        break;

      case 'percentage-of-total':
        pot = total.times((step.percentage || 0) / 100);
        break;

      case 'percentage-of-remaining':
        pot = remaining.times((step.percentage || 0) / 100);
        break;

      case 'all-remaining':
        pot = remaining;
        break;

      default:
        pot = new Decimal(0);
    }

    // Ensure we don't allocate more than remaining
    pot = Decimal.min(pot, remaining);

    // Distribute the pot according to the method
    const distribution = this.distribute(pot, recipients, step.method);

    // Update allocations
    const details: Array<{ name: string; amount: Decimal }> = [];
    distribution.forEach((amount, name) => {
      const current = allocations.get(name) || new Decimal(0);
      allocations.set(name, current.plus(amount));
      details.push({ name, amount });
    });

    return { allocated: pot, details };
  }

  private distribute(
    pot: Decimal,
    recipients: TeamMember[],
    method: AllocationMethod
  ): Map<string, Decimal> {
    const distribution = new Map<string, Decimal>();

    switch (method.type) {
      case 'equal':
        const equalShare = pot.dividedBy(recipients.length);
        recipients.forEach(r =>
          distribution.set(r.name, equalShare.toDecimalPlaces(this.PRECISION))
        );
        break;

      case 'by-hours':
        const totalHours = recipients.reduce((sum, r) => sum + (r.hours || 0), 0);
        if (totalHours > 0) {
          recipients.forEach(r => {
            const share = pot.times((r.hours || 0) / totalHours);
            distribution.set(r.name, share.toDecimalPlaces(this.PRECISION));
          });
        }
        break;

      case 'by-sales':
        const totalSales = recipients.reduce((sum, r) => sum + (r.sales || 0), 0);
        if (totalSales > 0) {
          recipients.forEach(r => {
            const share = pot.times((r.sales || 0) / totalSales);
            distribution.set(r.name, share.toDecimalPlaces(this.PRECISION));
          });
        }
        break;

      case 'by-points':
        const totalPoints = recipients.reduce((sum, r) => sum + (r.customPoints || 1), 0);
        recipients.forEach(r => {
          const share = pot.times((r.customPoints || 1) / totalPoints);
          distribution.set(r.name, share.toDecimalPlaces(this.PRECISION));
        });
        break;

      case 'by-seniority':
        const totalSeniority = recipients.reduce((sum, r) => sum + (r.seniorityMonths || 0), 0);
        if (totalSeniority > 0) {
          recipients.forEach(r => {
            const share = pot.times((r.seniorityMonths || 0) / totalSeniority);
            distribution.set(r.name, share.toDecimalPlaces(this.PRECISION));
          });
        }
        break;

      case 'weighted':
        if (method.weights) {
          const totalWeight = Object.values(method.weights).reduce((a, b) => a + b, 0);
          recipients.forEach(r => {
            const weight = method.weights?.[r.role] || 1;
            const share = pot.times(weight / totalWeight);
            distribution.set(r.name, share.toDecimalPlaces(this.PRECISION));
          });
        }
        break;
    }

    // Reconcile rounding differences
    this.reconcileRounding(distribution, pot);

    return distribution;
  }

  private reconcileRounding(distribution: Map<string, Decimal>, target: Decimal): void {
    const sum = Array.from(distribution.values()).reduce(
      (acc, val) => acc.plus(val),
      new Decimal(0)
    );

    let diff = target.minus(sum);
    const names = Array.from(distribution.keys()).sort();

    // Distribute penny differences
    while (diff.absoluteValue() >= 0.01 && names.length > 0) {
      for (const name of names) {
        if (diff.absoluteValue() < 0.01) break;

        const current = distribution.get(name) || new Decimal(0);
        if (diff.greaterThan(0)) {
          distribution.set(name, current.plus(0.01));
          diff = diff.minus(0.01);
        } else {
          distribution.set(name, current.minus(0.01));
          diff = diff.plus(0.01);
        }
      }
    }
  }
}

/**
 * Phase 17 — consent records, the data export and account deletion
 * (MASTER-SPEC §23, ADR-023).
 *
 * The export and the deletion both follow the database's own foreign keys,
 * so a table added in any later phase is covered without touching this file:
 *   - **owned** rows are those reached from `users` through ON DELETE CASCADE
 *     foreign keys (the user's profile, logs, sessions, their children…);
 *   - SET NULL references (an admin's `reviewed_by`, an audit row's actor)
 *     are pointers, not ownership: they are neither exported (they would carry
 *     other people's data) nor deleted (the database nulls them).
 */
import { and, desc, eq, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { auditLogs, consentRecords, users } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface ForeignKey {
  readonly child: string;
  readonly childColumn: string;
  readonly parent: string;
  readonly parentColumn: string;
  readonly onDelete: string;
}

const MAX_DEPTH = 6;
const quote = (ident: string): string => `"${ident.replace(/"/g, '""')}"`;

export class PrivacyRepository {
  constructor(private readonly db: Db) {}

  /* ------------------------------------------------------------ consent -- */

  async latestConsents(userId: string): Promise<Map<string, { granted: boolean; policyVersion: string; at: Date }>> {
    const rows = await this.db
      .select()
      .from(consentRecords)
      .where(eq(consentRecords.userId, userId))
      .orderBy(desc(consentRecords.grantedAt), desc(consentRecords.id));
    const out = new Map<string, { granted: boolean; policyVersion: string; at: Date }>();
    for (const r of rows) {
      if (!out.has(r.consentType)) out.set(r.consentType, { granted: r.granted, policyVersion: r.policyVersion, at: r.grantedAt });
    }
    return out;
  }

  async hasConsent(userId: string, type: 'ai-processing'): Promise<boolean> {
    const [r] = await this.db
      .select({ granted: consentRecords.granted })
      .from(consentRecords)
      .where(and(eq(consentRecords.userId, userId), eq(consentRecords.consentType, type)))
      .orderBy(desc(consentRecords.grantedAt), desc(consentRecords.id))
      .limit(1);
    return r?.granted ?? false;
  }

  async recordConsent(userId: string, type: (typeof consentRecords.$inferInsert)['consentType'], granted: boolean, policyVersion: string, ipHash: string | null): Promise<void> {
    await this.db.insert(consentRecords).values({ userId, consentType: type, granted, policyVersion, ipHash });
  }

  /* --------------------------------------------------------- the FK graph -- */

  async foreignKeys(): Promise<ForeignKey[]> {
    const rows = await this.db.execute<{ child: string; child_column: string; parent: string; parent_column: string; on_delete: string }>(sql`
      select kcu.table_name as child, kcu.column_name as child_column,
             ccu.table_name as parent, ccu.column_name as parent_column,
             rc.delete_rule as on_delete
      from information_schema.referential_constraints rc
      join information_schema.key_column_usage kcu
        on kcu.constraint_name = rc.constraint_name and kcu.constraint_schema = rc.constraint_schema
      join information_schema.constraint_column_usage ccu
        on ccu.constraint_name = rc.unique_constraint_name and ccu.constraint_schema = rc.unique_constraint_schema
      where rc.constraint_schema = 'public'`);
    return [...rows].map((r) => ({ child: r.child, childColumn: r.child_column, parent: r.parent, parentColumn: r.parent_column, onDelete: r.on_delete }));
  }

  /**
   * Every row the user owns, by table: `users` itself, then every table
   * reached through CASCADE foreign keys, breadth first. Rows are as stored
   * (snake_case columns, JSON values).
   */
  async ownedRows(userId: string): Promise<Record<string, Record<string, unknown>[]>> {
    const fks = (await this.foreignKeys()).filter((f) => f.onDelete === 'CASCADE');
    const tables: Record<string, Record<string, unknown>[]> = {};
    const seen = new Map<string, Set<string>>();
    const add = (table: string, rows: Record<string, unknown>[]): Record<string, unknown>[] => {
      const keys = seen.get(table) ?? new Set<string>();
      seen.set(table, keys);
      const fresh = rows.filter((r) => {
        const k = JSON.stringify(r);
        if (keys.has(k)) return false;
        keys.add(k);
        return true;
      });
      tables[table] = [...(tables[table] ?? []), ...fresh];
      return fresh;
    };

    const select = async (table: string, column: string, values: readonly unknown[]): Promise<Record<string, unknown>[]> => {
      const out: Record<string, unknown>[] = [];
      // Bound parameters, in chunks (Postgres caps parameters per statement).
      for (let i = 0; i < values.length; i += 1000) {
        const chunk = values.slice(i, i + 1000).map((v) => sql`${String(v)}`);
        const rows = await this.db.execute<Record<string, unknown>>(
          sql`select to_jsonb(t) as row from ${sql.raw(quote(table))} t where ${sql.raw(quote(column))}::text in (${sql.join(chunk, sql`, `)})`,
        );
        out.push(...[...rows].map((r) => (r as { row: Record<string, unknown> }).row));
      }
      return out;
    };

    let frontier: { table: string; rows: Record<string, unknown>[] }[] = [{ table: 'users', rows: add('users', await select('users', 'id', [userId])) }];
    for (let depth = 0; depth < MAX_DEPTH && frontier.length > 0; depth++) {
      const next: typeof frontier = [];
      for (const { table, rows } of frontier) {
        for (const fk of fks.filter((f) => f.parent === table)) {
          const values = [...new Set(rows.map((r) => r[fk.parentColumn]).filter((v) => v !== null && v !== undefined))];
          const fresh = add(fk.child, await select(fk.child, fk.childColumn, values));
          if (fresh.length > 0) next.push({ table: fk.child, rows: fresh });
        }
      }
      frontier = next;
    }
    return Object.fromEntries(Object.entries(tables).filter(([, rows]) => rows.length > 0));
  }

  /* ------------------------------------------------------------ erasure -- */

  async firebaseUid(userId: string): Promise<string | null> {
    const [r] = await this.db.select({ uid: users.firebaseUid }).from(users).where(eq(users.id, userId)).limit(1);
    return r?.uid ?? null;
  }

  /**
   * The user's rows, all at once: CASCADE takes what they own, SET NULL
   * unhooks what pointed at them. Audit entries ABOUT them (a support lookup)
   * lose the id; the entry itself stays, anonymous.
   */
  async deleteUser(userId: string): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx
        .update(auditLogs)
        .set({ entityId: null, metadata: sql`${auditLogs.metadata} || '{"subjectDeleted": true}'::jsonb` })
        .where(and(eq(auditLogs.entity, 'user'), eq(auditLogs.entityId, userId)));
      await tx.delete(users).where(eq(users.id, userId));
    });
  }
}
